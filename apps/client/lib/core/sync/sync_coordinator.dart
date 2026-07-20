import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../db/database_provider.dart';
import '../time/app_clock.dart';
import 'connectivity_signal_source.dart';
import 'generated_synchronization_adapter.dart';
import 'sync_engine.dart';
import 'sync_models.dart';
import 'sync_runner.dart';
import 'synchronization_adapter.dart';

final connectivitySignalSourceProvider = Provider<ConnectivitySignalSource>(
  (ref) => ConnectivityPlusSignalSource(),
  dependencies: const [],
);

final syncRetrySchedulerProvider = Provider<SyncRetryScheduler>(
  (ref) => const TimerSyncRetryScheduler(),
  dependencies: const [],
);

final syncRetryDelaysProvider = Provider<List<Duration>>(
  (ref) => const <Duration>[
    Duration(seconds: 5),
    Duration(seconds: 30),
    Duration(minutes: 2),
  ],
  dependencies: const [],
);

final synchronizationAdapterProvider = Provider<SynchronizationAdapter>(
  (ref) => GeneratedSynchronizationAdapter(
    ref.watch(ordinApiClientsProvider).synchronization,
  ),
  dependencies: [ordinApiClientsProvider],
);

final accountSyncRunnerProvider = Provider<AccountSyncRunner>(
  (ref) {
    final scope = ref.watch(accountScopeProvider);
    if (!scope.canSync) {
      throw StateError('Sync requires an authenticated account scope.');
    }
    final runner = SyncEngine(
      database: ref.watch(appDatabaseProvider),
      scope: scope,
      adapter: ref.watch(synchronizationAdapterProvider),
      clock: ref.watch(appClockProvider),
    );
    ref.onDispose(runner.cancel);
    return runner;
  },
  dependencies: [
    accountScopeProvider,
    appDatabaseProvider,
    synchronizationAdapterProvider,
    appClockProvider,
  ],
);

final syncCoordinatorProvider =
    NotifierProvider<SyncCoordinator, AccountSyncState>(
      SyncCoordinator.new,
      dependencies: [
        accountSyncRunnerProvider,
        connectivitySignalSourceProvider,
        syncRetrySchedulerProvider,
        syncRetryDelaysProvider,
        appClockProvider,
      ],
    );

enum AccountSyncPhase { idle, running, success, offline, error, conflict }

final class AccountSyncState {
  const AccountSyncState({
    this.phase = AccountSyncPhase.idle,
    this.lastSuccessfulAtUtc,
    this.conflictCount = 0,
    this.message,
  });

  final AccountSyncPhase phase;
  final DateTime? lastSuccessfulAtUtc;
  final int conflictCount;
  final String? message;

  bool get isRunning => phase == AccountSyncPhase.running;
}

enum SyncTrigger { initial, resume, connectivityRestored, manual, retry }

abstract interface class SyncRetryTask {
  bool get isActive;

  void cancel();
}

abstract interface class SyncRetryScheduler {
  SyncRetryTask schedule(Duration delay, void Function() callback);
}

final class TimerSyncRetryScheduler implements SyncRetryScheduler {
  const TimerSyncRetryScheduler();

  @override
  SyncRetryTask schedule(Duration delay, void Function() callback) {
    return _TimerSyncRetryTask(Timer(delay, callback));
  }
}

final class _TimerSyncRetryTask implements SyncRetryTask {
  const _TimerSyncRetryTask(this._timer);

  final Timer _timer;

  @override
  bool get isActive => _timer.isActive;

  @override
  void cancel() => _timer.cancel();
}

final class SyncCoordinator extends Notifier<AccountSyncState> {
  late AccountSyncRunner _runner;
  late ConnectivitySignalSource _connectivity;
  late SyncRetryScheduler _scheduler;
  late List<Duration> _retryDelays;
  late AppClock _clock;

  StreamSubscription<bool>? _connectivitySubscription;
  SyncRetryTask? _retryTask;
  Future<void>? _activeSync;
  bool? _online;
  bool _foreground = true;
  bool _disposed = false;
  int _retryIndex = 0;

  @override
  AccountSyncState build() {
    _runner = ref.watch(accountSyncRunnerProvider);
    _connectivity = ref.watch(connectivitySignalSourceProvider);
    _scheduler = ref.watch(syncRetrySchedulerProvider);
    _retryDelays = List<Duration>.unmodifiable(
      ref.watch(syncRetryDelaysProvider),
    );
    _clock = ref.watch(appClockProvider);
    ref.onDispose(_dispose);
    scheduleMicrotask(() => unawaited(_initialize()));
    return const AccountSyncState();
  }

  Future<void> retry() {
    return _synchronize(SyncTrigger.manual, ignoreOfflineSignal: true);
  }

  Future<void> onAppResumed() async {
    if (_disposed) {
      return;
    }
    _foreground = true;
    final connected = await _probeConnectivity();
    if (_disposed) {
      return;
    }
    if (connected == false) {
      _online = false;
      _setOffline();
      return;
    }
    if (connected != null) {
      _online = connected;
    }
    await _synchronize(SyncTrigger.resume);
  }

  void onAppBackgrounded() {
    _foreground = false;
    _cancelRetry();
  }

  Future<void> _initialize() async {
    if (_disposed) {
      return;
    }
    _connectivitySubscription = _connectivity.changes.listen(
      _handleConnectivityChange,
      onError: (_) {},
    );
    final connected = await _probeConnectivity();
    if (_disposed) {
      return;
    }
    if (connected == false) {
      _online = false;
      _setOffline();
      return;
    }
    if (connected != null) {
      _online = connected;
    }
    await _synchronize(SyncTrigger.initial);
  }

  void _handleConnectivityChange(bool connected) {
    if (_disposed) {
      return;
    }
    final previous = _online;
    _online = connected;
    if (!connected) {
      _cancelRetry();
      if (!state.isRunning) {
        _setOffline();
      }
      return;
    }
    if (previous != true) {
      unawaited(_synchronize(SyncTrigger.connectivityRestored));
    }
  }

  Future<void> _synchronize(
    SyncTrigger trigger, {
    bool ignoreOfflineSignal = false,
  }) {
    if (_disposed) {
      return Future<void>.value();
    }
    if (trigger != SyncTrigger.retry) {
      _retryIndex = 0;
      _cancelRetry();
    }
    final active = _activeSync;
    if (active != null) {
      return active;
    }
    if (trigger != SyncTrigger.manual && !_foreground) {
      return Future<void>.value();
    }
    if (!ignoreOfflineSignal && _online == false) {
      _setOffline();
      return Future<void>.value();
    }
    final future = _performSync();
    _activeSync = future;
    return future.whenComplete(() {
      if (identical(_activeSync, future)) {
        _activeSync = null;
      }
    });
  }

  Future<void> _performSync() async {
    state = AccountSyncState(
      phase: AccountSyncPhase.running,
      lastSuccessfulAtUtc: state.lastSuccessfulAtUtc,
      conflictCount: state.conflictCount,
      message: '正在同步数据',
    );
    try {
      final result = await _runner.run();
      if (_disposed) {
        return;
      }
      final persistedConflicts = await _runner.countConflicts();
      if (_disposed) {
        return;
      }
      final conflictCount = math.max(
        persistedConflicts,
        _uniqueConflictCount(result.conflicts),
      );
      _retryIndex = 0;
      _cancelRetry();
      final succeededAt = _clock.now().toUtc();
      state = AccountSyncState(
        phase: conflictCount == 0
            ? AccountSyncPhase.success
            : AccountSyncPhase.conflict,
        lastSuccessfulAtUtc: succeededAt,
        conflictCount: conflictCount,
        message: conflictCount == 0 ? '数据已同步' : '已同步，$conflictCount 条冲突以云端为准',
      );
    } on SyncCancelledException {
      return;
    } catch (_) {
      if (_disposed) {
        return;
      }
      final connected = await _probeConnectivity();
      if (_disposed) {
        return;
      }
      if (connected == false) {
        _online = false;
        _setOffline();
        return;
      }
      state = AccountSyncState(
        phase: AccountSyncPhase.error,
        lastSuccessfulAtUtc: state.lastSuccessfulAtUtc,
        conflictCount: state.conflictCount,
        message: '同步暂时失败，请稍后重试',
      );
      _scheduleRetry();
    }
  }

  Future<bool?> _probeConnectivity() async {
    try {
      return await _connectivity.isConnected();
    } catch (_) {
      return null;
    }
  }

  void _scheduleRetry() {
    if (_disposed || !_foreground || _online == false || _retryTask != null) {
      return;
    }
    if (_retryIndex >= _retryDelays.length) {
      return;
    }
    final delay = _retryDelays[_retryIndex++];
    if (delay <= Duration.zero) {
      return;
    }
    _retryTask = _scheduler.schedule(delay, () {
      _retryTask = null;
      unawaited(_synchronize(SyncTrigger.retry));
    });
  }

  void _setOffline() {
    state = AccountSyncState(
      phase: AccountSyncPhase.offline,
      lastSuccessfulAtUtc: state.lastSuccessfulAtUtc,
      conflictCount: state.conflictCount,
      message: '当前离线，联网后会自动同步',
    );
  }

  void _cancelRetry() {
    _retryTask?.cancel();
    _retryTask = null;
  }

  void _dispose() {
    _disposed = true;
    _cancelRetry();
    unawaited(_connectivitySubscription?.cancel());
    _connectivitySubscription = null;
    _runner.cancel();
  }

  static int _uniqueConflictCount(List<SyncConflict> conflicts) {
    return <String>{
      for (final conflict in conflicts)
        conflict.operationId ??
            '${conflict.entityType.name}:${conflict.entityId}',
    }.length;
  }
}
