import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/core/bootstrap/app_lifecycle_coordinator.dart';
import 'package:foods_client/core/time/device_time_zone.dart';

import '../../support/test_dependencies.dart';

void main() {
  testWidgets('resume reconciles local state and triggers account sync once', (
    tester,
  ) async {
    final runner = FakeAccountSyncRunner();
    final fasting = FakeFastingRepository();

    await tester.pumpWidget(
      testProviderScope(
        fasting: fasting,
        syncRunner: runner,
        child: ProviderScope(
          overrides: [
            initialTimeZoneIdProvider.overrideWithValue('Asia/Shanghai'),
            deviceTimeZoneProvider.overrideWithValue(
              const FixedDeviceTimeZone('UTC'),
            ),
            timeZonePollIntervalProvider.overrideWithValue(Duration.zero),
          ],
          child: const MaterialApp(
            home: AppLifecycleCoordinator(child: _TimeZoneProbe()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(runner.runCalls, 1);
    final initialFastingCalls = fasting.completeDueCalls;
    expect(find.text('zone:Asia/Shanghai'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(runner.runCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(runner.runCalls, 2);
    expect(fasting.completeDueCalls, greaterThan(initialFastingCalls));
    expect(find.text('zone:UTC'), findsOneWidget);
  });
}

class _TimeZoneProbe extends ConsumerWidget {
  const _TimeZoneProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Text('zone:${ref.watch(currentTimeZoneStateProvider)}'),
    );
  }
}
