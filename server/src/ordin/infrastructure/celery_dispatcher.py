import asyncio
from collections.abc import Awaitable
from typing import cast
from uuid import UUID

from celery import Celery  # type: ignore[import-untyped]
from redis.asyncio import Redis


class CeleryRecognitionDispatcher:
    def __init__(self, *, broker_url: str, probe_timeout_seconds: float = 2.0) -> None:
        self._broker_url = broker_url
        self._probe_timeout_seconds = probe_timeout_seconds
        self._celery = Celery("ordin-api-dispatcher", broker=broker_url)
        self._celery.conf.update(
            task_serializer="json",
            accept_content=["json"],
            broker_connection_retry_on_startup=True,
        )

    async def enqueue(self, job_id: UUID) -> None:
        await asyncio.to_thread(
            self._celery.send_task,
            "ordin.recognition.process",
            args=(str(job_id),),
            queue="recognition",
            ignore_result=True,
            argsrepr="(<recognition-job>,)",
        )

    async def ping(self) -> None:
        broker = Redis.from_url(
            self._broker_url,
            socket_connect_timeout=self._probe_timeout_seconds,
            socket_timeout=self._probe_timeout_seconds,
        )
        try:
            await asyncio.wait_for(
                cast(Awaitable[bool], broker.ping()),
                timeout=self._probe_timeout_seconds,
            )
        finally:
            await broker.aclose()
