// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'account_export_meal_item.g.dart';

@JsonSerializable()
class AccountExportMealItem {
  const AccountExportMealItem({
    required this.carbsMg,
    required this.energyKcal,
    required this.fatMg,
    required this.id,
    required this.name,
    required this.proteinMg,
    required this.servingMilli,
  });

  factory AccountExportMealItem.fromJson(Map<String, Object?> json) =>
      _$AccountExportMealItemFromJson(json);

  final int carbsMg;
  final int energyKcal;
  final int fatMg;
  final String id;
  final String name;
  final int proteinMg;
  final int servingMilli;

  Map<String, Object?> toJson() => _$AccountExportMealItemToJson(this);
}
