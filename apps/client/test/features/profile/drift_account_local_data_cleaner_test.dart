import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/core/db/app_database.dart';
import 'package:foods_client/features/profile/data/drift_account_local_data_cleaner.dart';

void main() {
  late AppDatabase database;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    await database.customSelect('SELECT 1').getSingle();
    await _seedOwner(database, _ownerA, 'a');
    await _seedOwner(database, _ownerB, 'b');
  });

  tearDown(() => database.close());

  test(
    'deletes all six account-owned tables without touching another owner',
    () async {
      final cleaner = DriftAccountLocalDataCleaner(database);

      await cleaner.deleteAllForOwner(_ownerA);

      for (final table in _tables) {
        expect(
          await _ownerCount(database, table, _ownerA),
          0,
          reason: '$table must be empty for deleted owner',
        );
        expect(
          await _ownerCount(database, table, _ownerB),
          1,
          reason: '$table must preserve another owner',
        );
      }
    },
  );
}

const _ownerA = '11111111-1111-4111-8111-111111111111';
const _ownerB = '22222222-2222-4222-8222-222222222222';
const _tables = <String>[
  'meal_items',
  'meal_logs',
  'fasting_sessions',
  'app_preferences_table',
  'sync_outbox',
  'sync_state',
];

Future<int> _ownerCount(
  AppDatabase database,
  String table,
  String owner,
) async {
  final row = await database
      .customSelect(
        'SELECT COUNT(*) AS amount FROM $table WHERE owner_user_id = ?',
        variables: [Variable<String>(owner)],
      )
      .getSingle();
  return row.read<int>('amount');
}

Future<void> _seedOwner(
  AppDatabase database,
  String owner,
  String suffix,
) async {
  final mealId = 'meal-$suffix';
  const timestamp = 1753070400000;
  await database.customStatement(
    '''
      INSERT INTO meal_logs (
        owner_user_id, id, meal_type, source, occurred_at_utc_ms,
        time_zone_id, local_day, is_within_eating_window,
        created_at_utc_ms, updated_at_utc_ms, deleted_at_utc_ms, server_version
      ) VALUES (?, ?, 'lunch', 'manual', ?, 'UTC', '2026-07-21', 1, ?, ?, NULL, 1)
    ''',
    [owner, mealId, timestamp, timestamp, timestamp],
  );
  await database.customStatement(
    '''
      INSERT INTO meal_items (
        owner_user_id, id, meal_log_id, name, serving_milli, energy_kcal,
        protein_mg, carbs_mg, fat_mg, image_reference,
        created_at_utc_ms, updated_at_utc_ms
      ) VALUES (?, ?, ?, 'Meal', 1000, 300, 1000, 2000, 3000, NULL, ?, ?)
    ''',
    [owner, 'item-$suffix', mealId, timestamp, timestamp],
  );
  await database.customStatement(
    '''
      INSERT INTO fasting_sessions (
        owner_user_id, id, plan, status, active_slot, started_at_utc_ms,
        target_end_at_utc_ms, ended_at_utc_ms, time_zone_id,
        started_local_day, target_end_local_day, ended_local_day,
        created_at_utc_ms, updated_at_utc_ms, server_version
      ) VALUES (?, ?, 'balanced', 'completed', NULL, ?, ?, ?, 'UTC',
        '2026-07-20', '2026-07-21', '2026-07-21', ?, ?, 1)
    ''',
    [
      owner,
      'fast-$suffix',
      timestamp - 1000,
      timestamp,
      timestamp,
      timestamp,
      timestamp,
    ],
  );
  await database.customStatement(
    '''
      INSERT INTO app_preferences_table (
        owner_user_id, singleton_id, daily_energy_target_kcal,
        selected_fasting_plan, fasting_reminder_enabled,
        updated_at_utc_ms, server_version
      ) VALUES (?, 1, 1800, 'balanced', 0, ?, 1)
    ''',
    [owner, timestamp],
  );
  await database.customStatement(
    '''
      INSERT INTO sync_outbox (
        owner_user_id, operation_id, entity_type, entity_id, action,
        payload_version, payload_json, expected_version, status,
        attempt_count, created_at_utc_ms, next_attempt_at_utc_ms, last_error
      ) VALUES (?, ?, 'mealLog', ?, 'upsert', 1, '{}', 0, 'pending', 0, ?, NULL, NULL)
    ''',
    [owner, 'operation-$suffix', mealId, timestamp],
  );
  await database.customStatement(
    '''
      INSERT INTO sync_state (owner_user_id, cursor, updated_at_utc_ms)
      VALUES (?, 1, ?)
    ''',
    [owner, timestamp],
  );
}
