// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'recognition_create_input.g.dart';

@JsonSerializable()
class RecognitionCreateInput {
  const RecognitionCreateInput({required this.uploadSessionId});

  factory RecognitionCreateInput.fromJson(Map<String, Object?> json) =>
      _$RecognitionCreateInputFromJson(json);

  final String uploadSessionId;

  Map<String, Object?> toJson() => _$RecognitionCreateInputToJson(this);
}
