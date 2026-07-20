// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'client_platform.dart';

part 'device_input.g.dart';

@JsonSerializable()
class DeviceInput {
  const DeviceInput({
    required this.appVersion,
    required this.installationId,
    required this.platform,
  });

  factory DeviceInput.fromJson(Map<String, Object?> json) =>
      _$DeviceInputFromJson(json);

  final String appVersion;
  final String installationId;
  final ClientPlatform platform;

  Map<String, Object?> toJson() => _$DeviceInputToJson(this);
}
