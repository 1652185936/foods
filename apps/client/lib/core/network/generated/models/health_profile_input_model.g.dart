// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'health_profile_input_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HealthProfileInputModel _$HealthProfileInputModelFromJson(
  Map<String, dynamic> json,
) => HealthProfileInputModel(
  expectedVersion: (json['expectedVersion'] as num).toInt(),
  birthDate: json['birthDate'] as String?,
  currentWeightKg: json['currentWeightKg'] as String?,
  goalType: json['goalType'] == null
      ? null
      : GoalType.fromJson(json['goalType'] as String),
  heightCm: json['heightCm'] as String?,
  targetWeightKg: json['targetWeightKg'] as String?,
);

Map<String, dynamic> _$HealthProfileInputModelToJson(
  HealthProfileInputModel instance,
) => <String, dynamic>{
  'birthDate': instance.birthDate,
  'currentWeightKg': instance.currentWeightKg,
  'expectedVersion': instance.expectedVersion,
  'goalType': _$GoalTypeEnumMap[instance.goalType],
  'heightCm': instance.heightCm,
  'targetWeightKg': instance.targetWeightKg,
};

const _$GoalTypeEnumMap = {
  GoalType.loseFat: 'loseFat',
  GoalType.gainMuscle: 'gainMuscle',
  GoalType.maintain: 'maintain',
  GoalType.healthyEating: 'healthyEating',
  GoalType.$unknown: r'$unknown',
};
