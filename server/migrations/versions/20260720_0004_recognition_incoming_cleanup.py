"""Track cleanup of abandoned recognition uploads.

Revision ID: 20260720_0004
Revises: 20260720_0003
Create Date: 2026-07-20
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20260720_0004"
down_revision: str | None = "20260720_0003"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "recognition_uploads",
        sa.Column("incoming_deleted_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index(
        "ix_recognition_uploads_incoming_cleanup",
        "recognition_uploads",
        ["expires_at", "status", "incoming_deleted_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_recognition_uploads_incoming_cleanup",
        table_name="recognition_uploads",
    )
    op.drop_column("recognition_uploads", "incoming_deleted_at")
