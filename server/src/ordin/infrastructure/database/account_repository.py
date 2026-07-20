from collections import defaultdict
from datetime import datetime, timedelta
from typing import Any
from uuid import UUID

from sqlalchemy import delete, exists, func, literal, or_, select, text, union_all, update
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker
from sqlalchemy.orm import Session, sessionmaker

from ordin.core.errors import AccountExportTooLargeError
from ordin.infrastructure.database.account_models import AccountObjectCleanupRow
from ordin.infrastructure.database.models import (
    DeviceRow,
    FastingSessionRow,
    HealthProfileRow,
    MealItemRow,
    MealLogRow,
    SessionRow,
    UserPreferencesRow,
    UserRow,
)
from ordin.infrastructure.database.recognition_models import (
    RecognitionCorrectionRow,
    RecognitionItemRow,
    RecognitionJobRow,
    RecognitionUploadRow,
)
from ordin.modules.accounts.models import (
    AccountDataSnapshot,
    AccountDeletion,
    AccountObjectCleanup,
    AccountRecognitionCorrection,
    AccountRecognitionCorrectionItem,
    AccountRecognitionResult,
)
from ordin.modules.recognition.models import RecognitionAlternative, RecognitionItem
from ordin.modules.records.models import (
    FastingPlan,
    FastingSession,
    FastingSessionStatus,
    MealItemInput,
    MealLog,
    MealSource,
    MealType,
    UserPreferences,
)
from ordin.modules.users.models import GoalType, HealthProfile, User, UserStatus


class SqlAlchemyAccountRepository:
    def __init__(self, session_factory: async_sessionmaker[AsyncSession]) -> None:
        self._session_factory = session_factory

    async def export_snapshot(
        self,
        *,
        user_id: UUID,
        exported_at: datetime,
        max_records: int,
    ) -> AccountDataSnapshot | None:
        async with self._session_factory() as session, session.begin():
            await session.execute(text("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY"))
            user_row = await session.scalar(
                select(UserRow).where(
                    UserRow.id == user_id,
                    UserRow.status == UserStatus.ACTIVE.value,
                )
            )
            if user_row is None:
                return None

            total = await self._export_record_count(session, user_id=user_id)
            if total > max_records:
                raise AccountExportTooLargeError

            health_row = await session.get(HealthProfileRow, user_id)
            preferences_row = await session.get(UserPreferencesRow, user_id)
            meal_rows = tuple(
                await session.scalars(
                    select(MealLogRow)
                    .where(MealLogRow.user_id == user_id, MealLogRow.deleted_at.is_(None))
                    .order_by(MealLogRow.occurred_at, MealLogRow.id)
                )
            )
            meal_item_rows = tuple(
                await session.scalars(
                    select(MealItemRow)
                    .join(
                        MealLogRow,
                        (MealLogRow.user_id == MealItemRow.user_id)
                        & (MealLogRow.id == MealItemRow.meal_log_id),
                    )
                    .where(
                        MealItemRow.user_id == user_id,
                        MealLogRow.deleted_at.is_(None),
                    )
                    .order_by(MealItemRow.meal_log_id, MealItemRow.position)
                )
            )
            fasting_rows = tuple(
                await session.scalars(
                    select(FastingSessionRow)
                    .where(
                        FastingSessionRow.user_id == user_id,
                        FastingSessionRow.deleted_at.is_(None),
                    )
                    .order_by(FastingSessionRow.started_at, FastingSessionRow.id)
                )
            )
            job_rows = tuple(
                await session.scalars(
                    select(RecognitionJobRow)
                    .where(RecognitionJobRow.user_id == user_id)
                    .order_by(RecognitionJobRow.created_at, RecognitionJobRow.id)
                )
            )
            recognition_item_rows = tuple(
                await session.scalars(
                    select(RecognitionItemRow)
                    .where(RecognitionItemRow.user_id == user_id)
                    .order_by(RecognitionItemRow.job_id, RecognitionItemRow.position)
                )
            )
            correction_rows = tuple(
                await session.scalars(
                    select(RecognitionCorrectionRow)
                    .where(RecognitionCorrectionRow.user_id == user_id)
                    .order_by(
                        RecognitionCorrectionRow.job_id,
                        RecognitionCorrectionRow.created_at,
                        RecognitionCorrectionRow.id,
                    )
                )
            )

            meal_items: dict[UUID, list[MealItemRow]] = defaultdict(list)
            for meal_item_row in meal_item_rows:
                meal_items[meal_item_row.meal_log_id].append(meal_item_row)
            recognition_items: dict[UUID, list[RecognitionItemRow]] = defaultdict(list)
            for recognition_item_row in recognition_item_rows:
                recognition_items[recognition_item_row.job_id].append(recognition_item_row)
            corrections: dict[UUID, list[RecognitionCorrectionRow]] = defaultdict(list)
            for correction_row in correction_rows:
                corrections[correction_row.job_id].append(correction_row)

            return AccountDataSnapshot(
                exported_at=exported_at,
                user=_user(user_row),
                health_profile=_health_profile(health_row) if health_row is not None else None,
                preferences=(
                    _preferences(preferences_row) if preferences_row is not None else None
                ),
                meals=tuple(_meal(row, meal_items[row.id]) for row in meal_rows),
                fasting_sessions=tuple(_fasting(row) for row in fasting_rows),
                recognitions=tuple(
                    _recognition(
                        row,
                        recognition_items[row.id],
                        corrections[row.id],
                    )
                    for row in job_rows
                ),
            )

    async def delete_account(
        self,
        *,
        user_id: UUID,
        session_id: UUID,
        refresh_token_hash: str,
        device_installation_id: UUID,
        cleanup_batch_id: UUID,
        now: datetime,
        immediate_cleanup_limit: int,
    ) -> AccountDeletion | None:
        async with self._session_factory() as session, session.begin():
            user_row = await session.scalar(
                select(UserRow)
                .where(
                    UserRow.id == user_id,
                    UserRow.status == UserStatus.ACTIVE.value,
                )
                .with_for_update()
            )
            if user_row is None:
                return None
            current_session = await session.scalar(
                select(SessionRow)
                .join(DeviceRow, DeviceRow.id == SessionRow.device_id)
                .where(
                    SessionRow.id == session_id,
                    SessionRow.user_id == user_id,
                    SessionRow.refresh_token_hash == refresh_token_hash,
                    SessionRow.revoked_at.is_(None),
                    SessionRow.expires_at > now,
                    DeviceRow.user_id == user_id,
                    DeviceRow.installation_id == device_installation_id,
                )
                .with_for_update()
            )
            if current_session is None:
                return None

            object_keys = union_all(
                select(RecognitionUploadRow.incoming_object_key.label("object_key")).where(
                    RecognitionUploadRow.user_id == user_id
                ),
                select(RecognitionUploadRow.sanitized_object_key.label("object_key")).where(
                    RecognitionUploadRow.user_id == user_id,
                    RecognitionUploadRow.sanitized_object_key.is_not(None),
                ),
            ).subquery()
            enqueue = insert(AccountObjectCleanupRow).from_select(
                (
                    "id",
                    "batch_id",
                    "object_key",
                    "attempt_count",
                    "queued_at",
                    "next_attempt_at",
                    "claimed_at",
                    "completed_at",
                ),
                select(
                    func.gen_random_uuid(),
                    literal(cleanup_batch_id),
                    object_keys.c.object_key,
                    literal(0),
                    literal(now),
                    literal(now),
                    literal(None),
                    literal(None),
                ),
            )
            await session.execute(
                enqueue.on_conflict_do_update(
                    index_elements=[AccountObjectCleanupRow.object_key],
                    set_={
                        "batch_id": cleanup_batch_id,
                        "queued_at": now,
                        "next_attempt_at": now,
                        "claimed_at": None,
                        "completed_at": None,
                    },
                )
            )
            await session.execute(delete(UserRow).where(UserRow.id == user_id))
            immediate = tuple(
                await session.scalars(
                    select(AccountObjectCleanupRow)
                    .where(
                        AccountObjectCleanupRow.batch_id == cleanup_batch_id,
                        AccountObjectCleanupRow.completed_at.is_(None),
                    )
                    .order_by(AccountObjectCleanupRow.queued_at, AccountObjectCleanupRow.id)
                    .limit(immediate_cleanup_limit)
                )
            )
            return AccountDeletion(
                immediate_cleanups=tuple(
                    AccountObjectCleanup(id=row.id, object_key=row.object_key) for row in immediate
                )
            )

    async def mark_cleanup_succeeded(self, *, cleanup_id: UUID, now: datetime) -> None:
        async with self._session_factory() as session, session.begin():
            await session.execute(
                update(AccountObjectCleanupRow)
                .where(
                    AccountObjectCleanupRow.id == cleanup_id,
                    AccountObjectCleanupRow.completed_at.is_(None),
                )
                .values(completed_at=now, claimed_at=None)
            )

    async def mark_cleanup_failed(self, *, cleanup_id: UUID, now: datetime) -> None:
        async with self._session_factory() as session, session.begin():
            await session.execute(
                update(AccountObjectCleanupRow)
                .where(
                    AccountObjectCleanupRow.id == cleanup_id,
                    AccountObjectCleanupRow.completed_at.is_(None),
                )
                .values(
                    attempt_count=AccountObjectCleanupRow.attempt_count + 1,
                    next_attempt_at=now + timedelta(minutes=2),
                    claimed_at=None,
                )
            )

    @staticmethod
    async def _export_record_count(session: AsyncSession, *, user_id: UUID) -> int:
        meal_count = (
            select(func.count())
            .select_from(MealLogRow)
            .where(MealLogRow.user_id == user_id, MealLogRow.deleted_at.is_(None))
            .scalar_subquery()
        )
        meal_item_count = (
            select(func.count())
            .select_from(MealItemRow)
            .join(
                MealLogRow,
                (MealLogRow.user_id == MealItemRow.user_id)
                & (MealLogRow.id == MealItemRow.meal_log_id),
            )
            .where(MealItemRow.user_id == user_id, MealLogRow.deleted_at.is_(None))
            .scalar_subquery()
        )
        fasting_count = (
            select(func.count())
            .select_from(FastingSessionRow)
            .where(
                FastingSessionRow.user_id == user_id,
                FastingSessionRow.deleted_at.is_(None),
            )
            .scalar_subquery()
        )
        recognition_count = (
            select(func.count())
            .select_from(RecognitionJobRow)
            .where(RecognitionJobRow.user_id == user_id)
            .scalar_subquery()
        )
        recognition_item_count = (
            select(func.count())
            .select_from(RecognitionItemRow)
            .where(RecognitionItemRow.user_id == user_id)
            .scalar_subquery()
        )
        correction_count = (
            select(
                func.count()
                + func.coalesce(
                    func.sum(func.jsonb_array_length(RecognitionCorrectionRow.corrected_items)),
                    0,
                )
            )
            .select_from(RecognitionCorrectionRow)
            .where(RecognitionCorrectionRow.user_id == user_id)
            .scalar_subquery()
        )
        optional_count = (
            select(func.count())
            .select_from(HealthProfileRow)
            .where(HealthProfileRow.user_id == user_id)
            .scalar_subquery()
            + select(func.count())
            .select_from(UserPreferencesRow)
            .where(UserPreferencesRow.user_id == user_id)
            .scalar_subquery()
        )
        total = await session.scalar(
            select(
                literal(1)
                + optional_count
                + meal_count
                + meal_item_count
                + fasting_count
                + recognition_count
                + recognition_item_count
                + correction_count
            )
        )
        return int(total or 0)


class SqlAlchemyWorkerAccountCleanupRepository:
    def __init__(self, session_factory: sessionmaker[Session]) -> None:
        self._session_factory = session_factory

    def claim_cleanups(
        self,
        *,
        now: datetime,
        limit: int,
        lease_seconds: int,
    ) -> tuple[tuple[UUID, str], ...]:
        stale_before = now - timedelta(seconds=lease_seconds)
        with self._session_factory() as session, session.begin():
            active_recognition_source = exists().where(
                RecognitionUploadRow.sanitized_object_key == AccountObjectCleanupRow.object_key
            )
            rows = tuple(
                session.scalars(
                    select(AccountObjectCleanupRow)
                    .where(
                        AccountObjectCleanupRow.completed_at.is_(None),
                        AccountObjectCleanupRow.next_attempt_at <= now,
                        or_(
                            AccountObjectCleanupRow.claimed_at.is_(None),
                            AccountObjectCleanupRow.claimed_at < stale_before,
                        ),
                        ~active_recognition_source,
                    )
                    .order_by(
                        AccountObjectCleanupRow.next_attempt_at,
                        AccountObjectCleanupRow.queued_at,
                        AccountObjectCleanupRow.id,
                    )
                    .limit(limit)
                    .with_for_update(skip_locked=True)
                )
            )
            for row in rows:
                row.claimed_at = now
                row.attempt_count += 1
            return tuple((row.id, row.object_key) for row in rows)

    def mark_cleanup_succeeded(self, *, cleanup_id: UUID, now: datetime) -> None:
        with self._session_factory() as session, session.begin():
            row = session.get(AccountObjectCleanupRow, cleanup_id)
            if row is not None and row.completed_at is None:
                row.completed_at = now
                row.claimed_at = None

    def mark_cleanup_failed(self, *, cleanup_id: UUID, now: datetime) -> None:
        with self._session_factory() as session, session.begin():
            row = session.get(AccountObjectCleanupRow, cleanup_id)
            if row is not None and row.completed_at is None:
                delay_seconds = min(60 * 60, 30 * (2 ** min(row.attempt_count, 7)))
                row.next_attempt_at = now + timedelta(seconds=delay_seconds)
                row.claimed_at = None


def _user(row: UserRow) -> User:
    return User(
        id=row.id,
        nickname=row.nickname,
        status=UserStatus(row.status),
        version=row.version,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


def _health_profile(row: HealthProfileRow) -> HealthProfile:
    return HealthProfile(
        user_id=row.user_id,
        birth_date=row.birth_date,
        height_cm=row.height_cm,
        current_weight_kg=row.current_weight_kg,
        target_weight_kg=row.target_weight_kg,
        goal_type=GoalType(row.goal_type) if row.goal_type is not None else None,
        daily_energy_target_kcal=row.daily_energy_target_kcal,
        version=row.version,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


def _preferences(row: UserPreferencesRow) -> UserPreferences:
    return UserPreferences(
        user_id=row.user_id,
        daily_energy_target_kcal=row.daily_energy_target_kcal,
        selected_fasting_plan=FastingPlan(row.selected_fasting_plan),
        fasting_reminder_enabled=row.fasting_reminder_enabled,
        version=row.version,
        change_cursor=row.change_cursor,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


def _meal(row: MealLogRow, items: list[MealItemRow]) -> MealLog:
    return MealLog(
        id=row.id,
        user_id=row.user_id,
        type=MealType(row.meal_type),
        source=MealSource(row.source),
        occurred_at=row.occurred_at,
        time_zone_id=row.time_zone_id,
        local_day=row.local_day,
        is_within_eating_window=row.is_within_eating_window,
        items=tuple(
            MealItemInput(
                id=item.id,
                name=item.name,
                serving_milli=item.serving_milli,
                energy_kcal=item.energy_kcal,
                protein_mg=item.protein_mg,
                carbs_mg=item.carbs_mg,
                fat_mg=item.fat_mg,
                image_reference=None,
            )
            for item in items
        ),
        version=row.version,
        change_cursor=row.change_cursor,
        deleted_at=None,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


def _fasting(row: FastingSessionRow) -> FastingSession:
    return FastingSession(
        id=row.id,
        user_id=row.user_id,
        plan=FastingPlan(row.plan),
        status=FastingSessionStatus(row.status),
        started_at=row.started_at,
        target_end_at=row.target_end_at,
        ended_at=row.ended_at,
        time_zone_id=row.time_zone_id,
        started_local_day=row.started_local_day,
        target_end_local_day=row.target_end_local_day,
        ended_local_day=row.ended_local_day,
        version=row.version,
        change_cursor=row.change_cursor,
        deleted_at=None,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


def _recognition(
    row: RecognitionJobRow,
    items: list[RecognitionItemRow],
    corrections: list[RecognitionCorrectionRow],
) -> AccountRecognitionResult:
    return AccountRecognitionResult(
        id=row.id,
        status=row.status,
        overall_confidence_milli=row.overall_confidence_milli,
        needs_review_reason=row.needs_review_reason,
        error_code=row.error_code,
        version=row.version,
        created_at=row.created_at,
        updated_at=row.updated_at,
        completed_at=row.completed_at,
        items=tuple(_recognition_item(item) for item in items),
        corrections=tuple(_recognition_correction(correction) for correction in corrections),
    )


def _recognition_item(row: RecognitionItemRow) -> RecognitionItem:
    alternatives = tuple(
        RecognitionAlternative(
            name=str(item["name"]),
            confidence_milli=int(item["confidenceMilli"]),
        )
        for item in row.alternatives
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


def _recognition_correction(row: RecognitionCorrectionRow) -> AccountRecognitionCorrection:
    return AccountRecognitionCorrection(
        id=row.id,
        base_version=row.base_version,
        created_at=row.created_at,
        items=tuple(_correction_item(item) for item in row.corrected_items),
    )


def _correction_item(value: dict[str, Any]) -> AccountRecognitionCorrectionItem:
    return AccountRecognitionCorrectionItem(
        id=UUID(str(value["id"])),
        position=int(value["position"]),
        name=str(value["name"]),
        canonical_food_id=(
            str(value["canonicalFoodId"]) if value.get("canonicalFoodId") is not None else None
        ),
        serving_milli=int(value["servingMilli"]),
        energy_kcal=int(value["energyKcal"]),
        protein_mg=int(value["proteinMg"]),
        carbs_mg=int(value["carbsMg"]),
        fat_mg=int(value["fatMg"]),
    )
