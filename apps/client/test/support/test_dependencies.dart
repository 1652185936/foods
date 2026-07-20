import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foods_client/core/db/database_provider.dart';
import 'package:foods_client/core/platform/notification_service.dart';
import 'package:foods_client/core/sync/connectivity_signal_source.dart';
import 'package:foods_client/core/sync/sync_coordinator.dart';
import 'package:foods_client/core/sync/sync_models.dart';
import 'package:foods_client/core/sync/sync_runner.dart';
import 'package:foods_client/core/time/app_clock.dart';
import 'package:foods_client/features/fasting/domain/fasting_plan.dart';
import 'package:foods_client/features/fasting/domain/fasting_repository.dart';
import 'package:foods_client/features/fasting/domain/fasting_session.dart';
import 'package:foods_client/features/meals/domain/meal_log.dart';
import 'package:foods_client/features/meals/domain/meal_repository.dart';
import 'package:foods_client/features/profile/domain/app_preferences.dart';
import 'package:foods_client/features/profile/domain/preferences_repository.dart';

ProviderScope testProviderScope({
  required Widget child,
  FakeMealRepository? meals,
  FakeFastingRepository? fasting,
  FakePreferencesRepository? preferences,
  AppClock? clock,
  AccountSyncRunner? syncRunner,
  ConnectivitySignalSource? connectivity,
  NotificationService? notifications,
}) {
  return ProviderScope(
    overrides: [
      mealRepositoryProvider.overrideWithValue(meals ?? FakeMealRepository()),
      fastingRepositoryProvider.overrideWithValue(
        fasting ?? FakeFastingRepository(),
      ),
      preferencesRepositoryProvider.overrideWithValue(
        preferences ?? FakePreferencesRepository(),
      ),
      appClockProvider.overrideWithValue(
        clock ?? MutableAppClock(DateTime.utc(2026, 7, 20, 8)),
      ),
      currentTimeZoneIdProvider.overrideWithValue('Asia/Shanghai'),
      accountSyncRunnerProvider.overrideWithValue(
        syncRunner ?? FakeAccountSyncRunner(),
      ),
      connectivitySignalSourceProvider.overrideWithValue(
        connectivity ?? const FakeConnectivitySignalSource(),
      ),
      notificationServiceProvider.overrideWithValue(
        notifications ?? const NoopNotificationService(),
      ),
      syncRetryDelaysProvider.overrideWithValue(const <Duration>[]),
    ],
    child: child,
  );
}

class FakeAccountSyncRunner implements AccountSyncRunner {
  FakeAccountSyncRunner({this.conflictCount = 0});

  final int conflictCount;
  int runCalls = 0;
  int cancelCalls = 0;

  @override
  void cancel() => cancelCalls++;

  @override
  Future<int> countConflicts() async => conflictCount;

  @override
  Future<SyncRunResult> run() async {
    runCalls++;
    return SyncRunResult(
      pushedOperations: 0,
      pulledChanges: 0,
      cursor: 0,
      conflicts: const <SyncConflict>[],
    );
  }
}

class FakeConnectivitySignalSource implements ConnectivitySignalSource {
  const FakeConnectivitySignalSource({this.connected = true});

  final bool connected;

  @override
  Stream<bool> get changes => const Stream<bool>.empty();

  @override
  Future<bool> isConnected() async => connected;
}

class MutableAppClock implements AppClock {
  MutableAppClock(this.value);

  DateTime value;

  @override
  DateTime now() => value;
}

class FakeMealRepository implements MealRepository {
  final _dayController = StreamController<MealDaySnapshot>.broadcast();
  final _statisticsController = StreamController<MealStatistics>.broadcast();
  final List<MealLog> meals = <MealLog>[];
  int _nextId = 1;

  @override
  Future<MealLog> addMeal(MealDraft draft) async {
    final id = 'meal-${_nextId++}';
    final log = MealLog(
      id: id,
      type: draft.type,
      source: draft.source,
      occurredAtUtc: draft.occurredAtUtc,
      timeZoneId: draft.timeZoneId,
      localDay: draft.localDay ?? '2026-07-20',
      isWithinEatingWindow: draft.isWithinEatingWindow,
      items: [
        for (var index = 0; index < draft.items.length; index++)
          MealItem(
            id: '$id-item-$index',
            name: draft.items[index].name,
            servingMilli: draft.items[index].servingMilli,
            energyKcal: draft.items[index].energyKcal,
            proteinMg: draft.items[index].proteinMg,
            carbsMg: draft.items[index].carbsMg,
            fatMg: draft.items[index].fatMg,
            imageReference: draft.items[index].imageReference,
          ),
      ],
      createdAtUtc: draft.occurredAtUtc,
      updatedAtUtc: draft.occurredAtUtc,
    );
    meals.add(log);
    _emit();
    return log;
  }

  @override
  Future<void> deleteMeal(String mealId) async {
    meals.removeWhere((meal) => meal.id == mealId);
    _emit();
  }

  @override
  Stream<MealDaySnapshot> watchDay({required String localDay}) async* {
    yield _snapshot();
    yield* _dayController.stream;
  }

  @override
  Stream<MealStatistics> watchStatistics() async* {
    yield _statistics();
    yield* _statisticsController.stream;
  }

  MealDaySnapshot _snapshot() {
    var energy = 0;
    var protein = 0;
    var carbs = 0;
    var fat = 0;
    for (final meal in meals) {
      for (final item in meal.items) {
        energy += item.energyKcal;
        protein += item.proteinMg;
        carbs += item.carbsMg;
        fat += item.fatMg;
      }
    }
    return MealDaySnapshot(
      meals: meals,
      summary: DailyNutritionSummary(
        energyKcal: energy,
        proteinMg: protein,
        carbsMg: carbs,
        fatMg: fat,
      ),
    );
  }

  MealStatistics _statistics() => MealStatistics(
    recordedDays: meals.map((meal) => meal.localDay).toSet().length,
    mealCount: meals.length,
  );

  void _emit() {
    _dayController.add(_snapshot());
    _statisticsController.add(_statistics());
  }
}

class FakeFastingRepository implements FastingRepository {
  FakeFastingRepository({
    this.active,
    List<FastingSession> recent = const <FastingSession>[],
    this.statistics = const FastingStatistics(),
    this.startGate,
  }) : recent = List<FastingSession>.of(recent);

  FastingSession? active;
  final List<FastingSession> recent;
  FastingStatistics statistics;
  final Completer<void>? startGate;
  int _nextId = 1;
  int completeDueCalls = 0;
  int startCalls = 0;
  final List<String> statisticsTimeZoneIds = <String>[];
  final _statisticsController = StreamController<FastingStatistics>.broadcast();

  @override
  Future<void> cancelActive({required DateTime nowUtc}) async {
    final session = active;
    if (session == null) {
      return;
    }
    recent.removeWhere((item) => item.id == session.id);
    recent.insert(
      0,
      _copySession(
        session,
        status: FastingSessionStatus.cancelled,
        endedAtUtc: nowUtc,
      ),
    );
    active = null;
  }

  @override
  Future<bool> completeDue({required DateTime nowUtc}) async {
    completeDueCalls++;
    final session = active;
    if (session == null || session.targetEndAtUtc.isAfter(nowUtc)) {
      return false;
    }
    recent.removeWhere((item) => item.id == session.id);
    recent.insert(
      0,
      _copySession(
        session,
        status: FastingSessionStatus.completed,
        endedAtUtc: session.targetEndAtUtc,
      ),
    );
    active = null;
    statistics = FastingStatistics(
      completedCount: statistics.completedCount + 1,
      completedThisWeek: statistics.completedThisWeek + 1,
      currentStreak: statistics.currentStreak + 1,
      completionRatePercent: 100,
    );
    _statisticsController.add(statistics);
    return true;
  }

  @override
  Future<FastingSession?> loadActive() async => active;

  @override
  Future<List<FastingSession>> loadRecent({int limit = 30}) async =>
      recent.take(limit).toList(growable: false);

  @override
  Future<FastingSession> start({
    required FastingPlan plan,
    required DateTime nowUtc,
    required String timeZoneId,
  }) async {
    startCalls++;
    await startGate?.future;
    if (active != null) {
      throw StateError('A fast is already active.');
    }
    final id = 'fast-${_nextId++}';
    active = FastingSession(
      id: id,
      plan: plan,
      status: FastingSessionStatus.active,
      startedAtUtc: nowUtc,
      targetEndAtUtc: nowUtc.add(plan.fastingDuration),
      timeZoneId: timeZoneId,
      startedLocalDay: '2026-07-20',
      targetEndLocalDay: '2026-07-21',
      createdAtUtc: nowUtc,
      updatedAtUtc: nowUtc,
    );
    recent.insert(0, active!);
    return active!;
  }

  @override
  Stream<FastingStatistics> watchStatistics({
    required String timeZoneId,
  }) async* {
    statisticsTimeZoneIds.add(timeZoneId);
    yield statistics;
    yield* _statisticsController.stream;
  }

  FastingSession _copySession(
    FastingSession source, {
    required FastingSessionStatus status,
    required DateTime endedAtUtc,
  }) {
    return FastingSession(
      id: source.id,
      plan: source.plan,
      status: status,
      startedAtUtc: source.startedAtUtc,
      targetEndAtUtc: source.targetEndAtUtc,
      timeZoneId: source.timeZoneId,
      startedLocalDay: source.startedLocalDay,
      targetEndLocalDay: source.targetEndLocalDay,
      endedLocalDay: source.targetEndLocalDay,
      endedAtUtc: endedAtUtc,
      createdAtUtc: source.createdAtUtc,
      updatedAtUtc: endedAtUtc,
    );
  }
}

class FakePreferencesRepository implements PreferencesRepository {
  FakePreferencesRepository([this.current = const AppPreferences()]);

  AppPreferences current;
  final _controller = StreamController<AppPreferences>.broadcast();

  @override
  Future<AppPreferences> load() async => current;

  @override
  Future<void> save(AppPreferences preferences) async {
    current = preferences;
    _controller.add(preferences);
  }

  @override
  Stream<AppPreferences> watch() async* {
    yield current;
    yield* _controller.stream;
  }
}
