# Ordin Server

FastAPI service for account sessions and health-profile data. PostgreSQL is the
source of truth, while Redis stores short-lived OTP challenges and rate limits.

## Local setup

Run Compose from the repository root, then all Python commands from this
directory:

```powershell
docker compose up -d postgres redis
cd server
Copy-Item .env.example .env
uv sync --locked --all-groups
uv run --locked alembic upgrade head
uv run --locked ordin-api
```

The development OTP code has no source-code default. It must be provided through
`ORDIN_DEVELOPMENT_OTP_CODE` in the local `.env`. Development/test OTP mode may
only bind to a loopback address unless the CLI's explicit unsafe LAN-development
override is present.

Useful endpoints:

- `GET /api/v1/health`: process liveness
- `GET /api/v1/ready`: PostgreSQL and Redis readiness
- `GET /docs`: development/test OpenAPI UI

## Verification

```powershell
uv lock --check
uv run --locked ruff format --check .
uv run --locked ruff check .
uv run --locked mypy src tests scripts
uv run --locked pytest
uv run --locked python scripts/export_openapi.py --check
$env:ORDIN_RUN_EXTERNAL_TESTS='1'
uv run --locked pytest tests/integration/test_external_services.py
```

External tests require the `ordin_test` database to be migrated to the current
Alembic head and use Redis database 15.

## Production OTP relay

Staging and production require `ORDIN_OTP_SENDER_BACKEND=webhook`, an HTTPS
`ORDIN_OTP_WEBHOOK_URL`, and a secret-manager supplied
`ORDIN_OTP_WEBHOOK_TOKEN`. The private relay receives an authenticated JSON
request containing `phoneNumber`, `code`, and `expiresAt`; it owns the
vendor-specific SMS integration. Production startup rejects development secrets,
fixed OTP mode, insecure webhook URLs, and unbounded forwarded-header trust.
