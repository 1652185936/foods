import argparse
import hashlib
import io
import sys
import time
from dataclasses import dataclass
from typing import Any, cast
from urllib.parse import urlsplit
from uuid import uuid4

import httpx
from PIL import Image


class SmokeFailure(RuntimeError):
    pass


@dataclass(frozen=True, slots=True)
class SmokeConfig:
    base_url: str
    phone_number: str
    otp_code: str
    include_recognition: bool
    include_account_deletion: bool
    timeout_seconds: float


@dataclass(frozen=True, slots=True)
class AuthContext:
    headers: dict[str, str]
    refresh_token: str
    installation_id: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run a credential-safe smoke test against a deployed Ordin API."
    )
    parser.add_argument("--base-url", default="http://127.0.0.1:8000")
    parser.add_argument("--phone-number", default="+971501234567")
    parser.add_argument(
        "--otp-code",
        help="Current OTP. Loopback development defaults to 123456.",
    )
    parser.add_argument(
        "--include-recognition",
        action="store_true",
        help="Also verify direct object upload and asynchronous recognition.",
    )
    parser.add_argument(
        "--include-account-deletion",
        action="store_true",
        help="Export and permanently delete the supplied disposable smoke account.",
    )
    parser.add_argument("--timeout-seconds", type=float, default=45.0)
    return parser.parse_args()


def build_config(args: argparse.Namespace) -> SmokeConfig:
    base_url = cast(str, args.base_url).rstrip("/")
    parsed = urlsplit(base_url)
    is_loopback = parsed.hostname in {"127.0.0.1", "localhost", "::1"}
    if (
        parsed.scheme not in {"http", "https"}
        or parsed.hostname is None
        or parsed.username is not None
        or parsed.password is not None
        or parsed.path not in {"", "/"}
        or parsed.query
        or parsed.fragment
        or (parsed.scheme == "http" and not is_loopback)
    ):
        raise SmokeFailure("base URL must be an HTTPS origin or a loopback HTTP origin")
    otp_code = cast(str | None, args.otp_code)
    if otp_code is None:
        if not is_loopback:
            raise SmokeFailure("--otp-code is required outside loopback development")
        otp_code = "123456"
    timeout_seconds = cast(float, args.timeout_seconds)
    if timeout_seconds <= 0:
        raise SmokeFailure("--timeout-seconds must be positive")
    return SmokeConfig(
        base_url=base_url,
        phone_number=cast(str, args.phone_number),
        otp_code=otp_code,
        include_recognition=cast(bool, args.include_recognition),
        include_account_deletion=cast(bool, args.include_account_deletion),
        timeout_seconds=timeout_seconds,
    )


def _expect_status(response: httpx.Response, expected: set[int], step: str) -> None:
    if response.status_code not in expected:
        request_id = response.headers.get("x-request-id", "unavailable")
        raise SmokeFailure(
            f"{step} returned HTTP {response.status_code} (request id: {request_id})"
        )


def _json_object(response: httpx.Response, step: str) -> dict[str, Any]:
    try:
        value = response.json()
    except ValueError as error:
        raise SmokeFailure(f"{step} did not return JSON") from error
    if not isinstance(value, dict) or not all(isinstance(key, str) for key in value):
        raise SmokeFailure(f"{step} returned an unexpected JSON shape")
    return cast(dict[str, Any], value)


def _required_string(payload: dict[str, Any], key: str, step: str) -> str:
    value = payload.get(key)
    if not isinstance(value, str) or not value:
        raise SmokeFailure(f"{step} response is missing {key}")
    return value


def _required_int(payload: dict[str, Any], key: str, step: str) -> int:
    value = payload.get(key)
    if not isinstance(value, int) or isinstance(value, bool):
        raise SmokeFailure(f"{step} response is missing {key}")
    return value


def _required_object(payload: dict[str, Any], key: str, step: str) -> dict[str, Any]:
    value = payload.get(key)
    if not isinstance(value, dict) or not all(isinstance(item, str) for item in value):
        raise SmokeFailure(f"{step} response is missing {key}")
    return cast(dict[str, Any], value)


def _required_string_map(payload: dict[str, Any], key: str, step: str) -> dict[str, str]:
    value = _required_object(payload, key, step)
    if not all(isinstance(item, str) for item in value.values()):
        raise SmokeFailure(f"{step} response contains invalid {key}")
    return cast(dict[str, str], value)


def _sample_jpeg() -> bytes:
    output = io.BytesIO()
    image = Image.new("RGB", (64, 64), color=(61, 99, 73))
    image.save(output, format="JPEG", quality=85)
    return output.getvalue()


def _authenticate(client: httpx.Client, config: SmokeConfig) -> AuthContext:
    installation_id = str(uuid4())
    challenge = client.post(
        "/api/v1/auth/otp/challenges",
        headers={"Idempotency-Key": f"smoke-challenge-{uuid4()}"},
        json={
            "phoneNumber": config.phone_number,
            "deviceInstallationId": installation_id,
        },
    )
    _expect_status(challenge, {202}, "OTP challenge")
    challenge_id = _required_string(
        _json_object(challenge, "OTP challenge"), "challengeId", "OTP challenge"
    )
    verified = client.post(
        f"/api/v1/auth/otp/challenges/{challenge_id}/verify",
        json={
            "code": config.otp_code,
            "device": {
                "installationId": installation_id,
                "platform": "android",
                "appVersion": "smoke-test",
            },
        },
    )
    _expect_status(verified, {200}, "OTP verification")
    tokens = _required_object(
        _json_object(verified, "OTP verification"), "tokens", "OTP verification"
    )
    access_token = _required_string(tokens, "accessToken", "OTP verification")
    refresh_token = _required_string(tokens, "refreshToken", "OTP verification")
    return AuthContext(
        headers={"Authorization": f"Bearer {access_token}"},
        refresh_token=refresh_token,
        installation_id=installation_id,
    )


def _sync_write_smoke(client: httpx.Client, auth_headers: dict[str, str]) -> None:
    current = client.get("/api/v1/users/me/preferences", headers=auth_headers)
    if current.status_code == 404:
        expected_version = 0
        preferences = {
            "dailyEnergyTargetKcal": 1780,
            "selectedFastingPlan": "balanced",
            "fastingReminderEnabled": False,
        }
    else:
        _expect_status(current, {200}, "preference read")
        payload = _json_object(current, "preference read")
        expected_version = _required_int(payload, "version", "preference read")
        preferences = {
            "dailyEnergyTargetKcal": _required_int(
                payload, "dailyEnergyTargetKcal", "preference read"
            ),
            "selectedFastingPlan": _required_string(
                payload, "selectedFastingPlan", "preference read"
            ),
            "fastingReminderEnabled": payload.get("fastingReminderEnabled"),
        }
        if not isinstance(preferences["fastingReminderEnabled"], bool):
            raise SmokeFailure("preference read response is missing fastingReminderEnabled")

    operation = {
        "operationId": str(uuid4()),
        "entityType": "appPreferences",
        "entityId": "current",
        "action": "upsert",
        "expectedVersion": expected_version,
        "payloadVersion": 1,
        "appPreferences": preferences,
    }
    request = {"operations": [operation]}
    first = client.post("/api/v1/sync/push", headers=auth_headers, json=request)
    _expect_status(first, {200}, "idempotent sync write")
    replay = client.post("/api/v1/sync/push", headers=auth_headers, json=request)
    _expect_status(replay, {200}, "idempotent sync replay")
    first_results = _json_object(first, "idempotent sync write").get("results")
    replay_results = _json_object(replay, "idempotent sync replay").get("results")
    if (
        not isinstance(first_results, list)
        or len(first_results) != 1
        or not isinstance(first_results[0], dict)
        or first_results[0].get("status") != "applied"
        or not isinstance(replay_results, list)
        or len(replay_results) != 1
        or not isinstance(replay_results[0], dict)
        or replay_results[0].get("replayed") is not True
    ):
        raise SmokeFailure("sync write did not preserve idempotent replay semantics")


def _recognition_smoke(
    client: httpx.Client,
    auth_headers: dict[str, str],
    timeout_seconds: float,
) -> None:
    content = _sample_jpeg()
    upload = client.post(
        "/api/v1/recognition-uploads",
        headers=auth_headers,
        json={
            "contentType": "image/jpeg",
            "sizeBytes": len(content),
            "checksumSha256": hashlib.sha256(content).hexdigest(),
        },
    )
    _expect_status(upload, {201}, "recognition upload creation")
    upload_payload = _json_object(upload, "recognition upload creation")
    upload_id = _required_string(upload_payload, "uploadSessionId", "recognition upload creation")
    upload_url = _required_string(upload_payload, "uploadUrl", "recognition upload creation")
    upload_headers = _required_string_map(
        upload_payload, "uploadHeaders", "recognition upload creation"
    )
    stored = client.put(upload_url, headers=upload_headers, content=content)
    _expect_status(stored, {200, 204}, "direct object upload")
    completed = client.post(
        f"/api/v1/recognition-uploads/{upload_id}/complete",
        headers=auth_headers,
    )
    _expect_status(completed, {200}, "recognition upload completion")
    queued = client.post(
        "/api/v1/recognitions",
        headers={**auth_headers, "Idempotency-Key": f"smoke-recognition-{uuid4()}"},
        json={"uploadSessionId": upload_id},
    )
    _expect_status(queued, {202}, "recognition queue")
    job_id = _required_string(_json_object(queued, "recognition queue"), "id", "recognition queue")

    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        response = client.get(f"/api/v1/recognitions/{job_id}", headers=auth_headers)
        _expect_status(response, {200}, "recognition polling")
        payload = _json_object(response, "recognition polling")
        status = _required_string(payload, "status", "recognition polling")
        if status in {"succeeded", "needs_review"}:
            items = payload.get("items")
            if not isinstance(items, list) or not items:
                raise SmokeFailure("recognition completed without candidates")
            return
        if status in {"failed", "expired"}:
            error_code = payload.get("errorCode")
            safe_code = error_code if isinstance(error_code, str) else "unknown"
            raise SmokeFailure(f"recognition reached {status} ({safe_code})")
        time.sleep(0.5)
    raise SmokeFailure("recognition did not complete before the smoke timeout")


def _all_keys(value: object) -> set[str]:
    if isinstance(value, dict):
        return {
            *[key for key in value if isinstance(key, str)],
            *[key for nested in value.values() for key in _all_keys(nested)],
        }
    if isinstance(value, list):
        return {key for nested in value for key in _all_keys(nested)}
    return set()


def _account_privacy_smoke(client: httpx.Client, auth: AuthContext) -> None:
    exported = client.get("/api/v1/users/me/data-export", headers=auth.headers)
    _expect_status(exported, {200}, "account data export")
    payload = _json_object(exported, "account data export")
    if payload.get("schemaVersion") != 1:
        raise SmokeFailure("account data export returned an unsupported schema version")
    forbidden = {
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
    leaked = forbidden & _all_keys(payload)
    if leaked:
        raise SmokeFailure("account data export contains a forbidden internal field")

    deleted = client.request(
        "DELETE",
        "/api/v1/users/me",
        headers=auth.headers,
        json={
            "confirmation": "DELETE_MY_ACCOUNT",
            "refreshToken": auth.refresh_token,
            "deviceInstallationId": auth.installation_id,
        },
    )
    _expect_status(deleted, {204}, "account deletion")
    _expect_status(
        client.get("/api/v1/users/me", headers=auth.headers),
        {401},
        "deleted access token rejection",
    )
    _expect_status(
        client.post(
            "/api/v1/auth/token/refresh",
            json={
                "refreshToken": auth.refresh_token,
                "deviceInstallationId": auth.installation_id,
            },
        ),
        {401},
        "deleted refresh token rejection",
    )


def run(config: SmokeConfig) -> None:
    timeout = httpx.Timeout(config.timeout_seconds)
    with httpx.Client(base_url=config.base_url, timeout=timeout, follow_redirects=False) as client:
        for path, label in (
            ("/api/v1/health", "health check"),
            ("/api/v1/ready", "readiness check"),
        ):
            response = client.get(path)
            _expect_status(response, {200}, label)
        auth = _authenticate(client, config)
        _expect_status(client.get("/api/v1/users/me", headers=auth.headers), {200}, "current user")
        _sync_write_smoke(client, auth.headers)
        _expect_status(
            client.get("/api/v1/sync/pull", params={"limit": 1}, headers=auth.headers),
            {200},
            "sync pull",
        )
        if config.include_recognition:
            _recognition_smoke(client, auth.headers, config.timeout_seconds)
        if config.include_account_deletion:
            _account_privacy_smoke(client, auth)


def main() -> int:
    try:
        config = build_config(parse_args())
        run(config)
    except SmokeFailure as error:
        print(f"Smoke failed: {error}", file=sys.stderr)
        return 1
    except httpx.HTTPError:
        print("Smoke failed: a network request could not be completed", file=sys.stderr)
        return 1
    except Exception as error:
        print(f"Smoke failed: unexpected {type(error).__name__}", file=sys.stderr)
        return 1
    verified = ["core API"]
    if config.include_recognition:
        verified.append("recognition")
    if config.include_account_deletion:
        verified.append("account privacy")
    scope = ", ".join(verified)
    print(f"Smoke passed: {scope}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
