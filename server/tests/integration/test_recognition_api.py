import hashlib
from dataclasses import replace
from io import BytesIO
from typing import cast
from uuid import UUID, uuid4

from httpx import AsyncClient
from PIL import Image

from ordin.infrastructure.object_storage.memory import InMemoryObjectStorage
from ordin.infrastructure.recognition_memory import (
    InMemoryRecognitionRepository,
    RecordingRecognitionDispatcher,
)
from ordin.modules.recognition.models import (
    RecognitionAlternative,
    RecognitionItem,
    RecognitionStatus,
)
from tests.helpers import bearer, sign_in


def _png() -> bytes:
    output = BytesIO()
    with Image.new("RGB", (24, 16), color=(220, 80, 30)) as image:
        image.save(output, format="PNG")
    return output.getvalue()


async def _create_completed_upload(
    client: AsyncClient,
    storage: InMemoryObjectStorage,
    headers: dict[str, str],
    content: bytes,
) -> dict[str, object]:
    created = await client.post(
        "/api/v1/recognition-uploads",
        headers=headers,
        json={
            "contentType": "image/png",
            "sizeBytes": len(content),
            "checksumSha256": hashlib.sha256(content).hexdigest(),
        },
    )
    assert created.status_code == 201, created.text
    payload = created.json()
    object_key = payload["objectKey"]
    assert isinstance(object_key, str)
    assert object_key.startswith("recognition/incoming/")
    await storage.put_uploaded(key=object_key, content=content, content_type="image/png")
    completed = await client.post(
        f"/api/v1/recognition-uploads/{payload['uploadSessionId']}/complete",
        headers=headers,
    )
    assert completed.status_code == 200, completed.text
    return cast(dict[str, object], completed.json())


async def test_upload_recognition_idempotency_isolation_and_correction(
    client: AsyncClient,
    recognition_storage: InMemoryObjectStorage,
    recognition_repository: InMemoryRecognitionRepository,
    recognition_dispatcher: RecordingRecognitionDispatcher,
) -> None:
    first_session, _ = await sign_in(client, idempotency_key="recognition-user-one")
    second_session, _ = await sign_in(
        client,
        phone_number="+971502222222",
        idempotency_key="recognition-user-two",
    )
    first_tokens = first_session["tokens"]
    second_tokens = second_session["tokens"]
    assert isinstance(first_tokens, dict)
    assert isinstance(second_tokens, dict)
    first_headers = bearer(first_tokens["accessToken"])
    second_headers = bearer(second_tokens["accessToken"])

    completed = await _create_completed_upload(client, recognition_storage, first_headers, _png())
    source_key = completed["sourceObjectKey"]
    assert isinstance(source_key, str)
    sanitized = recognition_storage.get_for_test(source_key)
    assert sanitized is not None
    with Image.open(BytesIO(sanitized[0])) as decoded:
        decoded.verify()

    create_payload = {"uploadSessionId": completed["uploadSessionId"]}
    request_headers = {**first_headers, "Idempotency-Key": "recognition-create-001"}
    first = await client.post("/api/v1/recognitions", headers=request_headers, json=create_payload)
    replay = await client.post("/api/v1/recognitions", headers=request_headers, json=create_payload)
    assert first.status_code == replay.status_code == 202
    assert first.json()["id"] == replay.json()["id"]
    assert recognition_dispatcher.enqueued == [UUID(first.json()["id"]), UUID(first.json()["id"])]

    job_id = UUID(first.json()["id"])
    assert (
        await client.get(f"/api/v1/recognitions/{job_id}", headers=second_headers)
    ).status_code == 404

    first_user = first_session["user"]
    assert isinstance(first_user, dict)
    user_id = UUID(str(first_user["id"]))
    queued = recognition_repository._jobs[(user_id, job_id)]
    recognition_repository._jobs[(user_id, job_id)] = replace(
        queued,
        status=RecognitionStatus.NEEDS_REVIEW,
        overall_confidence_milli=520,
        needs_review_reason="low_confidence",
        items=(
            RecognitionItem(
                id=uuid4(),
                position=0,
                name="Possible dish",
                canonical_food_id=None,
                serving_milli=250_000,
                energy_kcal=400,
                protein_mg=10_000,
                carbs_mg=50_000,
                fat_mg=12_000,
                confidence_milli=520,
                alternatives=(RecognitionAlternative("Alternative", 300),),
                is_user_corrected=False,
            ),
        ),
    )
    corrected_item_id = uuid4()
    corrected = await client.put(
        f"/api/v1/recognitions/{job_id}/correction",
        headers=first_headers,
        json={
            "expectedVersion": 1,
            "items": [
                {
                    "id": str(corrected_item_id),
                    "name": "User corrected dish",
                    "canonicalFoodId": " corrected-dish ",
                    "servingMilli": 300000,
                    "energyKcal": 450,
                    "proteinMg": 12000,
                    "carbsMg": 55000,
                    "fatMg": 14000,
                }
            ],
        },
    )
    assert corrected.status_code == 200, corrected.text
    assert corrected.json()["status"] == "succeeded"
    assert corrected.json()["items"][0]["isUserCorrected"] is True
    assert corrected.json()["items"][0]["canonicalFoodId"] == "corrected-dish"
    assert corrected.json()["version"] == 2


async def test_invalid_upload_is_rejected_and_not_left_in_storage(
    client: AsyncClient,
    recognition_storage: InMemoryObjectStorage,
) -> None:
    session, _ = await sign_in(client, idempotency_key="invalid-image-user")
    tokens = session["tokens"]
    assert isinstance(tokens, dict)
    headers = bearer(tokens["accessToken"])
    content = b"not-a-real-png"
    created = await client.post(
        "/api/v1/recognition-uploads",
        headers=headers,
        json={
            "contentType": "image/png",
            "sizeBytes": len(content),
            "checksumSha256": hashlib.sha256(content).hexdigest(),
        },
    )
    object_key = created.json()["objectKey"]
    await recognition_storage.put_uploaded(
        key=object_key,
        content=content,
        content_type="image/png",
    )
    completed = await client.post(
        f"/api/v1/recognition-uploads/{created.json()['uploadSessionId']}/complete",
        headers=headers,
    )
    assert completed.status_code == 422
    assert completed.json()["code"] == "invalid_image"
    assert recognition_storage.get_for_test(object_key) is None
