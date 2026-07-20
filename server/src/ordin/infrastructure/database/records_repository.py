import hashlib
from collections import defaultdict
from datetime import date, datetime
from uuid import UUID

from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from ordin.infrastructure.database.models import (
    FastingSessionRow,
    MealItemRow,
    MealLogRow,
    SyncOperationRow,
    UserPreferencesRow,
    sync_revision_sequence,
)
from ordin.modules.records.models import (
    FastingPlan,
    FastingSession,
    FastingSessionStatus,
    MealItemInput,
    MealLog,
    MealSource,
    MealType,
    SyncAction,
    SyncChange,
    SyncEntityType,
    SyncOperation,
    SyncPage,
    SyncWriteResult,
    SyncWriteStatus,
    UserPreferences,
)


class SqlAlchemyRecordsRepository:
    def __init__(self, session_factory: async_sessionmaker[AsyncSession]) -> None:
        self._session_factory = session_factory

    async def apply_sync_operation(
        self,
        *,
        user_id: UUID,
        operation: SyncOperation,
        request_hash: str,
        now: datetime,
    ) -> SyncWriteResult:
        async with self._session_factory() as session, session.begin():
            await self._advisory_lock(session, f"operation:{user_id}:{operation.operation_id}")
            receipt = await session.scalar(
                select(SyncOperationRow)
                .where(
                    SyncOperationRow.user_id == user_id,
                    SyncOperationRow.operation_id == operation.operation_id,
                )
                .with_for_update()
            )
            if receipt is not None:
                if receipt.request_hash != request_hash:
                    return self._result(
                        operation,
                        status=SyncWriteStatus.IDEMPOTENCY_CONFLICT,
                    )
                return SyncWriteResult(
                    operation_id=receipt.operation_id,
                    entity_type=SyncEntityType(receipt.entity_type),
                    entity_id=receipt.entity_id,
                    status=SyncWriteStatus(receipt.result_status),
                    replayed=True,
                    current_version=receipt.current_version,
                    change_cursor=receipt.change_cursor,
                )

            if operation.entity_type is SyncEntityType.FASTING_SESSION:
                await self._advisory_lock(session, f"active-fasting:{user_id}")
            await self._advisory_lock(
                session,
                f"entity:{user_id}:{operation.entity_type.value}:{operation.entity_id}",
            )
            if operation.entity_type is SyncEntityType.MEAL_LOG:
                result = await self._apply_meal(session, user_id, operation, now)
            elif operation.entity_type is SyncEntityType.FASTING_SESSION:
                result = await self._apply_fasting(session, user_id, operation, now)
            else:
                result = await self._apply_preferences(session, user_id, operation, now)
            session.add(
                SyncOperationRow(
                    user_id=user_id,
                    operation_id=operation.operation_id,
                    entity_type=operation.entity_type.value,
                    entity_id=operation.entity_id,
                    action=operation.action.value,
                    payload_version=operation.payload_version,
                    request_hash=request_hash,
                    result_status=result.status.value,
                    current_version=result.current_version,
                    change_cursor=result.change_cursor,
                    created_at=now,
                )
            )
            await session.flush()
            return result

    async def pull_sync_changes(
        self,
        *,
        user_id: UUID,
        after_cursor: int,
        limit: int,
    ) -> SyncPage:
        async with self._session_factory() as session:
            fetch_limit = limit + 1
            meal_rows = list(
                await session.scalars(
                    select(MealLogRow)
                    .where(
                        MealLogRow.user_id == user_id,
                        MealLogRow.change_cursor > after_cursor,
                    )
                    .order_by(MealLogRow.change_cursor)
                    .limit(fetch_limit)
                )
            )
            fasting_rows = list(
                await session.scalars(
                    select(FastingSessionRow)
                    .where(
                        FastingSessionRow.user_id == user_id,
                        FastingSessionRow.change_cursor > after_cursor,
                    )
                    .order_by(FastingSessionRow.change_cursor)
                    .limit(fetch_limit)
                )
            )
            preference_rows = list(
                await session.scalars(
                    select(UserPreferencesRow)
                    .where(
                        UserPreferencesRow.user_id == user_id,
                        UserPreferencesRow.change_cursor > after_cursor,
                    )
                    .limit(fetch_limit)
                )
            )
            candidates: list[
                tuple[int, SyncEntityType, MealLogRow | FastingSessionRow | UserPreferencesRow]
            ] = []
            candidates.extend(
                (row.change_cursor, SyncEntityType.MEAL_LOG, row) for row in meal_rows
            )
            candidates.extend(
                (row.change_cursor, SyncEntityType.FASTING_SESSION, row) for row in fasting_rows
            )
            candidates.extend(
                (row.change_cursor, SyncEntityType.APP_PREFERENCES, row) for row in preference_rows
            )
            candidates.sort(key=lambda entry: entry[0])
            has_more = len(candidates) > limit
            selected = candidates[:limit]
            selected_meal_ids = [
                row.id
                for _, entity_type, row in selected
                if entity_type is SyncEntityType.MEAL_LOG
                and isinstance(row, MealLogRow)
                and row.deleted_at is None
            ]
            items_by_meal = await self._load_items(session, user_id, selected_meal_ids)
            changes: list[SyncChange] = []
            for _, entity_type, row in selected:
                if entity_type is SyncEntityType.MEAL_LOG:
                    assert isinstance(row, MealLogRow)
                    meal = (
                        self._to_meal(row, items_by_meal.get(row.id, ()))
                        if row.deleted_at is None
                        else None
                    )
                    changes.append(
                        SyncChange(
                            entity_type=entity_type,
                            entity_id=str(row.id),
                            version=row.version,
                            change_cursor=row.change_cursor,
                            deleted_at=row.deleted_at,
                            meal=meal,
                        )
                    )
                elif entity_type is SyncEntityType.FASTING_SESSION:
                    assert isinstance(row, FastingSessionRow)
                    changes.append(
                        SyncChange(
                            entity_type=entity_type,
                            entity_id=str(row.id),
                            version=row.version,
                            change_cursor=row.change_cursor,
                            deleted_at=row.deleted_at,
                            fasting_session=(
                                self._to_fasting(row) if row.deleted_at is None else None
                            ),
                        )
                    )
                else:
                    assert isinstance(row, UserPreferencesRow)
                    changes.append(
                        SyncChange(
                            entity_type=entity_type,
                            entity_id="current",
                            version=row.version,
                            change_cursor=row.change_cursor,
                            deleted_at=None,
                            app_preferences=self._to_preferences(row),
                        )
                    )
            return SyncPage(
                changes=tuple(changes),
                next_cursor=changes[-1].change_cursor if changes else after_cursor,
                has_more=has_more,
            )

    async def get_meal(self, *, user_id: UUID, meal_id: UUID) -> MealLog | None:
        async with self._session_factory() as session:
            row = await session.scalar(
                select(MealLogRow).where(
                    MealLogRow.user_id == user_id,
                    MealLogRow.id == meal_id,
                    MealLogRow.deleted_at.is_(None),
                )
            )
            if row is None:
                return None
            items = await self._load_items(session, user_id, [meal_id])
            return self._to_meal(row, items.get(meal_id, ()))

    async def list_meals(
        self,
        *,
        user_id: UUID,
        local_day: date | None,
        limit: int,
    ) -> tuple[MealLog, ...]:
        async with self._session_factory() as session:
            statement = select(MealLogRow).where(
                MealLogRow.user_id == user_id,
                MealLogRow.deleted_at.is_(None),
            )
            if local_day is not None:
                statement = statement.where(MealLogRow.local_day == local_day)
            rows = list(
                await session.scalars(
                    statement.order_by(MealLogRow.occurred_at.desc(), MealLogRow.id.desc()).limit(
                        limit
                    )
                )
            )
            items = await self._load_items(session, user_id, [row.id for row in rows])
            return tuple(self._to_meal(row, items.get(row.id, ())) for row in rows)

    async def get_fasting_session(
        self,
        *,
        user_id: UUID,
        fasting_session_id: UUID,
    ) -> FastingSession | None:
        async with self._session_factory() as session:
            row = await session.scalar(
                select(FastingSessionRow).where(
                    FastingSessionRow.user_id == user_id,
                    FastingSessionRow.id == fasting_session_id,
                    FastingSessionRow.deleted_at.is_(None),
                )
            )
            return self._to_fasting(row) if row is not None else None

    async def list_fasting_sessions(
        self,
        *,
        user_id: UUID,
        status: FastingSessionStatus | None,
        limit: int,
    ) -> tuple[FastingSession, ...]:
        async with self._session_factory() as session:
            statement = select(FastingSessionRow).where(
                FastingSessionRow.user_id == user_id,
                FastingSessionRow.deleted_at.is_(None),
            )
            if status is not None:
                statement = statement.where(FastingSessionRow.status == status.value)
            rows = await session.scalars(
                statement.order_by(
                    FastingSessionRow.started_at.desc(),
                    FastingSessionRow.id.desc(),
                ).limit(limit)
            )
            return tuple(self._to_fasting(row) for row in rows)

    async def get_user_preferences(self, *, user_id: UUID) -> UserPreferences | None:
        async with self._session_factory() as session:
            row = await session.get(UserPreferencesRow, user_id)
            return self._to_preferences(row) if row is not None else None

    async def _apply_meal(
        self,
        session: AsyncSession,
        user_id: UUID,
        operation: SyncOperation,
        now: datetime,
    ) -> SyncWriteResult:
        entity_id = UUID(operation.entity_id)
        row = await session.scalar(
            select(MealLogRow)
            .where(MealLogRow.user_id == user_id, MealLogRow.id == entity_id)
            .with_for_update()
        )
        if operation.action is SyncAction.DELETE:
            if row is None:
                return self._result(operation, status=SyncWriteStatus.NOT_FOUND)
            if row.deleted_at is not None:
                return self._result(
                    operation,
                    status=SyncWriteStatus.APPLIED,
                    current_version=row.version,
                    change_cursor=row.change_cursor,
                )
            if row.version != operation.expected_version:
                return self._conflict(operation, row.version, row.change_cursor)
            row.version += 1
            row.change_cursor = await self._next_change_cursor(session)
            row.deleted_at = now
            row.updated_at = now
            return self._result(
                operation,
                status=SyncWriteStatus.APPLIED,
                current_version=row.version,
                change_cursor=row.change_cursor,
            )

        payload = operation.meal
        assert payload is not None
        if row is None:
            if operation.expected_version != 0:
                return self._result(operation, status=SyncWriteStatus.NOT_FOUND)
            cursor = await self._next_change_cursor(session)
            row = MealLogRow(
                user_id=user_id,
                id=entity_id,
                meal_type=payload.type.value,
                source=payload.source.value,
                occurred_at=payload.occurred_at,
                time_zone_id=payload.time_zone_id,
                local_day=payload.local_day,
                is_within_eating_window=payload.is_within_eating_window,
                version=1,
                change_cursor=cursor,
                deleted_at=None,
                created_at=now,
                updated_at=now,
            )
            session.add(row)
            await session.flush()
            self._add_meal_items(session, user_id, entity_id, payload.items, now)
            return self._result(
                operation,
                status=SyncWriteStatus.APPLIED,
                current_version=1,
                change_cursor=cursor,
            )
        if row.deleted_at is not None or row.version != operation.expected_version:
            return self._conflict(operation, row.version, row.change_cursor)
        row.meal_type = payload.type.value
        row.source = payload.source.value
        row.occurred_at = payload.occurred_at
        row.time_zone_id = payload.time_zone_id
        row.local_day = payload.local_day
        row.is_within_eating_window = payload.is_within_eating_window
        row.version += 1
        row.change_cursor = await self._next_change_cursor(session)
        row.updated_at = now
        await session.execute(
            delete(MealItemRow).where(
                MealItemRow.user_id == user_id,
                MealItemRow.meal_log_id == entity_id,
            )
        )
        self._add_meal_items(session, user_id, entity_id, payload.items, now)
        return self._result(
            operation,
            status=SyncWriteStatus.APPLIED,
            current_version=row.version,
            change_cursor=row.change_cursor,
        )

    async def _apply_fasting(
        self,
        session: AsyncSession,
        user_id: UUID,
        operation: SyncOperation,
        now: datetime,
    ) -> SyncWriteResult:
        entity_id = UUID(operation.entity_id)
        row = await session.scalar(
            select(FastingSessionRow)
            .where(
                FastingSessionRow.user_id == user_id,
                FastingSessionRow.id == entity_id,
            )
            .with_for_update()
        )
        if operation.action is SyncAction.DELETE:
            if row is None:
                return self._result(operation, status=SyncWriteStatus.NOT_FOUND)
            if row.deleted_at is not None:
                return self._result(
                    operation,
                    status=SyncWriteStatus.APPLIED,
                    current_version=row.version,
                    change_cursor=row.change_cursor,
                )
            if row.version != operation.expected_version:
                return self._conflict(operation, row.version, row.change_cursor)
            row.version += 1
            row.change_cursor = await self._next_change_cursor(session)
            row.deleted_at = now
            row.updated_at = now
            return self._result(
                operation,
                status=SyncWriteStatus.APPLIED,
                current_version=row.version,
                change_cursor=row.change_cursor,
            )

        payload = operation.fasting_session
        assert payload is not None
        if row is None and operation.expected_version != 0:
            return self._result(operation, status=SyncWriteStatus.NOT_FOUND)
        if row is not None and (
            row.deleted_at is not None or row.version != operation.expected_version
        ):
            return self._conflict(operation, row.version, row.change_cursor)
        if payload.status is FastingSessionStatus.ACTIVE:
            active = await session.scalar(
                select(FastingSessionRow).where(
                    FastingSessionRow.user_id == user_id,
                    FastingSessionRow.id != entity_id,
                    FastingSessionRow.status == FastingSessionStatus.ACTIVE.value,
                    FastingSessionRow.deleted_at.is_(None),
                )
            )
            if active is not None:
                return self._result(
                    operation,
                    status=SyncWriteStatus.ACTIVE_FASTING_CONFLICT,
                )
        cursor = await self._next_change_cursor(session)
        if row is None:
            row = FastingSessionRow(
                user_id=user_id,
                id=entity_id,
                plan=payload.plan.value,
                status=payload.status.value,
                started_at=payload.started_at,
                target_end_at=payload.target_end_at,
                ended_at=payload.ended_at,
                time_zone_id=payload.time_zone_id,
                started_local_day=payload.started_local_day,
                target_end_local_day=payload.target_end_local_day,
                ended_local_day=payload.ended_local_day,
                version=1,
                change_cursor=cursor,
                deleted_at=None,
                created_at=now,
                updated_at=now,
            )
            session.add(row)
        else:
            row.plan = payload.plan.value
            row.status = payload.status.value
            row.started_at = payload.started_at
            row.target_end_at = payload.target_end_at
            row.ended_at = payload.ended_at
            row.time_zone_id = payload.time_zone_id
            row.started_local_day = payload.started_local_day
            row.target_end_local_day = payload.target_end_local_day
            row.ended_local_day = payload.ended_local_day
            row.version += 1
            row.change_cursor = cursor
            row.updated_at = now
        return self._result(
            operation,
            status=SyncWriteStatus.APPLIED,
            current_version=row.version,
            change_cursor=cursor,
        )

    async def _apply_preferences(
        self,
        session: AsyncSession,
        user_id: UUID,
        operation: SyncOperation,
        now: datetime,
    ) -> SyncWriteResult:
        payload = operation.app_preferences
        assert payload is not None
        row = await session.scalar(
            select(UserPreferencesRow)
            .where(UserPreferencesRow.user_id == user_id)
            .with_for_update()
        )
        if row is None:
            if operation.expected_version != 0:
                return self._result(operation, status=SyncWriteStatus.NOT_FOUND)
            cursor = await self._next_change_cursor(session)
            row = UserPreferencesRow(
                user_id=user_id,
                daily_energy_target_kcal=payload.daily_energy_target_kcal,
                selected_fasting_plan=payload.selected_fasting_plan.value,
                fasting_reminder_enabled=payload.fasting_reminder_enabled,
                version=1,
                change_cursor=cursor,
                created_at=now,
                updated_at=now,
            )
            session.add(row)
        else:
            if row.version != operation.expected_version:
                return self._conflict(operation, row.version, row.change_cursor)
            cursor = await self._next_change_cursor(session)
            row.daily_energy_target_kcal = payload.daily_energy_target_kcal
            row.selected_fasting_plan = payload.selected_fasting_plan.value
            row.fasting_reminder_enabled = payload.fasting_reminder_enabled
            row.version += 1
            row.change_cursor = cursor
            row.updated_at = now
        return self._result(
            operation,
            status=SyncWriteStatus.APPLIED,
            current_version=row.version,
            change_cursor=cursor,
        )

    @staticmethod
    async def _advisory_lock(session: AsyncSession, value: str) -> None:
        key = int.from_bytes(hashlib.sha256(value.encode()).digest()[:8], "big", signed=True)
        await session.execute(select(func.pg_advisory_xact_lock(key)))

    @staticmethod
    async def _next_change_cursor(session: AsyncSession) -> int:
        value = await session.scalar(select(sync_revision_sequence.next_value()))
        if not isinstance(value, int):
            raise RuntimeError("PostgreSQL did not return a synchronization cursor")
        return value

    @staticmethod
    def _add_meal_items(
        session: AsyncSession,
        user_id: UUID,
        meal_id: UUID,
        items: tuple[MealItemInput, ...],
        now: datetime,
    ) -> None:
        session.add_all(
            MealItemRow(
                user_id=user_id,
                id=item.id,
                meal_log_id=meal_id,
                position=position,
                name=item.name,
                serving_milli=item.serving_milli,
                energy_kcal=item.energy_kcal,
                protein_mg=item.protein_mg,
                carbs_mg=item.carbs_mg,
                fat_mg=item.fat_mg,
                image_reference=item.image_reference,
                created_at=now,
                updated_at=now,
            )
            for position, item in enumerate(items)
        )

    @staticmethod
    async def _load_items(
        session: AsyncSession,
        user_id: UUID,
        meal_ids: list[UUID],
    ) -> dict[UUID, tuple[MealItemRow, ...]]:
        if not meal_ids:
            return {}
        rows = await session.scalars(
            select(MealItemRow)
            .where(
                MealItemRow.user_id == user_id,
                MealItemRow.meal_log_id.in_(meal_ids),
            )
            .order_by(MealItemRow.meal_log_id, MealItemRow.position)
        )
        grouped: defaultdict[UUID, list[MealItemRow]] = defaultdict(list)
        for row in rows:
            grouped[row.meal_log_id].append(row)
        return {meal_id: tuple(items) for meal_id, items in grouped.items()}

    @staticmethod
    def _to_meal(row: MealLogRow, items: tuple[MealItemRow, ...]) -> MealLog:
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
                    image_reference=item.image_reference,
                )
                for item in items
            ),
            version=row.version,
            change_cursor=row.change_cursor,
            deleted_at=row.deleted_at,
            created_at=row.created_at,
            updated_at=row.updated_at,
        )

    @staticmethod
    def _to_fasting(row: FastingSessionRow) -> FastingSession:
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
            deleted_at=row.deleted_at,
            created_at=row.created_at,
            updated_at=row.updated_at,
        )

    @staticmethod
    def _to_preferences(row: UserPreferencesRow) -> UserPreferences:
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

    @staticmethod
    def _result(
        operation: SyncOperation,
        *,
        status: SyncWriteStatus,
        current_version: int | None = None,
        change_cursor: int | None = None,
    ) -> SyncWriteResult:
        return SyncWriteResult(
            operation_id=operation.operation_id,
            entity_type=operation.entity_type,
            entity_id=operation.entity_id,
            status=status,
            replayed=False,
            current_version=current_version,
            change_cursor=change_cursor,
        )

    @classmethod
    def _conflict(
        cls,
        operation: SyncOperation,
        current_version: int,
        change_cursor: int,
    ) -> SyncWriteResult:
        return cls._result(
            operation,
            status=SyncWriteStatus.VERSION_CONFLICT,
            current_version=current_version,
            change_cursor=change_cursor,
        )
