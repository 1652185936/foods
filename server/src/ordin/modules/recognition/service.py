import asyncio
import base64
import hashlib
import re
from datetime import datetime, timedelta
from uuid import UUID

from ordin.core.clock import Clock
from ordin.core.errors import (
    InvalidImageError,
    InvalidRecognitionStateError,
    ResourceNotFoundError,
    ServiceUnavailableError,
    UploadStateConflictError,
    VersionConflictError,
)
from ordin.core.identifiers import new_uuid
from ordin.core.security import HmacDigester
from ordin.modules.recognition.errors import (
    InvalidImageContentError,
    ObjectNotFoundError,
    ObjectStorageUnavailableError,
)
from ordin.modules.recognition.models import (
    CorrectionWriteStatus,
    PresignedUpload,
    RecognitionCreateResult,
    RecognitionItemInput,
    RecognitionJob,
    RecognitionUpload,
    UploadStatus,
)
from ordin.modules.recognition.ports import (
    ImageProcessor,
    ObjectStorage,
    RecognitionRepository,
    RecognitionTaskDispatcher,
)

ALLOWED_IMAGE_CONTENT_TYPES = frozenset({"image/jpeg", "image/png", "image/webp"})
_SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")


class RecognitionService:
    def __init__(
        self,
        *,
        repository: RecognitionRepository,
        storage: ObjectStorage,
        image_processor: ImageProcessor,
        dispatcher: RecognitionTaskDispatcher,
        clock: Clock,
        idempotency_digester: HmacDigester,
        upload_ttl_seconds: int,
        source_retention_seconds: int,
        max_image_bytes: int,
        max_image_pixels: int,
    ) -> None:
        self._repository = repository
        self._storage = storage
        self._image_processor = image_processor
        self._dispatcher = dispatcher
        self._clock = clock
        self._idempotency_digester = idempotency_digester
        self._upload_ttl_seconds = upload_ttl_seconds
        self._source_retention_seconds = source_retention_seconds
        self._max_image_bytes = max_image_bytes
        self._max_image_pixels = max_image_pixels

    async def create_upload(
        self,
        *,
        user_id: UUID,
        content_type: str,
        size_bytes: int,
        checksum_sha256: str,
    ) -> tuple[RecognitionUpload, PresignedUpload]:
        normalized_content_type = content_type.lower().strip()
        normalized_checksum = checksum_sha256.lower().strip()
        if normalized_content_type not in ALLOWED_IMAGE_CONTENT_TYPES:
            raise InvalidImageError
        if not 1 <= size_bytes <= self._max_image_bytes:
            raise InvalidImageError
        if _SHA256_PATTERN.fullmatch(normalized_checksum) is None:
            raise InvalidImageError

        now = self._clock.now()
        upload_id = new_uuid()
        object_key = f"recognition/incoming/{new_uuid().hex}"
        upload = RecognitionUpload(
            id=upload_id,
            user_id=user_id,
            incoming_object_key=object_key,
            expected_content_type=normalized_content_type,
            expected_size_bytes=size_bytes,
            expected_checksum_sha256=normalized_checksum,
            status=UploadStatus.INITIATED,
            expires_at=now + timedelta(seconds=self._upload_ttl_seconds),
            claimed_at=None,
            sanitized_object_key=None,
            sanitized_content_type=None,
            sanitized_size_bytes=None,
            sanitized_checksum_sha256=None,
            width=None,
            height=None,
            retention_until=None,
            created_at=now,
            updated_at=now,
        )
        await self._repository.create_upload(upload)
        try:
            signed = await self._storage.create_presigned_upload(
                key=object_key,
                content_type=normalized_content_type,
                size_bytes=size_bytes,
                checksum_sha256=normalized_checksum,
                expires_at=upload.expires_at,
            )
        except ObjectStorageUnavailableError as error:
            raise ServiceUnavailableError from error
        return upload, signed

    async def complete_upload(self, *, user_id: UUID, upload_id: UUID) -> RecognitionUpload:
        now = self._clock.now()
        claim = await self._repository.claim_upload(
            user_id=user_id,
            upload_id=upload_id,
            now=now,
        )
        if claim is None:
            raise ResourceNotFoundError
        upload = claim.upload
        if upload.status in {UploadStatus.READY, UploadStatus.CONSUMED}:
            return upload
        if upload.status in {UploadStatus.INVALID, UploadStatus.EXPIRED}:
            raise ResourceNotFoundError
        if not claim.claimed:
            raise UploadStateConflictError

        try:
            metadata = await self._storage.head(upload.incoming_object_key)
            content = await self._storage.read(
                upload.incoming_object_key,
                max_bytes=self._max_image_bytes,
            )
        except ObjectNotFoundError as error:
            await self._repository.release_upload(user_id=user_id, upload_id=upload_id, now=now)
            raise UploadStateConflictError from error
        except ObjectStorageUnavailableError as error:
            await self._repository.release_upload(user_id=user_id, upload_id=upload_id, now=now)
            raise ServiceUnavailableError from error
        except InvalidImageContentError as error:
            await self._repository.invalidate_upload(user_id=user_id, upload_id=upload_id, now=now)
            await self._best_effort_delete(upload.incoming_object_key)
            raise InvalidImageError from error

        try:
            self._validate_uploaded_object(
                upload, metadata.size_bytes, metadata.content_type, content
            )
            processed = await asyncio.to_thread(
                self._image_processor.sanitize,
                content=content,
                declared_content_type=upload.expected_content_type,
                max_pixels=self._max_image_pixels,
            )
            retention_until = now + timedelta(seconds=self._source_retention_seconds)
            sanitized_key = await self._repository.reserve_sanitized_object_key(
                user_id=user_id,
                upload_id=upload_id,
                candidate_object_key=(f"recognition/source/{new_uuid().hex}.{processed.extension}"),
                cleanup_id=new_uuid(),
                retention_until=retention_until,
                now=now,
            )
            if sanitized_key is None:
                raise UploadStateConflictError
            await self._storage.write(
                key=sanitized_key,
                content=processed.content,
                content_type=processed.content_type,
            )
        except InvalidImageContentError as error:
            await self._repository.invalidate_upload(user_id=user_id, upload_id=upload_id, now=now)
            await self._best_effort_delete(upload.incoming_object_key)
            raise InvalidImageError from error
        except ObjectStorageUnavailableError as error:
            await self._repository.release_upload(user_id=user_id, upload_id=upload_id, now=now)
            raise ServiceUnavailableError from error

        try:
            completed = await self._repository.complete_upload(
                user_id=user_id,
                upload_id=upload_id,
                image=processed,
                sanitized_object_key=sanitized_key,
                retention_until=retention_until,
                now=now,
            )
        except Exception as error:
            current = await self._current_upload_after_write_failure(
                user_id=user_id,
                upload_id=upload_id,
                sanitized_key=sanitized_key,
            )
            if current is not None:
                await self._best_effort_delete(upload.incoming_object_key)
                return current
            await self._best_effort_delete(sanitized_key)
            await self._best_effort_release(user_id=user_id, upload_id=upload_id, now=now)
            raise ServiceUnavailableError from error
        if completed is None:
            await self._repository.enqueue_sanitized_object_cleanup(
                upload_id=upload_id,
                object_key=sanitized_key,
                cleanup_id=new_uuid(),
                now=now,
            )
            await self._best_effort_delete(sanitized_key)
            raise UploadStateConflictError
        await self._best_effort_delete(upload.incoming_object_key)
        return completed

    async def create_recognition(
        self,
        *,
        user_id: UUID,
        upload_id: UUID,
        idempotency_key: str,
    ) -> RecognitionCreateResult:
        now = self._clock.now()
        key_hash = self._idempotency_digester.digest(f"recognition:{user_id}:{idempotency_key}")
        request_hash = self._idempotency_digester.digest(
            f"recognition-request:{user_id}:{upload_id}"
        )
        result = await self._repository.create_job(
            user_id=user_id,
            upload_id=upload_id,
            job_id=new_uuid(),
            idempotency_key_hash=key_hash,
            request_hash=request_hash,
            now=now,
        )
        if result is None:
            raise UploadStateConflictError
        try:
            await self._dispatcher.enqueue(result.job.id)
        except Exception as error:
            # The queued row is intentionally retained. A replay with the same key re-enqueues it,
            # while the worker's database claim makes duplicate delivery harmless.
            raise ServiceUnavailableError from error
        return result

    async def get_recognition(self, *, user_id: UUID, job_id: UUID) -> RecognitionJob:
        job = await self._repository.get_job(user_id=user_id, job_id=job_id)
        if job is None:
            raise ResourceNotFoundError
        return job

    async def correct_recognition(
        self,
        *,
        user_id: UUID,
        job_id: UUID,
        expected_version: int,
        items: tuple[RecognitionItemInput, ...],
    ) -> RecognitionJob:
        result = await self._repository.apply_correction(
            user_id=user_id,
            job_id=job_id,
            expected_version=expected_version,
            items=items,
            correction_id=new_uuid(),
            now=self._clock.now(),
        )
        if result.status is CorrectionWriteStatus.NOT_FOUND:
            raise ResourceNotFoundError
        if result.status is CorrectionWriteStatus.VERSION_CONFLICT:
            raise VersionConflictError
        if result.status is CorrectionWriteStatus.INVALID_STATE:
            raise InvalidRecognitionStateError
        if result.job is None:
            raise RuntimeError("applied correction did not return a recognition job")
        return result.job

    async def ready(self) -> None:
        await asyncio.gather(
            self._repository.ping(),
            self._storage.ping(),
            self._dispatcher.ping(),
        )

    def _validate_uploaded_object(
        self,
        upload: RecognitionUpload,
        actual_size: int,
        actual_content_type: str,
        content: bytes,
    ) -> None:
        if actual_size != upload.expected_size_bytes or len(content) != upload.expected_size_bytes:
            raise InvalidImageContentError("size mismatch")
        if actual_content_type.lower().strip() != upload.expected_content_type:
            raise InvalidImageContentError("content type mismatch")
        checksum = hashlib.sha256(content).hexdigest()
        if checksum != upload.expected_checksum_sha256:
            raise InvalidImageContentError("checksum mismatch")

    async def _best_effort_delete(self, key: str) -> None:
        try:
            await self._storage.delete(key)
        except ObjectStorageUnavailableError:
            return

    async def _best_effort_release(
        self,
        *,
        user_id: UUID,
        upload_id: UUID,
        now: datetime,
    ) -> None:
        try:
            await self._repository.release_upload(
                user_id=user_id,
                upload_id=upload_id,
                now=now,
            )
        except Exception:
            return

    async def _current_upload_after_write_failure(
        self,
        *,
        user_id: UUID,
        upload_id: UUID,
        sanitized_key: str,
    ) -> RecognitionUpload | None:
        try:
            current = await self._repository.get_upload(user_id=user_id, upload_id=upload_id)
        except Exception:
            return None
        if (
            current is not None
            and current.status in {UploadStatus.READY, UploadStatus.CONSUMED}
            and current.sanitized_object_key == sanitized_key
        ):
            return current
        return None


def checksum_header_value(checksum_sha256: str) -> str:
    return base64.b64encode(bytes.fromhex(checksum_sha256)).decode("ascii")
