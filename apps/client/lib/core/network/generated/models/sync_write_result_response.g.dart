// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_write_result_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SyncWriteResultResponse _$SyncWriteResultResponseFromJson(
  Map<String, dynamic> json,
) => SyncWriteResultResponse(
  changeCursor: (json['changeCursor'] as num?)?.toInt(),
  entityId: json['entityId'] as String,
  entityType: SyncEntityType.fromJson(json['entityType'] as String),
  operationId: json['operationId'] as String,
  replayed: json['replayed'] as bool,
  serverVersion: (json['serverVersion'] as num?)?.toInt(),
  status: SyncWriteStatus.fromJson(json['status'] as String),
);

Map<String, dynamic> _$SyncWriteResultResponseToJson(
  SyncWriteResultResponse instance,
) => <String, dynamic>{
  'changeCursor': instance.changeCursor,
  'entityId': instance.entityId,
  'entityType': _$SyncEntityTypeEnumMap[instance.entityType]!,
  'operationId': instance.operationId,
  'replayed': instance.replayed,
  'serverVersion': instance.serverVersion,
  'status': _$SyncWriteStatusEnumMap[instance.status]!,
};

const _$SyncEntityTypeEnumMap = {
  SyncEntityType.mealLog: 'mealLog',
  SyncEntityType.fastingSession: 'fastingSession',
  SyncEntityType.appPreferences: 'appPreferences',
  SyncEntityType.$unknown: r'$unknown',
};

const _$SyncWriteStatusEnumMap = {
  SyncWriteStatus.applied: 'applied',
  SyncWriteStatus.versionConflict: 'versionConflict',
  SyncWriteStatus.notFound: 'notFound',
  SyncWriteStatus.idempotencyConflict: 'idempotencyConflict',
  SyncWriteStatus.activeFastingConflict: 'activeFastingConflict',
  SyncWriteStatus.$unknown: r'$unknown',
};
