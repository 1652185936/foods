// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_preferences_sync_payload.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppPreferencesSyncPayload _$AppPreferencesSyncPayloadFromJson(
  Map<String, dynamic> json,
) => AppPreferencesSyncPayload(
  dailyEnergyTargetKcal: (json['dailyEnergyTargetKcal'] as num).toInt(),
  fastingReminderEnabled: json['fastingReminderEnabled'] as bool,
  selectedFastingPlan: FastingPlan.fromJson(
    json['selectedFastingPlan'] as String,
  ),
);

Map<String, dynamic> _$AppPreferencesSyncPayloadToJson(
  AppPreferencesSyncPayload instance,
) => <String, dynamic>{
  'dailyEnergyTargetKcal': instance.dailyEnergyTargetKcal,
  'fastingReminderEnabled': instance.fastingReminderEnabled,
  'selectedFastingPlan': _$FastingPlanEnumMap[instance.selectedFastingPlan]!,
};

const _$FastingPlanEnumMap = {
  FastingPlan.gentle: 'gentle',
  FastingPlan.balanced: 'balanced',
  FastingPlan.advanced: 'advanced',
  FastingPlan.$unknown: r'$unknown',
};
