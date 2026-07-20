import os
from collections.abc import AsyncIterator, Awaitable
from typing import cast

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
                "TRUNCATE TABLE sessions, health_profiles, devices, auth_identities, users CASCADE"
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

    assert {"users", "auth_identities", "devices", "sessions", "health_profiles"} <= tables
    assert "uq_auth_identities_provider_subject" in constraints
    assert "uq_sessions_refresh_token_hash" in constraints
