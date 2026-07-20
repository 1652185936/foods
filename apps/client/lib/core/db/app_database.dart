import 'package:drift/drift.dart';

import 'account_scope.dart';

part 'app_database.g.dart';

class MealLogs extends Table {
  TextColumn get ownerUserId => text()();
  TextColumn get id => text()();
  TextColumn get mealType => text()();
  TextColumn get source => text()();
  IntColumn get occurredAtUtcMs => integer()();
  TextColumn get timeZoneId => text()();
  TextColumn get localDay => text()();
  BoolColumn get isWithinEatingWindow => boolean()();
  IntColumn get createdAtUtcMs => integer()();
  IntColumn get updatedAtUtcMs => integer()();
  IntColumn get deletedAtUtcMs => integer().nullable()();
  IntColumn get serverVersion => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{ownerUserId, id};
}

class MealItems extends Table {
  TextColumn get ownerUserId => text()();
  TextColumn get id => text()();
  TextColumn get mealLogId => text()();
  TextColumn get name => text()();
  IntColumn get servingMilli => integer()();
  IntColumn get energyKcal => integer()();
  IntColumn get proteinMg => integer()();
  IntColumn get carbsMg => integer()();
  IntColumn get fatMg => integer()();
  TextColumn get imageReference => text().nullable()();
  IntColumn get createdAtUtcMs => integer()();
  IntColumn get updatedAtUtcMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{ownerUserId, id};

  @override
  List<String> get customConstraints => <String>[
    'FOREIGN KEY(owner_user_id, meal_log_id) '
        'REFERENCES meal_logs(owner_user_id, id) ON DELETE CASCADE',
  ];
}

class FastingSessions extends Table {
  TextColumn get ownerUserId => text()();
  TextColumn get id => text()();
  TextColumn get plan => text()();
  TextColumn get status => text()();
  IntColumn get activeSlot => integer().nullable()();
  IntColumn get startedAtUtcMs => integer()();
  IntColumn get targetEndAtUtcMs => integer()();
  IntColumn get endedAtUtcMs => integer().nullable()();
  TextColumn get timeZoneId => text()();
  TextColumn get startedLocalDay => text()();
  TextColumn get targetEndLocalDay => text()();
  TextColumn get endedLocalDay => text().nullable()();
  IntColumn get createdAtUtcMs => integer()();
  IntColumn get updatedAtUtcMs => integer()();
  IntColumn get serverVersion => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{ownerUserId, id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{ownerUserId, activeSlot},
  ];
}

class AppPreferencesTable extends Table {
  TextColumn get ownerUserId => text()();
  IntColumn get singletonId => integer()();
  IntColumn get dailyEnergyTargetKcal => integer()();
  TextColumn get selectedFastingPlan => text()();
  BoolColumn get fastingReminderEnabled => boolean()();
  IntColumn get updatedAtUtcMs => integer()();
  IntColumn get serverVersion => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{
    ownerUserId,
    singletonId,
  };
}

class SyncOutbox extends Table {
  TextColumn get ownerUserId => text()();
  TextColumn get operationId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get action => text()();
  IntColumn get payloadVersion => integer()();
  TextColumn get payloadJson => text()();
  IntColumn get expectedVersion => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  IntColumn get createdAtUtcMs => integer()();
  IntColumn get nextAttemptAtUtcMs => integer().nullable()();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{
    ownerUserId,
    operationId,
  };
}

class SyncState extends Table {
  TextColumn get ownerUserId => text()();
  IntColumn get cursor => integer().withDefault(const Constant(0))();
  IntColumn get updatedAtUtcMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{ownerUserId};
}

@DriftDatabase(
  tables: <Type>[
    MealLogs,
    MealItems,
    FastingSessions,
    AppPreferencesTable,
    SyncOutbox,
    SyncState,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await into(appPreferencesTable).insert(
        AppPreferencesTableCompanion.insert(
          singletonId: 1,
          ownerUserId: localOnlyOwnerUserId,
          dailyEnergyTargetKcal: 1780,
          selectedFastingPlan: 'balanced',
          fastingReminderEnabled: false,
          updatedAtUtcMs: now,
        ),
      );
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.alterTable(
          TableMigration(
            mealLogs,
            newColumns: <GeneratedColumn<Object>>[
              mealLogs.ownerUserId,
              mealLogs.serverVersion,
            ],
            columnTransformer: <GeneratedColumn<Object>, Expression<Object>>{
              mealLogs.ownerUserId: const Constant(localOnlyOwnerUserId),
              mealLogs.serverVersion: const Constant(0),
            },
          ),
        );
        await migrator.alterTable(
          TableMigration(
            mealItems,
            newColumns: <GeneratedColumn<Object>>[mealItems.ownerUserId],
            columnTransformer: <GeneratedColumn<Object>, Expression<Object>>{
              mealItems.ownerUserId: const Constant(localOnlyOwnerUserId),
            },
          ),
        );
        await migrator.alterTable(
          TableMigration(
            fastingSessions,
            newColumns: <GeneratedColumn<Object>>[
              fastingSessions.ownerUserId,
              fastingSessions.serverVersion,
            ],
            columnTransformer: <GeneratedColumn<Object>, Expression<Object>>{
              fastingSessions.ownerUserId: const Constant(localOnlyOwnerUserId),
              fastingSessions.serverVersion: const Constant(0),
            },
          ),
        );
        await migrator.alterTable(
          TableMigration(
            appPreferencesTable,
            newColumns: <GeneratedColumn<Object>>[
              appPreferencesTable.ownerUserId,
              appPreferencesTable.serverVersion,
            ],
            columnTransformer: <GeneratedColumn<Object>, Expression<Object>>{
              appPreferencesTable.ownerUserId: const Constant(
                localOnlyOwnerUserId,
              ),
              appPreferencesTable.serverVersion: const Constant(0),
            },
          ),
        );
        await migrator.alterTable(
          TableMigration(
            syncOutbox,
            newColumns: <GeneratedColumn<Object>>[
              syncOutbox.ownerUserId,
              syncOutbox.expectedVersion,
            ],
            columnTransformer: <GeneratedColumn<Object>, Expression<Object>>{
              syncOutbox.ownerUserId: const Constant(localOnlyOwnerUserId),
              syncOutbox.expectedVersion: const Constant(0),
            },
          ),
        );
        await migrator.createTable(syncState);
      }
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA busy_timeout = 5000');
    },
  );
}
