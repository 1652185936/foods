import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/core/auth/auth_controller.dart';
import 'package:foods_client/core/db/database_provider.dart';
import 'package:foods_client/core/sync/connectivity_signal_source.dart';
import 'package:foods_client/core/sync/sync_coordinator.dart';
import 'package:foods_client/core/sync/sync_models.dart';
import 'package:foods_client/core/sync/sync_runner.dart';
import 'package:foods_client/features/auth/presentation/auth_session_gate.dart';

import '../../support/auth_test_support.dart';

final _scopeCounterProvider = NotifierProvider<_ScopeCounter, int>(
  _ScopeCounter.new,
);

void main() {
  final now = DateTime.utc(2026, 7, 20, 12);

  testWidgets('switching users destroys account-scoped provider state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _accountApp(
        AuthAuthenticated(
          session: authTestSession(authTestUserA, now),
          scopeGeneration: 1,
        ),
      ),
    );
    expect(find.text('owner:$authTestUserA'), findsOneWidget);
    expect(find.text('counter:0'), findsOneWidget);

    await tester.tap(find.byKey(const Key('scope-increment')));
    await tester.pump();
    expect(find.text('counter:1'), findsOneWidget);

    await tester.pumpWidget(
      _accountApp(
        AuthAuthenticated(
          session: authTestSession(authTestUserB, now),
          scopeGeneration: 2,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('owner:$authTestUserB'), findsOneWidget);
    expect(find.text('counter:0'), findsOneWidget);
    expect(find.text('owner:$authTestUserA'), findsNothing);
  });

  testWidgets('account switch disposes old synchronization state', (
    tester,
  ) async {
    final runners = <String, _TrackingSyncRunner>{};
    final connectivity = _TrackingConnectivity();
    addTearDown(connectivity.dispose);
    var auth = AuthAuthenticated(
      session: authTestSession(authTestUserA, now),
      scopeGeneration: 1,
    );
    late StateSetter rebuild;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          return _syncAccountApp(auth, runners, connectivity);
        },
      ),
    );
    await tester.pumpAndSettle();

    final runnerA = runners[authTestUserA]!;
    expect(runnerA.runCalls, 1);
    expect(runnerA.cancelCalls, 0);
    expect(connectivity.activeListeners, 1);

    rebuild(() {
      auth = AuthAuthenticated(
        session: authTestSession(authTestUserB, now),
        scopeGeneration: 2,
      );
    });
    await tester.pumpAndSettle();

    expect(runnerA.cancelCalls, 1);
    expect(runners[authTestUserB]?.runCalls, 1);
    expect(connectivity.cancelCalls, 1);
    expect(connectivity.activeListeners, 1);
  });

  testWidgets('logging-out rebuild keeps the same account sync coordinator', (
    tester,
  ) async {
    final runners = <String, _TrackingSyncRunner>{};
    final connectivity = _TrackingConnectivity();
    addTearDown(connectivity.dispose);
    var auth = AuthAuthenticated(
      session: authTestSession(authTestUserA, now),
      scopeGeneration: 1,
    );
    late StateSetter rebuild;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          return _syncAccountApp(auth, runners, connectivity);
        },
      ),
    );
    await tester.pumpAndSettle();

    final runner = runners[authTestUserA]!;
    rebuild(() {
      auth = AuthAuthenticated(
        session: auth.session,
        scopeGeneration: auth.scopeGeneration,
        isLoggingOut: true,
      );
    });
    await tester.pumpAndSettle();

    expect(runner.runCalls, 1);
    expect(runner.cancelCalls, 0);
    expect(connectivity.activeListeners, 1);
  });
}

Widget _accountApp(AuthAuthenticated auth) {
  return AuthenticatedAccountScope(
    key: ValueKey('account:${auth.session.userId}:${auth.scopeGeneration}'),
    auth: auth,
    child: const MaterialApp(home: _ScopeProbe()),
  );
}

Widget _syncAccountApp(
  AuthAuthenticated auth,
  Map<String, _TrackingSyncRunner> runners,
  ConnectivitySignalSource connectivity,
) {
  final runner = runners.putIfAbsent(
    auth.session.userId,
    _TrackingSyncRunner.new,
  );
  return AuthenticatedAccountScope(
    key: ValueKey('account:${auth.session.userId}:${auth.scopeGeneration}'),
    auth: auth,
    child: ProviderScope(
      overrides: [
        accountSyncRunnerProvider.overrideWithValue(runner),
        connectivitySignalSourceProvider.overrideWithValue(connectivity),
        syncRetryDelaysProvider.overrideWithValue(const <Duration>[]),
      ],
      child: const MaterialApp(home: _SyncScopeProbe()),
    ),
  );
}

class _ScopeCounter extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
}

class _ScopeProbe extends ConsumerWidget {
  const _ScopeProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(accountScopeProvider).ownerUserId;
    final counter = ref.watch(_scopeCounterProvider);
    return Scaffold(
      body: Column(
        children: [
          Text('owner:$owner'),
          Text('counter:$counter'),
          IconButton(
            key: const Key('scope-increment'),
            onPressed: () =>
                ref.read(_scopeCounterProvider.notifier).increment(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _SyncScopeProbe extends ConsumerWidget {
  const _SyncScopeProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syncCoordinatorProvider);
    return Scaffold(body: Text('sync:${state.phase.name}'));
  }
}

final class _TrackingSyncRunner implements AccountSyncRunner {
  int runCalls = 0;
  int cancelCalls = 0;

  @override
  void cancel() => cancelCalls++;

  @override
  Future<int> countConflicts() async => 0;

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

final class _TrackingConnectivity implements ConnectivitySignalSource {
  final List<StreamController<bool>> _controllers = <StreamController<bool>>[];
  int activeListeners = 0;
  int cancelCalls = 0;

  @override
  Stream<bool> get changes {
    late final StreamController<bool> controller;
    controller = StreamController<bool>(
      onListen: () => activeListeners++,
      onCancel: () {
        activeListeners--;
        cancelCalls++;
      },
    );
    _controllers.add(controller);
    return controller.stream;
  }

  @override
  Future<bool> isConnected() async => true;

  Future<void> dispose() async {
    for (final controller in _controllers) {
      await controller.close();
    }
  }
}
