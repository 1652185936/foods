from dataclasses import replace
from typing import Any
from uuid import UUID, uuid4

import pytest
from httpx import AsyncClient

from ordin.infrastructure.container import AppContainer
from ordin.infrastructure.object_storage.memory import InMemoryObjectStorage
from ordin.infrastructure.recognition_memory import InMemoryRecognitionRepository
from ordin.modules.recognition.errors import ObjectStorageUnavailableError
from ordin.modules.recognition.models import RecognitionItem, RecognitionStatus
from tests.helpers import bearer, sign_in
from tests.integration.test_recognition_api import _create_completed_upload, _png
from tests.integration.test_records_api import (
    _fasting_operation,
    _meal_operation,
    _preferences_operation,
)


async def test_export_is_complete_readable_bounded_and_user_isolated(
    client: AsyncClient,
    container: AppContainer,
    recognition_storage: InMemoryObjectStorage,
    recognition_repository: InMemoryRecognitionRepository,
) -> None:
    first, _ = await sign_in(client, idempotency_key="account-export-one")
    second, _ = await sign_in(
        client,
        phone_number="+971502222222",
        idempotency_key="account-export-two",
    )
    first_tokens = first["tokens"]
    second_tokens = second["tokens"]
    assert isinstance(first_tokens, dict)
    assert isinstance(second_tokens, dict)
    first_headers = bearer(first_tokens["accessToken"])
    second_headers = bearer(second_tokens["accessToken"])

    profile = await client.put(
        "/api/v1/users/me/health-profile",
        headers=first_headers,
        json={
            "expectedVersion": 0,
            "heightCm": "171.50",
            "currentWeightKg": "68.25",
            "goalType": "maintain",
        },
    )
    assert profile.status_code == 200
    records = await client.post(
        "/api/v1/sync/push",
        headers=first_headers,
        json={
            "operations": [
                _meal_operation(
                    entity_id=uuid4(),
                    image_reference="private/account/meal-image.jpg",
                ),
                _fasting_operation(entity_id=uuid4()),
                _preferences_operation(),
            ]
        },
    )
    assert records.status_code == 200

    completed = await _create_completed_upload(
        client,
        recognition_storage,
        first_headers,
        _png(),
    )
    queued = await client.post(
        "/api/v1/recognitions",
        headers={**first_headers, "Idempotency-Key": "account-export-recognition"},
        json={"uploadSessionId": completed["uploadSessionId"]},
    )
    assert queued.status_code == 202
    first_user = first["user"]
    assert isinstance(first_user, dict)
    first_user_id = UUID(str(first_user["id"]))
    job_id = UUID(queued.json()["id"])
    job = recognition_repository._jobs[(first_user_id, job_id)]
    item_id = uuid4()
    recognition_repository._jobs[(first_user_id, job_id)] = replace(
        job,
        status=RecognitionStatus.NEEDS_REVIEW,
        overall_confidence_milli=450,
        needs_review_reason="low_confidence",
        items=(
            RecognitionItem(
                id=item_id,
                position=0,
                name="Detected dish",
                canonical_food_id="detected-dish",
                serving_milli=250_000,
                energy_kcal=410,
                protein_mg=12_000,
                carbs_mg=45_000,
                fat_mg=16_000,
                confidence_milli=450,
                alternatives=(),
                is_user_corrected=False,
            ),
        ),
    )
    corrected = await client.put(
        f"/api/v1/recognitions/{job_id}/correction",
        headers=first_headers,
        json={
            "expectedVersion": 1,
            "items": [
                {
                    "id": str(item_id),
                    "name": "Reviewed dish",
                    "servingMilli": 275000,
                    "energyKcal": 430,
                    "proteinMg": 13000,
                    "carbsMg": 46000,
                    "fatMg": 17000,
                }
            ],
        },
    )
    assert corrected.status_code == 200

    exported = await client.get("/api/v1/users/me/data-export", headers=first_headers)
    assert exported.status_code == 200, exported.text
    payload = exported.json()
    assert payload["schemaVersion"] == 1
    assert payload["exportedAt"] == "2026-07-20T12:00:00Z"
    assert payload["healthProfile"]["heightCm"] == "171.50"
    assert payload["preferences"]["dailyEnergyTargetKcal"] == 1800
    assert payload["meals"][0]["items"][0]["name"] == "Chicken rice"
    assert payload["fastingSessions"][0]["status"] == "active"
    assert payload["recognitions"][0]["items"][0]["name"] == "Reviewed dish"
    assert payload["recognitions"][0]["corrections"][0]["items"][0]["name"] == ("Reviewed dish")
    forbidden_keys = {
        "accessToken",
        "refreshToken",
        "deviceInstallationId",
        "identitySubjectHash",
        "idempotencyKeyHash",
        "requestHash",
        "objectKey",
        "sourceObjectKey",
        "uploadUrl",
        "imageReference",
    }
    assert not (set(_all_keys(payload)) & forbidden_keys)
    assert "private/account/meal-image.jpg" not in exported.text
    for upload in recognition_repository._uploads.values():
        assert upload.incoming_object_key not in exported.text
        if upload.sanitized_object_key is not None:
            assert upload.sanitized_object_key not in exported.text

    isolated = await client.get("/api/v1/users/me/data-export", headers=second_headers)
    assert isolated.status_code == 200
    assert isolated.json()["meals"] == []
    assert isolated.json()["recognitions"] == []

    container.accounts_service._export_max_records = 1
    too_large = await client.get("/api/v1/users/me/data-export", headers=first_headers)
    assert too_large.status_code == 413
    assert too_large.json()["code"] == "account_export_too_large"


async def test_delete_requires_current_refresh_and_device_then_invalidates_every_session(
    client: AsyncClient,
    recognition_storage: InMemoryObjectStorage,
    recognition_repository: InMemoryRecognitionRepository,
) -> None:
    phone = "+971503333333"
    first, first_installation = await sign_in(
        client,
        phone_number=phone,
        idempotency_key="account-delete-one",
    )
    second, second_installation = await sign_in(
        client,
        phone_number=phone,
        idempotency_key="account-delete-two",
    )
    first_tokens = first["tokens"]
    second_tokens = second["tokens"]
    first_user = first["user"]
    assert isinstance(first_tokens, dict)
    assert isinstance(second_tokens, dict)
    assert isinstance(first_user, dict)
    old_user_id = first_user["id"]
    old_user_uuid = UUID(str(old_user_id))
    first_headers = bearer(first_tokens["accessToken"])
    second_headers = bearer(second_tokens["accessToken"])

    await _create_completed_upload(
        client,
        recognition_storage,
        first_headers,
        _png(),
    )
    object_keys = {
        upload.incoming_object_key for upload in recognition_repository._uploads.values()
    } | {
        upload.sanitized_object_key
        for upload in recognition_repository._uploads.values()
        if upload.sanitized_object_key is not None
    }

    bad_confirmation = await client.request(
        "DELETE",
        "/api/v1/users/me",
        headers=first_headers,
        json={
            "confirmation": "DELETE_ACCOUNT",
            "refreshToken": first_tokens["refreshToken"],
            "deviceInstallationId": str(first_installation),
        },
    )
    assert bad_confirmation.status_code == 422
    wrong_refresh = await client.request(
        "DELETE",
        "/api/v1/users/me",
        headers=first_headers,
        json={
            "confirmation": "DELETE_MY_ACCOUNT",
            "refreshToken": "x" * 64,
            "deviceInstallationId": str(first_installation),
        },
    )
    assert wrong_refresh.status_code == 401
    other_session_refresh = await client.request(
        "DELETE",
        "/api/v1/users/me",
        headers=first_headers,
        json={
            "confirmation": "DELETE_MY_ACCOUNT",
            "refreshToken": second_tokens["refreshToken"],
            "deviceInstallationId": str(second_installation),
        },
    )
    assert other_session_refresh.status_code == 401
    wrong_device = await client.request(
        "DELETE",
        "/api/v1/users/me",
        headers=first_headers,
        json={
            "confirmation": "DELETE_MY_ACCOUNT",
            "refreshToken": first_tokens["refreshToken"],
            "deviceInstallationId": str(uuid4()),
        },
    )
    assert wrong_device.status_code == 401
    assert (await client.get("/api/v1/users/me", headers=first_headers)).status_code == 200

    deleted = await client.request(
        "DELETE",
        "/api/v1/users/me",
        headers=first_headers,
        json={
            "confirmation": "DELETE_MY_ACCOUNT",
            "refreshToken": first_tokens["refreshToken"],
            "deviceInstallationId": str(first_installation),
        },
    )
    assert deleted.status_code == 204
    assert not deleted.content
    assert (await client.get("/api/v1/users/me", headers=first_headers)).status_code == 401
    assert (await client.get("/api/v1/users/me", headers=second_headers)).status_code == 401
    for tokens, installation_id in (
        (first_tokens, first_installation),
        (second_tokens, second_installation),
    ):
        refresh = await client.post(
            "/api/v1/auth/token/refresh",
            json={
                "refreshToken": tokens["refreshToken"],
                "deviceInstallationId": str(installation_id),
            },
        )
        assert refresh.status_code == 401
    assert all(recognition_storage.get_for_test(key) is None for key in object_keys)

    repeated = await client.request(
        "DELETE",
        "/api/v1/users/me",
        headers=first_headers,
        json={
            "confirmation": "DELETE_MY_ACCOUNT",
            "refreshToken": first_tokens["refreshToken"],
            "deviceInstallationId": str(first_installation),
        },
    )
    assert repeated.status_code == 401

    registered_again, _ = await sign_in(
        client,
        phone_number=phone,
        idempotency_key="account-delete-register-again",
    )
    new_user = registered_again["user"]
    assert isinstance(new_user, dict)
    assert new_user["id"] != old_user_id
    assert all(owner_id != old_user_uuid for owner_id, _ in recognition_repository._uploads)


async def test_delete_stays_committed_when_immediate_object_cleanup_fails(
    client: AsyncClient,
    recognition_storage: InMemoryObjectStorage,
    recognition_repository: InMemoryRecognitionRepository,
    monkeypatch: pytest.MonkeyPatch,
    caplog: pytest.LogCaptureFixture,
) -> None:
    signed_in, installation_id = await sign_in(
        client,
        phone_number="+971504444444",
        idempotency_key="account-delete-storage-failure",
    )
    tokens = signed_in["tokens"]
    assert isinstance(tokens, dict)
    headers = bearer(tokens["accessToken"])
    await _create_completed_upload(client, recognition_storage, headers, _png())
    queued_keys = {
        object_key
        for upload in recognition_repository._uploads.values()
        for object_key in (upload.incoming_object_key, upload.sanitized_object_key)
        if object_key is not None
    }
    object_keys = {key for key in queued_keys if recognition_storage.get_for_test(key) is not None}

    async def unavailable_delete(object_key: str) -> None:
        del object_key
        raise ObjectStorageUnavailableError

    monkeypatch.setattr(recognition_storage, "delete", unavailable_delete)
    deleted = await client.request(
        "DELETE",
        "/api/v1/users/me",
        headers=headers,
        json={
            "confirmation": "DELETE_MY_ACCOUNT",
            "refreshToken": tokens["refreshToken"],
            "deviceInstallationId": str(installation_id),
        },
    )

    assert deleted.status_code == 204
    assert (await client.get("/api/v1/users/me", headers=headers)).status_code == 401
    assert all(recognition_storage.get_for_test(key) is not None for key in object_keys)
    assert str(tokens["refreshToken"]) not in caplog.text
    assert all(key not in caplog.text for key in object_keys)


def _all_keys(value: Any) -> list[str]:
    if isinstance(value, dict):
        return list(value) + [key for nested in value.values() for key in _all_keys(nested)]
    if isinstance(value, list):
        return [key for nested in value for key in _all_keys(nested)]
    return []
