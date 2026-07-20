from dataclasses import dataclass
from datetime import datetime
from enum import StrEnum
from uuid import UUID


class UploadStatus(StrEnum):
    INITIATED = "initiated"
    PROCESSING = "processing"
    READY = "ready"
    CONSUMED = "consumed"
    INVALID = "invalid"
    EXPIRED = "expired"


class RecognitionStatus(StrEnum):
    QUEUED = "queued"
    RUNNING = "running"
    SUCCEEDED = "succeeded"
    NEEDS_REVIEW = "needs_review"
    FAILED = "failed"
    EXPIRED = "expired"


class CorrectionWriteStatus(StrEnum):
    APPLIED = "applied"
    NOT_FOUND = "not_found"
    VERSION_CONFLICT = "version_conflict"
    INVALID_STATE = "invalid_state"


@dataclass(frozen=True, slots=True)
class StoredObject:
    key: str
    size_bytes: int
    content_type: str
    checksum_sha256: str | None


@dataclass(frozen=True, slots=True)
class PresignedUpload:
    url: str
    required_headers: dict[str, str]
    expires_at: datetime


@dataclass(frozen=True, slots=True)
class ProcessedImage:
    content: bytes
    content_type: str
    extension: str
    checksum_sha256: str
    width: int
    height: int


@dataclass(frozen=True, slots=True)
class RecognitionUpload:
    id: UUID
    user_id: UUID
    incoming_object_key: str
    expected_content_type: str
    expected_size_bytes: int
    expected_checksum_sha256: str
    status: UploadStatus
    expires_at: datetime
    claimed_at: datetime | None
    sanitized_object_key: str | None
    sanitized_content_type: str | None
    sanitized_size_bytes: int | None
    sanitized_checksum_sha256: str | None
    width: int | None
    height: int | None
    retention_until: datetime | None
    created_at: datetime
    updated_at: datetime


@dataclass(frozen=True, slots=True)
class UploadClaim:
    upload: RecognitionUpload
    claimed: bool


@dataclass(frozen=True, slots=True)
class RecognitionAlternative:
    name: str
    confidence_milli: int


@dataclass(frozen=True, slots=True)
class RecognitionItem:
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
    alternatives: tuple[RecognitionAlternative, ...]
    is_user_corrected: bool


@dataclass(frozen=True, slots=True)
class RecognitionJob:
    id: UUID
    user_id: UUID
    upload_id: UUID
    status: RecognitionStatus
    provider_name: str | None
    overall_confidence_milli: int | None
    needs_review_reason: str | None
    error_code: str | None
    version: int
    attempt_count: int
    source_retention_until: datetime
    created_at: datetime
    updated_at: datetime
    completed_at: datetime | None
    items: tuple[RecognitionItem, ...]


@dataclass(frozen=True, slots=True)
class RecognitionCreateResult:
    job: RecognitionJob
    created: bool


@dataclass(frozen=True, slots=True)
class CorrectionWriteResult:
    status: CorrectionWriteStatus
    job: RecognitionJob | None


@dataclass(frozen=True, slots=True)
class RecognitionItemInput:
    id: UUID
    name: str
    canonical_food_id: str | None
    serving_milli: int
    energy_kcal: int
    protein_mg: int
    carbs_mg: int
    fat_mg: int


@dataclass(frozen=True, slots=True)
class ProviderFoodCandidate:
    name: str
    canonical_food_id: str | None
    serving_milli: int
    energy_kcal: int
    protein_mg: int
    carbs_mg: int
    fat_mg: int
    confidence_milli: int
    alternatives: tuple[RecognitionAlternative, ...] = ()


@dataclass(frozen=True, slots=True)
class ProviderAnalysis:
    provider_name: str
    overall_confidence_milli: int
    items: tuple[ProviderFoodCandidate, ...]
