from datetime import date
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Path, Query

from ordin.api.dependencies import ContainerDependency, PrincipalDependency
from ordin.api.errors import problem_responses
from ordin.api.record_schemas import (
    AppPreferencesResponse,
    FastingSessionListResponse,
    FastingSessionResponse,
    MealListResponse,
    MealResponse,
    SyncPullResponse,
    SyncPushInput,
    SyncPushResponse,
    SyncWriteResultResponse,
)
from ordin.core.errors import InvalidSyncOperationError
from ordin.modules.records.models import FastingSessionStatus

router = APIRouter()


@router.post(
    "/sync/push",
    operation_id="pushSyncOperations",
    response_model=SyncPushResponse,
    responses=problem_responses(401, 422),
    summary="Push an ordered batch of offline operations",
    tags=["synchronization"],
)
async def push_sync_operations(
    payload: SyncPushInput,
    principal: PrincipalDependency,
    container: ContainerDependency,
) -> SyncPushResponse:
    results = await container.records_service.push(
        user_id=principal.user.id,
        operations=tuple(operation.to_domain() for operation in payload.operations),
    )
    return SyncPushResponse(
        results=[SyncWriteResultResponse.from_domain(result) for result in results]
    )


@router.get(
    "/sync/pull",
    operation_id="pullSyncChanges",
    response_model=SyncPullResponse,
    responses=problem_responses(401, 422),
    summary="Pull ordered changes after a synchronization cursor",
    tags=["synchronization"],
)
async def pull_sync_changes(
    principal: PrincipalDependency,
    container: ContainerDependency,
    cursor: Annotated[int, Query(ge=0)] = 0,
    limit: Annotated[int, Query(ge=1, le=500)] = 100,
) -> SyncPullResponse:
    page = await container.records_service.pull(
        user_id=principal.user.id,
        after_cursor=cursor,
        limit=limit,
    )
    return SyncPullResponse.from_domain(page)


@router.get(
    "/meals",
    operation_id="listMeals",
    response_model=MealListResponse,
    responses=problem_responses(401, 422),
    summary="List current meal records",
    tags=["meals"],
)
async def list_meals(
    principal: PrincipalDependency,
    container: ContainerDependency,
    local_day: Annotated[
        str | None,
        Query(
            alias="localDay",
            pattern=r"^[0-9]{4}-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12][0-9]|3[01])$",
        ),
    ] = None,
    limit: Annotated[int, Query(ge=1, le=200)] = 100,
) -> MealListResponse:
    try:
        parsed_local_day = date.fromisoformat(local_day) if local_day is not None else None
    except ValueError as error:
        raise InvalidSyncOperationError from error
    meals = await container.records_service.list_meals(
        user_id=principal.user.id,
        local_day=parsed_local_day,
        limit=limit,
    )
    return MealListResponse(items=[MealResponse.from_domain(meal) for meal in meals])


@router.get(
    "/meals/{mealId}",
    operation_id="getMeal",
    response_model=MealResponse,
    responses=problem_responses(401, 404, 422),
    summary="Get a current meal record",
    tags=["meals"],
)
async def get_meal(
    meal_id: Annotated[UUID, Path(alias="mealId")],
    principal: PrincipalDependency,
    container: ContainerDependency,
) -> MealResponse:
    meal = await container.records_service.get_meal(
        user_id=principal.user.id,
        meal_id=meal_id,
    )
    return MealResponse.from_domain(meal)


@router.get(
    "/fasting-sessions",
    operation_id="listFastingSessions",
    response_model=FastingSessionListResponse,
    responses=problem_responses(401, 422),
    summary="List current fasting sessions",
    tags=["fasting"],
)
async def list_fasting_sessions(
    principal: PrincipalDependency,
    container: ContainerDependency,
    session_status: Annotated[
        FastingSessionStatus | None,
        Query(alias="status"),
    ] = None,
    limit: Annotated[int, Query(ge=1, le=200)] = 100,
) -> FastingSessionListResponse:
    sessions = await container.records_service.list_fasting_sessions(
        user_id=principal.user.id,
        status=session_status,
        limit=limit,
    )
    return FastingSessionListResponse(
        items=[FastingSessionResponse.from_domain(session) for session in sessions]
    )


@router.get(
    "/fasting-sessions/{fastingSessionId}",
    operation_id="getFastingSession",
    response_model=FastingSessionResponse,
    responses=problem_responses(401, 404, 422),
    summary="Get a current fasting session",
    tags=["fasting"],
)
async def get_fasting_session(
    fasting_session_id: Annotated[UUID, Path(alias="fastingSessionId")],
    principal: PrincipalDependency,
    container: ContainerDependency,
) -> FastingSessionResponse:
    session = await container.records_service.get_fasting_session(
        user_id=principal.user.id,
        fasting_session_id=fasting_session_id,
    )
    return FastingSessionResponse.from_domain(session)


@router.get(
    "/users/me/preferences",
    operation_id="getCurrentAppPreferences",
    response_model=AppPreferencesResponse,
    responses=problem_responses(401, 404),
    summary="Get the current application preferences",
    tags=["users"],
)
async def get_current_app_preferences(
    principal: PrincipalDependency,
    container: ContainerDependency,
) -> AppPreferencesResponse:
    preferences = await container.records_service.get_user_preferences(user_id=principal.user.id)
    return AppPreferencesResponse.from_domain(preferences)
