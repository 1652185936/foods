// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'sync_write_result_response.dart';

part 'sync_push_response.g.dart';

@JsonSerializable()
class SyncPushResponse {
  const SyncPushResponse({required this.results});

  factory SyncPushResponse.fromJson(Map<String, Object?> json) =>
      _$SyncPushResponseFromJson(json);

  final List<SyncWriteResultResponse> results;

  Map<String, Object?> toJson() => _$SyncPushResponseToJson(this);
}
