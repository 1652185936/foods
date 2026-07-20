from datetime import datetime
from typing import Protocol
from uuid import UUID

from ordin.modules.recognition.models import (
    CorrectionWriteResult,
    PresignedUpload,
    ProcessedImage,
    ProviderAnalysis,
    RecognitionCreateResult,
    RecognitionItem,
    RecognitionItemInput,
    RecognitionJob,
    RecognitionUpload,
    StoredObject,
    UploadClaim,
)


class ObjectStorage(Protocol):
    async def create_presigned_upload(
        self,
        *,
        key: str,
        content_type: str,
        size_bytes: int,
        checksum_sha256: str,
        expires_at: datetime,
    ) -> PresignedUpload: ...

    async def head(self, key: str) -> StoredObject: ...

    async def read(self, key: str, *, max_bytes: int) -> bytes: ...

    async def write(self, *, key: str, content: bytes, content_type: str) -> StoredObject: ...

    async def delete(self, key: str) -> None: ...

    async def ping(self) -> None: ...


class ImageProcessor(Protocol):
    def sanitize(
        self,
        *,
        content: bytes,
        declared_content_type: str,
        max_pixels: int,
    ) -> ProcessedImage: ...


class RecognitionTaskDispatcher(Protocol):
    async def enqueue(self, job_id: UUID) -> None: ...

    async def ping(self) -> None: ...


class RecognitionRepository(Protocol):
    async def create_upload(self, upload: RecognitionUpload) -> RecognitionUpload: ...

    async def claim_upload(
        self,
        *,
        user_id: UUID,
        upload_id: UUID,
        now: datetime,
    ) -> UploadClaim | None: ...

    async def release_upload(self, *, user_id: UUID, upload_id: UUID, now: datetime) -> None: ...

    async def invalidate_upload(self, *, user_id: UUID, upload_id: UUID, now: datetime) -> None: ...

    async def reserve_sanitized_object_key(
        self,
        *,
        user_id: UUID,
        upload_id: UUID,
        candidate_object_key: str,
        cleanup_id: UUID,
        retention_until: datetime,
        now: datetime,
    ) -> str | None: ...

    async def enqueue_sanitized_object_cleanup(
        self,
        *,
        upload_id: UUID,
        object_key: str,
        cleanup_id: UUID,
        now: datetime,
    ) -> None: ...

    async def complete_upload(
        self,
        *,
        user_id: UUID,
        upload_id: UUID,
        image: ProcessedImage,
        sanitized_object_key: str,
        retention_until: datetime,
        now: datetime,
    ) -> RecognitionUpload | None: ...

    async def get_upload(self, *, user_id: UUID, upload_id: UUID) -> RecognitionUpload | None: ...

    async def create_job(
        self,
        *,
        user_id: UUID,
        upload_id: UUID,
        job_id: UUID,
        idempotency_key_hash: str,
        request_hash: str,
        now: datetime,
    ) -> RecognitionCreateResult | None: ...

    async def get_job(self, *, user_id: UUID, job_id: UUID) -> RecognitionJob | None: ...

    async def apply_correction(
        self,
        *,
        user_id: UUID,
        job_id: UUID,
        expected_version: int,
        items: tuple[RecognitionItemInput, ...],
        correction_id: UUID,
        now: datetime,
    ) -> CorrectionWriteResult: ...

    async def ping(self) -> None: ...


class SyncRecognitionObjectStorage(Protocol):
    def read(self, key: str, *, max_bytes: int) -> bytes: ...

    def delete(self, key: str) -> None: ...


class RecognitionProvider(Protocol):
    def analyze_food_image(self, *, content: bytes, content_type: str) -> ProviderAnalysis: ...


class WorkerRecognitionRepository(Protocol):
    def claim_job(
        self,
        *,
        job_id: UUID,
        now: datetime,
        lease_seconds: int,
    ) -> tuple[RecognitionJob, str, str] | None: ...

    def complete_job(
        self,
        *,
        job_id: UUID,
        analysis: ProviderAnalysis,
        status: str,
        needs_review_reason: str | None,
        items: tuple[RecognitionItem, ...],
        now: datetime,
    ) -> None: ...

    def release_job_for_retry(self, *, job_id: UUID, error_code: str, now: datetime) -> None: ...

    def fail_job(self, *, job_id: UUID, error_code: str, now: datetime) -> None: ...

    def list_expired_sources(
        self, *, now: datetime, limit: int
    ) -> tuple[tuple[UUID, str], ...]: ...

    def list_expired_incoming_uploads(
        self, *, now: datetime, limit: int
    ) -> tuple[tuple[UUID, str], ...]: ...

    def mark_incoming_object_deleted(self, *, upload_id: UUID, now: datetime) -> None: ...

    def mark_source_deleted(self, *, upload_id: UUID, now: datetime) -> None: ...
