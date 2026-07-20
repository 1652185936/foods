// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MealResponse _$MealResponseFromJson(Map<String, dynamic> json) => MealResponse(
  changeCursor: (json['changeCursor'] as num).toInt(),
  createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
  id: json['id'] as String,
  isWithinEatingWindow: json['isWithinEatingWindow'] as bool,
  items: (json['items'] as List<dynamic>)
      .map((e) => MealItemResponse.fromJson(e as Map<String, dynamic>))
      .toList(),
  localDay: json['localDay'] as String,
  occurredAtUtc: DateTime.parse(json['occurredAtUtc'] as String),
  source: MealSource.fromJson(json['source'] as String),
  timeZoneId: json['timeZoneId'] as String,
  type: MealType.fromJson(json['type'] as String),
  updatedAtUtc: DateTime.parse(json['updatedAtUtc'] as String),
  version: (json['version'] as num).toInt(),
);

Map<String, dynamic> _$MealResponseToJson(MealResponse instance) =>
    <String, dynamic>{
      'changeCursor': instance.changeCursor,
      'createdAtUtc': instance.createdAtUtc.toIso8601String(),
      'id': instance.id,
      'isWithinEatingWindow': instance.isWithinEatingWindow,
      'items': instance.items,
      'localDay': instance.localDay,
      'occurredAtUtc': instance.occurredAtUtc.toIso8601String(),
      'source': _$MealSourceEnumMap[instance.source]!,
      'timeZoneId': instance.timeZoneId,
      'type': _$MealTypeEnumMap[instance.type]!,
      'updatedAtUtc': instance.updatedAtUtc.toIso8601String(),
      'version': instance.version,
    };

const _$MealSourceEnumMap = {
  MealSource.manual: 'manual',
  MealSource.recognition: 'recognition',
  MealSource.recipe: 'recipe',
  MealSource.$unknown: r'$unknown',
};

const _$MealTypeEnumMap = {
  MealType.breakfast: 'breakfast',
  MealType.lunch: 'lunch',
  MealType.dinner: 'dinner',
  MealType.snack: 'snack',
  MealType.$unknown: r'$unknown',
};
