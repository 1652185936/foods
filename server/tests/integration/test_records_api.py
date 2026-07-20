from copy import deepcopy
from uuid import UUID, uuid4

from httpx import AsyncClient

from tests.helpers import bearer, sign_in


def _meal_operation(
    *,
    entity_id: UUID,
    operation_id: UUID | None = None,
    expected_version: int = 0,
    energy_kcal: int = 620,
    action: str = "upsert",
    image_reference: str | None = None,
) -> dict[str, object]:
    operation: dict[str, object] = {
        "operationId": str(operation_id or uuid4()),
        "entityType": "mealLog",
        "entityId": str(entity_id),
        "action": action,
        "expectedVersion": expected_version,
        "payloadVersion": 1,
    }
    if action == "upsert":
        operation["meal"] = {
            "type": "lunch",
            "source": "manual",
            "occurredAtUtc": "2026-07-20T11:30:00Z",
            "timeZoneId": "Asia/Dubai",
            "localDay": "2026-07-20",
            "isWithinEatingWindow": True,
            "items": [
                {
                    "id": str(uuid4()),
                    "name": "Chicken rice",
                    "servingMilli": 1000,
                    "energyKcal": energy_kcal,
                    "proteinMg": 35000,
                    "carbsMg": 72000,
                    "fatMg": 14000,
                    "imageReference": image_reference,
                }
            ],
        }
    return operation


def _fasting_operation(
    *,
    entity_id: UUID,
    operation_id: UUID | None = None,
    expected_version: int = 0,
    status: str = "active",
) -> dict[str, object]:
    ended = status != "active"
    return {
        "operationId": str(operation_id or uuid4()),
        "entityType": "fastingSession",
        "entityId": str(entity_id),
        "action": "upsert",
        "expectedVersion": expected_version,
        "payloadVersion": 1,
        "fastingSession": {
            "plan": "balanced",
            "status": status,
            "startedAtUtc": "2026-07-20T12:00:00Z",
            "targetEndAtUtc": "2026-07-21T04:00:00Z",
            "endedAtUtc": "2026-07-20T12:00:00Z" if ended else None,
            "timeZoneId": "Asia/Dubai",
            "startedLocalDay": "2026-07-20",
            "targetEndLocalDay": "2026-07-21",
            "endedLocalDay": "2026-07-20" if ended else None,
        },
    }


def _preferences_operation(
    *,
    operation_id: UUID | None = None,
    expected_version: int = 0,
    energy_target: int = 1800,
) -> dict[str, object]:
    return {
        "operationId": str(operation_id or uuid4()),
        "entityType": "appPreferences",
        "entityId": "current",
        "action": "upsert",
        "expectedVersion": expected_version,
        "payloadVersion": 1,
        "appPreferences": {
            "dailyEnergyTargetKcal": energy_target,
            "selectedFastingPlan": "balanced",
            "fastingReminderEnabled": True,
        },
    }


async def _headers(client: AsyncClient, *, phone: str = "+971501234567") -> dict[str, str]:
    signed_in, _ = await sign_in(
        client,
        phone_number=phone,
        idempotency_key=f"signin-{phone}",
    )
    tokens = signed_in["tokens"]
    assert isinstance(tokens, dict)
    return bearer(tokens["accessToken"])


async def test_push_pull_and_resource_queries_cover_all_offline_entities(
    client: AsyncClient,
) -> None:
    headers = await _headers(client)
    meal_id = uuid4()
    fasting_id = uuid4()
    response = await client.post(
        "/api/v1/sync/push",
        headers=headers,
        json={
            "operations": [
                _meal_operation(entity_id=meal_id),
                _fasting_operation(entity_id=fasting_id),
                _preferences_operation(),
            ]
        },
    )

    assert response.status_code == 200, response.text
    results = response.json()["results"]
    assert [result["status"] for result in results] == ["applied"] * 3
    assert [result["serverVersion"] for result in results] == [1, 1, 1]
    assert [result["changeCursor"] for result in results] == [1, 2, 3]

    first_page = await client.get("/api/v1/sync/pull?cursor=0&limit=2", headers=headers)
    assert first_page.status_code == 200
    assert first_page.json()["hasMore"] is True
    assert first_page.json()["nextCursor"] == 2
    assert [change["entityType"] for change in first_page.json()["changes"]] == [
        "mealLog",
        "fastingSession",
    ]
    assert first_page.json()["changes"][0]["meal"]["localDay"] == "2026-07-20"

    second_page = await client.get(
        f"/api/v1/sync/pull?cursor={first_page.json()['nextCursor']}",
        headers=headers,
    )
    assert second_page.status_code == 200
    assert second_page.json()["hasMore"] is False
    assert second_page.json()["changes"][0]["entityType"] == "appPreferences"

    meals = await client.get("/api/v1/meals?localDay=2026-07-20", headers=headers)
    assert meals.status_code == 200
    assert meals.json()["items"][0]["id"] == str(meal_id)
    assert "userId" not in meals.text
    fasting = await client.get(f"/api/v1/fasting-sessions/{fasting_id}", headers=headers)
    assert fasting.status_code == 200
    assert fasting.json()["startedLocalDay"] == "2026-07-20"
    preferences = await client.get("/api/v1/users/me/preferences", headers=headers)
    assert preferences.status_code == 200
    assert preferences.json()["dailyEnergyTargetKcal"] == 1800


async def test_idempotency_version_conflict_and_tombstone_are_deterministic(
    client: AsyncClient,
) -> None:
    headers = await _headers(client)
    meal_id = uuid4()
    operation_id = uuid4()
    original = _meal_operation(entity_id=meal_id, operation_id=operation_id)

    first = await client.post(
        "/api/v1/sync/push",
        headers=headers,
        json={"operations": [original]},
    )
    replay = await client.post(
        "/api/v1/sync/push",
        headers=headers,
        json={"operations": [original]},
    )
    assert first.status_code == replay.status_code == 200
    assert first.json()["results"][0]["replayed"] is False
    assert replay.json()["results"][0]["replayed"] is True
    assert replay.json()["results"][0]["changeCursor"] == 1

    changed = deepcopy(original)
    changed["meal"]["items"][0]["energyKcal"] = 999  # type: ignore[index]
    key_collision = await client.post(
        "/api/v1/sync/push",
        headers=headers,
        json={"operations": [changed]},
    )
    assert key_collision.status_code == 200
    assert key_collision.json()["results"][0]["status"] == "idempotencyConflict"

    stale = await client.post(
        "/api/v1/sync/push",
        headers=headers,
        json={
            "operations": [_meal_operation(entity_id=meal_id, expected_version=0, energy_kcal=700)]
        },
    )
    assert stale.status_code == 200
    stale_result = stale.json()["results"][0]
    assert stale_result["status"] == "versionConflict"
    assert stale_result["serverVersion"] == 1

    deleted = await client.post(
        "/api/v1/sync/push",
        headers=headers,
        json={
            "operations": [
                _meal_operation(
                    entity_id=meal_id,
                    expected_version=1,
                    action="delete",
                )
            ]
        },
    )
    assert deleted.status_code == 200
    result = deleted.json()["results"][0]
    assert result["status"] == "applied"
    assert result["serverVersion"] == 2
    assert (await client.get(f"/api/v1/meals/{meal_id}", headers=headers)).status_code == 404

    pulled = await client.get("/api/v1/sync/pull?cursor=1", headers=headers)
    change = pulled.json()["changes"][0]
    assert change["entityId"] == str(meal_id)
    assert change["version"] == 2
    assert change["deletedAtUtc"] is not None
    assert change["meal"] is None


async def test_records_are_strictly_isolated_by_authenticated_user(client: AsyncClient) -> None:
    first_headers = await _headers(client, phone="+971501111111")
    second_headers = await _headers(client, phone="+971502222222")
    shared_id = uuid4()
    created = await client.post(
        "/api/v1/sync/push",
        headers=first_headers,
        json={"operations": [_meal_operation(entity_id=shared_id)]},
    )
    assert created.status_code == 200

    assert (
        await client.get(f"/api/v1/meals/{shared_id}", headers=second_headers)
    ).status_code == 404
    assert (await client.get("/api/v1/sync/pull", headers=second_headers)).json()["changes"] == []
    foreign_delete = await client.post(
        "/api/v1/sync/push",
        headers=second_headers,
        json={
            "operations": [
                _meal_operation(entity_id=shared_id, expected_version=1, action="delete")
            ]
        },
    )
    assert foreign_delete.json()["results"][0]["status"] == "notFound"

    independent = await client.post(
        "/api/v1/sync/push",
        headers=second_headers,
        json={"operations": [_meal_operation(entity_id=shared_id)]},
    )
    assert independent.json()["results"][0]["status"] == "applied"
    assert (
        await client.get(f"/api/v1/meals/{shared_id}", headers=first_headers)
    ).status_code == 200
    assert (
        await client.get(f"/api/v1/meals/{shared_id}", headers=second_headers)
    ).status_code == 200


async def test_fasting_transitions_enforce_one_active_session_and_versions(
    client: AsyncClient,
) -> None:
    headers = await _headers(client)
    first_id = uuid4()
    second_id = uuid4()
    first = await client.post(
        "/api/v1/sync/push",
        headers=headers,
        json={"operations": [_fasting_operation(entity_id=first_id)]},
    )
    assert first.json()["results"][0]["status"] == "applied"

    competing = await client.post(
        "/api/v1/sync/push",
        headers=headers,
        json={"operations": [_fasting_operation(entity_id=second_id)]},
    )
    assert competing.json()["results"][0]["status"] == "activeFastingConflict"

    cancelled = await client.post(
        "/api/v1/sync/push",
        headers=headers,
        json={
            "operations": [
                _fasting_operation(
                    entity_id=first_id,
                    expected_version=1,
                    status="cancelled",
                )
            ]
        },
    )
    assert cancelled.json()["results"][0]["serverVersion"] == 2
    current = await client.get(f"/api/v1/fasting-sessions/{first_id}", headers=headers)
    assert current.json()["status"] == "cancelled"

    retried_with_new_operation = await client.post(
        "/api/v1/sync/push",
        headers=headers,
        json={"operations": [_fasting_operation(entity_id=second_id)]},
    )
    assert retried_with_new_operation.json()["results"][0]["status"] == "applied"


async def test_sync_validation_rejects_unsafe_or_inconsistent_payloads(
    client: AsyncClient,
) -> None:
    headers = await _headers(client)
    unsafe_image = _meal_operation(
        entity_id=uuid4(),
        image_reference="file:///private/meal.jpg",
    )
    invalid_image = await client.post(
        "/api/v1/sync/push",
        headers=headers,
        json={"operations": [unsafe_image]},
    )
    assert invalid_image.status_code == 422

    invalid_day = _meal_operation(entity_id=uuid4())
    invalid_day["meal"]["localDay"] = "2026-02-31"  # type: ignore[index]
    invalid_calendar = await client.post(
        "/api/v1/sync/push",
        headers=headers,
        json={"operations": [invalid_day]},
    )
    assert invalid_calendar.status_code == 422

    preferences_delete = _preferences_operation()
    preferences_delete["action"] = "delete"
    preferences_delete.pop("appPreferences")
    invalid_delete = await client.post(
        "/api/v1/sync/push",
        headers=headers,
        json={"operations": [preferences_delete]},
    )
    assert invalid_delete.status_code == 422

    backwards_fast = _fasting_operation(entity_id=uuid4(), status="cancelled")
    backwards_fast["fastingSession"]["endedAtUtc"] = "2026-07-20T11:59:59Z"  # type: ignore[index]
    invalid_fast = await client.post(
        "/api/v1/sync/push",
        headers=headers,
        json={"operations": [backwards_fast]},
    )
    assert invalid_fast.status_code == 422

    assert (await client.get("/api/v1/sync/pull")).status_code == 401
