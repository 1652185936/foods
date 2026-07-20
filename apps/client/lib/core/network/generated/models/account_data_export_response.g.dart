// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_data_export_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AccountDataExportResponse _$AccountDataExportResponseFromJson(
  Map<String, dynamic> json,
) => AccountDataExportResponse(
  exportedAt: DateTime.parse(json['exportedAt'] as String),
  fastingSessions: (json['fastingSessions'] as List<dynamic>)
      .map((e) => FastingSessionResponse.fromJson(e as Map<String, dynamic>))
      .toList(),
  healthProfile: json['healthProfile'] == null
      ? null
      : HealthProfileResponse.fromJson(
          json['healthProfile'] as Map<String, dynamic>,
        ),
  meals: (json['meals'] as List<dynamic>)
      .map((e) => AccountExportMeal.fromJson(e as Map<String, dynamic>))
      .toList(),
  preferences: json['preferences'] == null
      ? null
      : AppPreferencesResponse.fromJson(
          json['preferences'] as Map<String, dynamic>,
        ),
  recognitions: (json['recognitions'] as List<dynamic>)
      .map((e) => AccountExportRecognition.fromJson(e as Map<String, dynamic>))
      .toList(),
  user: UserResponse.fromJson(json['user'] as Map<String, dynamic>),
  schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
);

Map<String, dynamic> _$AccountDataExportResponseToJson(
  AccountDataExportResponse instance,
) => <String, dynamic>{
  'exportedAt': instance.exportedAt.toIso8601String(),
  'fastingSessions': instance.fastingSessions,
  'healthProfile': instance.healthProfile,
  'meals': instance.meals,
  'preferences': instance.preferences,
  'recognitions': instance.recognitions,
  'schemaVersion': instance.schemaVersion,
  'user': instance.user,
};
