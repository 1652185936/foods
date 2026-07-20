import unicodedata
from uuid import UUID

from ordin.core.clock import Clock
from ordin.core.identifiers import new_uuid
from ordin.modules.accounts.ports import WorkerAccountCleanupRepository
from ordin.modules.recognition.errors import (
    InvalidImageContentError,
    ObjectNotFoundError,
    ObjectStorageUnavailableError,
    ProviderPermanentError,
    ProviderTemporaryError,
)
from ordin.modules.recognition.models import (
    ProviderAnalysis,
    RecognitionItem,
    RecognitionStatus,
)
from ordin.modules.recognition.ports import (
    RecognitionProvider,
    SyncRecognitionObjectStorage,
    WorkerRecognitionRepository,
)


class RetryableRecognitionJobError(Exception):
    def __init__(self, error_code: str) -> None:
        super().__init__(error_code)
        self.error_code = error_code


class RecognitionWorkerService:
    def __init__(
        self,
        *,
        repository: WorkerRecognitionRepository,
        storage: SyncRecognitionObjectStorage,
        provider: RecognitionProvider,
        clock: Clock,
        max_image_bytes: int,
        confidence_threshold_milli: int,
        claim_lease_seconds: int,
        account_cleanup_repository: WorkerAccountCleanupRepository | None = None,
        account_cleanup_batch_size: int = 100,
        account_cleanup_claim_lease_seconds: int = 300,
    ) -> None:
        self._repository = repository
        self._storage = storage
        self._provider = provider
        self._clock = clock
        self._max_image_bytes = max_image_bytes
        self._confidence_threshold_milli = confidence_threshold_milli
        self._claim_lease_seconds = claim_lease_seconds
        self._account_cleanup_repository = account_cleanup_repository
        self._account_cleanup_batch_size = account_cleanup_batch_size
        self._account_cleanup_claim_lease_seconds = account_cleanup_claim_lease_seconds

    def process(self, job_id: UUID) -> bool:
        now = self._clock.now()
        claim = self._repository.claim_job(
            job_id=job_id,
            now=now,
            lease_seconds=self._claim_lease_seconds,
        )
        if claim is None:
            return False
        _, object_key, content_type = claim
        try:
            content = self._storage.read(object_key, max_bytes=self._max_image_bytes)
            analysis = self._provider.analyze_food_image(
                content=content,
                content_type=content_type,
            )
            _validate_analysis(analysis)
        except (ObjectStorageUnavailableError, ProviderTemporaryError) as error:
            self._repository.release_job_for_retry(
                job_id=job_id,
                error_code="provider_temporarily_unavailable",
                now=self._clock.now(),
            )
            raise RetryableRecognitionJobError("provider_temporarily_unavailable") from error
        except ObjectNotFoundError, InvalidImageContentError:
            self._repository.fail_job(
                job_id=job_id,
                error_code="source_unavailable",
                now=self._clock.now(),
            )
            return True
        except ProviderPermanentError:
            self._repository.fail_job(
                job_id=job_id,
                error_code="provider_rejected_request",
                now=self._clock.now(),
            )
            return True

        items = tuple(
            RecognitionItem(
                id=new_uuid(),
                position=position,
                name=item.name,
                canonical_food_id=item.canonical_food_id,
                serving_milli=item.serving_milli,
                energy_kcal=item.energy_kcal,
                protein_mg=item.protein_mg,
                carbs_mg=item.carbs_mg,
                fat_mg=item.fat_mg,
                confidence_milli=item.confidence_milli,
                alternatives=item.alternatives,
                is_user_corrected=False,
            )
            for position, item in enumerate(analysis.items)
        )
        needs_review = analysis.overall_confidence_milli < self._confidence_threshold_milli or any(
            item.confidence_milli < self._confidence_threshold_milli for item in analysis.items
        )
        status = RecognitionStatus.NEEDS_REVIEW if needs_review else RecognitionStatus.SUCCEEDED
        self._repository.complete_job(
            job_id=job_id,
            analysis=analysis,
            status=status.value,
            needs_review_reason="low_confidence" if needs_review else None,
            items=items,
            now=self._clock.now(),
        )
        return True

    def fail_after_retries(self, job_id: UUID) -> None:
        self._repository.fail_job(
            job_id=job_id,
            error_code="retry_exhausted",
            now=self._clock.now(),
        )

    def release_for_retry(self, job_id: UUID, *, error_code: str) -> None:
        self._repository.release_job_for_retry(
            job_id=job_id,
            error_code=error_code,
            now=self._clock.now(),
        )

    def cleanup_expired_sources(self, *, limit: int = 100) -> int:
        now = self._clock.now()
        cleaned = 0
        expired_incoming = self._repository.list_expired_incoming_uploads(
            now=now,
            limit=limit,
        )
        for upload_id, object_key in expired_incoming:
            try:
                self._storage.delete(object_key)
            except ObjectNotFoundError:
                pass
            except ObjectStorageUnavailableError:
                continue
            self._repository.mark_incoming_object_deleted(upload_id=upload_id, now=now)
            cleaned += 1

        expired_sources = self._repository.list_expired_sources(now=now, limit=limit)
        for upload_id, object_key in expired_sources:
            try:
                self._storage.delete(object_key)
            except ObjectNotFoundError:
                pass
            except ObjectStorageUnavailableError:
                continue
            self._repository.mark_source_deleted(upload_id=upload_id, now=now)
            cleaned += 1
        return cleaned

    def cleanup_deleted_account_objects(self) -> int:
        repository = self._account_cleanup_repository
        if repository is None:
            return 0
        now = self._clock.now()
        cleaned = 0
        pending = repository.claim_cleanups(
            now=now,
            limit=self._account_cleanup_batch_size,
            lease_seconds=self._account_cleanup_claim_lease_seconds,
        )
        for cleanup_id, object_key in pending:
            try:
                self._storage.delete(object_key)
            except ObjectNotFoundError:
                pass
            except ObjectStorageUnavailableError:
                repository.mark_cleanup_failed(cleanup_id=cleanup_id, now=self._clock.now())
                continue
            repository.mark_cleanup_succeeded(cleanup_id=cleanup_id, now=self._clock.now())
            cleaned += 1
        return cleaned


def _validate_analysis(analysis: ProviderAnalysis) -> None:
    if not _is_valid_provider_text(analysis.provider_name, max_length=64):
        raise ProviderPermanentError
    if not _is_int_in_range(analysis.overall_confidence_milli, minimum=0, maximum=1000):
        raise ProviderPermanentError
    if not 1 <= len(analysis.items) <= 10:
        raise ProviderPermanentError
    for item in analysis.items:
        if not _is_valid_provider_text(item.name, max_length=120):
            raise ProviderPermanentError
        if item.canonical_food_id is not None and not _is_valid_provider_text(
            item.canonical_food_id,
            max_length=120,
        ):
            raise ProviderPermanentError
        if not _is_int_in_range(item.confidence_milli, minimum=0, maximum=1000):
            raise ProviderPermanentError
        if not _is_int_in_range(item.serving_milli, minimum=1, maximum=10_000_000):
            raise ProviderPermanentError
        if not _is_int_in_range(item.energy_kcal, minimum=0, maximum=100_000):
            raise ProviderPermanentError
        if not all(
            _is_int_in_range(value, minimum=0, maximum=10_000_000)
            for value in (item.protein_mg, item.carbs_mg, item.fat_mg)
        ):
            raise ProviderPermanentError
        if len(item.alternatives) > 5:
            raise ProviderPermanentError
        for alternative in item.alternatives:
            if not _is_valid_provider_text(alternative.name, max_length=120):
                raise ProviderPermanentError
            if not _is_int_in_range(
                alternative.confidence_milli,
                minimum=0,
                maximum=1000,
            ):
                raise ProviderPermanentError


def _is_valid_provider_text(value: object, *, max_length: int) -> bool:
    if not isinstance(value, str) or value != value.strip() or not value:
        return False
    if len(value) > max_length:
        return False
    return not any(unicodedata.category(character).startswith("C") for character in value)


def _is_int_in_range(value: object, *, minimum: int, maximum: int) -> bool:
    return type(value) is int and minimum <= value <= maximum
