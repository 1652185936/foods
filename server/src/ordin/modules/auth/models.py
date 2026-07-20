from dataclasses import dataclass
from datetime import datetime
from enum import StrEnum
from uuid import UUID


class ClientPlatform(StrEnum):
    ANDROID = "android"
    IOS = "ios"
    WINDOWS = "windows"
    MACOS = "macos"


@dataclass(frozen=True, slots=True)
class DeviceRegistration:
    installation_id: UUID
    platform: ClientPlatform
    app_version: str


@dataclass(frozen=True, slots=True)
class OtpChallenge:
    id: UUID
    identity_subject_hash: str
    code_digest: str
    created_at: datetime
    expires_at: datetime
    max_attempts: int


class OtpVerificationStatus(StrEnum):
    VERIFIED = "verified"
    INVALID = "invalid"
    EXPIRED = "expired"
    ATTEMPTS_EXHAUSTED = "attempts_exhausted"


@dataclass(frozen=True, slots=True)
class OtpVerification:
    status: OtpVerificationStatus
    identity_subject_hash: str | None = None


@dataclass(frozen=True, slots=True)
class AuthenticatedSession:
    user_id: UUID
    session_id: UUID
    refresh_expires_at: datetime


class RefreshRotationStatus(StrEnum):
    ROTATED = "rotated"
    INVALID = "invalid"
    REUSED = "reused"


@dataclass(frozen=True, slots=True)
class RefreshRotation:
    status: RefreshRotationStatus
    session: AuthenticatedSession | None = None


@dataclass(frozen=True, slots=True)
class AccessClaims:
    user_id: UUID
    session_id: UUID
    expires_at: datetime


@dataclass(frozen=True, slots=True)
class TokenPair:
    access_token: str
    access_expires_at: datetime
    refresh_token: str
    refresh_expires_at: datetime
