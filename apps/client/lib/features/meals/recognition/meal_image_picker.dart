import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

enum MealImageOrigin { camera, gallery, recovered }

abstract interface class MealImageFile {
  String get name;

  Future<int> length();

  Stream<List<int>> openRead(int start, int end);
}

final class XFileMealImage implements MealImageFile {
  const XFileMealImage(this.file);

  final XFile file;

  @override
  String get name => file.name;

  @override
  Future<int> length() => file.length();

  @override
  Stream<List<int>> openRead(int start, int end) => file.openRead(start, end);
}

final class PickedMealImage {
  const PickedMealImage({required this.file, required this.origin});

  final MealImageFile file;
  final MealImageOrigin origin;
}

enum MealImagePickerFailureKind { permissionDenied, unavailable, platform }

final class MealImagePickerFailure implements Exception {
  const MealImagePickerFailure(this.kind, {this.cause});

  final MealImagePickerFailureKind kind;
  final Object? cause;
}

abstract interface class MealImagePicker {
  bool get supportsCamera;

  Future<PickedMealImage?> pickFromCamera();

  Future<PickedMealImage?> pickFromGallery();

  Future<PickedMealImage?> recoverLostImage();
}

final class ImagePickerMealImagePicker implements MealImagePicker {
  ImagePickerMealImagePicker({ImagePicker? picker, TargetPlatform? platform})
    : _picker = picker ?? ImagePicker(),
      _platform = platform ?? defaultTargetPlatform;

  final ImagePicker _picker;
  final TargetPlatform _platform;

  @override
  bool get supportsCamera =>
      !kIsWeb &&
      (_platform == TargetPlatform.android || _platform == TargetPlatform.iOS);

  @override
  Future<PickedMealImage?> pickFromCamera() async {
    if (!supportsCamera) {
      throw const MealImagePickerFailure(
        MealImagePickerFailureKind.unavailable,
      );
    }
    return _pick(ImageSource.camera, MealImageOrigin.camera);
  }

  @override
  Future<PickedMealImage?> pickFromGallery() =>
      _pick(ImageSource.gallery, MealImageOrigin.gallery);

  @override
  Future<PickedMealImage?> recoverLostImage() async {
    if (kIsWeb || _platform != TargetPlatform.android) {
      return null;
    }
    try {
      final response = await _picker.retrieveLostData();
      final exception = response.exception;
      if (exception != null) {
        throw _mapPlatformFailure(exception);
      }
      final files = response.files;
      if (files == null || files.isEmpty) {
        return null;
      }
      return PickedMealImage(
        file: XFileMealImage(files.first),
        origin: MealImageOrigin.recovered,
      );
    } on MealImagePickerFailure {
      rethrow;
    } on PlatformException catch (error) {
      throw _mapPlatformFailure(error);
    } catch (error) {
      throw MealImagePickerFailure(
        MealImagePickerFailureKind.platform,
        cause: error,
      );
    }
  }

  Future<PickedMealImage?> _pick(
    ImageSource source,
    MealImageOrigin origin,
  ) async {
    try {
      final file = await _picker.pickImage(source: source);
      if (file == null) {
        return null;
      }
      return PickedMealImage(file: XFileMealImage(file), origin: origin);
    } on PlatformException catch (error) {
      throw _mapPlatformFailure(error);
    } catch (error) {
      throw MealImagePickerFailure(
        MealImagePickerFailureKind.platform,
        cause: error,
      );
    }
  }

  MealImagePickerFailure _mapPlatformFailure(PlatformException error) {
    final code = error.code.toLowerCase();
    final denied = code.contains('denied') || code.contains('permission');
    return MealImagePickerFailure(
      denied
          ? MealImagePickerFailureKind.permissionDenied
          : MealImagePickerFailureKind.platform,
      cause: error,
    );
  }
}
