// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'fasting_plan.dart';
import 'fasting_session_status.dart';

part 'fasting_session_sync_payload.g.dart';

@JsonSerializable()
class FastingSessionSyncPayload {
  const FastingSessionSyncPayload({
    required this.plan,
    required this.startedAtUtc,
    required this.startedLocalDay,
    required this.status,
    required this.targetEndAtUtc,
    required this.targetEndLocalDay,
    required this.timeZoneId,
    this.endedAtUtc,
    this.endedLocalDay,
  });

  factory FastingSessionSyncPayload.fromJson(Map<String, Object?> json) =>
      _$FastingSessionSyncPayloadFromJson(json);

  final DateTime? endedAtUtc;
  final String? endedLocalDay;
  final FastingPlan plan;
  final DateTime startedAtUtc;
  final String startedLocalDay;
  final FastingSessionStatus status;
  final DateTime targetEndAtUtc;
  final String targetEndLocalDay;
  final String timeZoneId;

  Map<String, Object?> toJson() => _$FastingSessionSyncPayloadToJson(this);
}
