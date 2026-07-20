import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'meal_image_picker.dart';

const maxRecognitionImageBytes = 20 * 1024 * 1024;

enum MealImageContentType {
  jpeg('image/jpeg'),
  png('image/png'),
  webp('image/webp');

  const MealImageContentType(this.mimeType);

  final String mimeType;
}

final class PreparedMealImage {
  PreparedMealImage({
    required Uint8List bytes,
    required this.contentType,
    required this.checksumSha256,
    required this.origin,
  }) : bytes = Uint8List.fromList(bytes);

  final Uint8List bytes;
  final MealImageContentType contentType;
  final String checksumSha256;
  final MealImageOrigin origin;

  int get sizeBytes => bytes.length;
}

enum MealImageValidationFailureKind {
  empty,
  tooLarge,
  unsupportedFormat,
  changedWhileReading,
  unreadable,
}

final class MealImageValidationFailure implements Exception {
  const MealImageValidationFailure(this.kind, {this.cause});

  final MealImageValidationFailureKind kind;
  final Object? cause;
}

Future<PreparedMealImage> prepareMealImage(PickedMealImage picked) async {
  late final int declaredLength;
  try {
    declaredLength = await picked.file.length();
  } catch (error) {
    throw MealImageValidationFailure(
      MealImageValidationFailureKind.unreadable,
      cause: error,
    );
  }
  if (declaredLength <= 0) {
    throw const MealImageValidationFailure(
      MealImageValidationFailureKind.empty,
    );
  }
  if (declaredLength > maxRecognitionImageBytes) {
    throw const MealImageValidationFailure(
      MealImageValidationFailureKind.tooLarge,
    );
  }

  final builder = BytesBuilder(copy: false);
  try {
    await for (final chunk in picked.file.openRead(0, declaredLength)) {
      if (builder.length + chunk.length > maxRecognitionImageBytes) {
        throw const MealImageValidationFailure(
          MealImageValidationFailureKind.tooLarge,
        );
      }
      builder.add(chunk);
    }
  } on MealImageValidationFailure {
    rethrow;
  } catch (error) {
    throw MealImageValidationFailure(
      MealImageValidationFailureKind.unreadable,
      cause: error,
    );
  }
  final bytes = builder.takeBytes();
  if (bytes.length != declaredLength) {
    throw const MealImageValidationFailure(
      MealImageValidationFailureKind.changedWhileReading,
    );
  }
  final contentType = _detectContentType(bytes);
  if (contentType == null) {
    throw const MealImageValidationFailure(
      MealImageValidationFailureKind.unsupportedFormat,
    );
  }
  return PreparedMealImage(
    bytes: bytes,
    contentType: contentType,
    checksumSha256: sha256.convert(bytes).toString(),
    origin: picked.origin,
  );
}

MealImageContentType? _detectContentType(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return MealImageContentType.jpeg;
  }
  const pngSignature = <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  if (bytes.length >= pngSignature.length && _matches(bytes, 0, pngSignature)) {
    return MealImageContentType.png;
  }
  if (bytes.length >= 12 &&
      _matches(bytes, 0, const <int>[0x52, 0x49, 0x46, 0x46]) &&
      _matches(bytes, 8, const <int>[0x57, 0x45, 0x42, 0x50])) {
    return MealImageContentType.webp;
  }
  return null;
}

bool _matches(Uint8List bytes, int offset, List<int> expected) {
  for (var index = 0; index < expected.length; index++) {
    if (bytes[offset + index] != expected[index]) {
      return false;
    }
  }
  return true;
}
