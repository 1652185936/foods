import asyncio
import hmac
import time
from dataclasses import dataclass, replace
from datetime import datetime
from uuid import UUID

from ordin.core.identifiers import new_uuid
from ordin.modules.auth.models import (
    AuthenticatedSession,
    DeviceRegistration,
    OtpChallenge,
    OtpVerification,
    OtpVerificationStatus,
    RefreshRotation,
    RefreshRotationStatus,
)
from ordin.modules.users.models import (
    HealthProfile,
    HealthProfileInput,
    HealthProfileWriteResult,
    User,
    UserStatus,
    UserWriteResult,
    VersionedWriteStatus,
)


class InMemoryOtpChallengeStore:
    def __init__(self) -> None:
        self._challenges: dict[UUID, OtpChallenge] = {}
        self._attempts: dict[UUID, int] = {}
        self._idempotency: dict[str, UUID] = {}
        self._challenge_idempotency: dict[UUID, str] = {}
        self._lock = asyncio.Lock()

    async def find_idempotent(
        self,
        key_digest: str,
        now: datetime,
    ) -> OtpChallenge | None:
        async with self._lock:
            challenge_id = self._idempotency.get(key_digest)
            challenge = self._challenges.get(challenge_id) if challenge_id else None
            if challenge is None or challenge.expires_at <= now:
                self._idempotency.pop(key_digest, None)
                return None
            return challenge

    async def create(
        self,
        challenge: OtpChallenge,
        idempotency_key_digest: str | None,
    ) -> tuple[OtpChallenge, bool]:
        async with self._lock:
            if idempotency_key_digest is not None:
                existing_id = self._idempotency.get(idempotency_key_digest)
                existing = self._challenges.get(existing_id) if existing_id else None
                if existing is not None:
                    return existing, False
                self._idempotency[idempotency_key_digest] = challenge.id
                self._challenge_idempotency[challenge.id] = idempotency_key_digest
            self._challenges[challenge.id] = challenge
            self._attempts[challenge.id] = 0
            return challenge, True

    async def verify(
        self,
        challenge_id: UUID,
        code_digest: str,
        now: datetime,
    ) -> OtpVerification:
        async with self._lock:
            challenge = self._challenges.get(challenge_id)
            if challenge is None:
                return OtpVerification(OtpVerificationStatus.INVALID)
            if challenge.expires_at <= now:
                self._remove(challenge_id)
                return OtpVerification(OtpVerificationStatus.EXPIRED)

            attempts = self._attempts.get(challenge_id, 0)
            if attempts >= challenge.max_attempts:
                self._remove(challenge_id)
                return OtpVerification(OtpVerificationStatus.ATTEMPTS_EXHAUSTED)
            if not hmac.compare_digest(challenge.code_digest, code_digest):
                attempts += 1
                self._attempts[challenge_id] = attempts
                if attempts >= challenge.max_attempts:
                    self._remove(challenge_id)
                    return OtpVerification(OtpVerificationStatus.ATTEMPTS_EXHAUSTED)
                return OtpVerification(OtpVerificationStatus.INVALID)

            self._remove(challenge_id)
            return OtpVerification(
                OtpVerificationStatus.VERIFIED,
                identity_subject_hash=challenge.identity_subject_hash,
            )

    async def delete(self, challenge_id: UUID, idempotency_key_digest: str | None) -> None:
        async with self._lock:
            self._remove(challenge_id)
            if idempotency_key_digest is not None:
                self._idempotency.pop(idempotency_key_digest, None)

    async def ping(self) -> None:
        return None

    def _remove(self, challenge_id: UUID) -> None:
        self._challenges.pop(challenge_id, None)
        self._attempts.pop(challenge_id, None)
        idempotency_key = self._challenge_idempotency.pop(challenge_id, None)
        if idempotency_key is not None:
            self._idempotency.pop(idempotency_key, None)


class InMemoryRateLimiter:
    def __init__(self) -> None:
        self._windows: dict[str, tuple[int, float]] = {}
        self._lock = asyncio.Lock()

    async def hit(self, key: str, *, limit: int, window_seconds: int) -> int | None:
        now = time.monotonic()
        async with self._lock:
            count, expires_at = self._windows.get(key, (0, now + window_seconds))
            if expires_at <= now:
                count, expires_at = 0, now + window_seconds
            count += 1
            self._windows[key] = (count, expires_at)
            if count > limit:
                return max(1, int(expires_at - now))
            return None

    async def ping(self) -> None:
        return None


@dataclass(slots=True)
class _MemorySession:
    id: UUID
    user_id: UUID
    device_installation_id: UUID
    family_id: UUID
    refresh_token_hash: str
    expires_at: datetime
    revoked_at: datetime | None = None
    replaced_by_session_id: UUID | None = None


class InMemoryApplicationRepository:
    def __init__(self) -> None:
        self._users: dict[UUID, User] = {}
        self._identity_users: dict[str, UUID] = {}
        self._sessions: dict[UUID, _MemorySession] = {}
        self._session_by_refresh_hash: dict[str, UUID] = {}
        self._health_profiles: dict[UUID, HealthProfile] = {}
        self._lock = asyncio.Lock()

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
    ) -> tuple[User, AuthenticatedSession]:
        async with self._lock:
            user_id = self._identity_users.get(identity_subject_hash)
            if user_id is None:
                user_id = new_uuid()
                user = User(
                    id=user_id,
                    nickname=None,
                    status=UserStatus.ACTIVE,
                    version=1,
                    created_at=now,
                    updated_at=now,
                )
                self._users[user_id] = user
                self._identity_users[identity_subject_hash] = user_id
            user = self._users[user_id]
            session = _MemorySession(
                id=session_id,
                user_id=user_id,
                device_installation_id=device.installation_id,
                family_id=token_family_id,
                refresh_token_hash=refresh_token_hash,
                expires_at=refresh_expires_at,
            )
            self._sessions[session_id] = session
            self._session_by_refresh_hash[refresh_token_hash] = session_id
            return user, AuthenticatedSession(user_id, session_id, refresh_expires_at)

    async def rotate_refresh_session(
        self,
        *,
        current_refresh_token_hash: str,
        device_installation_id: UUID,
        new_session_id: UUID,
        new_refresh_token_hash: str,
        new_refresh_expires_at: datetime,
        now: datetime,
    ) -> RefreshRotation:
        async with self._lock:
            current_id = self._session_by_refresh_hash.get(current_refresh_token_hash)
            current = self._sessions.get(current_id) if current_id else None
            if current is None:
                return RefreshRotation(RefreshRotationStatus.INVALID)
            if current.revoked_at is not None or current.replaced_by_session_id is not None:
                for session in self._sessions.values():
                    if session.family_id == current.family_id and session.revoked_at is None:
                        session.revoked_at = now
                return RefreshRotation(RefreshRotationStatus.REUSED)
            if (
                current.expires_at <= now
                or current.device_installation_id != device_installation_id
            ):
                if current.expires_at <= now:
                    current.revoked_at = now
                return RefreshRotation(RefreshRotationStatus.INVALID)

            current.revoked_at = now
            current.replaced_by_session_id = new_session_id
            replacement = _MemorySession(
                id=new_session_id,
                user_id=current.user_id,
                device_installation_id=current.device_installation_id,
                family_id=current.family_id,
                refresh_token_hash=new_refresh_token_hash,
                expires_at=new_refresh_expires_at,
            )
            self._sessions[new_session_id] = replacement
            self._session_by_refresh_hash[new_refresh_token_hash] = new_session_id
            return RefreshRotation(
                RefreshRotationStatus.ROTATED,
                AuthenticatedSession(current.user_id, new_session_id, new_refresh_expires_at),
            )

    async def revoke_session(self, *, user_id: UUID, session_id: UUID, now: datetime) -> None:
        async with self._lock:
            session = self._sessions.get(session_id)
            if session is not None and session.user_id == user_id:
                session.revoked_at = session.revoked_at or now

    async def get_authenticated_user(
        self,
        *,
        user_id: UUID,
        session_id: UUID,
        now: datetime,
    ) -> User | None:
        async with self._lock:
            session = self._sessions.get(session_id)
            user = self._users.get(user_id)
            if (
                session is None
                or session.user_id != user_id
                or session.revoked_at is not None
                or session.expires_at <= now
                or user is None
                or user.status is not UserStatus.ACTIVE
            ):
                return None
            return user

    async def get_user(self, user_id: UUID) -> User | None:
        return self._users.get(user_id)

    async def update_user_nickname(
        self,
        *,
        user_id: UUID,
        expected_version: int,
        nickname: str,
        now: datetime,
    ) -> UserWriteResult:
        async with self._lock:
            user = self._users.get(user_id)
            if user is None or user.status is not UserStatus.ACTIVE:
                return UserWriteResult(VersionedWriteStatus.NOT_FOUND)
            if user.version != expected_version:
                return UserWriteResult(VersionedWriteStatus.CONFLICT)
            updated = replace(
                user,
                nickname=nickname,
                version=user.version + 1,
                updated_at=now,
            )
            self._users[user_id] = updated
            return UserWriteResult(VersionedWriteStatus.UPDATED, updated)

    async def get_health_profile(self, user_id: UUID) -> HealthProfile | None:
        return self._health_profiles.get(user_id)

    async def put_health_profile(
        self,
        *,
        user_id: UUID,
        expected_version: int,
        profile: HealthProfileInput,
        now: datetime,
    ) -> HealthProfileWriteResult:
        async with self._lock:
            user = self._users.get(user_id)
            if user is None or user.status is not UserStatus.ACTIVE:
                return HealthProfileWriteResult(VersionedWriteStatus.NOT_FOUND)
            current = self._health_profiles.get(user_id)
            current_version = current.version if current else 0
            if current_version != expected_version:
                return HealthProfileWriteResult(VersionedWriteStatus.CONFLICT)
            updated = HealthProfile(
                user_id=user_id,
                birth_date=profile.birth_date,
                height_cm=profile.height_cm,
                current_weight_kg=profile.current_weight_kg,
                target_weight_kg=profile.target_weight_kg,
                goal_type=profile.goal_type,
                daily_energy_target_kcal=(
                    current.daily_energy_target_kcal if current is not None else None
                ),
                version=current_version + 1,
                created_at=current.created_at if current is not None else now,
                updated_at=now,
            )
            self._health_profiles[user_id] = updated
            return HealthProfileWriteResult(VersionedWriteStatus.UPDATED, updated)

    async def ping(self) -> None:
        return None
