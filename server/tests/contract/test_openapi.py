import json
from collections.abc import Mapping
from pathlib import Path
from typing import Any

from fastapi import FastAPI

CONTRACT_PATH = Path(__file__).resolve().parents[3] / "contracts" / "openapi" / "ordin-api-v1.json"
HTTP_METHODS = {"delete", "get", "head", "options", "patch", "post", "put", "trace"}


def test_openapi_contains_health_contract(app: FastAPI) -> None:
    schema = app.openapi()
    operation = schema["paths"]["/api/v1/health"]["get"]

    assert operation["operationId"] == "getHealth"
    assert operation["responses"]["200"]["content"]["application/json"]["schema"] == {
        "$ref": "#/components/schemas/HealthResponse"
    }


def test_openapi_exposes_only_the_versioned_v1_surface(app: FastAPI) -> None:
    schema = app.openapi()

    assert set(schema["paths"]) == {
        "/api/v1/auth/otp/challenges",
        "/api/v1/auth/otp/challenges/{challengeId}/verify",
        "/api/v1/auth/sessions/current",
        "/api/v1/auth/token/refresh",
        "/api/v1/fasting-sessions",
        "/api/v1/fasting-sessions/{fastingSessionId}",
        "/api/v1/health",
        "/api/v1/meals",
        "/api/v1/meals/{mealId}",
        "/api/v1/ready",
        "/api/v1/recognition-uploads",
        "/api/v1/recognition-uploads/{uploadSessionId}/complete",
        "/api/v1/recognitions",
        "/api/v1/recognitions/{recognitionId}",
        "/api/v1/recognitions/{recognitionId}/correction",
        "/api/v1/sync/pull",
        "/api/v1/sync/push",
        "/api/v1/users/me",
        "/api/v1/users/me/data-export",
        "/api/v1/users/me/health-profile",
        "/api/v1/users/me/preferences",
    }
    assert schema["paths"]["/api/v1/auth/otp/challenges"]["post"]["operationId"] == (
        "createOtpChallenge"
    )
    assert schema["paths"]["/api/v1/users/me"]["get"]["operationId"] == "getCurrentUser"
    assert schema["paths"]["/api/v1/users/me"]["delete"]["operationId"] == "deleteCurrentUser"
    assert (
        schema["paths"]["/api/v1/users/me/data-export"]["get"]["operationId"]
        == "exportCurrentUserData"
    )
    export_meal = schema["components"]["schemas"]["AccountExportMeal"]
    assert export_meal["properties"]["localDay"]["pattern"] == (
        r"^[0-9]{4}-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12][0-9]|3[01])$"
    )


def test_openapi_applies_bearer_security_only_to_protected_operations(app: FastAPI) -> None:
    schema = app.openapi()

    assert schema["components"]["securitySchemes"]["AccessToken"] == {
        "scheme": "bearer",
        "type": "http",
    }
    assert "security" not in schema["paths"]["/api/v1/auth/otp/challenges"]["post"]
    assert schema["paths"]["/api/v1/users/me"]["get"]["security"] == [{"AccessToken": []}]


def test_openapi_uses_camel_case_and_problem_details(app: FastAPI) -> None:
    schema = app.openapi()
    challenge_properties = schema["components"]["schemas"]["OtpChallengeInput"]["properties"]
    profile_properties = schema["components"]["schemas"]["HealthProfileResponse"]["properties"]
    validation_response = schema["paths"]["/api/v1/users/me"]["patch"]["responses"]["422"]

    assert "phoneNumber" in challenge_properties
    assert "phone_number" not in challenge_properties
    assert "dailyEnergyTargetKcal" in profile_properties
    assert "userId" not in schema["components"]["schemas"]["UserPatchInput"]["properties"]
    assert validation_response["content"] == {
        "application/problem+json": {"schema": {"$ref": "#/components/schemas/ProblemDetails"}}
    }


def test_health_profile_decimal_wire_fields_are_strings(app: FastAPI) -> None:
    schemas = app.openapi()["components"]["schemas"]

    for schema_name in ("HealthProfileInputModel", "HealthProfileResponse"):
        properties = schemas[schema_name]["properties"]
        for field_name in ("heightCm", "currentWeightKg", "targetWeightKg"):
            field_schema = properties[field_name]
            variants = field_schema.get("anyOf", [field_schema])
            assert {variant.get("type") for variant in variants} <= {"string", "null"}
            assert not any(variant.get("type") == "number" for variant in variants)


def test_openapi_operation_ids_are_unique(app: FastAPI) -> None:
    schema = app.openapi()
    operation_ids = [
        operation["operationId"]
        for path_item in schema["paths"].values()
        for method, operation in path_item.items()
        if method in HTTP_METHODS and isinstance(operation, Mapping)
    ]

    assert len(operation_ids) == len(set(operation_ids))


def test_committed_openapi_contract_matches_application(app: FastAPI) -> None:
    committed: dict[str, Any] = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))

    assert committed == app.openapi()
