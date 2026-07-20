enum SyncEntityKind { mealLog, fastingSession, appPreferences }

enum SyncOperationAction { upsert, delete }

enum SyncWriteDisposition {
  applied,
  versionConflict,
  notFound,
  idempotencyConflict,
  activeFastingConflict,
  unknown,
}

final class PendingSyncOperation {
  PendingSyncOperation({
    required this.operationId,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.expectedVersion,
    required this.payloadVersion,
    required Map<String, Object?>? payload,
  }) : payload = payload == null
           ? null
           : Map<String, Object?>.unmodifiable(payload);

  final String operationId;
  final SyncEntityKind entityType;
  final String entityId;
  final SyncOperationAction action;
  final int expectedVersion;
  final int payloadVersion;
  final Map<String, Object?>? payload;
}

final class SyncWriteReceipt {
  const SyncWriteReceipt({
    required this.operationId,
    required this.entityType,
    required this.entityId,
    required this.disposition,
    required this.replayed,
    this.serverVersion,
    this.changeCursor,
  });

  final String operationId;
  final SyncEntityKind entityType;
  final String entityId;
  final SyncWriteDisposition disposition;
  final bool replayed;
  final int? serverVersion;
  final int? changeCursor;
}

final class RemoteSyncChange {
  RemoteSyncChange({
    required this.changeCursor,
    required this.entityType,
    required this.entityId,
    required this.version,
    required this.deletedAtUtc,
    required Map<String, Object?>? payload,
  }) : payload = payload == null
           ? null
           : Map<String, Object?>.unmodifiable(payload);

  final int changeCursor;
  final SyncEntityKind entityType;
  final String entityId;
  final int version;
  final DateTime? deletedAtUtc;
  final Map<String, Object?>? payload;

  bool get isTombstone => deletedAtUtc != null;
}

final class SyncPullPage {
  SyncPullPage({
    required List<RemoteSyncChange> changes,
    required this.nextCursor,
    required this.hasMore,
  }) : changes = List<RemoteSyncChange>.unmodifiable(changes);

  final List<RemoteSyncChange> changes;
  final int nextCursor;
  final bool hasMore;
}

enum SyncConflictSource { push, pull }

final class SyncConflict {
  const SyncConflict({
    required this.source,
    required this.entityType,
    required this.entityId,
    required this.serverVersion,
    this.operationId,
    this.disposition,
  });

  final SyncConflictSource source;
  final SyncEntityKind entityType;
  final String entityId;
  final int? serverVersion;
  final String? operationId;
  final SyncWriteDisposition? disposition;
}

final class SyncRunResult {
  SyncRunResult({
    required this.pushedOperations,
    required this.pulledChanges,
    required this.cursor,
    required List<SyncConflict> conflicts,
  }) : conflicts = List<SyncConflict>.unmodifiable(conflicts);

  final int pushedOperations;
  final int pulledChanges;
  final int cursor;
  final List<SyncConflict> conflicts;
}
