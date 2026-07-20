enum MealType { breakfast, lunch, dinner, snack }

enum MealSource { manual, recognition, recipe }

const maxMealItemsPerLog = 50;
const maxMealItemNameLength = 120;
const maxMealServingMilli = 10000000;
const maxMealEnergyKcal = 100000;
const maxMealNutrientMg = 10000000;
const maxMealImageReferenceLength = 512;

extension MealTypeLabel on MealType {
  String get label => switch (this) {
    MealType.breakfast => '早餐',
    MealType.lunch => '午餐',
    MealType.dinner => '晚餐',
    MealType.snack => '加餐',
  };
}

class MealItem {
  const MealItem({
    required this.id,
    required this.name,
    required this.servingMilli,
    required this.energyKcal,
    required this.proteinMg,
    required this.carbsMg,
    required this.fatMg,
    this.imageReference,
  });

  final String id;
  final String name;
  final int servingMilli;
  final int energyKcal;
  final int proteinMg;
  final int carbsMg;
  final int fatMg;
  final String? imageReference;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'servingMilli': servingMilli,
    'energyKcal': energyKcal,
    'proteinMg': proteinMg,
    'carbsMg': carbsMg,
    'fatMg': fatMg,
    'imageReference': imageReference,
  };
}

class MealItemDraft {
  const MealItemDraft({
    required this.name,
    this.servingMilli = 1000,
    required this.energyKcal,
    this.proteinMg = 0,
    this.carbsMg = 0,
    this.fatMg = 0,
    this.imageReference,
  });

  final String name;
  final int servingMilli;
  final int energyKcal;
  final int proteinMg;
  final int carbsMg;
  final int fatMg;
  final String? imageReference;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'servingMilli': servingMilli,
    'energyKcal': energyKcal,
    'proteinMg': proteinMg,
    'carbsMg': carbsMg,
    'fatMg': fatMg,
    'imageReference': imageReference,
  };
}

class MealDraft {
  MealDraft({
    required this.type,
    required this.source,
    required this.occurredAtUtc,
    required this.timeZoneId,
    this.localDay,
    required this.isWithinEatingWindow,
    required List<MealItemDraft> items,
  }) : items = _validatedMealItems(items);

  final MealType type;
  final MealSource source;
  final DateTime occurredAtUtc;
  final String timeZoneId;
  final String? localDay;
  final bool isWithinEatingWindow;
  final List<MealItemDraft> items;

  Map<String, Object?> toJson() => <String, Object?>{
    'type': type.name,
    'source': source.name,
    'occurredAtUtc': occurredAtUtc.toUtc().toIso8601String(),
    'timeZoneId': timeZoneId,
    'localDay': localDay,
    'isWithinEatingWindow': isWithinEatingWindow,
    'items': items.map((item) => item.toJson()).toList(growable: false),
  };
}

void validateMealDraft(MealDraft draft) {
  _validateMealItems(draft.items);
}

List<MealItemDraft> _validatedMealItems(List<MealItemDraft> items) {
  _validateMealItems(items);
  return List<MealItemDraft>.unmodifiable(items);
}

void _validateMealItems(List<MealItemDraft> items) {
  if (items.isEmpty || items.length > maxMealItemsPerLog) {
    throw const InvalidMealDraftException(
      'A meal requires between 1 and 50 items.',
    );
  }
  for (final item in items) {
    final normalizedName = item.name.trim();
    if (normalizedName.isEmpty ||
        normalizedName.runes.length > maxMealItemNameLength) {
      throw const InvalidMealDraftException(
        'An item name must contain at most 120 characters.',
      );
    }
    if (item.servingMilli <= 0 ||
        item.servingMilli > maxMealServingMilli ||
        item.energyKcal < 0 ||
        item.energyKcal > maxMealEnergyKcal ||
        item.proteinMg < 0 ||
        item.proteinMg > maxMealNutrientMg ||
        item.carbsMg < 0 ||
        item.carbsMg > maxMealNutrientMg ||
        item.fatMg < 0 ||
        item.fatMg > maxMealNutrientMg) {
      throw const InvalidMealDraftException(
        'Nutrition and serving values exceed the supported range.',
      );
    }
    if (!_isValidImageReference(item.imageReference)) {
      throw const InvalidMealDraftException(
        'The meal image reference is invalid.',
      );
    }
  }
}

bool _isValidImageReference(String? value) {
  if (value == null) {
    return true;
  }
  if (value.isEmpty ||
      value != value.trim() ||
      value.length > maxMealImageReferenceLength ||
      value.startsWith('/') ||
      value.contains(r'\') ||
      Uri.tryParse(value)?.hasScheme == true ||
      !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._/-]*$').hasMatch(value)) {
    return false;
  }
  return !value
      .split('/')
      .any((segment) => segment.isEmpty || segment == '.' || segment == '..');
}

final class InvalidMealDraftException implements Exception {
  const InvalidMealDraftException(this.message);

  final String message;
}

class MealLog {
  MealLog({
    required this.id,
    required this.type,
    required this.source,
    required this.occurredAtUtc,
    required this.timeZoneId,
    required this.localDay,
    required this.isWithinEatingWindow,
    required List<MealItem> items,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.serverVersion = 0,
  }) : items = List<MealItem>.unmodifiable(items);

  final String id;
  final MealType type;
  final MealSource source;
  final DateTime occurredAtUtc;
  final String timeZoneId;
  final String localDay;
  final bool isWithinEatingWindow;
  final List<MealItem> items;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final int serverVersion;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'type': type.name,
    'source': source.name,
    'occurredAtUtc': occurredAtUtc.toUtc().toIso8601String(),
    'timeZoneId': timeZoneId,
    'localDay': localDay,
    'isWithinEatingWindow': isWithinEatingWindow,
    'items': items.map((item) => item.toJson()).toList(growable: false),
    'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
    'updatedAtUtc': updatedAtUtc.toUtc().toIso8601String(),
  };
}

class DailyNutritionSummary {
  const DailyNutritionSummary({
    this.energyKcal = 0,
    this.proteinMg = 0,
    this.carbsMg = 0,
    this.fatMg = 0,
    this.targetEnergyKcal = 1780,
  });

  final int energyKcal;
  final int proteinMg;
  final int carbsMg;
  final int fatMg;
  final int targetEnergyKcal;
}

class MealDaySnapshot {
  MealDaySnapshot({
    List<MealLog> meals = const <MealLog>[],
    this.summary = const DailyNutritionSummary(),
  }) : meals = List<MealLog>.unmodifiable(meals);

  final List<MealLog> meals;
  final DailyNutritionSummary summary;
}

class MealStatistics {
  const MealStatistics({this.recordedDays = 0, this.mealCount = 0});

  final int recordedDays;
  final int mealCount;
}
