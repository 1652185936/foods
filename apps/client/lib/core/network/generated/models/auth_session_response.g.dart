// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_session_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuthSessionResponse _$AuthSessionResponseFromJson(Map<String, dynamic> json) =>
    AuthSessionResponse(
      tokens: TokenPairResponse.fromJson(
        json['tokens'] as Map<String, dynamic>,
      ),
      user: UserResponse.fromJson(json['user'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$AuthSessionResponseToJson(
  AuthSessionResponse instance,
) => <String, dynamic>{'tokens': instance.tokens, 'user': instance.user};
