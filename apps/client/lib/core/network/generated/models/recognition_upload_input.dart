// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'recognition_upload_input_content_type.dart';

part 'recognition_upload_input.g.dart';

@JsonSerializable()
class RecognitionUploadInput {
  const RecognitionUploadInput({
    required this.checksumSha256,
    required this.contentType,
    required this.sizeBytes,
  });

  factory RecognitionUploadInput.fromJson(Map<String, Object?> json) =>
      _$RecognitionUploadInputFromJson(json);

  final String checksumSha256;
  final RecognitionUploadInputContentType contentType;
  final int sizeBytes;

  Map<String, Object?> toJson() => _$RecognitionUploadInputToJson(this);
}
