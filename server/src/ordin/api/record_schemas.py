from datetime import date, datetime, timedelta
from typing import Literal, Self
from uuid import UUID
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import AwareDatetime, Field, field_validator, model_validator

from ordin.api.schemas import ApiModel
from ordin.modules.records.models import (
    FastingPlan,
    FastingSession,
    FastingSessionInput,
    FastingSessionStatus,
    MealInput,
    MealItemInput,
    MealLog,
    MealSource,
    MealType,
    SyncAction,
    SyncChange,
    SyncEntityType,
    SyncOperation,
    SyncPage,
    SyncWriteResult,
    SyncWriteStatus,
    UserPreferences,
    UserPreferencesInput,
)

_TIME_ZONE_PATTERN = r"^[A-Za-z0-9_+./-]+$"
_LOCAL_DAY_PATTERN = r"^[0-9]{4}-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12][0-9]|3[01])$"
_UTC_TIME_ZONE_ALIASES = frozenset({"UTC", "GMT", "Etc/GMT"})


def _parse_local_day(value: str) -> date:
    try:
        return date.fromisoformat(value)
    except ValueError as error:
        raise ValueError("local day must be a calendar date") from error


def _parse_time_zone(value: str) -> ZoneInfo:
    try:
        return ZoneInfo(value)
    except (ValueError, ZoneInfoNotFoundError) as error:
        raise ValueError("timeZoneId must identify an available IANA time zone") from error


def _normalize_time_zone_id(value: str) -> str:
    _parse_time_zone(value)
    return "UTC" if value in _UTC_TIME_ZONE_ALIASES else value


def _require_utc(value: datetime, *, field_name: str) -> None:
    if value.utcoffset() != timedelta(0):
        raise ValueError(f"{field_name} must use UTC")


def _require_local_day(
    *,
    value: datetime,
    local_day: str,
    time_zone: ZoneInfo,
    field_name: str,
) -> None:
    if value.astimezone(time_zone).date() != _parse_local_day(local_day):
        raise ValueError(f"{field_name} does not match its UTC instant and timeZoneId")


class MealItemInputModel(ApiModel):
    id: UUID
    name: str = Field(min_length=1, max_length=120)
    serving_milli: int = Field(gt=0, le=10_000_000)
    energy_kcal: int = Field(ge=0, le=100_000)
    protein_mg: int = Field(ge=0, le=10_000_000)
    carbs_mg: int = Field(ge=0, le=10_000_000)
    fat_mg: int = Field(ge=0, le=10_000_000)
    image_reference: str | None = Field(
        default=None,
        max_length=512,
        pattern=r"^[A-Za-z0-9][A-Za-z0-9._/-]*$",
    )

    @field_validator("name")
    @classmethod
    def normalize_name(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("name must contain non-whitespace characters")
        return normalized

    @field_validator("image_reference")
    @classmethod
    def validate_image_reference(cls, value: str | None) -> str | None:
        if value is None:
            return None
        if value.startswith("/") or "\\" in value or "://" in value:
            raise ValueError("imageReference must be an opaque object key")
        if any(part in {"", ".", ".."} for part in value.split("/")):
            raise ValueError("imageReference contains an unsafe path segment")
        return value

    def to_domain(self) -> MealItemInput:
        return MealItemInput(
            id=self.id,
            name=self.name,
            serving_milli=self.serving_milli,
            energy_kcal=self.energy_kcal,
            protein_mg=self.protein_mg,
            carbs_mg=self.carbs_mg,
            fat_mg=self.fat_mg,
            image_reference=self.image_reference,
        )


class MealSyncPayload(ApiModel):
    type: MealType
    source: MealSource
    occurred_at_utc: AwareDatetime
    time_zone_id: str = Field(min_length=1, max_length=64, pattern=_TIME_ZONE_PATTERN)
    local_day: str = Field(pattern=_LOCAL_DAY_PATTERN)
    is_within_eating_window: bool
    items: list[MealItemInputModel] = Field(min_length=1, max_length=50)

    @field_validator("local_day")
    @classmethod
    def validate_local_day(cls, value: str) -> str:
        _parse_local_day(value)
        return value

    @field_validator("time_zone_id")
    @classmethod
    def validate_time_zone_id(cls, value: str) -> str:
        return _normalize_time_zone_id(value)

    @model_validator(mode="after")
    def validate_consistency(self) -> Self:
        if len({item.id for item in self.items}) != len(self.items):
            raise ValueError("meal item identifiers must be unique")
        _require_utc(self.occurred_at_utc, field_name="occurredAtUtc")
        _require_local_day(
            value=self.occurred_at_utc,
            local_day=self.local_day,
            time_zone=_parse_time_zone(self.time_zone_id),
            field_name="localDay",
        )
        return self

    def to_domain(self) -> MealInput:
        return MealInput(
            type=self.type,
            source=self.source,
            occurred_at=self.occurred_at_utc,
            time_zone_id=self.time_zone_id,
            local_day=_parse_local_day(self.local_day),
            is_within_eating_window=self.is_within_eating_window,
            items=tuple(item.to_domain() for item in self.items),
        )


class FastingSessionSyncPayload(ApiModel):
    plan: FastingPlan
    status: FastingSessionStatus
    started_at_utc: AwareDatetime
    target_end_at_utc: AwareDatetime
    ended_at_utc: AwareDatetime | None = None
    time_zone_id: str = Field(min_length=1, max_length=64, pattern=_TIME_ZONE_PATTERN)
    started_local_day: str = Field(pattern=_LOCAL_DAY_PATTERN)
    target_end_local_day: str = Field(pattern=_LOCAL_DAY_PATTERN)
    ended_local_day: str | None = Field(default=None, pattern=_LOCAL_DAY_PATTERN)

    @field_validator("started_local_day", "target_end_local_day", "ended_local_day")
    @classmethod
    def validate_local_days(cls, value: str | None) -> str | None:
        if value is not None:
            _parse_local_day(value)
        return value

    @field_validator("time_zone_id")
    @classmethod
    def validate_time_zone_id(cls, value: str) -> str:
        return _normalize_time_zone_id(value)

    @model_validator(mode="after")
    def validate_consistency(self) -> Self:
        _require_utc(self.started_at_utc, field_name="startedAtUtc")
        _require_utc(self.target_end_at_utc, field_name="targetEndAtUtc")
        if self.ended_at_utc is not None:
            _require_utc(self.ended_at_utc, field_name="endedAtUtc")

        if self.target_end_at_utc <= self.started_at_utc:
            raise ValueError("targetEndAtUtc must be after startedAtUtc")
        expected_target = self.started_at_utc + timedelta(hours=self.plan.fasting_hours)
        if abs((self.target_end_at_utc - expected_target).total_seconds()) > 1:
            raise ValueError("targetEndAtUtc must match the selected fasting plan")

        if self.status is FastingSessionStatus.ACTIVE:
            if self.ended_at_utc is not None or self.ended_local_day is not None:
                raise ValueError("active sessions cannot have end metadata")
        elif self.ended_at_utc is None or self.ended_local_day is None:
            raise ValueError("finished sessions require endedAtUtc and endedLocalDay")
        elif self.ended_at_utc < self.started_at_utc:
            raise ValueError("endedAtUtc cannot be before startedAtUtc")

        if (
            self.status is FastingSessionStatus.COMPLETED
            and self.ended_at_utc is not None
            and abs((self.ended_at_utc - self.target_end_at_utc).total_seconds()) > 1
        ):
            raise ValueError("completed sessions must end at targetEndAtUtc")

        time_zone = _parse_time_zone(self.time_zone_id)
        _require_local_day(
            value=self.started_at_utc,
            local_day=self.started_local_day,
            time_zone=time_zone,
            field_name="startedLocalDay",
        )
        _require_local_day(
            value=self.target_end_at_utc,
            local_day=self.target_end_local_day,
            time_zone=time_zone,
            field_name="targetEndLocalDay",
        )
        if self.ended_at_utc is not None and self.ended_local_day is not None:
            _require_local_day(
                value=self.ended_at_utc,
                local_day=self.ended_local_day,
                time_zone=time_zone,
                field_name="endedLocalDay",
            )
        return self

    def to_domain(self) -> FastingSessionInput:
        return FastingSessionInput(
            plan=self.plan,
            status=self.status,
            started_at=self.started_at_utc,
            target_end_at=self.target_end_at_utc,
            ended_at=self.ended_at_utc,
            time_zone_id=self.time_zone_id,
            started_local_day=_parse_local_day(self.started_local_day),
            target_end_local_day=_parse_local_day(self.target_end_local_day),
            ended_local_day=(
                _parse_local_day(self.ended_local_day) if self.ended_local_day is not None else None
            ),
        )


class AppPreferencesSyncPayload(ApiModel):
    daily_energy_target_kcal: int = Field(gt=0, le=20_000)
    selected_fasting_plan: FastingPlan
    fasting_reminder_enabled: bool

    def to_domain(self) -> UserPreferencesInput:
        return UserPreferencesInput(
            daily_energy_target_kcal=self.daily_energy_target_kcal,
            selected_fasting_plan=self.selected_fasting_plan,
            fasting_reminder_enabled=self.fasting_reminder_enabled,
        )


class SyncOperationInput(ApiModel):
    operation_id: UUID
    entity_type: SyncEntityType
    entity_id: str = Field(min_length=1, max_length=36)
    action: SyncAction
    expected_version: int = Field(ge=0)
    payload_version: Literal[1] = 1
    meal: MealSyncPayload | None = None
    fasting_session: FastingSessionSyncPayload | None = None
    app_preferences: AppPreferencesSyncPayload | None = None

    @model_validator(mode="after")
    def payload_matches_operation(self) -> Self:
        if self.action is SyncAction.DELETE:
            if self.entity_type is SyncEntityType.APP_PREFERENCES:
                raise ValueError("appPreferences cannot be deleted")
            if (
                self.meal is not None
                or self.fasting_session is not None
                or self.app_preferences is not None
            ):
                raise ValueError("delete operations cannot include an entity payload")
            self._validate_entity_id()
            return self
        if self.entity_type is SyncEntityType.MEAL_LOG:
            if (
                self.meal is None
                or self.fasting_session is not None
                or self.app_preferences is not None
            ):
                raise ValueError("mealLog upserts require only a meal payload")
        elif self.entity_type is SyncEntityType.FASTING_SESSION and (
            self.fasting_session is None
            or self.meal is not None
            or self.app_preferences is not None
        ):
            raise ValueError("fastingSession upserts require only a fastingSession payload")
        elif self.entity_type is SyncEntityType.APP_PREFERENCES and (
            self.app_preferences is None
            or self.meal is not None
            or self.fasting_session is not None
        ):
            raise ValueError("appPreferences upserts require only an appPreferences payload")
        self._validate_entity_id()
        return self

    def _validate_entity_id(self) -> None:
        if self.entity_type is SyncEntityType.APP_PREFERENCES:
            if self.entity_id != "current":
                raise ValueError("appPreferences entityId must be current")
            return
        try:
            parsed = UUID(self.entity_id)
        except ValueError as error:
            raise ValueError("record entityId must be a UUID") from error
        if str(parsed) != self.entity_id:
            raise ValueError("record entityId must use canonical UUID formatting")

    def to_domain(self) -> SyncOperation:
        return SyncOperation(
            operation_id=self.operation_id,
            entity_type=self.entity_type,
            entity_id=self.entity_id,
            action=self.action,
            expected_version=self.expected_version,
            payload_version=self.payload_version,
            meal=self.meal.to_domain() if self.meal is not None else None,
            fasting_session=(
                self.fasting_session.to_domain() if self.fasting_session is not None else None
            ),
            app_preferences=(
                self.app_preferences.to_domain() if self.app_preferences is not None else None
            ),
        )


class SyncPushInput(ApiModel):
    operations: list[SyncOperationInput] = Field(min_length=1, max_length=100)


class SyncWriteResultResponse(ApiModel):
    operation_id: UUID
    entity_type: SyncEntityType
    entity_id: str
    status: SyncWriteStatus
    replayed: bool
    server_version: int | None
    change_cursor: int | None

    @classmethod
    def from_domain(cls, result: SyncWriteResult) -> SyncWriteResultResponse:
        return cls(
            operation_id=result.operation_id,
            entity_type=result.entity_type,
            entity_id=result.entity_id,
            status=result.status,
            replayed=result.replayed,
            server_version=result.current_version,
            change_cursor=result.change_cursor,
        )


class SyncPushResponse(ApiModel):
    results: list[SyncWriteResultResponse]


class MealItemResponse(ApiModel):
    id: UUID
    name: str
    serving_milli: int
    energy_kcal: int
    protein_mg: int
    carbs_mg: int
    fat_mg: int
    image_reference: str | None

    @classmethod
    def from_domain(cls, item: MealItemInput) -> MealItemResponse:
        return cls(
            id=item.id,
            name=item.name,
            serving_milli=item.serving_milli,
            energy_kcal=item.energy_kcal,
            protein_mg=item.protein_mg,
            carbs_mg=item.carbs_mg,
            fat_mg=item.fat_mg,
            image_reference=item.image_reference,
        )


class MealResponse(ApiModel):
    id: UUID
    type: MealType
    source: MealSource
    occurred_at_utc: datetime
    time_zone_id: str
    local_day: str = Field(pattern=_LOCAL_DAY_PATTERN)
    is_within_eating_window: bool
    items: list[MealItemResponse]
    version: int
    change_cursor: int
    created_at_utc: datetime
    updated_at_utc: datetime

    @classmethod
    def from_domain(cls, meal: MealLog) -> MealResponse:
        return cls(
            id=meal.id,
            type=meal.type,
            source=meal.source,
            occurred_at_utc=meal.occurred_at,
            time_zone_id=meal.time_zone_id,
            local_day=meal.local_day.isoformat(),
            is_within_eating_window=meal.is_within_eating_window,
            items=[MealItemResponse.from_domain(item) for item in meal.items],
            version=meal.version,
            change_cursor=meal.change_cursor,
            created_at_utc=meal.created_at,
            updated_at_utc=meal.updated_at,
        )


class MealListResponse(ApiModel):
    items: list[MealResponse]


class FastingSessionResponse(ApiModel):
    id: UUID
    plan: FastingPlan
    status: FastingSessionStatus
    started_at_utc: datetime
    target_end_at_utc: datetime
    ended_at_utc: datetime | None
    time_zone_id: str
    started_local_day: str = Field(pattern=_LOCAL_DAY_PATTERN)
    target_end_local_day: str = Field(pattern=_LOCAL_DAY_PATTERN)
    ended_local_day: str | None = Field(default=None, pattern=_LOCAL_DAY_PATTERN)
    version: int
    change_cursor: int
    created_at_utc: datetime
    updated_at_utc: datetime

    @classmethod
    def from_domain(cls, session: FastingSession) -> FastingSessionResponse:
        return cls(
            id=session.id,
            plan=session.plan,
            status=session.status,
            started_at_utc=session.started_at,
            target_end_at_utc=session.target_end_at,
            ended_at_utc=session.ended_at,
            time_zone_id=session.time_zone_id,
            started_local_day=session.started_local_day.isoformat(),
            target_end_local_day=session.target_end_local_day.isoformat(),
            ended_local_day=(
                session.ended_local_day.isoformat() if session.ended_local_day is not None else None
            ),
            version=session.version,
            change_cursor=session.change_cursor,
            created_at_utc=session.created_at,
            updated_at_utc=session.updated_at,
        )


class FastingSessionListResponse(ApiModel):
    items: list[FastingSessionResponse]


class AppPreferencesResponse(ApiModel):
    daily_energy_target_kcal: int
    selected_fasting_plan: FastingPlan
    fasting_reminder_enabled: bool
    version: int
    change_cursor: int
    created_at_utc: datetime
    updated_at_utc: datetime

    @classmethod
    def from_domain(cls, preferences: UserPreferences) -> AppPreferencesResponse:
        return cls(
            daily_energy_target_kcal=preferences.daily_energy_target_kcal,
            selected_fasting_plan=preferences.selected_fasting_plan,
            fasting_reminder_enabled=preferences.fasting_reminder_enabled,
            version=preferences.version,
            change_cursor=preferences.change_cursor,
            created_at_utc=preferences.created_at,
            updated_at_utc=preferences.updated_at,
        )


class SyncChangeResponse(ApiModel):
    entity_type: SyncEntityType
    entity_id: str
    version: int
    change_cursor: int
    deleted_at_utc: datetime | None
    meal: MealResponse | None = None
    fasting_session: FastingSessionResponse | None = None
    app_preferences: AppPreferencesResponse | None = None

    @classmethod
    def from_domain(cls, change: SyncChange) -> SyncChangeResponse:
        return cls(
            entity_type=change.entity_type,
            entity_id=change.entity_id,
            version=change.version,
            change_cursor=change.change_cursor,
            deleted_at_utc=change.deleted_at,
            meal=MealResponse.from_domain(change.meal) if change.meal is not None else None,
            fasting_session=(
                FastingSessionResponse.from_domain(change.fasting_session)
                if change.fasting_session is not None
                else None
            ),
            app_preferences=(
                AppPreferencesResponse.from_domain(change.app_preferences)
                if change.app_preferences is not None
                else None
            ),
        )


class SyncPullResponse(ApiModel):
    changes: list[SyncChangeResponse]
    next_cursor: int
    has_more: bool

    @classmethod
    def from_domain(cls, page: SyncPage) -> SyncPullResponse:
        return cls(
            changes=[SyncChangeResponse.from_domain(change) for change in page.changes],
            next_cursor=page.next_cursor,
            has_more=page.has_more,
        )
