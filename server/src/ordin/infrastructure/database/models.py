from datetime import date, datetime
from decimal import Decimal
from uuid import UUID

from sqlalchemy import (
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    UniqueConstraint,
    Uuid,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from ordin.infrastructure.database.base import Base


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
