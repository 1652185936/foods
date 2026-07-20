from datetime import date, datetime
from typing import Protocol
from uuid import UUID

from ordin.modules.records.models import (
    FastingSession,
    FastingSessionStatus,
    MealLog,
    SyncOperation,
    SyncPage,
    SyncWriteResult,
    UserPreferences,
)


class RecordsRepository(Protocol):
    async def apply_sync_operation(
        self,
        *,
        user_id: UUID,
        operation: SyncOperation,
        request_hash: str,
        now: datetime,
    ) -> SyncWriteResult: ...

    async def pull_sync_changes(
        self,
        *,
        user_id: UUID,
        after_cursor: int,
        limit: int,
    ) -> SyncPage: ...

    async def get_meal(
        self,
        *,
        user_id: UUID,
        meal_id: UUID,
    ) -> MealLog | None: ...

    async def list_meals(
        self,
        *,
        user_id: UUID,
        local_day: date | None,
        limit: int,
    ) -> tuple[MealLog, ...]: ...

    async def get_fasting_session(
        self,
        *,
        user_id: UUID,
        fasting_session_id: UUID,
    ) -> FastingSession | None: ...

    async def list_fasting_sessions(
        self,
        *,
        user_id: UUID,
        status: FastingSessionStatus | None,
        limit: int,
    ) -> tuple[FastingSession, ...]: ...

    async def get_user_preferences(self, *, user_id: UUID) -> UserPreferences | None: ...
