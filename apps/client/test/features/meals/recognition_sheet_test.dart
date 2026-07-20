import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/features/meals/domain/meal_log.dart';
import 'package:foods_client/features/meals/presentation/recognition_sheet.dart';
import 'package:foods_client/features/meals/recognition/meal_image_picker.dart';
import 'package:foods_client/features/meals/recognition/meal_image_preparer.dart';
import 'package:foods_client/features/meals/recognition/recognition_models.dart';
import 'package:foods_client/features/meals/recognition/recognition_providers.dart';
import 'package:foods_client/features/meals/recognition/recognition_service.dart';

void main() {
  testWidgets('cancel closes the source step immediately', (tester) async {
    await _pumpHarness(tester, picker: _FakePicker());

    await tester.tap(find.byKey(const Key('open-flow')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recognition-sheet')), findsOneWidget);

    await tester.tap(find.byKey(const Key('recognition-cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recognition-sheet')), findsNothing);
  });

  testWidgets(
    'picker cancellation stays recoverable and manual fallback opens',
    (tester) async {
      await _pumpHarness(tester, picker: _FakePicker());
      await tester.tap(find.byKey(const Key('open-flow')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('recognition-gallery')));
      await tester.pumpAndSettle();

      expect(find.text('未选择照片，你可以重新选择或手动记录'), findsOneWidget);
      await tester.tap(find.byKey(const Key('recognition-manual')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('recognition-sheet')), findsNothing);
      expect(find.byKey(const Key('manual-meal-save')), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const Key('manual-meal-name')),
                matching: find.byType(TextField),
              ),
            )
            .maxLength,
        maxMealItemNameLength,
      );
    },
  );

  testWidgets('busy recognition remains cancellable', (tester) async {
    final remote = _FakeRemote(blockUploadUntilCancelled: true);
    await _pumpHarness(
      tester,
      picker: _FakePicker(image: _pickedImage()),
      remote: remote,
    );
    await tester.tap(find.byKey(const Key('open-flow')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('recognition-gallery')));
    await tester.pump();
    expect(find.byKey(const Key('recognition-running')), findsOneWidget);

    final cancel = find.byKey(const Key('recognition-cancel'));
    await tester.ensureVisible(cancel);
    await tester.pump();
    await tester.tap(cancel);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recognition-sheet')), findsNothing);
    expect(remote.uploadCancelled, isTrue);
  });

  testWidgets(
    'low-confidence multi-dish result requires review and correction',
    (tester) async {
      final remote = _FakeRemote(result: _reviewJob());
      MealDraft? savedDraft;
      await _pumpHarness(
        tester,
        picker: _FakePicker(image: _pickedImage()),
        remote: remote,
        onResult: (draft) => savedDraft = draft,
      );
      await tester.tap(find.byKey(const Key('open-flow')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('recognition-gallery')));
      await tester.pumpAndSettle();

      expect(find.text('2 道菜'), findsOneWidget);
      expect(find.text('识别把握较低，请逐项核对后再保存。'), findsOneWidget);
      final confirm = tester.widget<FilledButton>(
        find.byKey(const Key('recognition-confirm')),
      );
      expect(confirm.onPressed, isNull);

      final name = find.byKey(const Key('recognition-item-0-name'));
      await tester.ensureVisible(name);
      await tester.enterText(name, '番茄炒蛋（少油）');
      final checkbox = find.byKey(const Key('recognition-review-confirmed'));
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      final enabledConfirm = find.byKey(const Key('recognition-confirm'));
      expect(tester.widget<FilledButton>(enabledConfirm).onPressed, isNotNull);
      await tester.ensureVisible(enabledConfirm);
      await tester.pumpAndSettle();
      await tester.tap(enabledConfirm);
      await tester.pumpAndSettle();

      expect(remote.correctedDishes, hasLength(2));
      expect(remote.correctedDishes!.first.name, '番茄炒蛋（少油）');
      expect(remote.correctedDishes!.first.canonicalFoodId, isNull);
      expect(savedDraft, isNotNull);
      expect(savedDraft!.items, hasLength(2));
      expect(
        savedDraft!.items.every((item) => item.imageReference == null),
        isTrue,
      );
      expect(savedDraft!.source, MealSource.recognition);
    },
  );
}

Future<void> _pumpHarness(
  WidgetTester tester, {
  required MealImagePicker picker,
  _FakeRemote? remote,
  ValueChanged<MealDraft?>? onResult,
}) async {
  final service = MealRecognitionService(
    remote: remote ?? _FakeRemote(),
    pollInterval: Duration.zero,
    delay: (_, cancellation) async => cancellation.throwIfCancelled(),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mealImagePickerProvider.overrideWithValue(picker),
        mealRecognitionServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(home: _Harness(onResult: onResult)),
    ),
  );
}

class _Harness extends StatelessWidget {
  const _Harness({this.onResult});

  final ValueChanged<MealDraft?>? onResult;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        key: const Key('open-flow'),
        onPressed: () async {
          final result = await showRecognitionFlow(
            context,
            nowUtc: DateTime.utc(2026, 7, 21, 4),
            timeZoneId: 'Asia/Shanghai',
            isWithinEatingWindow: true,
          );
          onResult?.call(result);
        },
        child: const Text('开始识别'),
      ),
    ),
  );
}

final class _FakePicker implements MealImagePicker {
  const _FakePicker({this.image});

  final PickedMealImage? image;

  @override
  bool get supportsCamera => false;

  @override
  Future<PickedMealImage?> pickFromCamera() async => image;

  @override
  Future<PickedMealImage?> pickFromGallery() async => image;

  @override
  Future<PickedMealImage?> recoverLostImage() async => null;
}

final class _MemoryImageFile implements MealImageFile {
  const _MemoryImageFile(this.bytes);

  final Uint8List bytes;

  @override
  String get name => 'meal.png';

  @override
  Future<int> length() async => bytes.length;

  @override
  Stream<List<int>> openRead(int start, int end) =>
      Stream<List<int>>.value(bytes.sublist(start, end));
}

PickedMealImage _pickedImage() {
  final bytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );
  return PickedMealImage(
    file: _MemoryImageFile(bytes),
    origin: MealImageOrigin.gallery,
  );
}

final class _FakeRemote implements RecognitionRemoteGateway {
  _FakeRemote({
    RecognitionJobData? result,
    this.blockUploadUntilCancelled = false,
  }) : result = result ?? _successJob();

  final RecognitionJobData result;
  final bool blockUploadUntilCancelled;
  bool uploadCancelled = false;
  List<RecognitionDishData>? correctedDishes;

  @override
  Future<void> completeUpload(String uploadSessionId) async {}

  @override
  Future<RecognitionJobData> correctRecognition({
    required String recognitionId,
    required int expectedVersion,
    required List<RecognitionDishData> dishes,
  }) async {
    correctedDishes = dishes;
    return RecognitionJobData(
      id: recognitionId,
      status: 'succeeded',
      version: expectedVersion + 1,
      dishes: dishes,
    );
  }

  @override
  Future<RecognitionUploadTicket> createUpload(PreparedMealImage image) async =>
      RecognitionUploadTicket(
        uploadSessionId: 'upload-1',
        uploadUri: Uri.parse('https://uploads.example.test/object'),
        uploadHeaders: const <String, String>{'Content-Type': 'image/png'},
      );

  @override
  Future<RecognitionJobData> createRecognition({
    required String uploadSessionId,
    required String idempotencyKey,
  }) async => result;

  @override
  Future<RecognitionJobData> getRecognition(String recognitionId) async =>
      result;

  @override
  Future<void> uploadImage(
    RecognitionUploadTicket ticket,
    PreparedMealImage image,
    RecognitionCancellation cancellation,
  ) async {
    if (!blockUploadUntilCancelled) {
      return;
    }
    await cancellation.whenCancelled;
    uploadCancelled = true;
    cancellation.throwIfCancelled();
  }
}

RecognitionJobData _successJob() => RecognitionJobData(
  id: 'recognition-1',
  status: 'succeeded',
  version: 1,
  overallConfidenceMilli: 930,
  dishes: const <RecognitionDishData>[
    RecognitionDishData(
      id: 'dish-1',
      name: '番茄炒蛋',
      servingMilli: 250000,
      energyKcal: 310,
      proteinMg: 18000,
      carbsMg: 12000,
      fatMg: 21000,
      confidenceMilli: 930,
    ),
  ],
);

RecognitionJobData _reviewJob() => RecognitionJobData(
  id: 'recognition-review',
  status: 'needs_review',
  version: 3,
  overallConfidenceMilli: 520,
  needsReviewReason: 'low_confidence',
  dishes: const <RecognitionDishData>[
    RecognitionDishData(
      id: 'dish-1',
      name: '番茄炒蛋',
      canonicalFoodId: 'tomato-eggs',
      servingMilli: 250000,
      energyKcal: 310,
      proteinMg: 18000,
      carbsMg: 12000,
      fatMg: 21000,
      confidenceMilli: 540,
    ),
    RecognitionDishData(
      id: 'dish-2',
      name: '米饭',
      canonicalFoodId: 'rice',
      servingMilli: 180000,
      energyKcal: 210,
      proteinMg: 5000,
      carbsMg: 46000,
      fatMg: 1000,
      confidenceMilli: 830,
    ),
  ],
);
