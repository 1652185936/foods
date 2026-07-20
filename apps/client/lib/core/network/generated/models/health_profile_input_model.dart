// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'goal_type.dart';

part 'health_profile_input_model.g.dart';

@JsonSerializable()
class HealthProfileInputModel {
  const HealthProfileInputModel({
    required this.expectedVersion,
    this.birthDate,
    this.currentWeightKg,
    this.goalType,
    this.heightCm,
    this.targetWeightKg,
  });

  factory HealthProfileInputModel.fromJson(Map<String, Object?> json) =>
      _$HealthProfileInputModelFromJson(json);

  final String? birthDate;
  final String? currentWeightKg;
  final int expectedVersion;
  final GoalType? goalType;
  final String? heightCm;
  final String? targetWeightKg;

  Map<String, Object?> toJson() => _$HealthProfileInputModelToJson(this);
}
