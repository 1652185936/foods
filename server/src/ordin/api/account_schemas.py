from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import Field

from ordin.api.recognition_schemas import RecognitionAlternativeResponse
from ordin.api.record_schemas import AppPreferencesResponse, FastingSessionResponse
from ordin.api.schemas import ApiModel, HealthProfileResponse, UserResponse
from ordin.modules.accounts.models import (
    AccountDataSnapshot,
    AccountRecognitionCorrection,
    AccountRecognitionCorrectionItem,
    AccountRecognitionResult,
)
from ordin.modules.recognition.models import RecognitionItem
from ordin.modules.records.models import MealItemInput, MealLog, MealSource, MealType

_LOCAL_DAY_PATTERN = r"^[0-9]{4}-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12][0-9]|3[01])$"


class AccountDeletionInput(ApiModel):
    confirmation: Literal["DELETE_MY_ACCOUNT"]
    refresh_token: str = Field(min_length=32, max_length=512)
    device_installation_id: UUID


class AccountExportMealItem(ApiModel):
    id: UUID
    name: str
    serving_milli: int
    energy_kcal: int
    protein_mg: int
    carbs_mg: int
    fat_mg: int

    @classmethod
    def from_domain(cls, item: MealItemInput) -> AccountExportMealItem:
        return cls(
            id=item.id,
            name=item.name,
            serving_milli=item.serving_milli,
            energy_kcal=item.energy_kcal,
            protein_mg=item.protein_mg,
            carbs_mg=item.carbs_mg,
            fat_mg=item.fat_mg,
        )


class AccountExportMeal(ApiModel):
    id: UUID
    type: MealType
    source: MealSource
    occurred_at_utc: datetime
    time_zone_id: str
    local_day: str = Field(pattern=_LOCAL_DAY_PATTERN)
    is_within_eating_window: bool
    items: list[AccountExportMealItem]
    version: int
    created_at_utc: datetime
    updated_at_utc: datetime

    @classmethod
    def from_domain(cls, meal: MealLog) -> AccountExportMeal:
        return cls(
            id=meal.id,
            type=meal.type,
            source=meal.source,
            occurred_at_utc=meal.occurred_at,
            time_zone_id=meal.time_zone_id,
            local_day=meal.local_day.isoformat(),
            is_within_eating_window=meal.is_within_eating_window,
            items=[AccountExportMealItem.from_domain(item) for item in meal.items],
            version=meal.version,
            created_at_utc=meal.created_at,
            updated_at_utc=meal.updated_at,
        )


class AccountExportRecognitionItem(ApiModel):
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
    def from_domain(cls, item: RecognitionItem) -> AccountExportRecognitionItem:
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


class AccountExportCorrectionItem(ApiModel):
    id: UUID
    position: int
    name: str
    canonical_food_id: str | None
    serving_milli: int
    energy_kcal: int
    protein_mg: int
    carbs_mg: int
    fat_mg: int

    @classmethod
    def from_domain(
        cls,
        item: AccountRecognitionCorrectionItem,
    ) -> AccountExportCorrectionItem:
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
        )


class AccountExportCorrection(ApiModel):
    id: UUID
    base_version: int
    created_at_utc: datetime
    items: list[AccountExportCorrectionItem]

    @classmethod
    def from_domain(cls, value: AccountRecognitionCorrection) -> AccountExportCorrection:
        return cls(
            id=value.id,
            base_version=value.base_version,
            created_at_utc=value.created_at,
            items=[AccountExportCorrectionItem.from_domain(item) for item in value.items],
        )


class AccountExportRecognition(ApiModel):
    id: UUID
    status: str
    overall_confidence_milli: int | None
    needs_review_reason: str | None
    error_code: str | None
    version: int
    created_at_utc: datetime
    updated_at_utc: datetime
    completed_at_utc: datetime | None
    items: list[AccountExportRecognitionItem]
    corrections: list[AccountExportCorrection]

    @classmethod
    def from_domain(cls, value: AccountRecognitionResult) -> AccountExportRecognition:
        return cls(
            id=value.id,
            status=value.status,
            overall_confidence_milli=value.overall_confidence_milli,
            needs_review_reason=value.needs_review_reason,
            error_code=value.error_code,
            version=value.version,
            created_at_utc=value.created_at,
            updated_at_utc=value.updated_at,
            completed_at_utc=value.completed_at,
            items=[AccountExportRecognitionItem.from_domain(item) for item in value.items],
            corrections=[
                AccountExportCorrection.from_domain(correction) for correction in value.corrections
            ],
        )


class AccountDataExportResponse(ApiModel):
    schema_version: Literal[1] = 1
    exported_at: datetime
    user: UserResponse
    health_profile: HealthProfileResponse | None
    preferences: AppPreferencesResponse | None
    meals: list[AccountExportMeal]
    fasting_sessions: list[FastingSessionResponse]
    recognitions: list[AccountExportRecognition]

    @classmethod
    def from_domain(cls, snapshot: AccountDataSnapshot) -> AccountDataExportResponse:
        return cls(
            exported_at=snapshot.exported_at,
            user=UserResponse.from_domain(snapshot.user),
            health_profile=(
                HealthProfileResponse.from_domain(snapshot.health_profile)
                if snapshot.health_profile is not None
                else None
            ),
            preferences=(
                AppPreferencesResponse.from_domain(snapshot.preferences)
                if snapshot.preferences is not None
                else None
            ),
            meals=[AccountExportMeal.from_domain(meal) for meal in snapshot.meals],
            fasting_sessions=[
                FastingSessionResponse.from_domain(session) for session in snapshot.fasting_sessions
            ],
            recognitions=[
                AccountExportRecognition.from_domain(value) for value in snapshot.recognitions
            ],
        )
