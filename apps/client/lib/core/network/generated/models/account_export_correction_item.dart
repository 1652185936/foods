// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'account_export_correction_item.g.dart';

@JsonSerializable()
class AccountExportCorrectionItem {
  const AccountExportCorrectionItem({
    required this.canonicalFoodId,
    required this.carbsMg,
    required this.energyKcal,
    required this.fatMg,
    required this.id,
    required this.name,
    required this.position,
    required this.proteinMg,
    required this.servingMilli,
  });

  factory AccountExportCorrectionItem.fromJson(Map<String, Object?> json) =>
      _$AccountExportCorrectionItemFromJson(json);

  final String? canonicalFoodId;
  final int carbsMg;
  final int energyKcal;
  final int fatMg;
  final String id;
  final String name;
  final int position;
  final int proteinMg;
  final int servingMilli;

  Map<String, Object?> toJson() => _$AccountExportCorrectionItemToJson(this);
}
