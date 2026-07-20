from datetime import datetime
from typing import Protocol
from uuid import UUID

from ordin.modules.auth.models import (
    AccessClaims,
    AuthenticatedSession,
    DeviceRegistration,
    OtpChallenge,
    OtpVerification,
    RefreshRotation,
)
from ordin.modules.users.models import (
    HealthProfile,
    HealthProfileInput,
    HealthProfileWriteResult,
    User,
    UserWriteResult,
)


class OtpSender(Protocol):
    async def send(self, phone_number: str, code: str, expires_at: datetime) -> None: ...


class OtpCodeGenerator(Protocol):
    def generate(self) -> str: ...


class TokenProvider(Protocol):
    @property
    def refresh_ttl_seconds(self) -> int: ...

    def issue_access_token(
        self,
        *,
        user_id: UUID,
        session_id: UUID,
        now: datetime,
    ) -> tuple[str, datetime]: ...

    def decode_access_token(self, encoded_token: str, *, now: datetime) -> AccessClaims: ...

    def generate_refresh_token(self) -> str: ...

    def digest_refresh_token(self, token: str) -> str: ...


class OtpChallengeStore(Protocol):
    async def find_idempotent(
        self,
        key_digest: str,
        now: datetime,
    ) -> OtpChallenge | None: ...

    async def create(
        self,
        challenge: OtpChallenge,
        idempotency_key_digest: str | None,
    ) -> tuple[OtpChallenge, bool]: ...

    async def verify(
        self,
        challenge_id: UUID,
        code_digest: str,
        now: datetime,
    ) -> OtpVerification: ...

    async def delete(self, challenge_id: UUID, idempotency_key_digest: str | None) -> None: ...

    async def ping(self) -> None: ...


class RateLimiter(Protocol):
    async def hit(
        self,
        key: str,
        *,
        limit: int,
        window_seconds: int,
    ) -> int | None: ...

    async def ping(self) -> None: ...


class ApplicationRepository(Protocol):
    async def create_authenticated_session(
        self,
        *,
        identity_subject_hash: str,
        device: DeviceRegistration,
        session_id: UUID,
        token_family_id: UUID,
        refresh_token_hash: str,
        refresh_expires_at: datetime,
        now: datetime,
    ) -> tuple[User, AuthenticatedSession]: ...

    async def rotate_refresh_session(
        self,
        *,
        current_refresh_token_hash: str,
        device_installation_id: UUID,
        new_session_id: UUID,
        new_refresh_token_hash: str,
        new_refresh_expires_at: datetime,
        now: datetime,
    ) -> RefreshRotation: ...

    async def revoke_session(self, *, user_id: UUID, session_id: UUID, now: datetime) -> None: ...

    async def get_authenticated_user(
        self,
        *,
        user_id: UUID,
        session_id: UUID,
        now: datetime,
    ) -> User | None: ...

    async def get_user(self, user_id: UUID) -> User | None: ...

    async def update_user_nickname(
        self,
        *,
        user_id: UUID,
        expected_version: int,
        nickname: str,
        now: datetime,
    ) -> UserWriteResult: ...

    async def get_health_profile(self, user_id: UUID) -> HealthProfile | None: ...

    async def put_health_profile(
        self,
        *,
        user_id: UUID,
        expected_version: int,
        profile: HealthProfileInput,
        now: datetime,
    ) -> HealthProfileWriteResult: ...

    async def ping(self) -> None: ...
