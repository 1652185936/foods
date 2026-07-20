// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'device_input.dart';

part 'otp_verification_input.g.dart';

@JsonSerializable()
class OtpVerificationInput {
  const OtpVerificationInput({required this.code, required this.device});

  factory OtpVerificationInput.fromJson(Map<String, Object?> json) =>
      _$OtpVerificationInputFromJson(json);

  final String code;
  final DeviceInput device;

  Map<String, Object?> toJson() => _$OtpVerificationInputToJson(this);
}
