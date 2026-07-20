// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fasting_session_sync_payload.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FastingSessionSyncPayload _$FastingSessionSyncPayloadFromJson(
  Map<String, dynamic> json,
) => FastingSessionSyncPayload(
  plan: FastingPlan.fromJson(json['plan'] as String),
  startedAtUtc: DateTime.parse(json['startedAtUtc'] as String),
  startedLocalDay: json['startedLocalDay'] as String,
  status: FastingSessionStatus.fromJson(json['status'] as String),
  targetEndAtUtc: DateTime.parse(json['targetEndAtUtc'] as String),
  targetEndLocalDay: json['targetEndLocalDay'] as String,
  timeZoneId: json['timeZoneId'] as String,
  endedAtUtc: json['endedAtUtc'] == null
      ? null
      : DateTime.parse(json['endedAtUtc'] as String),
  endedLocalDay: json['endedLocalDay'] as String?,
);

Map<String, dynamic> _$FastingSessionSyncPayloadToJson(
  FastingSessionSyncPayload instance,
) => <String, dynamic>{
  'endedAtUtc': instance.endedAtUtc?.toIso8601String(),
  'endedLocalDay': instance.endedLocalDay,
  'plan': _$FastingPlanEnumMap[instance.plan]!,
  'startedAtUtc': instance.startedAtUtc.toIso8601String(),
  'startedLocalDay': instance.startedLocalDay,
  'status': _$FastingSessionStatusEnumMap[instance.status]!,
  'targetEndAtUtc': instance.targetEndAtUtc.toIso8601String(),
  'targetEndLocalDay': instance.targetEndLocalDay,
  'timeZoneId': instance.timeZoneId,
};

const _$FastingPlanEnumMap = {
  FastingPlan.gentle: 'gentle',
  FastingPlan.balanced: 'balanced',
  FastingPlan.advanced: 'advanced',
  FastingPlan.$unknown: r'$unknown',
};

const _$FastingSessionStatusEnumMap = {
  FastingSessionStatus.active: 'active',
  FastingSessionStatus.completed: 'completed',
  FastingSessionStatus.cancelled: 'cancelled',
  FastingSessionStatus.$unknown: r'$unknown',
};
