import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/core/db/database_provider.dart';
import 'package:foods_client/core/time/device_time_zone.dart';
import 'package:foods_client/core/time/local_day.dart';
import 'package:foods_client/features/fasting/application/fasting_controller.dart';
import 'package:foods_client/features/fasting/domain/fasting_plan.dart';
import 'package:foods_client/features/fasting/domain/fasting_session.dart';
import 'package:foods_client/features/meals/application/meals_controller.dart';
import 'package:foods_client/features/meals/domain/meal_log.dart';

import '../../support/test_dependencies.dart';

void main() {
  test('calendar-day shifts cross month, year, and leap-day boundaries', () {
    expect(
      shiftLocalCalendarDays(DateTime(2026, 3, 1), -1),
      DateTime(2026, 2, 28),
    );
    expect(
      shiftLocalCalendarDays(DateTime(2024, 3, 1), -1),
      DateTime(2024, 2, 29),
    );
    expect(shiftLocalCalendarDays(DateTime(2026, 12, 31), 1), DateTime(2027));
  });

  test('current meal day rolls over at the scheduled midnight', () async {
    final clock = MutableAppClock(DateTime.utc(2026, 7, 20, 15, 59, 59));
    final container = ProviderContainer.test(
      overrides: [
        appClockProvider.overrideWithValue(clock),
        currentTimeZoneIdProvider.overrideWithValue('Asia/Shanghai'),
        mealDayRolloverDelayProvider.overrideWithValue(
          (_, _) => const Duration(milliseconds: 5),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(currentMealDayProvider), DateTime(2026, 7, 20));
    clock.value = DateTime.utc(2026, 7, 20, 16);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(container.read(currentMealDayProvider), DateTime(2026, 7, 21));
  });

  test('current local day refreshes when the device IANA zone changes', () {
    final container = ProviderContainer.test(
      overrides: [
        appClockProvider.overrideWithValue(
          MutableAppClock(DateTime.utc(2026, 7, 20, 17)),
        ),
        initialTimeZoneIdProvider.overrideWithValue('UTC'),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(currentMealDayProvider), DateTime(2026, 7, 20));
    container
        .read(currentTimeZoneStateProvider.notifier)
        .updateIdentifier('Asia/Shanghai');

    expect(container.read(currentMealDayProvider), DateTime(2026, 7, 21));
  });

  test('fasting statistics resubscribe across a local week boundary', () async {
    final clock = MutableAppClock(DateTime.utc(2026, 7, 26, 23, 59, 59));
    final fasting = FakeFastingRepository();
    final container = ProviderContainer.test(
      overrides: [
        appClockProvider.overrideWithValue(clock),
        currentTimeZoneIdProvider.overrideWithValue('UTC'),
        fastingRepositoryProvider.overrideWithValue(fasting),
        mealDayRolloverDelayProvider.overrideWithValue(
          (_, _) => const Duration(milliseconds: 5),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      fastingStatisticsProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await container.read(fastingStatisticsProvider.future);
    expect(fasting.statisticsTimeZoneIds, hasLength(1));

    clock.value = DateTime.utc(2026, 7, 27);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(fasting.statisticsTimeZoneIds.length, greaterThanOrEqualTo(2));
  });

  for (final scenario in <({DateTime occurredAt, bool expected})>[
    (occurredAt: DateTime.utc(2026, 7, 20, 11), expected: true),
    (occurredAt: DateTime.utc(2026, 7, 20, 13), expected: false),
    (occurredAt: DateTime.utc(2026, 7, 21, 4), expected: true),
  ]) {
    test('meal at ${scenario.occurredAt.toIso8601String()} has '
        'eating-window=${scenario.expected}', () async {
      final repository = FakeMealRepository();
      final active = _activeSession();
      final container = ProviderContainer.test(
        overrides: [
          mealRepositoryProvider.overrideWithValue(repository),
          fastingRepositoryProvider.overrideWithValue(
            FakeFastingRepository(active: active, recent: [active]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final saved = await container
          .read(mealMutationProvider.notifier)
          .save(
            MealDraft(
              type: MealType.lunch,
              source: MealSource.manual,
              occurredAtUtc: scenario.occurredAt,
              timeZoneId: 'Asia/Shanghai',
              isWithinEatingWindow: true,
              items: const [MealItemDraft(name: '测试餐', energyKcal: 300)],
            ),
          );

      expect(saved, isTrue);
      expect(repository.meals.single.isWithinEatingWindow, scenario.expected);
    });
  }
}

FastingSession _activeSession() {
  final startedAt = DateTime.utc(2026, 7, 20, 12);
  return FastingSession(
    id: 'active-fast',
    plan: FastingPlan.balanced,
    status: FastingSessionStatus.active,
    startedAtUtc: startedAt,
    targetEndAtUtc: startedAt.add(const Duration(hours: 16)),
    timeZoneId: 'Asia/Shanghai',
    startedLocalDay: '2026-07-20',
    targetEndLocalDay: '2026-07-21',
    createdAtUtc: startedAt,
    updatedAtUtc: startedAt,
  );
}
