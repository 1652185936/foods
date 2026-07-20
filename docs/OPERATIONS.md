# Production Operations

This runbook covers the server deployment baseline in
`deploy/compose.production.yml`. It does not provision cloud resources, publish
images, configure DNS/TLS, or supply third-party credentials.

## Deployment model

- One immutable server image runs four separate process roles: `api`, `worker`,
  `beat`, and the one-shot `migrate` tool.
- PostgreSQL, Redis cache, Redis Celery broker, and S3-compatible object storage
  are externally managed services. They are not part of the production Compose
  project.
- Only `api` joins the existing reverse-proxy network. It uses Docker `expose`
  and does not publish a host port. Worker, Beat, and migration containers have
  no inbound network surface.
- Runtime containers are non-root, read-only, capability-free, protected by
  `no-new-privileges`, and limited by PID, CPU, memory, and temporary filesystem
  controls.
- Run exactly one Beat replica. Duplicate Beat instances would enqueue duplicate
  periodic cleanup work.

The `deploy.update_config` and `rollback_config` sections define the intended
rolling policy for orchestrators that honor Compose deploy semantics. Standalone
`docker compose` does not guarantee zero-downtime rolling replacement. A hard
zero-downtime requirement needs a compatible orchestrator or an explicit
blue/green procedure at the reverse proxy.

## External prerequisites

Production deployment is blocked until the operator supplies all of the
following outside the repository:

- A Linux container host or compatible orchestrator and an existing private
  reverse-proxy Docker network.
- An immutable image digest in a reachable container registry. The repository's
  build workflow intentionally does not publish images.
- Public DNS, TLS certificate, and reverse-proxy routing for the API origin.
- PostgreSQL with TLS, point-in-time recovery, an application DML role, and a
  separate migration DDL role.
- Two authenticated TLS Redis endpoints or logical services: one for cache and
  one dedicated to Celery.
- A private S3 bucket, HTTPS internal and public endpoints, scoped object
  credentials, lifecycle policy, and any required versioning/replication.
- HTTPS OTP relay credentials and HTTPS recognition-provider credentials.
- Central logs, infrastructure metrics, alert routing, and an on-call owner.

Do not mark production ready while any item above is represented by an
`example.invalid` host or a `REPLACE_WITH_...` value.

## Secret preparation

Use `deploy/.env.production.example` only as a variable inventory. Materialize
`deploy/.env.production` from the deployment platform's secret manager at deploy
time. The real file is ignored by Git, but it is still plaintext on disk:

```bash
chmod 600 deploy/.env.production
```

Restrict host access because Docker administrators can inspect container
environment variables. Never attach the production environment file to CI
artifacts, support bundles, or issue reports. Use `docker compose config --quiet`;
the non-quiet form expands environment values and can disclose secrets in logs.

Production startup fails closed unless:

- `ORDIN_IMAGE_REPOSITORY` names the published repository and
  `ORDIN_IMAGE_SHA256` is the image's 64-character SHA-256 value. The Compose
  file constructs `repository@sha256:digest`; a mutable tag alone cannot be
  deployed.
- PostgreSQL uses `postgresql+psycopg` with `sslmode=require`, `verify-ca`, or
  preferably `verify-full`.
- Redis cache and Celery use authenticated `rediss://` URLs, the broker is
  separate from cache, and Celery requests certificate verification.
- The public API, S3 endpoints, OTP relay, and recognition provider use HTTPS.
- Application, object-storage, OTP, and provider credentials are not known
  development values or template placeholders.
- Forwarded headers are trusted only from explicit immediate proxy IPs or
  bounded CIDRs. `*`, `0.0.0.0/0`, and `::/0` are rejected.

## Preflight

All commands run from the repository root:

```bash
docker compose \
  --env-file deploy/.env.production \
  --file deploy/compose.production.yml \
  config --quiet

docker compose \
  --env-file deploy/.env.production \
  --file deploy/compose.production.yml \
  --profile tools pull

docker compose \
  --env-file deploy/.env.production \
  --file deploy/compose.production.yml \
  --profile tools run --rm --no-deps migrate \
  python -c "from ordin.infrastructure.migration_config import MigrationSettings; MigrationSettings(); print('migration configuration valid')"

docker compose \
  --env-file deploy/.env.production \
  --file deploy/compose.production.yml \
  run --rm --no-deps api \
  python -c "from ordin.infrastructure.config import Settings; Settings(); print('runtime configuration valid')"
```

Confirm that the rendered image reference matches the digest published by the
registry, the proxy network exists, managed-service allowlists include the
deployment host, TLS certificate chains validate, and provider quotas are
sufficient. Take a database backup before a schema change.

## Migration and deployment

Run migrations once, before replacing application processes:

```bash
docker compose \
  --env-file deploy/.env.production \
  --file deploy/compose.production.yml \
  --profile tools run --rm --no-deps migrate alembic current

docker compose \
  --env-file deploy/.env.production \
  --file deploy/compose.production.yml \
  --profile tools run --rm --no-deps migrate alembic upgrade head

docker compose \
  --env-file deploy/.env.production \
  --file deploy/compose.production.yml \
  up --detach --pull always --wait api worker beat
```

Migrations must remain backward compatible with the currently serving image.
Use expand/migrate/contract changes when a schema change cannot support both
versions. Do not run multiple migration containers concurrently.
The migration container receives only `ORDIN_DATABASE_URL`, populated from the
separate DDL-role `ORDIN_MIGRATION_DATABASE_URL`; application, OTP, object
storage, provider, Redis, and signing secrets are intentionally unavailable.

Record the deployed Git commit, immutable image digest, Alembic revision,
operator, backup identifier, and deployment timestamps in the change record.

## Health verification

`/api/v1/health` is process liveness. `/api/v1/ready` verifies PostgreSQL, the
OTP/rate-limit Redis service, private object storage, and the Celery broker with
a bounded connectivity probe. It is the reverse proxy's readiness signal.
Broker readiness proves the API can reach the queue endpoint; it does not prove
a worker is consuming. Require the Worker healthcheck and an end-to-end
recognition smoke test for release verification.

```bash
docker compose \
  --env-file deploy/.env.production \
  --file deploy/compose.production.yml \
  ps

curl --fail --silent --show-error \
  https://api.example.com/api/v1/health

curl --fail --silent --show-error \
  https://api.example.com/api/v1/ready
```

Also complete an authenticated smoke test through the public proxy: request and
verify OTP using an approved test number, read the profile, submit an idempotent
record write, and run one recognition upload. Do not use the development OTP
backend in staging or production.

```bash
uv run --locked python server/scripts/smoke_api.py \
  --base-url https://api.example.com \
  --phone-number +971501234567 \
  --otp-code "$ORDIN_SMOKE_OTP"

uv run --locked python server/scripts/smoke_api.py \
  --base-url https://api.example.com \
  --phone-number +971501234567 \
  --otp-code "$ORDIN_SMOKE_OTP" \
  --include-recognition
```

The second command creates one short-lived object and consumes one recognition
job, so run it only in the approved release smoke window. The script redacts
tokens and presigned storage details by design.

Alert on sustained readiness failures, HTTP error rate/latency, PostgreSQL
connections and replication lag, Redis availability/memory, Celery queue age,
worker failures, S3 errors, cleanup failures, and provider throttling. Derive
numeric thresholds from measured traffic rather than copying arbitrary values.

## Backup and restore

PostgreSQL is the system of record. Enable managed point-in-time recovery and
regular immutable snapshots. The release target is a verified RPO no worse than
15 minutes and RTO no worse than four hours; provider configuration alone is not
evidence that the target is met.

Before migration, create an on-demand snapshot or a custom-format `pg_dump`
using a separately injected backup role. Do not place the backup DSN in the app
environment. Encrypt exports and store their checksum and retention metadata.

Restore drills must use a new isolated database instance:

1. Restore the selected snapshot/export to the isolated instance.
2. Run integrity checks, critical table counts, and `alembic current`.
3. Point a disposable API/Worker deployment at the restored instance.
4. Verify authentication, profile reads, record sync, and recognition job state.
5. Record achieved RPO/RTO and delete the drill environment according to policy.

Redis cache and the Celery broker are not sources of truth. Do not restore stale
queues over a fresh deployment. After broker loss, reconcile queued/running jobs
from PostgreSQL and rely on claim leases and idempotency before re-enqueueing.

S3 lifecycle rules must not delete recognition sources earlier than the
application retention setting. Use bucket versioning/replication when business
retention requires it, and include an object restore in disaster-recovery drills.

## Rollback

Keep the previous immutable image digest and environment revision. For an
application-only regression, restore the previous digest and redeploy API and
Worker. Keep Beat at one replica:

```bash
docker compose \
  --env-file deploy/.env.production \
  --file deploy/compose.production.yml \
  up --detach --pull always --wait api worker beat
```

Only roll back the application image when the migrated schema remains backward
compatible. Alembic downgrade is not the routine production rollback mechanism.
For a destructive or incompatible migration, stop writes and restore the
pre-migration backup to a new database, validate it, then switch application
connectivity under an incident change record.

## Worker backlog

Inspect active, reserved, and worker state without exposing broker credentials:

```bash
docker compose \
  --env-file deploy/.env.production \
  --file deploy/compose.production.yml \
  exec worker celery -A ordin.worker.celery_app:app inspect active

docker compose \
  --env-file deploy/.env.production \
  --file deploy/compose.production.yml \
  exec worker celery -A ordin.worker.celery_app:app inspect reserved

docker compose \
  --env-file deploy/.env.production \
  --file deploy/compose.production.yml \
  exec worker celery -A ordin.worker.celery_app:app inspect stats
```

Use managed Redis queue depth and oldest-message age as the authoritative backlog
signals. Scale `ORDIN_WORKER_REPLICAS` and `ORDIN_WORKER_CONCURRENCY` gradually,
checking database, Redis, S3, and provider limits after each change. Never scale
Beat above one. During a provider outage, stop or reduce recognition consumers
before retry traffic amplifies the incident.

## Object cleanup

Beat dispatches `ordin.recognition.cleanup` to the `maintenance` queue hourly.
The task removes expired sanitized sources and abandoned incoming uploads. A
missing object is treated as already cleaned; a storage outage leaves the row
eligible for the next run.

Account deletion writes every incoming and sanitized object key to the durable
`account_object_cleanups` table in the same transaction that deletes the user.
The API attempts a bounded first batch, then Beat dispatches
`ordin.account.cleanup` to the same `maintenance` queue every 15 minutes. A
missing object completes the queue row; a storage failure retains it with a
bounded retry delay. Keep exactly one Beat replica so both schedules remain
predictable.

Trigger one cleanup dispatch when validating recovery:

```bash
docker compose \
  --env-file deploy/.env.production \
  --file deploy/compose.production.yml \
  exec worker celery -A ordin.worker.celery_app:app \
  call ordin.recognition.cleanup --queue maintenance
```

Confirm completion through Worker logs, database cleanup markers, and object
inventory. Do not shorten retention without product/privacy approval.

Trigger an account-object retry after recovering storage connectivity:

```bash
docker compose \
  --env-file deploy/.env.production \
  --file deploy/compose.production.yml \
  exec worker celery -A ordin.worker.celery_app:app \
  call ordin.account.cleanup --queue maintenance
```

Alert on the oldest incomplete `account_object_cleanups.queued_at`, repeated
attempts, and sustained row growth. Reconcile incomplete keys against the
private bucket before closing a privacy incident. Never delete pending queue
rows merely to reduce backlog; doing so can orphan personal images after the
account row has already been removed.

## Credential rotation

- Rotate database, Redis, S3, OTP relay, and recognition-provider credentials
  with an overlap window where the provider supports it. Update the secret
  manager, redeploy, verify readiness, then revoke the old credential.
- Rotating `ORDIN_JWT_SECRET` invalidates existing access tokens.
- Rotating `ORDIN_TOKEN_HMAC_SECRET` invalidates stored refresh tokens and forces
  users to authenticate again.
- `ORDIN_IDENTITY_HMAC_SECRET` protects persistent identity lookup keys. It
  cannot be safely replaced without a dual-key data migration; treat rotation as
  a planned schema/data operation.
- Rotate `ORDIN_OTP_HMAC_SECRET` only after existing OTP challenges expire.
- Rotating `ORDIN_IDEMPOTENCY_HMAC_SECRET` changes replay keys. Wait out client
  retry windows or provide a dual-key migration before replacement.

After any rotation, verify API readiness, authentication, refresh, idempotent
writes, object upload, recognition, Worker health, and cleanup dispatch. Record
the credential version, not the credential value, in the change log.
