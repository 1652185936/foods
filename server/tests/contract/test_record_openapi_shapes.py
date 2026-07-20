from typing import Any

from fastapi import FastAPI


def _assert_plain_string(schema: dict[str, Any]) -> None:
    branches = schema.get("anyOf", [schema])
    string_branches = [branch for branch in branches if branch.get("type") == "string"]
    assert string_branches
    assert all("format" not in branch for branch in string_branches)
    assert all("pattern" in branch for branch in string_branches)


def _assert_date_time(schema: dict[str, Any]) -> None:
    branches = schema.get("anyOf", [schema])
    date_time_branches = [
        branch
        for branch in branches
        if branch.get("type") == "string" and branch.get("format") == "date-time"
    ]
    assert date_time_branches


def test_date_only_wire_fields_are_plain_patterned_strings(app: FastAPI) -> None:
    schema = app.openapi()
    models = schema["components"]["schemas"]

    _assert_plain_string(models["HealthProfileInputModel"]["properties"]["birthDate"])
    _assert_plain_string(models["HealthProfileResponse"]["properties"]["birthDate"])
    _assert_plain_string(models["MealSyncPayload"]["properties"]["localDay"])
    _assert_plain_string(models["MealResponse"]["properties"]["localDay"])
    for field in ("startedLocalDay", "targetEndLocalDay", "endedLocalDay"):
        _assert_plain_string(models["FastingSessionSyncPayload"]["properties"][field])
        _assert_plain_string(models["FastingSessionResponse"]["properties"][field])

    list_meals = schema["paths"]["/api/v1/meals"]["get"]
    local_day = next(
        parameter for parameter in list_meals["parameters"] if parameter["name"] == "localDay"
    )
    _assert_plain_string(local_day["schema"])

    _assert_date_time(models["MealSyncPayload"]["properties"]["occurredAtUtc"])
    for field in ("startedAtUtc", "targetEndAtUtc", "endedAtUtc"):
        _assert_date_time(models["FastingSessionSyncPayload"]["properties"][field])
    _assert_date_time(models["SyncChangeResponse"]["properties"]["deletedAtUtc"])
