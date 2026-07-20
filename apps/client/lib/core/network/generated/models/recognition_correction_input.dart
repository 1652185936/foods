// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'recognition_correction_item_input.dart';

part 'recognition_correction_input.g.dart';

@JsonSerializable()
class RecognitionCorrectionInput {
  const RecognitionCorrectionInput({
    required this.expectedVersion,
    required this.items,
  });

  factory RecognitionCorrectionInput.fromJson(Map<String, Object?> json) =>
      _$RecognitionCorrectionInputFromJson(json);

  final int expectedVersion;
  final List<RecognitionCorrectionItemInput> items;

  Map<String, Object?> toJson() => _$RecognitionCorrectionInputToJson(this);
}
