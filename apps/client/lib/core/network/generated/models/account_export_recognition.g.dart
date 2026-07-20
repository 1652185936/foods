// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_export_recognition.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AccountExportRecognition _$AccountExportRecognitionFromJson(
  Map<String, dynamic> json,
) => AccountExportRecognition(
  completedAtUtc: json['completedAtUtc'] == null
      ? null
      : DateTime.parse(json['completedAtUtc'] as String),
  corrections: (json['corrections'] as List<dynamic>)
      .map((e) => AccountExportCorrection.fromJson(e as Map<String, dynamic>))
      .toList(),
  createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
  errorCode: json['errorCode'] as String?,
  id: json['id'] as String,
  items: (json['items'] as List<dynamic>)
      .map(
        (e) => AccountExportRecognitionItem.fromJson(e as Map<String, dynamic>),
      )
      .toList(),
  needsReviewReason: json['needsReviewReason'] as String?,
  overallConfidenceMilli: (json['overallConfidenceMilli'] as num?)?.toInt(),
  status: json['status'] as String,
  updatedAtUtc: DateTime.parse(json['updatedAtUtc'] as String),
  version: (json['version'] as num).toInt(),
);

Map<String, dynamic> _$AccountExportRecognitionToJson(
  AccountExportRecognition instance,
) => <String, dynamic>{
  'completedAtUtc': instance.completedAtUtc?.toIso8601String(),
  'corrections': instance.corrections,
  'createdAtUtc': instance.createdAtUtc.toIso8601String(),
  'errorCode': instance.errorCode,
  'id': instance.id,
  'items': instance.items,
  'needsReviewReason': instance.needsReviewReason,
  'overallConfidenceMilli': instance.overallConfidenceMilli,
  'status': instance.status,
  'updatedAtUtc': instance.updatedAtUtc.toIso8601String(),
  'version': instance.version,
};
