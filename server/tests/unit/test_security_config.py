from typing import Literal

import pytest
from pydantic import AnyHttpUrl, SecretStr, ValidationError

from ordin.infrastructure.config import Settings
from ordin.infrastructure.migration_config import MigrationSettings

_HTTPS_WEBHOOK_URL = AnyHttpUrl("https://sms.example/send")
_HTTPS_PUBLIC_API_ORIGIN = AnyHttpUrl("https://api.example.com")
_WEBHOOK_TOKEN = SecretStr("w" * 32)


def _production_settings(
    *,
    environment: Literal["staging", "production"] = "production",
    otp_webhook_url: AnyHttpUrl | None = _HTTPS_WEBHOOK_URL,
    otp_webhook_token: SecretStr | None = _WEBHOOK_TOKEN,
    forwarded_allow_ips: str = "127.0.0.1",
    recognition_provider_name: str = "configured-provider",
    public_api_origin: AnyHttpUrl = _HTTPS_PUBLIC_API_ORIGIN,
    database_url: str = (
        "postgresql+psycopg://ordin_app:database-password-0001@db.example.com/ordin"
        "?sslmode=verify-full"
    ),
    redis_url: str = "rediss://:cache-password-0001@cache.example.com:6379/0",
    celery_broker_url: str = (
        "rediss://:broker-password-0001@broker.example.com:6379/0?ssl_cert_reqs=required"
    ),
) -> Settings:
    return Settings(
        environment=environment,
        jwt_secret=SecretStr("j" * 32),
        identity_hmac_secret=SecretStr("i" * 32),
        otp_hmac_secret=SecretStr("o" * 32),
        token_hmac_secret=SecretStr("t" * 32),
        idempotency_hmac_secret=SecretStr("d" * 32),
        otp_sender_backend="webhook",
        development_otp_code=None,
        otp_webhook_url=otp_webhook_url,
        otp_webhook_token=otp_webhook_token,
        recognition_provider_backend="http",
        recognition_provider_url=AnyHttpUrl("https://recognition.example/analyze"),
        recognition_provider_token=SecretStr("r" * 32),
        recognition_provider_name=recognition_provider_name,
        public_api_origin=public_api_origin,
        database_url=database_url,
        redis_url=redis_url,
        s3_endpoint_url=AnyHttpUrl("https://s3.internal.example"),
        s3_public_endpoint_url=AnyHttpUrl("https://uploads.example"),
        s3_access_key_id=SecretStr("production-access-key"),
        s3_secret_access_key=SecretStr("s" * 32),
        celery_broker_url=celery_broker_url,
        forwarded_allow_ips=forwarded_allow_ips,
    )


def test_production_rejects_development_otp_backend() -> None:
    with pytest.raises(ValidationError, match="development OTP delivery is forbidden"):
        Settings(
            environment="production",
            jwt_secret=SecretStr("production-jwt-secret-with-at-least-thirty-two-characters"),
            identity_hmac_secret=SecretStr("production-identity-secret-with-at-least-thirty-two"),
            otp_hmac_secret=SecretStr("production-otp-secret-with-at-least-thirty-two-chars"),
            token_hmac_secret=SecretStr("production-token-secret-with-at-least-thirty-two"),
            idempotency_hmac_secret=SecretStr("production-idem-secret-with-at-least-thirty-two"),
            otp_sender_backend="development",
            development_otp_code=None,
        )


def test_development_has_no_implicit_fixed_otp() -> None:
    settings = Settings(environment="development")

    assert settings.development_otp_code is None
    assert settings.redis_url.startswith("redis://")
    assert str(settings.public_api_origin).startswith("http://127.0.0.1")


def test_production_rejects_default_secrets_before_otp_validation() -> None:
    with pytest.raises(ValidationError, match="non-development secrets"):
        Settings(
            environment="production",
            otp_sender_backend="webhook",
            development_otp_code=None,
        )


def test_production_rejects_short_secrets() -> None:
    with pytest.raises(ValidationError, match="at least 32 characters"):
        Settings(
            environment="production",
            jwt_secret=SecretStr("short"),
            identity_hmac_secret=SecretStr("a" * 32),
            otp_hmac_secret=SecretStr("b" * 32),
            token_hmac_secret=SecretStr("c" * 32),
            idempotency_hmac_secret=SecretStr("d" * 32),
            otp_sender_backend="webhook",
            development_otp_code=None,
        )


def test_production_requires_complete_https_webhook_settings() -> None:
    with pytest.raises(ValidationError, match="OTP webhook URL and token"):
        _production_settings(otp_webhook_url=None, otp_webhook_token=None)
    with pytest.raises(ValidationError, match="HTTPS OTP webhook"):
        _production_settings(
            otp_webhook_url=AnyHttpUrl("http://sms.internal/send"),
        )


def test_production_rejects_unbounded_or_invalid_forwarded_proxy_trust() -> None:
    with pytest.raises(ValidationError, match="must not trust"):
        _production_settings(forwarded_allow_ips="*")
    with pytest.raises(ValidationError, match="IP addresses or CIDR"):
        _production_settings(forwarded_allow_ips="proxy.local")


@pytest.mark.parametrize("environment", ["staging", "production"])
@pytest.mark.parametrize("forwarded_allow_ips", ["0.0.0.0/0", "::/0"])
def test_deployed_environments_reject_all_address_forwarded_proxy_ranges(
    environment: Literal["staging", "production"],
    forwarded_allow_ips: str,
) -> None:
    with pytest.raises(ValidationError, match="must not trust"):
        _production_settings(
            environment=environment,
            forwarded_allow_ips=forwarded_allow_ips,
        )


def test_migration_settings_only_load_the_database_url(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    database_url = "postgresql+psycopg://migrator:secret@database.example/ordin"
    monkeypatch.setenv("ORDIN_ENVIRONMENT", "production")
    monkeypatch.setenv("ORDIN_DATABASE_URL", database_url)

    settings = MigrationSettings()

    assert settings.database_url == database_url
    assert set(MigrationSettings.model_fields) == {"database_url"}


def test_recognition_provider_name_is_a_safe_identifier() -> None:
    with pytest.raises(ValidationError, match="safe 1-64 character identifier"):
        _production_settings(recognition_provider_name=" provider\nname ")


@pytest.mark.parametrize(
    "database_url",
    [
        "postgresql+psycopg://ordin_app:database-password-0001@db.example.com/ordin",
        (
            "postgresql+psycopg://ordin_app:database-password-0001@db.example.com/ordin"
            "?sslmode=disable"
        ),
        "sqlite:///ordin.db?sslmode=verify-full",
    ],
)
def test_production_requires_tls_postgresql(database_url: str) -> None:
    with pytest.raises(ValidationError, match=r"PostgreSQL|TLS for PostgreSQL"):
        _production_settings(database_url=database_url)


def test_production_requires_non_placeholder_database_credentials() -> None:
    with pytest.raises(ValidationError, match="non-placeholder database credentials"):
        _production_settings(
            database_url=(
                "postgresql+psycopg://ordin_app:replace-with-secret-manager@db.example.com/ordin"
                "?sslmode=verify-full"
            )
        )


@pytest.mark.parametrize(
    ("setting", "value", "message"),
    [
        ("redis", "redis://:cache-password-0001@cache.example.com:6379/0", "Redis cache"),
        ("redis", "rediss://cache.example.com:6379/0", "Redis cache credentials"),
        (
            "celery",
            "redis://:broker-password-0001@broker.example.com:6379/0",
            "Celery broker",
        ),
        (
            "celery",
            "rediss://:broker-password-0001@broker.example.com:6379/0",
            "verify its TLS certificate",
        ),
    ],
)
def test_production_requires_authenticated_tls_redis(
    setting: str,
    value: str,
    message: str,
) -> None:
    with pytest.raises(ValidationError, match=message):
        if setting == "redis":
            _production_settings(redis_url=value)
        else:
            _production_settings(celery_broker_url=value)


def test_production_requires_https_public_and_object_origins() -> None:
    with pytest.raises(ValidationError, match="HTTPS public API origin"):
        _production_settings(public_api_origin=AnyHttpUrl("http://api.example.com"))
    with pytest.raises(ValidationError, match="must not contain credentials, a path, or a query"):
        _production_settings(public_api_origin=AnyHttpUrl("https://api.example.com/v1"))
    with pytest.raises(ValidationError, match="HTTPS object storage endpoints"):
        Settings(
            **{
                **_production_settings().model_dump(),
                "s3_public_endpoint_url": AnyHttpUrl("http://uploads.example.com"),
            }
        )


def test_production_rejects_placeholder_application_secret() -> None:
    values = _production_settings().model_dump()
    values["jwt_secret"] = SecretStr("REPLACE_WITH_SECRET_MANAGER_VALUE_0001")

    with pytest.raises(ValidationError, match="non-development secrets"):
        Settings(**values)
