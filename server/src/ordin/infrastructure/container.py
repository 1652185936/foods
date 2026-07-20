import asyncio
from collections.abc import Awaitable, Callable
from dataclasses import dataclass

from httpx import AsyncClient
from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from ordin.core.clock import Clock, SystemClock
from ordin.core.security import HmacDigester
from ordin.infrastructure.account_memory import InMemoryAccountRepository
from ordin.infrastructure.auth.tokens import TokenService
from ordin.infrastructure.celery_dispatcher import CeleryRecognitionDispatcher
from ordin.infrastructure.config import Settings
from ordin.infrastructure.database.account_repository import SqlAlchemyAccountRepository
from ordin.infrastructure.database.recognition_repository import SqlAlchemyRecognitionRepository
from ordin.infrastructure.database.records_repository import SqlAlchemyRecordsRepository
from ordin.infrastructure.database.repository import SqlAlchemyApplicationRepository
from ordin.infrastructure.image_processing import PillowImageProcessor
from ordin.infrastructure.memory import InMemoryApplicationRepository
from ordin.infrastructure.object_storage.s3 import S3ObjectStorage, build_s3_client
from ordin.infrastructure.otp.webhook_sender import WebhookOtpSender
from ordin.infrastructure.recognition_memory import InMemoryRecognitionRepository
from ordin.infrastructure.records_memory import InMemoryRecordsRepository
from ordin.infrastructure.redis.otp_store import RedisOtpChallengeStore
from ordin.infrastructure.redis.rate_limiter import RedisRateLimiter
from ordin.modules.accounts.ports import AccountRepository
from ordin.modules.accounts.service import AccountsService
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
from ordin.modules.recognition.ports import (
    ImageProcessor,
    ObjectStorage,
    RecognitionRepository,
    RecognitionTaskDispatcher,
)
from ordin.modules.recognition.service import RecognitionService
from ordin.modules.records.ports import RecordsRepository
from ordin.modules.records.service import RecordsService
from ordin.modules.users.service import UsersService


async def _noop_close() -> None:
    return None


@dataclass(slots=True)
class AppContainer:
    settings: Settings
    repository: ApplicationRepository
    records_repository: RecordsRepository
    otp_store: OtpChallengeStore
    rate_limiter: RateLimiter
    clock: Clock
    token_service: TokenService
    auth_service: AuthService
    users_service: UsersService
    accounts_service: AccountsService
    records_service: RecordsService
    recognition_service: RecognitionService
    _close_callback: Callable[[], Awaitable[None]] = _noop_close

    async def ready(self) -> bool:
        try:
            await asyncio.gather(
                self.repository.ping(),
                self.otp_store.ping(),
                self.rate_limiter.ping(),
                self.recognition_service.ready(),
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
    records_repository: RecordsRepository,
    recognition_repository: RecognitionRepository,
    recognition_storage: ObjectStorage,
    recognition_dispatcher: RecognitionTaskDispatcher,
    account_repository: AccountRepository | None = None,
    otp_store: OtpChallengeStore,
    rate_limiter: RateLimiter,
    otp_sender: OtpSender,
    otp_code_generator: OtpCodeGenerator,
    clock: Clock | None = None,
    image_processor: ImageProcessor | None = None,
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
    recognition_service = RecognitionService(
        repository=recognition_repository,
        storage=recognition_storage,
        image_processor=image_processor or PillowImageProcessor(),
        dispatcher=recognition_dispatcher,
        clock=resolved_clock,
        idempotency_digester=HmacDigester(settings.idempotency_hmac_secret.get_secret_value()),
        upload_ttl_seconds=settings.recognition_upload_ttl_seconds,
        source_retention_seconds=settings.recognition_source_retention_seconds,
        max_image_bytes=settings.recognition_max_image_bytes,
        max_image_pixels=settings.recognition_max_image_pixels,
    )
    if account_repository is None:
        if not isinstance(repository, InMemoryApplicationRepository):
            raise TypeError("account_repository is required for non-memory application storage")
        if not isinstance(records_repository, InMemoryRecordsRepository):
            raise TypeError("account_repository is required for non-memory records storage")
        if not isinstance(recognition_repository, InMemoryRecognitionRepository):
            raise TypeError("account_repository is required for non-memory recognition storage")
        account_repository = InMemoryAccountRepository(
            application=repository,
            records=records_repository,
            recognition=recognition_repository,
        )
    accounts_service = AccountsService(
        repository=account_repository,
        storage=recognition_storage,
        token_service=token_service,
        clock=resolved_clock,
        export_max_records=settings.account_export_max_records,
    )
    return AppContainer(
        settings=settings,
        repository=repository,
        records_repository=records_repository,
        otp_store=otp_store,
        rate_limiter=rate_limiter,
        clock=resolved_clock,
        token_service=token_service,
        auth_service=auth_service,
        users_service=UsersService(repository=repository, clock=resolved_clock),
        accounts_service=accounts_service,
        records_service=RecordsService(repository=records_repository, clock=resolved_clock),
        recognition_service=recognition_service,
        _close_callback=close_callback,
    )


def build_default_container(settings: Settings) -> AppContainer:
    engine = create_async_engine(
        settings.database_url,
        pool_pre_ping=True,
        hide_parameters=True,
    )
    session_factory = async_sessionmaker(engine, expire_on_commit=False)
    application_repository = SqlAlchemyApplicationRepository(session_factory)
    records_repository = SqlAlchemyRecordsRepository(session_factory)
    recognition_repository = SqlAlchemyRecognitionRepository(session_factory)
    account_repository = SqlAlchemyAccountRepository(session_factory)
    redis = Redis.from_url(settings.redis_url, decode_responses=True)
    s3_client = build_s3_client(
        endpoint_url=str(settings.s3_endpoint_url),
        region=settings.s3_region,
        access_key_id=settings.s3_access_key_id.get_secret_value(),
        secret_access_key=settings.s3_secret_access_key.get_secret_value(),
        force_path_style=settings.s3_force_path_style,
    )
    s3_presign_client = build_s3_client(
        endpoint_url=str(settings.s3_public_endpoint_url),
        region=settings.s3_region,
        access_key_id=settings.s3_access_key_id.get_secret_value(),
        secret_access_key=settings.s3_secret_access_key.get_secret_value(),
        force_path_style=settings.s3_force_path_style,
    )

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
        s3_client.close()
        s3_presign_client.close()
        await engine.dispose()

    return assemble_container(
        settings=settings,
        repository=application_repository,
        records_repository=records_repository,
        recognition_repository=recognition_repository,
        account_repository=account_repository,
        recognition_storage=S3ObjectStorage(
            s3_client,
            bucket=settings.s3_bucket,
            presign_client=s3_presign_client,
        ),
        recognition_dispatcher=CeleryRecognitionDispatcher(broker_url=settings.celery_broker_url),
        otp_store=RedisOtpChallengeStore(redis),
        rate_limiter=RedisRateLimiter(redis),
        otp_sender=otp_sender,
        otp_code_generator=otp_code_generator,
        close_callback=close_resources,
    )
