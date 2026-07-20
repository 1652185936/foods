import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/time/local_day.dart';
import '../../profile/domain/app_preferences.dart';
import '../domain/fasting_plan.dart';
import '../domain/fasting_session.dart';

enum FastingPhase { idle, fasting, eating }

class FastingState {
  FastingState({
    required this.plan,
    this.activeSession,
    List<FastingSession> recentSessions = const <FastingSession>[],
    this.isMutating = false,
  }) : recentSessions = List<FastingSession>.unmodifiable(recentSessions);

  final FastingPlan plan;
  final FastingSession? activeSession;
  final List<FastingSession> recentSessions;
  final bool isMutating;

  bool get isActive => activeSession != null;

  FastingPhase phaseAt(DateTime nowUtc) {
    if (activeSession != null) {
      return FastingPhase.fasting;
    }
    return eatingSessionAt(nowUtc) == null
        ? FastingPhase.idle
        : FastingPhase.eating;
  }

  FastingSession? eatingSessionAt(DateTime nowUtc) {
    final now = nowUtc.toUtc();
    for (final session in recentSessions) {
      if (session.status != FastingSessionStatus.completed) {
        continue;
      }
      final windowStart = session.targetEndAtUtc;
      final windowEnd = windowStart.add(session.plan.eatingDuration);
      if (!now.isBefore(windowStart) && now.isBefore(windowEnd)) {
        return session;
      }
    }
    return null;
  }

  Duration remainingAt(DateTime nowUtc) {
    final target = activeSession?.targetEndAtUtc;
    if (target == null || !target.isAfter(nowUtc.toUtc())) {
      return Duration.zero;
    }
    return target.difference(nowUtc.toUtc());
  }

  Duration eatingWindowRemainingAt(DateTime nowUtc) {
    final session = eatingSessionAt(nowUtc);
    if (session == null) {
      return Duration.zero;
    }
    return session.targetEndAtUtc
        .add(session.plan.eatingDuration)
        .difference(nowUtc.toUtc());
  }

  FastingState withMutation(bool value) => FastingState(
    plan: plan,
    activeSession: activeSession,
    recentSessions: recentSessions,
    isMutating: value,
  );
}

final fastingStatisticsProvider = StreamProvider<FastingStatistics>(
  (ref) {
    ref.watch(currentLocalDayProvider);
    final timeZoneId = ref.watch(currentTimeZoneIdProvider);
    return ref
        .watch(fastingRepositoryProvider)
        .watchStatistics(timeZoneId: timeZoneId);
  },
  dependencies: [
    currentLocalDayProvider,
    currentTimeZoneIdProvider,
    fastingRepositoryProvider,
  ],
);

final fastingProvider = AsyncNotifierProvider<FastingController, FastingState>(
  FastingController.new,
  dependencies: [
    fastingRepositoryProvider,
    preferencesRepositoryProvider,
    appClockProvider,
    currentTimeZoneIdProvider,
    notificationServiceProvider,
  ],
);

enum FastingMutationResult { applied, ignored, failed }

class FastingController extends AsyncNotifier<FastingState> {
  bool _mutating = false;

  @override
  Future<FastingState> build() => _load();

  Future<FastingMutationResult> selectPlan(FastingPlan plan) async {
    final current = state.asData?.value;
    if (current == null || current.isActive || current.plan == plan) {
      return FastingMutationResult.ignored;
    }
    return _runMutation(() async {
      final repository = ref.read(preferencesRepositoryProvider);
      final preferences = await repository.load();
      await repository.save(preferences.copyWith(selectedFastingPlan: plan));
    });
  }

  Future<FastingMutationResult> start() async {
    final current = state.asData?.value;
    if (current == null || current.isActive) {
      return FastingMutationResult.ignored;
    }
    return _runMutation(() async {
      final preferences = await ref.read(preferencesRepositoryProvider).load();
      final session = await ref
          .read(fastingRepositoryProvider)
          .start(
            plan: current.plan,
            nowUtc: ref.read(appClockProvider).now().toUtc(),
            timeZoneId: ref.read(currentTimeZoneIdProvider),
          );
      await _reconcileReminderBestEffort(
        preferences.fastingReminderEnabled ? session : null,
        requestPermission: preferences.fastingReminderEnabled,
      );
    });
  }

  Future<FastingMutationResult> stop() {
    final current = state.asData?.value;
    if (current == null || !current.isActive) {
      return Future<FastingMutationResult>.value(FastingMutationResult.ignored);
    }
    return _runMutation(() async {
      await ref
          .read(fastingRepositoryProvider)
          .cancelActive(nowUtc: ref.read(appClockProvider).now().toUtc());
      await _cancelReminderBestEffort();
    });
  }

  Future<bool> completeIfNeeded() async {
    if (_mutating || state.asData?.value.activeSession == null) {
      return false;
    }
    _mutating = true;
    _setMutationBusy(true);
    try {
      final completed = await ref
          .read(fastingRepositoryProvider)
          .completeDue(nowUtc: ref.read(appClockProvider).now().toUtc());
      if (completed) {
        await _cancelReminderBestEffort();
        state = AsyncData(await _load(completeDue: false));
      } else {
        _setMutationBusy(false);
      }
      return completed;
    } catch (_) {
      _setMutationBusy(false);
      return false;
    } finally {
      _mutating = false;
    }
  }

  Future<void> refresh() async {
    if (_mutating) {
      return;
    }
    try {
      state = AsyncData(await _load());
    } catch (_) {
      // Keep the last usable state during a foreground refresh failure.
    }
  }

  Future<void> retry() async {
    if (_mutating) {
      return;
    }
    state = const AsyncLoading<FastingState>();
    state = await AsyncValue.guard(_load);
  }

  Future<FastingMutationResult> _runMutation(
    Future<void> Function() action,
  ) async {
    if (_mutating) {
      return FastingMutationResult.ignored;
    }
    _mutating = true;
    final previous = state.asData?.value;
    _setMutationBusy(true);
    try {
      await action();
      state = AsyncData(await _load(completeDue: false));
      return FastingMutationResult.applied;
    } catch (_) {
      try {
        state = AsyncData(await _load(completeDue: false));
      } catch (_) {
        if (previous != null) {
          state = AsyncData(previous.withMutation(false));
        }
      }
      return FastingMutationResult.failed;
    } finally {
      _mutating = false;
    }
  }

  void _setMutationBusy(bool value) {
    final current = state.asData?.value;
    if (current != null && current.isMutating != value) {
      state = AsyncData(current.withMutation(value));
    }
  }

  Future<FastingState> _load({bool completeDue = true}) async {
    final nowUtc = ref.read(appClockProvider).now().toUtc();
    final fastingRepository = ref.read(fastingRepositoryProvider);
    if (completeDue) {
      await fastingRepository.completeDue(nowUtc: nowUtc);
    }
    final preferencesRepository = ref.read(preferencesRepositoryProvider);
    final results = await Future.wait<Object?>(<Future<Object?>>[
      preferencesRepository.load(),
      fastingRepository.loadActive(),
      fastingRepository.loadRecent(limit: 12),
    ]);
    final preferences = results[0]! as AppPreferences;
    final active = results[1] as FastingSession?;
    final recent = results[2]! as List<FastingSession>;
    await _reconcileReminderBestEffort(
      preferences.fastingReminderEnabled ? active : null,
    );
    return FastingState(
      plan: preferences.selectedFastingPlan,
      activeSession: active,
      recentSessions: recent,
    );
  }

  Future<void> _reconcileReminderBestEffort(
    FastingSession? activeSession, {
    bool requestPermission = false,
  }) async {
    try {
      if (activeSession == null) {
        await ref.read(notificationServiceProvider).cancelFastingReminder();
      } else {
        await ref
            .read(notificationServiceProvider)
            .reconcile(activeSession, requestPermission: requestPermission);
      }
    } catch (_) {
      // A committed fasting mutation remains successful when the platform
      // notification service is unavailable or permission has been denied.
    }
  }

  Future<void> _cancelReminderBestEffort() =>
      _reconcileReminderBestEffort(null);
}
