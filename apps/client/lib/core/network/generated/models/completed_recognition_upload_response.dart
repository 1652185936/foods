// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'completed_recognition_upload_response.g.dart';

@JsonSerializable()
class CompletedRecognitionUploadResponse {
  const CompletedRecognitionUploadResponse({
    required this.height,
    required this.sourceContentType,
    required this.sourceExpiresAt,
    required this.sourceObjectKey,
    required this.sourceSizeBytes,
    required this.status,
    required this.uploadSessionId,
    required this.width,
  });

  factory CompletedRecognitionUploadResponse.fromJson(
    Map<String, Object?> json,
  ) => _$CompletedRecognitionUploadResponseFromJson(json);

  final int height;
  final String sourceContentType;
  final DateTime sourceExpiresAt;
  final String sourceObjectKey;
  final int sourceSizeBytes;
  final String status;
  final String uploadSessionId;
  final int width;

  Map<String, Object?> toJson() =>
      _$CompletedRecognitionUploadResponseToJson(this);
}
