import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/core/db/account_scope.dart';
import 'package:foods_client/core/db/app_database.dart';
import 'package:foods_client/core/id/id_generator.dart';
import 'package:foods_client/core/time/app_clock.dart';
import 'package:foods_client/features/profile/data/drift_preferences_repository.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

const _accountA = '11111111-1111-4111-8111-111111111111';

void main() {
  test(
    'v1 data is quarantined and v2 ownership constraints are structural',
    () async {
      final directory = await Directory.systemTemp.createTemp('foods-db-v1-');
      final file = File(
        '${directory.path}${Platform.pathSeparator}foods.sqlite',
      );
      final legacy = sqlite.sqlite3.open(file.path);
      _createV1Schema(legacy);
      legacy.close();

      final database = AppDatabase(NativeDatabase(file));
      try {
        await database.customSelect('SELECT 1').getSingle();

        final meal = await database.select(database.mealLogs).getSingle();
        final item = await database.select(database.mealItems).getSingle();
        final fasting = await database
            .select(database.fastingSessions)
            .getSingle();
        final preferences = await database
            .select(database.appPreferencesTable)
            .getSingle();
        final outbox = await database.select(database.syncOutbox).getSingle();
        expect(meal.ownerUserId, localOnlyOwnerUserId);
        expect(meal.serverVersion, 0);
        expect(item.ownerUserId, localOnlyOwnerUserId);
        expect(fasting.ownerUserId, localOnlyOwnerUserId);
        expect(fasting.serverVersion, 0);
        expect(preferences.ownerUserId, localOnlyOwnerUserId);
        expect(preferences.serverVersion, 0);
        expect(outbox.ownerUserId, localOnlyOwnerUserId);
        expect(outbox.expectedVersion, 0);

        final accountPreferences = DriftPreferencesRepository(
          database: database,
          ids: _FixedIdGenerator('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
          clock: FixedAppClock(DateTime.utc(2026, 7, 20, 12)),
          scope: AccountScope.authenticated(_accountA),
        );
        final loaded = await accountPreferences.load();
        expect(loaded.dailyEnergyTargetKcal, 1780);

        final preferenceRows = await database
            .select(database.appPreferencesTable)
            .get();
        expect(preferenceRows, hasLength(2));
        expect(
          preferenceRows
              .where((row) => row.ownerUserId == localOnlyOwnerUserId)
              .single
              .dailyEnergyTargetKcal,
          2200,
        );
        expect(
          preferenceRows
              .where((row) => row.ownerUserId == _accountA)
              .single
              .dailyEnergyTargetKcal,
          1780,
        );
        final accountOutbox = await (database.select(
          database.syncOutbox,
        )..where((row) => row.ownerUserId.equals(_accountA))).getSingle();
        expect(accountOutbox.entityType, 'appPreferences');
      } finally {
        await database.close();
      }

      final migrated = sqlite.sqlite3.open(file.path);
      try {
        expect(migrated.userVersion, 2);
        _expectOwnerWithoutDefault(migrated, 'meal_logs');
        _expectOwnerWithoutDefault(migrated, 'meal_items');
        _expectOwnerWithoutDefault(migrated, 'fasting_sessions');
        _expectOwnerWithoutDefault(migrated, 'app_preferences_table');
        _expectOwnerWithoutDefault(migrated, 'sync_outbox');
        _expectOwnerWithoutDefault(migrated, 'sync_state');
        _expectCompositePrimaryKey(migrated, 'meal_logs', const <String>[
          'owner_user_id',
          'id',
        ]);
        _expectCompositePrimaryKey(migrated, 'meal_items', const <String>[
          'owner_user_id',
          'id',
        ]);
        _expectCompositeMealForeignKey(migrated);
        _expectPerOwnerActiveIndex(migrated);
      } finally {
        migrated.close();
        await directory.delete(recursive: true);
      }
    },
  );
}

void _createV1Schema(sqlite.Database database) {
  database.execute('''
    PRAGMA user_version = 1;
    CREATE TABLE meal_logs (
      id TEXT NOT NULL PRIMARY KEY,
      meal_type TEXT NOT NULL,
      source TEXT NOT NULL,
      occurred_at_utc_ms INTEGER NOT NULL,
      time_zone_id TEXT NOT NULL,
      local_day TEXT NOT NULL,
      is_within_eating_window INTEGER NOT NULL,
      created_at_utc_ms INTEGER NOT NULL,
      updated_at_utc_ms INTEGER NOT NULL,
      deleted_at_utc_ms INTEGER NULL
    );
    CREATE TABLE meal_items (
      id TEXT NOT NULL PRIMARY KEY,
      meal_log_id TEXT NOT NULL REFERENCES meal_logs(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      serving_milli INTEGER NOT NULL,
      energy_kcal INTEGER NOT NULL,
      protein_mg INTEGER NOT NULL,
      carbs_mg INTEGER NOT NULL,
      fat_mg INTEGER NOT NULL,
      image_reference TEXT NULL,
      created_at_utc_ms INTEGER NOT NULL,
      updated_at_utc_ms INTEGER NOT NULL
    );
    CREATE TABLE fasting_sessions (
      id TEXT NOT NULL PRIMARY KEY,
      plan TEXT NOT NULL,
      status TEXT NOT NULL,
      active_slot INTEGER NULL UNIQUE,
      started_at_utc_ms INTEGER NOT NULL,
      target_end_at_utc_ms INTEGER NOT NULL,
      ended_at_utc_ms INTEGER NULL,
      time_zone_id TEXT NOT NULL,
      started_local_day TEXT NOT NULL,
      target_end_local_day TEXT NOT NULL,
      ended_local_day TEXT NULL,
      created_at_utc_ms INTEGER NOT NULL,
      updated_at_utc_ms INTEGER NOT NULL
    );
    CREATE TABLE app_preferences_table (
      singleton_id INTEGER NOT NULL PRIMARY KEY,
      daily_energy_target_kcal INTEGER NOT NULL,
      selected_fasting_plan TEXT NOT NULL,
      fasting_reminder_enabled INTEGER NOT NULL,
      updated_at_utc_ms INTEGER NOT NULL
    );
    CREATE TABLE sync_outbox (
      operation_id TEXT NOT NULL PRIMARY KEY,
      entity_type TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      action TEXT NOT NULL,
      payload_version INTEGER NOT NULL,
      payload_json TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending',
      attempt_count INTEGER NOT NULL DEFAULT 0,
      created_at_utc_ms INTEGER NOT NULL,
      next_attempt_at_utc_ms INTEGER NULL,
      last_error TEXT NULL
    );
    INSERT INTO meal_logs VALUES (
      'meal-legacy', 'lunch', 'manual', 1753012800000, 'UTC',
      '2026-07-20', 1, 1753012800000, 1753012800000, NULL
    );
    INSERT INTO meal_items VALUES (
      'item-legacy', 'meal-legacy', 'Legacy meal', 1000, 300,
      1000, 2000, 3000, NULL, 1753012800000, 1753012800000
    );
    INSERT INTO fasting_sessions VALUES (
      'fast-legacy', 'balanced', 'active', 1, 1753012800000,
      1753070400000, NULL, 'UTC', '2026-07-20', '2026-07-21',
      NULL, 1753012800000, 1753012800000
    );
    INSERT INTO app_preferences_table VALUES (
      1, 2200, 'balanced', 1, 1753012800000
    );
    INSERT INTO sync_outbox VALUES (
      'operation-legacy', 'mealLog', 'meal-legacy', 'upsert', 1,
      '{}', 'pending', 0, 1753012800000, NULL, NULL
    );
  ''');
}

void _expectOwnerWithoutDefault(sqlite.Database database, String table) {
  final row = database
      .select('PRAGMA table_info($table)')
      .singleWhere((entry) => entry['name'] == 'owner_user_id');
  expect(row['notnull'], 1, reason: '$table.owner_user_id must be required');
  expect(row['dflt_value'], isNull, reason: '$table must fail closed');
}

void _expectCompositePrimaryKey(
  sqlite.Database database,
  String table,
  List<String> expected,
) {
  final primary =
      database
          .select('PRAGMA table_info($table)')
          .where((row) => (row['pk']! as int) > 0)
          .toList()
        ..sort(
          (left, right) => (left['pk']! as int).compareTo(right['pk']! as int),
        );
  expect(primary.map((row) => row['name']).toList(), expected);
}

void _expectCompositeMealForeignKey(sqlite.Database database) {
  final rows = database
      .select('PRAGMA foreign_key_list(meal_items)')
      .where((row) => row['table'] == 'meal_logs')
      .toList();
  expect(rows, hasLength(2));
  expect(rows.map((row) => row['id']).toSet(), hasLength(1));
  expect(
    <String, String>{
      for (final row in rows) row['from']! as String: row['to']! as String,
    },
    <String, String>{'owner_user_id': 'owner_user_id', 'meal_log_id': 'id'},
  );
  expect(rows.map((row) => row['on_delete']).toSet(), <Object?>{'CASCADE'});
}

void _expectPerOwnerActiveIndex(sqlite.Database database) {
  final indexes = database
      .select('PRAGMA index_list(fasting_sessions)')
      .where((row) => row['unique'] == 1);
  final matches = indexes.where((index) {
    final name = index['name']! as String;
    final columns = database
        .select('PRAGMA index_info("$name")')
        .map((row) => row['name'])
        .toList();
    return columns.length == 2 &&
        columns.contains('owner_user_id') &&
        columns.contains('active_slot');
  });
  expect(matches, hasLength(1));
}

final class _FixedIdGenerator implements IdGenerator {
  const _FixedIdGenerator(this.value);

  final String value;

  @override
  String next() => value;
}
