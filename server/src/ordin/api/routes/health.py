from typing import Literal

from fastapi import APIRouter
from pydantic import BaseModel

from ordin.api.dependencies import ContainerDependency
from ordin.api.errors import problem_responses
from ordin.core.errors import ServiceUnavailableError

router = APIRouter(tags=["system"])


class HealthResponse(BaseModel):
    status: Literal["ok"] = "ok"


@router.get(
    "/health",
    operation_id="getHealth",
    response_model=HealthResponse,
    summary="Check API health",
)
async def get_health() -> HealthResponse:
    return HealthResponse()


class ReadinessResponse(BaseModel):
    status: Literal["ready"] = "ready"


@router.get(
    "/ready",
    operation_id="getReadiness",
    response_model=ReadinessResponse,
    responses=problem_responses(503),
    summary="Check dependency readiness",
)
async def get_readiness(container: ContainerDependency) -> ReadinessResponse:
    if not await container.ready():
        raise ServiceUnavailableError
    return ReadinessResponse()
