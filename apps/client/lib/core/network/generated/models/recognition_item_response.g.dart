// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recognition_item_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RecognitionItemResponse _$RecognitionItemResponseFromJson(
  Map<String, dynamic> json,
) => RecognitionItemResponse(
  alternatives: (json['alternatives'] as List<dynamic>)
      .map(
        (e) =>
            RecognitionAlternativeResponse.fromJson(e as Map<String, dynamic>),
      )
      .toList(),
  canonicalFoodId: json['canonicalFoodId'] as String?,
  carbsMg: (json['carbsMg'] as num).toInt(),
  confidenceMilli: (json['confidenceMilli'] as num).toInt(),
  energyKcal: (json['energyKcal'] as num).toInt(),
  fatMg: (json['fatMg'] as num).toInt(),
  id: json['id'] as String,
  isUserCorrected: json['isUserCorrected'] as bool,
  name: json['name'] as String,
  position: (json['position'] as num).toInt(),
  proteinMg: (json['proteinMg'] as num).toInt(),
  servingMilli: (json['servingMilli'] as num).toInt(),
);

Map<String, dynamic> _$RecognitionItemResponseToJson(
  RecognitionItemResponse instance,
) => <String, dynamic>{
  'alternatives': instance.alternatives,
  'canonicalFoodId': instance.canonicalFoodId,
  'carbsMg': instance.carbsMg,
  'confidenceMilli': instance.confidenceMilli,
  'energyKcal': instance.energyKcal,
  'fatMg': instance.fatMg,
  'id': instance.id,
  'isUserCorrected': instance.isUserCorrected,
  'name': instance.name,
  'position': instance.position,
  'proteinMg': instance.proteinMg,
  'servingMilli': instance.servingMilli,
};
