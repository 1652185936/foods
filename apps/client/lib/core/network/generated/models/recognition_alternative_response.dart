// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'recognition_alternative_response.g.dart';

@JsonSerializable()
class RecognitionAlternativeResponse {
  const RecognitionAlternativeResponse({
    required this.confidenceMilli,
    required this.name,
  });

  factory RecognitionAlternativeResponse.fromJson(Map<String, Object?> json) =>
      _$RecognitionAlternativeResponseFromJson(json);

  final int confidenceMilli;
  final String name;

  Map<String, Object?> toJson() => _$RecognitionAlternativeResponseToJson(this);
}
