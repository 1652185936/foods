// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'fasting_plan.dart';
import 'fasting_session_status.dart';

part 'fasting_session_response.g.dart';

@JsonSerializable()
class FastingSessionResponse {
  const FastingSessionResponse({
    required this.changeCursor,
    required this.createdAtUtc,
    required this.endedAtUtc,
    required this.id,
    required this.plan,
    required this.startedAtUtc,
    required this.startedLocalDay,
    required this.status,
    required this.targetEndAtUtc,
    required this.targetEndLocalDay,
    required this.timeZoneId,
    required this.updatedAtUtc,
    required this.version,
    this.endedLocalDay,
  });

  factory FastingSessionResponse.fromJson(Map<String, Object?> json) =>
      _$FastingSessionResponseFromJson(json);

  final int changeCursor;
  final DateTime createdAtUtc;
  final DateTime? endedAtUtc;
  final String? endedLocalDay;
  final String id;
  final FastingPlan plan;
  final DateTime startedAtUtc;
  final String startedLocalDay;
  final FastingSessionStatus status;
  final DateTime targetEndAtUtc;
  final String targetEndLocalDay;
  final String timeZoneId;
  final DateTime updatedAtUtc;
  final int version;

  Map<String, Object?> toJson() => _$FastingSessionResponseToJson(this);
}
