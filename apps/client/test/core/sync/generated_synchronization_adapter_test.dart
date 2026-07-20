import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/core/network/generated/export.dart' as api;
import 'package:foods_client/core/sync/generated_synchronization_adapter.dart';
import 'package:foods_client/core/sync/sync_models.dart';
import 'package:foods_client/core/sync/synchronization_adapter.dart';

const _operationId = '11111111-1111-4111-8111-111111111111';
const _mealId = '22222222-2222-4222-8222-222222222222';
const _itemId = '33333333-3333-4333-8333-333333333333';
final _now = DateTime.utc(2026, 7, 20, 12);

void main() {
  test(
    'push maps only sync payload fields and nulls unsafe image keys',
    () async {
      final apiClient = _FakeSynchronizationApi();
      final adapter = GeneratedSynchronizationAdapter(apiClient);
      final upsert = _mealOperation();

      await adapter.push(upsert);

      final sentMeal = apiClient.pushes.single.operations.single.meal!;
      expect(sentMeal.type, api.MealType.lunch);
      expect(sentMeal.items.single.imageReference, isNull);
      expect(sentMeal.items.single.id, _itemId);

      await adapter.push(
        PendingSyncOperation(
          operationId: '44444444-4444-4444-8444-444444444444',
          entityType: SyncEntityKind.mealLog,
          entityId: _mealId,
          action: SyncOperationAction.delete,
          expectedVersion: 1,
          payloadVersion: 1,
          payload: <String, Object?>{'id': _mealId},
        ),
      );
      final deletion = apiClient.pushes.last.operations.single;
      expect(deletion.meal, isNull);
      expect(deletion.fastingSession, isNull);
      expect(deletion.appPreferences, isNull);
    },
  );

  test(
    'push rejects date strings without an explicit zero UTC offset',
    () async {
      final apiClient = _FakeSynchronizationApi();
      final adapter = GeneratedSynchronizationAdapter(apiClient);
      final operation = _mealOperation(occurredAtUtc: '2026-07-20T12:00:00');

      await expectLater(
        adapter.push(operation),
        throwsA(isA<FormatException>()),
      );
      expect(apiClient.pushes, isEmpty);
    },
  );

  test('push normalizes Android GMT aliases for every timed entity', () async {
    final apiClient = _FakeSynchronizationApi();
    final adapter = GeneratedSynchronizationAdapter(apiClient);

    await adapter.push(_mealOperation(timeZoneId: 'GMT'));
    await adapter.push(_fastingOperation(timeZoneId: 'Etc/GMT'));

    expect(apiClient.pushes[0].operations.single.meal!.timeZoneId, 'UTC');
    expect(
      apiClient.pushes[1].operations.single.fastingSession!.timeZoneId,
      'UTC',
    );
  });

  test('push rejects applied receipts without version and cursor', () async {
    final apiClient = _FakeSynchronizationApi(
      pushResult: (operation) => api.SyncWriteResultResponse(
        changeCursor: null,
        entityId: operation.entityId,
        entityType: operation.entityType,
        operationId: operation.operationId,
        replayed: false,
        serverVersion: null,
        status: api.SyncWriteStatus.applied,
      ),
    );

    await expectLater(
      GeneratedSynchronizationAdapter(apiClient).push(_mealOperation()),
      throwsStateError,
    );
  });

  test('push maps a valid 400 problem for an upsert to a rejection', () async {
    final apiClient = _FakeSynchronizationApi(
      pushError: _responseFailure(statusCode: 400),
    );

    await expectLater(
      GeneratedSynchronizationAdapter(apiClient).push(_mealOperation()),
      throwsA(
        isA<RejectedSyncOperationException>()
            .having((error) => error.statusCode, 'statusCode', 400)
            .having(
              (error) => error.problemCode,
              'problemCode',
              'invalid_sync_operation',
            ),
      ),
    );
  });

  test('push maps a valid 422 problem for a delete to a rejection', () async {
    final apiClient = _FakeSynchronizationApi(
      pushError: _responseFailure(statusCode: 422),
    );

    await expectLater(
      GeneratedSynchronizationAdapter(apiClient).push(_deleteOperation()),
      throwsA(
        isA<RejectedSyncOperationException>()
            .having((error) => error.statusCode, 'statusCode', 422)
            .having(
              (error) => error.problemCode,
              'problemCode',
              'invalid_sync_operation',
            ),
      ),
    );
  });

  for (final statusCode in <int>[401, 409, 500]) {
    test('push preserves a valid $statusCode problem response', () async {
      final error = _responseFailure(statusCode: statusCode);
      final apiClient = _FakeSynchronizationApi(pushError: error);

      await expectLater(
        GeneratedSynchronizationAdapter(apiClient).push(_mealOperation()),
        throwsA(same(error)),
      );
    });
  }

  test('push preserves a malformed 422 response', () async {
    final error = _responseFailure(
      statusCode: 422,
      data: <String, Object?>{'code': 'invalid_sync_operation', 'status': 422},
    );
    final apiClient = _FakeSynchronizationApi(pushError: error);

    await expectLater(
      GeneratedSynchronizationAdapter(apiClient).push(_mealOperation()),
      throwsA(same(error)),
    );
  });

  test('push preserves a 422 problem whose body status disagrees', () async {
    final error = _responseFailure(
      statusCode: 422,
      data: <String, Object?>{
        'code': 'invalid_sync_operation',
        'status': 400,
        'title': 'Invalid sync operation',
        'traceId': 'trace-sync-rejection',
        'type': 'urn:ordin:problem:invalid_sync_operation',
      },
    );
    final apiClient = _FakeSynchronizationApi(pushError: error);

    await expectLater(
      GeneratedSynchronizationAdapter(apiClient).push(_mealOperation()),
      throwsA(same(error)),
    );
  });

  for (final type in <DioExceptionType>[
    DioExceptionType.connectionError,
    DioExceptionType.cancel,
  ]) {
    test('push preserves a ${type.name} transport failure', () async {
      final error = DioException(
        requestOptions: RequestOptions(path: '/api/v1/sync/push'),
        type: type,
        error: StateError('transport failed'),
      );
      final apiClient = _FakeSynchronizationApi(pushError: error);

      await expectLater(
        GeneratedSynchronizationAdapter(apiClient).push(_mealOperation()),
        throwsA(same(error)),
      );
    });
  }

  test('pull rejects out-of-order changes before exposing a page', () async {
    final apiClient = _FakeSynchronizationApi(
      pullResponse: api.SyncPullResponse(
        changes: <api.SyncChangeResponse>[
          _preferencesChange(cursor: 2, version: 1),
          _preferencesChange(cursor: 1, version: 2),
        ],
        hasMore: false,
        nextCursor: 2,
      ),
    );

    await expectLater(
      GeneratedSynchronizationAdapter(apiClient).pull(cursor: 0, limit: 100),
      throwsStateError,
    );
  });

  test(
    'pull rejects payload metadata that disagrees with the change',
    () async {
      final response = api.MealResponse(
        changeCursor: 2,
        createdAtUtc: _now,
        id: _mealId,
        isWithinEatingWindow: true,
        items: const <api.MealItemResponse>[],
        localDay: '2026-07-20',
        occurredAtUtc: _now,
        source: api.MealSource.manual,
        timeZoneId: 'UTC',
        type: api.MealType.lunch,
        updatedAtUtc: _now,
        version: 1,
      );
      final apiClient = _FakeSynchronizationApi(
        pullResponse: api.SyncPullResponse(
          changes: <api.SyncChangeResponse>[
            api.SyncChangeResponse(
              changeCursor: 1,
              deletedAtUtc: null,
              entityId: _mealId,
              entityType: api.SyncEntityType.mealLog,
              version: 1,
              meal: response,
            ),
          ],
          hasMore: false,
          nextCursor: 1,
        ),
      );

      await expectLater(
        GeneratedSynchronizationAdapter(apiClient).pull(cursor: 0, limit: 100),
        throwsStateError,
      );
    },
  );
}

PendingSyncOperation _deleteOperation() {
  return PendingSyncOperation(
    operationId: '44444444-4444-4444-8444-444444444444',
    entityType: SyncEntityKind.mealLog,
    entityId: _mealId,
    action: SyncOperationAction.delete,
    expectedVersion: 1,
    payloadVersion: 1,
    payload: <String, Object?>{'id': _mealId},
  );
}

DioException _responseFailure({required int statusCode, Object? data}) {
  final requestOptions = RequestOptions(path: '/api/v1/sync/push');
  return DioException(
    requestOptions: requestOptions,
    response: Response<Object?>(
      requestOptions: requestOptions,
      statusCode: statusCode,
      data:
          data ??
          <String, Object?>{
            'code': 'invalid_sync_operation',
            'status': statusCode,
            'title': 'Invalid sync operation',
            'traceId': 'trace-sync-rejection',
            'type': 'https://api.example.test/problems/invalid-sync-operation',
          },
    ),
    type: DioExceptionType.badResponse,
  );
}

PendingSyncOperation _mealOperation({
  Object occurredAtUtc = '2026-07-20T12:00:00.000Z',
  String timeZoneId = 'UTC',
}) {
  return PendingSyncOperation(
    operationId: _operationId,
    entityType: SyncEntityKind.mealLog,
    entityId: _mealId,
    action: SyncOperationAction.upsert,
    expectedVersion: 0,
    payloadVersion: 1,
    payload: <String, Object?>{
      'id': _mealId,
      'type': 'lunch',
      'source': 'manual',
      'occurredAtUtc': occurredAtUtc,
      'timeZoneId': timeZoneId,
      'localDay': '2026-07-20',
      'isWithinEatingWindow': true,
      'items': <Map<String, Object?>>[
        <String, Object?>{
          'id': _itemId,
          'name': 'Meal',
          'servingMilli': 1000,
          'energyKcal': 300,
          'proteinMg': 1000,
          'carbsMg': 2000,
          'fatMg': 3000,
          'imageReference': 'https://unsafe.example/image.jpg',
          'createdAtUtc': 'ignored',
          'updatedAtUtc': 'ignored',
        },
      ],
      'createdAtUtc': 'ignored',
      'updatedAtUtc': 'ignored',
    },
  );
}

PendingSyncOperation _fastingOperation({required String timeZoneId}) {
  return PendingSyncOperation(
    operationId: '44444444-4444-4444-8444-444444444444',
    entityType: SyncEntityKind.fastingSession,
    entityId: '55555555-5555-4555-8555-555555555555',
    action: SyncOperationAction.upsert,
    expectedVersion: 0,
    payloadVersion: 1,
    payload: <String, Object?>{
      'plan': 'balanced',
      'status': 'active',
      'startedAtUtc': '2026-07-20T12:00:00.000Z',
      'targetEndAtUtc': '2026-07-21T04:00:00.000Z',
      'endedAtUtc': null,
      'timeZoneId': timeZoneId,
      'startedLocalDay': '2026-07-20',
      'targetEndLocalDay': '2026-07-21',
      'endedLocalDay': null,
    },
  );
}

api.SyncChangeResponse _preferencesChange({
  required int cursor,
  required int version,
}) {
  return api.SyncChangeResponse(
    changeCursor: cursor,
    deletedAtUtc: null,
    entityId: 'current',
    entityType: api.SyncEntityType.appPreferences,
    version: version,
    appPreferences: api.AppPreferencesResponse(
      changeCursor: cursor,
      createdAtUtc: _now,
      dailyEnergyTargetKcal: 2000,
      fastingReminderEnabled: true,
      selectedFastingPlan: api.FastingPlan.balanced,
      updatedAtUtc: _now,
      version: version,
    ),
  );
}

typedef _PushResultFactory =
    api.SyncWriteResultResponse Function(api.SyncOperationInput operation);

final class _FakeSynchronizationApi implements api.SynchronizationApi {
  _FakeSynchronizationApi({this.pushResult, this.pullResponse, this.pushError});

  final _PushResultFactory? pushResult;
  final api.SyncPullResponse? pullResponse;
  final DioException? pushError;
  final List<api.SyncPushInput> pushes = <api.SyncPushInput>[];

  @override
  Future<api.SyncPullResponse> pullSyncChanges({
    int? cursor = 0,
    int? limit = 100,
    Map<String, dynamic>? extras =
        api.SynchronizationApi.pullSyncChangesOpenapiExtras,
  }) async {
    return pullResponse ??
        api.SyncPullResponse(
          changes: const <api.SyncChangeResponse>[],
          hasMore: false,
          nextCursor: cursor ?? 0,
        );
  }

  @override
  Future<api.SyncPushResponse> pushSyncOperations({
    required api.SyncPushInput body,
    Map<String, dynamic>? extras =
        api.SynchronizationApi.pushSyncOperationsOpenapiExtras,
  }) async {
    pushes.add(body);
    final error = pushError;
    if (error != null) {
      throw error;
    }
    final operation = body.operations.single;
    final result =
        pushResult?.call(operation) ??
        api.SyncWriteResultResponse(
          changeCursor: operation.expectedVersion + 1,
          entityId: operation.entityId,
          entityType: operation.entityType,
          operationId: operation.operationId,
          replayed: false,
          serverVersion: operation.expectedVersion + 1,
          status: api.SyncWriteStatus.applied,
        );
    return api.SyncPushResponse(results: <api.SyncWriteResultResponse>[result]);
  }
}
