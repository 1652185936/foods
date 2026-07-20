from dataclasses import dataclass
from datetime import datetime
from uuid import UUID

from ordin.modules.recognition.models import RecognitionItem
from ordin.modules.records.models import FastingSession, MealLog, UserPreferences
from ordin.modules.users.models import HealthProfile, User


@dataclass(frozen=True, slots=True)
class AccountRecognitionCorrectionItem:
    id: UUID
    position: int
    name: str
    canonical_food_id: str | None
    serving_milli: int
    energy_kcal: int
    protein_mg: int
    carbs_mg: int
    fat_mg: int


@dataclass(frozen=True, slots=True)
class AccountRecognitionCorrection:
    id: UUID
    base_version: int
    created_at: datetime
    items: tuple[AccountRecognitionCorrectionItem, ...]


@dataclass(frozen=True, slots=True)
class AccountRecognitionResult:
    id: UUID
    status: str
    overall_confidence_milli: int | None
    needs_review_reason: str | None
    error_code: str | None
    version: int
    created_at: datetime
    updated_at: datetime
    completed_at: datetime | None
    items: tuple[RecognitionItem, ...]
    corrections: tuple[AccountRecognitionCorrection, ...]


@dataclass(frozen=True, slots=True)
class AccountDataSnapshot:
    exported_at: datetime
    user: User
    health_profile: HealthProfile | None
    preferences: UserPreferences | None
    meals: tuple[MealLog, ...]
    fasting_sessions: tuple[FastingSession, ...]
    recognitions: tuple[AccountRecognitionResult, ...]


@dataclass(frozen=True, slots=True)
class AccountObjectCleanup:
    id: UUID
    object_key: str


@dataclass(frozen=True, slots=True)
class AccountDeletion:
    immediate_cleanups: tuple[AccountObjectCleanup, ...]
