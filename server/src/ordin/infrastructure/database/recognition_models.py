from datetime import datetime
from typing import Any
from uuid import UUID

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKeyConstraint,
    Index,
    Integer,
    PrimaryKeyConstraint,
    String,
    UniqueConstraint,
    Uuid,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from ordin.infrastructure.database.base import Base


class RecognitionUploadRow(Base):
    __tablename__ = "recognition_uploads"
    __table_args__ = (
        CheckConstraint(
            "status IN ('initiated', 'processing', 'ready', 'consumed', 'invalid', 'expired')",
            name="status_valid",
        ),
        CheckConstraint(
            "expected_content_type IN ('image/jpeg', 'image/png', 'image/webp')",
            name="expected_content_type_valid",
        ),
        CheckConstraint("expected_size_bytes > 0", name="expected_size_positive"),
        CheckConstraint("length(expected_checksum_sha256) = 64", name="expected_checksum_length"),
        CheckConstraint(
            "sanitized_size_bytes IS NULL OR sanitized_size_bytes > 0",
            name="sanitized_size_positive",
        ),
        CheckConstraint(
            "sanitized_checksum_sha256 IS NULL OR length(sanitized_checksum_sha256) = 64",
            name="sanitized_checksum_length",
        ),
        CheckConstraint("width IS NULL OR width > 0", name="width_positive"),
        CheckConstraint("height IS NULL OR height > 0", name="height_positive"),
        ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        PrimaryKeyConstraint("user_id", "id"),
        UniqueConstraint("id", name="uq_recognition_uploads_id"),
        UniqueConstraint("incoming_object_key", name="uq_recognition_uploads_incoming_key"),
        UniqueConstraint("sanitized_object_key", name="uq_recognition_uploads_sanitized_key"),
        Index(
            "ix_recognition_uploads_incoming_cleanup",
            "expires_at",
            "status",
            "incoming_deleted_at",
        ),
        Index("ix_recognition_uploads_retention", "retention_until", "status"),
    )

    user_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    incoming_object_key: Mapped[str] = mapped_column(String(160), nullable=False)
    expected_content_type: Mapped[str] = mapped_column(String(32), nullable=False)
    expected_size_bytes: Mapped[int] = mapped_column(Integer, nullable=False)
    expected_checksum_sha256: Mapped[str] = mapped_column(String(64), nullable=False)
    status: Mapped[str] = mapped_column(String(16), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    claimed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    incoming_deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    sanitized_object_key: Mapped[str | None] = mapped_column(String(160))
    sanitized_content_type: Mapped[str | None] = mapped_column(String(32))
    sanitized_size_bytes: Mapped[int | None] = mapped_column(Integer)
    sanitized_checksum_sha256: Mapped[str | None] = mapped_column(String(64))
    width: Mapped[int | None] = mapped_column(Integer)
    height: Mapped[int | None] = mapped_column(Integer)
    retention_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    consumed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class RecognitionJobRow(Base):
    __tablename__ = "recognition_jobs"
    __table_args__ = (
        CheckConstraint(
            "status IN ('queued', 'running', 'succeeded', 'needs_review', 'failed', 'expired')",
            name="status_valid",
        ),
        CheckConstraint("version >= 1", name="version_positive"),
        CheckConstraint("attempt_count >= 0", name="attempt_count_non_negative"),
        CheckConstraint(
            "overall_confidence_milli IS NULL OR overall_confidence_milli BETWEEN 0 AND 1000",
            name="overall_confidence_bounded",
        ),
        CheckConstraint("length(idempotency_key_hash) = 64", name="idempotency_hash_length"),
        CheckConstraint("length(request_hash) = 64", name="request_hash_length"),
        ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        ForeignKeyConstraint(
            ["user_id", "upload_id"],
            ["recognition_uploads.user_id", "recognition_uploads.id"],
            ondelete="CASCADE",
        ),
        PrimaryKeyConstraint("user_id", "id"),
        UniqueConstraint("id", name="uq_recognition_jobs_id"),
        UniqueConstraint("user_id", "idempotency_key_hash", name="uq_recognition_jobs_idempotency"),
        Index("ix_recognition_jobs_user_created", "user_id", "created_at"),
        Index("ix_recognition_jobs_status_claimed", "status", "claimed_at"),
    )

    user_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    upload_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    idempotency_key_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    request_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    status: Mapped[str] = mapped_column(String(24), nullable=False)
    provider_name: Mapped[str | None] = mapped_column(String(64))
    overall_confidence_milli: Mapped[int | None] = mapped_column(Integer)
    needs_review_reason: Mapped[str | None] = mapped_column(String(64))
    error_code: Mapped[str | None] = mapped_column(String(64))
    version: Mapped[int] = mapped_column(Integer, nullable=False)
    attempt_count: Mapped[int] = mapped_column(Integer, nullable=False)
    claimed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    source_retention_until: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class RecognitionItemRow(Base):
    __tablename__ = "recognition_items"
    __table_args__ = (
        CheckConstraint("position >= 0", name="position_non_negative"),
        CheckConstraint("length(trim(name)) > 0", name="name_present"),
        CheckConstraint("serving_milli > 0 AND serving_milli <= 10000000", name="serving_bounded"),
        CheckConstraint("energy_kcal BETWEEN 0 AND 100000", name="energy_bounded"),
        CheckConstraint("protein_mg BETWEEN 0 AND 10000000", name="protein_bounded"),
        CheckConstraint("carbs_mg BETWEEN 0 AND 10000000", name="carbs_bounded"),
        CheckConstraint("fat_mg BETWEEN 0 AND 10000000", name="fat_bounded"),
        CheckConstraint("confidence_milli BETWEEN 0 AND 1000", name="confidence_bounded"),
        ForeignKeyConstraint(
            ["user_id", "job_id"],
            ["recognition_jobs.user_id", "recognition_jobs.id"],
            ondelete="CASCADE",
        ),
        PrimaryKeyConstraint("user_id", "id"),
        UniqueConstraint("user_id", "job_id", "position", name="uq_recognition_items_position"),
        Index("ix_recognition_items_job", "user_id", "job_id"),
    )

    user_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    job_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    position: Mapped[int] = mapped_column(Integer, nullable=False)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    canonical_food_id: Mapped[str | None] = mapped_column(String(120))
    serving_milli: Mapped[int] = mapped_column(Integer, nullable=False)
    energy_kcal: Mapped[int] = mapped_column(Integer, nullable=False)
    protein_mg: Mapped[int] = mapped_column(Integer, nullable=False)
    carbs_mg: Mapped[int] = mapped_column(Integer, nullable=False)
    fat_mg: Mapped[int] = mapped_column(Integer, nullable=False)
    confidence_milli: Mapped[int] = mapped_column(Integer, nullable=False)
    alternatives: Mapped[list[dict[str, Any]]] = mapped_column(JSONB, nullable=False)
    is_user_corrected: Mapped[bool] = mapped_column(Boolean, nullable=False)


class RecognitionCorrectionRow(Base):
    __tablename__ = "recognition_corrections"
    __table_args__ = (
        CheckConstraint("base_version >= 1", name="base_version_positive"),
        ForeignKeyConstraint(
            ["user_id", "job_id"],
            ["recognition_jobs.user_id", "recognition_jobs.id"],
            ondelete="CASCADE",
        ),
        PrimaryKeyConstraint("user_id", "id"),
        Index("ix_recognition_corrections_job", "user_id", "job_id", "created_at"),
    )

    user_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    job_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    base_version: Mapped[int] = mapped_column(Integer, nullable=False)
    corrected_items: Mapped[list[dict[str, Any]]] = mapped_column(JSONB, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
