// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recognition_upload_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RecognitionUploadResponse _$RecognitionUploadResponseFromJson(
  Map<String, dynamic> json,
) => RecognitionUploadResponse(
  expiresAt: DateTime.parse(json['expiresAt'] as String),
  objectKey: json['objectKey'] as String,
  status: json['status'] as String,
  uploadHeaders: Map<String, String>.from(json['uploadHeaders'] as Map),
  uploadSessionId: json['uploadSessionId'] as String,
  uploadUrl: json['uploadUrl'] as String,
);

Map<String, dynamic> _$RecognitionUploadResponseToJson(
  RecognitionUploadResponse instance,
) => <String, dynamic>{
  'expiresAt': instance.expiresAt.toIso8601String(),
  'objectKey': instance.objectKey,
  'status': instance.status,
  'uploadHeaders': instance.uploadHeaders,
  'uploadSessionId': instance.uploadSessionId,
  'uploadUrl': instance.uploadUrl,
};
