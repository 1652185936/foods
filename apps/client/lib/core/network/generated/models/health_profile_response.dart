// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'goal_type.dart';

part 'health_profile_response.g.dart';

@JsonSerializable()
class HealthProfileResponse {
  const HealthProfileResponse({
    required this.createdAt,
    required this.currentWeightKg,
    required this.dailyEnergyTargetKcal,
    required this.goalType,
    required this.heightCm,
    required this.targetWeightKg,
    required this.updatedAt,
    required this.userId,
    required this.version,
    this.birthDate,
  });

  factory HealthProfileResponse.fromJson(Map<String, Object?> json) =>
      _$HealthProfileResponseFromJson(json);

  final String? birthDate;
  final DateTime createdAt;
  final String? currentWeightKg;
  final int? dailyEnergyTargetKcal;
  final GoalType? goalType;
  final String? heightCm;
  final String? targetWeightKg;
  final DateTime updatedAt;
  final String userId;
  final int version;

  Map<String, Object?> toJson() => _$HealthProfileResponseToJson(this);
}
