from typing import NoReturn, Protocol
from uuid import UUID

from billiard.exceptions import SoftTimeLimitExceeded  # type: ignore[import-untyped]

from ordin.infrastructure.config import Settings
from ordin.worker.celery_app import app
from ordin.worker.recognition_service import RetryableRecognitionJobError
from ordin.worker.runtime import get_worker_service

settings = Settings()


class _TaskRequest(Protocol):
    retries: int


class _BoundTask(Protocol):
    request: _TaskRequest

    def retry(self, *, exc: Exception, countdown: int) -> NoReturn: ...


@app.task(  # type: ignore[untyped-decorator]
    bind=True,
    name="ordin.recognition.process",
    max_retries=settings.recognition_task_max_retries,
)
def process_recognition(self: _BoundTask, job_id: str) -> bool:
    parsed_job_id = UUID(job_id)
    service = get_worker_service()
    try:
        return service.process(parsed_job_id)
    except SoftTimeLimitExceeded as error:
        service.release_for_retry(parsed_job_id, error_code="soft_timeout")
        if self.request.retries >= settings.recognition_task_max_retries:
            service.fail_after_retries(parsed_job_id)
            return True
        raise self.retry(
            exc=RetryableRecognitionJobError("soft_timeout"),
            countdown=_retry_delay(self.request.retries),
        ) from error
    except RetryableRecognitionJobError as error:
        if self.request.retries >= settings.recognition_task_max_retries:
            service.fail_after_retries(parsed_job_id)
            return True
        raise self.retry(
            exc=RetryableRecognitionJobError(error.error_code),
            countdown=_retry_delay(self.request.retries),
        ) from error
    except Exception as error:
        if self.request.retries >= settings.recognition_task_max_retries:
            service.fail_after_retries(parsed_job_id)
            return True
        service.release_for_retry(
            parsed_job_id,
            error_code="worker_transient_failure",
        )
        raise self.retry(
            exc=RetryableRecognitionJobError("worker_transient_failure"),
            countdown=_retry_delay(self.request.retries),
        ) from error


@app.task(name="ordin.recognition.cleanup")  # type: ignore[untyped-decorator]
def cleanup_expired_recognition_sources() -> int:
    return get_worker_service().cleanup_expired_sources()


@app.task(name="ordin.account.cleanup")  # type: ignore[untyped-decorator]
def cleanup_deleted_account_objects() -> int:
    return get_worker_service().cleanup_deleted_account_objects()


def _retry_delay(retry_count: int) -> int:
    return min(60, 1 << min(retry_count + 1, 5))
