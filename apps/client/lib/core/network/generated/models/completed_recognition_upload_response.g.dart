// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'completed_recognition_upload_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CompletedRecognitionUploadResponse _$CompletedRecognitionUploadResponseFromJson(
  Map<String, dynamic> json,
) => CompletedRecognitionUploadResponse(
  height: (json['height'] as num).toInt(),
  sourceContentType: json['sourceContentType'] as String,
  sourceExpiresAt: DateTime.parse(json['sourceExpiresAt'] as String),
  sourceObjectKey: json['sourceObjectKey'] as String,
  sourceSizeBytes: (json['sourceSizeBytes'] as num).toInt(),
  status: json['status'] as String,
  uploadSessionId: json['uploadSessionId'] as String,
  width: (json['width'] as num).toInt(),
);

Map<String, dynamic> _$CompletedRecognitionUploadResponseToJson(
  CompletedRecognitionUploadResponse instance,
) => <String, dynamic>{
  'height': instance.height,
  'sourceContentType': instance.sourceContentType,
  'sourceExpiresAt': instance.sourceExpiresAt.toIso8601String(),
  'sourceObjectKey': instance.sourceObjectKey,
  'sourceSizeBytes': instance.sourceSizeBytes,
  'status': instance.status,
  'uploadSessionId': instance.uploadSessionId,
  'width': instance.width,
};
