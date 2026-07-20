// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recognition_correction_item_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RecognitionCorrectionItemInput _$RecognitionCorrectionItemInputFromJson(
  Map<String, dynamic> json,
) => RecognitionCorrectionItemInput(
  carbsMg: (json['carbsMg'] as num).toInt(),
  energyKcal: (json['energyKcal'] as num).toInt(),
  fatMg: (json['fatMg'] as num).toInt(),
  id: json['id'] as String,
  name: json['name'] as String,
  proteinMg: (json['proteinMg'] as num).toInt(),
  servingMilli: (json['servingMilli'] as num).toInt(),
  canonicalFoodId: json['canonicalFoodId'] as String?,
);

Map<String, dynamic> _$RecognitionCorrectionItemInputToJson(
  RecognitionCorrectionItemInput instance,
) => <String, dynamic>{
  'canonicalFoodId': instance.canonicalFoodId,
  'carbsMg': instance.carbsMg,
  'energyKcal': instance.energyKcal,
  'fatMg': instance.fatMg,
  'id': instance.id,
  'name': instance.name,
  'proteinMg': instance.proteinMg,
  'servingMilli': instance.servingMilli,
};
