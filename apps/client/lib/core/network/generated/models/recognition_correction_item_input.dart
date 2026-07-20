// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'recognition_correction_item_input.g.dart';

@JsonSerializable()
class RecognitionCorrectionItemInput {
  const RecognitionCorrectionItemInput({
    required this.carbsMg,
    required this.energyKcal,
    required this.fatMg,
    required this.id,
    required this.name,
    required this.proteinMg,
    required this.servingMilli,
    this.canonicalFoodId,
  });

  factory RecognitionCorrectionItemInput.fromJson(Map<String, Object?> json) =>
      _$RecognitionCorrectionItemInputFromJson(json);

  final String? canonicalFoodId;
  final int carbsMg;
  final int energyKcal;
  final int fatMg;
  final String id;
  final String name;
  final int proteinMg;
  final int servingMilli;

  Map<String, Object?> toJson() => _$RecognitionCorrectionItemInputToJson(this);
}
