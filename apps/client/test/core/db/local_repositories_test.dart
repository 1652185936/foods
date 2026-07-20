import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/core/db/account_scope.dart';
import 'package:foods_client/core/db/app_database.dart';
import 'package:foods_client/core/id/id_generator.dart';
import 'package:foods_client/core/time/app_clock.dart';
import 'package:foods_client/core/time/time_zone_converter.dart';
import 'package:foods_client/features/fasting/data/drift_fasting_repository.dart';
import 'package:foods_client/features/fasting/domain/fasting_plan.dart';
import 'package:foods_client/features/fasting/domain/fasting_session.dart';
import 'package:foods_client/features/meals/data/drift_meal_repository.dart';
import 'package:foods_client/features/meals/domain/meal_log.dart';
import 'package:foods_client/features/profile/data/drift_preferences_repository.dart';
import 'package:foods_client/features/profile/domain/app_preferences.dart';

void main() {
  late AppDatabase database;
  late SequenceIdGenerator ids;
  final clock = FixedAppClock(DateTime.utc(2026, 7, 20, 12));
  const timeZones = IanaTimeZoneConverter();
  const scope = AccountScope.localOnly();

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    ids = SequenceIdGenerator();
  });

  tearDown(() => database.close());

  test('an empty meal day keeps the persisted energy target', () async {
    final preferences = DriftPreferencesRepository(
      database: database,
      ids: ids,
      clock: clock,
      scope: scope,
    );
    await preferences.save(const AppPreferences(dailyEnergyTargetKcal: 2250));
    final meals = DriftMealRepository(
      database: database,
      ids: ids,
      clock: clock,
      timeZones: timeZones,
      scope: scope,
    );

    final snapshot = await meals.watchDay(localDay: '2026-07-20').first;

    expect(snapshot.meals, isEmpty);
    expect(snapshot.summary.targetEnergyKcal, 2250);
  });

  test('meal rows roll back when the outbox write fails', () async {
    final repository = DriftMealRepository(
      database: database,
      ids: SequenceIdGenerator(throwAt: 3),
      clock: clock,
      timeZones: timeZones,
      scope: scope,
    );

    await expectLater(
      repository.addMeal(_draft(DateTime.utc(2026, 7, 20, 12))),
      throwsStateError,
    );

    expect(await database.select(database.mealLogs).get(), isEmpty);
    expect(await database.select(database.mealItems).get(), isEmpty);
    expect(await database.select(database.syncOutbox).get(), isEmpty);
  });

  test('meal aggregate rejects payloads the sync API cannot accept', () {
    expect(
      () => _draftWithItem(
        MealItemDraft(
          name: List<String>.filled(121, 'a').join(),
          energyKcal: 300,
        ),
      ),
      throwsA(isA<InvalidMealDraftException>()),
    );
    expect(
      () =>
          _draftWithItem(const MealItemDraft(name: 'Meal', energyKcal: 100001)),
      throwsA(isA<InvalidMealDraftException>()),
    );
    expect(
      () => _draftWithItem(
        const MealItemDraft(
          name: 'Meal',
          energyKcal: 300,
          imageReference: '../private.jpg',
        ),
      ),
      throwsA(isA<InvalidMealDraftException>()),
    );
  });

  test('preferences reject a target above the sync API maximum', () async {
    final preferences = DriftPreferencesRepository(
      database: database,
      ids: ids,
      clock: clock,
      scope: scope,
    );

    await expectLater(
      preferences.save(const AppPreferences(dailyEnergyTargetKcal: 20001)),
      throwsA(isA<InvalidPreferencesException>()),
    );
    expect(await database.select(database.syncOutbox).get(), isEmpty);
  });

  test(
    'meal insert and soft delete each enqueue an outbox operation',
    () async {
      final repository = DriftMealRepository(
        database: database,
        ids: ids,
        clock: clock,
        timeZones: timeZones,
        scope: scope,
      );
      final meal = await repository.addMeal(
        _draft(DateTime.utc(2026, 7, 20, 12)),
      );

      expect(await database.select(database.mealLogs).get(), hasLength(1));
      expect(await database.select(database.mealItems).get(), hasLength(1));
      expect(await database.select(database.syncOutbox).get(), hasLength(1));

      await repository.deleteMeal(meal.id);

      final deleted = await database.select(database.mealLogs).getSingle();
      final outbox = await database.select(database.syncOutbox).get();
      final visible = await repository.watchDay(localDay: '2026-07-20').first;
      expect(deleted.deletedAtUtcMs, isNotNull);
      expect(outbox, hasLength(2));
      expect(outbox.map((entry) => entry.action), contains('delete'));
      expect(visible.meals, isEmpty);
    },
  );

  test(
    'fasting session is recovered and completes at its exact target',
    () async {
      final repository = DriftFastingRepository(
        database: database,
        ids: ids,
        clock: clock,
        timeZones: timeZones,
        scope: scope,
      );
      final started = DateTime.utc(2026, 7, 20, 12);
      final session = await repository.start(
        plan: FastingPlan.balanced,
        nowUtc: started,
        timeZoneId: 'Asia/Shanghai',
      );
      final restartedRepository = DriftFastingRepository(
        database: database,
        ids: ids,
        clock: clock,
        timeZones: timeZones,
        scope: scope,
      );

      expect((await restartedRepository.loadActive())?.id, session.id);
      await expectLater(
        restartedRepository.start(
          plan: FastingPlan.gentle,
          nowUtc: started.add(const Duration(hours: 1)),
          timeZoneId: 'Asia/Shanghai',
        ),
        throwsA(isA<ActiveFastingSessionException>()),
      );
      expect(
        await restartedRepository.completeDue(
          nowUtc: session.targetEndAtUtc.subtract(
            const Duration(milliseconds: 1),
          ),
        ),
        isFalse,
      );
      expect(
        await restartedRepository.completeDue(nowUtc: session.targetEndAtUtc),
        isTrue,
      );
      expect(await restartedRepository.loadActive(), isNull);
      expect(
        (await restartedRepository.loadRecent()).first.status,
        FastingSessionStatus.completed,
      );
      expect(await database.select(database.syncOutbox).get(), hasLength(2));
    },
  );

  test('meal window flag uses the active session time range', () async {
    final fasting = DriftFastingRepository(
      database: database,
      ids: ids,
      clock: clock,
      timeZones: timeZones,
      scope: scope,
    );
    final started = DateTime.utc(2026, 7, 20, 12);
    final session = await fasting.start(
      plan: FastingPlan.balanced,
      nowUtc: started,
      timeZoneId: 'Asia/Shanghai',
    );
    final meals = DriftMealRepository(
      database: database,
      ids: ids,
      clock: clock,
      timeZones: timeZones,
      scope: scope,
    );

    final before = await meals.addMeal(
      _draft(started.subtract(const Duration(minutes: 1))),
    );
    final during = await meals.addMeal(
      _draft(started.add(const Duration(minutes: 1))),
    );
    final atTarget = await meals.addMeal(_draft(session.targetEndAtUtc));

    expect(before.isWithinEatingWindow, isTrue);
    expect(during.isWithinEatingWindow, isFalse);
    expect(atTarget.isWithinEatingWindow, isTrue);
  });
}

MealDraft _draft(DateTime occurredAtUtc) {
  return MealDraft(
    type: MealType.lunch,
    source: MealSource.manual,
    occurredAtUtc: occurredAtUtc,
    timeZoneId: 'Asia/Shanghai',
    localDay: '2026-07-20',
    isWithinEatingWindow: true,
    items: const <MealItemDraft>[MealItemDraft(name: '测试餐', energyKcal: 300)],
  );
}

MealDraft _draftWithItem(MealItemDraft item) => MealDraft(
  type: MealType.lunch,
  source: MealSource.manual,
  occurredAtUtc: DateTime.utc(2026, 7, 20, 12),
  timeZoneId: 'Asia/Shanghai',
  localDay: '2026-07-20',
  isWithinEatingWindow: true,
  items: <MealItemDraft>[item],
);

class SequenceIdGenerator implements IdGenerator {
  SequenceIdGenerator({this.throwAt});

  final int? throwAt;
  int _next = 1;

  @override
  String next() {
    if (_next == throwAt) {
      throw StateError('Synthetic id failure.');
    }
    return 'id-${_next++}';
  }
}
