// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'fasting_session_response.dart';

part 'fasting_session_list_response.g.dart';

@JsonSerializable()
class FastingSessionListResponse {
  const FastingSessionListResponse({required this.items});

  factory FastingSessionListResponse.fromJson(Map<String, Object?> json) =>
      _$FastingSessionListResponseFromJson(json);

  final List<FastingSessionResponse> items;

  Map<String, Object?> toJson() => _$FastingSessionListResponseToJson(this);
}
