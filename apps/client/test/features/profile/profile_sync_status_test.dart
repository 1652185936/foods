import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/core/auth/auth_controller.dart';
import 'package:foods_client/core/db/account_scope.dart';
import 'package:foods_client/core/db/database_provider.dart';
import 'package:foods_client/core/sync/sync_models.dart';
import 'package:foods_client/core/sync/sync_runner.dart';
import 'package:foods_client/features/profile/presentation/profile_page.dart';

import '../../support/auth_test_support.dart';
import '../../support/test_dependencies.dart';

void main() {
  final now = DateTime.utc(2026, 7, 20, 12);

  testWidgets('sync failure keeps profile usable and manual retry recovers', (
    tester,
  ) async {
    final runner = _ControllableSyncRunner()..fail = true;

    await tester.pumpWidget(_profileApp(now: now, runner: runner));
    await tester.pumpAndSettle();
    await _showSyncRow(tester);

    expect(find.text('同步暂时失败，请稍后重试'), findsOneWidget);
    expect(find.byKey(const Key('profile-logout')), findsOneWidget);
    expect(find.text('断食提醒偏好'), findsOneWidget);

    runner.fail = false;
    await tester.tap(find.byKey(const Key('profile-sync-retry')));
    await tester.pumpAndSettle();

    expect(runner.runCalls, 2);
    expect(find.textContaining('数据已同步'), findsOneWidget);
  });

  testWidgets('running sync shows progress and disables duplicate retry', (
    tester,
  ) async {
    final gate = Completer<SyncRunResult>();
    final runner = _ControllableSyncRunner(gate: gate);

    await tester.pumpWidget(_profileApp(now: now, runner: runner));
    await tester.pump();
    await _showSyncRow(tester);

    expect(find.text('正在同步数据'), findsOneWidget);
    expect(find.byKey(const Key('profile-sync-retry')), findsNothing);
    expect(runner.runCalls, 1);

    gate.complete(_emptyResult());
    await tester.pumpAndSettle();

    expect(find.textContaining('数据已同步'), findsOneWidget);
  });
}

Widget _profileApp({required DateTime now, required AccountSyncRunner runner}) {
  final auth = AuthAuthenticated(
    session: authTestSession(authTestUserA, now),
    scopeGeneration: 1,
  );
  return testProviderScope(
    clock: MutableAppClock(now),
    syncRunner: runner,
    child: ProviderScope(
      overrides: [
        accountScopeProvider.overrideWithValue(
          AccountScope.authenticated(authTestUserA),
        ),
        currentAuthSessionProvider.overrideWithValue(auth),
      ],
      child: const MaterialApp(home: ProfilePage()),
    ),
  );
}

Future<void> _showSyncRow(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const Key('profile-sync-status')),
    240,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

SyncRunResult _emptyResult() => SyncRunResult(
  pushedOperations: 0,
  pulledChanges: 0,
  cursor: 0,
  conflicts: const <SyncConflict>[],
);

final class _ControllableSyncRunner implements AccountSyncRunner {
  _ControllableSyncRunner({this.gate});

  final Completer<SyncRunResult>? gate;
  bool fail = false;
  int runCalls = 0;

  @override
  void cancel() {}

  @override
  Future<int> countConflicts() async => 0;

  @override
  Future<SyncRunResult> run() {
    runCalls++;
    if (fail) {
      return Future<SyncRunResult>.error(StateError('network unavailable'));
    }
    return gate?.future ?? Future<SyncRunResult>.value(_emptyResult());
  }
}
