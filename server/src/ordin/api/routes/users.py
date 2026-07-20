from fastapi import APIRouter

from ordin.api.dependencies import ContainerDependency, PrincipalDependency
from ordin.api.errors import problem_responses
from ordin.api.schemas import (
    HealthProfileInputModel,
    HealthProfileResponse,
    UserPatchInput,
    UserResponse,
)

router = APIRouter(prefix="/users/me", tags=["users"])


@router.get(
    "",
    operation_id="getCurrentUser",
    response_model=UserResponse,
    responses=problem_responses(401),
    summary="Get the current user",
)
async def get_current_user(principal: PrincipalDependency) -> UserResponse:
    return UserResponse.from_domain(principal.user)


@router.patch(
    "",
    operation_id="updateCurrentUser",
    response_model=UserResponse,
    responses=problem_responses(401, 404, 409, 422),
    summary="Update the current user",
)
async def update_current_user(
    payload: UserPatchInput,
    principal: PrincipalDependency,
    container: ContainerDependency,
) -> UserResponse:
    user = await container.users_service.update_nickname(
        user_id=principal.user.id,
        expected_version=payload.expected_version,
        nickname=payload.nickname,
    )
    return UserResponse.from_domain(user)


@router.get(
    "/health-profile",
    operation_id="getCurrentHealthProfile",
    response_model=HealthProfileResponse,
    responses=problem_responses(401, 404),
    summary="Get the current health profile",
)
async def get_current_health_profile(
    principal: PrincipalDependency,
    container: ContainerDependency,
) -> HealthProfileResponse:
    profile = await container.users_service.get_health_profile(principal.user.id)
    return HealthProfileResponse.from_domain(profile)


@router.put(
    "/health-profile",
    operation_id="putCurrentHealthProfile",
    response_model=HealthProfileResponse,
    responses=problem_responses(401, 404, 409, 422),
    summary="Create or replace the current health profile",
)
async def put_current_health_profile(
    payload: HealthProfileInputModel,
    principal: PrincipalDependency,
    container: ContainerDependency,
) -> HealthProfileResponse:
    profile = await container.users_service.put_health_profile(
        user_id=principal.user.id,
        expected_version=payload.expected_version,
        profile=payload.to_domain(),
    )
    return HealthProfileResponse.from_domain(profile)
