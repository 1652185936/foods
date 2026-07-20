// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'otp_challenge_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OtpChallengeInput _$OtpChallengeInputFromJson(Map<String, dynamic> json) =>
    OtpChallengeInput(
      deviceInstallationId: json['deviceInstallationId'] as String,
      phoneNumber: json['phoneNumber'] as String,
    );

Map<String, dynamic> _$OtpChallengeInputToJson(OtpChallengeInput instance) =>
    <String, dynamic>{
      'deviceInstallationId': instance.deviceInstallationId,
      'phoneNumber': instance.phoneNumber,
    };
