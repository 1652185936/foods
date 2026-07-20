import logging
from collections.abc import Mapping
from typing import Any

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHttpException

from ordin.api.schemas import FieldProblem, ProblemDetails
from ordin.core.errors import (
    ApplicationError,
    InvalidAuthenticationError,
    InvalidOtpError,
    RateLimitExceededError,
    ResourceNotFoundError,
    ServiceUnavailableError,
    VersionConflictError,
)
from ordin.core.identifiers import new_uuid

logger = logging.getLogger(__name__)


def problem_responses(*statuses: int) -> dict[int | str, dict[str, Any]]:
    return {
        status: {
            "model": ProblemDetails,
            "content": {"application/problem+json": {}},
        }
        for status in statuses
    }


def install_exception_handlers(application: FastAPI) -> None:
    application.add_exception_handler(ApplicationError, _application_error_handler)
    application.add_exception_handler(RequestValidationError, _validation_error_handler)
    application.add_exception_handler(StarletteHttpException, _http_error_handler)
    application.add_exception_handler(Exception, _unexpected_error_handler)


async def _application_error_handler(request: Request, error: Exception) -> JSONResponse:
    assert isinstance(error, ApplicationError)
    headers: dict[str, str] = {}
    if isinstance(error, InvalidAuthenticationError):
        status, title, detail = 401, "Authentication failed", "Authentication is required."
        headers["WWW-Authenticate"] = "Bearer"
    elif isinstance(error, InvalidOtpError):
        status = 401
        title = "Verification failed"
        detail = "The verification code could not be accepted."
    elif isinstance(error, RateLimitExceededError):
        status, title, detail = 429, "Too many requests", "Retry after the indicated delay."
        headers["Retry-After"] = str(error.retry_after_seconds)
    elif isinstance(error, ResourceNotFoundError):
        status, title, detail = 404, "Resource not found", "The requested resource was not found."
    elif isinstance(error, VersionConflictError):
        status, title, detail = 409, "Version conflict", "Refresh the resource and retry."
    elif isinstance(error, ServiceUnavailableError):
        status, title, detail = (
            503,
            "Service unavailable",
            "The service is temporarily unavailable.",
        )
    else:
        status, title, detail = 400, "Request failed", "The request could not be completed."
    return _problem_response(
        request,
        status=status,
        code=error.code,
        title=title,
        detail=detail,
        headers=headers,
    )


async def _validation_error_handler(
    request: Request,
    error: Exception,
) -> JSONResponse:
    assert isinstance(error, RequestValidationError)
    field_errors = [
        FieldProblem(
            field=".".join(str(part) for part in item["loc"] if part not in {"body"}),
            code=str(item["type"]),
            message=str(item["msg"]),
        )
        for item in error.errors()
    ]
    return _problem_response(
        request,
        status=422,
        code="validation_error",
        title="Validation failed",
        detail="One or more request fields are invalid.",
        field_errors=field_errors,
    )


async def _http_error_handler(request: Request, error: Exception) -> JSONResponse:
    assert isinstance(error, StarletteHttpException)
    return _problem_response(
        request,
        status=error.status_code,
        code="http_error",
        title="HTTP request failed",
        detail="The HTTP request could not be completed.",
        headers=error.headers,
    )


async def _unexpected_error_handler(request: Request, error: Exception) -> JSONResponse:
    trace_id = _trace_id(request)
    logger.exception("Unhandled API error", extra={"trace_id": trace_id}, exc_info=error)
    return _problem_response(
        request,
        status=500,
        code="internal_error",
        title="Internal server error",
        detail="An unexpected error occurred.",
    )


def _problem_response(
    request: Request,
    *,
    status: int,
    code: str,
    title: str,
    detail: str,
    headers: Mapping[str, str] | None = None,
    field_errors: list[FieldProblem] | None = None,
) -> JSONResponse:
    problem = ProblemDetails(
        type=f"urn:ordin:problem:{code}",
        title=title,
        status=status,
        code=code,
        trace_id=_trace_id(request),
        detail=detail,
        field_errors=field_errors,
    )
    return JSONResponse(
        status_code=status,
        content=problem.model_dump(mode="json", by_alias=True, exclude_none=True),
        media_type="application/problem+json",
        headers=headers,
    )


def _trace_id(request: Request) -> str:
    return str(getattr(request.state, "trace_id", new_uuid()))
