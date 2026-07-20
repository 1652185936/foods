from uuid import UUID

from ordin.core.clock import Clock
from ordin.core.errors import ResourceNotFoundError, VersionConflictError
from ordin.modules.ports import ApplicationRepository
from ordin.modules.users.models import (
    HealthProfile,
    HealthProfileInput,
    User,
    VersionedWriteStatus,
)


class UsersService:
    def __init__(self, *, repository: ApplicationRepository, clock: Clock) -> None:
        self._repository = repository
        self._clock = clock

    async def get_user(self, user_id: UUID) -> User:
        user = await self._repository.get_user(user_id)
        if user is None:
            raise ResourceNotFoundError
        return user

    async def update_nickname(
        self,
        *,
        user_id: UUID,
        expected_version: int,
        nickname: str,
    ) -> User:
        result = await self._repository.update_user_nickname(
            user_id=user_id,
            expected_version=expected_version,
            nickname=nickname,
            now=self._clock.now(),
        )
        if result.status is VersionedWriteStatus.CONFLICT:
            raise VersionConflictError
        if result.status is VersionedWriteStatus.NOT_FOUND or result.user is None:
            raise ResourceNotFoundError
        return result.user

    async def get_health_profile(self, user_id: UUID) -> HealthProfile:
        profile = await self._repository.get_health_profile(user_id)
        if profile is None:
            raise ResourceNotFoundError
        return profile

    async def put_health_profile(
        self,
        *,
        user_id: UUID,
        expected_version: int,
        profile: HealthProfileInput,
    ) -> HealthProfile:
        result = await self._repository.put_health_profile(
            user_id=user_id,
            expected_version=expected_version,
            profile=profile,
            now=self._clock.now(),
        )
        if result.status is VersionedWriteStatus.CONFLICT:
            raise VersionConflictError
        if result.status is VersionedWriteStatus.NOT_FOUND or result.profile is None:
            raise ResourceNotFoundError
        return result.profile
