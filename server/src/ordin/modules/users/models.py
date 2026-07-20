from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal
from enum import StrEnum
from uuid import UUID


class UserStatus(StrEnum):
    ACTIVE = "active"
    DELETION_PENDING = "deletion_pending"
    DELETED = "deleted"


class GoalType(StrEnum):
    LOSE_FAT = "loseFat"
    GAIN_MUSCLE = "gainMuscle"
    MAINTAIN = "maintain"
    HEALTHY_EATING = "healthyEating"


@dataclass(frozen=True, slots=True)
class User:
    id: UUID
    nickname: str | None
    status: UserStatus
    version: int
    created_at: datetime
    updated_at: datetime


@dataclass(frozen=True, slots=True)
class HealthProfile:
    user_id: UUID
    birth_date: date | None
    height_cm: Decimal | None
    current_weight_kg: Decimal | None
    target_weight_kg: Decimal | None
    goal_type: GoalType | None
    daily_energy_target_kcal: int | None
    version: int
    created_at: datetime
    updated_at: datetime


@dataclass(frozen=True, slots=True)
class HealthProfileInput:
    birth_date: date | None
    height_cm: Decimal | None
    current_weight_kg: Decimal | None
    target_weight_kg: Decimal | None
    goal_type: GoalType | None


class VersionedWriteStatus(StrEnum):
    UPDATED = "updated"
    NOT_FOUND = "not_found"
    CONFLICT = "conflict"


@dataclass(frozen=True, slots=True)
class UserWriteResult:
    status: VersionedWriteStatus
    user: User | None = None


@dataclass(frozen=True, slots=True)
class HealthProfileWriteResult:
    status: VersionedWriteStatus
    profile: HealthProfile | None = None
