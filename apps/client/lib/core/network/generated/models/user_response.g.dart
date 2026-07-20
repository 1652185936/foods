// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserResponse _$UserResponseFromJson(Map<String, dynamic> json) => UserResponse(
  createdAt: DateTime.parse(json['createdAt'] as String),
  id: json['id'] as String,
  nickname: json['nickname'] as String?,
  status: json['status'] as String,
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  version: (json['version'] as num).toInt(),
);

Map<String, dynamic> _$UserResponseToJson(UserResponse instance) =>
    <String, dynamic>{
      'createdAt': instance.createdAt.toIso8601String(),
      'id': instance.id,
      'nickname': instance.nickname,
      'status': instance.status,
      'updatedAt': instance.updatedAt.toIso8601String(),
      'version': instance.version,
    };
