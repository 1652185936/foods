// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'token_pair_response.g.dart';

@JsonSerializable()
class TokenPairResponse {
  const TokenPairResponse({
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshToken,
    required this.refreshTokenExpiresAt,
    this.tokenType = 'Bearer',
  });

  factory TokenPairResponse.fromJson(Map<String, Object?> json) =>
      _$TokenPairResponseFromJson(json);

  final String accessToken;
  final DateTime accessTokenExpiresAt;
  final String refreshToken;
  final DateTime refreshTokenExpiresAt;
  final String tokenType;

  Map<String, Object?> toJson() => _$TokenPairResponseToJson(this);
}
