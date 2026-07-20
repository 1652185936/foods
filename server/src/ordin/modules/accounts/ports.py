from datetime import datetime
from typing import Protocol
from uuid import UUID

from ordin.modules.accounts.models import AccountDataSnapshot, AccountDeletion


class AccountRepository(Protocol):
    async def export_snapshot(
        self,
        *,
        user_id: UUID,
        exported_at: datetime,
        max_records: int,
    ) -> AccountDataSnapshot | None: ...

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
    ) -> AccountDeletion | None: ...

    async def mark_cleanup_succeeded(self, *, cleanup_id: UUID, now: datetime) -> None: ...

    async def mark_cleanup_failed(self, *, cleanup_id: UUID, now: datetime) -> None: ...


class WorkerAccountCleanupRepository(Protocol):
    def claim_cleanups(
        self,
        *,
        now: datetime,
        limit: int,
        lease_seconds: int,
    ) -> tuple[tuple[UUID, str], ...]: ...

    def mark_cleanup_succeeded(self, *, cleanup_id: UUID, now: datetime) -> None: ...

    def mark_cleanup_failed(self, *, cleanup_id: UUID, now: datetime) -> None: ...
