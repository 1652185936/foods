// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'recognition_upload_response.g.dart';

@JsonSerializable()
class RecognitionUploadResponse {
  const RecognitionUploadResponse({
    required this.expiresAt,
    required this.objectKey,
    required this.status,
    required this.uploadHeaders,
    required this.uploadSessionId,
    required this.uploadUrl,
  });

  factory RecognitionUploadResponse.fromJson(Map<String, Object?> json) =>
      _$RecognitionUploadResponseFromJson(json);

  final DateTime expiresAt;
  final String objectKey;
  final String status;
  final Map<String, String> uploadHeaders;
  final String uploadSessionId;
  final String uploadUrl;

  Map<String, Object?> toJson() => _$RecognitionUploadResponseToJson(this);
}
