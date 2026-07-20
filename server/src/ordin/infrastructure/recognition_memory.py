import asyncio
from dataclasses import replace
from datetime import datetime
from uuid import UUID

from ordin.core.errors import IdempotencyConflictError
from ordin.modules.recognition.models import (
    CorrectionWriteResult,
    CorrectionWriteStatus,
    ProcessedImage,
    RecognitionCreateResult,
    RecognitionItem,
    RecognitionItemInput,
    RecognitionJob,
    RecognitionStatus,
    RecognitionUpload,
    UploadClaim,
    UploadStatus,
)


class InMemoryRecognitionRepository:
    def __init__(self) -> None:
        self._uploads: dict[tuple[UUID, UUID], RecognitionUpload] = {}
        self._jobs: dict[tuple[UUID, UUID], RecognitionJob] = {}
        self._idempotency: dict[tuple[UUID, str], tuple[str, UUID]] = {}
        self.sanitized_object_cleanups: dict[str, datetime] = {}
        self.corrections: list[tuple[UUID, UUID, int, tuple[RecognitionItemInput, ...]]] = []
        self._lock = asyncio.Lock()

    async def create_upload(self, upload: RecognitionUpload) -> RecognitionUpload:
        async with self._lock:
            self._uploads[(upload.user_id, upload.id)] = upload
            return upload

    async def claim_upload(
        self,
        *,
        user_id: UUID,
        upload_id: UUID,
        now: datetime,
    ) -> UploadClaim | None:
        async with self._lock:
            key = (user_id, upload_id)
            upload = self._uploads.get(key)
            if upload is None:
                return None
            if upload.status is UploadStatus.INITIATED and upload.expires_at <= now:
                upload = replace(upload, status=UploadStatus.EXPIRED, updated_at=now)
                self._uploads[key] = upload
                return UploadClaim(upload=upload, claimed=False)
            if upload.status is UploadStatus.INITIATED:
                upload = replace(
                    upload,
                    status=UploadStatus.PROCESSING,
                    claimed_at=now,
                    updated_at=now,
                )
                self._uploads[key] = upload
                return UploadClaim(upload=upload, claimed=True)
            return UploadClaim(upload=upload, claimed=False)

    async def release_upload(self, *, user_id: UUID, upload_id: UUID, now: datetime) -> None:
        async with self._lock:
            key = (user_id, upload_id)
            upload = self._uploads.get(key)
            if upload is not None and upload.status is UploadStatus.PROCESSING:
                self._uploads[key] = replace(
                    upload,
                    status=UploadStatus.INITIATED,
                    claimed_at=None,
                    updated_at=now,
                )

    async def invalidate_upload(self, *, user_id: UUID, upload_id: UUID, now: datetime) -> None:
        async with self._lock:
            key = (user_id, upload_id)
            upload = self._uploads.get(key)
            if upload is not None:
                self._uploads[key] = replace(
                    upload,
                    status=UploadStatus.INVALID,
                    updated_at=now,
                )

    async def reserve_sanitized_object_key(
        self,
        *,
        user_id: UUID,
        upload_id: UUID,
        candidate_object_key: str,
        cleanup_id: UUID,
        retention_until: datetime,
        now: datetime,
    ) -> str | None:
        del cleanup_id
        async with self._lock:
            key = (user_id, upload_id)
            upload = self._uploads.get(key)
            if upload is None or upload.status is not UploadStatus.PROCESSING:
                return None
            object_key = upload.sanitized_object_key or candidate_object_key
            self._uploads[key] = replace(
                upload,
                sanitized_object_key=object_key,
                retention_until=upload.retention_until or retention_until,
                updated_at=now,
            )
            self.sanitized_object_cleanups.setdefault(object_key, retention_until)
            return object_key

    async def enqueue_sanitized_object_cleanup(
        self,
        *,
        upload_id: UUID,
        object_key: str,
        cleanup_id: UUID,
        now: datetime,
    ) -> None:
        del upload_id, cleanup_id
        async with self._lock:
            self.sanitized_object_cleanups[object_key] = now

    async def complete_upload(
        self,
        *,
        user_id: UUID,
        upload_id: UUID,
        image: ProcessedImage,
        sanitized_object_key: str,
        retention_until: datetime,
        now: datetime,
    ) -> RecognitionUpload | None:
        async with self._lock:
            key = (user_id, upload_id)
            upload = self._uploads.get(key)
            if (
                upload is None
                or upload.status is not UploadStatus.PROCESSING
                or upload.sanitized_object_key != sanitized_object_key
            ):
                return None
            completed = replace(
                upload,
                status=UploadStatus.READY,
                sanitized_object_key=sanitized_object_key,
                sanitized_content_type=image.content_type,
                sanitized_size_bytes=len(image.content),
                sanitized_checksum_sha256=image.checksum_sha256,
                width=image.width,
                height=image.height,
                retention_until=retention_until,
                updated_at=now,
            )
            self._uploads[key] = completed
            return completed

    async def get_upload(self, *, user_id: UUID, upload_id: UUID) -> RecognitionUpload | None:
        return self._uploads.get((user_id, upload_id))

    async def create_job(
        self,
        *,
        user_id: UUID,
        upload_id: UUID,
        job_id: UUID,
        idempotency_key_hash: str,
        request_hash: str,
        now: datetime,
    ) -> RecognitionCreateResult | None:
        async with self._lock:
            idempotency_key = (user_id, idempotency_key_hash)
            existing = self._idempotency.get(idempotency_key)
            if existing is not None:
                existing_request_hash, existing_job_id = existing
                if existing_request_hash != request_hash:
                    raise IdempotencyConflictError
                return RecognitionCreateResult(
                    job=self._jobs[(user_id, existing_job_id)],
                    created=False,
                )

            upload_key = (user_id, upload_id)
            upload = self._uploads.get(upload_key)
            if (
                upload is None
                or upload.status is not UploadStatus.READY
                or upload.sanitized_object_key is None
                or upload.retention_until is None
                or upload.retention_until <= now
            ):
                return None
            job = RecognitionJob(
                id=job_id,
                user_id=user_id,
                upload_id=upload_id,
                status=RecognitionStatus.QUEUED,
                provider_name=None,
                overall_confidence_milli=None,
                needs_review_reason=None,
                error_code=None,
                version=1,
                attempt_count=0,
                source_retention_until=upload.retention_until,
                created_at=now,
                updated_at=now,
                completed_at=None,
                items=(),
            )
            self._jobs[(user_id, job_id)] = job
            self._idempotency[idempotency_key] = (request_hash, job_id)
            self._uploads[upload_key] = replace(
                upload,
                status=UploadStatus.CONSUMED,
                updated_at=now,
            )
            return RecognitionCreateResult(job=job, created=True)

    async def get_job(self, *, user_id: UUID, job_id: UUID) -> RecognitionJob | None:
        return self._jobs.get((user_id, job_id))

    async def apply_correction(
        self,
        *,
        user_id: UUID,
        job_id: UUID,
        expected_version: int,
        items: tuple[RecognitionItemInput, ...],
        correction_id: UUID,
        now: datetime,
    ) -> CorrectionWriteResult:
        async with self._lock:
            key = (user_id, job_id)
            job = self._jobs.get(key)
            if job is None:
                return CorrectionWriteResult(CorrectionWriteStatus.NOT_FOUND, None)
            if job.version != expected_version:
                return CorrectionWriteResult(CorrectionWriteStatus.VERSION_CONFLICT, job)
            if job.status not in {RecognitionStatus.SUCCEEDED, RecognitionStatus.NEEDS_REVIEW}:
                return CorrectionWriteResult(CorrectionWriteStatus.INVALID_STATE, job)
            corrected_items = tuple(
                RecognitionItem(
                    id=item.id,
                    position=position,
                    name=item.name,
                    canonical_food_id=item.canonical_food_id,
                    serving_milli=item.serving_milli,
                    energy_kcal=item.energy_kcal,
                    protein_mg=item.protein_mg,
                    carbs_mg=item.carbs_mg,
                    fat_mg=item.fat_mg,
                    confidence_milli=1000,
                    alternatives=(),
                    is_user_corrected=True,
                )
                for position, item in enumerate(items)
            )
            corrected = replace(
                job,
                status=RecognitionStatus.SUCCEEDED,
                overall_confidence_milli=1000,
                needs_review_reason=None,
                version=job.version + 1,
                updated_at=now,
                completed_at=job.completed_at or now,
                items=corrected_items,
            )
            self._jobs[key] = corrected
            self.corrections.append((correction_id, job_id, expected_version, items))
            return CorrectionWriteResult(CorrectionWriteStatus.APPLIED, corrected)

    async def ping(self) -> None:
        return None


class RecordingRecognitionDispatcher:
    def __init__(self) -> None:
        self.enqueued: list[UUID] = []
        self.ping_error: Exception | None = None

    async def enqueue(self, job_id: UUID) -> None:
        self.enqueued.append(job_id)

    async def ping(self) -> None:
        if self.ping_error is not None:
            raise self.ping_error
