// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'token_pair_response.dart';
import 'user_response.dart';

part 'auth_session_response.g.dart';

@JsonSerializable()
class AuthSessionResponse {
  const AuthSessionResponse({required this.tokens, required this.user});

  factory AuthSessionResponse.fromJson(Map<String, Object?> json) =>
      _$AuthSessionResponseFromJson(json);

  final TokenPairResponse tokens;
  final UserResponse user;

  Map<String, Object?> toJson() => _$AuthSessionResponseToJson(this);
}
