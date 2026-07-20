// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'otp_verification_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OtpVerificationInput _$OtpVerificationInputFromJson(
  Map<String, dynamic> json,
) => OtpVerificationInput(
  code: json['code'] as String,
  device: DeviceInput.fromJson(json['device'] as Map<String, dynamic>),
);

Map<String, dynamic> _$OtpVerificationInputToJson(
  OtpVerificationInput instance,
) => <String, dynamic>{'code': instance.code, 'device': instance.device};
