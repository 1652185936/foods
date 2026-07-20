// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'otp_challenge_input.g.dart';

@JsonSerializable()
class OtpChallengeInput {
  const OtpChallengeInput({
    required this.deviceInstallationId,
    required this.phoneNumber,
  });

  factory OtpChallengeInput.fromJson(Map<String, Object?> json) =>
      _$OtpChallengeInputFromJson(json);

  final String deviceInstallationId;
  final String phoneNumber;

  Map<String, Object?> toJson() => _$OtpChallengeInputToJson(this);
}
