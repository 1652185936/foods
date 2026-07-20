import 'package:drift/drift.dart';

import '../../../core/db/account_scope.dart';
import '../../../core/db/app_database.dart' as db;
import '../../../core/db/outbox_writer.dart';
import '../../../core/id/id_generator.dart';
import '../../../core/time/app_clock.dart';
import '../../fasting/domain/fasting_plan.dart';
import '../domain/app_preferences.dart';
import '../domain/preferences_repository.dart';

final class DriftPreferencesRepository implements PreferencesRepository {
  DriftPreferencesRepository({
    required db.AppDatabase database,
    required IdGenerator ids,
    required AppClock clock,
    required AccountScope scope,
  }) : _database = database,
       _clock = clock,
       _scope = scope,
       _outbox = OutboxWriter(database, ids, clock, scope);

  final db.AppDatabase _database;
  final AppClock _clock;
  final AccountScope _scope;
  final OutboxWriter _outbox;

  @override
  Future<AppPreferences> load() async {
    final row =
        await (_database.select(_database.appPreferencesTable)..where(
              (entry) =>
                  entry.ownerUserId.equals(_scope.ownerUserId) &
                  entry.singletonId.equals(1),
            ))
            .getSingleOrNull();
    if (row != null) {
      return _map(row);
    }
    const defaults = AppPreferences();
    await save(defaults);
    return defaults;
  }

  @override
  Future<void> save(AppPreferences preferences) async {
    if (preferences.dailyEnergyTargetKcal <= 0 ||
        preferences.dailyEnergyTargetKcal > 20000) {
      throw const InvalidPreferencesException();
    }
    final now = _clock.now().toUtc();
    await _database.transaction(() async {
      final existing =
          await (_database.select(_database.appPreferencesTable)..where(
                (entry) =>
                    entry.ownerUserId.equals(_scope.ownerUserId) &
                    entry.singletonId.equals(1),
              ))
              .getSingleOrNull();
      final expectedVersion =
          existing?.serverVersion ?? preferences.serverVersion;
      await _database
          .into(_database.appPreferencesTable)
          .insertOnConflictUpdate(
            db.AppPreferencesTableCompanion.insert(
              ownerUserId: _scope.ownerUserId,
              singletonId: 1,
              dailyEnergyTargetKcal: preferences.dailyEnergyTargetKcal,
              selectedFastingPlan: preferences.selectedFastingPlan.name,
              fastingReminderEnabled: preferences.fastingReminderEnabled,
              updatedAtUtcMs: now.millisecondsSinceEpoch,
              serverVersion: Value(expectedVersion),
            ),
          );
      await _outbox.add(
        entityType: 'appPreferences',
        entityId: 'current',
        action: 'upsert',
        payload: preferences.toJson(),
        expectedVersion: expectedVersion,
      );
    });
  }

  @override
  Stream<AppPreferences> watch() {
    final query = _database.select(_database.appPreferencesTable)
      ..where(
        (entry) =>
            entry.ownerUserId.equals(_scope.ownerUserId) &
            entry.singletonId.equals(1),
      );
    return query.watchSingleOrNull().map(
      (row) => row == null ? const AppPreferences() : _map(row),
    );
  }

  AppPreferences _map(db.AppPreferencesTableData row) {
    return AppPreferences(
      dailyEnergyTargetKcal: row.dailyEnergyTargetKcal,
      selectedFastingPlan: FastingPlan.values.byName(row.selectedFastingPlan),
      fastingReminderEnabled: row.fastingReminderEnabled,
      serverVersion: row.serverVersion,
    );
  }
}

final class InvalidPreferencesException implements Exception {
  const InvalidPreferencesException();
}
