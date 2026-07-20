from datetime import UTC, datetime
from uuid import uuid4

import pytest

from ordin.core.errors import InvalidSyncOperationError
from ordin.infrastructure.records_memory import InMemoryRecordsRepository
from ordin.modules.records.models import (
    FastingPlan,
    SyncAction,
    SyncEntityType,
    SyncOperation,
    UserPreferencesInput,
)
from ordin.modules.records.service import RecordsService, _operation_hash


class _Clock:
    def now(self) -> datetime:
        return datetime(2026, 7, 20, 12, tzinfo=UTC)


def _preferences_operation() -> SyncOperation:
    return SyncOperation(
        operation_id=uuid4(),
        entity_type=SyncEntityType.APP_PREFERENCES,
        entity_id="current",
        action=SyncAction.UPSERT,
        expected_version=0,
        payload_version=1,
        app_preferences=UserPreferencesInput(
            daily_energy_target_kcal=1800,
            selected_fasting_plan=FastingPlan.BALANCED,
            fasting_reminder_enabled=True,
        ),
    )


async def test_duplicate_operation_ids_in_one_batch_are_rejected() -> None:
    repository = InMemoryRecordsRepository()
    service = RecordsService(repository=repository, clock=_Clock())
    operation = _preferences_operation()
    user_id = uuid4()

    with pytest.raises(InvalidSyncOperationError):
        await service.push(user_id=user_id, operations=(operation, operation))
    assert await repository.get_user_preferences(user_id=user_id) is None


def test_operation_fingerprint_is_stable_and_user_scoped() -> None:
    operation = _preferences_operation()
    first_user = uuid4()
    second_user = uuid4()

    assert _operation_hash(first_user, operation) == _operation_hash(first_user, operation)
    assert _operation_hash(first_user, operation) != _operation_hash(second_user, operation)
