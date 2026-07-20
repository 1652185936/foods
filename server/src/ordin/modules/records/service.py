import hashlib
import json
import re
from dataclasses import asdict
from datetime import UTC, date, datetime, timedelta
from enum import Enum
from typing import Any
from uuid import UUID
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from ordin.core.clock import Clock
from ordin.core.errors import InvalidSyncOperationError, ResourceNotFoundError
from ordin.modules.records.models import (
    FastingSession,
    FastingSessionStatus,
    MealLog,
    SyncAction,
    SyncEntityType,
    SyncOperation,
    SyncPage,
    SyncWriteResult,
    UserPreferences,
)
from ordin.modules.records.ports import RecordsRepository

_TIME_ZONE_PATTERN = re.compile(r"^(?:UTC|[A-Za-z_+-]+(?:/[A-Za-z0-9_+.-]+)+)$")
_OBJECT_KEY_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._/-]*$")


class RecordsService:
    def __init__(self, *, repository: RecordsRepository, clock: Clock) -> None:
        self._repository = repository
        self._clock = clock

    async def push(
        self,
        *,
        user_id: UUID,
        operations: tuple[SyncOperation, ...],
    ) -> tuple[SyncWriteResult, ...]:
        if not 1 <= len(operations) <= 100:
            raise InvalidSyncOperationError
        if len({operation.operation_id for operation in operations}) != len(operations):
            raise InvalidSyncOperationError
        now = self._clock.now()
        for operation in operations:
            self._validate_operation(operation, now=now)
        results: list[SyncWriteResult] = []
        for operation in operations:
            result = await self._repository.apply_sync_operation(
                user_id=user_id,
                operation=operation,
                request_hash=_operation_hash(user_id, operation),
                now=now,
            )
            results.append(result)
        return tuple(results)

    async def pull(
        self,
        *,
        user_id: UUID,
        after_cursor: int,
        limit: int,
    ) -> SyncPage:
        return await self._repository.pull_sync_changes(
            user_id=user_id,
            after_cursor=after_cursor,
            limit=limit,
        )

    async def get_meal(self, *, user_id: UUID, meal_id: UUID) -> MealLog:
        meal = await self._repository.get_meal(user_id=user_id, meal_id=meal_id)
        if meal is None:
            raise ResourceNotFoundError
        return meal

    async def list_meals(
        self,
        *,
        user_id: UUID,
        local_day: date | None,
        limit: int,
    ) -> tuple[MealLog, ...]:
        return await self._repository.list_meals(
            user_id=user_id,
            local_day=local_day,
            limit=limit,
        )

    async def get_fasting_session(
        self,
        *,
        user_id: UUID,
        fasting_session_id: UUID,
    ) -> FastingSession:
        session = await self._repository.get_fasting_session(
            user_id=user_id,
            fasting_session_id=fasting_session_id,
        )
        if session is None:
            raise ResourceNotFoundError
        return session

    async def list_fasting_sessions(
        self,
        *,
        user_id: UUID,
        status: FastingSessionStatus | None,
        limit: int,
    ) -> tuple[FastingSession, ...]:
        return await self._repository.list_fasting_sessions(
            user_id=user_id,
            status=status,
            limit=limit,
        )

    async def get_user_preferences(self, *, user_id: UUID) -> UserPreferences:
        preferences = await self._repository.get_user_preferences(user_id=user_id)
        if preferences is None:
            raise ResourceNotFoundError
        return preferences

    @staticmethod
    def _validate_operation(operation: SyncOperation, *, now: datetime) -> None:
        if operation.payload_version != 1 or operation.expected_version < 0:
            raise InvalidSyncOperationError
        if operation.entity_type is SyncEntityType.APP_PREFERENCES:
            if operation.entity_id != "current" or operation.action is SyncAction.DELETE:
                raise InvalidSyncOperationError
            if (
                operation.app_preferences is None
                or operation.meal is not None
                or operation.fasting_session is not None
            ):
                raise InvalidSyncOperationError
            if not 1 <= operation.app_preferences.daily_energy_target_kcal <= 20_000:
                raise InvalidSyncOperationError
            return
        _require_uuid_entity_id(operation.entity_id)
        if operation.action is SyncAction.DELETE:
            if (
                operation.meal is not None
                or operation.fasting_session is not None
                or operation.app_preferences is not None
            ):
                raise InvalidSyncOperationError
            return
        if operation.entity_type is SyncEntityType.MEAL_LOG:
            if (
                operation.meal is None
                or operation.fasting_session is not None
                or operation.app_preferences is not None
            ):
                raise InvalidSyncOperationError
            if not 1 <= len(operation.meal.items) <= 50:
                raise InvalidSyncOperationError
            if len({item.id for item in operation.meal.items}) != len(operation.meal.items):
                raise InvalidSyncOperationError
            time_zone = _time_zone(operation.meal.time_zone_id)
            if time_zone is None:
                raise InvalidSyncOperationError
            if any(
                not item.name.strip()
                or len(item.name) > 120
                or not 1 <= item.serving_milli <= 10_000_000
                or not 0 <= item.energy_kcal <= 100_000
                or not 0 <= item.protein_mg <= 10_000_000
                or not 0 <= item.carbs_mg <= 10_000_000
                or not 0 <= item.fat_mg <= 10_000_000
                or (
                    item.image_reference is not None
                    and not _is_valid_object_key(item.image_reference)
                )
                for item in operation.meal.items
            ):
                raise InvalidSyncOperationError
            _require_utc(operation.meal.occurred_at)
            if operation.meal.local_day != operation.meal.occurred_at.astimezone(time_zone).date():
                raise InvalidSyncOperationError
            return
        if (
            operation.fasting_session is None
            or operation.meal is not None
            or operation.app_preferences is not None
        ):
            raise InvalidSyncOperationError
        payload = operation.fasting_session
        _require_utc(payload.started_at)
        _require_utc(payload.target_end_at)
        time_zone = _time_zone(payload.time_zone_id)
        if time_zone is None:
            raise InvalidSyncOperationError
        if payload.ended_at is not None:
            _require_utc(payload.ended_at)
        if payload.target_end_at <= payload.started_at:
            raise InvalidSyncOperationError
        expected_end = (
            payload.started_at.astimezone(UTC).timestamp() + payload.plan.fasting_hours * 3600
        )
        if abs(payload.target_end_at.astimezone(UTC).timestamp() - expected_end) > 1:
            raise InvalidSyncOperationError
        if payload.status is FastingSessionStatus.ACTIVE:
            if payload.ended_at is not None or payload.ended_local_day is not None:
                raise InvalidSyncOperationError
        elif (
            payload.ended_at is None
            or payload.ended_local_day is None
            or payload.ended_at < payload.started_at
            or payload.ended_at > now + timedelta(minutes=5)
        ):
            raise InvalidSyncOperationError
        if (
            payload.status is FastingSessionStatus.COMPLETED
            and payload.ended_at is not None
            and abs((payload.ended_at - payload.target_end_at).total_seconds()) > 1
        ):
            raise InvalidSyncOperationError
        if payload.started_local_day != payload.started_at.astimezone(time_zone).date():
            raise InvalidSyncOperationError
        if payload.target_end_local_day != payload.target_end_at.astimezone(time_zone).date():
            raise InvalidSyncOperationError
        if payload.ended_at is not None and (
            payload.ended_local_day != payload.ended_at.astimezone(time_zone).date()
        ):
            raise InvalidSyncOperationError


def _require_utc(value: datetime) -> None:
    if value.tzinfo is None or value.utcoffset() != timedelta(0):
        raise InvalidSyncOperationError


def _require_uuid_entity_id(value: str) -> None:
    try:
        parsed = UUID(value)
    except ValueError as error:
        raise InvalidSyncOperationError from error
    if str(parsed) != value:
        raise InvalidSyncOperationError


def _is_valid_object_key(value: str) -> bool:
    if (
        not 1 <= len(value) <= 512
        or value.startswith("/")
        or not _OBJECT_KEY_PATTERN.fullmatch(value)
    ):
        return False
    parts = value.split("/")
    return all(part not in {"", ".", ".."} for part in parts)


def _is_valid_time_zone_id(value: str) -> bool:
    return _time_zone(value) is not None


def _time_zone(value: str) -> ZoneInfo | None:
    if not 1 <= len(value) <= 64 or _TIME_ZONE_PATTERN.fullmatch(value) is None:
        return None
    try:
        return ZoneInfo(value)
    except ValueError, ZoneInfoNotFoundError:
        return None


def _operation_hash(user_id: UUID, operation: SyncOperation) -> str:
    encoded = json.dumps(
        {"userId": str(user_id), "operation": asdict(operation)},
        default=_json_default,
        ensure_ascii=True,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def _json_default(value: Any) -> str:
    if isinstance(value, datetime):
        return value.astimezone(UTC).isoformat()
    if isinstance(value, date):
        return value.isoformat()
    if isinstance(value, (UUID, Enum)):
        return str(value)
    raise TypeError(f"unsupported operation value: {type(value).__name__}")
