// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'fasting_plan.dart';

part 'app_preferences_response.g.dart';

@JsonSerializable()
class AppPreferencesResponse {
  const AppPreferencesResponse({
    required this.changeCursor,
    required this.createdAtUtc,
    required this.dailyEnergyTargetKcal,
    required this.fastingReminderEnabled,
    required this.selectedFastingPlan,
    required this.updatedAtUtc,
    required this.version,
  });

  factory AppPreferencesResponse.fromJson(Map<String, Object?> json) =>
      _$AppPreferencesResponseFromJson(json);

  final int changeCursor;
  final DateTime createdAtUtc;
  final int dailyEnergyTargetKcal;
  final bool fastingReminderEnabled;
  final FastingPlan selectedFastingPlan;
  final DateTime updatedAtUtc;
  final int version;

  Map<String, Object?> toJson() => _$AppPreferencesResponseToJson(this);
}
