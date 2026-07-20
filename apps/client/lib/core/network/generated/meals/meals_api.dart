// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/meal_list_response.dart';
import '../models/meal_response.dart';

part 'meals_api.g.dart';

@RestApi()
abstract class MealsApi {
  factory MealsApi(Dio dio, {String? baseUrl}) = _MealsApi;

  static const Map<String, dynamic> listMealsOpenapiExtras = <String, dynamic>{
    'openapi': <String, dynamic>{
      'tags': <String>["meals"],
      'operationId': "listMeals",
      'externalDocsUrl': null,
    },
  };
  static const Map<String, dynamic> getMealOpenapiExtras = <String, dynamic>{
    'openapi': <String, dynamic>{
      'tags': <String>["meals"],
      'operationId': "getMeal",
      'externalDocsUrl': null,
    },
  };

  /// List current meal records
  @GET('/api/v1/meals')
  Future<MealListResponse> listMeals({
    @Query('limit') int? limit = 100,
    @Query('localDay') String? localDay,
    @Extras() Map<String, dynamic>? extras = MealsApi.listMealsOpenapiExtras,
  });

  /// Get a current meal record
  @GET('/api/v1/meals/{mealId}')
  Future<MealResponse> getMeal({
    @Path('mealId') required String mealId,
    @Extras() Map<String, dynamic>? extras = MealsApi.getMealOpenapiExtras,
  });
}
