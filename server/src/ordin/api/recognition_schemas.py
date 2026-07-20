import unicodedata
from datetime import datetime
from typing import Literal, Self
from uuid import UUID

from pydantic import Field, field_validator, model_validator

from ordin.api.schemas import ApiModel
from ordin.modules.recognition.models import (
    RecognitionAlternative,
    RecognitionItem,
    RecognitionItemInput,
    RecognitionJob,
    RecognitionUpload,
)


class RecognitionUploadInput(ApiModel):
    content_type: Literal["image/jpeg", "image/png", "image/webp"]
    size_bytes: int = Field(gt=0, le=20 * 1024 * 1024)
    checksum_sha256: str = Field(pattern=r"^[0-9a-fA-F]{64}$")


class RecognitionUploadResponse(ApiModel):
    upload_session_id: UUID
    object_key: str
    status: str
    upload_url: str
    upload_headers: dict[str, str]
    expires_at: datetime


class CompletedRecognitionUploadResponse(ApiModel):
    upload_session_id: UUID
    status: str
    source_object_key: str
    source_content_type: str
    source_size_bytes: int
    width: int
    height: int
    source_expires_at: datetime

    @classmethod
    def from_domain(cls, upload: RecognitionUpload) -> CompletedRecognitionUploadResponse:
        if (
            upload.sanitized_object_key is None
            or upload.sanitized_content_type is None
            or upload.sanitized_size_bytes is None
            or upload.width is None
            or upload.height is None
            or upload.retention_until is None
        ):
            raise RuntimeError("completed upload is missing sanitized image metadata")
        return cls(
            upload_session_id=upload.id,
            status=upload.status.value,
            source_object_key=upload.sanitized_object_key,
            source_content_type=upload.sanitized_content_type,
            source_size_bytes=upload.sanitized_size_bytes,
            width=upload.width,
            height=upload.height,
            source_expires_at=upload.retention_until,
        )


class RecognitionCreateInput(ApiModel):
    upload_session_id: UUID


class RecognitionAlternativeResponse(ApiModel):
    name: str
    confidence_milli: int

    @classmethod
    def from_domain(cls, value: RecognitionAlternative) -> RecognitionAlternativeResponse:
        return cls(name=value.name, confidence_milli=value.confidence_milli)


class RecognitionItemResponse(ApiModel):
    id: UUID
    position: int
    name: str
    canonical_food_id: str | None
    serving_milli: int
    energy_kcal: int
    protein_mg: int
    carbs_mg: int
    fat_mg: int
    confidence_milli: int
    alternatives: list[RecognitionAlternativeResponse]
    is_user_corrected: bool

    @classmethod
    def from_domain(cls, item: RecognitionItem) -> RecognitionItemResponse:
        return cls(
            id=item.id,
            position=item.position,
            name=item.name,
            canonical_food_id=item.canonical_food_id,
            serving_milli=item.serving_milli,
            energy_kcal=item.energy_kcal,
            protein_mg=item.protein_mg,
            carbs_mg=item.carbs_mg,
            fat_mg=item.fat_mg,
            confidence_milli=item.confidence_milli,
            alternatives=[
                RecognitionAlternativeResponse.from_domain(value) for value in item.alternatives
            ],
            is_user_corrected=item.is_user_corrected,
        )


class RecognitionResponse(ApiModel):
    id: UUID
    upload_session_id: UUID
    status: str
    provider_name: str | None
    overall_confidence_milli: int | None
    needs_review_reason: str | None
    error_code: str | None
    version: int
    source_expires_at: datetime
    created_at: datetime
    updated_at: datetime
    completed_at: datetime | None
    items: list[RecognitionItemResponse]

    @classmethod
    def from_domain(cls, job: RecognitionJob) -> RecognitionResponse:
        return cls(
            id=job.id,
            upload_session_id=job.upload_id,
            status=job.status.value,
            provider_name=job.provider_name,
            overall_confidence_milli=job.overall_confidence_milli,
            needs_review_reason=job.needs_review_reason,
            error_code=job.error_code,
            version=job.version,
            source_expires_at=job.source_retention_until,
            created_at=job.created_at,
            updated_at=job.updated_at,
            completed_at=job.completed_at,
            items=[RecognitionItemResponse.from_domain(item) for item in job.items],
        )


class RecognitionCorrectionItemInput(ApiModel):
    id: UUID
    name: str = Field(min_length=1, max_length=120)
    canonical_food_id: str | None = Field(default=None, max_length=120)
    serving_milli: int = Field(gt=0, le=10_000_000)
    energy_kcal: int = Field(ge=0, le=100_000)
    protein_mg: int = Field(ge=0, le=10_000_000)
    carbs_mg: int = Field(ge=0, le=10_000_000)
    fat_mg: int = Field(ge=0, le=10_000_000)

    @field_validator("name")
    @classmethod
    def normalize_name(cls, value: str) -> str:
        return _normalize_printable(value, field_name="name")

    @field_validator("canonical_food_id")
    @classmethod
    def normalize_canonical_food_id(cls, value: str | None) -> str | None:
        if value is None or not value.strip():
            return None
        return _normalize_printable(value, field_name="canonicalFoodId")

    def to_domain(self) -> RecognitionItemInput:
        return RecognitionItemInput(
            id=self.id,
            name=self.name,
            canonical_food_id=self.canonical_food_id,
            serving_milli=self.serving_milli,
            energy_kcal=self.energy_kcal,
            protein_mg=self.protein_mg,
            carbs_mg=self.carbs_mg,
            fat_mg=self.fat_mg,
        )


class RecognitionCorrectionInput(ApiModel):
    expected_version: int = Field(ge=1)
    items: list[RecognitionCorrectionItemInput] = Field(min_length=1, max_length=10)

    @model_validator(mode="after")
    def require_unique_item_ids(self) -> Self:
        if len({item.id for item in self.items}) != len(self.items):
            raise ValueError("correction item ids must be unique")
        return self


def _normalize_printable(value: str, *, field_name: str) -> str:
    normalized = value.strip()
    if not normalized:
        raise ValueError(f"{field_name} must contain non-whitespace characters")
    if any(unicodedata.category(character).startswith("C") for character in normalized):
        raise ValueError(f"{field_name} must not contain control characters")
    return normalized
