// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'readiness_response.g.dart';

@JsonSerializable()
class ReadinessResponse {
  const ReadinessResponse({this.status = 'ready'});

  factory ReadinessResponse.fromJson(Map<String, Object?> json) =>
      _$ReadinessResponseFromJson(json);

  final String status;

  Map<String, Object?> toJson() => _$ReadinessResponseToJson(this);
}
