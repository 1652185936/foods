import re
from functools import lru_cache
from ipaddress import ip_network
from typing import Literal
from urllib.parse import parse_qs, urlsplit

from pydantic import AnyHttpUrl, Field, SecretStr, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict
from sqlalchemy.engine import make_url
from sqlalchemy.exc import ArgumentError

_PRODUCTION_SECRET_MARKERS = (
    "development-",
    "change-before-production",
    "replace-with-",
    "set-in-secret-manager",
    "placeholder",
)


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="ORDIN_",
        case_sensitive=False,
        env_file=".env",
        extra="ignore",
    )

    app_name: str = "Ordin API"
    environment: Literal["development", "test", "staging", "production"] = "development"
    api_v1_prefix: str = "/api/v1"
    public_api_origin: AnyHttpUrl = AnyHttpUrl("http://127.0.0.1:8000")
    database_url: str = "postgresql+psycopg://ordin:ordin@127.0.0.1:55432/ordin"
    redis_url: str = "redis://127.0.0.1:6379/0"
    celery_broker_url: str = "redis://127.0.0.1:6379/1"

    s3_endpoint_url: AnyHttpUrl = AnyHttpUrl("http://127.0.0.1:9000")
    s3_public_endpoint_url: AnyHttpUrl = AnyHttpUrl("http://127.0.0.1:9000")
    s3_region: str = "us-east-1"
    s3_bucket: str = "ordin-private"
    s3_access_key_id: SecretStr = SecretStr("minioadmin")
    s3_secret_access_key: SecretStr = SecretStr("minioadmin")
    s3_force_path_style: bool = True

    recognition_provider_backend: Literal["development", "http"] = "development"
    recognition_provider_url: AnyHttpUrl | None = None
    recognition_provider_token: SecretStr | None = None
    recognition_provider_name: str = "configured-provider"
    recognition_provider_timeout_seconds: float = Field(default=30.0, gt=0, le=60)
    recognition_upload_ttl_seconds: int = Field(default=10 * 60, ge=60, le=10 * 60)
    recognition_source_retention_seconds: int = Field(
        default=24 * 60 * 60,
        ge=60 * 60,
        le=7 * 24 * 60 * 60,
    )
    recognition_max_image_bytes: int = Field(default=10 * 1024 * 1024, ge=1024, le=20 * 1024 * 1024)
    recognition_max_image_pixels: int = Field(default=40_000_000, ge=1_000_000, le=80_000_000)
    recognition_confidence_threshold_milli: int = Field(default=700, ge=0, le=1000)
    recognition_claim_lease_seconds: int = Field(default=180, ge=60, le=15 * 60)
    recognition_task_soft_timeout_seconds: int = Field(default=45, ge=10, le=5 * 60)
    recognition_task_hard_timeout_seconds: int = Field(default=60, ge=15, le=10 * 60)
    recognition_task_max_retries: int = Field(default=2, ge=0, le=5)
    account_export_max_records: int = Field(default=10_000, ge=100, le=100_000)
    account_cleanup_batch_size: int = Field(default=100, ge=1, le=1_000)
    account_cleanup_claim_lease_seconds: int = Field(default=5 * 60, ge=60, le=60 * 60)

    jwt_issuer: str = "ordin-api"
    jwt_audience: str = "ordin-client"
    jwt_secret: SecretStr = SecretStr("development-jwt-secret-change-before-production-0001")
    identity_hmac_secret: SecretStr = SecretStr(
        "development-identity-secret-change-before-production"
    )
    otp_hmac_secret: SecretStr = SecretStr("development-otp-secret-change-before-production-0001")
    token_hmac_secret: SecretStr = SecretStr("development-token-secret-change-before-production")
    idempotency_hmac_secret: SecretStr = SecretStr(
        "development-idempotency-secret-change-before-production"
    )

    access_token_ttl_seconds: int = 15 * 60
    refresh_token_ttl_seconds: int = 30 * 24 * 60 * 60
    otp_ttl_seconds: int = 5 * 60
    otp_resend_after_seconds: int = 60
    otp_max_attempts: int = 5
    otp_phone_limit: int = 5
    otp_device_limit: int = 8
    otp_ip_limit: int = 20
    otp_rate_window_seconds: int = 60 * 60

    otp_sender_backend: Literal["development", "webhook"] = "development"
    development_otp_code: SecretStr | None = None
    otp_webhook_url: AnyHttpUrl | None = None
    otp_webhook_token: SecretStr | None = None
    otp_webhook_timeout_seconds: float = Field(default=5.0, gt=0, le=30)

    # Uvicorn only consumes forwarded headers from these immediate proxy peers.
    forwarded_allow_ips: str = "127.0.0.1"

    @property
    def expose_api_docs(self) -> bool:
        return self.environment in {"development", "test"}

    @model_validator(mode="after")
    def reject_development_security_in_production(self) -> Settings:
        if self.recognition_task_soft_timeout_seconds >= self.recognition_task_hard_timeout_seconds:
            raise ValueError("recognition soft timeout must be shorter than its hard timeout")
        if self.recognition_claim_lease_seconds <= self.recognition_task_hard_timeout_seconds:
            raise ValueError("recognition claim lease must exceed the hard task timeout")
        if self.recognition_provider_backend == "http" and (
            self.recognition_provider_url is None or self.recognition_provider_token is None
        ):
            raise ValueError("HTTP recognition provider mode requires a URL and token")
        if re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,63}", self.recognition_provider_name) is None:
            raise ValueError("recognition provider name must be a safe 1-64 character identifier")
        if self.environment not in {"staging", "production"}:
            return self

        protected_values = (
            self.jwt_secret,
            self.identity_hmac_secret,
            self.otp_hmac_secret,
            self.token_hmac_secret,
            self.idempotency_hmac_secret,
        )
        if any(_is_insecure_secret(secret.get_secret_value()) for secret in protected_values):
            raise ValueError("staging and production require non-development secrets")
        if any(len(secret.get_secret_value()) < 32 for secret in protected_values):
            raise ValueError("staging and production secrets must contain at least 32 characters")
        if self.otp_sender_backend == "development" or self.development_otp_code is not None:
            raise ValueError("development OTP delivery is forbidden outside development and test")
        if self.otp_webhook_url is None or self.otp_webhook_token is None:
            raise ValueError("staging and production require the OTP webhook URL and token")
        if self.otp_webhook_url.scheme != "https":
            raise ValueError("staging and production require an HTTPS OTP webhook")
        if len(self.otp_webhook_token.get_secret_value()) < 32:
            raise ValueError("the OTP webhook token must contain at least 32 characters")
        if _is_insecure_secret(self.otp_webhook_token.get_secret_value()):
            raise ValueError("staging and production require a non-placeholder OTP token")
        if self.recognition_provider_backend != "http":
            raise ValueError("staging and production require a real recognition provider")
        if self.recognition_provider_url is None or self.recognition_provider_token is None:
            raise ValueError("staging and production require recognition provider credentials")
        if self.recognition_provider_url.scheme != "https":
            raise ValueError("staging and production require an HTTPS recognition provider")
        if len(self.recognition_provider_token.get_secret_value()) < 32:
            raise ValueError("the recognition provider token must contain at least 32 characters")
        if _is_insecure_secret(self.recognition_provider_token.get_secret_value()):
            raise ValueError(
                "staging and production require a non-placeholder recognition provider token"
            )
        if self.s3_endpoint_url.scheme != "https" or self.s3_public_endpoint_url.scheme != "https":
            raise ValueError("staging and production require HTTPS object storage endpoints")
        if self.s3_access_key_id.get_secret_value() == "minioadmin" or (
            self.s3_secret_access_key.get_secret_value() == "minioadmin"
        ):
            raise ValueError("staging and production require non-development object credentials")
        if _is_insecure_secret(self.s3_access_key_id.get_secret_value()) or _is_insecure_secret(
            self.s3_secret_access_key.get_secret_value()
        ):
            raise ValueError("staging and production require non-placeholder object credentials")
        if len(self.s3_secret_access_key.get_secret_value()) < 16:
            raise ValueError("the object storage secret must contain at least 16 characters")
        self._validate_public_api_origin()
        self._validate_database_url()
        self._validate_redis_url(self.redis_url, label="Redis cache", require_cert_option=False)
        if self.celery_broker_url == self.redis_url:
            raise ValueError("staging and production require a dedicated Celery broker URL")
        self._validate_redis_url(
            self.celery_broker_url,
            label="Celery broker",
            require_cert_option=True,
        )
        self._validate_forwarded_allow_ips()
        return self

    def _validate_public_api_origin(self) -> None:
        origin = self.public_api_origin
        if origin.scheme != "https":
            raise ValueError("staging and production require an HTTPS public API origin")
        if (
            origin.username is not None
            or origin.password is not None
            or origin.path not in {None, "", "/"}
            or origin.query is not None
            or origin.fragment is not None
        ):
            raise ValueError(
                "the public API origin must not contain credentials, a path, or a query"
            )

    def _validate_database_url(self) -> None:
        try:
            database = make_url(self.database_url)
        except ArgumentError as error:
            raise ValueError("the production database URL is invalid") from error
        if database.drivername != "postgresql+psycopg" or database.host is None:
            raise ValueError("staging and production require PostgreSQL through psycopg")
        if database.query.get("sslmode") not in {"require", "verify-ca", "verify-full"}:
            raise ValueError("staging and production require TLS for PostgreSQL")
        if database.username is None or database.password is None or len(database.password) < 16:
            raise ValueError("staging and production require strong database credentials")
        if _is_insecure_secret(database.password):
            raise ValueError("staging and production require non-placeholder database credentials")

    def _validate_redis_url(
        self,
        value: str,
        *,
        label: str,
        require_cert_option: bool,
    ) -> None:
        parsed = urlsplit(value)
        if parsed.scheme != "rediss" or parsed.hostname is None:
            raise ValueError(f"staging and production require TLS for the {label}")
        if parsed.password is None or len(parsed.password) < 16:
            raise ValueError(f"staging and production require strong {label} credentials")
        if _is_insecure_secret(parsed.password):
            raise ValueError(f"staging and production require non-placeholder {label} credentials")
        if require_cert_option:
            certificate_requirement = parse_qs(parsed.query).get("ssl_cert_reqs", [])
            if not certificate_requirement or certificate_requirement[-1].lower() not in {
                "required",
                "cert_required",
            }:
                raise ValueError("the production Celery broker must verify its TLS certificate")

    def _validate_forwarded_allow_ips(self) -> None:
        values = [value.strip() for value in self.forwarded_allow_ips.split(",") if value.strip()]
        if "*" in values:
            raise ValueError(
                "staging and production must not trust forwarded headers from every peer"
            )
        try:
            networks = [ip_network(value, strict=False) for value in values]
        except ValueError as error:
            raise ValueError(
                "forwarded proxy peers must be IP addresses or CIDR networks"
            ) from error
        if any(network.prefixlen == 0 for network in networks):
            raise ValueError(
                "staging and production must not trust forwarded headers from every peer"
            )


@lru_cache
def get_settings() -> Settings:
    return Settings()


def _is_insecure_secret(value: str) -> bool:
    normalized = re.sub(r"[^a-z0-9]+", "-", value.casefold())
    return any(marker in normalized for marker in _PRODUCTION_SECRET_MARKERS)
