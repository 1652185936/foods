from uuid import UUID, uuid4

import pytest

from ordin.worker import tasks


class _ScheduledRetry(Exception):
    pass


class _ExplodingService:
    def __init__(self) -> None:
        self.released: tuple[UUID, str] | None = None
        self.failed: UUID | None = None

    def process(self, job_id: UUID) -> bool:
        del job_id
        raise RuntimeError("database connection reset")

    def release_for_retry(self, job_id: UUID, *, error_code: str) -> None:
        self.released = (job_id, error_code)

    def fail_after_retries(self, job_id: UUID) -> None:
        self.failed = job_id


def test_unexpected_failure_releases_claim_before_retry(monkeypatch: pytest.MonkeyPatch) -> None:
    job_id = uuid4()
    service = _ExplodingService()
    monkeypatch.setattr(tasks, "get_worker_service", lambda: service)

    def retry(*, exc: Exception, countdown: int) -> None:
        del exc, countdown
        raise _ScheduledRetry

    monkeypatch.setattr(tasks.process_recognition, "retry", retry)

    with pytest.raises(_ScheduledRetry):
        tasks.process_recognition.run(str(job_id))

    assert service.released == (job_id, "worker_transient_failure")
    assert service.failed is None


def test_unexpected_failure_marks_job_failed_after_final_retry(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    job_id = uuid4()
    service = _ExplodingService()
    monkeypatch.setattr(tasks, "get_worker_service", lambda: service)
    monkeypatch.setattr(tasks.settings, "recognition_task_max_retries", 0)

    assert tasks.process_recognition.run(str(job_id)) is True

    assert service.released is None
    assert service.failed == job_id
