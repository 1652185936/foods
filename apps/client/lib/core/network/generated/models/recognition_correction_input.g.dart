// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recognition_correction_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RecognitionCorrectionInput _$RecognitionCorrectionInputFromJson(
  Map<String, dynamic> json,
) => RecognitionCorrectionInput(
  expectedVersion: (json['expectedVersion'] as num).toInt(),
  items: (json['items'] as List<dynamic>)
      .map(
        (e) =>
            RecognitionCorrectionItemInput.fromJson(e as Map<String, dynamic>),
      )
      .toList(),
);

Map<String, dynamic> _$RecognitionCorrectionInputToJson(
  RecognitionCorrectionInput instance,
) => <String, dynamic>{
  'expectedVersion': instance.expectedVersion,
  'items': instance.items,
};
