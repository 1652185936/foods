"""Create secure image upload and recognition task tables.

Revision ID: 20260720_0003
Revises: 20260720_0002
Create Date: 2026-07-20
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "20260720_0003"
down_revision: str | None = "20260720_0002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "recognition_uploads",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("incoming_object_key", sa.String(length=160), nullable=False),
        sa.Column("expected_content_type", sa.String(length=32), nullable=False),
        sa.Column("expected_size_bytes", sa.Integer(), nullable=False),
        sa.Column("expected_checksum_sha256", sa.String(length=64), nullable=False),
        sa.Column("status", sa.String(length=16), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("claimed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("sanitized_object_key", sa.String(length=160), nullable=True),
        sa.Column("sanitized_content_type", sa.String(length=32), nullable=True),
        sa.Column("sanitized_size_bytes", sa.Integer(), nullable=True),
        sa.Column("sanitized_checksum_sha256", sa.String(length=64), nullable=True),
        sa.Column("width", sa.Integer(), nullable=True),
        sa.Column("height", sa.Integer(), nullable=True),
        sa.Column("retention_until", sa.DateTime(timezone=True), nullable=True),
        sa.Column("consumed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint(
            "expected_content_type IN ('image/jpeg', 'image/png', 'image/webp')",
            name="ck_recognition_uploads_expected_content_type_valid",
        ),
        sa.CheckConstraint(
            "length(expected_checksum_sha256) = 64",
            name="ck_recognition_uploads_expected_checksum_length",
        ),
        sa.CheckConstraint(
            "expected_size_bytes > 0",
            name="ck_recognition_uploads_expected_size_positive",
        ),
        sa.CheckConstraint(
            "height IS NULL OR height > 0",
            name="ck_recognition_uploads_height_positive",
        ),
        sa.CheckConstraint(
            "sanitized_checksum_sha256 IS NULL OR length(sanitized_checksum_sha256) = 64",
            name="ck_recognition_uploads_sanitized_checksum_length",
        ),
        sa.CheckConstraint(
            "sanitized_size_bytes IS NULL OR sanitized_size_bytes > 0",
            name="ck_recognition_uploads_sanitized_size_positive",
        ),
        sa.CheckConstraint(
            "status IN ('initiated', 'processing', 'ready', 'consumed', 'invalid', 'expired')",
            name="ck_recognition_uploads_status_valid",
        ),
        sa.CheckConstraint(
            "width IS NULL OR width > 0",
            name="ck_recognition_uploads_width_positive",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_recognition_uploads_user_id_users",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("user_id", "id", name="pk_recognition_uploads"),
        sa.UniqueConstraint("id", name="uq_recognition_uploads_id"),
        sa.UniqueConstraint(
            "incoming_object_key",
            name="uq_recognition_uploads_incoming_key",
        ),
        sa.UniqueConstraint(
            "sanitized_object_key",
            name="uq_recognition_uploads_sanitized_key",
        ),
    )
    op.create_index(
        "ix_recognition_uploads_retention",
        "recognition_uploads",
        ["retention_until", "status"],
        unique=False,
    )
    op.create_table(
        "recognition_jobs",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("upload_id", sa.Uuid(), nullable=False),
        sa.Column("idempotency_key_hash", sa.String(length=64), nullable=False),
        sa.Column("request_hash", sa.String(length=64), nullable=False),
        sa.Column("status", sa.String(length=24), nullable=False),
        sa.Column("provider_name", sa.String(length=64), nullable=True),
        sa.Column("overall_confidence_milli", sa.Integer(), nullable=True),
        sa.Column("needs_review_reason", sa.String(length=64), nullable=True),
        sa.Column("error_code", sa.String(length=64), nullable=True),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("attempt_count", sa.Integer(), nullable=False),
        sa.Column("claimed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("source_retention_until", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint(
            "attempt_count >= 0",
            name="ck_recognition_jobs_attempt_count_non_negative",
        ),
        sa.CheckConstraint(
            "length(idempotency_key_hash) = 64",
            name="ck_recognition_jobs_idempotency_hash_length",
        ),
        sa.CheckConstraint(
            "overall_confidence_milli IS NULL OR overall_confidence_milli BETWEEN 0 AND 1000",
            name="ck_recognition_jobs_overall_confidence_bounded",
        ),
        sa.CheckConstraint(
            "length(request_hash) = 64",
            name="ck_recognition_jobs_request_hash_length",
        ),
        sa.CheckConstraint(
            "status IN ('queued', 'running', 'succeeded', 'needs_review', 'failed', 'expired')",
            name="ck_recognition_jobs_status_valid",
        ),
        sa.CheckConstraint("version >= 1", name="ck_recognition_jobs_version_positive"),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_recognition_jobs_user_id_users",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["user_id", "upload_id"],
            ["recognition_uploads.user_id", "recognition_uploads.id"],
            name="fk_recognition_jobs_user_id_recognition_uploads",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("user_id", "id", name="pk_recognition_jobs"),
        sa.UniqueConstraint("id", name="uq_recognition_jobs_id"),
        sa.UniqueConstraint(
            "user_id",
            "idempotency_key_hash",
            name="uq_recognition_jobs_idempotency",
        ),
    )
    op.create_index(
        "ix_recognition_jobs_status_claimed",
        "recognition_jobs",
        ["status", "claimed_at"],
        unique=False,
    )
    op.create_index(
        "ix_recognition_jobs_user_created",
        "recognition_jobs",
        ["user_id", "created_at"],
        unique=False,
    )
    op.create_table(
        "recognition_items",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("job_id", sa.Uuid(), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("canonical_food_id", sa.String(length=120), nullable=True),
        sa.Column("serving_milli", sa.Integer(), nullable=False),
        sa.Column("energy_kcal", sa.Integer(), nullable=False),
        sa.Column("protein_mg", sa.Integer(), nullable=False),
        sa.Column("carbs_mg", sa.Integer(), nullable=False),
        sa.Column("fat_mg", sa.Integer(), nullable=False),
        sa.Column("confidence_milli", sa.Integer(), nullable=False),
        sa.Column("alternatives", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("is_user_corrected", sa.Boolean(), nullable=False),
        sa.CheckConstraint(
            "carbs_mg BETWEEN 0 AND 10000000",
            name="ck_recognition_items_carbs_bounded",
        ),
        sa.CheckConstraint(
            "confidence_milli BETWEEN 0 AND 1000",
            name="ck_recognition_items_confidence_bounded",
        ),
        sa.CheckConstraint(
            "energy_kcal BETWEEN 0 AND 100000",
            name="ck_recognition_items_energy_bounded",
        ),
        sa.CheckConstraint(
            "fat_mg BETWEEN 0 AND 10000000",
            name="ck_recognition_items_fat_bounded",
        ),
        sa.CheckConstraint(
            "length(trim(name)) > 0",
            name="ck_recognition_items_name_present",
        ),
        sa.CheckConstraint(
            "position >= 0",
            name="ck_recognition_items_position_non_negative",
        ),
        sa.CheckConstraint(
            "protein_mg BETWEEN 0 AND 10000000",
            name="ck_recognition_items_protein_bounded",
        ),
        sa.CheckConstraint(
            "serving_milli > 0 AND serving_milli <= 10000000",
            name="ck_recognition_items_serving_bounded",
        ),
        sa.ForeignKeyConstraint(
            ["user_id", "job_id"],
            ["recognition_jobs.user_id", "recognition_jobs.id"],
            name="fk_recognition_items_user_id_recognition_jobs",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("user_id", "id", name="pk_recognition_items"),
        sa.UniqueConstraint(
            "user_id",
            "job_id",
            "position",
            name="uq_recognition_items_position",
        ),
    )
    op.create_index(
        "ix_recognition_items_job",
        "recognition_items",
        ["user_id", "job_id"],
        unique=False,
    )
    op.create_table(
        "recognition_corrections",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("job_id", sa.Uuid(), nullable=False),
        sa.Column("base_version", sa.Integer(), nullable=False),
        sa.Column("corrected_items", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint(
            "base_version >= 1",
            name="ck_recognition_corrections_base_version_positive",
        ),
        sa.ForeignKeyConstraint(
            ["user_id", "job_id"],
            ["recognition_jobs.user_id", "recognition_jobs.id"],
            name="fk_recognition_corrections_user_id_recognition_jobs",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("user_id", "id", name="pk_recognition_corrections"),
    )
    op.create_index(
        "ix_recognition_corrections_job",
        "recognition_corrections",
        ["user_id", "job_id", "created_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_recognition_corrections_job", table_name="recognition_corrections")
    op.drop_table("recognition_corrections")
    op.drop_index("ix_recognition_items_job", table_name="recognition_items")
    op.drop_table("recognition_items")
    op.drop_index("ix_recognition_jobs_user_created", table_name="recognition_jobs")
    op.drop_index("ix_recognition_jobs_status_claimed", table_name="recognition_jobs")
    op.drop_table("recognition_jobs")
    op.drop_index("ix_recognition_uploads_retention", table_name="recognition_uploads")
    op.drop_table("recognition_uploads")
