from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

import pytest

from ordin.modules.recognition.errors import (
    ObjectNotFoundError,
    ObjectStorageUnavailableError,
    ProviderTemporaryError,
)
from ordin.modules.recognition.models import (
    ProviderAnalysis,
    ProviderFoodCandidate,
    RecognitionAlternative,
    RecognitionJob,
    RecognitionStatus,
)
from ordin.worker.recognition_service import (
    RecognitionWorkerService,
    RetryableRecognitionJobError,
)


class _Clock:
    def now(self) -> datetime:
        return datetime(2026, 7, 20, 12, tzinfo=UTC)


class _Storage:
    def __init__(self, failures: dict[str, Exception] | None = None) -> None:
        self.deleted: list[str] = []
        self.failures = failures or {}

    def read(self, key: str, *, max_bytes: int) -> bytes:
        del key, max_bytes
        return b"sanitized-image"

    def delete(self, key: str) -> None:
        self.deleted.append(key)
        failure = self.failures.get(key)
        if failure is not None:
            raise failure


class _Provider:
    def __init__(
        self,
        *,
        confidence: int,
        temporary_failure: bool = False,
        analysis: ProviderAnalysis | None = None,
    ) -> None:
        self.confidence = confidence
        self.temporary_failure = temporary_failure
        self.analysis = analysis

    def analyze_food_image(self, *, content: bytes, content_type: str) -> ProviderAnalysis:
        del content, content_type
        if self.temporary_failure:
            raise ProviderTemporaryError
        if self.analysis is not None:
            return self.analysis
        return ProviderAnalysis(
            provider_name="test-provider",
            overall_confidence_milli=self.confidence,
            items=(
                ProviderFoodCandidate(
                    name="Dish one",
                    canonical_food_id="dish-one",
                    serving_milli=200_000,
                    energy_kcal=320,
                    protein_mg=15_000,
                    carbs_mg=35_000,
                    fat_mg=10_000,
                    confidence_milli=self.confidence,
                ),
            ),
        )


class _Repository:
    def __init__(self) -> None:
        self.job_id = uuid4()
        self.claimed = False
        self.completed_status: str | None = None
        self.completed_items = 0
        self.released_error: str | None = None
        self.failed_error: str | None = None
        self.expired_incoming: list[tuple[UUID, str]] = []
        self.expired_sources: list[tuple[UUID, str]] = []
        self.incoming_marked: list[UUID] = []
        self.sources_marked: list[UUID] = []

    def claim_job(
        self,
        *,
        job_id: UUID,
        now: datetime,
        lease_seconds: int,
    ) -> tuple[RecognitionJob, str, str] | None:
        del now, lease_seconds
        if job_id != self.job_id or self.claimed:
            return None
        self.claimed = True
        return _job(job_id), "recognition/source/test.png", "image/png"

    def complete_job(self, **kwargs: object) -> None:
        self.completed_status = str(kwargs["status"])
        self.completed_items = len(kwargs["items"])  # type: ignore[arg-type]

    def release_job_for_retry(self, *, job_id: UUID, error_code: str, now: datetime) -> None:
        del job_id, now
        self.released_error = error_code

    def fail_job(self, *, job_id: UUID, error_code: str, now: datetime) -> None:
        del job_id, now
        self.failed_error = error_code

    def list_expired_sources(
        self,
        *,
        now: datetime,
        limit: int,
    ) -> tuple[tuple[UUID, str], ...]:
        del now
        return tuple(self.expired_sources[:limit])

    def list_expired_incoming_uploads(
        self,
        *,
        now: datetime,
        limit: int,
    ) -> tuple[tuple[UUID, str], ...]:
        del now
        return tuple(self.expired_incoming[:limit])

    def mark_incoming_object_deleted(self, *, upload_id: UUID, now: datetime) -> None:
        del now
        self.incoming_marked.append(upload_id)

    def mark_source_deleted(self, *, upload_id: UUID, now: datetime) -> None:
        del now
        self.sources_marked.append(upload_id)


class _AccountCleanupRepository:
    def __init__(self, pending: list[tuple[UUID, str]]) -> None:
        self.pending = pending
        self.succeeded: list[UUID] = []
        self.failed: list[UUID] = []
        self.claim_limits: list[int] = []

    def claim_cleanups(
        self,
        *,
        now: datetime,
        limit: int,
        lease_seconds: int,
    ) -> tuple[tuple[UUID, str], ...]:
        del now, lease_seconds
        self.claim_limits.append(limit)
        return tuple(item for item in self.pending if item[0] not in self.succeeded)[:limit]

    def mark_cleanup_succeeded(self, *, cleanup_id: UUID, now: datetime) -> None:
        del now
        self.succeeded.append(cleanup_id)

    def mark_cleanup_failed(self, *, cleanup_id: UUID, now: datetime) -> None:
        del now
        self.failed.append(cleanup_id)


def _job(job_id: UUID) -> RecognitionJob:
    now = datetime(2026, 7, 20, 12, tzinfo=UTC)
    return RecognitionJob(
        id=job_id,
        user_id=uuid4(),
        upload_id=uuid4(),
        status=RecognitionStatus.RUNNING,
        provider_name=None,
        overall_confidence_milli=None,
        needs_review_reason=None,
        error_code=None,
        version=2,
        attempt_count=1,
        source_retention_until=now + timedelta(hours=24),
        created_at=now,
        updated_at=now,
        completed_at=None,
        items=(),
    )


def _service(
    repository: _Repository,
    provider: _Provider,
    *,
    storage: _Storage | None = None,
) -> RecognitionWorkerService:
    return RecognitionWorkerService(
        repository=repository,
        storage=storage or _Storage(),
        provider=provider,
        clock=_Clock(),
        max_image_bytes=1024,
        confidence_threshold_milli=700,
        claim_lease_seconds=180,
    )


def _analysis(
    *,
    provider_name: str = "provider",
    canonical_food_id: str | None = "dish",
    alternatives: tuple[RecognitionAlternative, ...] = (),
) -> ProviderAnalysis:
    return ProviderAnalysis(
        provider_name=provider_name,
        overall_confidence_milli=900,
        items=(
            ProviderFoodCandidate(
                name="Dish",
                canonical_food_id=canonical_food_id,
                serving_milli=100_000,
                energy_kcal=100,
                protein_mg=1_000,
                carbs_mg=2_000,
                fat_mg=3_000,
                confidence_milli=900,
                alternatives=alternatives,
            ),
        ),
    )


def test_low_confidence_becomes_needs_review_and_duplicate_claim_is_noop() -> None:
    repository = _Repository()
    service = _service(repository, _Provider(confidence=520))

    assert service.process(repository.job_id) is True
    assert repository.completed_status == "needs_review"
    assert repository.completed_items == 1
    assert service.process(repository.job_id) is False


def test_transient_provider_failure_releases_job_for_bounded_retry() -> None:
    repository = _Repository()
    service = _service(repository, _Provider(confidence=900, temporary_failure=True))

    with pytest.raises(RetryableRecognitionJobError):
        service.process(repository.job_id)
    assert repository.released_error == "provider_temporarily_unavailable"


def test_cleanup_expires_missing_incoming_object_and_respects_page_limit() -> None:
    repository = _Repository()
    first_id = uuid4()
    second_id = uuid4()
    repository.expired_incoming = [(first_id, "missing"), (second_id, "next-page")]
    storage = _Storage({"missing": ObjectNotFoundError()})
    service = _service(repository, _Provider(confidence=900), storage=storage)

    assert service.cleanup_expired_sources(limit=1) == 1

    assert storage.deleted == ["missing"]
    assert repository.incoming_marked == [first_id]


def test_cleanup_retries_incoming_object_after_storage_recovers() -> None:
    repository = _Repository()
    upload_id = uuid4()
    repository.expired_incoming = [(upload_id, "temporarily-unavailable")]
    storage = _Storage({"temporarily-unavailable": ObjectStorageUnavailableError()})
    service = _service(repository, _Provider(confidence=900), storage=storage)

    assert service.cleanup_expired_sources() == 0
    assert repository.incoming_marked == []

    storage.failures.clear()
    assert service.cleanup_expired_sources() == 1
    assert repository.incoming_marked == [upload_id]


def test_deleted_account_cleanup_is_bounded_and_missing_objects_succeed() -> None:
    first_id = uuid4()
    missing_id = uuid4()
    deferred_id = uuid4()
    cleanup_repository = _AccountCleanupRepository(
        [(first_id, "first"), (missing_id, "missing"), (deferred_id, "deferred")]
    )
    storage = _Storage({"missing": ObjectNotFoundError()})
    service = RecognitionWorkerService(
        repository=_Repository(),
        storage=storage,
        provider=_Provider(confidence=900),
        clock=_Clock(),
        max_image_bytes=1024,
        confidence_threshold_milli=700,
        claim_lease_seconds=180,
        account_cleanup_repository=cleanup_repository,
        account_cleanup_batch_size=2,
        account_cleanup_claim_lease_seconds=300,
    )

    assert service.cleanup_deleted_account_objects() == 2
    assert cleanup_repository.claim_limits == [2]
    assert cleanup_repository.succeeded == [first_id, missing_id]
    assert deferred_id not in cleanup_repository.succeeded


def test_deleted_account_cleanup_retries_after_storage_failure() -> None:
    cleanup_id = uuid4()
    cleanup_repository = _AccountCleanupRepository([(cleanup_id, "temporary")])
    storage = _Storage({"temporary": ObjectStorageUnavailableError()})
    service = RecognitionWorkerService(
        repository=_Repository(),
        storage=storage,
        provider=_Provider(confidence=900),
        clock=_Clock(),
        max_image_bytes=1024,
        confidence_threshold_milli=700,
        claim_lease_seconds=180,
        account_cleanup_repository=cleanup_repository,
    )

    assert service.cleanup_deleted_account_objects() == 0
    assert cleanup_repository.failed == [cleanup_id]
    assert cleanup_repository.succeeded == []

    storage.failures.clear()
    assert service.cleanup_deleted_account_objects() == 1
    assert cleanup_repository.succeeded == [cleanup_id]


@pytest.mark.parametrize(
    "analysis",
    [
        _analysis(provider_name="  "),
        _analysis(provider_name="p" * 65),
        _analysis(provider_name="provider\u0000name"),
        _analysis(canonical_food_id=""),
        _analysis(canonical_food_id="c" * 121),
        _analysis(canonical_food_id="dish\u0000id"),
        _analysis(
            alternatives=(RecognitionAlternative(name="Alternative", confidence_milli=1001),),
        ),
        _analysis(
            alternatives=(RecognitionAlternative(name="\t", confidence_milli=500),),
        ),
        _analysis(
            alternatives=(RecognitionAlternative(name="a" * 121, confidence_milli=500),),
        ),
        _analysis(
            alternatives=tuple(
                RecognitionAlternative(name=f"Alternative {index}", confidence_milli=500)
                for index in range(6)
            )
        ),
    ],
    ids=(
        "blank-provider-name",
        "provider-name-too-long",
        "control-character-provider-name",
        "blank-canonical-id",
        "canonical-id-too-long",
        "control-character-canonical-id",
        "alternative-confidence-out-of-range",
        "blank-alternative-name",
        "alternative-name-too-long",
        "too-many-alternatives",
    ),
)
def test_malformed_provider_analysis_fails_closed(analysis: ProviderAnalysis) -> None:
    repository = _Repository()
    service = _service(repository, _Provider(confidence=900, analysis=analysis))

    assert service.process(repository.job_id) is True

    assert repository.failed_error == "provider_rejected_request"
    assert repository.completed_status is None
