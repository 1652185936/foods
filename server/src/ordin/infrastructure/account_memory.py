import asyncio
from dataclasses import dataclass
from datetime import datetime
from uuid import UUID

from ordin.core.errors import AccountExportTooLargeError
from ordin.core.identifiers import new_uuid
from ordin.infrastructure.memory import InMemoryApplicationRepository
from ordin.infrastructure.recognition_memory import InMemoryRecognitionRepository
from ordin.infrastructure.records_memory import InMemoryRecordsRepository
from ordin.modules.accounts.models import (
    AccountDataSnapshot,
    AccountDeletion,
    AccountObjectCleanup,
    AccountRecognitionCorrection,
    AccountRecognitionCorrectionItem,
    AccountRecognitionResult,
)
from ordin.modules.users.models import UserStatus


@dataclass(slots=True)
class _MemoryCleanup:
    id: UUID
    object_key: str
    completed: bool = False


class InMemoryAccountRepository:
    def __init__(
        self,
        *,
        application: InMemoryApplicationRepository,
        records: InMemoryRecordsRepository,
        recognition: InMemoryRecognitionRepository,
    ) -> None:
        self._application = application
        self._records = records
        self._recognition = recognition
        self._cleanups: dict[UUID, _MemoryCleanup] = {}
        self._cleanup_by_key: dict[str, UUID] = {}
        self._cleanup_lock = asyncio.Lock()

    async def export_snapshot(
        self,
        *,
        user_id: UUID,
        exported_at: datetime,
        max_records: int,
    ) -> AccountDataSnapshot | None:
        async with (
            self._application._lock,
            self._records._lock,
            self._recognition._lock,
        ):
            user = self._application._users.get(user_id)
            if user is None or user.status is not UserStatus.ACTIVE:
                return None
            meals = tuple(
                meal
                for (owner_id, _), meal in self._records._meals.items()
                if owner_id == user_id and meal.deleted_at is None
            )
            fasting_sessions = tuple(
                fasting
                for (owner_id, _), fasting in self._records._fasting_sessions.items()
                if owner_id == user_id and fasting.deleted_at is None
            )
            jobs = tuple(
                job for (owner_id, _), job in self._recognition._jobs.items() if owner_id == user_id
            )
            corrections_by_job: dict[UUID, list[AccountRecognitionCorrection]] = {}
            for correction_id, job_id, base_version, items in self._recognition.corrections:
                job = self._recognition._jobs.get((user_id, job_id))
                if job is None:
                    continue
                corrections_by_job.setdefault(job_id, []).append(
                    AccountRecognitionCorrection(
                        id=correction_id,
                        base_version=base_version,
                        created_at=job.updated_at,
                        items=tuple(
                            AccountRecognitionCorrectionItem(
                                id=item.id,
                                position=position,
                                name=item.name,
                                canonical_food_id=item.canonical_food_id,
                                serving_milli=item.serving_milli,
                                energy_kcal=item.energy_kcal,
                                protein_mg=item.protein_mg,
                                carbs_mg=item.carbs_mg,
                                fat_mg=item.fat_mg,
                            )
                            for position, item in enumerate(items)
                        ),
                    )
                )
            preferences = self._records._preferences.get(user_id)
            health_profile = self._application._health_profiles.get(user_id)
            count = (
                1
                + int(health_profile is not None)
                + int(preferences is not None)
                + len(meals)
                + sum(len(meal.items) for meal in meals)
                + len(fasting_sessions)
                + len(jobs)
                + sum(len(job.items) for job in jobs)
                + sum(
                    1 + len(correction.items)
                    for corrections in corrections_by_job.values()
                    for correction in corrections
                )
            )
            if count > max_records:
                raise AccountExportTooLargeError
            return AccountDataSnapshot(
                exported_at=exported_at,
                user=user,
                health_profile=health_profile,
                preferences=preferences,
                meals=tuple(sorted(meals, key=lambda meal: (meal.occurred_at, meal.id.int))),
                fasting_sessions=tuple(
                    sorted(
                        fasting_sessions,
                        key=lambda fasting: (fasting.started_at, fasting.id.int),
                    )
                ),
                recognitions=tuple(
                    AccountRecognitionResult(
                        id=job.id,
                        status=job.status.value,
                        overall_confidence_milli=job.overall_confidence_milli,
                        needs_review_reason=job.needs_review_reason,
                        error_code=job.error_code,
                        version=job.version,
                        created_at=job.created_at,
                        updated_at=job.updated_at,
                        completed_at=job.completed_at,
                        items=job.items,
                        corrections=tuple(corrections_by_job.get(job.id, ())),
                    )
                    for job in sorted(jobs, key=lambda job: (job.created_at, job.id.int))
                ),
            )

    async def delete_account(
        self,
        *,
        user_id: UUID,
        session_id: UUID,
        refresh_token_hash: str,
        device_installation_id: UUID,
        cleanup_batch_id: UUID,
        now: datetime,
        immediate_cleanup_limit: int,
    ) -> AccountDeletion | None:
        del cleanup_batch_id
        async with (
            self._application._lock,
            self._records._lock,
            self._recognition._lock,
            self._cleanup_lock,
        ):
            user = self._application._users.get(user_id)
            current = self._application._sessions.get(session_id)
            if (
                user is None
                or user.status is not UserStatus.ACTIVE
                or current is None
                or current.user_id != user_id
                or current.refresh_token_hash != refresh_token_hash
                or current.device_installation_id != device_installation_id
                or current.revoked_at is not None
                or current.expires_at <= now
            ):
                return None

            queued: list[_MemoryCleanup] = []
            for (owner_id, _), upload in self._recognition._uploads.items():
                if owner_id != user_id:
                    continue
                for object_key in (
                    upload.incoming_object_key,
                    upload.sanitized_object_key,
                ):
                    if object_key is None or object_key in self._cleanup_by_key:
                        continue
                    cleanup = _MemoryCleanup(id=new_uuid(), object_key=object_key)
                    self._cleanups[cleanup.id] = cleanup
                    self._cleanup_by_key[object_key] = cleanup.id
                    queued.append(cleanup)

            self._application._users.pop(user_id, None)
            self._application._health_profiles.pop(user_id, None)
            for identity_hash, owner_id in tuple(self._application._identity_users.items()):
                if owner_id == user_id:
                    self._application._identity_users.pop(identity_hash, None)
            for owned_session_id, session in tuple(self._application._sessions.items()):
                if session.user_id == user_id:
                    self._application._sessions.pop(owned_session_id, None)
                    self._application._session_by_refresh_hash.pop(
                        session.refresh_token_hash,
                        None,
                    )
            self._records._meals = {
                key: value for key, value in self._records._meals.items() if key[0] != user_id
            }
            self._records._fasting_sessions = {
                key: value
                for key, value in self._records._fasting_sessions.items()
                if key[0] != user_id
            }
            self._records._preferences.pop(user_id, None)
            self._records._receipts = {
                key: value for key, value in self._records._receipts.items() if key[0] != user_id
            }
            self._recognition._uploads = {
                key: value for key, value in self._recognition._uploads.items() if key[0] != user_id
            }
            self._recognition._jobs = {
                key: value for key, value in self._recognition._jobs.items() if key[0] != user_id
            }
            self._recognition._idempotency = {
                key: value
                for key, value in self._recognition._idempotency.items()
                if key[0] != user_id
            }
            remaining_job_ids = {job_id for _, job_id in self._recognition._jobs}
            self._recognition.corrections = [
                correction
                for correction in self._recognition.corrections
                if correction[1] in remaining_job_ids
            ]
            return AccountDeletion(
                immediate_cleanups=tuple(
                    AccountObjectCleanup(id=item.id, object_key=item.object_key)
                    for item in queued[:immediate_cleanup_limit]
                )
            )

    async def mark_cleanup_succeeded(self, *, cleanup_id: UUID, now: datetime) -> None:
        del now
        async with self._cleanup_lock:
            cleanup = self._cleanups.get(cleanup_id)
            if cleanup is not None:
                cleanup.completed = True

    async def mark_cleanup_failed(self, *, cleanup_id: UUID, now: datetime) -> None:
        del cleanup_id, now
