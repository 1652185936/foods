// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'sync_change_response.dart';

part 'sync_pull_response.g.dart';

@JsonSerializable()
class SyncPullResponse {
  const SyncPullResponse({
    required this.changes,
    required this.hasMore,
    required this.nextCursor,
  });

  factory SyncPullResponse.fromJson(Map<String, Object?> json) =>
      _$SyncPullResponseFromJson(json);

  final List<SyncChangeResponse> changes;
  final bool hasMore;
  final int nextCursor;

  Map<String, Object?> toJson() => _$SyncPullResponseToJson(this);
}
