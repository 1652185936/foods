from dataclasses import dataclass
from datetime import date, datetime
from enum import StrEnum
from uuid import UUID


class MealType(StrEnum):
    BREAKFAST = "breakfast"
    LUNCH = "lunch"
    DINNER = "dinner"
    SNACK = "snack"


class MealSource(StrEnum):
    MANUAL = "manual"
    RECOGNITION = "recognition"
    RECIPE = "recipe"


class FastingPlan(StrEnum):
    GENTLE = "gentle"
    BALANCED = "balanced"
    ADVANCED = "advanced"

    @property
    def fasting_hours(self) -> int:
        return {
            FastingPlan.GENTLE: 14,
            FastingPlan.BALANCED: 16,
            FastingPlan.ADVANCED: 18,
        }[self]


class FastingSessionStatus(StrEnum):
    ACTIVE = "active"
    COMPLETED = "completed"
    CANCELLED = "cancelled"


class SyncEntityType(StrEnum):
    MEAL_LOG = "mealLog"
    FASTING_SESSION = "fastingSession"
    APP_PREFERENCES = "appPreferences"


class SyncAction(StrEnum):
    UPSERT = "upsert"
    DELETE = "delete"


class SyncWriteStatus(StrEnum):
    APPLIED = "applied"
    VERSION_CONFLICT = "versionConflict"
    NOT_FOUND = "notFound"
    IDEMPOTENCY_CONFLICT = "idempotencyConflict"
    ACTIVE_FASTING_CONFLICT = "activeFastingConflict"


@dataclass(frozen=True, slots=True)
class MealItemInput:
    id: UUID
    name: str
    serving_milli: int
    energy_kcal: int
    protein_mg: int
    carbs_mg: int
    fat_mg: int
    image_reference: str | None


@dataclass(frozen=True, slots=True)
class MealInput:
    type: MealType
    source: MealSource
    occurred_at: datetime
    time_zone_id: str
    local_day: date
    is_within_eating_window: bool
    items: tuple[MealItemInput, ...]


@dataclass(frozen=True, slots=True)
class MealLog:
    id: UUID
    user_id: UUID
    type: MealType
    source: MealSource
    occurred_at: datetime
    time_zone_id: str
    local_day: date
    is_within_eating_window: bool
    items: tuple[MealItemInput, ...]
    version: int
    change_cursor: int
    deleted_at: datetime | None
    created_at: datetime
    updated_at: datetime


@dataclass(frozen=True, slots=True)
class FastingSessionInput:
    plan: FastingPlan
    status: FastingSessionStatus
    started_at: datetime
    target_end_at: datetime
    ended_at: datetime | None
    time_zone_id: str
    started_local_day: date
    target_end_local_day: date
    ended_local_day: date | None


@dataclass(frozen=True, slots=True)
class FastingSession:
    id: UUID
    user_id: UUID
    plan: FastingPlan
    status: FastingSessionStatus
    started_at: datetime
    target_end_at: datetime
    ended_at: datetime | None
    time_zone_id: str
    started_local_day: date
    target_end_local_day: date
    ended_local_day: date | None
    version: int
    change_cursor: int
    deleted_at: datetime | None
    created_at: datetime
    updated_at: datetime


@dataclass(frozen=True, slots=True)
class UserPreferencesInput:
    daily_energy_target_kcal: int
    selected_fasting_plan: FastingPlan
    fasting_reminder_enabled: bool


@dataclass(frozen=True, slots=True)
class UserPreferences:
    user_id: UUID
    daily_energy_target_kcal: int
    selected_fasting_plan: FastingPlan
    fasting_reminder_enabled: bool
    version: int
    change_cursor: int
    created_at: datetime
    updated_at: datetime


@dataclass(frozen=True, slots=True)
class SyncOperation:
    operation_id: UUID
    entity_type: SyncEntityType
    entity_id: str
    action: SyncAction
    expected_version: int
    payload_version: int
    meal: MealInput | None = None
    fasting_session: FastingSessionInput | None = None
    app_preferences: UserPreferencesInput | None = None


@dataclass(frozen=True, slots=True)
class SyncWriteResult:
    operation_id: UUID
    entity_type: SyncEntityType
    entity_id: str
    status: SyncWriteStatus
    replayed: bool
    current_version: int | None
    change_cursor: int | None


@dataclass(frozen=True, slots=True)
class SyncChange:
    entity_type: SyncEntityType
    entity_id: str
    version: int
    change_cursor: int
    deleted_at: datetime | None
    meal: MealLog | None = None
    fasting_session: FastingSession | None = None
    app_preferences: UserPreferences | None = None


@dataclass(frozen=True, slots=True)
class SyncPage:
    changes: tuple[SyncChange, ...]
    next_cursor: int
    has_more: bool
