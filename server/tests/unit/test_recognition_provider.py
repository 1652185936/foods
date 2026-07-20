import httpx
import pytest

from ordin.infrastructure.recognition_provider import HttpRecognitionProvider
from ordin.modules.recognition.errors import ProviderPermanentError


def _provider(payload: dict[str, object]) -> HttpRecognitionProvider:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.headers["Authorization"] == "Bearer provider-token"
        return httpx.Response(200, json=payload)

    return HttpRecognitionProvider(
        client=httpx.Client(transport=httpx.MockTransport(handler)),
        url="https://provider.example/analyze",
        bearer_token="provider-token",
        provider_name="provider-v1",
    )


def _payload(*, name: str, canonical_food_id: str | None = " dish-1 ") -> dict[str, object]:
    return {
        "overallConfidenceMilli": 900,
        "items": [
            {
                "name": name,
                "canonicalFoodId": canonical_food_id,
                "servingMilli": 200000,
                "energyKcal": 320,
                "proteinMg": 15000,
                "carbsMg": 35000,
                "fatMg": 10000,
                "confidenceMilli": 900,
                "alternatives": [{"name": " alternative ", "confidenceMilli": 200}],
            }
        ],
    }


def test_http_provider_trims_untrusted_display_and_identifier_fields() -> None:
    result = _provider(_payload(name=" dish name ")).analyze_food_image(
        content=b"image",
        content_type="image/jpeg",
    )

    assert result.items[0].name == "dish name"
    assert result.items[0].canonical_food_id == "dish-1"
    assert result.items[0].alternatives[0].name == "alternative"


@pytest.mark.parametrize("name", ["   ", "dish\u0000name", "dish\nname"])
def test_http_provider_rejects_blank_or_control_character_names(name: str) -> None:
    with pytest.raises(ProviderPermanentError):
        _provider(_payload(name=name)).analyze_food_image(
            content=b"image",
            content_type="image/jpeg",
        )
