class RecognitionInfrastructureError(Exception):
    """Base class for adapter failures that must not leak provider details."""


class ObjectNotFoundError(RecognitionInfrastructureError):
    pass


class ObjectStorageUnavailableError(RecognitionInfrastructureError):
    pass


class InvalidImageContentError(RecognitionInfrastructureError):
    pass


class ProviderTemporaryError(RecognitionInfrastructureError):
    pass


class ProviderPermanentError(RecognitionInfrastructureError):
    pass
