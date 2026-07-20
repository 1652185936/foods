from copy import deepcopy
from uuid import uuid4

import pytest
from pydantic import ValidationError

from ordin.api.record_schemas import FastingSessionSyncPayload, MealSyncPayload


def _meal_payload() -> dict[str, object]:
    return {
        "type": "dinner",
        "source": "manual",
        # This is 18:30 EST on March 7, immediately before the DST transition day.
        "occurredAtUtc": "2026-03-07T23:30:00Z",
        "timeZoneId": "America/New_York",
        "localDay": "2026-03-07",
        "isWithinEatingWindow": True,
        "items": [
            {
                "id": str(uuid4()),
                "name": "Dinner",
                "servingMilli": 1000,
                "energyKcal": 600,
                "proteinMg": 30000,
                "carbsMg": 50000,
                "fatMg": 20000,
            }
        ],
    }


def _fasting_payload() -> dict[str, object]:
    return {
        "plan": "balanced",
        "status": "completed",
        # The 16-hour interval crosses midnight and the America/New_York DST jump.
        "startedAtUtc": "2026-03-07T23:30:00Z",
        "targetEndAtUtc": "2026-03-08T15:30:00Z",
        "endedAtUtc": "2026-03-08T15:30:00Z",
        "timeZoneId": "America/New_York",
        "startedLocalDay": "2026-03-07",
        "targetEndLocalDay": "2026-03-08",
        "endedLocalDay": "2026-03-08",
    }


def test_meal_accepts_local_day_derived_across_dst_boundary() -> None:
    payload = MealSyncPayload.model_validate(_meal_payload())

    assert payload.local_day == "2026-03-07"


@pytest.mark.parametrize("time_zone_id", ["GMT", "Etc/GMT"])
def test_meal_accepts_android_zero_offset_alias_and_normalizes_it(
    time_zone_id: str,
) -> None:
    payload = _meal_payload()
    payload.update(
        occurredAtUtc="2026-03-07T23:30:00Z",
        timeZoneId=time_zone_id,
        localDay="2026-03-07",
    )

    parsed = MealSyncPayload.model_validate(payload)

    assert parsed.time_zone_id == "UTC"


def test_meal_rejects_zone_name_that_only_matches_the_syntax() -> None:
    payload = _meal_payload()
    payload["timeZoneId"] = "America/Definitely_Not_A_Zone"

    with pytest.raises(ValidationError, match="available IANA time zone"):
        MealSyncPayload.model_validate(payload)


def test_meal_rejects_local_day_that_disagrees_with_instant_and_zone() -> None:
    payload = _meal_payload()
    payload["localDay"] = "2026-03-08"

    with pytest.raises(ValidationError, match="localDay does not match"):
        MealSyncPayload.model_validate(payload)


def test_meal_rejects_non_utc_offset_even_when_it_represents_the_same_instant() -> None:
    payload = _meal_payload()
    payload["occurredAtUtc"] = "2026-03-08T03:30:00+04:00"

    with pytest.raises(ValidationError, match="occurredAtUtc must use UTC"):
        MealSyncPayload.model_validate(payload)


def test_fasting_accepts_consistent_days_across_midnight_and_dst() -> None:
    payload = FastingSessionSyncPayload.model_validate(_fasting_payload())

    assert payload.started_local_day == "2026-03-07"
    assert payload.target_end_local_day == "2026-03-08"
    assert payload.ended_local_day == "2026-03-08"


def test_fasting_accepts_android_gmt_and_normalizes_it() -> None:
    payload = _fasting_payload()
    payload["timeZoneId"] = "GMT"

    parsed = FastingSessionSyncPayload.model_validate(payload)

    assert parsed.time_zone_id == "UTC"


@pytest.mark.parametrize(
    ("field", "wrong_day", "message"),
    [
        ("startedLocalDay", "2026-03-08", "startedLocalDay does not match"),
        ("targetEndLocalDay", "2026-03-07", "targetEndLocalDay does not match"),
        ("endedLocalDay", "2026-03-07", "endedLocalDay does not match"),
    ],
)
def test_fasting_rejects_each_inconsistent_local_day(
    field: str,
    wrong_day: str,
    message: str,
) -> None:
    payload = _fasting_payload()
    payload[field] = wrong_day

    with pytest.raises(ValidationError, match=message):
        FastingSessionSyncPayload.model_validate(payload)


def test_fasting_rejects_invalid_zone() -> None:
    payload = _fasting_payload()
    payload["timeZoneId"] = "America/Definitely_Not_A_Zone"

    with pytest.raises(ValidationError, match="available IANA time zone"):
        FastingSessionSyncPayload.model_validate(payload)


@pytest.mark.parametrize(
    ("changes", "message"),
    [
        (
            {"targetEndAtUtc": "2026-03-08T14:30:00Z"},
            "targetEndAtUtc must match the selected fasting plan",
        ),
        (
            {"status": "active"},
            "active sessions cannot have end metadata",
        ),
        (
            {"status": "cancelled", "endedAtUtc": None, "endedLocalDay": None},
            "finished sessions require endedAtUtc and endedLocalDay",
        ),
        (
            {
                "status": "cancelled",
                "endedAtUtc": "2026-03-07T22:30:00Z",
                "endedLocalDay": "2026-03-07",
            },
            "endedAtUtc cannot be before startedAtUtc",
        ),
        (
            {
                "endedAtUtc": "2026-03-08T15:29:00Z",
                "endedLocalDay": "2026-03-08",
            },
            "completed sessions must end at targetEndAtUtc",
        ),
        (
            {"targetEndAtUtc": "2026-03-08T19:30:00+04:00"},
            "targetEndAtUtc must use UTC",
        ),
    ],
)
def test_fasting_rejects_inconsistent_status_and_timestamps(
    changes: dict[str, object],
    message: str,
) -> None:
    payload = deepcopy(_fasting_payload())
    payload.update(changes)

    with pytest.raises(ValidationError, match=message):
        FastingSessionSyncPayload.model_validate(payload)
