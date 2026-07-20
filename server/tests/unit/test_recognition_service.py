import hashlib
from datetime import UTC, datetime
from io import BytesIO
from uuid import UUID

import pytest
from PIL import Image

from ordin.core.errors import ServiceUnavailableError, UploadStateConflictError
from ordin.core.security import HmacDigester
from ordin.infrastructure.image_processing import PillowImageProcessor
from ordin.infrastructure.object_storage.memory import InMemoryObjectStorage
from ordin.infrastructure.recognition_memory import (
    InMemoryRecognitionRepository,
    RecordingRecognitionDispatcher,
)
from ordin.modules.recognition.errors import ObjectStorageUnavailableError
from ordin.modules.recognition.models import ProcessedImage, RecognitionUpload, UploadStatus
from ordin.modules.recognition.service import RecognitionService


class _Clock:
    def now(self) -> datetime:
        return datetime(2026, 7, 20, 12, tzinfo=UTC)


class _FailingCompleteRepository(InMemoryRecognitionRepository):
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
        del user_id, upload_id, image, sanitized_object_key, retention_until, now
        raise RuntimeError("database unavailable")


class _DeletedDuringCompleteRepository(InMemoryRecognitionRepository):
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
        del image, sanitized_object_key, retention_until, now
        self._uploads.pop((user_id, upload_id), None)
        return None


class _UnavailableSourceDeleteStorage(InMemoryObjectStorage):
    async def delete(self, key: str) -> None:
        if key.startswith("recognition/source/"):
            raise ObjectStorageUnavailableError
        await super().delete(key)


async def test_sanitized_object_is_removed_and_claim_released_if_database_write_fails() -> None:
    repository = _FailingCompleteRepository()
    storage = InMemoryObjectStorage()
    service = RecognitionService(
        repository=repository,
        storage=storage,
        image_processor=PillowImageProcessor(),
        dispatcher=RecordingRecognitionDispatcher(),
        clock=_Clock(),
        idempotency_digester=HmacDigester("test-secret"),
        upload_ttl_seconds=600,
        source_retention_seconds=3600,
        max_image_bytes=1024 * 1024,
        max_image_pixels=1_000_000,
    )
    output = BytesIO()
    with Image.new("RGB", (12, 8), color=(30, 60, 90)) as image:
        image.save(output, format="PNG")
    content = output.getvalue()
    user_id = UUID("00000000-0000-0000-0000-000000000001")
    upload, _ = await service.create_upload(
        user_id=user_id,
        content_type="image/png",
        size_bytes=len(content),
        checksum_sha256=hashlib.sha256(content).hexdigest(),
    )
    await storage.put_uploaded(
        key=upload.incoming_object_key,
        content=content,
        content_type="image/png",
    )

    with pytest.raises(ServiceUnavailableError):
        await service.complete_upload(user_id=user_id, upload_id=upload.id)

    current = await repository.get_upload(user_id=user_id, upload_id=upload.id)
    assert current is not None and current.status is UploadStatus.INITIATED
    assert all(not key.startswith("recognition/source/") for key in storage._objects)


async def test_account_delete_during_write_rearms_durable_sanitized_cleanup() -> None:
    repository = _DeletedDuringCompleteRepository()
    storage = _UnavailableSourceDeleteStorage()
    service = RecognitionService(
        repository=repository,
        storage=storage,
        image_processor=PillowImageProcessor(),
        dispatcher=RecordingRecognitionDispatcher(),
        clock=_Clock(),
        idempotency_digester=HmacDigester("test-secret"),
        upload_ttl_seconds=600,
        source_retention_seconds=3600,
        max_image_bytes=1024 * 1024,
        max_image_pixels=1_000_000,
    )
    output = BytesIO()
    with Image.new("RGB", (12, 8), color=(30, 60, 90)) as image:
        image.save(output, format="PNG")
    content = output.getvalue()
    user_id = UUID("00000000-0000-0000-0000-000000000002")
    upload, _ = await service.create_upload(
        user_id=user_id,
        content_type="image/png",
        size_bytes=len(content),
        checksum_sha256=hashlib.sha256(content).hexdigest(),
    )
    await storage.put_uploaded(
        key=upload.incoming_object_key,
        content=content,
        content_type="image/png",
    )

    with pytest.raises(UploadStateConflictError):
        await service.complete_upload(user_id=user_id, upload_id=upload.id)

    source_keys = [key for key in storage._objects if key.startswith("recognition/source/")]
    assert len(source_keys) == 1
    assert repository.sanitized_object_cleanups[source_keys[0]] == _Clock().now()
