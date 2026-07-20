// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'fasting_plan.dart';

part 'app_preferences_sync_payload.g.dart';

@JsonSerializable()
class AppPreferencesSyncPayload {
  const AppPreferencesSyncPayload({
    required this.dailyEnergyTargetKcal,
    required this.fastingReminderEnabled,
    required this.selectedFastingPlan,
  });

  factory AppPreferencesSyncPayload.fromJson(Map<String, Object?> json) =>
      _$AppPreferencesSyncPayloadFromJson(json);

  final int dailyEnergyTargetKcal;
  final bool fastingReminderEnabled;
  final FastingPlan selectedFastingPlan;

  Map<String, Object?> toJson() => _$AppPreferencesSyncPayloadToJson(this);
}
