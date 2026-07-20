from datetime import datetime
from uuid import UUID

from sqlalchemy import CheckConstraint, DateTime, Index, Integer, String, UniqueConstraint, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from ordin.infrastructure.database.base import Base


class AccountObjectCleanupRow(Base):
    __tablename__ = "account_object_cleanups"
    __table_args__ = (
        UniqueConstraint("object_key", name="uq_account_object_cleanups_object_key"),
        CheckConstraint("attempt_count >= 0", name="attempt_count_non_negative"),
        Index(
            "ix_account_object_cleanups_due",
            "completed_at",
            "next_attempt_at",
            "claimed_at",
        ),
        Index("ix_account_object_cleanups_batch", "batch_id", "queued_at"),
    )

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True)
    batch_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), nullable=False)
    object_key: Mapped[str] = mapped_column(String(160), nullable=False)
    attempt_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    queued_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    next_attempt_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    claimed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
