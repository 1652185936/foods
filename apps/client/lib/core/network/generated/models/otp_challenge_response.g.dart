// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'otp_challenge_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OtpChallengeResponse _$OtpChallengeResponseFromJson(
  Map<String, dynamic> json,
) => OtpChallengeResponse(
  challengeId: json['challengeId'] as String,
  expiresAt: DateTime.parse(json['expiresAt'] as String),
  resendAfterSeconds: (json['resendAfterSeconds'] as num).toInt(),
);

Map<String, dynamic> _$OtpChallengeResponseToJson(
  OtpChallengeResponse instance,
) => <String, dynamic>{
  'challengeId': instance.challengeId,
  'expiresAt': instance.expiresAt.toIso8601String(),
  'resendAfterSeconds': instance.resendAfterSeconds,
};
