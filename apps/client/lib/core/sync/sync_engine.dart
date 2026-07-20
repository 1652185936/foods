import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/account_scope.dart';
import '../db/app_database.dart' as db;
import '../time/app_clock.dart';
import 'sync_models.dart';
import 'sync_runner.dart';
import 'synchronization_adapter.dart';

final class SyncEngine implements AccountSyncRunner {
  factory SyncEngine({
    required db.AppDatabase database,
    required AccountScope scope,
    required SynchronizationAdapter adapter,
    required AppClock clock,
  }) => SyncEngine._(database, scope, adapter, clock);

  SyncEngine._(this._database, this._scope, this._adapter, this._clock);

  final db.AppDatabase _database;
  final AccountScope _scope;
  final SynchronizationAdapter _adapter;
  final AppClock _clock;

  Future<SyncRunResult>? _activeRun;
  bool _cancelled = false;

  @override
  void cancel() {
    _cancelled = true;
  }

  @override
  Future<int> countConflicts() async {
    _ensureActive();
    final rows =
        await (_database.select(_database.syncOutbox)..where(
              (row) =>
                  row.ownerUserId.equals(_scope.ownerUserId) &
                  row.status.equals('conflict'),
            ))
            .get();
    _ensureActive();
    return rows.length;
  }

  @override
  Future<SyncRunResult> run({int pushLimit = 100, int pullLimit = 100}) {
    final activeRun = _activeRun;
    if (activeRun != null) {
      return activeRun;
    }
    final future = _run(pushLimit: pushLimit, pullLimit: pullLimit);
    _activeRun = future;
    return future.whenComplete(() {
      if (identical(_activeRun, future)) {
        _activeRun = null;
      }
    });
  }

  Future<SyncRunResult> _run({
    required int pushLimit,
    required int pullLimit,
  }) async {
    _ensureActive();
    if (!_scope.canSync) {
      throw const LocalOnlySyncDisabledException();
    }
    if (pushLimit < 1 || pushLimit > 100) {
      throw ArgumentError.value(
        pushLimit,
        'pushLimit',
        'Must be from 1 to 100.',
      );
    }
    if (pullLimit < 1 || pullLimit > 100) {
      throw ArgumentError.value(
        pullLimit,
        'pullLimit',
        'Must be from 1 to 100.',
      );
    }

    final conflicts = <SyncConflict>[];
    final pushed = await _pushPending(pushLimit, conflicts);
    final pullResult = await _pullChanges(pullLimit, conflicts);
    return SyncRunResult(
      pushedOperations: pushed,
      pulledChanges: pullResult.changes,
      cursor: pullResult.cursor,
      conflicts: conflicts,
    );
  }

  Future<int> _pushPending(int limit, List<SyncConflict> conflicts) async {
    var pushed = 0;
    while (pushed < limit) {
      _ensureActive();
      final row = await _nextPendingOperation();
      if (row == null) {
        break;
      }
      final operation = _operationFromRow(row);
      late final SyncWriteReceipt receipt;
      try {
        receipt = await _adapter.push(operation);
      } on RejectedSyncOperationException catch (error) {
        if (_cancelled) {
          throw const SyncCancelledException();
        }
        await _markRejectedPush(row, error);
        pushed++;
        conflicts.add(
          SyncConflict(
            source: SyncConflictSource.push,
            entityType: operation.entityType,
            entityId: operation.entityId,
            operationId: operation.operationId,
            serverVersion: null,
          ),
        );
        continue;
      } catch (error, stackTrace) {
        if (_cancelled) {
          throw const SyncCancelledException();
        }
        await _recordPushFailure(row, error);
        Error.throwWithStackTrace(error, stackTrace);
      }
      _ensureActive();
      pushed++;
      _validateReceipt(operation, receipt);
      if (receipt.disposition == SyncWriteDisposition.applied) {
        await _acceptAppliedReceipt(row, receipt);
        continue;
      }
      await _markPushConflict(row, receipt);
      conflicts.add(
        SyncConflict(
          source: SyncConflictSource.push,
          entityType: operation.entityType,
          entityId: operation.entityId,
          operationId: operation.operationId,
          disposition: receipt.disposition,
          serverVersion: receipt.serverVersion,
        ),
      );
    }
    return pushed;
  }

  Future<db.SyncOutboxData?> _nextPendingOperation() {
    final query = _database.select(_database.syncOutbox)
      ..where(
        (row) =>
            row.ownerUserId.equals(_scope.ownerUserId) &
            row.status.equals('pending'),
      )
      ..orderBy(<OrderingTerm Function(db.SyncOutbox)>[
        (row) => OrderingTerm.asc(row.createdAtUtcMs),
        (row) => OrderingTerm.asc(row.operationId),
      ])
      ..limit(1);
    return query.getSingleOrNull();
  }

  PendingSyncOperation _operationFromRow(db.SyncOutboxData row) {
    if (row.expectedVersion < 0) {
      throw StateError('An outbox operation has a negative expected version.');
    }
    if (row.payloadVersion != 1) {
      throw StateError(
        'Unsupported outbox payload version ${row.payloadVersion}.',
      );
    }
    final entityType = _entityTypeFromName(row.entityType);
    final action = switch (row.action) {
      'upsert' => SyncOperationAction.upsert,
      'delete' => SyncOperationAction.delete,
      _ => throw StateError('Unknown outbox action ${row.action}.'),
    };
    Map<String, Object?>? payload;
    if (action == SyncOperationAction.upsert) {
      final decoded = jsonDecode(row.payloadJson);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'An upsert outbox payload must be an object.',
        );
      }
      payload = Map<String, Object?>.from(decoded);
    }
    return PendingSyncOperation(
      operationId: row.operationId,
      entityType: entityType,
      entityId: row.entityId,
      action: action,
      expectedVersion: row.expectedVersion,
      payloadVersion: row.payloadVersion,
      payload: payload,
    );
  }

  void _validateReceipt(
    PendingSyncOperation operation,
    SyncWriteReceipt receipt,
  ) {
    if (receipt.operationId != operation.operationId ||
        receipt.entityType != operation.entityType ||
        receipt.entityId != operation.entityId) {
      throw StateError('The sync receipt does not match its operation.');
    }
    switch (receipt.disposition) {
      case SyncWriteDisposition.applied:
      case SyncWriteDisposition.versionConflict:
        if ((receipt.serverVersion ?? 0) <= 0 ||
            (receipt.changeCursor ?? 0) <= 0) {
          throw StateError(
            '${receipt.disposition.name} requires a positive version and cursor.',
          );
        }
      case SyncWriteDisposition.notFound:
      case SyncWriteDisposition.idempotencyConflict:
      case SyncWriteDisposition.activeFastingConflict:
        if (receipt.serverVersion != null || receipt.changeCursor != null) {
          throw StateError(
            '${receipt.disposition.name} cannot include a version or cursor.',
          );
        }
      case SyncWriteDisposition.unknown:
        throw StateError('The server returned an unknown sync write status.');
    }
  }

  Future<void> _recordPushFailure(db.SyncOutboxData row, Object error) {
    return (_database.update(_database.syncOutbox)..where(
          (entry) =>
              entry.ownerUserId.equals(_scope.ownerUserId) &
              entry.operationId.equals(row.operationId),
        ))
        .write(
          db.SyncOutboxCompanion(
            attemptCount: Value(row.attemptCount + 1),
            nextAttemptAtUtcMs: const Value(null),
            lastError: Value(_diagnostic(error)),
          ),
        );
  }

  Future<void> _markRejectedPush(
    db.SyncOutboxData row,
    RejectedSyncOperationException error,
  ) {
    final diagnostic = 'push:rejected:${error.statusCode}:${error.problemCode}';
    return (_database.update(_database.syncOutbox)..where(
          (entry) =>
              entry.ownerUserId.equals(_scope.ownerUserId) &
              entry.operationId.equals(row.operationId) &
              entry.status.equals('pending'),
        ))
        .write(
          db.SyncOutboxCompanion(
            status: const Value('conflict'),
            attemptCount: Value(row.attemptCount + 1),
            nextAttemptAtUtcMs: const Value(null),
            lastError: Value(_diagnostic(diagnostic)),
          ),
        );
  }

  Future<void> _acceptAppliedReceipt(
    db.SyncOutboxData row,
    SyncWriteReceipt receipt,
  ) {
    final serverVersion = receipt.serverVersion!;
    return _database.transaction(() async {
      _ensureActive();
      final current =
          await (_database.select(_database.syncOutbox)..where(
                (entry) =>
                    entry.ownerUserId.equals(_scope.ownerUserId) &
                    entry.operationId.equals(row.operationId) &
                    entry.status.equals('pending'),
              ))
              .getSingleOrNull();
      if (current == null ||
          current.entityType != row.entityType ||
          current.entityId != row.entityId) {
        throw StateError('The pending sync operation changed while pushing.');
      }
      _ensureActive();
      await _updateLocalServerVersion(
        _entityTypeFromName(row.entityType),
        row.entityId,
        serverVersion,
      );
      await (_database.delete(_database.syncOutbox)..where(
            (entry) =>
                entry.ownerUserId.equals(_scope.ownerUserId) &
                entry.operationId.equals(row.operationId),
          ))
          .go();
      await (_database.update(_database.syncOutbox)..where(
            (entry) =>
                entry.ownerUserId.equals(_scope.ownerUserId) &
                entry.entityType.equals(row.entityType) &
                entry.entityId.equals(row.entityId) &
                entry.status.equals('pending'),
          ))
          .write(db.SyncOutboxCompanion(expectedVersion: Value(serverVersion)));
    });
  }

  Future<void> _updateLocalServerVersion(
    SyncEntityKind entityType,
    String entityId,
    int serverVersion,
  ) async {
    switch (entityType) {
      case SyncEntityKind.mealLog:
        await (_database.update(_database.mealLogs)..where(
              (row) =>
                  row.ownerUserId.equals(_scope.ownerUserId) &
                  row.id.equals(entityId),
            ))
            .write(db.MealLogsCompanion(serverVersion: Value(serverVersion)));
      case SyncEntityKind.fastingSession:
        await (_database.update(_database.fastingSessions)..where(
              (row) =>
                  row.ownerUserId.equals(_scope.ownerUserId) &
                  row.id.equals(entityId),
            ))
            .write(
              db.FastingSessionsCompanion(serverVersion: Value(serverVersion)),
            );
      case SyncEntityKind.appPreferences:
        if (entityId != 'current') {
          throw StateError('appPreferences entityId must be current.');
        }
        await (_database.update(_database.appPreferencesTable)..where(
              (row) =>
                  row.ownerUserId.equals(_scope.ownerUserId) &
                  row.singletonId.equals(1),
            ))
            .write(
              db.AppPreferencesTableCompanion(
                serverVersion: Value(serverVersion),
              ),
            );
    }
  }

  Future<void> _markPushConflict(
    db.SyncOutboxData row,
    SyncWriteReceipt receipt,
  ) {
    final message = 'push:${receipt.disposition.name}';
    return _database.transaction(() async {
      await (_database.update(_database.syncOutbox)..where(
            (entry) =>
                entry.ownerUserId.equals(_scope.ownerUserId) &
                entry.entityType.equals(row.entityType) &
                entry.entityId.equals(row.entityId) &
                entry.status.equals('pending'),
          ))
          .write(
            db.SyncOutboxCompanion(
              status: const Value('conflict'),
              lastError: Value(message),
            ),
          );
      await (_database.update(_database.syncOutbox)..where(
            (entry) =>
                entry.ownerUserId.equals(_scope.ownerUserId) &
                entry.operationId.equals(row.operationId),
          ))
          .write(
            db.SyncOutboxCompanion(attemptCount: Value(row.attemptCount + 1)),
          );
    });
  }

  Future<({int changes, int cursor})> _pullChanges(
    int limit,
    List<SyncConflict> conflicts,
  ) async {
    var cursor = await _loadCursor();
    var pulled = 0;
    var hasMore = true;
    final conflictKeys = <String>{};
    while (hasMore) {
      _ensureActive();
      final page = await _adapter.pull(cursor: cursor, limit: limit);
      _ensureActive();
      _validatePage(page, cursor);
      final pageConflicts = <SyncConflict>[];
      await _database.transaction(() async {
        for (final change in page.changes) {
          _ensureActive();
          await _applyRemoteChange(change, pageConflicts, conflictKeys);
        }
        _ensureActive();
        await _database
            .into(_database.syncState)
            .insertOnConflictUpdate(
              db.SyncStateCompanion.insert(
                ownerUserId: _scope.ownerUserId,
                cursor: Value(page.nextCursor),
                updatedAtUtcMs: _clock.now().toUtc().millisecondsSinceEpoch,
              ),
            );
      });
      conflicts.addAll(pageConflicts);
      pulled += page.changes.length;
      cursor = page.nextCursor;
      hasMore = page.hasMore;
    }
    return (changes: pulled, cursor: cursor);
  }

  Future<int> _loadCursor() async {
    final row =
        await (_database.select(_database.syncState)
              ..where((entry) => entry.ownerUserId.equals(_scope.ownerUserId)))
            .getSingleOrNull();
    return row?.cursor ?? 0;
  }

  void _validatePage(SyncPullPage page, int requestedCursor) {
    if (requestedCursor < 0 || page.nextCursor < requestedCursor) {
      throw StateError('A sync pull cursor cannot move backwards.');
    }
    var previous = requestedCursor;
    for (final change in page.changes) {
      if (change.changeCursor <= previous || change.version <= 0) {
        throw StateError(
          'Sync changes require increasing cursors and positive versions.',
        );
      }
      if (change.changeCursor > page.nextCursor) {
        throw StateError('A sync change exceeds the page cursor.');
      }
      previous = change.changeCursor;
      _validateChangeShape(change);
    }
    if (page.hasMore && page.nextCursor <= requestedCursor) {
      throw StateError('A paginated sync pull did not advance its cursor.');
    }
  }

  void _validateChangeShape(RemoteSyncChange change) {
    if (change.entityId.isEmpty) {
      throw StateError('A sync change requires an entity id.');
    }
    if (change.entityType == SyncEntityKind.appPreferences &&
        change.entityId != 'current') {
      throw StateError('appPreferences entityId must be current.');
    }
    if (change.isTombstone) {
      if (change.payload != null || !change.deletedAtUtc!.isUtc) {
        throw StateError('A tombstone must contain only a UTC deletion time.');
      }
      if (change.entityType == SyncEntityKind.appPreferences) {
        throw StateError('appPreferences cannot be deleted.');
      }
      return;
    }
    final payload = change.payload;
    if (payload == null) {
      throw StateError('A non-tombstone sync change requires a payload.');
    }
    if (change.entityType != SyncEntityKind.appPreferences &&
        payload['id'] != change.entityId) {
      throw StateError('A sync payload id does not match its change.');
    }
  }

  Future<void> _applyRemoteChange(
    RemoteSyncChange change,
    List<SyncConflict> conflicts,
    Set<String> conflictKeys,
  ) async {
    final localVersion = await _localServerVersion(change);
    if (localVersion != null && localVersion >= change.version) {
      return;
    }
    final localOperations = await _entityOutboxRows(
      change.entityType,
      change.entityId,
    );
    if (localOperations.isNotEmpty) {
      await _markPullOutboxConflict(change);
      for (final operation in localOperations) {
        final key = 'pull:${operation.operationId}:${change.version}';
        if (conflictKeys.add(key)) {
          conflicts.add(
            SyncConflict(
              source: SyncConflictSource.pull,
              entityType: change.entityType,
              entityId: change.entityId,
              operationId: operation.operationId,
              serverVersion: change.version,
            ),
          );
        }
      }
    }
    if (change.isTombstone) {
      await _applyTombstone(change);
      return;
    }
    switch (change.entityType) {
      case SyncEntityKind.mealLog:
        await _applyMeal(change);
      case SyncEntityKind.fastingSession:
        await _applyFasting(change, conflicts, conflictKeys);
      case SyncEntityKind.appPreferences:
        await _applyPreferences(change);
    }
  }

  Future<int?> _localServerVersion(RemoteSyncChange change) async {
    switch (change.entityType) {
      case SyncEntityKind.mealLog:
        final row =
            await (_database.select(_database.mealLogs)..where(
                  (row) =>
                      row.ownerUserId.equals(_scope.ownerUserId) &
                      row.id.equals(change.entityId),
                ))
                .getSingleOrNull();
        return row?.serverVersion;
      case SyncEntityKind.fastingSession:
        final row =
            await (_database.select(_database.fastingSessions)..where(
                  (row) =>
                      row.ownerUserId.equals(_scope.ownerUserId) &
                      row.id.equals(change.entityId),
                ))
                .getSingleOrNull();
        return row?.serverVersion;
      case SyncEntityKind.appPreferences:
        final row =
            await (_database.select(_database.appPreferencesTable)..where(
                  (row) =>
                      row.ownerUserId.equals(_scope.ownerUserId) &
                      row.singletonId.equals(1),
                ))
                .getSingleOrNull();
        return row?.serverVersion;
    }
  }

  Future<List<db.SyncOutboxData>> _entityOutboxRows(
    SyncEntityKind entityType,
    String entityId,
  ) {
    final query = _database.select(_database.syncOutbox)
      ..where(
        (row) =>
            row.ownerUserId.equals(_scope.ownerUserId) &
            row.entityType.equals(entityType.name) &
            row.entityId.equals(entityId) &
            row.status.isIn(const <String>['pending', 'conflict']),
      );
    return query.get();
  }

  Future<void> _markPullOutboxConflict(RemoteSyncChange change) {
    return (_database.update(_database.syncOutbox)..where(
          (row) =>
              row.ownerUserId.equals(_scope.ownerUserId) &
              row.entityType.equals(change.entityType.name) &
              row.entityId.equals(change.entityId) &
              row.status.equals('pending'),
        ))
        .write(
          db.SyncOutboxCompanion(
            status: const Value('conflict'),
            lastError: Value('pull:serverVersion:${change.version}'),
          ),
        );
  }

  Future<void> _applyTombstone(RemoteSyncChange change) async {
    switch (change.entityType) {
      case SyncEntityKind.mealLog:
        await (_database.delete(_database.mealLogs)..where(
              (row) =>
                  row.ownerUserId.equals(_scope.ownerUserId) &
                  row.id.equals(change.entityId),
            ))
            .go();
      case SyncEntityKind.fastingSession:
        await (_database.delete(_database.fastingSessions)..where(
              (row) =>
                  row.ownerUserId.equals(_scope.ownerUserId) &
                  row.id.equals(change.entityId),
            ))
            .go();
      case SyncEntityKind.appPreferences:
        throw StateError('appPreferences cannot be deleted.');
    }
  }

  Future<void> _applyMeal(RemoteSyncChange change) async {
    final payload = change.payload!;
    final createdAt = _utcDateTime(payload, 'createdAtUtc');
    final updatedAt = _utcDateTime(payload, 'updatedAtUtc');
    final occurredAt = _utcDateTime(payload, 'occurredAtUtc');
    final mealType = _enumName(payload, 'type', const <String>{
      'breakfast',
      'lunch',
      'dinner',
      'snack',
    });
    final source = _enumName(payload, 'source', const <String>{
      'manual',
      'recognition',
      'recipe',
    });
    final localDay = _requiredString(payload, 'localDay');
    final timeZoneId = _requiredString(payload, 'timeZoneId');
    final withinWindow = _requiredBool(payload, 'isWithinEatingWindow');
    final items = _requiredList(payload, 'items');
    if (items.isEmpty) {
      throw const FormatException('A meal must have at least one item.');
    }
    final parsedItems = <_RemoteMealItem>[];
    final itemIds = <String>{};
    for (final value in items) {
      final item = _requiredMap(value, 'items[]');
      final parsed = _RemoteMealItem(
        id: _requiredString(item, 'id'),
        name: _requiredString(item, 'name'),
        servingMilli: _requiredInt(item, 'servingMilli'),
        energyKcal: _requiredInt(item, 'energyKcal'),
        proteinMg: _requiredInt(item, 'proteinMg'),
        carbsMg: _requiredInt(item, 'carbsMg'),
        fatMg: _requiredInt(item, 'fatMg'),
        imageReference: _safeObjectKey(item['imageReference']),
      );
      if (!itemIds.add(parsed.id)) {
        throw const FormatException('Meal item ids must be unique.');
      }
      parsedItems.add(parsed);
    }

    await _database
        .into(_database.mealLogs)
        .insertOnConflictUpdate(
          db.MealLogsCompanion.insert(
            ownerUserId: _scope.ownerUserId,
            id: change.entityId,
            mealType: mealType,
            source: source,
            occurredAtUtcMs: occurredAt.millisecondsSinceEpoch,
            timeZoneId: timeZoneId,
            localDay: localDay,
            isWithinEatingWindow: withinWindow,
            createdAtUtcMs: createdAt.millisecondsSinceEpoch,
            updatedAtUtcMs: updatedAt.millisecondsSinceEpoch,
            deletedAtUtcMs: const Value(null),
            serverVersion: Value(change.version),
          ),
        );
    await (_database.delete(_database.mealItems)..where(
          (row) =>
              row.ownerUserId.equals(_scope.ownerUserId) &
              row.mealLogId.equals(change.entityId),
        ))
        .go();
    for (final item in parsedItems) {
      await _database
          .into(_database.mealItems)
          .insert(
            db.MealItemsCompanion.insert(
              ownerUserId: _scope.ownerUserId,
              id: item.id,
              mealLogId: change.entityId,
              name: item.name,
              servingMilli: item.servingMilli,
              energyKcal: item.energyKcal,
              proteinMg: item.proteinMg,
              carbsMg: item.carbsMg,
              fatMg: item.fatMg,
              imageReference: Value(item.imageReference),
              createdAtUtcMs: createdAt.millisecondsSinceEpoch,
              updatedAtUtcMs: updatedAt.millisecondsSinceEpoch,
            ),
          );
    }
  }

  Future<void> _applyFasting(
    RemoteSyncChange change,
    List<SyncConflict> conflicts,
    Set<String> conflictKeys,
  ) async {
    final payload = change.payload!;
    final status = _enumName(payload, 'status', const <String>{
      'active',
      'completed',
      'cancelled',
    });
    final plan = _enumName(payload, 'plan', const <String>{
      'gentle',
      'balanced',
      'advanced',
    });
    final startedAt = _utcDateTime(payload, 'startedAtUtc');
    final targetEndAt = _utcDateTime(payload, 'targetEndAtUtc');
    final endedAt = _nullableUtcDateTime(payload['endedAtUtc'], 'endedAtUtc');
    final createdAt = _utcDateTime(payload, 'createdAtUtc');
    final updatedAt = _utcDateTime(payload, 'updatedAtUtc');
    final endedLocalDay = _nullableString(payload['endedLocalDay']);
    if (status == 'active' && (endedAt != null || endedLocalDay != null)) {
      throw const FormatException('An active fast cannot have end metadata.');
    }
    if (status != 'active' && (endedAt == null || endedLocalDay == null)) {
      throw const FormatException('A finished fast requires end metadata.');
    }

    if (status == 'active') {
      final other =
          await (_database.select(_database.fastingSessions)..where(
                (row) =>
                    row.ownerUserId.equals(_scope.ownerUserId) &
                    row.activeSlot.equals(1) &
                    row.id.equals(change.entityId).not(),
              ))
              .getSingleOrNull();
      if (other != null) {
        final operations = await _entityOutboxRows(
          SyncEntityKind.fastingSession,
          other.id,
        );
        if (operations.isNotEmpty) {
          await (_database.update(_database.syncOutbox)..where(
                (row) =>
                    row.ownerUserId.equals(_scope.ownerUserId) &
                    row.entityType.equals(SyncEntityKind.fastingSession.name) &
                    row.entityId.equals(other.id) &
                    row.status.equals('pending'),
              ))
              .write(
                db.SyncOutboxCompanion(
                  status: const Value('conflict'),
                  lastError: Value('pull:activeFasting:${change.entityId}'),
                ),
              );
        }
        final key = 'pull:active:${other.id}:${change.version}';
        if (conflictKeys.add(key)) {
          conflicts.add(
            SyncConflict(
              source: SyncConflictSource.pull,
              entityType: SyncEntityKind.fastingSession,
              entityId: other.id,
              serverVersion: change.version,
            ),
          );
        }
        await (_database.delete(_database.fastingSessions)..where(
              (row) =>
                  row.ownerUserId.equals(_scope.ownerUserId) &
                  row.id.equals(other.id),
            ))
            .go();
      }
    }

    await _database
        .into(_database.fastingSessions)
        .insertOnConflictUpdate(
          db.FastingSessionsCompanion.insert(
            ownerUserId: _scope.ownerUserId,
            id: change.entityId,
            plan: plan,
            status: status,
            activeSlot: Value(status == 'active' ? 1 : null),
            startedAtUtcMs: startedAt.millisecondsSinceEpoch,
            targetEndAtUtcMs: targetEndAt.millisecondsSinceEpoch,
            endedAtUtcMs: Value(endedAt?.millisecondsSinceEpoch),
            timeZoneId: _requiredString(payload, 'timeZoneId'),
            startedLocalDay: _requiredString(payload, 'startedLocalDay'),
            targetEndLocalDay: _requiredString(payload, 'targetEndLocalDay'),
            endedLocalDay: Value(endedLocalDay),
            createdAtUtcMs: createdAt.millisecondsSinceEpoch,
            updatedAtUtcMs: updatedAt.millisecondsSinceEpoch,
            serverVersion: Value(change.version),
          ),
        );
  }

  Future<void> _applyPreferences(RemoteSyncChange change) async {
    final payload = change.payload!;
    final target = _requiredInt(payload, 'dailyEnergyTargetKcal');
    if (target <= 0) {
      throw const FormatException('The energy target must be positive.');
    }
    final plan = _enumName(payload, 'selectedFastingPlan', const <String>{
      'gentle',
      'balanced',
      'advanced',
    });
    final updatedAt = _utcDateTime(payload, 'updatedAtUtc');
    await _database
        .into(_database.appPreferencesTable)
        .insertOnConflictUpdate(
          db.AppPreferencesTableCompanion.insert(
            ownerUserId: _scope.ownerUserId,
            singletonId: 1,
            dailyEnergyTargetKcal: target,
            selectedFastingPlan: plan,
            fastingReminderEnabled: _requiredBool(
              payload,
              'fastingReminderEnabled',
            ),
            updatedAtUtcMs: updatedAt.millisecondsSinceEpoch,
            serverVersion: Value(change.version),
          ),
        );
  }

  static SyncEntityKind _entityTypeFromName(String value) => switch (value) {
    'mealLog' => SyncEntityKind.mealLog,
    'fastingSession' => SyncEntityKind.fastingSession,
    'appPreferences' => SyncEntityKind.appPreferences,
    _ => throw StateError('Unknown sync entity type $value.'),
  };

  static String _enumName(
    Map<String, Object?> map,
    String key,
    Set<String> allowed,
  ) {
    final value = _requiredString(map, key);
    if (!allowed.contains(value)) {
      throw FormatException('Unknown $key value $value.');
    }
    return value;
  }

  static Map<String, Object?> _requiredMap(Object? value, String label) {
    if (value is! Map) {
      throw FormatException('$label must be an object.');
    }
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  static List<Object?> _requiredList(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! List) {
      throw FormatException('$key must be a list.');
    }
    return value.cast<Object?>();
  }

  static String _requiredString(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('$key must be a non-empty string.');
    }
    return value;
  }

  static String? _nullableString(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is! String || value.isEmpty) {
      throw const FormatException('Expected a non-empty string or null.');
    }
    return value;
  }

  static int _requiredInt(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! int) {
      throw FormatException('$key must be an integer.');
    }
    return value;
  }

  static bool _requiredBool(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! bool) {
      throw FormatException('$key must be a boolean.');
    }
    return value;
  }

  static DateTime _utcDateTime(Map<String, Object?> map, String key) {
    final value = _nullableUtcDateTime(map[key], key);
    if (value == null) {
      throw FormatException('$key must be a UTC date-time.');
    }
    return value;
  }

  static DateTime? _nullableUtcDateTime(Object? value, String label) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      if (!value.isUtc) {
        throw FormatException('$label must be UTC.');
      }
      return value;
    }
    if (value is String) {
      if (!(value.endsWith('Z') || value.endsWith('+00:00'))) {
        throw FormatException('$label must include a zero UTC offset.');
      }
      final parsed = DateTime.tryParse(value);
      if (parsed == null || !parsed.isUtc) {
        throw FormatException('$label must be a UTC date-time.');
      }
      return parsed;
    }
    throw FormatException('$label must be a UTC date-time.');
  }

  static String? _safeObjectKey(Object? value) {
    if (value is! String || value.isEmpty || value != value.trim()) {
      return null;
    }
    final lower = value.toLowerCase();
    if (value.startsWith('/') ||
        value.contains(r'\') ||
        lower.startsWith('assets/') ||
        lower.startsWith('file:') ||
        Uri.tryParse(value)?.hasScheme == true) {
      return null;
    }
    final segments = value.split('/');
    if (segments.any(
      (segment) => segment.isEmpty || segment == '.' || segment == '..',
    )) {
      return null;
    }
    return RegExp(r'^[A-Za-z0-9][A-Za-z0-9._/-]{0,511}$').hasMatch(value)
        ? value
        : null;
  }

  static String _diagnostic(Object error) {
    final value = error.toString();
    return value.length <= 500 ? value : value.substring(0, 500);
  }

  void _ensureActive() {
    if (_cancelled) {
      throw const SyncCancelledException();
    }
  }
}

final class _RemoteMealItem {
  const _RemoteMealItem({
    required this.id,
    required this.name,
    required this.servingMilli,
    required this.energyKcal,
    required this.proteinMg,
    required this.carbsMg,
    required this.fatMg,
    required this.imageReference,
  });

  final String id;
  final String name;
  final int servingMilli;
  final int energyKcal;
  final int proteinMg;
  final int carbsMg;
  final int fatMg;
  final String? imageReference;
}
