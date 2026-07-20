"""Create meal, fasting, preference, and synchronization tables.

Revision ID: 20260720_0002
Revises: 20260720_0001
Create Date: 2026-07-20
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20260720_0002"
down_revision: str | None = "20260720_0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute("CREATE SEQUENCE ordin_sync_revision_seq START WITH 1")
    op.create_table(
        "meal_logs",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("meal_type", sa.String(length=16), nullable=False),
        sa.Column("source", sa.String(length=16), nullable=False),
        sa.Column("occurred_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("time_zone_id", sa.String(length=64), nullable=False),
        sa.Column("local_day", sa.Date(), nullable=False),
        sa.Column("is_within_eating_window", sa.Boolean(), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("change_cursor", sa.BigInteger(), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint(
            "change_cursor >= 1",
            name="ck_meal_logs_change_cursor_positive",
        ),
        sa.CheckConstraint(
            "meal_type IN ('breakfast', 'lunch', 'dinner', 'snack')",
            name="ck_meal_logs_meal_type_valid",
        ),
        sa.CheckConstraint(
            "source IN ('manual', 'recognition', 'recipe')",
            name="ck_meal_logs_source_valid",
        ),
        sa.CheckConstraint(
            "length(time_zone_id) > 0",
            name="ck_meal_logs_time_zone_present",
        ),
        sa.CheckConstraint("version >= 1", name="ck_meal_logs_version_positive"),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_meal_logs_user_id_users",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("user_id", "id", name="pk_meal_logs"),
    )
    op.create_index(
        "ix_meal_logs_user_change",
        "meal_logs",
        ["user_id", "change_cursor"],
        unique=False,
    )
    op.create_index(
        "ix_meal_logs_user_local_day",
        "meal_logs",
        ["user_id", "local_day", "deleted_at"],
        unique=False,
    )
    op.create_table(
        "meal_items",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("meal_log_id", sa.Uuid(), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("serving_milli", sa.Integer(), nullable=False),
        sa.Column("energy_kcal", sa.Integer(), nullable=False),
        sa.Column("protein_mg", sa.Integer(), nullable=False),
        sa.Column("carbs_mg", sa.Integer(), nullable=False),
        sa.Column("fat_mg", sa.Integer(), nullable=False),
        sa.Column("image_reference", sa.String(length=512), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint(
            "carbs_mg BETWEEN 0 AND 10000000",
            name="ck_meal_items_carbs_bounded",
        ),
        sa.CheckConstraint(
            "energy_kcal BETWEEN 0 AND 100000",
            name="ck_meal_items_energy_bounded",
        ),
        sa.CheckConstraint(
            "fat_mg BETWEEN 0 AND 10000000",
            name="ck_meal_items_fat_bounded",
        ),
        sa.CheckConstraint(
            "length(trim(name)) > 0",
            name="ck_meal_items_name_present",
        ),
        sa.CheckConstraint("position >= 0", name="ck_meal_items_position_non_negative"),
        sa.CheckConstraint(
            "protein_mg BETWEEN 0 AND 10000000",
            name="ck_meal_items_protein_bounded",
        ),
        sa.CheckConstraint(
            "serving_milli <= 10000000",
            name="ck_meal_items_serving_bounded",
        ),
        sa.CheckConstraint("serving_milli > 0", name="ck_meal_items_serving_positive"),
        sa.ForeignKeyConstraint(
            ["user_id", "meal_log_id"],
            ["meal_logs.user_id", "meal_logs.id"],
            name="fk_meal_items_user_id_meal_logs",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("user_id", "id", name="pk_meal_items"),
        sa.UniqueConstraint(
            "user_id",
            "meal_log_id",
            "position",
            name="uq_meal_items_parent_position",
        ),
    )
    op.create_index(
        "ix_meal_items_parent",
        "meal_items",
        ["user_id", "meal_log_id"],
        unique=False,
    )
    op.create_table(
        "fasting_sessions",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("plan", sa.String(length=16), nullable=False),
        sa.Column("status", sa.String(length=16), nullable=False),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("target_end_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("ended_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("time_zone_id", sa.String(length=64), nullable=False),
        sa.Column("started_local_day", sa.Date(), nullable=False),
        sa.Column("target_end_local_day", sa.Date(), nullable=False),
        sa.Column("ended_local_day", sa.Date(), nullable=True),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("change_cursor", sa.BigInteger(), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint(
            "change_cursor >= 1",
            name="ck_fasting_sessions_change_cursor_positive",
        ),
        sa.CheckConstraint(
            "(status = 'active' AND ended_at IS NULL AND ended_local_day IS NULL) OR "
            "(status = 'completed' AND ended_at = target_end_at "
            "AND ended_local_day IS NOT NULL) OR "
            "(status = 'cancelled' AND ended_at >= started_at "
            "AND ended_local_day IS NOT NULL)",
            name="ck_fasting_sessions_end_matches_status",
        ),
        sa.CheckConstraint(
            "plan IN ('gentle', 'balanced', 'advanced')",
            name="ck_fasting_sessions_plan_valid",
        ),
        sa.CheckConstraint(
            "status IN ('active', 'completed', 'cancelled')",
            name="ck_fasting_sessions_status_valid",
        ),
        sa.CheckConstraint(
            "target_end_at > started_at",
            name="ck_fasting_sessions_target_after_start",
        ),
        sa.CheckConstraint(
            "length(time_zone_id) > 0",
            name="ck_fasting_sessions_time_zone_present",
        ),
        sa.CheckConstraint(
            "version >= 1",
            name="ck_fasting_sessions_version_positive",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_fasting_sessions_user_id_users",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("user_id", "id", name="pk_fasting_sessions"),
    )
    op.create_index(
        "ix_fasting_sessions_user_change",
        "fasting_sessions",
        ["user_id", "change_cursor"],
        unique=False,
    )
    op.create_index(
        "ix_fasting_sessions_user_started",
        "fasting_sessions",
        ["user_id", "started_at"],
        unique=False,
    )
    op.create_index(
        "uq_fasting_sessions_user_active",
        "fasting_sessions",
        ["user_id"],
        unique=True,
        postgresql_where=sa.text("status = 'active' AND deleted_at IS NULL"),
    )
    op.create_table(
        "user_preferences",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("daily_energy_target_kcal", sa.Integer(), nullable=False),
        sa.Column("selected_fasting_plan", sa.String(length=16), nullable=False),
        sa.Column("fasting_reminder_enabled", sa.Boolean(), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("change_cursor", sa.BigInteger(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint(
            "change_cursor >= 1",
            name="ck_user_preferences_change_cursor_positive",
        ),
        sa.CheckConstraint(
            "daily_energy_target_kcal > 0 AND daily_energy_target_kcal <= 20000",
            name="ck_user_preferences_energy_target_valid",
        ),
        sa.CheckConstraint(
            "selected_fasting_plan IN ('gentle', 'balanced', 'advanced')",
            name="ck_user_preferences_fasting_plan_valid",
        ),
        sa.CheckConstraint(
            "version >= 1",
            name="ck_user_preferences_version_positive",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_user_preferences_user_id_users",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("user_id", name="pk_user_preferences"),
    )
    op.create_table(
        "sync_operations",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("operation_id", sa.Uuid(), nullable=False),
        sa.Column("entity_type", sa.String(length=32), nullable=False),
        sa.Column("entity_id", sa.String(length=36), nullable=False),
        sa.Column("action", sa.String(length=16), nullable=False),
        sa.Column("payload_version", sa.Integer(), nullable=False),
        sa.Column("request_hash", sa.String(length=64), nullable=False),
        sa.Column("result_status", sa.String(length=32), nullable=False),
        sa.Column("current_version", sa.Integer(), nullable=True),
        sa.Column("change_cursor", sa.BigInteger(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint(
            "action IN ('upsert', 'delete')",
            name="ck_sync_operations_action_valid",
        ),
        sa.CheckConstraint(
            "change_cursor IS NULL OR change_cursor >= 1",
            name="ck_sync_operations_change_cursor_positive",
        ),
        sa.CheckConstraint(
            "current_version IS NULL OR current_version >= 1",
            name="ck_sync_operations_current_version_positive",
        ),
        sa.CheckConstraint(
            "entity_type IN ('mealLog', 'fastingSession', 'appPreferences')",
            name="ck_sync_operations_entity_type_valid",
        ),
        sa.CheckConstraint(
            "entity_type <> 'appPreferences' OR (entity_id = 'current' AND action = 'upsert')",
            name="ck_sync_operations_preferences_shape",
        ),
        sa.CheckConstraint(
            "payload_version = 1",
            name="ck_sync_operations_payload_version_supported",
        ),
        sa.CheckConstraint(
            "length(request_hash) = 64",
            name="ck_sync_operations_request_hash_length",
        ),
        sa.CheckConstraint(
            "result_status IN ('applied', 'versionConflict', 'notFound', 'activeFastingConflict')",
            name="ck_sync_operations_result_status_valid",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_sync_operations_user_id_users",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "user_id",
            "operation_id",
            name="pk_sync_operations",
        ),
    )
    op.create_index(
        "ix_sync_operations_created",
        "sync_operations",
        ["created_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_sync_operations_created", table_name="sync_operations")
    op.drop_table("sync_operations")
    op.drop_table("user_preferences")
    op.drop_index("uq_fasting_sessions_user_active", table_name="fasting_sessions")
    op.drop_index("ix_fasting_sessions_user_started", table_name="fasting_sessions")
    op.drop_index("ix_fasting_sessions_user_change", table_name="fasting_sessions")
    op.drop_table("fasting_sessions")
    op.drop_index("ix_meal_items_parent", table_name="meal_items")
    op.drop_table("meal_items")
    op.drop_index("ix_meal_logs_user_local_day", table_name="meal_logs")
    op.drop_index("ix_meal_logs_user_change", table_name="meal_logs")
    op.drop_table("meal_logs")
    op.execute("DROP SEQUENCE ordin_sync_revision_seq")
