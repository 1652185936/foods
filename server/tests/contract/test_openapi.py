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
