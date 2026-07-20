// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'account_export_correction_item.dart';

part 'account_export_correction.g.dart';

@JsonSerializable()
class AccountExportCorrection {
  const AccountExportCorrection({
    required this.baseVersion,
    required this.createdAtUtc,
    required this.id,
    required this.items,
  });

  factory AccountExportCorrection.fromJson(Map<String, Object?> json) =>
      _$AccountExportCorrectionFromJson(json);

  final int baseVersion;
  final DateTime createdAtUtc;
  final String id;
  final List<AccountExportCorrectionItem> items;

  Map<String, Object?> toJson() => _$AccountExportCorrectionToJson(this);
}
