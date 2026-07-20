from datetime import date, datetime
from decimal import Decimal
from uuid import UUID

from sqlalchemy import (
    BigInteger,
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    ForeignKeyConstraint,
    Index,
    Integer,
    Numeric,
    PrimaryKeyConstraint,
    Sequence,
    String,
    UniqueConstraint,
    Uuid,
    func,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column

from ordin.infrastructure.database.base import Base

sync_revision_sequence = Sequence("ordin_sync_revision_seq", metadata=Base.metadata)


class UserRow(Base):
    __tablename__ = "users"
    __table_args__ = (
        CheckConstraint(
            "status IN ('active', 'deletion_pending', 'deleted')",
            name="status_valid",
        ),
        CheckConstraint("version >= 1", name="version_positive"),
    )

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True)
    nickname: Mapped[str | None] = mapped_column(String(40))
    status: Mapped[str] = mapped_column(String(32), nullable=False, default="active")
    version: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class AuthIdentityRow(Base):
    __tablename__ = "auth_identities"
    __table_args__ = (
        UniqueConstraint(
            "provider",
            "subject_hash",
            name="uq_auth_identities_provider_subject",
        ),
        CheckConstraint("provider IN ('phone')", name="provider_valid"),
    )

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True)
    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    provider: Mapped[str] = mapped_column(String(32), nullable=False)
    subject_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class DeviceRow(Base):
    __tablename__ = "devices"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "installation_id",
            name="uq_devices_user_installation",
        ),
        CheckConstraint(
            "platform IN ('android', 'ios', 'windows', 'macos')",
            name="platform_valid",
        ),
    )

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True)
    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    installation_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    platform: Mapped[str] = mapped_column(String(16), nullable=False)
    app_version: Mapped[str] = mapped_column(String(32), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    last_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class SessionRow(Base):
    __tablename__ = "sessions"
    __table_args__ = (
        UniqueConstraint(
            "refresh_token_hash",
            name="uq_sessions_refresh_token_hash",
        ),
        Index("ix_sessions_user_active", "user_id", "revoked_at"),
        Index("ix_sessions_family", "token_family_id"),
    )

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True)
    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    device_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("devices.id", ondelete="CASCADE"), nullable=False
    )
    token_family_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    refresh_token_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    revoked_reason: Mapped[str | None] = mapped_column(String(32))
    replaced_by_session_id: Mapped[UUID | None] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("sessions.id", ondelete="SET NULL")
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    last_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class HealthProfileRow(Base):
    __tablename__ = "health_profiles"
    __table_args__ = (
        CheckConstraint("height_cm IS NULL OR height_cm > 0", name="height_positive"),
        CheckConstraint(
            "current_weight_kg IS NULL OR current_weight_kg > 0",
            name="current_weight_positive",
        ),
        CheckConstraint(
            "target_weight_kg IS NULL OR target_weight_kg > 0",
            name="target_weight_positive",
        ),
        CheckConstraint(
            "goal_type IS NULL OR goal_type IN "
            "('loseFat', 'gainMuscle', 'maintain', 'healthyEating')",
            name="goal_type_valid",
        ),
        CheckConstraint(
            "daily_energy_target_kcal IS NULL OR daily_energy_target_kcal > 0",
            name="energy_target_positive",
        ),
        CheckConstraint("version >= 1", name="version_positive"),
    )

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
    )
    birth_date: Mapped[date | None] = mapped_column(Date)
    height_cm: Mapped[Decimal | None] = mapped_column(Numeric(5, 2))
    current_weight_kg: Mapped[Decimal | None] = mapped_column(Numeric(6, 2))
    target_weight_kg: Mapped[Decimal | None] = mapped_column(Numeric(6, 2))
    goal_type: Mapped[str | None] = mapped_column(String(32))
    daily_energy_target_kcal: Mapped[int | None] = mapped_column(Integer)
    version: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class MealLogRow(Base):
    __tablename__ = "meal_logs"
    __table_args__ = (
        CheckConstraint(
            "meal_type IN ('breakfast', 'lunch', 'dinner', 'snack')",
            name="meal_type_valid",
        ),
        CheckConstraint(
            "source IN ('manual', 'recognition', 'recipe')",
            name="source_valid",
        ),
        CheckConstraint("version >= 1", name="version_positive"),
        CheckConstraint("change_cursor >= 1", name="change_cursor_positive"),
        CheckConstraint("length(time_zone_id) > 0", name="time_zone_present"),
        ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        PrimaryKeyConstraint("user_id", "id"),
        Index("ix_meal_logs_user_local_day", "user_id", "local_day", "deleted_at"),
        Index("ix_meal_logs_user_change", "user_id", "change_cursor"),
    )

    user_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    meal_type: Mapped[str] = mapped_column(String(16), nullable=False)
    source: Mapped[str] = mapped_column(String(16), nullable=False)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    time_zone_id: Mapped[str] = mapped_column(String(64), nullable=False)
    local_day: Mapped[date] = mapped_column(Date, nullable=False)
    is_within_eating_window: Mapped[bool] = mapped_column(Boolean, nullable=False)
    version: Mapped[int] = mapped_column(Integer, nullable=False)
    change_cursor: Mapped[int] = mapped_column(BigInteger, nullable=False)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class MealItemRow(Base):
    __tablename__ = "meal_items"
    __table_args__ = (
        CheckConstraint("serving_milli > 0", name="serving_positive"),
        CheckConstraint("serving_milli <= 10000000", name="serving_bounded"),
        CheckConstraint("energy_kcal BETWEEN 0 AND 100000", name="energy_bounded"),
        CheckConstraint("protein_mg BETWEEN 0 AND 10000000", name="protein_bounded"),
        CheckConstraint("carbs_mg BETWEEN 0 AND 10000000", name="carbs_bounded"),
        CheckConstraint("fat_mg BETWEEN 0 AND 10000000", name="fat_bounded"),
        CheckConstraint("length(trim(name)) > 0", name="name_present"),
        CheckConstraint("position >= 0", name="position_non_negative"),
        ForeignKeyConstraint(
            ["user_id", "meal_log_id"],
            ["meal_logs.user_id", "meal_logs.id"],
            ondelete="CASCADE",
        ),
        PrimaryKeyConstraint("user_id", "id"),
        UniqueConstraint(
            "user_id",
            "meal_log_id",
            "position",
            name="uq_meal_items_parent_position",
        ),
        Index("ix_meal_items_parent", "user_id", "meal_log_id"),
    )

    user_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    meal_log_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    position: Mapped[int] = mapped_column(Integer, nullable=False)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    serving_milli: Mapped[int] = mapped_column(Integer, nullable=False)
    energy_kcal: Mapped[int] = mapped_column(Integer, nullable=False)
    protein_mg: Mapped[int] = mapped_column(Integer, nullable=False)
    carbs_mg: Mapped[int] = mapped_column(Integer, nullable=False)
    fat_mg: Mapped[int] = mapped_column(Integer, nullable=False)
    image_reference: Mapped[str | None] = mapped_column(String(512))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class FastingSessionRow(Base):
    __tablename__ = "fasting_sessions"
    __table_args__ = (
        CheckConstraint("plan IN ('gentle', 'balanced', 'advanced')", name="plan_valid"),
        CheckConstraint(
            "status IN ('active', 'completed', 'cancelled')",
            name="status_valid",
        ),
        CheckConstraint("target_end_at > started_at", name="target_after_start"),
        CheckConstraint(
            "(status = 'active' AND ended_at IS NULL AND ended_local_day IS NULL) OR "
            "(status = 'completed' AND ended_at = target_end_at "
            "AND ended_local_day IS NOT NULL) OR "
            "(status = 'cancelled' AND ended_at >= started_at "
            "AND ended_local_day IS NOT NULL)",
            name="end_matches_status",
        ),
        CheckConstraint("version >= 1", name="version_positive"),
        CheckConstraint("change_cursor >= 1", name="change_cursor_positive"),
        CheckConstraint("length(time_zone_id) > 0", name="time_zone_present"),
        ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        PrimaryKeyConstraint("user_id", "id"),
        Index("ix_fasting_sessions_user_started", "user_id", "started_at"),
        Index("ix_fasting_sessions_user_change", "user_id", "change_cursor"),
        Index(
            "uq_fasting_sessions_user_active",
            "user_id",
            unique=True,
            postgresql_where=text("status = 'active' AND deleted_at IS NULL"),
        ),
    )

    user_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    plan: Mapped[str] = mapped_column(String(16), nullable=False)
    status: Mapped[str] = mapped_column(String(16), nullable=False)
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    target_end_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    ended_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    time_zone_id: Mapped[str] = mapped_column(String(64), nullable=False)
    started_local_day: Mapped[date] = mapped_column(Date, nullable=False)
    target_end_local_day: Mapped[date] = mapped_column(Date, nullable=False)
    ended_local_day: Mapped[date | None] = mapped_column(Date)
    version: Mapped[int] = mapped_column(Integer, nullable=False)
    change_cursor: Mapped[int] = mapped_column(BigInteger, nullable=False)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class UserPreferencesRow(Base):
    __tablename__ = "user_preferences"
    __table_args__ = (
        CheckConstraint(
            "daily_energy_target_kcal > 0 AND daily_energy_target_kcal <= 20000",
            name="energy_target_valid",
        ),
        CheckConstraint(
            "selected_fasting_plan IN ('gentle', 'balanced', 'advanced')",
            name="fasting_plan_valid",
        ),
        CheckConstraint("version >= 1", name="version_positive"),
        CheckConstraint("change_cursor >= 1", name="change_cursor_positive"),
    )

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
    )
    daily_energy_target_kcal: Mapped[int] = mapped_column(Integer, nullable=False)
    selected_fasting_plan: Mapped[str] = mapped_column(String(16), nullable=False)
    fasting_reminder_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False)
    version: Mapped[int] = mapped_column(Integer, nullable=False)
    change_cursor: Mapped[int] = mapped_column(BigInteger, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class SyncOperationRow(Base):
    __tablename__ = "sync_operations"
    __table_args__ = (
        CheckConstraint(
            "entity_type IN ('mealLog', 'fastingSession', 'appPreferences')",
            name="entity_type_valid",
        ),
        CheckConstraint(
            "entity_type <> 'appPreferences' OR (entity_id = 'current' AND action = 'upsert')",
            name="preferences_shape",
        ),
        CheckConstraint("action IN ('upsert', 'delete')", name="action_valid"),
        CheckConstraint(
            "result_status IN ('applied', 'versionConflict', 'notFound', 'activeFastingConflict')",
            name="result_status_valid",
        ),
        CheckConstraint("payload_version = 1", name="payload_version_supported"),
        CheckConstraint(
            "current_version IS NULL OR current_version >= 1",
            name="current_version_positive",
        ),
        CheckConstraint(
            "change_cursor IS NULL OR change_cursor >= 1",
            name="change_cursor_positive",
        ),
        CheckConstraint("length(request_hash) = 64", name="request_hash_length"),
        ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        PrimaryKeyConstraint("user_id", "operation_id"),
        Index("ix_sync_operations_created", "created_at"),
    )

    user_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    operation_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    entity_type: Mapped[str] = mapped_column(String(32), nullable=False)
    entity_id: Mapped[str] = mapped_column(String(36), nullable=False)
    action: Mapped[str] = mapped_column(String(16), nullable=False)
    payload_version: Mapped[int] = mapped_column(Integer, nullable=False)
    request_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    result_status: Mapped[str] = mapped_column(String(32), nullable=False)
    current_version: Mapped[int | None] = mapped_column(Integer)
    change_cursor: Mapped[int | None] = mapped_column(BigInteger)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
