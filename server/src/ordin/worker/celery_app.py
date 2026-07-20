from celery import Celery  # type: ignore[import-untyped]

from ordin.infrastructure.config import Settings

settings = Settings()

app = Celery(
    "ordin-worker",
    broker=settings.celery_broker_url,
    include=["ordin.worker.tasks"],
)
app.conf.update(
    accept_content=["json"],
    task_serializer="json",
    result_backend=None,
    task_ignore_result=True,
    task_acks_late=True,
    task_reject_on_worker_lost=True,
    worker_prefetch_multiplier=1,
    broker_connection_retry_on_startup=True,
    broker_transport_options={
        "visibility_timeout": settings.recognition_claim_lease_seconds,
    },
    task_soft_time_limit=settings.recognition_task_soft_timeout_seconds,
    task_time_limit=settings.recognition_task_hard_timeout_seconds,
    task_default_queue="recognition",
    task_routes={
        "ordin.recognition.process": {"queue": "recognition"},
        "ordin.recognition.cleanup": {"queue": "maintenance"},
        "ordin.account.cleanup": {"queue": "maintenance"},
    },
    beat_schedule={
        "cleanup-expired-recognition-sources": {
            "task": "ordin.recognition.cleanup",
            "schedule": 60 * 60,
        },
        "cleanup-deleted-account-objects": {
            "task": "ordin.account.cleanup",
            "schedule": 15 * 60,
        },
    },
    timezone="UTC",
    enable_utc=True,
)
