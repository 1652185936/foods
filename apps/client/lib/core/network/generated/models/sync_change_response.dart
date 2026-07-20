// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'app_preferences_response.dart';
import 'fasting_session_response.dart';
import 'meal_response.dart';
import 'sync_entity_type.dart';

part 'sync_change_response.g.dart';

@JsonSerializable()
class SyncChangeResponse {
  const SyncChangeResponse({
    required this.changeCursor,
    required this.deletedAtUtc,
    required this.entityId,
    required this.entityType,
    required this.version,
    this.appPreferences,
    this.fastingSession,
    this.meal,
  });

  factory SyncChangeResponse.fromJson(Map<String, Object?> json) =>
      _$SyncChangeResponseFromJson(json);

  final AppPreferencesResponse? appPreferences;
  final int changeCursor;
  final DateTime? deletedAtUtc;
  final String entityId;
  final SyncEntityType entityType;
  final FastingSessionResponse? fastingSession;
  final MealResponse? meal;
  final int version;

  Map<String, Object?> toJson() => _$SyncChangeResponseToJson(this);
}
