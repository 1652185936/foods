// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_push_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SyncPushInput _$SyncPushInputFromJson(Map<String, dynamic> json) =>
    SyncPushInput(
      operations: (json['operations'] as List<dynamic>)
          .map((e) => SyncOperationInput.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$SyncPushInputToJson(SyncPushInput instance) =>
    <String, dynamic>{'operations': instance.operations};
