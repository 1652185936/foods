// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_item_input_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MealItemInputModel _$MealItemInputModelFromJson(Map<String, dynamic> json) =>
    MealItemInputModel(
      carbsMg: (json['carbsMg'] as num).toInt(),
      energyKcal: (json['energyKcal'] as num).toInt(),
      fatMg: (json['fatMg'] as num).toInt(),
      id: json['id'] as String,
      name: json['name'] as String,
      proteinMg: (json['proteinMg'] as num).toInt(),
      servingMilli: (json['servingMilli'] as num).toInt(),
      imageReference: json['imageReference'] as String?,
    );

Map<String, dynamic> _$MealItemInputModelToJson(MealItemInputModel instance) =>
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
