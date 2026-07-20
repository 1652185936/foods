class ApplicationError(Exception):
    code = "application_error"


class InvalidAuthenticationError(ApplicationError):
    code = "invalid_authentication"


class InvalidOtpError(ApplicationError):
    code = "invalid_otp"


class RateLimitExceededError(ApplicationError):
    code = "rate_limit_exceeded"

    def __init__(self, retry_after_seconds: int) -> None:
        super().__init__(self.code)
        self.retry_after_seconds = retry_after_seconds


class ResourceNotFoundError(ApplicationError):
    code = "resource_not_found"


class VersionConflictError(ApplicationError):
    code = "version_conflict"


class InvalidSyncOperationError(ApplicationError):
    code = "invalid_sync_operation"


class ServiceUnavailableError(ApplicationError):
    code = "service_unavailable"


class InvalidImageError(ApplicationError):
    code = "invalid_image"


class UploadStateConflictError(ApplicationError):
    code = "upload_state_conflict"


class IdempotencyConflictError(ApplicationError):
    code = "idempotency_conflict"


class InvalidRecognitionStateError(ApplicationError):
    code = "invalid_recognition_state"


class AccountExportTooLargeError(ApplicationError):
    code = "account_export_too_large"
