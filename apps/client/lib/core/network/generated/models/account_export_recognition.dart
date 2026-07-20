// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'account_export_correction.dart';
import 'account_export_recognition_item.dart';

part 'account_export_recognition.g.dart';

@JsonSerializable()
class AccountExportRecognition {
  const AccountExportRecognition({
    required this.completedAtUtc,
    required this.corrections,
    required this.createdAtUtc,
    required this.errorCode,
    required this.id,
    required this.items,
    required this.needsReviewReason,
    required this.overallConfidenceMilli,
    required this.status,
    required this.updatedAtUtc,
    required this.version,
  });

  factory AccountExportRecognition.fromJson(Map<String, Object?> json) =>
      _$AccountExportRecognitionFromJson(json);

  final DateTime? completedAtUtc;
  final List<AccountExportCorrection> corrections;
  final DateTime createdAtUtc;
  final String? errorCode;
  final String id;
  final List<AccountExportRecognitionItem> items;
  final String? needsReviewReason;
  final int? overallConfidenceMilli;
  final String status;
  final DateTime updatedAtUtc;
  final int version;

  Map<String, Object?> toJson() => _$AccountExportRecognitionToJson(this);
}
