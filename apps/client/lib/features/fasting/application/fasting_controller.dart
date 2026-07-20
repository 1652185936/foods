import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/fasting_plan.dart';

class FastingState {
  const FastingState({required this.plan, this.startedAt, this.targetEndAt});

  final FastingPlan plan;
  final DateTime? startedAt;
  final DateTime? targetEndAt;

  bool get isActive => startedAt != null && targetEndAt != null;

  Duration remainingAt(DateTime now) {
    final end = targetEndAt;
    if (end == null || !end.isAfter(now)) {
      return Duration.zero;
    }
    return end.difference(now);
  }
}

final fastingProvider = NotifierProvider<FastingController, FastingState>(
  FastingController.new,
);

class FastingController extends Notifier<FastingState> {
  @override
  FastingState build() {
    return const FastingState(plan: FastingPlan.balanced);
  }

  void selectPlan(FastingPlan plan) {
    if (state.isActive) {
      return;
    }
    state = FastingState(plan: plan);
  }

  void start({DateTime? now}) {
    if (state.isActive) {
      return;
    }
    final startedAt = now ?? DateTime.now();
    state = FastingState(
      plan: state.plan,
      startedAt: startedAt,
      targetEndAt: startedAt.add(state.plan.fastingDuration),
    );
  }

  void stop() {
    state = FastingState(plan: state.plan);
  }

  bool completeIfNeeded({DateTime? now}) {
    final end = state.targetEndAt;
    if (end == null || end.isAfter(now ?? DateTime.now())) {
      return false;
    }
    state = FastingState(plan: state.plan);
    return true;
  }
}
