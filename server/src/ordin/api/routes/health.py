from typing import Literal

from fastapi import APIRouter
from pydantic import BaseModel

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
