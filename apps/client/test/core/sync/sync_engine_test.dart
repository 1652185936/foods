import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/core/db/account_scope.dart';
import 'package:foods_client/core/db/app_database.dart';
import 'package:foods_client/core/id/id_generator.dart';
import 'package:foods_client/core/sync/sync_engine.dart';
import 'package:foods_client/core/sync/sync_models.dart';
import 'package:foods_client/core/sync/sync_runner.dart';
import 'package:foods_client/core/sync/synchronization_adapter.dart';
import 'package:foods_client/core/time/app_clock.dart';
import 'package:foods_client/core/time/time_zone_converter.dart';
import 'package:foods_client/features/fasting/data/drift_fasting_repository.dart';
import 'package:foods_client/features/fasting/domain/fasting_plan.dart';
import 'package:foods_client/features/meals/data/drift_meal_repository.dart';
import 'package:foods_client/features/meals/domain/meal_log.dart';

const _ownerA = '11111111-1111-4111-8111-111111111111';
const _ownerB = '22222222-2222-4222-8222-222222222222';
const _remoteMealId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _remoteItemId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
final _now = DateTime.utc(2026, 7, 20, 12);

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('authenticated scope accepts only canonical lowercase UUIDs', () {
    expect(AccountScope.authenticated(_ownerA).ownerUserId, _ownerA);
    expect(
      () => AccountScope.authenticated(_remoteMealId.toUpperCase()),
      throwsArgumentError,
    );
    expect(() => AccountScope.authenticated(' $_ownerA'), throwsArgumentError);
    expect(() => AccountScope.authenticated('not-a-uuid'), throwsArgumentError);
  });

  test('local-only data fails closed before network access', () async {
    final adapter = _FakeSynchronizationAdapter();
    final engine = _engine(database, const AccountScope.localOnly(), adapter);

    await expectLater(
      engine.run(),
      throwsA(isA<LocalOnlySyncDisabledException>()),
    );
    expect(adapter.receivedOperations, isEmpty);
    expect(adapter.pullCursors, isEmpty);
  });

  test(
    'cancellation prevents a late push receipt from writing locally',
    () async {
      final scope = AccountScope.authenticated(_ownerA);
      await _mealRepository(
        database,
        scope,
        _SequenceUuidGenerator(),
      ).addMeal(_mealDraft());
      final receipt = Completer<SyncWriteReceipt>();
      final adapter = _FakeSynchronizationAdapter(
        onPush: (_, _) => receipt.future,
      );
      final engine = _engine(database, scope, adapter);

      final running = engine.run();
      while (adapter.receivedOperations.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      final operation = adapter.receivedOperations.single;
      engine.cancel();
      receipt.complete(
        SyncWriteReceipt(
          operationId: operation.operationId,
          entityType: operation.entityType,
          entityId: operation.entityId,
          disposition: SyncWriteDisposition.applied,
          replayed: false,
          serverVersion: 1,
          changeCursor: 1,
        ),
      );

      await expectLater(running, throwsA(isA<SyncCancelledException>()));
      final pending = await database.select(database.syncOutbox).getSingle();
      expect(pending.status, 'pending');
      expect(pending.attemptCount, 0);
      expect(
        (await database.select(database.mealLogs).getSingle()).serverVersion,
        0,
      );
      expect(await database.select(database.syncState).get(), isEmpty);
    },
  );

  test(
    'repositories, active uniqueness, and outbox are account isolated',
    () async {
      final scopeA = AccountScope.authenticated(_ownerA);
      final scopeB = AccountScope.authenticated(_ownerB);
      final idsA = _SequenceUuidGenerator();
      final idsB = _SequenceUuidGenerator();
      final mealsA = _mealRepository(database, scopeA, idsA);
      final mealsB = _mealRepository(database, scopeB, idsB);
      final fastingA = _fastingRepository(database, scopeA, idsA);
      final fastingB = _fastingRepository(database, scopeB, idsB);

      final mealA = await mealsA.addMeal(_mealDraft());
      final mealB = await mealsB.addMeal(_mealDraft());
      expect(
        mealA.id,
        mealB.id,
        reason: 'composite ownership permits same ids',
      );
      await fastingA.start(
        plan: FastingPlan.balanced,
        nowUtc: _now,
        timeZoneId: 'UTC',
      );
      await fastingB.start(
        plan: FastingPlan.balanced,
        nowUtc: _now,
        timeZoneId: 'UTC',
      );

      expect((await mealsA.watchStatistics().first).mealCount, 1);
      expect((await mealsB.watchStatistics().first).mealCount, 1);
      expect(
        (await fastingA.loadActive())?.id,
        (await fastingB.loadActive())?.id,
      );
      expect(
        await database.select(database.fastingSessions).get(),
        hasLength(2),
      );
      final outbox = await database.select(database.syncOutbox).get();
      expect(outbox.where((row) => row.ownerUserId == _ownerA), hasLength(2));
      expect(outbox.where((row) => row.ownerUserId == _ownerB), hasLength(2));

      await mealsA.deleteMeal(mealA.id);
      expect((await mealsA.watchStatistics().first).mealCount, 0);
      expect((await mealsB.watchStatistics().first).mealCount, 1);
    },
  );

  test(
    'fasting start-stop operations chain expected server versions',
    () async {
      final scope = AccountScope.authenticated(_ownerA);
      final repository = _fastingRepository(
        database,
        scope,
        _SequenceUuidGenerator(),
      );
      await repository.start(
        plan: FastingPlan.balanced,
        nowUtc: _now,
        timeZoneId: 'UTC',
      );
      await repository.cancelActive(nowUtc: _now.add(const Duration(hours: 1)));
      final adapter = _FakeSynchronizationAdapter(
        onPush: (operation, call) async => SyncWriteReceipt(
          operationId: operation.operationId,
          entityType: operation.entityType,
          entityId: operation.entityId,
          disposition: SyncWriteDisposition.applied,
          replayed: false,
          serverVersion: operation.expectedVersion + 1,
          changeCursor: call,
        ),
      );

      final result = await _engine(database, scope, adapter).run();

      expect(result.pushedOperations, 2);
      expect(
        adapter.receivedOperations.map(
          (operation) => operation.expectedVersion,
        ),
        <int>[0, 1],
      );
      expect(await database.select(database.syncOutbox).get(), isEmpty);
      expect(
        (await database.select(database.fastingSessions).getSingle())
            .serverVersion,
        2,
      );
    },
  );

  test(
    'a delete uses the latest acknowledged version and has no payload',
    () async {
      final scope = AccountScope.authenticated(_ownerA);
      final repository = _mealRepository(
        database,
        scope,
        _SequenceUuidGenerator(),
      );
      final meal = await repository.addMeal(_mealDraft());
      var cursor = 0;
      final adapter = _FakeSynchronizationAdapter(
        onPush: (operation, _) async => SyncWriteReceipt(
          operationId: operation.operationId,
          entityType: operation.entityType,
          entityId: operation.entityId,
          disposition: SyncWriteDisposition.applied,
          replayed: false,
          serverVersion: operation.expectedVersion + 1,
          changeCursor: ++cursor,
        ),
      );
      final engine = _engine(database, scope, adapter);
      await engine.run();

      await repository.deleteMeal(meal.id);
      await engine.run();

      final deletion = adapter.receivedOperations.last;
      expect(deletion.action, SyncOperationAction.delete);
      expect(deletion.expectedVersion, 1);
      expect(deletion.payload, isNull);
      final stored = await database.select(database.mealLogs).getSingle();
      expect(stored.deletedAtUtcMs, isNotNull);
      expect(stored.serverVersion, 2);
    },
  );

  test(
    'crash after server commit retries the same operation id as replay',
    () async {
      final scope = AccountScope.authenticated(_ownerA);
      await _mealRepository(
        database,
        scope,
        _SequenceUuidGenerator(),
      ).addMeal(_mealDraft());
      final adapter = _FakeSynchronizationAdapter(
        onPush: (operation, call) async {
          if (call == 1) {
            throw StateError('connection lost after server commit');
          }
          return SyncWriteReceipt(
            operationId: operation.operationId,
            entityType: operation.entityType,
            entityId: operation.entityId,
            disposition: SyncWriteDisposition.applied,
            replayed: true,
            serverVersion: 1,
            changeCursor: 1,
          );
        },
      );
      final engine = _engine(database, scope, adapter);

      await expectLater(engine.run(), throwsStateError);
      final pending = await database.select(database.syncOutbox).getSingle();
      expect(pending.attemptCount, 1);
      expect(pending.status, 'pending');

      await engine.run();

      expect(adapter.receivedOperations, hasLength(2));
      expect(
        adapter.receivedOperations.first.operationId,
        adapter.receivedOperations.last.operationId,
      );
      expect(await database.select(database.syncOutbox).get(), isEmpty);
      expect(
        (await database.select(database.mealLogs).getSingle()).serverVersion,
        1,
      );
    },
  );

  test(
    'permanent push rejection is isolated while later push and pull continue',
    () async {
      final scope = AccountScope.authenticated(_ownerA);
      final repository = _mealRepository(
        database,
        scope,
        _SequenceUuidGenerator(),
      );
      final rejectedMeal = await repository.addMeal(_mealDraft());
      final appliedMeal = await repository.addMeal(_mealDraft());
      final adapter = _FakeSynchronizationAdapter(
        onPush: (operation, call) async {
          if (call == 1) {
            throw const RejectedSyncOperationException(
              statusCode: 422,
              problemCode: 'validation_error',
            );
          }
          return SyncWriteReceipt(
            operationId: operation.operationId,
            entityType: operation.entityType,
            entityId: operation.entityId,
            disposition: SyncWriteDisposition.applied,
            replayed: false,
            serverVersion: 1,
            changeCursor: 2,
          );
        },
        onPull: (_, _) async => SyncPullPage(
          changes: const <RemoteSyncChange>[],
          nextCursor: 7,
          hasMore: false,
        ),
      );

      final result = await _engine(database, scope, adapter).run();

      expect(result.pushedOperations, 2);
      expect(result.pulledChanges, 0);
      expect(result.cursor, 7);
      expect(
        adapter.receivedOperations.map((operation) => operation.entityId),
        <String>[rejectedMeal.id, appliedMeal.id],
      );
      expect(adapter.pullCursors, <int>[0]);
      expect(result.conflicts, hasLength(1));
      expect(result.conflicts.single.source, SyncConflictSource.push);
      expect(result.conflicts.single.entityId, rejectedMeal.id);
      expect(result.conflicts.single.disposition, isNull);

      final rejected = await database.select(database.syncOutbox).getSingle();
      expect(rejected.entityId, rejectedMeal.id);
      expect(rejected.status, 'conflict');
      expect(rejected.attemptCount, 1);
      expect(rejected.nextAttemptAtUtcMs, isNull);
      expect(rejected.lastError, 'push:rejected:422:validation_error');
      expect(await _engine(database, scope, adapter).countConflicts(), 1);

      final meals = await database.select(database.mealLogs).get();
      expect(
        meals.singleWhere((meal) => meal.id == rejectedMeal.id).serverVersion,
        0,
      );
      expect(
        meals.singleWhere((meal) => meal.id == appliedMeal.id).serverVersion,
        1,
      );
      expect(
        await database.select(database.syncState).getSingle(),
        isA<SyncStateData>().having((state) => state.cursor, 'cursor', 7),
      );
    },
  );

  test(
    'malformed pull data rolls back the full page including cursor',
    () async {
      const secondMeal = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
      final valid = _remoteMealChange(
        entityId: _remoteMealId,
        itemId: _remoteItemId,
        cursor: 1,
        version: 1,
      );
      final malformedPayload = _remoteMealPayload(
        entityId: secondMeal,
        itemId: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
      )..['occurredAtUtc'] = '2026-07-20T12:00:00';
      final malformed = RemoteSyncChange(
        changeCursor: 2,
        entityType: SyncEntityKind.mealLog,
        entityId: secondMeal,
        version: 1,
        deletedAtUtc: null,
        payload: malformedPayload,
      );
      final adapter = _FakeSynchronizationAdapter(
        onPull: (_, _) async => SyncPullPage(
          changes: <RemoteSyncChange>[valid, malformed],
          nextCursor: 2,
          hasMore: false,
        ),
      );

      await expectLater(
        _engine(database, AccountScope.authenticated(_ownerA), adapter).run(),
        throwsA(isA<FormatException>()),
      );

      expect(await database.select(database.mealLogs).get(), isEmpty);
      expect(await database.select(database.mealItems).get(), isEmpty);
      expect(await database.select(database.syncState).get(), isEmpty);
    },
  );

  test(
    'push conflict is observable and pull applies server state without outbox',
    () async {
      final scope = AccountScope.authenticated(_ownerA);
      final repository = _mealRepository(
        database,
        scope,
        _SequenceUuidGenerator(),
      );
      final local = await repository.addMeal(_mealDraft());
      final adapter = _FakeSynchronizationAdapter(
        onPush: (operation, _) async => SyncWriteReceipt(
          operationId: operation.operationId,
          entityType: operation.entityType,
          entityId: operation.entityId,
          disposition: SyncWriteDisposition.versionConflict,
          replayed: false,
          serverVersion: 1,
          changeCursor: 1,
        ),
        onPull: (_, _) async => SyncPullPage(
          changes: <RemoteSyncChange>[
            _remoteMealChange(
              entityId: local.id,
              itemId: _remoteItemId,
              cursor: 1,
              version: 1,
              name: 'Server meal',
              imageReference: 'https://unsafe.example/image.jpg',
            ),
          ],
          nextCursor: 1,
          hasMore: false,
        ),
      );

      final result = await _engine(database, scope, adapter).run();

      expect(
        result.conflicts.map((conflict) => conflict.source),
        <SyncConflictSource>[SyncConflictSource.push, SyncConflictSource.pull],
      );
      final item = await database.select(database.mealItems).getSingle();
      expect(item.name, 'Server meal');
      expect(item.imageReference, isNull);
      final diagnostic = await database.select(database.syncOutbox).getSingle();
      expect(diagnostic.status, 'conflict');
      expect(
        await database.select(database.syncState).getSingle(),
        isA<SyncStateData>().having((state) => state.cursor, 'cursor', 1),
      );
    },
  );

  test(
    'remote tombstone deletes locally without creating an outbox row',
    () async {
      final upsert = _remoteMealChange(
        entityId: _remoteMealId,
        itemId: _remoteItemId,
        cursor: 1,
        version: 1,
      );
      final tombstone = RemoteSyncChange(
        changeCursor: 2,
        entityType: SyncEntityKind.mealLog,
        entityId: _remoteMealId,
        version: 2,
        deletedAtUtc: _now,
        payload: null,
      );
      final adapter = _FakeSynchronizationAdapter(
        onPull: (_, _) async => SyncPullPage(
          changes: <RemoteSyncChange>[upsert, tombstone],
          nextCursor: 2,
          hasMore: false,
        ),
      );

      final result = await _engine(
        database,
        AccountScope.authenticated(_ownerA),
        adapter,
      ).run();

      expect(result.pulledChanges, 2);
      expect(await database.select(database.mealLogs).get(), isEmpty);
      expect(await database.select(database.mealItems).get(), isEmpty);
      expect(await database.select(database.syncOutbox).get(), isEmpty);
    },
  );

  test('pull cursors and preferences are isolated per account', () async {
    Future<SyncPullPage> page(int target, int cursor) async => SyncPullPage(
      changes: <RemoteSyncChange>[
        RemoteSyncChange(
          changeCursor: cursor,
          entityType: SyncEntityKind.appPreferences,
          entityId: 'current',
          version: 1,
          deletedAtUtc: null,
          payload: <String, Object?>{
            'dailyEnergyTargetKcal': target,
            'selectedFastingPlan': 'balanced',
            'fastingReminderEnabled': true,
            'updatedAtUtc': _now,
          },
        ),
      ],
      nextCursor: cursor,
      hasMore: false,
    );

    await _engine(
      database,
      AccountScope.authenticated(_ownerA),
      _FakeSynchronizationAdapter(onPull: (_, _) => page(2100, 3)),
    ).run();
    await _engine(
      database,
      AccountScope.authenticated(_ownerB),
      _FakeSynchronizationAdapter(onPull: (_, _) => page(2400, 7)),
    ).run();

    final states = await database.select(database.syncState).get();
    expect(states, hasLength(2));
    expect(
      states.singleWhere((state) => state.ownerUserId == _ownerA).cursor,
      3,
    );
    expect(
      states.singleWhere((state) => state.ownerUserId == _ownerB).cursor,
      7,
    );
    final preferences = await database
        .select(database.appPreferencesTable)
        .get();
    expect(
      preferences
          .singleWhere((row) => row.ownerUserId == _ownerA)
          .dailyEnergyTargetKcal,
      2100,
    );
    expect(
      preferences
          .singleWhere((row) => row.ownerUserId == _ownerB)
          .dailyEnergyTargetKcal,
      2400,
    );
  });
}

SyncEngine _engine(
  AppDatabase database,
  AccountScope scope,
  SynchronizationAdapter adapter,
) {
  return SyncEngine(
    database: database,
    scope: scope,
    adapter: adapter,
    clock: FixedAppClock(_now),
  );
}

DriftMealRepository _mealRepository(
  AppDatabase database,
  AccountScope scope,
  IdGenerator ids,
) {
  return DriftMealRepository(
    database: database,
    ids: ids,
    clock: FixedAppClock(_now),
    timeZones: const IanaTimeZoneConverter(),
    scope: scope,
  );
}

DriftFastingRepository _fastingRepository(
  AppDatabase database,
  AccountScope scope,
  IdGenerator ids,
) {
  return DriftFastingRepository(
    database: database,
    ids: ids,
    clock: FixedAppClock(_now),
    timeZones: const IanaTimeZoneConverter(),
    scope: scope,
  );
}

MealDraft _mealDraft() => MealDraft(
  type: MealType.lunch,
  source: MealSource.manual,
  occurredAtUtc: _now,
  timeZoneId: 'UTC',
  localDay: '2026-07-20',
  isWithinEatingWindow: true,
  items: const <MealItemDraft>[
    MealItemDraft(name: 'Local meal', energyKcal: 300),
  ],
);

RemoteSyncChange _remoteMealChange({
  required String entityId,
  required String itemId,
  required int cursor,
  required int version,
  String name = 'Remote meal',
  String? imageReference,
}) {
  return RemoteSyncChange(
    changeCursor: cursor,
    entityType: SyncEntityKind.mealLog,
    entityId: entityId,
    version: version,
    deletedAtUtc: null,
    payload: _remoteMealPayload(
      entityId: entityId,
      itemId: itemId,
      name: name,
      imageReference: imageReference,
    ),
  );
}

Map<String, Object?> _remoteMealPayload({
  required String entityId,
  required String itemId,
  String name = 'Remote meal',
  String? imageReference,
}) {
  return <String, Object?>{
    'id': entityId,
    'type': 'lunch',
    'source': 'manual',
    'occurredAtUtc': _now,
    'timeZoneId': 'UTC',
    'localDay': '2026-07-20',
    'isWithinEatingWindow': true,
    'items': <Map<String, Object?>>[
      <String, Object?>{
        'id': itemId,
        'name': name,
        'servingMilli': 1000,
        'energyKcal': 420,
        'proteinMg': 1000,
        'carbsMg': 2000,
        'fatMg': 3000,
        'imageReference': imageReference,
      },
    ],
    'createdAtUtc': _now,
    'updatedAtUtc': _now,
  };
}

typedef _PushHandler =
    Future<SyncWriteReceipt> Function(PendingSyncOperation operation, int call);
typedef _PullHandler = Future<SyncPullPage> Function(int cursor, int limit);

final class _FakeSynchronizationAdapter implements SynchronizationAdapter {
  _FakeSynchronizationAdapter({this.onPush, this.onPull});

  final _PushHandler? onPush;
  final _PullHandler? onPull;
  final List<PendingSyncOperation> receivedOperations =
      <PendingSyncOperation>[];
  final List<int> pullCursors = <int>[];

  @override
  Future<SyncWriteReceipt> push(PendingSyncOperation operation) {
    receivedOperations.add(operation);
    final handler = onPush;
    if (handler == null) {
      throw StateError('Unexpected push operation.');
    }
    return handler(operation, receivedOperations.length);
  }

  @override
  Future<SyncPullPage> pull({required int cursor, required int limit}) {
    pullCursors.add(cursor);
    final handler = onPull;
    if (handler != null) {
      return handler(cursor, limit);
    }
    return Future<SyncPullPage>.value(
      SyncPullPage(
        changes: const <RemoteSyncChange>[],
        nextCursor: cursor,
        hasMore: false,
      ),
    );
  }
}

final class _SequenceUuidGenerator implements IdGenerator {
  int _next = 1;

  @override
  String next() {
    final suffix = (_next++).toRadixString(16).padLeft(12, '0');
    return '00000000-0000-4000-8000-$suffix';
  }
}
