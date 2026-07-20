from __future__ import annotations

import asyncio
import base64
import hashlib
from datetime import datetime
from typing import TYPE_CHECKING, Any, cast

import boto3
from botocore.client import Config
from botocore.exceptions import BotoCoreError, ClientError

if TYPE_CHECKING:
    from mypy_boto3_s3 import S3Client

from ordin.modules.recognition.errors import (
    InvalidImageContentError,
    ObjectNotFoundError,
    ObjectStorageUnavailableError,
)
from ordin.modules.recognition.models import PresignedUpload, StoredObject
from ordin.modules.recognition.service import checksum_header_value


def build_s3_client(
    *,
    endpoint_url: str,
    region: str,
    access_key_id: str,
    secret_access_key: str,
    force_path_style: bool,
) -> S3Client:
    return boto3.client(
        "s3",
        endpoint_url=endpoint_url,
        region_name=region,
        aws_access_key_id=access_key_id,
        aws_secret_access_key=secret_access_key,
        config=Config(
            signature_version="s3v4",
            s3={"addressing_style": "path" if force_path_style else "virtual"},
        ),
    )


class S3ObjectStorage:
    def __init__(
        self,
        client: S3Client,
        *,
        bucket: str,
        presign_client: S3Client | None = None,
    ) -> None:
        self._client = client
        self._presign_client = presign_client or client
        self._bucket = bucket

    async def create_presigned_upload(
        self,
        *,
        key: str,
        content_type: str,
        size_bytes: int,
        checksum_sha256: str,
        expires_at: datetime,
    ) -> PresignedUpload:
        expires_in = max(1, int((expires_at - datetime.now(expires_at.tzinfo)).total_seconds()))
        checksum = checksum_header_value(checksum_sha256)

        def generate() -> str:
            try:
                return self._presign_client.generate_presigned_url(
                    "put_object",
                    Params={
                        "Bucket": self._bucket,
                        "Key": key,
                        "ContentType": content_type,
                        "ContentLength": size_bytes,
                        "ChecksumSHA256": checksum,
                    },
                    ExpiresIn=expires_in,
                    HttpMethod="PUT",
                )
            except (BotoCoreError, ClientError, ValueError) as error:
                raise ObjectStorageUnavailableError from error

        url = await asyncio.to_thread(generate)
        return PresignedUpload(
            url=url,
            required_headers={
                "Content-Type": content_type,
                "Content-Length": str(size_bytes),
                "x-amz-checksum-sha256": checksum,
            },
            expires_at=expires_at,
        )

    async def head(self, key: str) -> StoredObject:
        return await asyncio.to_thread(self._head, key)

    async def read(self, key: str, *, max_bytes: int) -> bytes:
        return await asyncio.to_thread(self._read, key, max_bytes)

    async def write(self, *, key: str, content: bytes, content_type: str) -> StoredObject:
        return await asyncio.to_thread(self._write, key, content, content_type)

    async def delete(self, key: str) -> None:
        await asyncio.to_thread(self._delete, key)

    async def ping(self) -> None:
        try:
            await asyncio.to_thread(self._client.head_bucket, Bucket=self._bucket)
        except (BotoCoreError, ClientError) as error:
            raise ObjectStorageUnavailableError from error

    def _head(self, key: str) -> StoredObject:
        try:
            response = self._client.head_object(
                Bucket=self._bucket, Key=key, ChecksumMode="ENABLED"
            )
        except ClientError as error:
            _raise_client_error(error)
        except BotoCoreError as error:
            raise ObjectStorageUnavailableError from error
        return _metadata(key, cast(dict[str, Any], response))

    def _read(self, key: str, max_bytes: int) -> bytes:
        body: Any = None
        try:
            response = self._client.get_object(Bucket=self._bucket, Key=key)
            body = response["Body"]
            content = cast(bytes, body.read(max_bytes + 1))
        except ClientError as error:
            _raise_client_error(error)
        except BotoCoreError as error:
            raise ObjectStorageUnavailableError from error
        finally:
            if body is not None:
                body.close()
        if len(content) > max_bytes:
            raise InvalidImageContentError("object exceeds the configured maximum")
        return content

    def _write(self, key: str, content: bytes, content_type: str) -> StoredObject:
        checksum = hashlib.sha256(content).digest()
        try:
            self._client.put_object(
                Bucket=self._bucket,
                Key=key,
                Body=content,
                ContentLength=len(content),
                ContentType=content_type,
                ChecksumSHA256=base64.b64encode(checksum).decode("ascii"),
            )
        except (BotoCoreError, ClientError) as error:
            raise ObjectStorageUnavailableError from error
        return StoredObject(
            key=key,
            size_bytes=len(content),
            content_type=content_type,
            checksum_sha256=checksum.hex(),
        )

    def _delete(self, key: str) -> None:
        try:
            self._client.delete_object(Bucket=self._bucket, Key=key)
        except (BotoCoreError, ClientError) as error:
            raise ObjectStorageUnavailableError from error


class S3SyncObjectStorage:
    def __init__(self, client: S3Client, *, bucket: str) -> None:
        self._storage = S3ObjectStorage(client, bucket=bucket)

    def read(self, key: str, *, max_bytes: int) -> bytes:
        return self._storage._read(key, max_bytes)

    def delete(self, key: str) -> None:
        self._storage._delete(key)


def _metadata(key: str, response: dict[str, Any]) -> StoredObject:
    checksum_base64 = response.get("ChecksumSHA256")
    checksum = base64.b64decode(checksum_base64).hex() if isinstance(checksum_base64, str) else None
    return StoredObject(
        key=key,
        size_bytes=int(response["ContentLength"]),
        content_type=str(response.get("ContentType", "application/octet-stream")),
        checksum_sha256=checksum,
    )


def _raise_client_error(error: ClientError) -> None:
    code = str(error.response.get("Error", {}).get("Code", ""))
    if code in {"404", "NoSuchKey", "NotFound"}:
        raise ObjectNotFoundError from error
    raise ObjectStorageUnavailableError from error
