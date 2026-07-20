"""Add durable cleanup queue for deleted account objects.

Revision ID: 20260721_0005
Revises: 20260720_0004
Create Date: 2026-07-21
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20260721_0005"
down_revision: str | None = "20260720_0004"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "account_object_cleanups",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("batch_id", sa.Uuid(), nullable=False),
        sa.Column("object_key", sa.String(length=160), nullable=False),
        sa.Column("attempt_count", sa.Integer(), nullable=False),
        sa.Column("queued_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("next_attempt_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("claimed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint(
            "attempt_count >= 0",
            name=op.f("ck_account_object_cleanups_attempt_count_non_negative"),
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_account_object_cleanups")),
        sa.UniqueConstraint(
            "object_key",
            name=op.f("uq_account_object_cleanups_object_key"),
        ),
    )
    op.create_index(
        "ix_account_object_cleanups_batch",
        "account_object_cleanups",
        ["batch_id", "queued_at"],
        unique=False,
    )
    op.create_index(
        "ix_account_object_cleanups_due",
        "account_object_cleanups",
        ["completed_at", "next_attempt_at", "claimed_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_account_object_cleanups_due", table_name="account_object_cleanups")
    op.drop_index("ix_account_object_cleanups_batch", table_name="account_object_cleanups")
    op.drop_table("account_object_cleanups")
