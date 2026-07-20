// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fasting_session_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FastingSessionResponse _$FastingSessionResponseFromJson(
  Map<String, dynamic> json,
) => FastingSessionResponse(
  changeCursor: (json['changeCursor'] as num).toInt(),
  createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
  endedAtUtc: json['endedAtUtc'] == null
      ? null
      : DateTime.parse(json['endedAtUtc'] as String),
  id: json['id'] as String,
  plan: FastingPlan.fromJson(json['plan'] as String),
  startedAtUtc: DateTime.parse(json['startedAtUtc'] as String),
  startedLocalDay: json['startedLocalDay'] as String,
  status: FastingSessionStatus.fromJson(json['status'] as String),
  targetEndAtUtc: DateTime.parse(json['targetEndAtUtc'] as String),
  targetEndLocalDay: json['targetEndLocalDay'] as String,
  timeZoneId: json['timeZoneId'] as String,
  updatedAtUtc: DateTime.parse(json['updatedAtUtc'] as String),
  version: (json['version'] as num).toInt(),
  endedLocalDay: json['endedLocalDay'] as String?,
);

Map<String, dynamic> _$FastingSessionResponseToJson(
  FastingSessionResponse instance,
) => <String, dynamic>{
  'changeCursor': instance.changeCursor,
  'createdAtUtc': instance.createdAtUtc.toIso8601String(),
  'endedAtUtc': instance.endedAtUtc?.toIso8601String(),
  'endedLocalDay': instance.endedLocalDay,
  'id': instance.id,
  'plan': _$FastingPlanEnumMap[instance.plan]!,
  'startedAtUtc': instance.startedAtUtc.toIso8601String(),
  'startedLocalDay': instance.startedLocalDay,
  'status': _$FastingSessionStatusEnumMap[instance.status]!,
  'targetEndAtUtc': instance.targetEndAtUtc.toIso8601String(),
  'targetEndLocalDay': instance.targetEndLocalDay,
  'timeZoneId': instance.timeZoneId,
  'updatedAtUtc': instance.updatedAtUtc.toIso8601String(),
  'version': instance.version,
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
