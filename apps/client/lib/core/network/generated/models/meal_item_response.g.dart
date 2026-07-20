// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_item_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MealItemResponse _$MealItemResponseFromJson(Map<String, dynamic> json) =>
    MealItemResponse(
      carbsMg: (json['carbsMg'] as num).toInt(),
      energyKcal: (json['energyKcal'] as num).toInt(),
      fatMg: (json['fatMg'] as num).toInt(),
      id: json['id'] as String,
      imageReference: json['imageReference'] as String?,
      name: json['name'] as String,
      proteinMg: (json['proteinMg'] as num).toInt(),
      servingMilli: (json['servingMilli'] as num).toInt(),
    );

Map<String, dynamic> _$MealItemResponseToJson(MealItemResponse instance) =>
    <String, dynamic>{
      'carbsMg': instance.carbsMg,
      'energyKcal': instance.energyKcal,
      'fatMg': instance.fatMg,
      'id': instance.id,
      'imageReference': instance.imageReference,
      'name': instance.name,
      'proteinMg': instance.proteinMg,
      'servingMilli': instance.servingMilli,
    };
