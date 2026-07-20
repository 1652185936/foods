// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'field_problem.dart';

part 'problem_details.g.dart';

@JsonSerializable()
class ProblemDetails {
  const ProblemDetails({
    required this.code,
    required this.status,
    required this.title,
    required this.traceId,
    required this.type,
    this.detail,
    this.fieldErrors,
  });

  factory ProblemDetails.fromJson(Map<String, Object?> json) =>
      _$ProblemDetailsFromJson(json);

  final String code;
  final String? detail;
  final List<FieldProblem>? fieldErrors;
  final int status;
  final String title;
  final String traceId;
  final String type;

  Map<String, Object?> toJson() => _$ProblemDetailsToJson(this);
}
