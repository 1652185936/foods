import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/features/fasting/domain/fasting_plan.dart';
import 'package:foods_client/features/fasting/domain/fasting_session.dart';
import 'package:foods_client/features/fasting/presentation/fasting_page.dart';

import '../../support/test_dependencies.dart';

void main() {
  testWidgets('countdown only writes when an active fast becomes due', (
    tester,
  ) async {
    final nowUtc = DateTime.utc(2026, 7, 20, 8);
    final clock = MutableAppClock(nowUtc);
    final session = FastingSession(
      id: 'active-fast',
      plan: FastingPlan.balanced,
      status: FastingSessionStatus.active,
      startedAtUtc: nowUtc,
      targetEndAtUtc: nowUtc.add(const Duration(hours: 16)),
      timeZoneId: 'Asia/Shanghai',
      startedLocalDay: '2026-07-20',
      targetEndLocalDay: '2026-07-21',
      createdAtUtc: nowUtc,
      updatedAtUtc: nowUtc,
    );
    final repository = FakeFastingRepository(
      active: session,
      recent: <FastingSession>[session],
    );

    await tester.pumpWidget(
      testProviderScope(
        clock: clock,
        fasting: repository,
        child: const MaterialApp(home: FastingPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('08:00'), findsOneWidget);
    final initialCompletionChecks = repository.completeDueCalls;

    await tester.pump(const Duration(seconds: 3));
    expect(repository.completeDueCalls, initialCompletionChecks);

    clock.value = session.targetEndAtUtc;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(repository.completeDueCalls, initialCompletionChecks + 1);
    expect(repository.active, isNull);
  });

  testWidgets('completed fast shows a live eating-window state', (
    tester,
  ) async {
    final nowUtc = DateTime.utc(2026, 7, 20, 8);
    final session = FastingSession(
      id: 'completed-fast',
      plan: FastingPlan.balanced,
      status: FastingSessionStatus.completed,
      startedAtUtc: nowUtc.subtract(FastingPlan.balanced.fastingDuration),
      targetEndAtUtc: nowUtc,
      timeZoneId: 'Asia/Shanghai',
      startedLocalDay: '2026-07-19',
      targetEndLocalDay: '2026-07-20',
      endedLocalDay: '2026-07-20',
      endedAtUtc: nowUtc,
      createdAtUtc: nowUtc.subtract(FastingPlan.balanced.fastingDuration),
      updatedAtUtc: nowUtc,
    );

    await tester.pumpWidget(
      testProviderScope(
        clock: MutableAppClock(nowUtc),
        fasting: FakeFastingRepository(recent: <FastingSession>[session]),
        child: const MaterialApp(home: FastingPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('当前处于进食窗口'), findsOneWidget);
    expect(find.text('进食窗口剩余'), findsOneWidget);
    expect(find.text('08:00:00'), findsOneWidget);
    expect(find.text('开始下一轮 16 小时断食'), findsOneWidget);
  });

  testWidgets('rapid start taps run one mutation without a failure message', (
    tester,
  ) async {
    final gate = Completer<void>();
    final repository = FakeFastingRepository(startGate: gate);

    await tester.pumpWidget(
      testProviderScope(
        fasting: repository,
        child: const MaterialApp(home: FastingPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('start-fasting')));
    await tester.pump();
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('start-fasting')),
    );
    expect(button.onPressed, isNull);
    expect(repository.startCalls, 1);

    await tester.tap(
      find.byKey(const Key('start-fasting')),
      warnIfMissed: false,
    );
    expect(repository.startCalls, 1);
    expect(find.text('开始失败，请重试'), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(repository.startCalls, 1);
  });
}
