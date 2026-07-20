// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'app_preferences_sync_payload.dart';
import 'fasting_session_sync_payload.dart';
import 'meal_sync_payload.dart';
import 'sync_action.dart';
import 'sync_entity_type.dart';

part 'sync_operation_input.g.dart';

@JsonSerializable()
class SyncOperationInput {
  const SyncOperationInput({
    required this.action,
    required this.entityId,
    required this.entityType,
    required this.expectedVersion,
    required this.operationId,
    this.payloadVersion = 1,
    this.appPreferences,
    this.fastingSession,
    this.meal,
  });

  factory SyncOperationInput.fromJson(Map<String, Object?> json) =>
      _$SyncOperationInputFromJson(json);

  final SyncAction action;
  final AppPreferencesSyncPayload? appPreferences;
  final String entityId;
  final SyncEntityType entityType;
  final int expectedVersion;
  final FastingSessionSyncPayload? fastingSession;
  final MealSyncPayload? meal;
  final String operationId;
  final int payloadVersion;

  Map<String, Object?> toJson() => _$SyncOperationInputToJson(this);
}
