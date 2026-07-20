// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'account_deletion_input.g.dart';

@JsonSerializable()
class AccountDeletionInput {
  const AccountDeletionInput({
    required this.confirmation,
    required this.deviceInstallationId,
    required this.refreshToken,
  });

  factory AccountDeletionInput.fromJson(Map<String, Object?> json) =>
      _$AccountDeletionInputFromJson(json);

  final String confirmation;
  final String deviceInstallationId;
  final String refreshToken;

  Map<String, Object?> toJson() => _$AccountDeletionInputToJson(this);
}
