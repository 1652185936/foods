// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'user_patch_input.g.dart';

@JsonSerializable()
class UserPatchInput {
  const UserPatchInput({required this.expectedVersion, required this.nickname});

  factory UserPatchInput.fromJson(Map<String, Object?> json) =>
      _$UserPatchInputFromJson(json);

  final int expectedVersion;
  final String nickname;

  Map<String, Object?> toJson() => _$UserPatchInputToJson(this);
}
