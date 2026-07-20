// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_export_meal_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AccountExportMealItem _$AccountExportMealItemFromJson(
  Map<String, dynamic> json,
) => AccountExportMealItem(
  carbsMg: (json['carbsMg'] as num).toInt(),
  energyKcal: (json['energyKcal'] as num).toInt(),
  fatMg: (json['fatMg'] as num).toInt(),
  id: json['id'] as String,
  name: json['name'] as String,
  proteinMg: (json['proteinMg'] as num).toInt(),
  servingMilli: (json['servingMilli'] as num).toInt(),
);

Map<String, dynamic> _$AccountExportMealItemToJson(
  AccountExportMealItem instance,
) => <String, dynamic>{
  'carbsMg': instance.carbsMg,
  'energyKcal': instance.energyKcal,
  'fatMg': instance.fatMg,
  'id': instance.id,
  'name': instance.name,
  'proteinMg': instance.proteinMg,
  'servingMilli': instance.servingMilli,
};
