from httpx import AsyncClient


async def test_health_returns_typed_success(client: AsyncClient) -> None:
    response = await client.get("/api/v1/health")

    assert response.status_code == 200
    assert response.headers["content-type"] == "application/json"
    assert response.json() == {"status": "ok"}


async def test_readiness_checks_application_dependencies(client: AsyncClient) -> None:
    response = await client.get("/api/v1/ready")

    assert response.status_code == 200
    assert response.json() == {"status": "ready"}


async def test_request_id_is_sanitized_and_returned(client: AsyncClient) -> None:
    accepted = await client.get(
        "/api/v1/health",
        headers={"X-Request-ID": "mobile-request.123"},
    )
    rejected = await client.get(
        "/api/v1/health",
        headers={"X-Request-ID": "unsafe request id with spaces"},
    )

    assert accepted.headers["x-request-id"] == "mobile-request.123"
    assert rejected.headers["x-request-id"] != "unsafe request id with spaces"
