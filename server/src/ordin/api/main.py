import re
from collections.abc import AsyncIterator, Awaitable, Callable
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from starlette.responses import Response

from ordin import __version__
from ordin.api.errors import install_exception_handlers
from ordin.api.openapi import install_openapi_contract
from ordin.api.router import api_router
from ordin.core.identifiers import new_uuid
from ordin.infrastructure.config import Settings, get_settings
from ordin.infrastructure.container import AppContainer, build_default_container

_REQUEST_ID_PATTERN = re.compile(r"^[A-Za-z0-9._-]{1,64}$")


def create_app(
    settings: Settings | None = None,
    container: AppContainer | None = None,
) -> FastAPI:
    resolved_settings = settings or get_settings()

    @asynccontextmanager
    async def lifespan(application: FastAPI) -> AsyncIterator[None]:
        if container is not None:
            application.state.container = container
            yield
            return
        owned_container = build_default_container(resolved_settings)
        application.state.container = owned_container
        try:
            yield
        finally:
            await owned_container.close()

    application = FastAPI(
        title=resolved_settings.app_name,
        version=__version__,
        docs_url="/docs" if resolved_settings.expose_api_docs else None,
        redoc_url=None,
        openapi_url="/openapi.json" if resolved_settings.expose_api_docs else None,
        lifespan=lifespan,
    )
    if container is not None:
        application.state.container = container
    install_exception_handlers(application)

    @application.middleware("http")
    async def attach_trace_id(
        request: Request,
        call_next: Callable[[Request], Awaitable[Response]],
    ) -> Response:
        inbound = request.headers.get("X-Request-ID", "")
        request.state.trace_id = (
            inbound if _REQUEST_ID_PATTERN.fullmatch(inbound) else str(new_uuid())
        )
        response = await call_next(request)
        response.headers["X-Request-ID"] = request.state.trace_id
        return response

    application.include_router(api_router, prefix=resolved_settings.api_v1_prefix)
    install_openapi_contract(application)
    return application


app = create_app()
