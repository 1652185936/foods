// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_operation_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SyncOperationInput _$SyncOperationInputFromJson(Map<String, dynamic> json) =>
    SyncOperationInput(
      action: SyncAction.fromJson(json['action'] as String),
      entityId: json['entityId'] as String,
      entityType: SyncEntityType.fromJson(json['entityType'] as String),
      expectedVersion: (json['expectedVersion'] as num).toInt(),
      operationId: json['operationId'] as String,
      payloadVersion: (json['payloadVersion'] as num?)?.toInt() ?? 1,
      appPreferences: json['appPreferences'] == null
          ? null
          : AppPreferencesSyncPayload.fromJson(
              json['appPreferences'] as Map<String, dynamic>,
            ),
      fastingSession: json['fastingSession'] == null
          ? null
          : FastingSessionSyncPayload.fromJson(
              json['fastingSession'] as Map<String, dynamic>,
            ),
      meal: json['meal'] == null
          ? null
          : MealSyncPayload.fromJson(json['meal'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$SyncOperationInputToJson(SyncOperationInput instance) =>
    <String, dynamic>{
      'action': _$SyncActionEnumMap[instance.action]!,
      'appPreferences': instance.appPreferences,
      'entityId': instance.entityId,
      'entityType': _$SyncEntityTypeEnumMap[instance.entityType]!,
      'expectedVersion': instance.expectedVersion,
      'fastingSession': instance.fastingSession,
      'meal': instance.meal,
      'operationId': instance.operationId,
      'payloadVersion': instance.payloadVersion,
    };

const _$SyncActionEnumMap = {
  SyncAction.upsert: 'upsert',
  SyncAction.delete: 'delete',
  SyncAction.$unknown: r'$unknown',
};

const _$SyncEntityTypeEnumMap = {
  SyncEntityType.mealLog: 'mealLog',
  SyncEntityType.fastingSession: 'fastingSession',
  SyncEntityType.appPreferences: 'appPreferences',
  SyncEntityType.$unknown: r'$unknown',
};
