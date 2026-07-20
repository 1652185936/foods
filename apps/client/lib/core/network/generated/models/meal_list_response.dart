// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'meal_response.dart';

part 'meal_list_response.g.dart';

@JsonSerializable()
class MealListResponse {
  const MealListResponse({required this.items});

  factory MealListResponse.fromJson(Map<String, Object?> json) =>
      _$MealListResponseFromJson(json);

  final List<MealResponse> items;

  Map<String, Object?> toJson() => _$MealListResponseToJson(this);
}
