// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_pull_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SyncPullResponse _$SyncPullResponseFromJson(Map<String, dynamic> json) =>
    SyncPullResponse(
      changes: (json['changes'] as List<dynamic>)
          .map((e) => SyncChangeResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasMore: json['hasMore'] as bool,
      nextCursor: (json['nextCursor'] as num).toInt(),
    );

Map<String, dynamic> _$SyncPullResponseToJson(SyncPullResponse instance) =>
    <String, dynamic>{
      'changes': instance.changes,
      'hasMore': instance.hasMore,
      'nextCursor': instance.nextCursor,
    };
