import logging
from uuid import UUID

from ordin.core.clock import Clock
from ordin.core.errors import InvalidAuthenticationError, ResourceNotFoundError
from ordin.core.identifiers import new_uuid
from ordin.modules.accounts.models import AccountDataSnapshot
from ordin.modules.accounts.ports import AccountRepository
from ordin.modules.ports import TokenProvider
from ordin.modules.recognition.errors import ObjectNotFoundError
from ordin.modules.recognition.ports import ObjectStorage

logger = logging.getLogger(__name__)


class AccountsService:
    def __init__(
        self,
        *,
        repository: AccountRepository,
        storage: ObjectStorage,
        token_service: TokenProvider,
        clock: Clock,
        export_max_records: int,
        immediate_cleanup_limit: int = 20,
    ) -> None:
        self._repository = repository
        self._storage = storage
        self._token_service = token_service
        self._clock = clock
        self._export_max_records = export_max_records
        self._immediate_cleanup_limit = immediate_cleanup_limit

    async def export_data(self, *, user_id: UUID) -> AccountDataSnapshot:
        snapshot = await self._repository.export_snapshot(
            user_id=user_id,
            exported_at=self._clock.now(),
            max_records=self._export_max_records,
        )
        if snapshot is None:
            raise ResourceNotFoundError
        return snapshot

    async def delete_account(
        self,
        *,
        user_id: UUID,
        session_id: UUID,
        refresh_token: str,
        device_installation_id: UUID,
    ) -> None:
        now = self._clock.now()
        deleted = await self._repository.delete_account(
            user_id=user_id,
            session_id=session_id,
            refresh_token_hash=self._token_service.digest_refresh_token(refresh_token),
            device_installation_id=device_installation_id,
            cleanup_batch_id=new_uuid(),
            now=now,
            immediate_cleanup_limit=self._immediate_cleanup_limit,
        )
        if deleted is None:
            raise InvalidAuthenticationError

        failed = 0
        for cleanup in deleted.immediate_cleanups:
            succeeded = False
            try:
                await self._storage.delete(cleanup.object_key)
                succeeded = True
            except ObjectNotFoundError:
                succeeded = True
            except Exception:
                failed += 1
            try:
                if succeeded:
                    await self._repository.mark_cleanup_succeeded(
                        cleanup_id=cleanup.id,
                        now=self._clock.now(),
                    )
                else:
                    await self._repository.mark_cleanup_failed(
                        cleanup_id=cleanup.id,
                        now=self._clock.now(),
                    )
            except Exception:
                failed += 1
        if failed:
            logger.warning(
                "Deferred cleanup remains after account deletion",
                extra={"cleanup_failure_count": failed},
            )
