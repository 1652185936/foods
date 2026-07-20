from uuid import uuid4

import pytest
from pydantic import ValidationError

from ordin.api.recognition_schemas import RecognitionCorrectionItemInput


def _item(**overrides: object) -> dict[str, object]:
    value: dict[str, object] = {
        "id": uuid4(),
        "name": " corrected dish ",
        "canonicalFoodId": "   ",
        "servingMilli": 200000,
        "energyKcal": 320,
        "proteinMg": 15000,
        "carbsMg": 35000,
        "fatMg": 10000,
    }
    value.update(overrides)
    return value


def test_correction_text_is_trimmed_and_blank_optional_identifier_becomes_null() -> None:
    item = RecognitionCorrectionItemInput.model_validate(_item())

    assert item.name == "corrected dish"
    assert item.canonical_food_id is None


@pytest.mark.parametrize(
    ("field", "value"),
    [("name", "dish\u0000name"), ("canonicalFoodId", "dish\nidentifier")],
)
def test_correction_rejects_control_characters(field: str, value: str) -> None:
    with pytest.raises(ValidationError):
        RecognitionCorrectionItemInput.model_validate(_item(**{field: value}))
