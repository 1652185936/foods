from fastapi import APIRouter, Response, status

from ordin.api.account_schemas import AccountDataExportResponse, AccountDeletionInput
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
    "/data-export",
    operation_id="exportCurrentUserData",
    response_model=AccountDataExportResponse,
    responses=problem_responses(401, 404, 413),
    summary="Export a bounded, consistent snapshot of the current user's data",
)
async def export_current_user_data(
    principal: PrincipalDependency,
    container: ContainerDependency,
) -> AccountDataExportResponse:
    snapshot = await container.accounts_service.export_data(user_id=principal.user.id)
    return AccountDataExportResponse.from_domain(snapshot)


@router.delete(
    "",
    operation_id="deleteCurrentUser",
    status_code=status.HTTP_204_NO_CONTENT,
    responses=problem_responses(401, 422),
    summary="Permanently delete the current account and all of its data",
)
async def delete_current_user(
    payload: AccountDeletionInput,
    principal: PrincipalDependency,
    container: ContainerDependency,
) -> Response:
    await container.accounts_service.delete_account(
        user_id=principal.user.id,
        session_id=principal.session_id,
        refresh_token=payload.refresh_token,
        device_installation_id=payload.device_installation_id,
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


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
