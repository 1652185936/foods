// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'recognition_alternative_response.dart';

part 'recognition_item_response.g.dart';

@JsonSerializable()
class RecognitionItemResponse {
  const RecognitionItemResponse({
    required this.alternatives,
    required this.canonicalFoodId,
    required this.carbsMg,
    required this.confidenceMilli,
    required this.energyKcal,
    required this.fatMg,
    required this.id,
    required this.isUserCorrected,
    required this.name,
    required this.position,
    required this.proteinMg,
    required this.servingMilli,
  });

  factory RecognitionItemResponse.fromJson(Map<String, Object?> json) =>
      _$RecognitionItemResponseFromJson(json);

  final List<RecognitionAlternativeResponse> alternatives;
  final String? canonicalFoodId;
  final int carbsMg;
  final int confidenceMilli;
  final int energyKcal;
  final int fatMg;
  final String id;
  final bool isUserCorrected;
  final String name;
  final int position;
  final int proteinMg;
  final int servingMilli;

  Map<String, Object?> toJson() => _$RecognitionItemResponseToJson(this);
}
