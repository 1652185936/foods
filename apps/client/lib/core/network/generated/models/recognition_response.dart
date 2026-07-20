// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'recognition_item_response.dart';

part 'recognition_response.g.dart';

@JsonSerializable()
class RecognitionResponse {
  const RecognitionResponse({
    required this.completedAt,
    required this.createdAt,
    required this.errorCode,
    required this.id,
    required this.items,
    required this.needsReviewReason,
    required this.overallConfidenceMilli,
    required this.providerName,
    required this.sourceExpiresAt,
    required this.status,
    required this.updatedAt,
    required this.uploadSessionId,
    required this.version,
  });

  factory RecognitionResponse.fromJson(Map<String, Object?> json) =>
      _$RecognitionResponseFromJson(json);

  final DateTime? completedAt;
  final DateTime createdAt;
  final String? errorCode;
  final String id;
  final List<RecognitionItemResponse> items;
  final String? needsReviewReason;
  final int? overallConfidenceMilli;
  final String? providerName;
  final DateTime sourceExpiresAt;
  final String status;
  final DateTime updatedAt;
  final String uploadSessionId;
  final int version;

  Map<String, Object?> toJson() => _$RecognitionResponseToJson(this);
}
