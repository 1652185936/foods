// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'refresh_token_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RefreshTokenInput _$RefreshTokenInputFromJson(Map<String, dynamic> json) =>
    RefreshTokenInput(
      deviceInstallationId: json['deviceInstallationId'] as String,
      refreshToken: json['refreshToken'] as String,
    );

Map<String, dynamic> _$RefreshTokenInputToJson(RefreshTokenInput instance) =>
    <String, dynamic>{
      'deviceInstallationId': instance.deviceInstallationId,
      'refreshToken': instance.refreshToken,
    };
