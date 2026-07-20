import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/core/sync/connectivity_signal_source.dart';
import 'package:foods_client/core/sync/sync_coordinator.dart';
import 'package:foods_client/core/sync/sync_models.dart';
import 'package:foods_client/core/sync/sync_runner.dart';
import 'package:foods_client/core/time/app_clock.dart';

final _now = DateTime.utc(2026, 7, 21, 8, 30);

void main() {
  test('runs an initial synchronization automatically', () async {
    final fixture = _fixture();
    addTearDown(fixture.dispose);

    await _flush();

    expect(fixture.runner.runCalls, 1);
    expect(fixture.runner.countConflictCalls, 1);
    expect(
      fixture.container.read(syncCoordinatorProvider),
      isA<AccountSyncState>()
          .having((state) => state.phase, 'phase', AccountSyncPhase.success)
          .having(
            (state) => state.lastSuccessfulAtUtc,
            'lastSuccessfulAtUtc',
            _now,
          ),
    );
  });

  test('runs again when the app resumes', () async {
    final fixture = _fixture();
    addTearDown(fixture.dispose);
    await _flush();

    await fixture.container
        .read(syncCoordinatorProvider.notifier)
        .onAppResumed();

    expect(fixture.connectivity.probeCalls, 2);
    expect(fixture.runner.runCalls, 2);
  });

  test(
    'waits offline and synchronizes when connectivity is restored',
    () async {
      final fixture = _fixture(connected: false);
      addTearDown(fixture.dispose);
      await _flush();

      expect(fixture.runner.runCalls, 0);
      expect(
        fixture.container.read(syncCoordinatorProvider).phase,
        AccountSyncPhase.offline,
      );

      fixture.connectivity.emit(true);
      await _flush();

      expect(fixture.runner.runCalls, 1);
      expect(
        fixture.container.read(syncCoordinatorProvider).phase,
        AccountSyncPhase.success,
      );
    },
  );

  test('coalesces concurrent triggers into one in-flight run', () async {
    final gate = Completer<SyncRunResult>();
    final runner = _FakeSyncRunner()..enqueue(() => gate.future);
    final fixture = _fixture(runner: runner);
    addTearDown(fixture.dispose);
    await _flush();

    expect(runner.runCalls, 1);
    final retry = fixture.container
        .read(syncCoordinatorProvider.notifier)
        .retry();
    final resume = fixture.container
        .read(syncCoordinatorProvider.notifier)
        .onAppResumed();
    await _flush();

    expect(runner.runCalls, 1);

    gate.complete(_successfulResult());
    await Future.wait(<Future<void>>[retry, resume]);
    await _flush();

    expect(runner.runCalls, 1);
    expect(
      fixture.container.read(syncCoordinatorProvider).phase,
      AccountSyncPhase.success,
    );
  });

  test('uses finite backoff and never starts a retry hot loop', () async {
    final runner = _FakeSyncRunner()
      ..enqueueError(StateError('initial failure'))
      ..enqueueError(StateError('retry one failure'))
      ..enqueueError(StateError('retry two failure'))
      ..enqueueError(StateError('retry three failure'));
    final scheduler = _FakeRetryScheduler();
    final fixture = _fixture(
      runner: runner,
      scheduler: scheduler,
      retryDelays: const <Duration>[
        Duration(seconds: 1),
        Duration(seconds: 3),
        Duration(seconds: 9),
      ],
    );
    addTearDown(fixture.dispose);

    await _flush();
    expect(runner.runCalls, 1);
    expect(scheduler.scheduledDelays, const <Duration>[Duration(seconds: 1)]);

    scheduler.tasks.last.fire();
    await _flush();
    expect(runner.runCalls, 2);
    expect(scheduler.scheduledDelays, const <Duration>[
      Duration(seconds: 1),
      Duration(seconds: 3),
    ]);

    scheduler.tasks.last.fire();
    await _flush();
    expect(runner.runCalls, 3);
    expect(scheduler.scheduledDelays, const <Duration>[
      Duration(seconds: 1),
      Duration(seconds: 3),
      Duration(seconds: 9),
    ]);

    scheduler.tasks.last.fire();
    await _flush(8);

    expect(runner.runCalls, 4);
    expect(scheduler.tasks, hasLength(3));
    expect(scheduler.tasks.where((task) => task.isActive), isEmpty);
    expect(
      fixture.container.read(syncCoordinatorProvider).phase,
      AccountSyncPhase.error,
    );
  });

  test(
    'dispose cancels the runner, connectivity listener, and retry',
    () async {
      final runner = _FakeSyncRunner()
        ..enqueueError(StateError('temporary failure'));
      final scheduler = _FakeRetryScheduler();
      final connectivity = _FakeConnectivitySignalSource(true);
      final fixture = _fixture(
        runner: runner,
        scheduler: scheduler,
        connectivity: connectivity,
      );
      addTearDown(fixture.dispose);
      await _flush();

      final pendingRetry = scheduler.tasks.single;
      expect(connectivity.hasListener, isTrue);
      expect(pendingRetry.isActive, isTrue);

      fixture.disposeCoordinator();
      await _flush();

      expect(runner.cancelCalls, 1);
      expect(connectivity.hasListener, isFalse);
      expect(connectivity.cancelCalls, 1);
      expect(pendingRetry.isActive, isFalse);
      expect(pendingRetry.cancelCalls, 1);
    },
  );

  test('a failed manual synchronization completes without throwing', () async {
    final runner = _FakeSyncRunner()
      ..enqueueResult(_successfulResult())
      ..enqueueError(StateError('do not expose this exception'));
    final fixture = _fixture(runner: runner);
    addTearDown(fixture.dispose);
    await _flush();

    await expectLater(
      fixture.container.read(syncCoordinatorProvider.notifier).retry(),
      completes,
    );

    final state = fixture.container.read(syncCoordinatorProvider);
    expect(state.phase, AccountSyncPhase.error);
    expect(state.lastSuccessfulAtUtc, _now);
    expect(state.message, isNot(contains('do not expose')));
  });

  test('manual retry recovers immediately after a failure', () async {
    final runner = _FakeSyncRunner()
      ..enqueueError(StateError('temporary failure'))
      ..enqueueResult(_successfulResult());
    final scheduler = _FakeRetryScheduler();
    final fixture = _fixture(runner: runner, scheduler: scheduler);
    addTearDown(fixture.dispose);
    await _flush();

    final automaticRetry = scheduler.tasks.single;
    expect(
      fixture.container.read(syncCoordinatorProvider).phase,
      AccountSyncPhase.error,
    );

    await fixture.container.read(syncCoordinatorProvider.notifier).retry();

    expect(runner.runCalls, 2);
    expect(automaticRetry.isActive, isFalse);
    expect(automaticRetry.cancelCalls, 1);
    expect(
      fixture.container.read(syncCoordinatorProvider).phase,
      AccountSyncPhase.success,
    );
  });

  test('reports conflicts using the larger persisted conflict count', () async {
    final runner = _FakeSyncRunner(persistedConflictCount: 3)
      ..enqueueResult(
        _successfulResult(
          conflicts: const <SyncConflict>[
            SyncConflict(
              source: SyncConflictSource.push,
              entityType: SyncEntityKind.mealLog,
              entityId: 'meal-a',
              serverVersion: 2,
              operationId: 'operation-a',
              disposition: SyncWriteDisposition.versionConflict,
            ),
            SyncConflict(
              source: SyncConflictSource.pull,
              entityType: SyncEntityKind.mealLog,
              entityId: 'meal-a',
              serverVersion: 2,
              operationId: 'operation-a',
            ),
          ],
        ),
      );
    final fixture = _fixture(runner: runner);
    addTearDown(fixture.dispose);

    await _flush();

    expect(
      fixture.container.read(syncCoordinatorProvider),
      isA<AccountSyncState>()
          .having((state) => state.phase, 'phase', AccountSyncPhase.conflict)
          .having((state) => state.conflictCount, 'conflictCount', 3)
          .having(
            (state) => state.lastSuccessfulAtUtc,
            'lastSuccessfulAtUtc',
            _now,
          ),
    );
  });
}

_SyncCoordinatorFixture _fixture({
  _FakeSyncRunner? runner,
  _FakeConnectivitySignalSource? connectivity,
  _FakeRetryScheduler? scheduler,
  bool connected = true,
  List<Duration> retryDelays = const <Duration>[
    Duration(seconds: 5),
    Duration(seconds: 30),
    Duration(minutes: 2),
  ],
}) {
  final resolvedRunner = runner ?? _FakeSyncRunner();
  final resolvedConnectivity =
      connectivity ?? _FakeConnectivitySignalSource(connected);
  final resolvedScheduler = scheduler ?? _FakeRetryScheduler();
  final container = ProviderContainer.test(
    overrides: [
      accountSyncRunnerProvider.overrideWithValue(resolvedRunner),
      connectivitySignalSourceProvider.overrideWithValue(resolvedConnectivity),
      syncRetrySchedulerProvider.overrideWithValue(resolvedScheduler),
      syncRetryDelaysProvider.overrideWithValue(retryDelays),
      appClockProvider.overrideWithValue(FixedAppClock(_now)),
    ],
  );
  final subscription = container.listen<AccountSyncState>(
    syncCoordinatorProvider,
    (_, _) {},
    fireImmediately: true,
  );
  return _SyncCoordinatorFixture(
    container: container,
    subscription: subscription,
    runner: resolvedRunner,
    connectivity: resolvedConnectivity,
    scheduler: resolvedScheduler,
  );
}

Future<void> _flush([int turns = 4]) async {
  for (var turn = 0; turn < turns; turn++) {
    await Future<void>.delayed(Duration.zero);
  }
}

SyncRunResult _successfulResult({
  List<SyncConflict> conflicts = const <SyncConflict>[],
}) {
  return SyncRunResult(
    pushedOperations: 0,
    pulledChanges: 0,
    cursor: 0,
    conflicts: conflicts,
  );
}

typedef _RunHandler = Future<SyncRunResult> Function();

final class _FakeSyncRunner implements AccountSyncRunner {
  _FakeSyncRunner({this.persistedConflictCount = 0});

  final Queue<_RunHandler> _runs = Queue<_RunHandler>();
  int persistedConflictCount;
  int runCalls = 0;
  int countConflictCalls = 0;
  int cancelCalls = 0;

  void enqueue(_RunHandler handler) => _runs.add(handler);

  void enqueueResult(SyncRunResult result) {
    enqueue(() async => result);
  }

  void enqueueError(Object error) {
    enqueue(() async => throw error);
  }

  @override
  void cancel() => cancelCalls++;

  @override
  Future<int> countConflicts() async {
    countConflictCalls++;
    return persistedConflictCount;
  }

  @override
  Future<SyncRunResult> run() {
    runCalls++;
    if (_runs.isEmpty) {
      return Future<SyncRunResult>.value(_successfulResult());
    }
    return _runs.removeFirst()();
  }
}

final class _FakeConnectivitySignalSource implements ConnectivitySignalSource {
  _FakeConnectivitySignalSource(this.connected) {
    _changes = StreamController<bool>.broadcast(
      sync: true,
      onListen: () {
        listenCalls++;
        hasListener = true;
      },
      onCancel: () {
        cancelCalls++;
        hasListener = false;
      },
    );
  }

  late final StreamController<bool> _changes;
  bool connected;
  int probeCalls = 0;
  int listenCalls = 0;
  int cancelCalls = 0;
  bool hasListener = false;
  bool _closed = false;

  @override
  Stream<bool> get changes => _changes.stream;

  void emit(bool value) {
    connected = value;
    _changes.add(value);
  }

  @override
  Future<bool> isConnected() async {
    probeCalls++;
    return connected;
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _changes.close();
  }
}

final class _FakeRetryScheduler implements SyncRetryScheduler {
  final List<Duration> scheduledDelays = <Duration>[];
  final List<_FakeRetryTask> tasks = <_FakeRetryTask>[];

  @override
  SyncRetryTask schedule(Duration delay, void Function() callback) {
    scheduledDelays.add(delay);
    final task = _FakeRetryTask(callback);
    tasks.add(task);
    return task;
  }
}

final class _FakeRetryTask implements SyncRetryTask {
  _FakeRetryTask(this._callback);

  final void Function() _callback;
  bool _active = true;
  int cancelCalls = 0;

  @override
  bool get isActive => _active;

  @override
  void cancel() {
    if (!_active) {
      return;
    }
    cancelCalls++;
    _active = false;
  }

  void fire() {
    if (!_active) {
      return;
    }
    _active = false;
    _callback();
  }
}

final class _SyncCoordinatorFixture {
  _SyncCoordinatorFixture({
    required this.container,
    required this.subscription,
    required this.runner,
    required this.connectivity,
    required this.scheduler,
  });

  final ProviderContainer container;
  final ProviderSubscription<AccountSyncState> subscription;
  final _FakeSyncRunner runner;
  final _FakeConnectivitySignalSource connectivity;
  final _FakeRetryScheduler scheduler;
  bool _coordinatorDisposed = false;

  void disposeCoordinator() {
    if (_coordinatorDisposed) {
      return;
    }
    _coordinatorDisposed = true;
    subscription.close();
    container.dispose();
  }

  Future<void> dispose() async {
    disposeCoordinator();
    await connectivity.close();
  }
}
