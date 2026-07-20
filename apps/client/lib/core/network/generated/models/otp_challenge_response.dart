// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'otp_challenge_response.g.dart';

@JsonSerializable()
class OtpChallengeResponse {
  const OtpChallengeResponse({
    required this.challengeId,
    required this.expiresAt,
    required this.resendAfterSeconds,
  });

  factory OtpChallengeResponse.fromJson(Map<String, Object?> json) =>
      _$OtpChallengeResponseFromJson(json);

  final String challengeId;
  final DateTime expiresAt;
  final int resendAfterSeconds;

  Map<String, Object?> toJson() => _$OtpChallengeResponseToJson(this);
}
