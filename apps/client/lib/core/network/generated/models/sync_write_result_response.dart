// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'sync_entity_type.dart';
import 'sync_write_status.dart';

part 'sync_write_result_response.g.dart';

@JsonSerializable()
class SyncWriteResultResponse {
  const SyncWriteResultResponse({
    required this.changeCursor,
    required this.entityId,
    required this.entityType,
    required this.operationId,
    required this.replayed,
    required this.serverVersion,
    required this.status,
  });

  factory SyncWriteResultResponse.fromJson(Map<String, Object?> json) =>
      _$SyncWriteResultResponseFromJson(json);

  final int? changeCursor;
  final String entityId;
  final SyncEntityType entityType;
  final String operationId;
  final bool replayed;
  final int? serverVersion;
  final SyncWriteStatus status;

  Map<String, Object?> toJson() => _$SyncWriteResultResponseToJson(this);
}
