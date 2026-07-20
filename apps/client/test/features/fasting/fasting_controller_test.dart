import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/core/db/database_provider.dart';
import 'package:foods_client/core/platform/notification_service.dart';
import 'package:foods_client/features/fasting/application/fasting_controller.dart';
import 'package:foods_client/features/fasting/domain/fasting_plan.dart';
import 'package:foods_client/features/fasting/domain/fasting_session.dart';
import 'package:foods_client/features/profile/domain/app_preferences.dart';

import '../../support/test_dependencies.dart';

void main() {
  group('FastingPlan', () {
    const expectations = <FastingPlan, (String, Duration, Duration)>{
      FastingPlan.gentle: ('14:10', Duration(hours: 14), Duration(hours: 10)),
      FastingPlan.balanced: ('16:8', Duration(hours: 16), Duration(hours: 8)),
      FastingPlan.advanced: ('18:6', Duration(hours: 18), Duration(hours: 6)),
    };

    for (final entry in expectations.entries) {
      test('${entry.value.$1} has the configured durations', () {
        expect(entry.key.label, entry.value.$1);
        expect(entry.key.fastingDuration, entry.value.$2);
        expect(entry.key.eatingDuration, entry.value.$3);
      });
    }
  });

  test('start persists the selected plan and derives its target', () async {
    final clock = MutableAppClock(DateTime.utc(2026, 7, 20, 8, 30));
    final repository = FakeFastingRepository();
    final preferences = FakePreferencesRepository();
    final container = _container(clock, repository, preferences);
    addTearDown(container.dispose);
    await container.read(fastingProvider.future);

    expect(
      await container
          .read(fastingProvider.notifier)
          .selectPlan(FastingPlan.advanced),
      FastingMutationResult.applied,
    );
    expect(
      await container.read(fastingProvider.notifier).start(),
      FastingMutationResult.applied,
    );

    final state = container.read(fastingProvider).asData!.value;
    expect(state.plan, FastingPlan.advanced);
    expect(state.activeSession!.startedAtUtc, clock.value);
    expect(
      state.activeSession!.targetEndAtUtc,
      DateTime.utc(2026, 7, 21, 2, 30),
    );
    expect(preferences.current.selectedFastingPlan, FastingPlan.advanced);
  });

  test('completeIfNeeded keeps a session active before the target', () async {
    final startedAt = DateTime.utc(2026, 7, 20, 8, 30);
    final clock = MutableAppClock(startedAt);
    final repository = FakeFastingRepository();
    final container = _container(
      clock,
      repository,
      FakePreferencesRepository(),
    );
    addTearDown(container.dispose);
    await container.read(fastingProvider.future);
    await container.read(fastingProvider.notifier).start();

    clock.value = startedAt.add(
      const Duration(hours: 15, minutes: 59, seconds: 59),
    );
    final completed = await container
        .read(fastingProvider.notifier)
        .completeIfNeeded();

    expect(completed, isFalse);
    expect(container.read(fastingProvider).asData!.value.isActive, isTrue);
  });

  for (final offset in <Duration>[Duration.zero, const Duration(seconds: 1)]) {
    test('completeIfNeeded completes at or after the target '
        '(${offset.inSeconds} second offset)', () async {
      final startedAt = DateTime.utc(2026, 7, 20, 8, 30);
      final clock = MutableAppClock(startedAt);
      final repository = FakeFastingRepository();
      final container = _container(
        clock,
        repository,
        FakePreferencesRepository(),
      );
      addTearDown(container.dispose);
      await container.read(fastingProvider.future);
      await container.read(fastingProvider.notifier).start();

      clock.value = startedAt
          .add(FastingPlan.balanced.fastingDuration)
          .add(offset);
      final completed = await container
          .read(fastingProvider.notifier)
          .completeIfNeeded();

      expect(completed, isTrue);
      expect(container.read(fastingProvider).asData!.value.isActive, isFalse);
      expect(repository.recent.first.status, FastingSessionStatus.completed);
    });
  }

  test('build restores an active session from the repository', () async {
    final now = DateTime.utc(2026, 7, 20, 12);
    final session = FastingSession(
      id: 'persisted-fast',
      plan: FastingPlan.gentle,
      status: FastingSessionStatus.active,
      startedAtUtc: now.subtract(const Duration(hours: 2)),
      targetEndAtUtc: now.add(const Duration(hours: 12)),
      timeZoneId: 'Asia/Shanghai',
      startedLocalDay: '2026-07-20',
      targetEndLocalDay: '2026-07-21',
      createdAtUtc: now.subtract(const Duration(hours: 2)),
      updatedAtUtc: now.subtract(const Duration(hours: 2)),
    );
    final repository = FakeFastingRepository(
      active: session,
      recent: <FastingSession>[session],
    );
    final container = _container(
      MutableAppClock(now),
      repository,
      FakePreferencesRepository(
        const AppPreferences(selectedFastingPlan: FastingPlan.gentle),
      ),
    );
    addTearDown(container.dispose);

    final restored = await container.read(fastingProvider.future);

    expect(restored.activeSession?.id, 'persisted-fast');
    expect(restored.remainingAt(now), const Duration(hours: 12));
  });

  test(
    'cold-start restoration never requests notification permission',
    () async {
      final now = DateTime.utc(2026, 7, 20, 12);
      final session = FastingSession(
        id: 'persisted-fast',
        plan: FastingPlan.gentle,
        status: FastingSessionStatus.active,
        startedAtUtc: now.subtract(const Duration(hours: 2)),
        targetEndAtUtc: now.add(const Duration(hours: 12)),
        timeZoneId: 'Asia/Shanghai',
        startedLocalDay: '2026-07-20',
        targetEndLocalDay: '2026-07-21',
        createdAtUtc: now.subtract(const Duration(hours: 2)),
        updatedAtUtc: now.subtract(const Duration(hours: 2)),
      );
      final notifications = _RecordingNotificationService();
      final container = _container(
        MutableAppClock(now),
        FakeFastingRepository(
          active: session,
          recent: <FastingSession>[session],
        ),
        FakePreferencesRepository(
          const AppPreferences(fastingReminderEnabled: true),
        ),
        notificationService: notifications,
      );
      addTearDown(container.dispose);

      await container.read(fastingProvider.future);

      expect(notifications.sessions, <FastingSession?>[session]);
      expect(notifications.permissionRequests, <bool>[false]);
    },
  );

  test('starting an enabled reminder requests permission once', () async {
    final notifications = _RecordingNotificationService();
    final container = _container(
      MutableAppClock(DateTime.utc(2026, 7, 20, 8, 30)),
      FakeFastingRepository(),
      FakePreferencesRepository(
        const AppPreferences(fastingReminderEnabled: true),
      ),
      notificationService: notifications,
    );
    addTearDown(container.dispose);
    await container.read(fastingProvider.future);
    notifications.reset();

    expect(
      await container.read(fastingProvider.notifier).start(),
      FastingMutationResult.applied,
    );

    expect(notifications.permissionRequests, <bool>[true, false]);
    expect(notifications.sessions, hasLength(2));
  });

  test(
    'starting with reminders disabled only clears stale schedules',
    () async {
      final notifications = _RecordingNotificationService();
      final container = _container(
        MutableAppClock(DateTime.utc(2026, 7, 20, 8, 30)),
        FakeFastingRepository(),
        FakePreferencesRepository(
          const AppPreferences(fastingReminderEnabled: false),
        ),
        notificationService: notifications,
      );
      addTearDown(container.dispose);
      await container.read(fastingProvider.future);
      notifications.reset();

      expect(
        await container.read(fastingProvider.notifier).start(),
        FastingMutationResult.applied,
      );

      expect(notifications.sessions, isEmpty);
      expect(notifications.cancelCalls, 2);
    },
  );

  test('rapid start attempts run one mutation and expose busy state', () async {
    final gate = Completer<void>();
    final repository = FakeFastingRepository(startGate: gate);
    final container = _container(
      MutableAppClock(DateTime.utc(2026, 7, 20, 8, 30)),
      repository,
      FakePreferencesRepository(),
    );
    addTearDown(container.dispose);
    await container.read(fastingProvider.future);

    final first = container.read(fastingProvider.notifier).start();
    expect(container.read(fastingProvider).asData!.value.isMutating, isTrue);

    final repeated = await container.read(fastingProvider.notifier).start();
    expect(repeated, FastingMutationResult.ignored);
    expect(repository.startCalls, 1);

    gate.complete();
    expect(await first, FastingMutationResult.applied);
    expect(container.read(fastingProvider).asData!.value.isMutating, isFalse);
    expect(repository.startCalls, 1);
  });

  test(
    'notification failure never rolls back or misreports a started fast',
    () async {
      final repository = FakeFastingRepository();
      final container = _container(
        MutableAppClock(DateTime.utc(2026, 7, 20, 8, 30)),
        repository,
        FakePreferencesRepository(),
        notificationService: _ThrowingNotificationService(),
      );
      addTearDown(container.dispose);
      await container.read(fastingProvider.future);

      final result = await container.read(fastingProvider.notifier).start();

      expect(result, FastingMutationResult.applied);
      expect(repository.active, isNotNull);
      expect(container.read(fastingProvider).asData?.value.isActive, isTrue);
    },
  );

  test(
    'notification failure does not prevent cold-start restoration',
    () async {
      final now = DateTime.utc(2026, 7, 20, 12);
      final session = FastingSession(
        id: 'persisted-fast',
        plan: FastingPlan.gentle,
        status: FastingSessionStatus.active,
        startedAtUtc: now.subtract(const Duration(hours: 2)),
        targetEndAtUtc: now.add(const Duration(hours: 12)),
        timeZoneId: 'Asia/Shanghai',
        startedLocalDay: '2026-07-20',
        targetEndLocalDay: '2026-07-21',
        createdAtUtc: now.subtract(const Duration(hours: 2)),
        updatedAtUtc: now.subtract(const Duration(hours: 2)),
      );
      final container = _container(
        MutableAppClock(now),
        FakeFastingRepository(
          active: session,
          recent: <FastingSession>[session],
        ),
        FakePreferencesRepository(),
        notificationService: _ThrowingNotificationService(),
      );
      addTearDown(container.dispose);

      final restored = await container.read(fastingProvider.future);

      expect(restored.activeSession?.id, session.id);
    },
  );

  test('completed fast exposes an eating window with exact boundaries', () {
    final windowStart = DateTime.utc(2026, 7, 21);
    final session = FastingSession(
      id: 'completed-fast',
      plan: FastingPlan.balanced,
      status: FastingSessionStatus.completed,
      startedAtUtc: windowStart.subtract(FastingPlan.balanced.fastingDuration),
      targetEndAtUtc: windowStart,
      timeZoneId: 'Asia/Shanghai',
      startedLocalDay: '2026-07-20',
      targetEndLocalDay: '2026-07-21',
      endedLocalDay: '2026-07-21',
      endedAtUtc: windowStart,
      createdAtUtc: windowStart.subtract(FastingPlan.balanced.fastingDuration),
      updatedAtUtc: windowStart,
    );
    final state = FastingState(
      plan: FastingPlan.balanced,
      recentSessions: <FastingSession>[session],
    );

    expect(
      state.phaseAt(windowStart.subtract(const Duration(milliseconds: 1))),
      FastingPhase.idle,
    );
    expect(state.phaseAt(windowStart), FastingPhase.eating);
    expect(
      state.eatingWindowRemainingAt(windowStart),
      FastingPlan.balanced.eatingDuration,
    );
    expect(
      state.phaseAt(
        windowStart.add(
          FastingPlan.balanced.eatingDuration - const Duration(seconds: 1),
        ),
      ),
      FastingPhase.eating,
    );
    expect(
      state.phaseAt(windowStart.add(FastingPlan.balanced.eatingDuration)),
      FastingPhase.idle,
    );
  });
}

ProviderContainer _container(
  MutableAppClock clock,
  FakeFastingRepository fasting,
  FakePreferencesRepository preferences, {
  NotificationService notificationService = const NoopNotificationService(),
}) {
  return ProviderContainer.test(
    overrides: [
      appClockProvider.overrideWithValue(clock),
      currentTimeZoneIdProvider.overrideWithValue('Asia/Shanghai'),
      fastingRepositoryProvider.overrideWithValue(fasting),
      preferencesRepositoryProvider.overrideWithValue(preferences),
      notificationServiceProvider.overrideWithValue(notificationService),
    ],
  );
}

final class _ThrowingNotificationService implements NotificationService {
  @override
  Future<void> cancelFastingReminder() async {
    throw StateError('notifications unavailable');
  }

  @override
  Future<bool> notificationsEnabled() async {
    throw StateError('notifications unavailable');
  }

  @override
  Future<bool> requestNotificationPermission() async {
    throw StateError('notifications unavailable');
  }

  @override
  Future<void> reconcile(
    FastingSession? activeSession, {
    bool requestPermission = false,
  }) async {
    throw StateError('notifications unavailable');
  }
}

final class _RecordingNotificationService implements NotificationService {
  final List<FastingSession?> sessions = <FastingSession?>[];
  final List<bool> permissionRequests = <bool>[];
  int cancelCalls = 0;

  void reset() {
    sessions.clear();
    permissionRequests.clear();
    cancelCalls = 0;
  }

  @override
  Future<void> cancelFastingReminder() async {
    cancelCalls++;
  }

  @override
  Future<bool> notificationsEnabled() async => true;

  @override
  Future<bool> requestNotificationPermission() async => true;

  @override
  Future<void> reconcile(
    FastingSession? activeSession, {
    bool requestPermission = false,
  }) async {
    sessions.add(activeSession);
    permissionRequests.add(requestPermission);
  }
}
