import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/core/network/generated/recognition/recognition_api.dart';
import 'package:foods_client/features/meals/recognition/generated_recognition_gateway.dart';
import 'package:foods_client/features/meals/recognition/meal_image_picker.dart';
import 'package:foods_client/features/meals/recognition/meal_image_preparer.dart';
import 'package:foods_client/features/meals/recognition/recognition_models.dart';
import 'package:foods_client/features/meals/recognition/recognition_service.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  test(
    'direct upload forwards every required header and exact bytes',
    () async {
      final uploader = _CapturingUploader();
      final gateway = GeneratedRecognitionGateway(
        api: _MockRecognitionApi(),
        uploader: uploader,
      );
      final ticket = RecognitionUploadTicket(
        uploadSessionId: 'upload-1',
        uploadUri: Uri.parse(
          'https://uploads.example.test/object?signature=secret',
        ),
        uploadHeaders: const <String, String>{
          'Content-Type': 'image/png',
          'x-amz-checksum-sha256': 'abcDEF123',
          'X-Custom-Header': 'preserve this value',
        },
      );
      final image = _image();

      await gateway.uploadImage(ticket, image, RecognitionCancellation());

      expect(uploader.uri, ticket.uploadUri);
      expect(uploader.headers, ticket.uploadHeaders);
      expect(uploader.headers!.keys, orderedEquals(ticket.uploadHeaders.keys));
      expect(uploader.bytes, image.bytes);
    },
  );

  test('polls queued and running states until a multi-dish result', () async {
    final remote = _FakeRecognitionRemote(<RecognitionJobData>[
      _job('queued'),
      _job('running'),
      _job('succeeded', dishes: _dishes()),
    ]);
    var delays = 0;
    final service = MealRecognitionService(
      remote: remote,
      maxPollAttempts: 4,
      pollInterval: const Duration(seconds: 1),
      delay: (_, cancellation) async {
        cancellation.throwIfCancelled();
        delays++;
      },
    );
    final progress = <RecognitionProgressStage>[];

    final result = await service.recognize(
      _image(),
      cancellation: RecognitionCancellation(),
      onProgress: progress.add,
    );

    expect(result.dishes, hasLength(2));
    expect(remote.getCalls, 2);
    expect(delays, 2);
    expect(progress, orderedEquals(RecognitionProgressStage.values));
    expect(remote.idempotencyKey, matches(RegExp(r'^[0-9a-f-]{36}$')));
  });

  test('times out after the configured finite poll budget', () async {
    final remote = _FakeRecognitionRemote(<RecognitionJobData>[
      _job('queued'),
      _job('running'),
      _job('running'),
    ]);
    final service = MealRecognitionService(
      remote: remote,
      maxPollAttempts: 3,
      pollInterval: Duration.zero,
      delay: (_, _) async {},
    );

    await expectLater(
      service.recognize(_image(), cancellation: RecognitionCancellation()),
      throwsA(
        isA<RecognitionFailure>().having(
          (error) => error.kind,
          'kind',
          RecognitionFailureKind.timedOut,
        ),
      ),
    );
    expect(remote.getCalls, 2);
  });

  test('cancellation interrupts polling without a hot loop', () async {
    final cancellation = RecognitionCancellation();
    final enteredDelay = Completer<void>();
    final remote = _FakeRecognitionRemote(<RecognitionJobData>[_job('queued')]);
    final service = MealRecognitionService(
      remote: remote,
      maxPollAttempts: 20,
      delay: (_, token) async {
        enteredDelay.complete();
        await token.whenCancelled;
        token.throwIfCancelled();
      },
    );

    final operation = service.recognize(_image(), cancellation: cancellation);
    await enteredDelay.future;
    cancellation.cancel();

    await expectLater(
      operation,
      throwsA(
        isA<RecognitionFailure>().having(
          (error) => error.kind,
          'kind',
          RecognitionFailureKind.cancelled,
        ),
      ),
    );
    expect(remote.getCalls, 0);
  });

  test('a cancelled late create response cannot become a success', () async {
    final deferredCreate = Completer<RecognitionJobData>();
    final remote = _FakeRecognitionRemote(
      const <RecognitionJobData>[],
      deferredCreate: deferredCreate,
    );
    final cancellation = RecognitionCancellation();
    final service = MealRecognitionService(remote: remote);

    final operation = service.recognize(_image(), cancellation: cancellation);
    await remote.createStarted.future;
    cancellation.cancel();
    deferredCreate.complete(_job('succeeded', dishes: _dishes()));

    await expectLater(
      operation,
      throwsA(
        isA<RecognitionFailure>().having(
          (error) => error.kind,
          'kind',
          RecognitionFailureKind.cancelled,
        ),
      ),
    );
  });

  test('a cancelled late poll response cannot become a success', () async {
    final deferredGet = Completer<RecognitionJobData>();
    final remote = _FakeRecognitionRemote(<RecognitionJobData>[
      _job('queued'),
    ], deferredGet: deferredGet);
    final cancellation = RecognitionCancellation();
    final service = MealRecognitionService(
      remote: remote,
      pollInterval: Duration.zero,
    );

    final operation = service.recognize(_image(), cancellation: cancellation);
    await remote.getStarted.future;
    cancellation.cancel();
    deferredGet.complete(_job('succeeded', dishes: _dishes()));

    await expectLater(
      operation,
      throwsA(
        isA<RecognitionFailure>().having(
          (error) => error.kind,
          'kind',
          RecognitionFailureKind.cancelled,
        ),
      ),
    );
  });

  test('surfaces a terminal provider failure without polling again', () async {
    final remote = _FakeRecognitionRemote(<RecognitionJobData>[
      _job('failed', errorCode: 'provider_unavailable'),
    ]);
    final service = MealRecognitionService(remote: remote);

    await expectLater(
      service.recognize(_image(), cancellation: RecognitionCancellation()),
      throwsA(
        isA<RecognitionFailure>()
            .having(
              (error) => error.kind,
              'kind',
              RecognitionFailureKind.recognitionFailed,
            )
            .having((error) => error.code, 'code', 'provider_unavailable'),
      ),
    );
    expect(remote.getCalls, 0);
  });

  test('correction sends all edited dishes with optimistic version', () async {
    final remote = _FakeRecognitionRemote(<RecognitionJobData>[
      _job('needs_review', dishes: _dishes()),
    ]);
    final service = MealRecognitionService(remote: remote);
    final reviewed = _dishes()
        .map(
          (dish) => RecognitionDishData(
            id: dish.id,
            name: '${dish.name} 已核对',
            servingMilli: dish.servingMilli,
            energyKcal: dish.energyKcal,
            proteinMg: dish.proteinMg,
            carbsMg: dish.carbsMg,
            fatMg: dish.fatMg,
            confidenceMilli: dish.confidenceMilli,
          ),
        )
        .toList();

    final result = await service.correct(
      job: _job('needs_review', dishes: _dishes()),
      dishes: reviewed,
      cancellation: RecognitionCancellation(),
    );

    expect(result.status, 'succeeded');
    expect(remote.correctedDishes, reviewed);
    expect(remote.correctedVersion, 1);
  });
}

final class _MockRecognitionApi extends Mock implements RecognitionApi {}

final class _CapturingUploader implements DirectImageUploader {
  Uri? uri;
  Map<String, String>? headers;
  List<int>? bytes;

  @override
  Future<void> put({
    required Uri uri,
    required Map<String, String> headers,
    required List<int> bytes,
    required RecognitionCancellation cancellation,
  }) async {
    this.uri = uri;
    this.headers = Map<String, String>.from(headers);
    this.bytes = List<int>.from(bytes);
  }
}

final class _FakeRecognitionRemote implements RecognitionRemoteGateway {
  _FakeRecognitionRemote(
    List<RecognitionJobData> responses, {
    this.deferredCreate,
    this.deferredGet,
  }) : _responses = List<RecognitionJobData>.from(responses);

  final List<RecognitionJobData> _responses;
  final Completer<RecognitionJobData>? deferredCreate;
  final Completer<RecognitionJobData>? deferredGet;
  final Completer<void> createStarted = Completer<void>();
  final Completer<void> getStarted = Completer<void>();
  int getCalls = 0;
  String? idempotencyKey;
  List<RecognitionDishData>? correctedDishes;
  int? correctedVersion;

  @override
  Future<void> completeUpload(String uploadSessionId) async {}

  @override
  Future<RecognitionJobData> correctRecognition({
    required String recognitionId,
    required int expectedVersion,
    required List<RecognitionDishData> dishes,
  }) async {
    correctedVersion = expectedVersion;
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
        uploadUri: Uri.parse('https://upload.example.test/object'),
        uploadHeaders: const <String, String>{'Content-Type': 'image/jpeg'},
      );

  @override
  Future<RecognitionJobData> createRecognition({
    required String uploadSessionId,
    required String idempotencyKey,
  }) async {
    this.idempotencyKey = idempotencyKey;
    final deferred = deferredCreate;
    if (deferred != null) {
      createStarted.complete();
      return deferred.future;
    }
    return _responses.removeAt(0);
  }

  @override
  Future<RecognitionJobData> getRecognition(String recognitionId) async {
    getCalls++;
    final deferred = deferredGet;
    if (deferred != null) {
      getStarted.complete();
      return deferred.future;
    }
    return _responses.isEmpty ? _job('running') : _responses.removeAt(0);
  }

  @override
  Future<void> uploadImage(
    RecognitionUploadTicket ticket,
    PreparedMealImage image,
    RecognitionCancellation cancellation,
  ) async {}
}

PreparedMealImage _image() => PreparedMealImage(
  bytes: Uint8List.fromList(const <int>[0xff, 0xd8, 0xff, 0x00]),
  contentType: MealImageContentType.jpeg,
  checksumSha256: List<String>.filled(64, 'a').join(),
  origin: MealImageOrigin.gallery,
);

RecognitionJobData _job(
  String status, {
  List<RecognitionDishData> dishes = const <RecognitionDishData>[],
  String? errorCode,
}) => RecognitionJobData(
  id: 'recognition-1',
  status: status,
  version: 1,
  dishes: dishes,
  errorCode: errorCode,
);

List<RecognitionDishData> _dishes() => const <RecognitionDishData>[
  RecognitionDishData(
    id: 'dish-1',
    name: '番茄炒蛋',
    servingMilli: 250000,
    energyKcal: 310,
    proteinMg: 18000,
    carbsMg: 12000,
    fatMg: 21000,
    confidenceMilli: 920,
  ),
  RecognitionDishData(
    id: 'dish-2',
    name: '米饭',
    servingMilli: 180000,
    energyKcal: 210,
    proteinMg: 5000,
    carbsMg: 46000,
    fatMg: 1000,
    confidenceMilli: 880,
  ),
];
