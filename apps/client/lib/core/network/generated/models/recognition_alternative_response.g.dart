// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recognition_alternative_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RecognitionAlternativeResponse _$RecognitionAlternativeResponseFromJson(
  Map<String, dynamic> json,
) => RecognitionAlternativeResponse(
  confidenceMilli: (json['confidenceMilli'] as num).toInt(),
  name: json['name'] as String,
);

Map<String, dynamic> _$RecognitionAlternativeResponseToJson(
  RecognitionAlternativeResponse instance,
) => <String, dynamic>{
  'confidenceMilli': instance.confidenceMilli,
  'name': instance.name,
};
