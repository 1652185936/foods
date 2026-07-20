// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_sync_payload.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MealSyncPayload _$MealSyncPayloadFromJson(Map<String, dynamic> json) =>
    MealSyncPayload(
      isWithinEatingWindow: json['isWithinEatingWindow'] as bool,
      items: (json['items'] as List<dynamic>)
          .map((e) => MealItemInputModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      localDay: json['localDay'] as String,
      occurredAtUtc: DateTime.parse(json['occurredAtUtc'] as String),
      source: MealSource.fromJson(json['source'] as String),
      timeZoneId: json['timeZoneId'] as String,
      type: MealType.fromJson(json['type'] as String),
    );

Map<String, dynamic> _$MealSyncPayloadToJson(MealSyncPayload instance) =>
    <String, dynamic>{
      'isWithinEatingWindow': instance.isWithinEatingWindow,
      'items': instance.items,
      'localDay': instance.localDay,
      'occurredAtUtc': instance.occurredAtUtc.toIso8601String(),
      'source': _$MealSourceEnumMap[instance.source]!,
      'timeZoneId': instance.timeZoneId,
      'type': _$MealTypeEnumMap[instance.type]!,
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
