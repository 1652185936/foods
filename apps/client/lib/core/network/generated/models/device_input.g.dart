// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeviceInput _$DeviceInputFromJson(Map<String, dynamic> json) => DeviceInput(
  appVersion: json['appVersion'] as String,
  installationId: json['installationId'] as String,
  platform: ClientPlatform.fromJson(json['platform'] as String),
);

Map<String, dynamic> _$DeviceInputToJson(DeviceInput instance) =>
    <String, dynamic>{
      'appVersion': instance.appVersion,
      'installationId': instance.installationId,
      'platform': _$ClientPlatformEnumMap[instance.platform]!,
    };

const _$ClientPlatformEnumMap = {
  ClientPlatform.android: 'android',
  ClientPlatform.ios: 'ios',
  ClientPlatform.windows: 'windows',
  ClientPlatform.macos: 'macos',
  ClientPlatform.$unknown: r'$unknown',
};
