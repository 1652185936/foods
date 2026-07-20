// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_deletion_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AccountDeletionInput _$AccountDeletionInputFromJson(
  Map<String, dynamic> json,
) => AccountDeletionInput(
  confirmation: json['confirmation'] as String,
  deviceInstallationId: json['deviceInstallationId'] as String,
  refreshToken: json['refreshToken'] as String,
);

Map<String, dynamic> _$AccountDeletionInputToJson(
  AccountDeletionInput instance,
) => <String, dynamic>{
  'confirmation': instance.confirmation,
  'deviceInstallationId': instance.deviceInstallationId,
  'refreshToken': instance.refreshToken,
};
