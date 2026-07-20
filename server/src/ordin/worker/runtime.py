from functools import lru_cache

import httpx
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from ordin.core.clock import SystemClock
from ordin.infrastructure.config import Settings
from ordin.infrastructure.database import account_models
from ordin.infrastructure.database import models as database_models
from ordin.infrastructure.database.account_repository import (
    SqlAlchemyWorkerAccountCleanupRepository,
)
from ordin.infrastructure.database.recognition_repository import (
    SqlAlchemyWorkerRecognitionRepository,
)
from ordin.infrastructure.object_storage.s3 import (
    S3SyncObjectStorage,
    build_s3_client,
)
from ordin.infrastructure.recognition_provider import (
    DeterministicDevelopmentRecognitionProvider,
    HttpRecognitionProvider,
)
from ordin.modules.recognition.ports import RecognitionProvider
from ordin.worker.recognition_service import RecognitionWorkerService

del account_models
del database_models


@lru_cache
def get_worker_service() -> RecognitionWorkerService:
    settings = Settings()
    engine = create_engine(
        settings.database_url,
        pool_pre_ping=True,
        hide_parameters=True,
    )
    session_factory = sessionmaker(engine, expire_on_commit=False)
    s3_client = build_s3_client(
        endpoint_url=str(settings.s3_endpoint_url),
        region=settings.s3_region,
        access_key_id=settings.s3_access_key_id.get_secret_value(),
        secret_access_key=settings.s3_secret_access_key.get_secret_value(),
        force_path_style=settings.s3_force_path_style,
    )
    if settings.recognition_provider_backend == "development":
        provider: RecognitionProvider = DeterministicDevelopmentRecognitionProvider()
    else:
        provider_url = settings.recognition_provider_url
        provider_token = settings.recognition_provider_token
        if provider_url is None or provider_token is None:
            raise RuntimeError("recognition provider settings were not validated")
        provider = HttpRecognitionProvider(
            client=httpx.Client(
                timeout=settings.recognition_provider_timeout_seconds,
                follow_redirects=False,
            ),
            url=str(provider_url),
            bearer_token=provider_token.get_secret_value(),
            provider_name=settings.recognition_provider_name,
        )
    return RecognitionWorkerService(
        repository=SqlAlchemyWorkerRecognitionRepository(session_factory),
        storage=S3SyncObjectStorage(s3_client, bucket=settings.s3_bucket),
        provider=provider,
        clock=SystemClock(),
        max_image_bytes=settings.recognition_max_image_bytes,
        confidence_threshold_milli=settings.recognition_confidence_threshold_milli,
        claim_lease_seconds=settings.recognition_claim_lease_seconds,
        account_cleanup_repository=SqlAlchemyWorkerAccountCleanupRepository(session_factory),
        account_cleanup_batch_size=settings.account_cleanup_batch_size,
        account_cleanup_claim_lease_seconds=settings.account_cleanup_claim_lease_seconds,
    )
