import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/time/local_day.dart';
import '../domain/meal_log.dart';

final currentMealDayProvider = currentLocalDayProvider;
final mealDayRolloverDelayProvider = localDayRolloverDelayProvider;

final todayMealsProvider = StreamProvider<MealDaySnapshot>((ref) {
  final start = ref.watch(currentMealDayProvider);
  return ref
      .watch(mealRepositoryProvider)
      .watchDay(localDay: localDayKey(start));
}, dependencies: [currentMealDayProvider, mealRepositoryProvider]);

final mealStatisticsProvider = StreamProvider<MealStatistics>(
  (ref) => ref.watch(mealRepositoryProvider).watchStatistics(),
  dependencies: [mealRepositoryProvider],
);

enum MealMutationStatus { idle, saving, failure }

class MealMutationState {
  const MealMutationState({
    this.status = MealMutationStatus.idle,
    this.failedDraft,
  });

  final MealMutationStatus status;
  final MealDraft? failedDraft;

  bool get isSaving => status == MealMutationStatus.saving;
}

final mealMutationProvider =
    NotifierProvider<MealMutationController, MealMutationState>(
      MealMutationController.new,
      dependencies: [mealRepositoryProvider, fastingRepositoryProvider],
    );

class MealMutationController extends Notifier<MealMutationState> {
  @override
  MealMutationState build() => const MealMutationState();

  Future<bool> save(MealDraft draft) async {
    if (state.isSaving) {
      return false;
    }
    state = const MealMutationState(status: MealMutationStatus.saving);
    try {
      final active = await ref.read(fastingRepositoryProvider).loadActive();
      final isWithinEatingWindow =
          active == null ||
          draft.occurredAtUtc.isBefore(active.startedAtUtc) ||
          !draft.occurredAtUtc.isBefore(active.targetEndAtUtc);
      await ref
          .read(mealRepositoryProvider)
          .addMeal(_withEatingWindow(draft, isWithinEatingWindow));
      state = const MealMutationState();
      return true;
    } catch (_) {
      state = MealMutationState(
        status: MealMutationStatus.failure,
        failedDraft: draft,
      );
      return false;
    }
  }

  MealDraft _withEatingWindow(MealDraft draft, bool isWithinEatingWindow) {
    return MealDraft(
      type: draft.type,
      source: draft.source,
      occurredAtUtc: draft.occurredAtUtc,
      timeZoneId: draft.timeZoneId,
      localDay: draft.localDay,
      isWithinEatingWindow: isWithinEatingWindow,
      items: draft.items,
    );
  }

  Future<bool> retryLastSave() async {
    final draft = state.failedDraft;
    if (draft == null) {
      return false;
    }
    return save(draft);
  }

  Future<bool> delete(String mealId) async {
    if (state.isSaving) {
      return false;
    }
    state = const MealMutationState(status: MealMutationStatus.saving);
    try {
      await ref.read(mealRepositoryProvider).deleteMeal(mealId);
      state = const MealMutationState();
      return true;
    } catch (_) {
      state = const MealMutationState(status: MealMutationStatus.failure);
      return false;
    }
  }
}
