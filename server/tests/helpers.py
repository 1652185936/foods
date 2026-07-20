from uuid import UUID, uuid4

from httpx import AsyncClient


async def request_challenge(
    client: AsyncClient,
    *,
    phone_number: str = "+971501234567",
    installation_id: UUID | None = None,
    idempotency_key: str = "challenge-key-0001",
) -> tuple[UUID, UUID]:
    resolved_installation_id = installation_id or uuid4()
    response = await client.post(
        "/api/v1/auth/otp/challenges",
        headers={"Idempotency-Key": idempotency_key},
        json={
            "phoneNumber": phone_number,
            "deviceInstallationId": str(resolved_installation_id),
        },
    )
    assert response.status_code == 202, response.text
    return UUID(response.json()["challengeId"]), resolved_installation_id


async def sign_in(
    client: AsyncClient,
    *,
    phone_number: str = "+971501234567",
    installation_id: UUID | None = None,
    idempotency_key: str = "challenge-key-0001",
) -> tuple[dict[str, object], UUID]:
    challenge_id, resolved_installation_id = await request_challenge(
        client,
        phone_number=phone_number,
        installation_id=installation_id,
        idempotency_key=idempotency_key,
    )
    response = await client.post(
        f"/api/v1/auth/otp/challenges/{challenge_id}/verify",
        json={
            "code": "123456",
            "device": {
                "installationId": str(resolved_installation_id),
                "platform": "android",
                "appVersion": "0.1.0",
            },
        },
    )
    assert response.status_code == 200, response.text
    return response.json(), resolved_installation_id


def bearer(token: object) -> dict[str, str]:
    assert isinstance(token, str)
    return {"Authorization": f"Bearer {token}"}
