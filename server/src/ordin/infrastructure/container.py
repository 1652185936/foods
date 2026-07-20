import asyncio
from collections.abc import Awaitable, Callable
from dataclasses import dataclass

from httpx import AsyncClient
from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from ordin.core.clock import Clock, SystemClock
from ordin.core.security import HmacDigester
from ordin.infrastructure.auth.tokens import TokenService
from ordin.infrastructure.config import Settings
from ordin.infrastructure.database.repository import SqlAlchemyApplicationRepository
from ordin.infrastructure.otp.webhook_sender import WebhookOtpSender
from ordin.infrastructure.redis.otp_store import RedisOtpChallengeStore
from ordin.infrastructure.redis.rate_limiter import RedisRateLimiter
from ordin.modules.auth.otp import (
    DevelopmentOtpSender,
    FixedOtpCodeGenerator,
    SecureOtpCodeGenerator,
)
from ordin.modules.auth.service import AuthService
from ordin.modules.ports import (
    ApplicationRepository,
    OtpChallengeStore,
    OtpCodeGenerator,
    OtpSender,
    RateLimiter,
)
from ordin.modules.users.service import UsersService


async def _noop_close() -> None:
    return None


@dataclass(slots=True)
class AppContainer:
    settings: Settings
    repository: ApplicationRepository
    otp_store: OtpChallengeStore
    rate_limiter: RateLimiter
    clock: Clock
    token_service: TokenService
    auth_service: AuthService
    users_service: UsersService
    _close_callback: Callable[[], Awaitable[None]] = _noop_close

    async def ready(self) -> bool:
        try:
            await asyncio.gather(
                self.repository.ping(),
                self.otp_store.ping(),
                self.rate_limiter.ping(),
            )
        except Exception:
            return False
        return True

    async def close(self) -> None:
        await self._close_callback()


def assemble_container(
    *,
    settings: Settings,
    repository: ApplicationRepository,
    otp_store: OtpChallengeStore,
    rate_limiter: RateLimiter,
    otp_sender: OtpSender,
    otp_code_generator: OtpCodeGenerator,
    clock: Clock | None = None,
    close_callback: Callable[[], Awaitable[None]] = _noop_close,
) -> AppContainer:
    resolved_clock = clock or SystemClock()
    token_service = TokenService(
        jwt_secret=settings.jwt_secret.get_secret_value(),
        refresh_token_digester=HmacDigester(settings.token_hmac_secret.get_secret_value()),
        issuer=settings.jwt_issuer,
        audience=settings.jwt_audience,
        access_ttl_seconds=settings.access_token_ttl_seconds,
        refresh_ttl_seconds=settings.refresh_token_ttl_seconds,
    )
    auth_service = AuthService(
        repository=repository,
        otp_store=otp_store,
        rate_limiter=rate_limiter,
        otp_sender=otp_sender,
        otp_code_generator=otp_code_generator,
        token_service=token_service,
        clock=resolved_clock,
        identity_digester=HmacDigester(settings.identity_hmac_secret.get_secret_value()),
        otp_digester=HmacDigester(settings.otp_hmac_secret.get_secret_value()),
        idempotency_digester=HmacDigester(settings.idempotency_hmac_secret.get_secret_value()),
        otp_ttl_seconds=settings.otp_ttl_seconds,
        otp_max_attempts=settings.otp_max_attempts,
        otp_phone_limit=settings.otp_phone_limit,
        otp_device_limit=settings.otp_device_limit,
        otp_ip_limit=settings.otp_ip_limit,
        otp_rate_window_seconds=settings.otp_rate_window_seconds,
    )
    return AppContainer(
        settings=settings,
        repository=repository,
        otp_store=otp_store,
        rate_limiter=rate_limiter,
        clock=resolved_clock,
        token_service=token_service,
        auth_service=auth_service,
        users_service=UsersService(repository=repository, clock=resolved_clock),
        _close_callback=close_callback,
    )


def build_default_container(settings: Settings) -> AppContainer:
    engine = create_async_engine(
        settings.database_url,
        pool_pre_ping=True,
        hide_parameters=True,
    )
    session_factory = async_sessionmaker(engine, expire_on_commit=False)
    redis = Redis.from_url(settings.redis_url, decode_responses=True)

    otp_http_client: AsyncClient | None = None
    if settings.otp_sender_backend == "development":
        development_code = settings.development_otp_code
        if development_code is None:
            raise RuntimeError("development OTP mode requires ORDIN_DEVELOPMENT_OTP_CODE")
        otp_sender: OtpSender = DevelopmentOtpSender()
        otp_code_generator: OtpCodeGenerator = FixedOtpCodeGenerator(
            development_code.get_secret_value()
        )
    else:
        webhook_url = settings.otp_webhook_url
        webhook_token = settings.otp_webhook_token
        if webhook_url is None or webhook_token is None:
            raise RuntimeError("OTP webhook settings were not validated")
        otp_http_client = AsyncClient(
            timeout=settings.otp_webhook_timeout_seconds,
            follow_redirects=False,
        )
        otp_sender = WebhookOtpSender(
            client=otp_http_client,
            url=str(webhook_url),
            bearer_token=webhook_token.get_secret_value(),
        )
        otp_code_generator = SecureOtpCodeGenerator()

    async def close_resources() -> None:
        if otp_http_client is not None:
            await otp_http_client.aclose()
        await redis.aclose()
        await engine.dispose()

    return assemble_container(
        settings=settings,
        repository=SqlAlchemyApplicationRepository(session_factory),
        otp_store=RedisOtpChallengeStore(redis),
        rate_limiter=RedisRateLimiter(redis),
        otp_sender=otp_sender,
        otp_code_generator=otp_code_generator,
        close_callback=close_resources,
    )
