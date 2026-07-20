from datetime import date, datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from ordin.modules.auth.models import ClientPlatform, TokenPair
from ordin.modules.users.models import GoalType, HealthProfile, HealthProfileInput, User

_HEIGHT_PATTERN = r"^(?:0\.(?:0[1-9]|[1-9][0-9]?)|[1-9][0-9]{0,2}(?:\.[0-9]{1,2})?)$"
_WEIGHT_PATTERN = r"^(?:0\.(?:0[1-9]|[1-9][0-9]?)|[1-9][0-9]{0,3}(?:\.[0-9]{1,2})?)$"
_LOCAL_DAY_PATTERN = r"^[0-9]{4}-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12][0-9]|3[01])$"


def _decimal_or_none(value: str | None) -> Decimal | None:
    return Decimal(value) if value is not None else None


def _decimal_string(value: Decimal | None) -> str | None:
    return format(value, "f") if value is not None else None


def _date_or_none(value: str | None) -> date | None:
    if value is None:
        return None
    try:
        return date.fromisoformat(value)
    except ValueError as error:
        raise ValueError("date must be a calendar date") from error


def _to_camel(value: str) -> str:
    head, *tail = value.split("_")
    return head + "".join(part.capitalize() for part in tail)


class ApiModel(BaseModel):
    model_config = ConfigDict(
        alias_generator=_to_camel,
        populate_by_name=True,
        serialize_by_alias=True,
        extra="forbid",
    )


class FieldProblem(ApiModel):
    field: str
    code: str
    message: str


class ProblemDetails(ApiModel):
    type: str
    title: str
    status: int
    code: str
    trace_id: str
    detail: str | None = None
    field_errors: list[FieldProblem] | None = None


class DeviceInput(ApiModel):
    installation_id: UUID
    platform: ClientPlatform
    app_version: str = Field(min_length=1, max_length=32)


class OtpChallengeInput(ApiModel):
    phone_number: str = Field(pattern=r"^\+[1-9][0-9]{7,14}$")
    device_installation_id: UUID


class OtpChallengeResponse(ApiModel):
    challenge_id: UUID
    expires_at: datetime
    resend_after_seconds: int


class OtpVerificationInput(ApiModel):
    code: str = Field(pattern=r"^[0-9]{6}$")
    device: DeviceInput


class RefreshTokenInput(ApiModel):
    refresh_token: str = Field(min_length=32, max_length=512)
    device_installation_id: UUID


class TokenPairResponse(ApiModel):
    token_type: str = "Bearer"
    access_token: str
    access_token_expires_at: datetime
    refresh_token: str
    refresh_token_expires_at: datetime

    @classmethod
    def from_domain(cls, pair: TokenPair) -> TokenPairResponse:
        return cls(
            access_token=pair.access_token,
            access_token_expires_at=pair.access_expires_at,
            refresh_token=pair.refresh_token,
            refresh_token_expires_at=pair.refresh_expires_at,
        )


class UserResponse(ApiModel):
    id: UUID
    nickname: str | None
    status: str
    version: int
    created_at: datetime
    updated_at: datetime

    @classmethod
    def from_domain(cls, user: User) -> UserResponse:
        return cls(
            id=user.id,
            nickname=user.nickname,
            status=user.status.value,
            version=user.version,
            created_at=user.created_at,
            updated_at=user.updated_at,
        )


class AuthSessionResponse(ApiModel):
    tokens: TokenPairResponse
    user: UserResponse


class UserPatchInput(ApiModel):
    expected_version: int = Field(ge=1)
    nickname: str = Field(min_length=1, max_length=40)


class HealthProfileInputModel(ApiModel):
    expected_version: int = Field(ge=0)
    birth_date: str | None = Field(default=None, pattern=_LOCAL_DAY_PATTERN)
    height_cm: str | None = Field(default=None, pattern=_HEIGHT_PATTERN)
    current_weight_kg: str | None = Field(default=None, pattern=_WEIGHT_PATTERN)
    target_weight_kg: str | None = Field(default=None, pattern=_WEIGHT_PATTERN)
    goal_type: GoalType | None = None

    @field_validator("birth_date")
    @classmethod
    def validate_birth_date(cls, value: str | None) -> str | None:
        _date_or_none(value)
        return value

    def to_domain(self) -> HealthProfileInput:
        return HealthProfileInput(
            birth_date=_date_or_none(self.birth_date),
            height_cm=_decimal_or_none(self.height_cm),
            current_weight_kg=_decimal_or_none(self.current_weight_kg),
            target_weight_kg=_decimal_or_none(self.target_weight_kg),
            goal_type=self.goal_type,
        )


class HealthProfileResponse(ApiModel):
    user_id: UUID
    birth_date: str | None = Field(default=None, pattern=_LOCAL_DAY_PATTERN)
    height_cm: str | None
    current_weight_kg: str | None
    target_weight_kg: str | None
    goal_type: GoalType | None
    daily_energy_target_kcal: int | None
    version: int
    created_at: datetime
    updated_at: datetime

    @classmethod
    def from_domain(cls, profile: HealthProfile) -> HealthProfileResponse:
        return cls(
            user_id=profile.user_id,
            birth_date=profile.birth_date.isoformat() if profile.birth_date is not None else None,
            height_cm=_decimal_string(profile.height_cm),
            current_weight_kg=_decimal_string(profile.current_weight_kg),
            target_weight_kg=_decimal_string(profile.target_weight_kg),
            goal_type=profile.goal_type,
            daily_energy_target_kcal=profile.daily_energy_target_kcal,
            version=profile.version,
            created_at=profile.created_at,
            updated_at=profile.updated_at,
        )
