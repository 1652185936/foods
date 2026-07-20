import asyncio
import selectors
import sys
from collections.abc import AsyncIterator, Callable, Mapping
from datetime import UTC, datetime, timedelta

import pytest
import pytest_asyncio
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from ordin.api.main import create_app
from ordin.infrastructure.config import Settings
from ordin.infrastructure.container import AppContainer, assemble_container
from ordin.infrastructure.memory import (
    InMemoryApplicationRepository,
    InMemoryOtpChallengeStore,
    InMemoryRateLimiter,
)
from ordin.infrastructure.object_storage.memory import InMemoryObjectStorage
from ordin.infrastructure.recognition_memory import (
    InMemoryRecognitionRepository,
    RecordingRecognitionDispatcher,
)
from ordin.infrastructure.records_memory import InMemoryRecordsRepository
from ordin.modules.auth.otp import FixedOtpCodeGenerator


def pytest_asyncio_loop_factories(
    config: pytest.Config,
    item: pytest.Item,
) -> Mapping[str, Callable[[], asyncio.AbstractEventLoop]]:
    del config, item
    if sys.platform == "win32":
        return {"windows-selector": lambda: asyncio.SelectorEventLoop(selectors.SelectSelector())}
    return {"default": asyncio.new_event_loop}


class MutableClock:
    def __init__(self) -> None:
        self.current = datetime(2026, 7, 20, 12, 0, tzinfo=UTC)

    def now(self) -> datetime:
        return self.current

    def advance(self, **kwargs: float) -> None:
        self.current += timedelta(**kwargs)


class RecordingOtpSender:
    def __init__(self) -> None:
        self.deliveries: list[tuple[str, str, datetime]] = []

    async def send(self, phone_number: str, code: str, expires_at: datetime) -> None:
        self.deliveries.append((phone_number, code, expires_at))


@pytest.fixture
def settings() -> Settings:
    return Settings(
        environment="test",
        otp_phone_limit=5,
        otp_device_limit=8,
        otp_ip_limit=20,
    )


@pytest.fixture
def clock() -> MutableClock:
    return MutableClock()


@pytest.fixture
def otp_sender() -> RecordingOtpSender:
    return RecordingOtpSender()


@pytest.fixture
def repository() -> InMemoryApplicationRepository:
    return InMemoryApplicationRepository()


@pytest.fixture
def records_repository() -> InMemoryRecordsRepository:
    return InMemoryRecordsRepository()


@pytest.fixture
def recognition_repository() -> InMemoryRecognitionRepository:
    return InMemoryRecognitionRepository()


@pytest.fixture
def recognition_storage() -> InMemoryObjectStorage:
    return InMemoryObjectStorage()


@pytest.fixture
def recognition_dispatcher() -> RecordingRecognitionDispatcher:
    return RecordingRecognitionDispatcher()


@pytest.fixture
def otp_store() -> InMemoryOtpChallengeStore:
    return InMemoryOtpChallengeStore()


@pytest.fixture
def rate_limiter() -> InMemoryRateLimiter:
    return InMemoryRateLimiter()


@pytest.fixture
def container(
    settings: Settings,
    clock: MutableClock,
    otp_sender: RecordingOtpSender,
    repository: InMemoryApplicationRepository,
    records_repository: InMemoryRecordsRepository,
    recognition_repository: InMemoryRecognitionRepository,
    recognition_storage: InMemoryObjectStorage,
    recognition_dispatcher: RecordingRecognitionDispatcher,
    otp_store: InMemoryOtpChallengeStore,
    rate_limiter: InMemoryRateLimiter,
) -> AppContainer:
    return assemble_container(
        settings=settings,
        repository=repository,
        records_repository=records_repository,
        recognition_repository=recognition_repository,
        recognition_storage=recognition_storage,
        recognition_dispatcher=recognition_dispatcher,
        otp_store=otp_store,
        rate_limiter=rate_limiter,
        otp_sender=otp_sender,
        otp_code_generator=FixedOtpCodeGenerator("123456"),
        clock=clock,
    )


@pytest.fixture
def app(settings: Settings, container: AppContainer) -> FastAPI:
    return create_app(settings, container)


@pytest_asyncio.fixture
async def client(app: FastAPI) -> AsyncIterator[AsyncClient]:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as test_client:
        yield test_client
