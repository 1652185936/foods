import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/features/meals/recognition/meal_image_picker.dart';
import 'package:foods_client/features/meals/recognition/meal_image_preparer.dart';

void main() {
  group('prepareMealImage', () {
    for (final scenario in <({List<int> bytes, MealImageContentType type})>[
      (
        bytes: const <int>[0xff, 0xd8, 0xff, 0x00, 0x01],
        type: MealImageContentType.jpeg,
      ),
      (
        bytes: const <int>[
          0x89,
          0x50,
          0x4e,
          0x47,
          0x0d,
          0x0a,
          0x1a,
          0x0a,
          0x00,
        ],
        type: MealImageContentType.png,
      ),
      (
        bytes: const <int>[
          0x52,
          0x49,
          0x46,
          0x46,
          0x04,
          0x00,
          0x00,
          0x00,
          0x57,
          0x45,
          0x42,
          0x50,
        ],
        type: MealImageContentType.webp,
      ),
    ]) {
      test('detects ${scenario.type.mimeType} by magic bytes', () async {
        final prepared = await prepareMealImage(
          _picked(_FakeMealImageFile(scenario.bytes)),
        );

        expect(prepared.contentType, scenario.type);
        expect(prepared.bytes, scenario.bytes);
        expect(prepared.sizeBytes, scenario.bytes.length);
      });
    }

    test('computes the SHA-256 of the exact uploaded bytes', () async {
      final prepared = await prepareMealImage(
        _picked(_FakeMealImageFile(const <int>[0xff, 0xd8, 0xff, 0x00, 0x01])),
      );

      expect(
        prepared.checksumSha256,
        '6c13f379ff513a750741206db9e93afd6a6b8bf688c5766d74384b5ab07e87fb',
      );
    });

    test('rejects a declared image over 20 MiB without reading it', () async {
      final file = _FakeMealImageFile(const <int>[
        0xff,
        0xd8,
        0xff,
      ], declaredLength: maxRecognitionImageBytes + 1);

      await expectLater(
        prepareMealImage(_picked(file)),
        throwsA(
          isA<MealImageValidationFailure>().having(
            (error) => error.kind,
            'kind',
            MealImageValidationFailureKind.tooLarge,
          ),
        ),
      );
      expect(file.openReadCalls, 0);
    });

    test('rejects unsupported magic even when the name says jpg', () async {
      await expectLater(
        prepareMealImage(
          _picked(_FakeMealImageFile(const <int>[1, 2, 3], name: 'meal.jpg')),
        ),
        throwsA(
          isA<MealImageValidationFailure>().having(
            (error) => error.kind,
            'kind',
            MealImageValidationFailureKind.unsupportedFormat,
          ),
        ),
      );
    });

    test('rejects files that change length while being read', () async {
      await expectLater(
        prepareMealImage(
          _picked(
            _FakeMealImageFile(const <int>[
              0xff,
              0xd8,
              0xff,
            ], declaredLength: 4),
          ),
        ),
        throwsA(
          isA<MealImageValidationFailure>().having(
            (error) => error.kind,
            'kind',
            MealImageValidationFailureKind.changedWhileReading,
          ),
        ),
      );
    });
  });
}

PickedMealImage _picked(MealImageFile file) =>
    PickedMealImage(file: file, origin: MealImageOrigin.gallery);

final class _FakeMealImageFile implements MealImageFile {
  _FakeMealImageFile(
    List<int> bytes, {
    this.name = 'meal.bin',
    int? declaredLength,
  }) : _bytes = Uint8List.fromList(bytes),
       _declaredLength = declaredLength ?? bytes.length;

  final Uint8List _bytes;
  final int _declaredLength;
  int openReadCalls = 0;

  @override
  final String name;

  @override
  Future<int> length() async => _declaredLength;

  @override
  Stream<List<int>> openRead(int start, int end) {
    openReadCalls++;
    return Stream<List<int>>.value(
      _bytes.sublist(start, end.clamp(0, _bytes.length)),
    );
  }
}
