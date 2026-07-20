// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/fasting_session_list_response.dart';
import '../models/fasting_session_response.dart';
import '../models/fasting_session_status.dart';

part 'fasting_api.g.dart';

@RestApi()
abstract class FastingApi {
  factory FastingApi(Dio dio, {String? baseUrl}) = _FastingApi;

  static const Map<String, dynamic> listFastingSessionsOpenapiExtras =
      <String, dynamic>{
        'openapi': <String, dynamic>{
          'tags': <String>["fasting"],
          'operationId': "listFastingSessions",
          'externalDocsUrl': null,
        },
      };
  static const Map<String, dynamic> getFastingSessionOpenapiExtras =
      <String, dynamic>{
        'openapi': <String, dynamic>{
          'tags': <String>["fasting"],
          'operationId': "getFastingSession",
          'externalDocsUrl': null,
        },
      };

  /// List current fasting sessions
  @GET('/api/v1/fasting-sessions')
  Future<FastingSessionListResponse> listFastingSessions({
    @Query('limit') int? limit = 100,
    @Query('status') FastingSessionStatus? status,
    @Extras()
    Map<String, dynamic>? extras = FastingApi.listFastingSessionsOpenapiExtras,
  });

  /// Get a current fasting session
  @GET('/api/v1/fasting-sessions/{fastingSessionId}')
  Future<FastingSessionResponse> getFastingSession({
    @Path('fastingSessionId') required String fastingSessionId,
    @Extras()
    Map<String, dynamic>? extras = FastingApi.getFastingSessionOpenapiExtras,
  });
}
