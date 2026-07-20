from httpx import AsyncClient

from tests.helpers import bearer, sign_in


async def test_user_and_health_profile_versioned_flow(client: AsyncClient) -> None:
    signed_in, _ = await sign_in(client)
    tokens = signed_in["tokens"]
    user = signed_in["user"]
    assert isinstance(tokens, dict)
    assert isinstance(user, dict)
    headers = bearer(tokens["accessToken"])

    current = await client.get("/api/v1/users/me", headers=headers)
    assert current.status_code == 200
    assert "phoneNumber" not in current.json()

    updated = await client.patch(
        "/api/v1/users/me",
        headers=headers,
        json={"expectedVersion": user["version"], "nickname": "Lin"},
    )
    assert updated.status_code == 200
    assert updated.json()["nickname"] == "Lin"
    assert updated.json()["version"] == user["version"] + 1

    conflict = await client.patch(
        "/api/v1/users/me",
        headers=headers,
        json={"expectedVersion": user["version"], "nickname": "Old write"},
    )
    assert conflict.status_code == 409
    assert conflict.json()["code"] == "version_conflict"

    missing_profile = await client.get(
        "/api/v1/users/me/health-profile",
        headers=headers,
    )
    assert missing_profile.status_code == 404

    created_profile = await client.put(
        "/api/v1/users/me/health-profile",
        headers=headers,
        json={
            "expectedVersion": 0,
            "birthDate": "1995-05-08",
            "heightCm": "172.50",
            "currentWeightKg": "68.20",
            "targetWeightKg": "64.00",
            "goalType": "loseFat",
        },
    )
    assert created_profile.status_code == 200
    assert created_profile.json()["version"] == 1
    assert created_profile.json()["dailyEnergyTargetKcal"] is None

    numeric_wire_value = await client.put(
        "/api/v1/users/me/health-profile",
        headers=headers,
        json={"expectedVersion": 1, "heightCm": 172.5},
    )
    assert numeric_wire_value.status_code == 422

    profile_conflict = await client.put(
        "/api/v1/users/me/health-profile",
        headers=headers,
        json={"expectedVersion": 0, "goalType": "maintain"},
    )
    assert profile_conflict.status_code == 409


async def test_user_id_cannot_be_supplied_to_cross_the_owner_boundary(
    client: AsyncClient,
) -> None:
    first, _ = await sign_in(
        client,
        phone_number="+971501111111",
        idempotency_key="first-user-key",
    )
    second, _ = await sign_in(
        client,
        phone_number="+971502222222",
        idempotency_key="second-user-key",
    )
    first_tokens = first["tokens"]
    second_user = second["user"]
    assert isinstance(first_tokens, dict)
    assert isinstance(second_user, dict)

    response = await client.patch(
        "/api/v1/users/me",
        headers=bearer(first_tokens["accessToken"]),
        json={
            "expectedVersion": 1,
            "nickname": "attempted overwrite",
            "userId": second_user["id"],
        },
    )

    assert response.status_code == 422
    assert response.json()["code"] == "validation_error"
