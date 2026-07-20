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


class ServiceUnavailableError(ApplicationError):
    code = "service_unavailable"
