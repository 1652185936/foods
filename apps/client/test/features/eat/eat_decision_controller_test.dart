import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/features/eat/application/eat_decision_controller.dart';
import 'package:foods_client/features/eat/domain/dish.dart';

void main() {
  group('EatDecisionController', () {
    test('does not immediately repeat the previous result', () async {
      final dishes = <Dish>[_dish('first'), _dish('second')];
      final container = ProviderContainer.test(
        overrides: [
          dishCatalogProvider.overrideWithValue(dishes),
          decisionDelayProvider.overrideWithValue(Duration.zero),
        ],
      );

      final previous = container.read(eatDecisionProvider).dish;

      await container.read(eatDecisionProvider.notifier).decide();

      final result = container.read(eatDecisionProvider);
      expect(result.status, EatDecisionStatus.result);
      expect(result.dish?.id, isNot(previous?.id));
      expect(result.dish, same(dishes[1]));
    });

    test('a single-item catalog can be decided safely', () async {
      final onlyDish = _dish('only');
      final container = ProviderContainer.test(
        overrides: [
          dishCatalogProvider.overrideWithValue(<Dish>[onlyDish]),
          decisionDelayProvider.overrideWithValue(Duration.zero),
        ],
      );

      await container.read(eatDecisionProvider.notifier).decide();

      final result = container.read(eatDecisionProvider);
      expect(result.status, EatDecisionStatus.result);
      expect(result.dish, same(onlyDish));
    });

    test('rapid repeated decide calls run only one decision', () async {
      final container = ProviderContainer.test(
        overrides: [
          dishCatalogProvider.overrideWithValue(<Dish>[
            _dish('first'),
            _dish('second'),
          ]),
          decisionDelayProvider.overrideWithValue(Duration.zero),
        ],
      );
      final statuses = <EatDecisionStatus>[];
      final subscription = container.listen(
        eatDecisionProvider,
        (previous, next) => statuses.add(next.status),
      );
      addTearDown(subscription.close);
      final controller = container.read(eatDecisionProvider.notifier);

      final firstDecision = controller.decide();
      final repeatedDecision = controller.decide();
      await Future.wait(<Future<void>>[firstDecision, repeatedDecision]);

      expect(statuses, <EatDecisionStatus>[
        EatDecisionStatus.rolling,
        EatDecisionStatus.result,
      ]);
    });
  });
}

Dish _dish(String id) {
  return Dish(
    id: id,
    name: 'Dish $id',
    description: 'Description $id',
    imageAsset: 'assets/images/$id.webp',
    waitMinutes: 20,
    priceLabel: '20-30',
    tags: const <String>['test'],
  );
}
