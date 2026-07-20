// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/sync_pull_response.dart';
import '../models/sync_push_input.dart';
import '../models/sync_push_response.dart';

part 'synchronization_api.g.dart';

@RestApi()
abstract class SynchronizationApi {
  factory SynchronizationApi(Dio dio, {String? baseUrl}) = _SynchronizationApi;

  static const Map<String, dynamic> pullSyncChangesOpenapiExtras =
      <String, dynamic>{
        'openapi': <String, dynamic>{
          'tags': <String>["synchronization"],
          'operationId': "pullSyncChanges",
          'externalDocsUrl': null,
        },
      };
  static const Map<String, dynamic> pushSyncOperationsOpenapiExtras =
      <String, dynamic>{
        'openapi': <String, dynamic>{
          'tags': <String>["synchronization"],
          'operationId': "pushSyncOperations",
          'externalDocsUrl': null,
        },
      };

  /// Pull ordered changes after a synchronization cursor
  @GET('/api/v1/sync/pull')
  Future<SyncPullResponse> pullSyncChanges({
    @Query('cursor') int? cursor = 0,
    @Query('limit') int? limit = 100,
    @Extras()
    Map<String, dynamic>? extras =
        SynchronizationApi.pullSyncChangesOpenapiExtras,
  });

  /// Push an ordered batch of offline operations
  @POST('/api/v1/sync/push')
  Future<SyncPushResponse> pushSyncOperations({
    @Body() required SyncPushInput body,
    @Extras()
    Map<String, dynamic>? extras =
        SynchronizationApi.pushSyncOperationsOpenapiExtras,
  });
}
