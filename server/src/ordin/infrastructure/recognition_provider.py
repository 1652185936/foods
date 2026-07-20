import hashlib
import unicodedata
from typing import Annotated

import httpx
from pydantic import BaseModel, ConfigDict, Field, ValidationError, field_validator

from ordin.modules.recognition.errors import ProviderPermanentError, ProviderTemporaryError
from ordin.modules.recognition.models import (
    ProviderAnalysis,
    ProviderFoodCandidate,
    RecognitionAlternative,
)


def _to_camel(value: str) -> str:
    first, *rest = value.split("_")
    return first + "".join(part.capitalize() for part in rest)


class _AlternativePayload(BaseModel):
    model_config = ConfigDict(alias_generator=_to_camel, populate_by_name=True, extra="forbid")

    name: Annotated[str, Field(min_length=1, max_length=120)]
    confidence_milli: Annotated[int, Field(ge=0, le=1000)]

    @field_validator("name")
    @classmethod
    def _normalize_name(cls, value: str) -> str:
        return _normalize_untrusted_text(value, field_name="alternative name")


class _CandidatePayload(BaseModel):
    model_config = ConfigDict(alias_generator=_to_camel, populate_by_name=True, extra="forbid")

    name: Annotated[str, Field(min_length=1, max_length=120)]
    canonical_food_id: Annotated[str | None, Field(max_length=120)] = None
    serving_milli: Annotated[int, Field(gt=0, le=10_000_000)]
    energy_kcal: Annotated[int, Field(ge=0, le=100_000)]
    protein_mg: Annotated[int, Field(ge=0, le=10_000_000)]
    carbs_mg: Annotated[int, Field(ge=0, le=10_000_000)]
    fat_mg: Annotated[int, Field(ge=0, le=10_000_000)]
    confidence_milli: Annotated[int, Field(ge=0, le=1000)]
    alternatives: list[_AlternativePayload] = Field(default_factory=list, max_length=5)

    @field_validator("name")
    @classmethod
    def _normalize_name(cls, value: str) -> str:
        return _normalize_untrusted_text(value, field_name="candidate name")

    @field_validator("canonical_food_id")
    @classmethod
    def _normalize_canonical_food_id(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return _normalize_untrusted_text(value, field_name="canonical food id")


class _ProviderPayload(BaseModel):
    model_config = ConfigDict(alias_generator=_to_camel, populate_by_name=True, extra="forbid")

    overall_confidence_milli: Annotated[int, Field(ge=0, le=1000)]
    items: Annotated[list[_CandidatePayload], Field(min_length=1, max_length=10)]


class DeterministicDevelopmentRecognitionProvider:
    """Explicitly synthetic provider used only in development and tests."""

    def analyze_food_image(self, *, content: bytes, content_type: str) -> ProviderAnalysis:
        del content_type
        digest = hashlib.sha256(content).digest()
        variant = digest[0] % 3
        names = ("Development rice bowl", "Development mixed plate", "Development salad")
        energy = 420 + (digest[1] % 9) * 10
        candidate = ProviderFoodCandidate(
            name=names[variant],
            canonical_food_id=f"development-{variant}",
            serving_milli=350_000,
            energy_kcal=energy,
            protein_mg=18_000,
            carbs_mg=52_000,
            fat_mg=14_000,
            confidence_milli=900,
            alternatives=(
                RecognitionAlternative(name="Development alternative", confidence_milli=300),
            ),
        )
        return ProviderAnalysis(
            provider_name="development-deterministic",
            overall_confidence_milli=900,
            items=(candidate,),
        )


class HttpRecognitionProvider:
    def __init__(
        self,
        *,
        client: httpx.Client,
        url: str,
        bearer_token: str,
        provider_name: str,
    ) -> None:
        self._client = client
        self._url = url
        self._bearer_token = bearer_token
        self._provider_name = provider_name

    def analyze_food_image(self, *, content: bytes, content_type: str) -> ProviderAnalysis:
        try:
            response = self._client.post(
                self._url,
                headers={"Authorization": f"Bearer {self._bearer_token}"},
                files={"image": ("food-image", content, content_type)},
            )
        except (httpx.TimeoutException, httpx.NetworkError) as error:
            raise ProviderTemporaryError from error
        if response.status_code == 429 or response.status_code >= 500:
            raise ProviderTemporaryError
        if not 200 <= response.status_code < 300:
            raise ProviderPermanentError
        try:
            payload = _ProviderPayload.model_validate(response.json())
        except (ValueError, ValidationError) as error:
            raise ProviderPermanentError from error
        return ProviderAnalysis(
            provider_name=self._provider_name,
            overall_confidence_milli=payload.overall_confidence_milli,
            items=tuple(
                ProviderFoodCandidate(
                    name=item.name,
                    canonical_food_id=item.canonical_food_id,
                    serving_milli=item.serving_milli,
                    energy_kcal=item.energy_kcal,
                    protein_mg=item.protein_mg,
                    carbs_mg=item.carbs_mg,
                    fat_mg=item.fat_mg,
                    confidence_milli=item.confidence_milli,
                    alternatives=tuple(
                        RecognitionAlternative(
                            name=alternative.name,
                            confidence_milli=alternative.confidence_milli,
                        )
                        for alternative in item.alternatives
                    ),
                )
                for item in payload.items
            ),
        )


def _normalize_untrusted_text(value: str, *, field_name: str) -> str:
    normalized = value.strip()
    if not normalized:
        raise ValueError(f"{field_name} must contain non-whitespace characters")
    if any(unicodedata.category(character).startswith("C") for character in normalized):
        raise ValueError(f"{field_name} must not contain control characters")
    return normalized
