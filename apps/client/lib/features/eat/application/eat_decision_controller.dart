import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_dish_catalog.dart';
import '../domain/dish.dart';

enum EatDecisionStatus { idle, rolling, result, error }

class EatDecisionState {
  const EatDecisionState({required this.status, this.dish});

  final EatDecisionStatus status;
  final Dish? dish;

  bool get isRolling => status == EatDecisionStatus.rolling;
}

final dishCatalogProvider = Provider<List<Dish>>((ref) {
  return takeoutDishCatalog;
});

final decisionDelayProvider = Provider<Duration>((ref) {
  return const Duration(milliseconds: 700);
});

final eatDecisionProvider =
    NotifierProvider<EatDecisionController, EatDecisionState>(
      EatDecisionController.new,
    );

class EatDecisionController extends Notifier<EatDecisionState> {
  final Random _random = Random();

  @override
  EatDecisionState build() {
    final dishes = ref.watch(dishCatalogProvider);
    if (dishes.isEmpty) {
      return const EatDecisionState(status: EatDecisionStatus.error);
    }
    return EatDecisionState(status: EatDecisionStatus.idle, dish: dishes.first);
  }

  Future<void> decide() async {
    if (state.isRolling) {
      return;
    }

    final dishes = ref.read(dishCatalogProvider);
    if (dishes.isEmpty) {
      state = const EatDecisionState(status: EatDecisionStatus.error);
      return;
    }

    final previous = state.dish;
    state = EatDecisionState(
      status: EatDecisionStatus.rolling,
      dish: previous ?? dishes.first,
    );

    await Future<void>.delayed(ref.read(decisionDelayProvider));
    if (!ref.mounted) {
      return;
    }

    final candidates = dishes.length == 1
        ? dishes
        : dishes.where((dish) => dish.id != previous?.id).toList();
    final selected = candidates.isEmpty
        ? previous ?? dishes.first
        : candidates[_random.nextInt(candidates.length)];
    state = EatDecisionState(status: EatDecisionStatus.result, dish: selected);
  }
}
