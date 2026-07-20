from datetime import timedelta
from uuid import UUID

from ordin.core.clock import Clock
from ordin.core.errors import (
    InvalidAuthenticationError,
    InvalidOtpError,
    RateLimitExceededError,
    ServiceUnavailableError,
)
from ordin.core.identifiers import new_uuid
from ordin.core.security import HmacDigester
from ordin.modules.auth.models import (
    DeviceRegistration,
    OtpChallenge,
    OtpVerificationStatus,
    RefreshRotationStatus,
    TokenPair,
)
from ordin.modules.ports import (
    ApplicationRepository,
    OtpChallengeStore,
    OtpCodeGenerator,
    OtpSender,
    RateLimiter,
    TokenProvider,
)
from ordin.modules.users.models import User


class AuthService:
    def __init__(
        self,
        *,
        repository: ApplicationRepository,
        otp_store: OtpChallengeStore,
        rate_limiter: RateLimiter,
        otp_sender: OtpSender,
        otp_code_generator: OtpCodeGenerator,
        token_service: TokenProvider,
        clock: Clock,
        identity_digester: HmacDigester,
        otp_digester: HmacDigester,
        idempotency_digester: HmacDigester,
        otp_ttl_seconds: int,
        otp_max_attempts: int,
        otp_phone_limit: int,
        otp_device_limit: int,
        otp_ip_limit: int,
        otp_rate_window_seconds: int,
    ) -> None:
        self._repository = repository
        self._otp_store = otp_store
        self._rate_limiter = rate_limiter
        self._otp_sender = otp_sender
        self._otp_code_generator = otp_code_generator
        self._token_service = token_service
        self._clock = clock
        self._identity_digester = identity_digester
        self._otp_digester = otp_digester
        self._idempotency_digester = idempotency_digester
        self._otp_ttl_seconds = otp_ttl_seconds
        self._otp_max_attempts = otp_max_attempts
        self._otp_phone_limit = otp_phone_limit
        self._otp_device_limit = otp_device_limit
        self._otp_ip_limit = otp_ip_limit
        self._otp_rate_window_seconds = otp_rate_window_seconds

    async def request_otp(
        self,
        *,
        phone_number: str,
        device_installation_id: UUID,
        remote_address: str,
        idempotency_key: str | None,
    ) -> OtpChallenge:
        now = self._clock.now()
        phone_digest = self._identity_digester.digest(phone_number)
        idempotency_digest = (
            self._idempotency_digester.digest(
                f"{phone_digest}:{device_installation_id}:{idempotency_key}"
            )
            if idempotency_key
            else None
        )
        if idempotency_digest is not None:
            existing = await self._otp_store.find_idempotent(idempotency_digest, now)
            if existing is not None:
                return existing

        address_digest = self._identity_digester.digest(remote_address)
        rate_keys = (
            (f"phone:{phone_digest}", self._otp_phone_limit),
            (f"device:{device_installation_id}", self._otp_device_limit),
            (f"ip:{address_digest}", self._otp_ip_limit),
        )
        retry_after = 0
        for key, limit in rate_keys:
            limited_for = await self._rate_limiter.hit(
                key,
                limit=limit,
                window_seconds=self._otp_rate_window_seconds,
            )
            retry_after = max(retry_after, limited_for or 0)
        if retry_after:
            raise RateLimitExceededError(retry_after)

        challenge_id = new_uuid()
        code = self._otp_code_generator.generate()
        challenge = OtpChallenge(
            id=challenge_id,
            identity_subject_hash=phone_digest,
            code_digest=self._otp_digester.digest(f"{challenge_id}:{code}"),
            created_at=now,
            expires_at=now + timedelta(seconds=self._otp_ttl_seconds),
            max_attempts=self._otp_max_attempts,
        )
        stored, created = await self._otp_store.create(challenge, idempotency_digest)
        if not created:
            return stored
        try:
            await self._otp_sender.send(phone_number, code, challenge.expires_at)
        except Exception as error:
            await self._otp_store.delete(challenge.id, idempotency_digest)
            raise ServiceUnavailableError from error
        return challenge

    async def verify_otp(
        self,
        *,
        challenge_id: UUID,
        code: str,
        device: DeviceRegistration,
    ) -> tuple[TokenPair, User]:
        now = self._clock.now()
        verification = await self._otp_store.verify(
            challenge_id,
            self._otp_digester.digest(f"{challenge_id}:{code}"),
            now,
        )
        if (
            verification.status is not OtpVerificationStatus.VERIFIED
            or verification.identity_subject_hash is None
        ):
            raise InvalidOtpError

        refresh_token = self._token_service.generate_refresh_token()
        refresh_expires_at = now + timedelta(seconds=self._token_service.refresh_ttl_seconds)
        user, session = await self._repository.create_authenticated_session(
            identity_subject_hash=verification.identity_subject_hash,
            device=device,
            session_id=new_uuid(),
            token_family_id=new_uuid(),
            refresh_token_hash=self._token_service.digest_refresh_token(refresh_token),
            refresh_expires_at=refresh_expires_at,
            now=now,
        )
        access_token, access_expires_at = self._token_service.issue_access_token(
            user_id=user.id,
            session_id=session.session_id,
            now=now,
        )
        return (
            TokenPair(
                access_token=access_token,
                access_expires_at=access_expires_at,
                refresh_token=refresh_token,
                refresh_expires_at=refresh_expires_at,
            ),
            user,
        )

    async def refresh(
        self,
        *,
        refresh_token: str,
        device_installation_id: UUID,
    ) -> TokenPair:
        now = self._clock.now()
        next_refresh_token = self._token_service.generate_refresh_token()
        next_refresh_expires_at = now + timedelta(seconds=self._token_service.refresh_ttl_seconds)
        rotation = await self._repository.rotate_refresh_session(
            current_refresh_token_hash=self._token_service.digest_refresh_token(refresh_token),
            device_installation_id=device_installation_id,
            new_session_id=new_uuid(),
            new_refresh_token_hash=self._token_service.digest_refresh_token(next_refresh_token),
            new_refresh_expires_at=next_refresh_expires_at,
            now=now,
        )
        if rotation.status is not RefreshRotationStatus.ROTATED or rotation.session is None:
            raise InvalidAuthenticationError

        access_token, access_expires_at = self._token_service.issue_access_token(
            user_id=rotation.session.user_id,
            session_id=rotation.session.session_id,
            now=now,
        )
        return TokenPair(
            access_token=access_token,
            access_expires_at=access_expires_at,
            refresh_token=next_refresh_token,
            refresh_expires_at=next_refresh_expires_at,
        )

    async def logout(self, *, user_id: UUID, session_id: UUID) -> None:
        await self._repository.revoke_session(
            user_id=user_id,
            session_id=session_id,
            now=self._clock.now(),
        )
