// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'user_response.g.dart';

@JsonSerializable()
class UserResponse {
  const UserResponse({
    required this.createdAt,
    required this.id,
    required this.nickname,
    required this.status,
    required this.updatedAt,
    required this.version,
  });

  factory UserResponse.fromJson(Map<String, Object?> json) =>
      _$UserResponseFromJson(json);

  final DateTime createdAt;
  final String id;
  final String? nickname;
  final String status;
  final DateTime updatedAt;
  final int version;

  Map<String, Object?> toJson() => _$UserResponseToJson(this);
}
