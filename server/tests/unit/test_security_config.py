import pytest
from pydantic import AnyHttpUrl, SecretStr, ValidationError

from ordin.infrastructure.config import Settings

_HTTPS_WEBHOOK_URL = AnyHttpUrl("https://sms.example/send")
_WEBHOOK_TOKEN = SecretStr("w" * 32)


def _production_settings(
    *,
    otp_webhook_url: AnyHttpUrl | None = _HTTPS_WEBHOOK_URL,
    otp_webhook_token: SecretStr | None = _WEBHOOK_TOKEN,
    forwarded_allow_ips: str = "127.0.0.1",
) -> Settings:
    return Settings(
        environment="production",
        jwt_secret=SecretStr("j" * 32),
        identity_hmac_secret=SecretStr("i" * 32),
        otp_hmac_secret=SecretStr("o" * 32),
        token_hmac_secret=SecretStr("t" * 32),
        idempotency_hmac_secret=SecretStr("d" * 32),
        otp_sender_backend="webhook",
        development_otp_code=None,
        otp_webhook_url=otp_webhook_url,
        otp_webhook_token=otp_webhook_token,
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
    assert Settings(environment="development").development_otp_code is None


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
