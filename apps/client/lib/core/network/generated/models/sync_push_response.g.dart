// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_push_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SyncPushResponse _$SyncPushResponseFromJson(Map<String, dynamic> json) =>
    SyncPushResponse(
      results: (json['results'] as List<dynamic>)
          .map(
            (e) => SyncWriteResultResponse.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );

Map<String, dynamic> _$SyncPushResponseToJson(SyncPushResponse instance) =>
    <String, dynamic>{'results': instance.results};
