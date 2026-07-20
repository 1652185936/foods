import hashlib
import warnings
from io import BytesIO

from PIL import Image, ImageOps, UnidentifiedImageError

from ordin.modules.recognition.errors import InvalidImageContentError
from ordin.modules.recognition.models import ProcessedImage

_MIME_BY_FORMAT = {
    "JPEG": "image/jpeg",
    "PNG": "image/png",
    "WEBP": "image/webp",
}
_EXTENSION_BY_FORMAT = {"JPEG": "jpg", "PNG": "png", "WEBP": "webp"}


class PillowImageProcessor:
    def sanitize(
        self,
        *,
        content: bytes,
        declared_content_type: str,
        max_pixels: int,
    ) -> ProcessedImage:
        detected_content_type = _detect_magic(content)
        if detected_content_type != declared_content_type:
            raise InvalidImageContentError("file signature does not match the declared MIME type")

        try:
            with warnings.catch_warnings():
                warnings.simplefilter("error", Image.DecompressionBombWarning)
                with Image.open(BytesIO(content)) as probe:
                    image_format = probe.format
                    width, height = probe.size
                    if image_format not in _MIME_BY_FORMAT:
                        raise InvalidImageContentError("unsupported decoded image format")
                    if _MIME_BY_FORMAT[image_format] != declared_content_type:
                        raise InvalidImageContentError(
                            "decoded format does not match the MIME type"
                        )
                    if width <= 0 or height <= 0 or width * height > max_pixels:
                        raise InvalidImageContentError(
                            "image dimensions exceed the accepted bounds"
                        )
                    if getattr(probe, "n_frames", 1) != 1:
                        raise InvalidImageContentError("animated images are not accepted")
                    probe.verify()

                with Image.open(BytesIO(content)) as decoded:
                    decoded.load()
                    oriented = ImageOps.exif_transpose(decoded)
                    sanitized = _copy_safe_pixels(oriented, image_format)
                    sanitized_width, sanitized_height = sanitized.size
                    output = BytesIO()
                    _save_without_metadata(sanitized, output, image_format)
                    sanitized.close()
        except InvalidImageContentError:
            raise
        except (Image.DecompressionBombError, Image.DecompressionBombWarning) as error:
            raise InvalidImageContentError(
                "decompression bomb protection rejected the image"
            ) from error
        except (OSError, SyntaxError, UnidentifiedImageError, ValueError) as error:
            raise InvalidImageContentError("image decoding failed") from error

        result = output.getvalue()
        if not result:
            raise InvalidImageContentError("sanitized image is empty")
        return ProcessedImage(
            content=result,
            content_type=_MIME_BY_FORMAT[image_format],
            extension=_EXTENSION_BY_FORMAT[image_format],
            checksum_sha256=hashlib.sha256(result).hexdigest(),
            width=sanitized_width,
            height=sanitized_height,
        )


def _detect_magic(content: bytes) -> str:
    if content.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if content.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if len(content) >= 12 and content[:4] == b"RIFF" and content[8:12] == b"WEBP":
        return "image/webp"
    raise InvalidImageContentError("unsupported file signature")


def _copy_safe_pixels(image: Image.Image, image_format: str) -> Image.Image:
    if image_format == "JPEG":
        return image.convert("RGB")
    if image.mode in {"RGBA", "LA"} or "transparency" in image.info:
        return image.convert("RGBA")
    return image.convert("RGB")


def _save_without_metadata(image: Image.Image, output: BytesIO, image_format: str) -> None:
    if image_format == "JPEG":
        image.save(output, format="JPEG", quality=90, optimize=True)
    elif image_format == "PNG":
        image.save(output, format="PNG", optimize=True)
    else:
        image.save(output, format="WEBP", quality=90, method=4)
