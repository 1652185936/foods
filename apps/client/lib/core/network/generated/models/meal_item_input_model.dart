// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'meal_item_input_model.g.dart';

@JsonSerializable()
class MealItemInputModel {
  const MealItemInputModel({
    required this.carbsMg,
    required this.energyKcal,
    required this.fatMg,
    required this.id,
    required this.name,
    required this.proteinMg,
    required this.servingMilli,
    this.imageReference,
  });

  factory MealItemInputModel.fromJson(Map<String, Object?> json) =>
      _$MealItemInputModelFromJson(json);

  final int carbsMg;
  final int energyKcal;
  final int fatMg;
  final String id;
  final String? imageReference;
  final String name;
  final int proteinMg;
  final int servingMilli;

  Map<String, Object?> toJson() => _$MealItemInputModelToJson(this);
}
