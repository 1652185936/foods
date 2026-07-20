from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Header, Path, status

from ordin.api.dependencies import ContainerDependency, PrincipalDependency
from ordin.api.errors import problem_responses
from ordin.api.recognition_schemas import (
    CompletedRecognitionUploadResponse,
    RecognitionCorrectionInput,
    RecognitionCreateInput,
    RecognitionResponse,
    RecognitionUploadInput,
    RecognitionUploadResponse,
)

router = APIRouter(tags=["recognition"])


@router.post(
    "/recognition-uploads",
    operation_id="createRecognitionUpload",
    response_model=RecognitionUploadResponse,
    status_code=status.HTTP_201_CREATED,
    responses=problem_responses(401, 422, 503),
    summary="Create a short-lived direct image upload",
)
async def create_recognition_upload(
    payload: RecognitionUploadInput,
    principal: PrincipalDependency,
    container: ContainerDependency,
) -> RecognitionUploadResponse:
    upload, signed = await container.recognition_service.create_upload(
        user_id=principal.user.id,
        content_type=payload.content_type,
        size_bytes=payload.size_bytes,
        checksum_sha256=payload.checksum_sha256,
    )
    return RecognitionUploadResponse(
        upload_session_id=upload.id,
        object_key=upload.incoming_object_key,
        status=upload.status.value,
        upload_url=signed.url,
        upload_headers=signed.required_headers,
        expires_at=signed.expires_at,
    )


@router.post(
    "/recognition-uploads/{uploadSessionId}/complete",
    operation_id="completeRecognitionUpload",
    response_model=CompletedRecognitionUploadResponse,
    responses=problem_responses(401, 404, 409, 422, 503),
    summary="Validate, decode, and sanitize an uploaded image",
)
async def complete_recognition_upload(
    upload_session_id: Annotated[UUID, Path(alias="uploadSessionId")],
    principal: PrincipalDependency,
    container: ContainerDependency,
) -> CompletedRecognitionUploadResponse:
    upload = await container.recognition_service.complete_upload(
        user_id=principal.user.id,
        upload_id=upload_session_id,
    )
    return CompletedRecognitionUploadResponse.from_domain(upload)


@router.post(
    "/recognitions",
    operation_id="createRecognition",
    response_model=RecognitionResponse,
    status_code=status.HTTP_202_ACCEPTED,
    responses=problem_responses(401, 409, 422, 503),
    summary="Queue food recognition for a sanitized upload",
)
async def create_recognition(
    payload: RecognitionCreateInput,
    principal: PrincipalDependency,
    container: ContainerDependency,
    idempotency_key: Annotated[
        str,
        Header(alias="Idempotency-Key", min_length=8, max_length=128),
    ],
) -> RecognitionResponse:
    result = await container.recognition_service.create_recognition(
        user_id=principal.user.id,
        upload_id=payload.upload_session_id,
        idempotency_key=idempotency_key,
    )
    return RecognitionResponse.from_domain(result.job)


@router.get(
    "/recognitions/{recognitionId}",
    operation_id="getRecognition",
    response_model=RecognitionResponse,
    responses=problem_responses(401, 404, 422),
    summary="Get a food-recognition task and its structured candidates",
)
async def get_recognition(
    recognition_id: Annotated[UUID, Path(alias="recognitionId")],
    principal: PrincipalDependency,
    container: ContainerDependency,
) -> RecognitionResponse:
    job = await container.recognition_service.get_recognition(
        user_id=principal.user.id,
        job_id=recognition_id,
    )
    return RecognitionResponse.from_domain(job)


@router.put(
    "/recognitions/{recognitionId}/correction",
    operation_id="correctRecognition",
    response_model=RecognitionResponse,
    responses=problem_responses(401, 404, 409, 422),
    summary="Replace recognition candidates with a user-reviewed result",
)
async def correct_recognition(
    recognition_id: Annotated[UUID, Path(alias="recognitionId")],
    payload: RecognitionCorrectionInput,
    principal: PrincipalDependency,
    container: ContainerDependency,
) -> RecognitionResponse:
    job = await container.recognition_service.correct_recognition(
        user_id=principal.user.id,
        job_id=recognition_id,
        expected_version=payload.expected_version,
        items=tuple(item.to_domain() for item in payload.items),
    )
    return RecognitionResponse.from_domain(job)
