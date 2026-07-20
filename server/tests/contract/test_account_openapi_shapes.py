from typing import Any

from fastapi import FastAPI


def test_account_export_and_deletion_contracts_are_strict(app: FastAPI) -> None:
    schema: dict[str, Any] = app.openapi()
    paths = schema["paths"]
    models = schema["components"]["schemas"]

    export = paths["/api/v1/users/me/data-export"]["get"]
    assert export["operationId"] == "exportCurrentUserData"
    assert export["security"] == [{"AccessToken": []}]
    assert set(export["responses"]) == {"200", "401", "404", "413"}
    assert export["responses"]["413"]["content"]["application/problem+json"]["schema"] == {
        "$ref": "#/components/schemas/ProblemDetails"
    }

    export_model = models["AccountDataExportResponse"]
    assert export_model["additionalProperties"] is False
    assert export_model["properties"]["schemaVersion"]["const"] == 1
    assert set(export_model["required"]) == {
        "exportedAt",
        "user",
        "healthProfile",
        "preferences",
        "meals",
        "fastingSessions",
        "recognitions",
    }
    account_models = {
        name: value for name, value in models.items() if name.startswith("AccountExport")
    }
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
        "providerName",
    }
    assert all(
        forbidden.isdisjoint(model.get("properties", {})) for model in account_models.values()
    )

    deletion = paths["/api/v1/users/me"]["delete"]
    assert deletion["operationId"] == "deleteCurrentUser"
    assert deletion["security"] == [{"AccessToken": []}]
    assert set(deletion["responses"]) == {"204", "401", "422"}
    assert "content" not in deletion["responses"]["204"]
    deletion_model = models["AccountDeletionInput"]
    assert deletion_model["additionalProperties"] is False
    assert deletion_model["properties"]["confirmation"]["const"] == "DELETE_MY_ACCOUNT"
    assert deletion_model["properties"]["refreshToken"]["minLength"] == 32
    assert deletion_model["properties"]["refreshToken"]["maxLength"] == 512
    assert deletion_model["properties"]["deviceInstallationId"]["format"] == "uuid"
