from datetime import UTC, datetime

import httpx
from pydantic import AnyHttpUrl, SecretStr

from ordin.infrastructure.config import Settings
from ordin.infrastructure.container import build_default_container
from ordin.infrastructure.otp.webhook_sender import WebhookOtpSender


async def test_webhook_sender_uses_authenticated_structured_request() -> None:
    seen_request: httpx.Request | None = None

    async def handler(request: httpx.Request) -> httpx.Response:
        nonlocal seen_request
        seen_request = request
        return httpx.Response(202)

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
        sender = WebhookOtpSender(
            client=client,
            url="https://sms.example/send",
            bearer_token="private-relay-token",
        )
        await sender.send(
            "+971501234567",
            "987654",
            datetime(2026, 7, 20, 12, 30, tzinfo=UTC),
        )

    assert seen_request is not None
    assert seen_request.headers["Authorization"] == "Bearer private-relay-token"
    assert seen_request.headers["Content-Type"] == "application/json"
    assert seen_request.content == (
        b'{"phoneNumber":"+971501234567","code":"987654","expiresAt":"2026-07-20T12:30:00+00:00"}'
    )


async def test_production_container_assembles_webhook_delivery_path() -> None:
    settings = Settings(
        environment="production",
        jwt_secret=SecretStr("j" * 32),
        identity_hmac_secret=SecretStr("i" * 32),
        otp_hmac_secret=SecretStr("o" * 32),
        token_hmac_secret=SecretStr("t" * 32),
        idempotency_hmac_secret=SecretStr("d" * 32),
        otp_sender_backend="webhook",
        development_otp_code=None,
        otp_webhook_url=AnyHttpUrl("https://sms.example/send"),
        otp_webhook_token=SecretStr("w" * 32),
    )
    container = build_default_container(settings)
    try:
        assert container.settings is settings
    finally:
        await container.close()
