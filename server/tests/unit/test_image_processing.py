from io import BytesIO

import pytest
from PIL import Image, PngImagePlugin

from ordin.infrastructure.image_processing import PillowImageProcessor
from ordin.modules.recognition.errors import InvalidImageContentError


def test_jpeg_is_reencoded_without_exif_metadata() -> None:
    source = BytesIO()
    exif = Image.Exif()
    exif[0x010E] = "private description"
    with Image.new("RGB", (16, 12), color=(200, 30, 20)) as image:
        image.save(source, format="JPEG", exif=exif)

    result = PillowImageProcessor().sanitize(
        content=source.getvalue(),
        declared_content_type="image/jpeg",
        max_pixels=1_000,
    )

    assert result.content_type == "image/jpeg"
    assert (result.width, result.height) == (16, 12)
    with Image.open(BytesIO(result.content)) as sanitized:
        assert not sanitized.getexif()
        assert "exif" not in sanitized.info
        sanitized.load()


def test_reported_dimensions_follow_exif_orientation() -> None:
    source = BytesIO()
    exif = Image.Exif()
    exif[0x0112] = 6
    with Image.new("RGB", (16, 12), color=(200, 30, 20)) as image:
        image.save(source, format="JPEG", exif=exif)

    result = PillowImageProcessor().sanitize(
        content=source.getvalue(),
        declared_content_type="image/jpeg",
        max_pixels=1_000,
    )

    assert (result.width, result.height) == (12, 16)
    with Image.open(BytesIO(result.content)) as sanitized:
        assert sanitized.size == (12, 16)


def test_png_text_metadata_is_removed() -> None:
    source = BytesIO()
    metadata = PngImagePlugin.PngInfo()
    metadata.add_text("Location", "private")
    with Image.new("RGBA", (8, 8), color=(1, 2, 3, 128)) as image:
        image.save(source, format="PNG", pnginfo=metadata)

    result = PillowImageProcessor().sanitize(
        content=source.getvalue(),
        declared_content_type="image/png",
        max_pixels=1_000,
    )

    with Image.open(BytesIO(result.content)) as sanitized:
        assert "Location" not in sanitized.info


def test_magic_mime_and_pixel_bounds_are_enforced() -> None:
    with pytest.raises(InvalidImageContentError):
        PillowImageProcessor().sanitize(
            content=b"not an image",
            declared_content_type="image/jpeg",
            max_pixels=1_000,
        )

    source = BytesIO()
    with Image.new("RGB", (40, 40)) as image:
        image.save(source, format="PNG")
    with pytest.raises(InvalidImageContentError):
        PillowImageProcessor().sanitize(
            content=source.getvalue(),
            declared_content_type="image/png",
            max_pixels=1_000,
        )
