import 'dart:convert';

import 'package:drift/drift.dart';

import '../id/id_generator.dart';
import '../time/app_clock.dart';
import 'account_scope.dart';
import 'app_database.dart';

final class OutboxWriter {
  const OutboxWriter(this._database, this._ids, this._clock, this._scope);

  final AppDatabase _database;
  final IdGenerator _ids;
  final AppClock _clock;
  final AccountScope _scope;

  Future<void> add({
    required String entityType,
    required String entityId,
    required String action,
    required Map<String, Object?> payload,
    required int expectedVersion,
    int payloadVersion = 1,
  }) {
    if (expectedVersion < 0) {
      throw ArgumentError.value(expectedVersion, 'expectedVersion');
    }
    return _database
        .into(_database.syncOutbox)
        .insert(
          SyncOutboxCompanion.insert(
            ownerUserId: _scope.ownerUserId,
            operationId: _ids.next(),
            entityType: entityType,
            entityId: entityId,
            action: action,
            payloadVersion: payloadVersion,
            payloadJson: jsonEncode(payload),
            expectedVersion: Value(expectedVersion),
            createdAtUtcMs: _clock.now().toUtc().millisecondsSinceEpoch,
          ),
        );
  }
}
