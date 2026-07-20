import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/features/meals/recognition/meal_image_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  test('camera is available only on Android and iOS', () {
    expect(
      ImagePickerMealImagePicker(
        picker: _MockImagePicker(),
        platform: TargetPlatform.android,
      ).supportsCamera,
      isTrue,
    );
    expect(
      ImagePickerMealImagePicker(
        picker: _MockImagePicker(),
        platform: TargetPlatform.iOS,
      ).supportsCamera,
      isTrue,
    );
    expect(
      ImagePickerMealImagePicker(
        picker: _MockImagePicker(),
        platform: TargetPlatform.windows,
      ).supportsCamera,
      isFalse,
    );
    expect(
      ImagePickerMealImagePicker(
        picker: _MockImagePicker(),
        platform: TargetPlatform.macOS,
      ).supportsCamera,
      isFalse,
    );
  });

  test('gallery cancellation is returned as a normal null result', () async {
    final picker = _MockImagePicker();
    when(
      () => picker.pickImage(source: ImageSource.gallery),
    ).thenAnswer((_) async => null);
    final adapter = ImagePickerMealImagePicker(
      picker: picker,
      platform: TargetPlatform.android,
    );

    expect(await adapter.pickFromGallery(), isNull);
  });

  test('Android recovers the first image from lost data', () async {
    final picker = _MockImagePicker();
    final file = _MockXFile();
    when(() => file.name).thenReturn('recovered.png');
    when(() => picker.retrieveLostData()).thenAnswer(
      (_) async => LostDataResponse(
        file: file,
        files: <XFile>[file],
        type: RetrieveType.image,
      ),
    );
    final adapter = ImagePickerMealImagePicker(
      picker: picker,
      platform: TargetPlatform.android,
    );

    final recovered = await adapter.recoverLostImage();

    expect(recovered, isNotNull);
    expect(recovered!.origin, MealImageOrigin.recovered);
    expect(recovered.file.name, 'recovered.png');
    verify(() => picker.retrieveLostData()).called(1);
  });

  test('lost-data permission errors are normalized', () async {
    final picker = _MockImagePicker();
    when(() => picker.retrieveLostData()).thenAnswer(
      (_) async => LostDataResponse(
        exception: PlatformException(code: 'photo_access_denied'),
      ),
    );
    final adapter = ImagePickerMealImagePicker(
      picker: picker,
      platform: TargetPlatform.android,
    );

    await expectLater(
      adapter.recoverLostImage(),
      throwsA(
        isA<MealImagePickerFailure>().having(
          (error) => error.kind,
          'kind',
          MealImagePickerFailureKind.permissionDenied,
        ),
      ),
    );
  });

  test('desktop skips Android lost-data retrieval', () async {
    final picker = _MockImagePicker();
    final adapter = ImagePickerMealImagePicker(
      picker: picker,
      platform: TargetPlatform.windows,
    );

    expect(await adapter.recoverLostImage(), isNull);
    verifyNever(() => picker.retrieveLostData());
  });
}

final class _MockImagePicker extends Mock implements ImagePicker {}

final class _MockXFile extends Mock implements XFile {}
