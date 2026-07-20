import asyncio
import os
from collections.abc import AsyncIterator, Awaitable
from typing import cast
from uuid import uuid4

import pytest
import pytest_asyncio
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from pydantic import SecretStr
from redis.asyncio import Redis
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine

from ordin.api.main import create_app
from ordin.infrastructure.config import Settings
from ordin.infrastructure.container import AppContainer, build_default_container
from tests.helpers import bearer, request_challenge, sign_in
from tests.integration.test_records_api import _meal_operation, _preferences_operation

pytestmark = [
    pytest.mark.external,
    pytest.mark.skipif(
        os.getenv("ORDIN_RUN_EXTERNAL_TESTS") != "1",
        reason="set ORDIN_RUN_EXTERNAL_TESTS=1 with Docker dependencies running",
    ),
]

TEST_DATABASE_URL = os.getenv(
    "ORDIN_TEST_DATABASE_URL",
    "postgresql+psycopg://ordin:ordin@127.0.0.1:55432/ordin_test",
)
TEST_REDIS_URL = os.getenv("ORDIN_TEST_REDIS_URL", "redis://127.0.0.1:6379/15")


@pytest_asyncio.fixture
async def external_container() -> AsyncIterator[AppContainer]:
    engine = create_async_engine(TEST_DATABASE_URL)
    redis = Redis.from_url(TEST_REDIS_URL, decode_responses=True)
    async with engine.begin() as connection:
        users_table = await connection.scalar(text("SELECT to_regclass('public.users')"))
        if users_table is None:
            pytest.fail("run Alembic against ORDIN_TEST_DATABASE_URL before external tests")
        await connection.execute(
            text(
                "TRUNCATE TABLE account_object_cleanups, sync_operations, meal_items, "
                "meal_logs, fasting_sessions, "
                "user_preferences, sessions, health_profiles, devices, auth_identities, "
                "users CASCADE"
            )
        )
    await redis.flushdb()
    await redis.aclose()
    await engine.dispose()

    settings = Settings(
        environment="test",
        database_url=TEST_DATABASE_URL,
        redis_url=TEST_REDIS_URL,
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
async def external_client(external_container: AppContainer) -> AsyncIterator[AsyncClient]:
    app: FastAPI = create_app(external_container.settings, external_container)
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        yield client


async def test_postgres_redis_auth_profile_and_rotation(
    external_client: AsyncClient,
) -> None:
    signed_in, installation_id = await sign_in(external_client)
    tokens = signed_in["tokens"]
    assert isinstance(tokens, dict)
    headers = bearer(tokens["accessToken"])

    updated = await external_client.patch(
        "/api/v1/users/me",
        headers=headers,
        json={"expectedVersion": 1, "nickname": "Database user"},
    )
    assert updated.status_code == 200

    profile = await external_client.put(
        "/api/v1/users/me/health-profile",
        headers=headers,
        json={
            "expectedVersion": 0,
            "heightCm": "168.50",
            "currentWeightKg": "60.25",
            "goalType": "maintain",
        },
    )
    assert profile.status_code == 200
    assert profile.json()["heightCm"] == "168.50"

    rotated = await external_client.post(
        "/api/v1/auth/token/refresh",
        json={
            "refreshToken": tokens["refreshToken"],
            "deviceInstallationId": str(installation_id),
        },
    )
    assert rotated.status_code == 200
    assert (
        await external_client.get(
            "/api/v1/users/me",
            headers=bearer(tokens["accessToken"]),
        )
    ).status_code == 401
    assert (
        await external_client.get(
            "/api/v1/users/me",
            headers=bearer(rotated.json()["accessToken"]),
        )
    ).status_code == 200


async def test_redis_challenge_contains_only_identity_hash(
    external_client: AsyncClient,
) -> None:
    phone_number = "+971509999999"
    await request_challenge(
        external_client,
        phone_number=phone_number,
        idempotency_key="redis-security-key",
    )
    redis = Redis.from_url(TEST_REDIS_URL, decode_responses=True)
    try:
        keys = await cast(
            Awaitable[list[str]],
            redis.keys("ordin:otp:challenge:*"),
        )
        assert len(keys) == 1
        payload = await cast(
            Awaitable[dict[str, str]],
            redis.hgetall(keys[0]),
        )
    finally:
        await redis.aclose()

    assert "identity_subject_hash" in payload
    assert "phone" not in payload
    assert phone_number not in repr(payload)
    assert "123456" not in repr(payload)


async def test_postgres_sync_is_concurrent_idempotent_and_user_isolated(
    external_client: AsyncClient,
) -> None:
    first, _ = await sign_in(
        external_client,
        phone_number="+971501111111",
        idempotency_key="external-record-user-one",
    )
    second, _ = await sign_in(
        external_client,
        phone_number="+971502222222",
        idempotency_key="external-record-user-two",
    )
    first_tokens = first["tokens"]
    second_tokens = second["tokens"]
    assert isinstance(first_tokens, dict)
    assert isinstance(second_tokens, dict)
    first_headers = bearer(first_tokens["accessToken"])
    second_headers = bearer(second_tokens["accessToken"])

    meal_id = uuid4()
    operation = _meal_operation(entity_id=meal_id)
    first_write, concurrent_replay = await asyncio.gather(
        external_client.post(
            "/api/v1/sync/push",
            headers=first_headers,
            json={"operations": [operation]},
        ),
        external_client.post(
            "/api/v1/sync/push",
            headers=first_headers,
            json={"operations": [operation]},
        ),
    )
    assert first_write.status_code == concurrent_replay.status_code == 200
    results = [first_write.json()["results"][0], concurrent_replay.json()["results"][0]]
    assert sorted(result["replayed"] for result in results) == [False, True]
    assert {result["changeCursor"] for result in results} == {results[0]["changeCursor"]}

    preferences = await external_client.post(
        "/api/v1/sync/push",
        headers=first_headers,
        json={"operations": [_preferences_operation()]},
    )
    assert preferences.status_code == 200
    pulled = await external_client.get("/api/v1/sync/pull", headers=first_headers)
    assert [change["entityType"] for change in pulled.json()["changes"]] == [
        "mealLog",
        "appPreferences",
    ]
    assert (
        await external_client.get(f"/api/v1/meals/{meal_id}", headers=second_headers)
    ).status_code == 404
    assert (await external_client.get("/api/v1/sync/pull", headers=second_headers)).json()[
        "changes"
    ] == []

    engine = create_async_engine(TEST_DATABASE_URL)
    async with engine.connect() as connection:
        meal_count = await connection.scalar(
            text("SELECT count(*) FROM meal_logs WHERE id = :meal_id"),
            {"meal_id": meal_id},
        )
        receipt_count = await connection.scalar(
            text(
                "SELECT count(*) FROM sync_operations "
                "WHERE entity_type = 'mealLog' AND entity_id = :meal_id"
            ),
            {"meal_id": str(meal_id)},
        )
        request_hash = await connection.scalar(
            text(
                "SELECT request_hash FROM sync_operations "
                "WHERE entity_type = 'mealLog' AND entity_id = :meal_id"
            ),
            {"meal_id": str(meal_id)},
        )
    await engine.dispose()
    assert meal_count == receipt_count == 1
    assert isinstance(request_hash, str) and len(request_hash) == 64
    assert "+971" not in request_hash


async def test_alembic_schema_contains_security_constraints() -> None:
    engine = create_async_engine(TEST_DATABASE_URL)
    async with engine.connect() as connection:
        tables = set(
            await connection.scalars(
                text(
                    "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'"
                )
            )
        )
        constraints = set(
            await connection.scalars(
                text(
                    "SELECT constraint_name FROM information_schema.table_constraints "
                    "WHERE table_schema = 'public'"
                )
            )
        )
    await engine.dispose()

    assert {
        "users",
        "auth_identities",
        "devices",
        "sessions",
        "health_profiles",
        "meal_logs",
        "meal_items",
        "fasting_sessions",
        "user_preferences",
        "sync_operations",
    } <= tables
    assert "uq_auth_identities_provider_subject" in constraints
    assert "uq_sessions_refresh_token_hash" in constraints
    assert "pk_sync_operations" in constraints
    assert "fk_meal_items_user_id_meal_logs" in constraints

    engine = create_async_engine(TEST_DATABASE_URL)
    async with engine.connect() as connection:
        sequence = await connection.scalar(
            text("SELECT to_regclass('public.ordin_sync_revision_seq')")
        )
        active_index = await connection.scalar(
            text(
                "SELECT indexname FROM pg_indexes WHERE schemaname = 'public' "
                "AND indexname = 'uq_fasting_sessions_user_active'"
            )
        )
    await engine.dispose()
    assert sequence == "ordin_sync_revision_seq"
    assert active_index == "uq_fasting_sessions_user_active"
