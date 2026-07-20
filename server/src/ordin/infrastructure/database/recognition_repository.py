import hashlib
from collections.abc import Sequence
from datetime import datetime, timedelta
from typing import Any
from uuid import UUID

from sqlalchemy import delete, exists, func, select, update
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker
from sqlalchemy.orm import Session, sessionmaker

from ordin.core.errors import IdempotencyConflictError
from ordin.infrastructure.database.account_models import AccountObjectCleanupRow
from ordin.infrastructure.database.models import UserRow
from ordin.infrastructure.database.recognition_models import (
    RecognitionCorrectionRow,
    RecognitionItemRow,
    RecognitionJobRow,
    RecognitionUploadRow,
)
from ordin.modules.recognition.models import (
    CorrectionWriteResult,
    CorrectionWriteStatus,
    ProcessedImage,
    ProviderAnalysis,
    RecognitionAlternative,
    RecognitionCreateResult,
    RecognitionItem,
    RecognitionItemInput,
    RecognitionJob,
    RecognitionStatus,
    RecognitionUpload,
    UploadClaim,
    UploadStatus,
)


class SqlAlchemyRecognitionRepository:
    def __init__(self, session_factory: async_sessionmaker[AsyncSession]) -> None:
        self._session_factory = session_factory

    async def create_upload(self, upload: RecognitionUpload) -> RecognitionUpload:
        async with self._session_factory() as session, session.begin():
            session.add(_upload_row(upload))
        return upload

    async def claim_upload(
        self,
        *,
        user_id: UUID,
        upload_id: UUID,
        now: datetime,
    ) -> UploadClaim | None:
        async with self._session_factory() as session, session.begin():
            row = await session.scalar(
                select(RecognitionUploadRow)
                .where(
                    RecognitionUploadRow.user_id == user_id,
                    RecognitionUploadRow.id == upload_id,
                )
                .with_for_update()
            )
            if row is None:
                return None
            if row.status == UploadStatus.INITIATED.value and row.expires_at <= now:
                row.status = UploadStatus.EXPIRED.value
                row.updated_at = now
                return UploadClaim(_to_upload(row), claimed=False)
            if row.status == UploadStatus.INITIATED.value:
                row.status = UploadStatus.PROCESSING.value
                row.claimed_at = now
                row.updated_at = now
                return UploadClaim(_to_upload(row), claimed=True)
            return UploadClaim(_to_upload(row), claimed=False)

    async def release_upload(self, *, user_id: UUID, upload_id: UUID, now: datetime) -> None:
        async with self._session_factory() as session, session.begin():
            await session.execute(
                update(RecognitionUploadRow)
                .where(
                    RecognitionUploadRow.user_id == user_id,
                    RecognitionUploadRow.id == upload_id,
                    RecognitionUploadRow.status == UploadStatus.PROCESSING.value,
                )
                .values(
                    status=UploadStatus.INITIATED.value,
                    claimed_at=None,
                    updated_at=now,
                )
            )

    async def invalidate_upload(self, *, user_id: UUID, upload_id: UUID, now: datetime) -> None:
        async with self._session_factory() as session, session.begin():
            await session.execute(
                update(RecognitionUploadRow)
                .where(
                    RecognitionUploadRow.user_id == user_id,
                    RecognitionUploadRow.id == upload_id,
                    RecognitionUploadRow.status == UploadStatus.PROCESSING.value,
                )
                .values(status=UploadStatus.INVALID.value, updated_at=now)
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
        async with self._session_factory() as session, session.begin():
            active_user_id = await session.scalar(
                select(UserRow.id)
                .where(UserRow.id == user_id, UserRow.status == "active")
                .with_for_update()
            )
            if active_user_id is None:
                return None
            row = await session.scalar(
                select(RecognitionUploadRow)
                .where(
                    RecognitionUploadRow.user_id == user_id,
                    RecognitionUploadRow.id == upload_id,
                )
                .with_for_update()
            )
            if row is None or row.status != UploadStatus.PROCESSING.value:
                return None
            object_key = row.sanitized_object_key or candidate_object_key
            row.sanitized_object_key = object_key
            row.retention_until = row.retention_until or retention_until
            row.updated_at = now
            cleanup = insert(AccountObjectCleanupRow).values(
                id=cleanup_id,
                batch_id=upload_id,
                object_key=object_key,
                attempt_count=0,
                queued_at=now,
                next_attempt_at=retention_until,
                claimed_at=None,
                completed_at=None,
            )
            await session.execute(
                cleanup.on_conflict_do_nothing(index_elements=[AccountObjectCleanupRow.object_key])
            )
            return object_key

    async def enqueue_sanitized_object_cleanup(
        self,
        *,
        upload_id: UUID,
        object_key: str,
        cleanup_id: UUID,
        now: datetime,
    ) -> None:
        async with self._session_factory() as session, session.begin():
            cleanup = insert(AccountObjectCleanupRow).values(
                id=cleanup_id,
                batch_id=upload_id,
                object_key=object_key,
                attempt_count=0,
                queued_at=now,
                next_attempt_at=now,
                claimed_at=None,
                completed_at=None,
            )
            await session.execute(
                cleanup.on_conflict_do_update(
                    index_elements=[AccountObjectCleanupRow.object_key],
                    set_={
                        "batch_id": upload_id,
                        "next_attempt_at": now,
                        "claimed_at": None,
                        "completed_at": None,
                    },
                )
            )

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
        async with self._session_factory() as session, session.begin():
            row = await session.scalar(
                select(RecognitionUploadRow)
                .where(
                    RecognitionUploadRow.user_id == user_id,
                    RecognitionUploadRow.id == upload_id,
                )
                .with_for_update()
            )
            if (
                row is None
                or row.status != UploadStatus.PROCESSING.value
                or row.sanitized_object_key != sanitized_object_key
            ):
                return None
            row.status = UploadStatus.READY.value
            row.sanitized_object_key = sanitized_object_key
            row.sanitized_content_type = image.content_type
            row.sanitized_size_bytes = len(image.content)
            row.sanitized_checksum_sha256 = image.checksum_sha256
            row.width = image.width
            row.height = image.height
            row.retention_until = retention_until
            row.updated_at = now
            return _to_upload(row)

    async def get_upload(self, *, user_id: UUID, upload_id: UUID) -> RecognitionUpload | None:
        async with self._session_factory() as session:
            row = await session.scalar(
                select(RecognitionUploadRow).where(
                    RecognitionUploadRow.user_id == user_id,
                    RecognitionUploadRow.id == upload_id,
                )
            )
            return _to_upload(row) if row is not None else None

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
        async with self._session_factory() as session, session.begin():
            await session.execute(
                select(func.pg_advisory_xact_lock(_advisory_key(user_id, idempotency_key_hash)))
            )
            existing = await session.scalar(
                select(RecognitionJobRow).where(
                    RecognitionJobRow.user_id == user_id,
                    RecognitionJobRow.idempotency_key_hash == idempotency_key_hash,
                )
            )
            if existing is not None:
                if existing.request_hash != request_hash:
                    raise IdempotencyConflictError
                items = await _load_items_async(session, user_id=user_id, job_id=existing.id)
                return RecognitionCreateResult(_to_job(existing, items), created=False)

            upload = await session.scalar(
                select(RecognitionUploadRow)
                .where(
                    RecognitionUploadRow.user_id == user_id,
                    RecognitionUploadRow.id == upload_id,
                )
                .with_for_update()
            )
            if (
                upload is None
                or upload.status != UploadStatus.READY.value
                or upload.sanitized_object_key is None
                or upload.sanitized_content_type is None
                or upload.retention_until is None
                or upload.retention_until <= now
            ):
                return None
            row = RecognitionJobRow(
                user_id=user_id,
                id=job_id,
                upload_id=upload_id,
                idempotency_key_hash=idempotency_key_hash,
                request_hash=request_hash,
                status=RecognitionStatus.QUEUED.value,
                provider_name=None,
                overall_confidence_milli=None,
                needs_review_reason=None,
                error_code=None,
                version=1,
                attempt_count=0,
                claimed_at=None,
                source_retention_until=upload.retention_until,
                created_at=now,
                updated_at=now,
                completed_at=None,
            )
            session.add(row)
            upload.status = UploadStatus.CONSUMED.value
            upload.consumed_at = now
            upload.updated_at = now
            await session.flush()
            return RecognitionCreateResult(_to_job(row, ()), created=True)

    async def get_job(self, *, user_id: UUID, job_id: UUID) -> RecognitionJob | None:
        async with self._session_factory() as session:
            row = await session.scalar(
                select(RecognitionJobRow).where(
                    RecognitionJobRow.user_id == user_id,
                    RecognitionJobRow.id == job_id,
                )
            )
            if row is None:
                return None
            items = await _load_items_async(session, user_id=user_id, job_id=job_id)
            return _to_job(row, items)

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
        async with self._session_factory() as session, session.begin():
            row = await session.scalar(
                select(RecognitionJobRow)
                .where(
                    RecognitionJobRow.user_id == user_id,
                    RecognitionJobRow.id == job_id,
                )
                .with_for_update()
            )
            if row is None:
                return CorrectionWriteResult(CorrectionWriteStatus.NOT_FOUND, None)
            current_items = await _load_items_async(session, user_id=user_id, job_id=job_id)
            current_job = _to_job(row, current_items)
            if row.version != expected_version:
                return CorrectionWriteResult(CorrectionWriteStatus.VERSION_CONFLICT, current_job)
            if row.status not in {
                RecognitionStatus.SUCCEEDED.value,
                RecognitionStatus.NEEDS_REVIEW.value,
            }:
                return CorrectionWriteResult(CorrectionWriteStatus.INVALID_STATE, current_job)

            session.add(
                RecognitionCorrectionRow(
                    user_id=user_id,
                    id=correction_id,
                    job_id=job_id,
                    base_version=expected_version,
                    corrected_items=[
                        _correction_json(item, position) for position, item in enumerate(items)
                    ],
                    created_at=now,
                )
            )
            await session.execute(
                delete(RecognitionItemRow).where(
                    RecognitionItemRow.user_id == user_id,
                    RecognitionItemRow.job_id == job_id,
                )
            )
            corrected = tuple(
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
            session.add_all(_item_row(user_id, job_id, item) for item in corrected)
            row.status = RecognitionStatus.SUCCEEDED.value
            row.overall_confidence_milli = 1000
            row.needs_review_reason = None
            row.error_code = None
            row.version += 1
            row.updated_at = now
            row.completed_at = row.completed_at or now
            await session.flush()
            return CorrectionWriteResult(
                CorrectionWriteStatus.APPLIED,
                _to_job(row, corrected),
            )

    async def ping(self) -> None:
        async with self._session_factory() as session:
            await session.execute(select(1))


class SqlAlchemyWorkerRecognitionRepository:
    def __init__(self, session_factory: sessionmaker[Session]) -> None:
        self._session_factory = session_factory

    def claim_job(
        self,
        *,
        job_id: UUID,
        now: datetime,
        lease_seconds: int,
    ) -> tuple[RecognitionJob, str, str] | None:
        with self._session_factory() as session, session.begin():
            row = session.scalar(
                select(RecognitionJobRow).where(RecognitionJobRow.id == job_id).with_for_update()
            )
            if row is None:
                return None
            if row.source_retention_until <= now:
                if row.status in {RecognitionStatus.QUEUED.value, RecognitionStatus.RUNNING.value}:
                    row.status = RecognitionStatus.EXPIRED.value
                    row.version += 1
                    row.updated_at = now
                    row.completed_at = now
                return None
            stale_before = now - timedelta(seconds=lease_seconds)
            claimable = row.status == RecognitionStatus.QUEUED.value or (
                row.status == RecognitionStatus.RUNNING.value
                and row.claimed_at is not None
                and row.claimed_at <= stale_before
            )
            if not claimable:
                return None
            upload = session.scalar(
                select(RecognitionUploadRow).where(
                    RecognitionUploadRow.user_id == row.user_id,
                    RecognitionUploadRow.id == row.upload_id,
                )
            )
            if (
                upload is None
                or upload.sanitized_object_key is None
                or upload.sanitized_content_type is None
            ):
                row.status = RecognitionStatus.FAILED.value
                row.error_code = "source_unavailable"
                row.version += 1
                row.updated_at = now
                row.completed_at = now
                return None
            row.status = RecognitionStatus.RUNNING.value
            row.claimed_at = now
            row.attempt_count += 1
            row.error_code = None
            row.version += 1
            row.updated_at = now
            session.flush()
            items = _load_items_sync(session, user_id=row.user_id, job_id=row.id)
            return _to_job(row, items), upload.sanitized_object_key, upload.sanitized_content_type

    def complete_job(
        self,
        *,
        job_id: UUID,
        analysis: ProviderAnalysis,
        status: str,
        needs_review_reason: str | None,
        items: tuple[RecognitionItem, ...],
        now: datetime,
    ) -> None:
        with self._session_factory() as session, session.begin():
            row = session.scalar(
                select(RecognitionJobRow).where(RecognitionJobRow.id == job_id).with_for_update()
            )
            if row is None or row.status != RecognitionStatus.RUNNING.value:
                return
            session.execute(delete(RecognitionItemRow).where(RecognitionItemRow.job_id == job_id))
            session.add_all(_item_row(row.user_id, row.id, item) for item in items)
            row.status = status
            row.provider_name = analysis.provider_name
            row.overall_confidence_milli = analysis.overall_confidence_milli
            row.needs_review_reason = needs_review_reason
            row.error_code = None
            row.claimed_at = None
            row.version += 1
            row.updated_at = now
            row.completed_at = now

    def release_job_for_retry(self, *, job_id: UUID, error_code: str, now: datetime) -> None:
        with self._session_factory() as session, session.begin():
            row = session.scalar(
                select(RecognitionJobRow).where(RecognitionJobRow.id == job_id).with_for_update()
            )
            if row is not None and row.status == RecognitionStatus.RUNNING.value:
                row.status = RecognitionStatus.QUEUED.value
                row.error_code = error_code
                row.claimed_at = None
                row.version += 1
                row.updated_at = now

    def fail_job(self, *, job_id: UUID, error_code: str, now: datetime) -> None:
        with self._session_factory() as session, session.begin():
            row = session.scalar(
                select(RecognitionJobRow).where(RecognitionJobRow.id == job_id).with_for_update()
            )
            if row is not None and row.status in {
                RecognitionStatus.QUEUED.value,
                RecognitionStatus.RUNNING.value,
            }:
                row.status = RecognitionStatus.FAILED.value
                row.error_code = error_code
                row.claimed_at = None
                row.version += 1
                row.updated_at = now
                row.completed_at = now

    def list_expired_sources(
        self,
        *,
        now: datetime,
        limit: int,
    ) -> tuple[tuple[UUID, str], ...]:
        with self._session_factory() as session:
            running_job = exists().where(
                RecognitionJobRow.upload_id == RecognitionUploadRow.id,
                RecognitionJobRow.status == RecognitionStatus.RUNNING.value,
            )
            rows = session.scalars(
                select(RecognitionUploadRow)
                .where(
                    RecognitionUploadRow.retention_until.is_not(None),
                    RecognitionUploadRow.retention_until <= now,
                    RecognitionUploadRow.sanitized_object_key.is_not(None),
                    ~running_job,
                )
                .order_by(RecognitionUploadRow.retention_until)
                .limit(limit)
            )
            return tuple(
                (row.id, row.sanitized_object_key)
                for row in rows
                if row.sanitized_object_key is not None
            )

    def list_expired_incoming_uploads(
        self,
        *,
        now: datetime,
        limit: int,
    ) -> tuple[tuple[UUID, str], ...]:
        with self._session_factory() as session:
            rows = session.scalars(
                select(RecognitionUploadRow)
                .where(
                    RecognitionUploadRow.expires_at <= now,
                    RecognitionUploadRow.incoming_deleted_at.is_(None),
                )
                .order_by(RecognitionUploadRow.expires_at, RecognitionUploadRow.id)
                .limit(limit)
            )
            return tuple((row.id, row.incoming_object_key) for row in rows)

    def mark_incoming_object_deleted(self, *, upload_id: UUID, now: datetime) -> None:
        with self._session_factory() as session, session.begin():
            row = session.scalar(
                select(RecognitionUploadRow)
                .where(RecognitionUploadRow.id == upload_id)
                .with_for_update()
            )
            if row is None or row.expires_at > now:
                return
            if row.status not in {UploadStatus.READY.value, UploadStatus.CONSUMED.value}:
                row.status = UploadStatus.EXPIRED.value
                row.claimed_at = None
            row.incoming_deleted_at = now
            row.updated_at = now

    def mark_source_deleted(self, *, upload_id: UUID, now: datetime) -> None:
        with self._session_factory() as session, session.begin():
            row = session.scalar(
                select(RecognitionUploadRow)
                .where(RecognitionUploadRow.id == upload_id)
                .with_for_update()
            )
            if row is None:
                return
            row.status = UploadStatus.EXPIRED.value
            row.sanitized_object_key = None
            row.sanitized_checksum_sha256 = None
            row.sanitized_size_bytes = None
            row.updated_at = now
            session.execute(
                update(RecognitionJobRow)
                .where(
                    RecognitionJobRow.upload_id == upload_id,
                    RecognitionJobRow.status == RecognitionStatus.QUEUED.value,
                )
                .values(
                    status=RecognitionStatus.EXPIRED.value,
                    error_code="source_expired",
                    version=RecognitionJobRow.version + 1,
                    updated_at=now,
                    completed_at=now,
                )
            )


async def _load_items_async(
    session: AsyncSession,
    *,
    user_id: UUID,
    job_id: UUID,
) -> tuple[RecognitionItem, ...]:
    rows = await session.scalars(
        select(RecognitionItemRow)
        .where(
            RecognitionItemRow.user_id == user_id,
            RecognitionItemRow.job_id == job_id,
        )
        .order_by(RecognitionItemRow.position)
    )
    return tuple(_to_item(row) for row in rows)


def _load_items_sync(
    session: Session,
    *,
    user_id: UUID,
    job_id: UUID,
) -> tuple[RecognitionItem, ...]:
    rows = session.scalars(
        select(RecognitionItemRow)
        .where(
            RecognitionItemRow.user_id == user_id,
            RecognitionItemRow.job_id == job_id,
        )
        .order_by(RecognitionItemRow.position)
    )
    return tuple(_to_item(row) for row in rows)


def _upload_row(upload: RecognitionUpload) -> RecognitionUploadRow:
    return RecognitionUploadRow(
        user_id=upload.user_id,
        id=upload.id,
        incoming_object_key=upload.incoming_object_key,
        expected_content_type=upload.expected_content_type,
        expected_size_bytes=upload.expected_size_bytes,
        expected_checksum_sha256=upload.expected_checksum_sha256,
        status=upload.status.value,
        expires_at=upload.expires_at,
        claimed_at=upload.claimed_at,
        incoming_deleted_at=None,
        sanitized_object_key=upload.sanitized_object_key,
        sanitized_content_type=upload.sanitized_content_type,
        sanitized_size_bytes=upload.sanitized_size_bytes,
        sanitized_checksum_sha256=upload.sanitized_checksum_sha256,
        width=upload.width,
        height=upload.height,
        retention_until=upload.retention_until,
        consumed_at=None,
        created_at=upload.created_at,
        updated_at=upload.updated_at,
    )


def _to_upload(row: RecognitionUploadRow) -> RecognitionUpload:
    return RecognitionUpload(
        id=row.id,
        user_id=row.user_id,
        incoming_object_key=row.incoming_object_key,
        expected_content_type=row.expected_content_type,
        expected_size_bytes=row.expected_size_bytes,
        expected_checksum_sha256=row.expected_checksum_sha256,
        status=UploadStatus(row.status),
        expires_at=row.expires_at,
        claimed_at=row.claimed_at,
        sanitized_object_key=row.sanitized_object_key,
        sanitized_content_type=row.sanitized_content_type,
        sanitized_size_bytes=row.sanitized_size_bytes,
        sanitized_checksum_sha256=row.sanitized_checksum_sha256,
        width=row.width,
        height=row.height,
        retention_until=row.retention_until,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


def _to_job(row: RecognitionJobRow, items: Sequence[RecognitionItem]) -> RecognitionJob:
    return RecognitionJob(
        id=row.id,
        user_id=row.user_id,
        upload_id=row.upload_id,
        status=RecognitionStatus(row.status),
        provider_name=row.provider_name,
        overall_confidence_milli=row.overall_confidence_milli,
        needs_review_reason=row.needs_review_reason,
        error_code=row.error_code,
        version=row.version,
        attempt_count=row.attempt_count,
        source_retention_until=row.source_retention_until,
        created_at=row.created_at,
        updated_at=row.updated_at,
        completed_at=row.completed_at,
        items=tuple(items),
    )


def _item_row(user_id: UUID, job_id: UUID, item: RecognitionItem) -> RecognitionItemRow:
    return RecognitionItemRow(
        user_id=user_id,
        id=item.id,
        job_id=job_id,
        position=item.position,
        name=item.name,
        canonical_food_id=item.canonical_food_id,
        serving_milli=item.serving_milli,
        energy_kcal=item.energy_kcal,
        protein_mg=item.protein_mg,
        carbs_mg=item.carbs_mg,
        fat_mg=item.fat_mg,
        confidence_milli=item.confidence_milli,
        alternatives=[
            {"name": alternative.name, "confidenceMilli": alternative.confidence_milli}
            for alternative in item.alternatives
        ],
        is_user_corrected=item.is_user_corrected,
    )


def _to_item(row: RecognitionItemRow) -> RecognitionItem:
    alternatives = tuple(
        RecognitionAlternative(
            name=str(value["name"]),
            confidence_milli=int(value["confidenceMilli"]),
        )
        for value in row.alternatives
        if isinstance(value, dict) and "name" in value and "confidenceMilli" in value
    )
    return RecognitionItem(
        id=row.id,
        position=row.position,
        name=row.name,
        canonical_food_id=row.canonical_food_id,
        serving_milli=row.serving_milli,
        energy_kcal=row.energy_kcal,
        protein_mg=row.protein_mg,
        carbs_mg=row.carbs_mg,
        fat_mg=row.fat_mg,
        confidence_milli=row.confidence_milli,
        alternatives=alternatives,
        is_user_corrected=row.is_user_corrected,
    )


def _correction_json(item: RecognitionItemInput, position: int) -> dict[str, Any]:
    return {
        "id": str(item.id),
        "position": position,
        "name": item.name,
        "canonicalFoodId": item.canonical_food_id,
        "servingMilli": item.serving_milli,
        "energyKcal": item.energy_kcal,
        "proteinMg": item.protein_mg,
        "carbsMg": item.carbs_mg,
        "fatMg": item.fat_mg,
    }


def _advisory_key(user_id: UUID, idempotency_key_hash: str) -> int:
    digest = hashlib.sha256(f"{user_id}:{idempotency_key_hash}".encode()).digest()
    return int.from_bytes(digest[:8], "big", signed=True)
