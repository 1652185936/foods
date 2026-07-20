"""Create identity, session, and health-profile tables.

Revision ID: 20260720_0001
Revises:
Create Date: 2026-07-20
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20260720_0001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("nickname", sa.String(length=40), nullable=True),
        sa.Column("status", sa.String(length=32), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "status IN ('active', 'deletion_pending', 'deleted')",
            name="ck_users_status_valid",
        ),
        sa.CheckConstraint("version >= 1", name="ck_users_version_positive"),
        sa.PrimaryKeyConstraint("id", name="pk_users"),
    )
    op.create_table(
        "auth_identities",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("provider", sa.String(length=32), nullable=False),
        sa.Column("subject_hash", sa.String(length=64), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint("provider IN ('phone')", name="ck_auth_identities_provider_valid"),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_auth_identities_user_id_users",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_auth_identities"),
        sa.UniqueConstraint(
            "provider",
            "subject_hash",
            name="uq_auth_identities_provider_subject",
        ),
    )
    op.create_table(
        "devices",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("installation_id", sa.Uuid(), nullable=False),
        sa.Column("platform", sa.String(length=16), nullable=False),
        sa.Column("app_version", sa.String(length=32), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("last_seen_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint(
            "platform IN ('android', 'ios', 'windows', 'macos')",
            name="ck_devices_platform_valid",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_devices_user_id_users",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_devices"),
        sa.UniqueConstraint(
            "user_id",
            "installation_id",
            name="uq_devices_user_installation",
        ),
    )
    op.create_table(
        "health_profiles",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("birth_date", sa.Date(), nullable=True),
        sa.Column("height_cm", sa.Numeric(precision=5, scale=2), nullable=True),
        sa.Column("current_weight_kg", sa.Numeric(precision=6, scale=2), nullable=True),
        sa.Column("target_weight_kg", sa.Numeric(precision=6, scale=2), nullable=True),
        sa.Column("goal_type", sa.String(length=32), nullable=True),
        sa.Column("daily_energy_target_kcal", sa.Integer(), nullable=True),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "current_weight_kg IS NULL OR current_weight_kg > 0",
            name="ck_health_profiles_current_weight_positive",
        ),
        sa.CheckConstraint(
            "daily_energy_target_kcal IS NULL OR daily_energy_target_kcal > 0",
            name="ck_health_profiles_energy_target_positive",
        ),
        sa.CheckConstraint(
            "goal_type IS NULL OR goal_type IN "
            "('loseFat', 'gainMuscle', 'maintain', 'healthyEating')",
            name="ck_health_profiles_goal_type_valid",
        ),
        sa.CheckConstraint(
            "height_cm IS NULL OR height_cm > 0",
            name="ck_health_profiles_height_positive",
        ),
        sa.CheckConstraint(
            "target_weight_kg IS NULL OR target_weight_kg > 0",
            name="ck_health_profiles_target_weight_positive",
        ),
        sa.CheckConstraint("version >= 1", name="ck_health_profiles_version_positive"),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_health_profiles_user_id_users",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("user_id", name="pk_health_profiles"),
    )
    op.create_table(
        "sessions",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("device_id", sa.Uuid(), nullable=False),
        sa.Column("token_family_id", sa.Uuid(), nullable=False),
        sa.Column("refresh_token_hash", sa.String(length=64), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("revoked_reason", sa.String(length=32), nullable=True),
        sa.Column("replaced_by_session_id", sa.Uuid(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("last_seen_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["device_id"],
            ["devices.id"],
            name="fk_sessions_device_id_devices",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["replaced_by_session_id"],
            ["sessions.id"],
            name="fk_sessions_replaced_by_session_id_sessions",
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_sessions_user_id_users",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_sessions"),
        sa.UniqueConstraint(
            "refresh_token_hash",
            name="uq_sessions_refresh_token_hash",
        ),
    )
    op.create_index("ix_sessions_family", "sessions", ["token_family_id"], unique=False)
    op.create_index(
        "ix_sessions_user_active",
        "sessions",
        ["user_id", "revoked_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_sessions_user_active", table_name="sessions")
    op.drop_index("ix_sessions_family", table_name="sessions")
    op.drop_table("sessions")
    op.drop_table("health_profiles")
    op.drop_table("devices")
    op.drop_table("auth_identities")
    op.drop_table("users")
