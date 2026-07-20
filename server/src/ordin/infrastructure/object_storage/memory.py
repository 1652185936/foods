import hashlib
from datetime import datetime
from urllib.parse import quote

from ordin.modules.recognition.errors import ObjectNotFoundError
from ordin.modules.recognition.models import PresignedUpload, StoredObject
from ordin.modules.recognition.service import checksum_header_value


class InMemoryObjectStorage:
    def __init__(self) -> None:
        self._objects: dict[str, tuple[bytes, str]] = {}

    async def create_presigned_upload(
        self,
        *,
        key: str,
        content_type: str,
        size_bytes: int,
        checksum_sha256: str,
        expires_at: datetime,
    ) -> PresignedUpload:
        return PresignedUpload(
            url=f"https://upload.test/{quote(key)}",
            required_headers={
                "Content-Type": content_type,
                "Content-Length": str(size_bytes),
                "x-amz-checksum-sha256": checksum_header_value(checksum_sha256),
            },
            expires_at=expires_at,
        )

    async def head(self, key: str) -> StoredObject:
        try:
            content, content_type = self._objects[key]
        except KeyError as error:
            raise ObjectNotFoundError from error
        return StoredObject(
            key=key,
            size_bytes=len(content),
            content_type=content_type,
            checksum_sha256=hashlib.sha256(content).hexdigest(),
        )

    async def read(self, key: str, *, max_bytes: int) -> bytes:
        try:
            content = self._objects[key][0]
        except KeyError as error:
            raise ObjectNotFoundError from error
        return content[: max_bytes + 1]

    async def write(self, *, key: str, content: bytes, content_type: str) -> StoredObject:
        self._objects[key] = (content, content_type)
        return await self.head(key)

    async def delete(self, key: str) -> None:
        self._objects.pop(key, None)

    async def ping(self) -> None:
        return None

    async def put_uploaded(self, *, key: str, content: bytes, content_type: str) -> None:
        self._objects[key] = (content, content_type)

    def get_for_test(self, key: str) -> tuple[bytes, str] | None:
        return self._objects.get(key)
