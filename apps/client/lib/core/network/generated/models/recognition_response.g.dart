// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recognition_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RecognitionResponse _$RecognitionResponseFromJson(Map<String, dynamic> json) =>
    RecognitionResponse(
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      errorCode: json['errorCode'] as String?,
      id: json['id'] as String,
      items: (json['items'] as List<dynamic>)
          .map(
            (e) => RecognitionItemResponse.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      needsReviewReason: json['needsReviewReason'] as String?,
      overallConfidenceMilli: (json['overallConfidenceMilli'] as num?)?.toInt(),
      providerName: json['providerName'] as String?,
      sourceExpiresAt: DateTime.parse(json['sourceExpiresAt'] as String),
      status: json['status'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      uploadSessionId: json['uploadSessionId'] as String,
      version: (json['version'] as num).toInt(),
    );

Map<String, dynamic> _$RecognitionResponseToJson(
  RecognitionResponse instance,
) => <String, dynamic>{
  'completedAt': instance.completedAt?.toIso8601String(),
  'createdAt': instance.createdAt.toIso8601String(),
  'errorCode': instance.errorCode,
  'id': instance.id,
  'items': instance.items,
  'needsReviewReason': instance.needsReviewReason,
  'overallConfidenceMilli': instance.overallConfidenceMilli,
  'providerName': instance.providerName,
  'sourceExpiresAt': instance.sourceExpiresAt.toIso8601String(),
  'status': instance.status,
  'updatedAt': instance.updatedAt.toIso8601String(),
  'uploadSessionId': instance.uploadSessionId,
  'version': instance.version,
};
