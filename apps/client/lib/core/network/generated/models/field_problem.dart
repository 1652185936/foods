// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'field_problem.g.dart';

@JsonSerializable()
class FieldProblem {
  const FieldProblem({
    required this.code,
    required this.field,
    required this.message,
  });

  factory FieldProblem.fromJson(Map<String, Object?> json) =>
      _$FieldProblemFromJson(json);

  final String code;
  final String field;
  final String message;

  Map<String, Object?> toJson() => _$FieldProblemToJson(this);
}
