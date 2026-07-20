// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'token_pair_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TokenPairResponse _$TokenPairResponseFromJson(Map<String, dynamic> json) =>
    TokenPairResponse(
      accessToken: json['accessToken'] as String,
      accessTokenExpiresAt: DateTime.parse(
        json['accessTokenExpiresAt'] as String,
      ),
      refreshToken: json['refreshToken'] as String,
      refreshTokenExpiresAt: DateTime.parse(
        json['refreshTokenExpiresAt'] as String,
      ),
      tokenType: json['tokenType'] as String? ?? 'Bearer',
    );

Map<String, dynamic> _$TokenPairResponseToJson(TokenPairResponse instance) =>
    <String, dynamic>{
      'accessToken': instance.accessToken,
      'accessTokenExpiresAt': instance.accessTokenExpiresAt.toIso8601String(),
      'refreshToken': instance.refreshToken,
      'refreshTokenExpiresAt': instance.refreshTokenExpiresAt.toIso8601String(),
      'tokenType': instance.tokenType,
    };
