import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/features/fasting/application/fasting_controller.dart';
import 'package:foods_client/features/fasting/domain/fasting_plan.dart';

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

  test('start derives targetEndAt from the selected plan', () {
    final container = ProviderContainer.test();
    final controller = container.read(fastingProvider.notifier);
    final now = DateTime.utc(2026, 7, 20, 8, 30);

    controller.selectPlan(FastingPlan.advanced);
    controller.start(now: now);

    final state = container.read(fastingProvider);
    expect(state.plan, FastingPlan.advanced);
    expect(state.startedAt, now);
    expect(state.targetEndAt, DateTime.utc(2026, 7, 21, 2, 30));
  });

  test('completeIfNeeded keeps the fast active before its target', () {
    final container = ProviderContainer.test();
    final controller = container.read(fastingProvider.notifier);
    final startedAt = DateTime.utc(2026, 7, 20, 8, 30);

    controller.selectPlan(FastingPlan.gentle);
    controller.start(now: startedAt);

    final completed = controller.completeIfNeeded(
      now: startedAt.add(const Duration(hours: 13, minutes: 59)),
    );
    final state = container.read(fastingProvider);

    expect(completed, isFalse);
    expect(state.isActive, isTrue);
    expect(state.plan, FastingPlan.gentle);
  });

  for (final offset in [Duration.zero, const Duration(seconds: 1)]) {
    test('completeIfNeeded completes at or after target '
        '(${offset.inSeconds} second offset)', () {
      final container = ProviderContainer.test();
      final controller = container.read(fastingProvider.notifier);
      final startedAt = DateTime.utc(2026, 7, 20, 8, 30);

      controller.selectPlan(FastingPlan.advanced);
      controller.start(now: startedAt);
      final target = startedAt.add(FastingPlan.advanced.fastingDuration);

      final completed = controller.completeIfNeeded(now: target.add(offset));
      final state = container.read(fastingProvider);

      expect(completed, isTrue);
      expect(state.isActive, isFalse);
      expect(state.startedAt, isNull);
      expect(state.targetEndAt, isNull);
      expect(state.plan, FastingPlan.advanced);
    });
  }
}
