from functools import lru_cache
from ipaddress import ip_network
from typing import Literal

from pydantic import AnyHttpUrl, Field, SecretStr, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


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
    database_url: str = "postgresql+psycopg://ordin:ordin@127.0.0.1:55432/ordin"
    redis_url: str = "redis://127.0.0.1:6379/0"

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
        if self.environment not in {"staging", "production"}:
            return self

        insecure_markers = ("development-", "change-before-production")
        protected_values = (
            self.jwt_secret,
            self.identity_hmac_secret,
            self.otp_hmac_secret,
            self.token_hmac_secret,
            self.idempotency_hmac_secret,
        )
        if any(
            marker in secret.get_secret_value()
            for secret in protected_values
            for marker in insecure_markers
        ):
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
        self._validate_forwarded_allow_ips()
        return self

    def _validate_forwarded_allow_ips(self) -> None:
        values = [value.strip() for value in self.forwarded_allow_ips.split(",") if value.strip()]
        if "*" in values:
            raise ValueError(
                "staging and production must not trust forwarded headers from every peer"
            )
        try:
            for value in values:
                ip_network(value, strict=False)
        except ValueError as error:
            raise ValueError(
                "forwarded proxy peers must be IP addresses or CIDR networks"
            ) from error


@lru_cache
def get_settings() -> Settings:
    return Settings()
