// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/health_response.dart';
import '../models/readiness_response.dart';

part 'system_api.g.dart';

@RestApi()
abstract class SystemApi {
  factory SystemApi(Dio dio, {String? baseUrl}) = _SystemApi;

  static const Map<String, dynamic> getHealthOpenapiExtras = <String, dynamic>{
    'openapi': <String, dynamic>{
      'tags': <String>["system"],
      'operationId': "getHealth",
      'externalDocsUrl': null,
    },
  };
  static const Map<String, dynamic> getReadinessOpenapiExtras =
      <String, dynamic>{
        'openapi': <String, dynamic>{
          'tags': <String>["system"],
          'operationId': "getReadiness",
          'externalDocsUrl': null,
        },
      };

  /// Check API health
  @GET('/api/v1/health')
  Future<HealthResponse> getHealth({
    @Extras() Map<String, dynamic>? extras = SystemApi.getHealthOpenapiExtras,
  });

  /// Check dependency readiness
  @GET('/api/v1/ready')
  Future<ReadinessResponse> getReadiness({
    @Extras()
    Map<String, dynamic>? extras = SystemApi.getReadinessOpenapiExtras,
  });
}
