from fastapi import APIRouter

from ordin.api.routes.auth import router as auth_router
from ordin.api.routes.health import router as health_router
from ordin.api.routes.recognitions import router as recognitions_router
from ordin.api.routes.records import router as records_router
from ordin.api.routes.users import router as users_router

api_router = APIRouter()
api_router.include_router(health_router)
api_router.include_router(auth_router)
api_router.include_router(users_router)
api_router.include_router(records_router)
api_router.include_router(recognitions_router)
