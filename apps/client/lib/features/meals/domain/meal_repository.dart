import 'meal_log.dart';

abstract interface class MealRepository {
  Stream<MealDaySnapshot> watchDay({required String localDay});

  Stream<MealStatistics> watchStatistics();

  Future<MealLog> addMeal(MealDraft draft);

  Future<void> deleteMeal(String mealId);
}
