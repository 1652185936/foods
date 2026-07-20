// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'account_export_meal_item.dart';
import 'meal_source.dart';
import 'meal_type.dart';

part 'account_export_meal.g.dart';

@JsonSerializable()
class AccountExportMeal {
  const AccountExportMeal({
    required this.createdAtUtc,
    required this.id,
    required this.isWithinEatingWindow,
    required this.items,
    required this.localDay,
    required this.occurredAtUtc,
    required this.source,
    required this.timeZoneId,
    required this.type,
    required this.updatedAtUtc,
    required this.version,
  });

  factory AccountExportMeal.fromJson(Map<String, Object?> json) =>
      _$AccountExportMealFromJson(json);

  final DateTime createdAtUtc;
  final String id;
  final bool isWithinEatingWindow;
  final List<AccountExportMealItem> items;
  final String localDay;
  final DateTime occurredAtUtc;
  final MealSource source;
  final String timeZoneId;
  final MealType type;
  final DateTime updatedAtUtc;
  final int version;

  Map<String, Object?> toJson() => _$AccountExportMealToJson(this);
}
