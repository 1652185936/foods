import asyncio
import logging
from uuid import uuid4

from _pytest.logging import LogCaptureFixture
from httpx import AsyncClient

from ordin.infrastructure.memory import InMemoryOtpChallengeStore
from tests.conftest import MutableClock, RecordingOtpSender
from tests.helpers import bearer, request_challenge, sign_in


async def test_otp_request_is_idempotent_without_exposing_phone_or_code(
    client: AsyncClient,
    otp_sender: RecordingOtpSender,
    otp_store: InMemoryOtpChallengeStore,
    caplog: LogCaptureFixture,
) -> None:
    phone_number = "+971501234567"
    installation_id = uuid4()
    headers = {"Idempotency-Key": "same-request-key"}
    payload = {
        "phoneNumber": phone_number,
        "deviceInstallationId": str(installation_id),
    }

    with caplog.at_level(logging.DEBUG):
        first, second = await asyncio.gather(
            client.post("/api/v1/auth/otp/challenges", headers=headers, json=payload),
            client.post("/api/v1/auth/otp/challenges", headers=headers, json=payload),
        )

    assert first.status_code == second.status_code == 202
    assert first.json()["challengeId"] == second.json()["challengeId"]
    assert len(otp_sender.deliveries) == 1
    public_output = first.text + second.text + caplog.text
    assert phone_number not in public_output
    assert "123456" not in public_output
    persisted = repr(otp_store._challenges)
    assert phone_number not in persisted
    assert "123456" not in persisted


async def test_idempotency_key_is_scoped_to_identity_and_device(client: AsyncClient) -> None:
    shared_key = "shared-client-key"
    first_id, device_id = await request_challenge(
        client,
        phone_number="+971501111111",
        idempotency_key=shared_key,
    )
    second_id, _ = await request_challenge(
        client,
        phone_number="+971502222222",
        installation_id=device_id,
        idempotency_key=shared_key,
    )
    third_id, _ = await request_challenge(
        client,
        phone_number="+971501111111",
        installation_id=uuid4(),
        idempotency_key=shared_key,
    )

    assert len({first_id, second_id, third_id}) == 3


async def test_invalid_otp_returns_generic_problem_without_sensitive_input(
    client: AsyncClient,
) -> None:
    challenge_id, installation_id = await request_challenge(client)
    response = await client.post(
        f"/api/v1/auth/otp/challenges/{challenge_id}/verify",
        json={
            "code": "000000",
            "device": {
                "installationId": str(installation_id),
                "platform": "android",
                "appVersion": "0.1.0",
            },
        },
    )

    assert response.status_code == 401
    assert response.headers["content-type"].startswith("application/problem+json")
    assert response.json()["code"] == "invalid_otp"
    assert "000000" not in response.text
    assert "+971" not in response.text


async def test_otp_is_consumed_exactly_once_under_concurrency(client: AsyncClient) -> None:
    challenge_id, installation_id = await request_challenge(client)
    payload = {
        "code": "123456",
        "device": {
            "installationId": str(installation_id),
            "platform": "android",
            "appVersion": "0.1.0",
        },
    }
    responses = await asyncio.gather(
        client.post(f"/api/v1/auth/otp/challenges/{challenge_id}/verify", json=payload),
        client.post(f"/api/v1/auth/otp/challenges/{challenge_id}/verify", json=payload),
    )

    assert sorted(response.status_code for response in responses) == [200, 401]


async def test_expired_otp_and_exhausted_attempts_remain_generic(
    client: AsyncClient,
    clock: MutableClock,
) -> None:
    expired_challenge, installation_id = await request_challenge(
        client,
        idempotency_key="expired-challenge-key",
    )
    clock.advance(seconds=301)
    expired = await client.post(
        f"/api/v1/auth/otp/challenges/{expired_challenge}/verify",
        json={
            "code": "123456",
            "device": {
                "installationId": str(installation_id),
                "platform": "android",
                "appVersion": "0.1.0",
            },
        },
    )
    assert expired.status_code == 401
    assert expired.json()["code"] == "invalid_otp"

    challenge_id, second_installation = await request_challenge(
        client,
        idempotency_key="attempts-challenge-key",
    )
    invalid_payload = {
        "code": "000000",
        "device": {
            "installationId": str(second_installation),
            "platform": "android",
            "appVersion": "0.1.0",
        },
    }
    for _ in range(5):
        assert (
            await client.post(
                f"/api/v1/auth/otp/challenges/{challenge_id}/verify",
                json=invalid_payload,
            )
        ).status_code == 401
    invalid_payload["code"] = "123456"
    assert (
        await client.post(
            f"/api/v1/auth/otp/challenges/{challenge_id}/verify",
            json=invalid_payload,
        )
    ).status_code == 401


async def test_otp_request_rate_limit_returns_retry_after(client: AsyncClient) -> None:
    installation_id = uuid4()
    for index in range(5):
        response = await client.post(
            "/api/v1/auth/otp/challenges",
            headers={"Idempotency-Key": f"rate-limit-key-{index}"},
            json={
                "phoneNumber": "+971501234567",
                "deviceInstallationId": str(installation_id),
            },
        )
        assert response.status_code == 202

    limited = await client.post(
        "/api/v1/auth/otp/challenges",
        headers={"Idempotency-Key": "rate-limit-key-final"},
        json={
            "phoneNumber": "+971501234567",
            "deviceInstallationId": str(installation_id),
        },
    )
    assert limited.status_code == 429
    assert int(limited.headers["retry-after"]) >= 1
    assert limited.json()["code"] == "rate_limit_exceeded"


async def test_refresh_rotation_and_reuse_revoke_the_token_family(client: AsyncClient) -> None:
    signed_in, installation_id = await sign_in(client)
    original_tokens = signed_in["tokens"]
    assert isinstance(original_tokens, dict)
    original_access = original_tokens["accessToken"]
    original_refresh = original_tokens["refreshToken"]

    rotated = await client.post(
        "/api/v1/auth/token/refresh",
        json={
            "refreshToken": original_refresh,
            "deviceInstallationId": str(installation_id),
        },
    )
    assert rotated.status_code == 200
    rotated_tokens = rotated.json()
    assert rotated_tokens["refreshToken"] != original_refresh

    old_access_response = await client.get(
        "/api/v1/users/me",
        headers=bearer(original_access),
    )
    assert old_access_response.status_code == 401

    reuse = await client.post(
        "/api/v1/auth/token/refresh",
        json={
            "refreshToken": original_refresh,
            "deviceInstallationId": str(installation_id),
        },
    )
    assert reuse.status_code == 401

    revoked_family_access = await client.get(
        "/api/v1/users/me",
        headers=bearer(rotated_tokens["accessToken"]),
    )
    assert revoked_family_access.status_code == 401
    revoked_family_refresh = await client.post(
        "/api/v1/auth/token/refresh",
        json={
            "refreshToken": rotated_tokens["refreshToken"],
            "deviceInstallationId": str(installation_id),
        },
    )
    assert revoked_family_refresh.status_code == 401


async def test_logout_immediately_invalidates_access_token(client: AsyncClient) -> None:
    signed_in, _ = await sign_in(client)
    tokens = signed_in["tokens"]
    assert isinstance(tokens, dict)
    headers = bearer(tokens["accessToken"])

    response = await client.delete("/api/v1/auth/sessions/current", headers=headers)
    assert response.status_code == 204
    assert (await client.get("/api/v1/users/me", headers=headers)).status_code == 401


async def test_access_token_expiry_uses_application_clock(
    client: AsyncClient,
    clock: MutableClock,
) -> None:
    signed_in, _ = await sign_in(client)
    tokens = signed_in["tokens"]
    assert isinstance(tokens, dict)
    clock.advance(seconds=901)

    response = await client.get(
        "/api/v1/users/me",
        headers=bearer(tokens["accessToken"]),
    )
    assert response.status_code == 401


async def test_protected_routes_require_bearer_authentication(client: AsyncClient) -> None:
    response = await client.get("/api/v1/users/me")

    assert response.status_code == 401
    assert response.headers["www-authenticate"] == "Bearer"
    assert response.json()["code"] == "invalid_authentication"


async def test_validation_problem_does_not_echo_phone_or_otp(client: AsyncClient) -> None:
    phone = "+971501234567"
    response = await client.post(
        "/api/v1/auth/otp/challenges",
        json={
            "phoneNumber": phone,
            "deviceInstallationId": "not-a-uuid",
            "unexpectedCode": "123456",
        },
    )

    assert response.status_code == 422
    assert response.headers["content-type"].startswith("application/problem+json")
    assert phone not in response.text
    assert "123456" not in response.text
