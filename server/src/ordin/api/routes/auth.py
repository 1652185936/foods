from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Header, Path, Request, Response, status

from ordin.api.dependencies import ContainerDependency, PrincipalDependency
from ordin.api.errors import problem_responses
from ordin.api.schemas import (
    AuthSessionResponse,
    OtpChallengeInput,
    OtpChallengeResponse,
    OtpVerificationInput,
    RefreshTokenInput,
    TokenPairResponse,
    UserResponse,
)
from ordin.modules.auth.models import DeviceRegistration

router = APIRouter(prefix="/auth", tags=["authentication"])


@router.post(
    "/otp/challenges",
    operation_id="createOtpChallenge",
    response_model=OtpChallengeResponse,
    status_code=status.HTTP_202_ACCEPTED,
    responses=problem_responses(422, 429, 503),
    summary="Request a sign-in code",
)
async def create_otp_challenge(
    payload: OtpChallengeInput,
    request: Request,
    container: ContainerDependency,
    idempotency_key: Annotated[
        str | None,
        Header(alias="Idempotency-Key", min_length=8, max_length=128),
    ] = None,
) -> OtpChallengeResponse:
    remote_address = request.client.host if request.client is not None else "unknown"
    challenge = await container.auth_service.request_otp(
        phone_number=payload.phone_number,
        device_installation_id=payload.device_installation_id,
        remote_address=remote_address,
        idempotency_key=idempotency_key,
    )
    return OtpChallengeResponse(
        challenge_id=challenge.id,
        expires_at=challenge.expires_at,
        resend_after_seconds=container.settings.otp_resend_after_seconds,
    )


@router.post(
    "/otp/challenges/{challengeId}/verify",
    operation_id="verifyOtpChallenge",
    response_model=AuthSessionResponse,
    responses=problem_responses(401, 422, 503),
    summary="Verify a sign-in code",
)
async def verify_otp_challenge(
    challenge_id: Annotated[UUID, Path(alias="challengeId")],
    payload: OtpVerificationInput,
    container: ContainerDependency,
) -> AuthSessionResponse:
    tokens, user = await container.auth_service.verify_otp(
        challenge_id=challenge_id,
        code=payload.code,
        device=DeviceRegistration(
            installation_id=payload.device.installation_id,
            platform=payload.device.platform,
            app_version=payload.device.app_version,
        ),
    )
    return AuthSessionResponse(
        tokens=TokenPairResponse.from_domain(tokens),
        user=UserResponse.from_domain(user),
    )


@router.post(
    "/token/refresh",
    operation_id="refreshAuthToken",
    response_model=TokenPairResponse,
    responses=problem_responses(401, 422),
    summary="Rotate a refresh token",
)
async def refresh_auth_token(
    payload: RefreshTokenInput,
    container: ContainerDependency,
) -> TokenPairResponse:
    tokens = await container.auth_service.refresh(
        refresh_token=payload.refresh_token,
        device_installation_id=payload.device_installation_id,
    )
    return TokenPairResponse.from_domain(tokens)


@router.delete(
    "/sessions/current",
    operation_id="deleteCurrentSession",
    status_code=status.HTTP_204_NO_CONTENT,
    response_class=Response,
    responses=problem_responses(401),
    summary="Sign out the current session",
)
async def delete_current_session(
    principal: PrincipalDependency,
    container: ContainerDependency,
) -> Response:
    await container.auth_service.logout(
        user_id=principal.user.id,
        session_id=principal.session_id,
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)
