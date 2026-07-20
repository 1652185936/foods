import asyncio

import pytest

from ordin.infrastructure.celery_dispatcher import CeleryRecognitionDispatcher


class _HealthyBroker:
    def __init__(self) -> None:
        self.closed = False

    async def ping(self) -> bool:
        return True

    async def aclose(self) -> None:
        self.closed = True


class _BlockingBroker(_HealthyBroker):
    async def ping(self) -> bool:
        await asyncio.Future[None]()
        return True


async def test_broker_probe_uses_configured_url_and_closes_connection(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    broker = _HealthyBroker()
    observed: dict[str, object] = {}

    def from_url(url: str, **kwargs: object) -> _HealthyBroker:
        observed["url"] = url
        observed.update(kwargs)
        return broker

    monkeypatch.setattr(
        "ordin.infrastructure.celery_dispatcher.Redis.from_url",
        from_url,
    )
    dispatcher = CeleryRecognitionDispatcher(
        broker_url="redis://broker.example/14",
        probe_timeout_seconds=0.05,
    )

    await dispatcher.ping()

    assert observed == {
        "url": "redis://broker.example/14",
        "socket_connect_timeout": 0.05,
        "socket_timeout": 0.05,
    }
    assert broker.closed is True


async def test_broker_probe_has_a_total_timeout_and_closes_connection(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    broker = _BlockingBroker()
    monkeypatch.setattr(
        "ordin.infrastructure.celery_dispatcher.Redis.from_url",
        lambda *_args, **_kwargs: broker,
    )
    dispatcher = CeleryRecognitionDispatcher(
        broker_url="redis://broker.example/14",
        probe_timeout_seconds=0.01,
    )

    with pytest.raises(TimeoutError):
        await dispatcher.ping()

    assert broker.closed is True
