// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'refresh_token_input.g.dart';

@JsonSerializable()
class RefreshTokenInput {
  const RefreshTokenInput({
    required this.deviceInstallationId,
    required this.refreshToken,
  });

  factory RefreshTokenInput.fromJson(Map<String, Object?> json) =>
      _$RefreshTokenInputFromJson(json);

  final String deviceInstallationId;
  final String refreshToken;

  Map<String, Object?> toJson() => _$RefreshTokenInputToJson(this);
}
