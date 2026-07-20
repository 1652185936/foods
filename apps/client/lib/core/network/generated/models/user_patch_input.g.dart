// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_patch_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserPatchInput _$UserPatchInputFromJson(Map<String, dynamic> json) =>
    UserPatchInput(
      expectedVersion: (json['expectedVersion'] as num).toInt(),
      nickname: json['nickname'] as String,
    );

Map<String, dynamic> _$UserPatchInputToJson(UserPatchInput instance) =>
    <String, dynamic>{
      'expectedVersion': instance.expectedVersion,
      'nickname': instance.nickname,
    };
