// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_preferences_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppPreferencesResponse _$AppPreferencesResponseFromJson(
  Map<String, dynamic> json,
) => AppPreferencesResponse(
  changeCursor: (json['changeCursor'] as num).toInt(),
  createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
  dailyEnergyTargetKcal: (json['dailyEnergyTargetKcal'] as num).toInt(),
  fastingReminderEnabled: json['fastingReminderEnabled'] as bool,
  selectedFastingPlan: FastingPlan.fromJson(
    json['selectedFastingPlan'] as String,
  ),
  updatedAtUtc: DateTime.parse(json['updatedAtUtc'] as String),
  version: (json['version'] as num).toInt(),
);

Map<String, dynamic> _$AppPreferencesResponseToJson(
  AppPreferencesResponse instance,
) => <String, dynamic>{
  'changeCursor': instance.changeCursor,
  'createdAtUtc': instance.createdAtUtc.toIso8601String(),
  'dailyEnergyTargetKcal': instance.dailyEnergyTargetKcal,
  'fastingReminderEnabled': instance.fastingReminderEnabled,
  'selectedFastingPlan': _$FastingPlanEnumMap[instance.selectedFastingPlan]!,
  'updatedAtUtc': instance.updatedAtUtc.toIso8601String(),
  'version': instance.version,
};

const _$FastingPlanEnumMap = {
  FastingPlan.gentle: 'gentle',
  FastingPlan.balanced: 'balanced',
  FastingPlan.advanced: 'advanced',
  FastingPlan.$unknown: r'$unknown',
};
