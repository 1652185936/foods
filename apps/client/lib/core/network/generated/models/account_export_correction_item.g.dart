// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_export_correction_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AccountExportCorrectionItem _$AccountExportCorrectionItemFromJson(
  Map<String, dynamic> json,
) => AccountExportCorrectionItem(
  canonicalFoodId: json['canonicalFoodId'] as String?,
  carbsMg: (json['carbsMg'] as num).toInt(),
  energyKcal: (json['energyKcal'] as num).toInt(),
  fatMg: (json['fatMg'] as num).toInt(),
  id: json['id'] as String,
  name: json['name'] as String,
  position: (json['position'] as num).toInt(),
  proteinMg: (json['proteinMg'] as num).toInt(),
  servingMilli: (json['servingMilli'] as num).toInt(),
);

Map<String, dynamic> _$AccountExportCorrectionItemToJson(
  AccountExportCorrectionItem instance,
) => <String, dynamic>{
  'canonicalFoodId': instance.canonicalFoodId,
  'carbsMg': instance.carbsMg,
  'energyKcal': instance.energyKcal,
  'fatMg': instance.fatMg,
  'id': instance.id,
  'name': instance.name,
  'position': instance.position,
  'proteinMg': instance.proteinMg,
  'servingMilli': instance.servingMilli,
};
