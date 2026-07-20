from fastapi import FastAPI

from ordin import __version__
from ordin.api.router import api_router
from ordin.infrastructure.config import Settings, get_settings


def create_app(settings: Settings | None = None) -> FastAPI:
    resolved_settings = settings or get_settings()
    application = FastAPI(
        title=resolved_settings.app_name,
        version=__version__,
    )
    application.include_router(api_router, prefix=resolved_settings.api_v1_prefix)
    return application


app = create_app()
