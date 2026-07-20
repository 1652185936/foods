// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_change_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SyncChangeResponse _$SyncChangeResponseFromJson(Map<String, dynamic> json) =>
    SyncChangeResponse(
      changeCursor: (json['changeCursor'] as num).toInt(),
      deletedAtUtc: json['deletedAtUtc'] == null
          ? null
          : DateTime.parse(json['deletedAtUtc'] as String),
      entityId: json['entityId'] as String,
      entityType: SyncEntityType.fromJson(json['entityType'] as String),
      version: (json['version'] as num).toInt(),
      appPreferences: json['appPreferences'] == null
          ? null
          : AppPreferencesResponse.fromJson(
              json['appPreferences'] as Map<String, dynamic>,
            ),
      fastingSession: json['fastingSession'] == null
          ? null
          : FastingSessionResponse.fromJson(
              json['fastingSession'] as Map<String, dynamic>,
            ),
      meal: json['meal'] == null
          ? null
          : MealResponse.fromJson(json['meal'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$SyncChangeResponseToJson(SyncChangeResponse instance) =>
    <String, dynamic>{
      'appPreferences': instance.appPreferences,
      'changeCursor': instance.changeCursor,
      'deletedAtUtc': instance.deletedAtUtc?.toIso8601String(),
      'entityId': instance.entityId,
      'entityType': _$SyncEntityTypeEnumMap[instance.entityType]!,
      'fastingSession': instance.fastingSession,
      'meal': instance.meal,
      'version': instance.version,
    };

const _$SyncEntityTypeEnumMap = {
  SyncEntityType.mealLog: 'mealLog',
  SyncEntityType.fastingSession: 'fastingSession',
  SyncEntityType.appPreferences: 'appPreferences',
  SyncEntityType.$unknown: r'$unknown',
};
