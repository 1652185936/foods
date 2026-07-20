// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'health_profile_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HealthProfileResponse _$HealthProfileResponseFromJson(
  Map<String, dynamic> json,
) => HealthProfileResponse(
  createdAt: DateTime.parse(json['createdAt'] as String),
  currentWeightKg: json['currentWeightKg'] as String?,
  dailyEnergyTargetKcal: (json['dailyEnergyTargetKcal'] as num?)?.toInt(),
  goalType: json['goalType'] == null
      ? null
      : GoalType.fromJson(json['goalType'] as String),
  heightCm: json['heightCm'] as String?,
  targetWeightKg: json['targetWeightKg'] as String?,
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  userId: json['userId'] as String,
  version: (json['version'] as num).toInt(),
  birthDate: json['birthDate'] as String?,
);

Map<String, dynamic> _$HealthProfileResponseToJson(
  HealthProfileResponse instance,
) => <String, dynamic>{
  'birthDate': instance.birthDate,
  'createdAt': instance.createdAt.toIso8601String(),
  'currentWeightKg': instance.currentWeightKg,
  'dailyEnergyTargetKcal': instance.dailyEnergyTargetKcal,
  'goalType': _$GoalTypeEnumMap[instance.goalType],
  'heightCm': instance.heightCm,
  'targetWeightKg': instance.targetWeightKg,
  'updatedAt': instance.updatedAt.toIso8601String(),
  'userId': instance.userId,
  'version': instance.version,
};

const _$GoalTypeEnumMap = {
  GoalType.loseFat: 'loseFat',
  GoalType.gainMuscle: 'gainMuscle',
  GoalType.maintain: 'maintain',
  GoalType.healthyEating: 'healthyEating',
  GoalType.$unknown: r'$unknown',
};
