// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'meal_item_input_model.dart';
import 'meal_source.dart';
import 'meal_type.dart';

part 'meal_sync_payload.g.dart';

@JsonSerializable()
class MealSyncPayload {
  const MealSyncPayload({
    required this.isWithinEatingWindow,
    required this.items,
    required this.localDay,
    required this.occurredAtUtc,
    required this.source,
    required this.timeZoneId,
    required this.type,
  });

  factory MealSyncPayload.fromJson(Map<String, Object?> json) =>
      _$MealSyncPayloadFromJson(json);

  final bool isWithinEatingWindow;
  final List<MealItemInputModel> items;
  final String localDay;
  final DateTime occurredAtUtc;
  final MealSource source;
  final String timeZoneId;
  final MealType type;

  Map<String, Object?> toJson() => _$MealSyncPayloadToJson(this);
}
