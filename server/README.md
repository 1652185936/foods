# Ordin Server

FastAPI service for account sessions and health-profile data. PostgreSQL is the
source of truth, while Redis stores short-lived OTP challenges and rate limits.

## Local setup

Run Compose from the repository root, then all Python commands from this
directory:

```powershell
docker compose up -d postgres redis minio minio-init
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
- `GET /api/v1/ready`: PostgreSQL, Redis, object-storage, and Celery-broker readiness
- `GET /docs`: development/test OpenAPI UI

To run the containerized API and asynchronous workers instead:

```powershell
docker compose --profile backend up -d --build
```

## Food recognition

The mobile client uploads images directly to private object storage and then
submits a short asynchronous recognition job:

1. `POST /api/v1/recognition-uploads` creates a presigned upload.
2. The client uploads the image with the returned URL and headers.
3. `POST /api/v1/recognition-uploads/{uploadSessionId}/complete` validates,
   decodes, applies EXIF orientation, and writes a sanitized JPEG.
4. `POST /api/v1/recognitions` queues recognition with an `Idempotency-Key`.
5. `GET /api/v1/recognitions/{recognitionId}` returns status and candidates.
6. `PUT /api/v1/recognitions/{recognitionId}/correction` stores the reviewed
   result with optimistic concurrency.

Development and test environments use a deterministic synthetic provider.
Staging and production fail closed unless an HTTPS provider, non-default HTTPS
S3 credentials, and a dedicated TLS Redis broker are configured. Original
uploads expire after 24 hours by default; Celery Beat dispatches cleanup work.

## Account portability and deletion

`GET /api/v1/users/me/data-export` returns a repeatable-read snapshot with an
explicit schema version. Synchronous exports are capped by
`ORDIN_ACCOUNT_EXPORT_MAX_RECORDS` and return `413 account_export_too_large`
rather than silently truncating data.

`DELETE /api/v1/users/me` requires the confirmation constant, the current
session's refresh token, and its device installation ID. Recognition object
keys enter a durable, user-independent cleanup queue in the same transaction as
the account cascade. API cleanup is best effort; Celery Beat retries bounded
batches without restoring a deleted account.

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
$env:ORDIN_RUN_RECOGNITION_EXTERNAL_TESTS='1'
uv run --locked pytest tests/integration/test_recognition_external.py
```

External tests require the `ordin_test` database to be migrated to the current
Alembic head and use Redis database 15. Recognition tests use the independently
configured Celery test broker (Redis database 14 in CI) and also require the
local MinIO service. OpenAPI export is intentionally a separate coordinated step
because it contains the combined public API surface.

After the containerized stack is healthy, run the black-box API smoke test from
the repository checkout. It never prints access tokens, presigned URLs, upload
headers, or image content:

```powershell
# Loopback development uses the explicitly configured 123456 development OTP.
uv run --locked python scripts/smoke_api.py
uv run --locked python scripts/smoke_api.py --include-recognition

# Staging and production require a real one-time code and HTTPS origin.
uv run --locked python scripts/smoke_api.py `
  --base-url https://api.example.com `
  --phone-number +971501234567 `
  --otp-code 123456
```

Recognition is opt-in for remote environments because it creates an object and
consumes one provider job. Plain HTTP is accepted only for loopback development.

## Production OTP relay

Staging and production require `ORDIN_OTP_SENDER_BACKEND=webhook`, an HTTPS
`ORDIN_OTP_WEBHOOK_URL`, and a secret-manager supplied
`ORDIN_OTP_WEBHOOK_TOKEN`. The private relay receives an authenticated JSON
request containing `phoneNumber`, `code`, and `expiresAt`; it owns the
vendor-specific SMS integration. Production startup rejects development secrets,
fixed OTP mode, insecure webhook URLs, and unbounded forwarded-header trust.
Wildcard trust and all-address CIDRs (`0.0.0.0/0` and `::/0`) are rejected;
configure only the immediate reverse-proxy peer addresses.
