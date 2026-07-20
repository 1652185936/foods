import hashlib
import os
from collections.abc import AsyncIterator
from datetime import UTC, datetime, timedelta
from io import BytesIO
from uuid import UUID, uuid4

import httpx
import pytest
import pytest_asyncio
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from PIL import Image
from pydantic import SecretStr
from redis.asyncio import Redis
from sqlalchemy import create_engine, text
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy.orm import sessionmaker

from ordin.api.main import create_app
from ordin.core.clock import SystemClock
from ordin.infrastructure.config import Settings
from ordin.infrastructure.container import AppContainer, build_default_container
from ordin.infrastructure.database.account_repository import (
    SqlAlchemyWorkerAccountCleanupRepository,
)
from ordin.infrastructure.database.recognition_repository import (
    SqlAlchemyWorkerRecognitionRepository,
)
from ordin.infrastructure.object_storage.s3 import (
    S3SyncObjectStorage,
    build_s3_client,
)
from ordin.infrastructure.recognition_provider import (
    DeterministicDevelopmentRecognitionProvider,
)
from ordin.modules.recognition.errors import ObjectNotFoundError, ObjectStorageUnavailableError
from ordin.worker.recognition_service import RecognitionWorkerService
from tests.helpers import bearer, sign_in
from tests.integration.test_records_api import (
    _fasting_operation,
    _meal_operation,
    _preferences_operation,
)

pytestmark = [
    pytest.mark.external,
    pytest.mark.recognition_external,
    pytest.mark.skipif(
        os.getenv("ORDIN_RUN_RECOGNITION_EXTERNAL_TESTS") != "1",
        reason="set ORDIN_RUN_RECOGNITION_EXTERNAL_TESTS=1 with Docker dependencies running",
    ),
]

TEST_DATABASE_URL = os.getenv(
    "ORDIN_TEST_DATABASE_URL",
    "postgresql+psycopg://ordin:ordin@127.0.0.1:55432/ordin_test",
)
TEST_REDIS_URL = os.getenv("ORDIN_TEST_REDIS_URL", "redis://127.0.0.1:6379/15")
TEST_CELERY_BROKER_URL = os.getenv(
    "ORDIN_TEST_CELERY_BROKER_URL",
    "redis://127.0.0.1:6379/14",
)


@pytest_asyncio.fixture
async def recognition_external_container() -> AsyncIterator[AppContainer]:
    engine = create_async_engine(TEST_DATABASE_URL)
    redis = Redis.from_url(TEST_REDIS_URL, decode_responses=True)
    broker = Redis.from_url(TEST_CELERY_BROKER_URL, decode_responses=True)
    async with engine.begin() as connection:
        await connection.execute(
            text(
                "TRUNCATE TABLE account_object_cleanups, recognition_corrections, "
                "recognition_items, recognition_jobs, "
                "recognition_uploads, sessions, health_profiles, devices, auth_identities, "
                "users CASCADE"
            )
        )
    await redis.flushdb()
    await redis.aclose()
    await broker.flushdb()
    await broker.aclose()
    await engine.dispose()
    settings = Settings(
        environment="test",
        database_url=TEST_DATABASE_URL,
        redis_url=TEST_REDIS_URL,
        celery_broker_url=TEST_CELERY_BROKER_URL,
        development_otp_code=SecretStr("123456"),
        otp_phone_limit=20,
        otp_device_limit=20,
        otp_ip_limit=20,
    )
    container = build_default_container(settings)
    try:
        yield container
    finally:
        await container.close()


@pytest_asyncio.fixture
async def recognition_external_client(
    recognition_external_container: AppContainer,
) -> AsyncIterator[AsyncClient]:
    application: FastAPI = create_app(
        recognition_external_container.settings,
        recognition_external_container,
    )
    async with AsyncClient(
        transport=ASGITransport(app=application),
        base_url="http://testserver",
    ) as client:
        yield client


async def test_minio_postgres_and_worker_recognition_round_trip(
    recognition_external_client: AsyncClient,
    recognition_external_container: AppContainer,
) -> None:
    source = BytesIO()
    with Image.new("RGB", (32, 24), color=(210, 75, 25)) as image:
        image.save(source, format="JPEG")
    content = source.getvalue()
    signed_in, _ = await sign_in(
        recognition_external_client,
        idempotency_key="external-recognition-user",
    )
    tokens = signed_in["tokens"]
    assert isinstance(tokens, dict)
    headers = bearer(tokens["accessToken"])

    upload = await recognition_external_client.post(
        "/api/v1/recognition-uploads",
        headers=headers,
        json={
            "contentType": "image/jpeg",
            "sizeBytes": len(content),
            "checksumSha256": hashlib.sha256(content).hexdigest(),
        },
    )
    assert upload.status_code == 201, upload.text
    upload_payload = upload.json()
    async with httpx.AsyncClient() as storage_client:
        stored = await storage_client.put(
            upload_payload["uploadUrl"],
            headers=upload_payload["uploadHeaders"],
            content=content,
        )
    assert stored.status_code in {200, 204}, stored.text
    completed = await recognition_external_client.post(
        f"/api/v1/recognition-uploads/{upload_payload['uploadSessionId']}/complete",
        headers=headers,
    )
    assert completed.status_code == 200, completed.text

    queued = await recognition_external_client.post(
        "/api/v1/recognitions",
        headers={**headers, "Idempotency-Key": "external-recognition-job"},
        json={"uploadSessionId": upload_payload["uploadSessionId"]},
    )
    assert queued.status_code == 202, queued.text
    job_id = UUID(queued.json()["id"])

    settings = recognition_external_container.settings
    sync_engine = create_engine(settings.database_url, pool_pre_ping=True, hide_parameters=True)
    s3_client = build_s3_client(
        endpoint_url=str(settings.s3_endpoint_url),
        region=settings.s3_region,
        access_key_id=settings.s3_access_key_id.get_secret_value(),
        secret_access_key=settings.s3_secret_access_key.get_secret_value(),
        force_path_style=settings.s3_force_path_style,
    )
    worker = RecognitionWorkerService(
        repository=SqlAlchemyWorkerRecognitionRepository(
            sessionmaker(sync_engine, expire_on_commit=False)
        ),
        storage=S3SyncObjectStorage(s3_client, bucket=settings.s3_bucket),
        provider=DeterministicDevelopmentRecognitionProvider(),
        clock=SystemClock(),
        max_image_bytes=settings.recognition_max_image_bytes,
        confidence_threshold_milli=settings.recognition_confidence_threshold_milli,
        claim_lease_seconds=settings.recognition_claim_lease_seconds,
    )
    try:
        assert worker.process(job_id) is True
    finally:
        s3_client.close()
        sync_engine.dispose()

    result = await recognition_external_client.get(
        f"/api/v1/recognitions/{job_id}",
        headers=headers,
    )
    assert result.status_code == 200
    assert result.json()["status"] == "succeeded"
    assert result.json()["providerName"] == "development-deterministic"
    assert len(result.json()["items"]) == 1


async def test_consumed_upload_retries_raw_object_cleanup_without_losing_state(
    recognition_external_client: AsyncClient,
    recognition_external_container: AppContainer,
) -> None:
    source = BytesIO()
    with Image.new("RGB", (24, 16), color=(70, 120, 45)) as image:
        image.save(source, format="JPEG")
    content = source.getvalue()
    signed_in, _ = await sign_in(
        recognition_external_client,
        idempotency_key="external-incoming-cleanup-user",
    )
    tokens = signed_in["tokens"]
    assert isinstance(tokens, dict)
    headers = bearer(tokens["accessToken"])
    upload = await recognition_external_client.post(
        "/api/v1/recognition-uploads",
        headers=headers,
        json={
            "contentType": "image/jpeg",
            "sizeBytes": len(content),
            "checksumSha256": hashlib.sha256(content).hexdigest(),
        },
    )
    assert upload.status_code == 201
    upload_payload = upload.json()
    async with httpx.AsyncClient() as storage_client:
        stored = await storage_client.put(
            upload_payload["uploadUrl"],
            headers=upload_payload["uploadHeaders"],
            content=content,
        )
    assert stored.status_code in {200, 204}
    completed = await recognition_external_client.post(
        f"/api/v1/recognition-uploads/{upload_payload['uploadSessionId']}/complete",
        headers=headers,
    )
    assert completed.status_code == 200
    queued = await recognition_external_client.post(
        "/api/v1/recognitions",
        headers={**headers, "Idempotency-Key": "external-incoming-cleanup-job"},
        json={"uploadSessionId": upload_payload["uploadSessionId"]},
    )
    assert queued.status_code == 202

    settings = recognition_external_container.settings
    engine = create_engine(settings.database_url, pool_pre_ping=True, hide_parameters=True)
    factory = sessionmaker(engine, expire_on_commit=False)
    s3_client = build_s3_client(
        endpoint_url=str(settings.s3_endpoint_url),
        region=settings.s3_region,
        access_key_id=settings.s3_access_key_id.get_secret_value(),
        secret_access_key=settings.s3_secret_access_key.get_secret_value(),
        force_path_style=settings.s3_force_path_style,
    )
    incoming_key = upload_payload["objectKey"]
    sanitized_key = completed.json()["sourceObjectKey"]
    s3_client.put_object(Bucket=settings.s3_bucket, Key=incoming_key, Body=content)
    with engine.connect() as connection:
        expires_at = connection.scalar(
            text("SELECT expires_at FROM recognition_uploads WHERE id = :upload_id"),
            {"upload_id": UUID(upload_payload["uploadSessionId"])},
        )
        durable_cleanup = connection.execute(
            text(
                "SELECT next_attempt_at, completed_at FROM account_object_cleanups "
                "WHERE object_key = :object_key"
            ),
            {"object_key": sanitized_key},
        ).one()
    assert isinstance(expires_at, datetime)
    assert durable_cleanup.next_attempt_at > expires_at
    assert durable_cleanup.completed_at is None
    clock = _MutableClock()
    clock.current = expires_at + timedelta(seconds=1)
    storage = S3SyncObjectStorage(s3_client, bucket=settings.s3_bucket)
    worker = RecognitionWorkerService(
        repository=SqlAlchemyWorkerRecognitionRepository(factory),
        storage=storage,
        provider=DeterministicDevelopmentRecognitionProvider(),
        clock=clock,
        max_image_bytes=settings.recognition_max_image_bytes,
        confidence_threshold_milli=settings.recognition_confidence_threshold_milli,
        claim_lease_seconds=settings.recognition_claim_lease_seconds,
    )
    try:
        assert worker.cleanup_expired_sources() == 1
        with pytest.raises(ObjectNotFoundError):
            storage.read(incoming_key, max_bytes=len(content) + 1)
        with engine.connect() as connection:
            state = connection.execute(
                text(
                    "SELECT status, incoming_deleted_at FROM recognition_uploads "
                    "WHERE id = :upload_id"
                ),
                {"upload_id": UUID(upload_payload["uploadSessionId"])},
            ).one()
        assert state.status == "consumed"
        assert state.incoming_deleted_at is not None
    finally:
        s3_client.close()
        engine.dispose()


async def test_account_delete_cascades_postgres_and_cleans_minio(
    recognition_external_client: AsyncClient,
    recognition_external_container: AppContainer,
) -> None:
    phone = "+971507777777"
    first, first_installation = await sign_in(
        recognition_external_client,
        phone_number=phone,
        idempotency_key="external-account-delete-one",
    )
    second, second_installation = await sign_in(
        recognition_external_client,
        phone_number=phone,
        idempotency_key="external-account-delete-two",
    )
    first_tokens = first["tokens"]
    second_tokens = second["tokens"]
    first_user = first["user"]
    assert isinstance(first_tokens, dict)
    assert isinstance(second_tokens, dict)
    assert isinstance(first_user, dict)
    user_id = UUID(str(first_user["id"]))
    headers = bearer(first_tokens["accessToken"])

    profile = await recognition_external_client.put(
        "/api/v1/users/me/health-profile",
        headers=headers,
        json={"expectedVersion": 0, "currentWeightKg": "70.25"},
    )
    assert profile.status_code == 200
    records = await recognition_external_client.post(
        "/api/v1/sync/push",
        headers=headers,
        json={
            "operations": [
                _meal_operation(entity_id=uuid4()),
                _fasting_operation(entity_id=uuid4()),
                _preferences_operation(),
            ]
        },
    )
    assert records.status_code == 200

    source = BytesIO()
    with Image.new("RGB", (32, 24), color=(180, 85, 35)) as image:
        image.save(source, format="JPEG")
    content = source.getvalue()
    upload = await recognition_external_client.post(
        "/api/v1/recognition-uploads",
        headers=headers,
        json={
            "contentType": "image/jpeg",
            "sizeBytes": len(content),
            "checksumSha256": hashlib.sha256(content).hexdigest(),
        },
    )
    assert upload.status_code == 201
    upload_payload = upload.json()
    async with httpx.AsyncClient() as storage_client:
        stored = await storage_client.put(
            upload_payload["uploadUrl"],
            headers=upload_payload["uploadHeaders"],
            content=content,
        )
    assert stored.status_code in {200, 204}
    completed = await recognition_external_client.post(
        f"/api/v1/recognition-uploads/{upload_payload['uploadSessionId']}/complete",
        headers=headers,
    )
    assert completed.status_code == 200
    sanitized_key = completed.json()["sourceObjectKey"]
    incoming_key = upload_payload["objectKey"]
    queued = await recognition_external_client.post(
        "/api/v1/recognitions",
        headers={**headers, "Idempotency-Key": "external-account-delete-recognition"},
        json={"uploadSessionId": upload_payload["uploadSessionId"]},
    )
    assert queued.status_code == 202

    settings = recognition_external_container.settings
    sync_engine = create_engine(settings.database_url, pool_pre_ping=True, hide_parameters=True)
    s3_client = build_s3_client(
        endpoint_url=str(settings.s3_endpoint_url),
        region=settings.s3_region,
        access_key_id=settings.s3_access_key_id.get_secret_value(),
        secret_access_key=settings.s3_secret_access_key.get_secret_value(),
        force_path_style=settings.s3_force_path_style,
    )
    sync_storage = S3SyncObjectStorage(s3_client, bucket=settings.s3_bucket)
    worker = RecognitionWorkerService(
        repository=SqlAlchemyWorkerRecognitionRepository(
            sessionmaker(sync_engine, expire_on_commit=False)
        ),
        storage=sync_storage,
        provider=DeterministicDevelopmentRecognitionProvider(),
        clock=SystemClock(),
        max_image_bytes=settings.recognition_max_image_bytes,
        confidence_threshold_milli=settings.recognition_confidence_threshold_milli,
        claim_lease_seconds=settings.recognition_claim_lease_seconds,
    )
    job_id = UUID(queued.json()["id"])
    assert worker.process(job_id) is True
    result = await recognition_external_client.get(
        f"/api/v1/recognitions/{job_id}",
        headers=headers,
    )
    assert result.status_code == 200
    correction_item = result.json()["items"][0]
    corrected = await recognition_external_client.put(
        f"/api/v1/recognitions/{job_id}/correction",
        headers=headers,
        json={
            "expectedVersion": result.json()["version"],
            "items": [
                {
                    "id": correction_item["id"],
                    "name": "Reviewed external dish",
                    "servingMilli": correction_item["servingMilli"],
                    "energyKcal": correction_item["energyKcal"],
                    "proteinMg": correction_item["proteinMg"],
                    "carbsMg": correction_item["carbsMg"],
                    "fatMg": correction_item["fatMg"],
                }
            ],
        },
    )
    assert corrected.status_code == 200

    exported = await recognition_external_client.get(
        "/api/v1/users/me/data-export",
        headers=headers,
    )
    assert exported.status_code == 200, exported.text
    exported_payload = exported.json()
    assert exported_payload["schemaVersion"] == 1
    assert len(exported_payload["meals"]) == 1
    assert len(exported_payload["fastingSessions"]) == 1
    assert (
        exported_payload["recognitions"][0]["corrections"][0]["items"][0]["name"]
        == "Reviewed external dish"
    )
    assert incoming_key not in exported.text
    assert sanitized_key not in exported.text
    assert "objectKey" not in exported.text
    assert "imageReference" not in exported.text

    isolated_user, _ = await sign_in(
        recognition_external_client,
        phone_number="+971508888888",
        idempotency_key="external-account-export-isolated",
    )
    isolated_tokens = isolated_user["tokens"]
    assert isinstance(isolated_tokens, dict)
    isolated_export = await recognition_external_client.get(
        "/api/v1/users/me/data-export",
        headers=bearer(isolated_tokens["accessToken"]),
    )
    assert isolated_export.status_code == 200
    assert isolated_export.json()["meals"] == []
    assert isolated_export.json()["recognitions"] == []

    deleted = await recognition_external_client.request(
        "DELETE",
        "/api/v1/users/me",
        headers=headers,
        json={
            "confirmation": "DELETE_MY_ACCOUNT",
            "refreshToken": first_tokens["refreshToken"],
            "deviceInstallationId": str(first_installation),
        },
    )
    assert deleted.status_code == 204
    assert (
        await recognition_external_client.get("/api/v1/users/me", headers=headers)
    ).status_code == 401
    assert (
        await recognition_external_client.get(
            "/api/v1/users/me",
            headers=bearer(second_tokens["accessToken"]),
        )
    ).status_code == 401
    for tokens, installation_id in (
        (first_tokens, first_installation),
        (second_tokens, second_installation),
    ):
        refresh = await recognition_external_client.post(
            "/api/v1/auth/token/refresh",
            json={
                "refreshToken": tokens["refreshToken"],
                "deviceInstallationId": str(installation_id),
            },
        )
        assert refresh.status_code == 401

    async_engine = create_async_engine(TEST_DATABASE_URL)
    async with async_engine.connect() as connection:
        counts = {
            table: await connection.scalar(
                text(f"SELECT count(*) FROM {table} WHERE user_id = :user_id"),
                {"user_id": user_id},
            )
            for table in (
                "auth_identities",
                "devices",
                "sessions",
                "health_profiles",
                "meal_logs",
                "meal_items",
                "fasting_sessions",
                "user_preferences",
                "sync_operations",
                "recognition_uploads",
                "recognition_jobs",
                "recognition_items",
                "recognition_corrections",
            )
        }
        queue_rows = await connection.execute(
            text(
                "SELECT object_key, completed_at FROM account_object_cleanups "
                "WHERE object_key IN (:incoming_key, :sanitized_key)"
            ),
            {"incoming_key": incoming_key, "sanitized_key": sanitized_key},
        )
        queued_cleanups = list(queue_rows)
    await async_engine.dispose()
    assert set(counts.values()) == {0}
    assert len(queued_cleanups) == 2
    assert all(row.completed_at is not None for row in queued_cleanups)
    with pytest.raises(ObjectNotFoundError):
        sync_storage.read(incoming_key, max_bytes=1024)
    with pytest.raises(ObjectNotFoundError):
        sync_storage.read(sanitized_key, max_bytes=1024)

    registered_again, _ = await sign_in(
        recognition_external_client,
        phone_number=phone,
        idempotency_key="external-account-delete-register-again",
    )
    registered_user = registered_again["user"]
    assert isinstance(registered_user, dict)
    assert registered_user["id"] != str(user_id)
    s3_client.close()
    sync_engine.dispose()


class _MutableClock:
    def __init__(self) -> None:
        self.current = datetime(2026, 7, 21, 0, tzinfo=UTC)

    def now(self) -> datetime:
        return self.current


class _FailingStorage:
    def __init__(self, storage: S3SyncObjectStorage, failing_key: str) -> None:
        self.storage = storage
        self.failing_key = failing_key
        self.failed = True

    def read(self, key: str, *, max_bytes: int) -> bytes:
        return self.storage.read(key, max_bytes=max_bytes)

    def delete(self, key: str) -> None:
        if self.failed and key == self.failing_key:
            raise ObjectStorageUnavailableError
        self.storage.delete(key)


def test_postgres_cleanup_queue_retries_minio_failure_and_accepts_missing_object() -> None:
    settings = Settings(environment="test", database_url=TEST_DATABASE_URL)
    engine = create_engine(settings.database_url, pool_pre_ping=True, hide_parameters=True)
    factory = sessionmaker(engine, expire_on_commit=False)
    s3_client = build_s3_client(
        endpoint_url=str(settings.s3_endpoint_url),
        region=settings.s3_region,
        access_key_id=settings.s3_access_key_id.get_secret_value(),
        secret_access_key=settings.s3_secret_access_key.get_secret_value(),
        force_path_style=settings.s3_force_path_style,
    )
    storage = S3SyncObjectStorage(s3_client, bucket=settings.s3_bucket)
    existing_key = f"recognition/source/cleanup-{uuid4().hex}.jpg"
    missing_key = f"recognition/source/missing-{uuid4().hex}.jpg"
    failing_key = f"recognition/source/retry-{uuid4().hex}.jpg"
    s3_client.put_object(Bucket=settings.s3_bucket, Key=existing_key, Body=b"existing")
    s3_client.put_object(Bucket=settings.s3_bucket, Key=failing_key, Body=b"retry")
    cleanup_ids = [uuid4(), uuid4(), uuid4()]
    clock = _MutableClock()
    with engine.begin() as connection:
        connection.execute(text("DELETE FROM account_object_cleanups"))
        for cleanup_id, object_key in zip(
            cleanup_ids,
            (existing_key, missing_key, failing_key),
            strict=True,
        ):
            connection.execute(
                text(
                    "INSERT INTO account_object_cleanups "
                    "(id, batch_id, object_key, attempt_count, queued_at, next_attempt_at) "
                    "VALUES (:id, :batch_id, :object_key, 0, :now, :now)"
                ),
                {
                    "id": cleanup_id,
                    "batch_id": uuid4(),
                    "object_key": object_key,
                    "now": clock.now(),
                },
            )
    failing_storage = _FailingStorage(storage, failing_key)
    worker = RecognitionWorkerService(
        repository=SqlAlchemyWorkerRecognitionRepository(factory),
        storage=failing_storage,
        provider=DeterministicDevelopmentRecognitionProvider(),
        clock=clock,
        max_image_bytes=settings.recognition_max_image_bytes,
        confidence_threshold_milli=settings.recognition_confidence_threshold_milli,
        claim_lease_seconds=settings.recognition_claim_lease_seconds,
        account_cleanup_repository=SqlAlchemyWorkerAccountCleanupRepository(factory),
        account_cleanup_batch_size=10,
        account_cleanup_claim_lease_seconds=300,
    )
    try:
        assert worker.cleanup_deleted_account_objects() == 2
        with engine.connect() as connection:
            rows = list(
                connection.execute(
                    text("SELECT id, attempt_count, completed_at FROM account_object_cleanups")
                )
            )
        states = {row.id: row for row in rows}
        assert states[cleanup_ids[0]].completed_at is not None
        assert states[cleanup_ids[1]].completed_at is not None
        assert states[cleanup_ids[2]].completed_at is None
        assert states[cleanup_ids[2]].attempt_count == 1

        failing_storage.failed = False
        clock.current += timedelta(hours=2)
        assert worker.cleanup_deleted_account_objects() == 1
        with engine.connect() as connection:
            completed_at = connection.scalar(
                text("SELECT completed_at FROM account_object_cleanups WHERE id = :id"),
                {"id": cleanup_ids[2]},
            )
        assert completed_at is not None
    finally:
        s3_client.close()
        engine.dispose()
