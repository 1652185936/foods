import asyncio
from dataclasses import dataclass, replace
from datetime import date, datetime
from uuid import UUID

from ordin.modules.records.models import (
    FastingSession,
    FastingSessionStatus,
    MealLog,
    SyncAction,
    SyncChange,
    SyncEntityType,
    SyncOperation,
    SyncPage,
    SyncWriteResult,
    SyncWriteStatus,
    UserPreferences,
)


@dataclass(frozen=True, slots=True)
class _MemoryReceipt:
    request_hash: str
    result: SyncWriteResult


class InMemoryRecordsRepository:
    def __init__(self) -> None:
        self._meals: dict[tuple[UUID, UUID], MealLog] = {}
        self._fasting_sessions: dict[tuple[UUID, UUID], FastingSession] = {}
        self._preferences: dict[UUID, UserPreferences] = {}
        self._receipts: dict[tuple[UUID, UUID], _MemoryReceipt] = {}
        self._next_cursor = 1
        self._lock = asyncio.Lock()

    async def apply_sync_operation(
        self,
        *,
        user_id: UUID,
        operation: SyncOperation,
        request_hash: str,
        now: datetime,
    ) -> SyncWriteResult:
        async with self._lock:
            receipt_key = (user_id, operation.operation_id)
            receipt = self._receipts.get(receipt_key)
            if receipt is not None:
                if receipt.request_hash != request_hash:
                    return self._result(
                        operation,
                        status=SyncWriteStatus.IDEMPOTENCY_CONFLICT,
                    )
                return replace(receipt.result, replayed=True)

            if operation.entity_type is SyncEntityType.MEAL_LOG:
                result = self._apply_meal(user_id=user_id, operation=operation, now=now)
            elif operation.entity_type is SyncEntityType.FASTING_SESSION:
                result = self._apply_fasting(user_id=user_id, operation=operation, now=now)
            else:
                result = self._apply_preferences(user_id=user_id, operation=operation, now=now)
            self._receipts[receipt_key] = _MemoryReceipt(request_hash, result)
            return result

    async def pull_sync_changes(
        self,
        *,
        user_id: UUID,
        after_cursor: int,
        limit: int,
    ) -> SyncPage:
        async with self._lock:
            changes = [
                self._meal_change(meal)
                for (owner_id, _), meal in self._meals.items()
                if owner_id == user_id and meal.change_cursor > after_cursor
            ]
            changes.extend(
                self._fasting_change(session)
                for (owner_id, _), session in self._fasting_sessions.items()
                if owner_id == user_id and session.change_cursor > after_cursor
            )
            preferences = self._preferences.get(user_id)
            if preferences is not None and preferences.change_cursor > after_cursor:
                changes.append(self._preferences_change(preferences))
            changes.sort(key=lambda change: change.change_cursor)
            selected = tuple(changes[:limit])
            return SyncPage(
                changes=selected,
                next_cursor=selected[-1].change_cursor if selected else after_cursor,
                has_more=len(changes) > limit,
            )

    async def get_meal(self, *, user_id: UUID, meal_id: UUID) -> MealLog | None:
        meal = self._meals.get((user_id, meal_id))
        return meal if meal is not None and meal.deleted_at is None else None

    async def list_meals(
        self,
        *,
        user_id: UUID,
        local_day: date | None,
        limit: int,
    ) -> tuple[MealLog, ...]:
        meals = [
            meal
            for (owner_id, _), meal in self._meals.items()
            if owner_id == user_id
            and meal.deleted_at is None
            and (local_day is None or meal.local_day == local_day)
        ]
        meals.sort(key=lambda meal: (meal.occurred_at, meal.id.int), reverse=True)
        return tuple(meals[:limit])

    async def get_fasting_session(
        self,
        *,
        user_id: UUID,
        fasting_session_id: UUID,
    ) -> FastingSession | None:
        session = self._fasting_sessions.get((user_id, fasting_session_id))
        return session if session is not None and session.deleted_at is None else None

    async def list_fasting_sessions(
        self,
        *,
        user_id: UUID,
        status: FastingSessionStatus | None,
        limit: int,
    ) -> tuple[FastingSession, ...]:
        sessions = [
            session
            for (owner_id, _), session in self._fasting_sessions.items()
            if owner_id == user_id
            and session.deleted_at is None
            and (status is None or session.status is status)
        ]
        sessions.sort(key=lambda session: (session.started_at, session.id.int), reverse=True)
        return tuple(sessions[:limit])

    async def get_user_preferences(self, *, user_id: UUID) -> UserPreferences | None:
        return self._preferences.get(user_id)

    def _apply_meal(
        self,
        *,
        user_id: UUID,
        operation: SyncOperation,
        now: datetime,
    ) -> SyncWriteResult:
        entity_id = UUID(operation.entity_id)
        key = (user_id, entity_id)
        current = self._meals.get(key)
        if operation.action is SyncAction.DELETE:
            if current is None:
                return self._result(operation, status=SyncWriteStatus.NOT_FOUND)
            if current.deleted_at is not None:
                return self._result(
                    operation,
                    status=SyncWriteStatus.APPLIED,
                    current_version=current.version,
                    change_cursor=current.change_cursor,
                )
            if current.version != operation.expected_version:
                return self._record_conflict(operation, current.version, current.change_cursor)
            cursor = self._take_cursor()
            deleted = replace(
                current,
                version=current.version + 1,
                change_cursor=cursor,
                deleted_at=now,
                updated_at=now,
            )
            self._meals[key] = deleted
            return self._result(
                operation,
                status=SyncWriteStatus.APPLIED,
                current_version=deleted.version,
                change_cursor=cursor,
            )

        payload = operation.meal
        assert payload is not None
        if current is None:
            if operation.expected_version != 0:
                return self._result(operation, status=SyncWriteStatus.NOT_FOUND)
            cursor = self._take_cursor()
            created = MealLog(
                id=entity_id,
                user_id=user_id,
                type=payload.type,
                source=payload.source,
                occurred_at=payload.occurred_at,
                time_zone_id=payload.time_zone_id,
                local_day=payload.local_day,
                is_within_eating_window=payload.is_within_eating_window,
                items=payload.items,
                version=1,
                change_cursor=cursor,
                deleted_at=None,
                created_at=now,
                updated_at=now,
            )
            self._meals[key] = created
            return self._result(
                operation,
                status=SyncWriteStatus.APPLIED,
                current_version=1,
                change_cursor=cursor,
            )
        if current.deleted_at is not None or current.version != operation.expected_version:
            return self._record_conflict(operation, current.version, current.change_cursor)
        cursor = self._take_cursor()
        updated = MealLog(
            id=current.id,
            user_id=current.user_id,
            type=payload.type,
            source=payload.source,
            occurred_at=payload.occurred_at,
            time_zone_id=payload.time_zone_id,
            local_day=payload.local_day,
            is_within_eating_window=payload.is_within_eating_window,
            items=payload.items,
            version=current.version + 1,
            change_cursor=cursor,
            deleted_at=None,
            created_at=current.created_at,
            updated_at=now,
        )
        self._meals[key] = updated
        return self._result(
            operation,
            status=SyncWriteStatus.APPLIED,
            current_version=updated.version,
            change_cursor=cursor,
        )

    def _apply_fasting(
        self,
        *,
        user_id: UUID,
        operation: SyncOperation,
        now: datetime,
    ) -> SyncWriteResult:
        entity_id = UUID(operation.entity_id)
        key = (user_id, entity_id)
        current = self._fasting_sessions.get(key)
        if operation.action is SyncAction.DELETE:
            if current is None:
                return self._result(operation, status=SyncWriteStatus.NOT_FOUND)
            if current.deleted_at is not None:
                return self._result(
                    operation,
                    status=SyncWriteStatus.APPLIED,
                    current_version=current.version,
                    change_cursor=current.change_cursor,
                )
            if current.version != operation.expected_version:
                return self._record_conflict(operation, current.version, current.change_cursor)
            cursor = self._take_cursor()
            deleted = replace(
                current,
                version=current.version + 1,
                change_cursor=cursor,
                deleted_at=now,
                updated_at=now,
            )
            self._fasting_sessions[key] = deleted
            return self._result(
                operation,
                status=SyncWriteStatus.APPLIED,
                current_version=deleted.version,
                change_cursor=cursor,
            )

        payload = operation.fasting_session
        assert payload is not None
        if current is None:
            if operation.expected_version != 0:
                return self._result(operation, status=SyncWriteStatus.NOT_FOUND)
            if payload.status is FastingSessionStatus.ACTIVE and self._has_other_active_fasting(
                user_id=user_id,
                entity_id=entity_id,
            ):
                return self._result(
                    operation,
                    status=SyncWriteStatus.ACTIVE_FASTING_CONFLICT,
                )
            cursor = self._take_cursor()
            created = FastingSession(
                id=entity_id,
                user_id=user_id,
                plan=payload.plan,
                status=payload.status,
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
            self._fasting_sessions[key] = created
            return self._result(
                operation,
                status=SyncWriteStatus.APPLIED,
                current_version=1,
                change_cursor=cursor,
            )
        if current.deleted_at is not None or current.version != operation.expected_version:
            return self._record_conflict(operation, current.version, current.change_cursor)
        if payload.status is FastingSessionStatus.ACTIVE and self._has_other_active_fasting(
            user_id=user_id,
            entity_id=entity_id,
        ):
            return self._result(
                operation,
                status=SyncWriteStatus.ACTIVE_FASTING_CONFLICT,
            )
        cursor = self._take_cursor()
        updated = FastingSession(
            id=current.id,
            user_id=current.user_id,
            plan=payload.plan,
            status=payload.status,
            started_at=payload.started_at,
            target_end_at=payload.target_end_at,
            ended_at=payload.ended_at,
            time_zone_id=payload.time_zone_id,
            started_local_day=payload.started_local_day,
            target_end_local_day=payload.target_end_local_day,
            ended_local_day=payload.ended_local_day,
            version=current.version + 1,
            change_cursor=cursor,
            deleted_at=None,
            created_at=current.created_at,
            updated_at=now,
        )
        self._fasting_sessions[key] = updated
        return self._result(
            operation,
            status=SyncWriteStatus.APPLIED,
            current_version=updated.version,
            change_cursor=cursor,
        )

    def _apply_preferences(
        self,
        *,
        user_id: UUID,
        operation: SyncOperation,
        now: datetime,
    ) -> SyncWriteResult:
        payload = operation.app_preferences
        assert payload is not None
        current = self._preferences.get(user_id)
        if current is None:
            if operation.expected_version != 0:
                return self._result(operation, status=SyncWriteStatus.NOT_FOUND)
            cursor = self._take_cursor()
            created = UserPreferences(
                user_id=user_id,
                daily_energy_target_kcal=payload.daily_energy_target_kcal,
                selected_fasting_plan=payload.selected_fasting_plan,
                fasting_reminder_enabled=payload.fasting_reminder_enabled,
                version=1,
                change_cursor=cursor,
                created_at=now,
                updated_at=now,
            )
            self._preferences[user_id] = created
            return self._result(
                operation,
                status=SyncWriteStatus.APPLIED,
                current_version=1,
                change_cursor=cursor,
            )
        if current.version != operation.expected_version:
            return self._record_conflict(operation, current.version, current.change_cursor)
        cursor = self._take_cursor()
        updated = UserPreferences(
            user_id=user_id,
            daily_energy_target_kcal=payload.daily_energy_target_kcal,
            selected_fasting_plan=payload.selected_fasting_plan,
            fasting_reminder_enabled=payload.fasting_reminder_enabled,
            version=current.version + 1,
            change_cursor=cursor,
            created_at=current.created_at,
            updated_at=now,
        )
        self._preferences[user_id] = updated
        return self._result(
            operation,
            status=SyncWriteStatus.APPLIED,
            current_version=updated.version,
            change_cursor=cursor,
        )

    def _has_other_active_fasting(self, *, user_id: UUID, entity_id: UUID) -> bool:
        return any(
            owner_id == user_id
            and current_id != entity_id
            and session.deleted_at is None
            and session.status is FastingSessionStatus.ACTIVE
            for (owner_id, current_id), session in self._fasting_sessions.items()
        )

    def _take_cursor(self) -> int:
        cursor = self._next_cursor
        self._next_cursor += 1
        return cursor

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
    def _record_conflict(
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

    @staticmethod
    def _meal_change(meal: MealLog) -> SyncChange:
        return SyncChange(
            entity_type=SyncEntityType.MEAL_LOG,
            entity_id=str(meal.id),
            version=meal.version,
            change_cursor=meal.change_cursor,
            deleted_at=meal.deleted_at,
            meal=meal if meal.deleted_at is None else None,
        )

    @staticmethod
    def _fasting_change(session: FastingSession) -> SyncChange:
        return SyncChange(
            entity_type=SyncEntityType.FASTING_SESSION,
            entity_id=str(session.id),
            version=session.version,
            change_cursor=session.change_cursor,
            deleted_at=session.deleted_at,
            fasting_session=session if session.deleted_at is None else None,
        )

    @staticmethod
    def _preferences_change(preferences: UserPreferences) -> SyncChange:
        return SyncChange(
            entity_type=SyncEntityType.APP_PREFERENCES,
            entity_id="current",
            version=preferences.version,
            change_cursor=preferences.change_cursor,
            deleted_at=None,
            app_preferences=preferences,
        )
