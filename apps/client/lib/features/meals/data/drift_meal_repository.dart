import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart' as db;
import '../../../core/db/account_scope.dart';
import '../../../core/db/outbox_writer.dart';
import '../../../core/id/id_generator.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/time/time_zone_converter.dart';
import '../domain/meal_log.dart' as domain;
import '../domain/meal_repository.dart';

final class DriftMealRepository implements MealRepository {
  DriftMealRepository({
    required db.AppDatabase database,
    required IdGenerator ids,
    required AppClock clock,
    required this.timeZones,
    required AccountScope scope,
  }) : _database = database,
       _ids = ids,
       _clock = clock,
       _scope = scope,
       _outbox = OutboxWriter(database, ids, clock, scope);

  final db.AppDatabase _database;
  final IdGenerator _ids;
  final AppClock _clock;
  final AccountScope _scope;
  final TimeZoneConverter timeZones;
  final OutboxWriter _outbox;

  @override
  Future<domain.MealLog> addMeal(domain.MealDraft draft) async {
    domain.validateMealDraft(draft);
    final now = _clock.now().toUtc();
    final logId = _ids.next();
    final itemIds = draft.items.map((_) => _ids.next()).toList();
    var log = domain.MealLog(
      id: logId,
      type: draft.type,
      source: draft.source,
      occurredAtUtc: draft.occurredAtUtc.toUtc(),
      timeZoneId: draft.timeZoneId,
      localDay:
          draft.localDay ??
          timeZones.localDayKeyAt(draft.occurredAtUtc, draft.timeZoneId),
      isWithinEatingWindow: draft.isWithinEatingWindow,
      items: <domain.MealItem>[
        for (var index = 0; index < draft.items.length; index++)
          domain.MealItem(
            id: itemIds[index],
            name: draft.items[index].name.trim(),
            servingMilli: draft.items[index].servingMilli,
            energyKcal: draft.items[index].energyKcal,
            proteinMg: draft.items[index].proteinMg,
            carbsMg: draft.items[index].carbsMg,
            fatMg: draft.items[index].fatMg,
            imageReference: draft.items[index].imageReference,
          ),
      ],
      createdAtUtc: now,
      updatedAtUtc: now,
      serverVersion: 0,
    );

    await _database.transaction(() async {
      final activeFast =
          await (_database.select(_database.fastingSessions)..where(
                (row) =>
                    row.ownerUserId.equals(_scope.ownerUserId) &
                    row.activeSlot.equals(1),
              ))
              .getSingleOrNull();
      final occursDuringActiveFast =
          activeFast != null &&
          log.occurredAtUtc.millisecondsSinceEpoch >=
              activeFast.startedAtUtcMs &&
          log.occurredAtUtc.millisecondsSinceEpoch <
              activeFast.targetEndAtUtcMs;
      if (occursDuringActiveFast && log.isWithinEatingWindow) {
        log = domain.MealLog(
          id: log.id,
          type: log.type,
          source: log.source,
          occurredAtUtc: log.occurredAtUtc,
          timeZoneId: log.timeZoneId,
          localDay: log.localDay,
          isWithinEatingWindow: false,
          items: log.items,
          createdAtUtc: log.createdAtUtc,
          updatedAtUtc: log.updatedAtUtc,
        );
      }
      await _database
          .into(_database.mealLogs)
          .insert(
            db.MealLogsCompanion.insert(
              ownerUserId: _scope.ownerUserId,
              id: log.id,
              mealType: log.type.name,
              source: log.source.name,
              occurredAtUtcMs: log.occurredAtUtc.millisecondsSinceEpoch,
              timeZoneId: log.timeZoneId,
              localDay: log.localDay,
              isWithinEatingWindow: log.isWithinEatingWindow,
              createdAtUtcMs: now.millisecondsSinceEpoch,
              updatedAtUtcMs: now.millisecondsSinceEpoch,
              serverVersion: const Value(0),
            ),
          );
      for (final item in log.items) {
        await _database
            .into(_database.mealItems)
            .insert(
              db.MealItemsCompanion.insert(
                ownerUserId: _scope.ownerUserId,
                id: item.id,
                mealLogId: log.id,
                name: item.name,
                servingMilli: item.servingMilli,
                energyKcal: item.energyKcal,
                proteinMg: item.proteinMg,
                carbsMg: item.carbsMg,
                fatMg: item.fatMg,
                imageReference: Value(item.imageReference),
                createdAtUtcMs: now.millisecondsSinceEpoch,
                updatedAtUtcMs: now.millisecondsSinceEpoch,
              ),
            );
      }
      await _outbox.add(
        entityType: 'mealLog',
        entityId: log.id,
        action: 'upsert',
        payload: log.toJson(),
        expectedVersion: log.serverVersion,
      );
    });
    return log;
  }

  @override
  Future<void> deleteMeal(String mealId) async {
    final now = _clock.now().toUtc();
    await _database.transaction(() async {
      final row =
          await (_database.select(_database.mealLogs)..where(
                (row) =>
                    row.ownerUserId.equals(_scope.ownerUserId) &
                    row.id.equals(mealId) &
                    row.deletedAtUtcMs.isNull(),
              ))
              .getSingleOrNull();
      if (row == null) {
        return;
      }
      await (_database.update(_database.mealLogs)..where(
            (entry) =>
                entry.ownerUserId.equals(_scope.ownerUserId) &
                entry.id.equals(mealId),
          ))
          .write(
            db.MealLogsCompanion(
              deletedAtUtcMs: Value(now.millisecondsSinceEpoch),
              updatedAtUtcMs: Value(now.millisecondsSinceEpoch),
            ),
          );
      await _outbox.add(
        entityType: 'mealLog',
        entityId: mealId,
        action: 'delete',
        payload: <String, Object?>{
          'id': mealId,
          'deletedAtUtc': now.toIso8601String(),
        },
        expectedVersion: row.serverVersion,
      );
    });
  }

  @override
  Stream<domain.MealDaySnapshot> watchDay({required String localDay}) {
    final query =
        _database.select(_database.appPreferencesTable).join(<Join>[
            leftOuterJoin(
              _database.mealLogs,
              _database.mealLogs.deletedAtUtcMs.isNull() &
                  _database.mealLogs.ownerUserId.equals(_scope.ownerUserId) &
                  _database.mealLogs.localDay.equals(localDay),
            ),
            leftOuterJoin(
              _database.mealItems,
              _database.mealItems.ownerUserId.equalsExp(
                    _database.mealLogs.ownerUserId,
                  ) &
                  _database.mealItems.mealLogId.equalsExp(
                    _database.mealLogs.id,
                  ),
            ),
          ])
          ..where(
            _database.appPreferencesTable.ownerUserId.equals(
                  _scope.ownerUserId,
                ) &
                _database.appPreferencesTable.singletonId.equals(1),
          )
          ..orderBy(<OrderingTerm>[
            OrderingTerm.desc(_database.mealLogs.occurredAtUtcMs),
          ]);

    return query.watch().map(_mapDaySnapshot);
  }

  @override
  Stream<domain.MealStatistics> watchStatistics() {
    final query = _database.select(_database.mealLogs)
      ..where(
        (row) =>
            row.ownerUserId.equals(_scope.ownerUserId) &
            row.deletedAtUtcMs.isNull(),
      );
    return query.watch().map((rows) {
      final days = <String>{for (final row in rows) row.localDay};
      return domain.MealStatistics(
        recordedDays: days.length,
        mealCount: rows.length,
      );
    });
  }

  domain.MealDaySnapshot _mapDaySnapshot(List<TypedResult> rows) {
    final grouped = <String, (db.MealLog, List<db.MealItem>)>{};
    var targetEnergyKcal = 1780;
    for (final result in rows) {
      final log = result.readTableOrNull(_database.mealLogs);
      final item = result.readTableOrNull(_database.mealItems);
      final preferences = result.readTable(_database.appPreferencesTable);
      targetEnergyKcal = preferences.dailyEnergyTargetKcal;
      if (log == null) {
        continue;
      }
      final existing = grouped[log.id];
      if (existing == null) {
        grouped[log.id] = (log, <db.MealItem>[?item]);
      } else if (item != null) {
        existing.$2.add(item);
      }
    }

    final meals = grouped.values.map((entry) => _mapMeal(entry.$1, entry.$2));
    final mealList = meals.toList(growable: false);
    var energy = 0;
    var protein = 0;
    var carbs = 0;
    var fat = 0;
    for (final meal in mealList) {
      for (final item in meal.items) {
        energy += item.energyKcal;
        protein += item.proteinMg;
        carbs += item.carbsMg;
        fat += item.fatMg;
      }
    }
    return domain.MealDaySnapshot(
      meals: mealList,
      summary: domain.DailyNutritionSummary(
        energyKcal: energy,
        proteinMg: protein,
        carbsMg: carbs,
        fatMg: fat,
        targetEnergyKcal: targetEnergyKcal,
      ),
    );
  }

  domain.MealLog _mapMeal(db.MealLog row, List<db.MealItem> items) {
    return domain.MealLog(
      id: row.id,
      type: domain.MealType.values.byName(row.mealType),
      source: domain.MealSource.values.byName(row.source),
      occurredAtUtc: DateTime.fromMillisecondsSinceEpoch(
        row.occurredAtUtcMs,
        isUtc: true,
      ),
      timeZoneId: row.timeZoneId,
      localDay: row.localDay,
      isWithinEatingWindow: row.isWithinEatingWindow,
      items: items
          .map(
            (item) => domain.MealItem(
              id: item.id,
              name: item.name,
              servingMilli: item.servingMilli,
              energyKcal: item.energyKcal,
              proteinMg: item.proteinMg,
              carbsMg: item.carbsMg,
              fatMg: item.fatMg,
              imageReference: item.imageReference,
            ),
          )
          .toList(growable: false),
      createdAtUtc: DateTime.fromMillisecondsSinceEpoch(
        row.createdAtUtcMs,
        isUtc: true,
      ),
      updatedAtUtc: DateTime.fromMillisecondsSinceEpoch(
        row.updatedAtUtcMs,
        isUtc: true,
      ),
      serverVersion: row.serverVersion,
    );
  }
}
