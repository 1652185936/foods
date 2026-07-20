// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/completed_recognition_upload_response.dart';
import '../models/recognition_correction_input.dart';
import '../models/recognition_create_input.dart';
import '../models/recognition_response.dart';
import '../models/recognition_upload_input.dart';
import '../models/recognition_upload_response.dart';

part 'recognition_api.g.dart';

@RestApi()
abstract class RecognitionApi {
  factory RecognitionApi(Dio dio, {String? baseUrl}) = _RecognitionApi;

  static const Map<String, dynamic> createRecognitionUploadOpenapiExtras =
      <String, dynamic>{
        'openapi': <String, dynamic>{
          'tags': <String>["recognition"],
          'operationId': "createRecognitionUpload",
          'externalDocsUrl': null,
        },
      };
  static const Map<String, dynamic> completeRecognitionUploadOpenapiExtras =
      <String, dynamic>{
        'openapi': <String, dynamic>{
          'tags': <String>["recognition"],
          'operationId': "completeRecognitionUpload",
          'externalDocsUrl': null,
        },
      };
  static const Map<String, dynamic> createRecognitionOpenapiExtras =
      <String, dynamic>{
        'openapi': <String, dynamic>{
          'tags': <String>["recognition"],
          'operationId': "createRecognition",
          'externalDocsUrl': null,
        },
      };
  static const Map<String, dynamic> getRecognitionOpenapiExtras =
      <String, dynamic>{
        'openapi': <String, dynamic>{
          'tags': <String>["recognition"],
          'operationId': "getRecognition",
          'externalDocsUrl': null,
        },
      };
  static const Map<String, dynamic> correctRecognitionOpenapiExtras =
      <String, dynamic>{
        'openapi': <String, dynamic>{
          'tags': <String>["recognition"],
          'operationId': "correctRecognition",
          'externalDocsUrl': null,
        },
      };

  /// Create a short-lived direct image upload
  @POST('/api/v1/recognition-uploads')
  Future<RecognitionUploadResponse> createRecognitionUpload({
    @Body() required RecognitionUploadInput body,
    @Extras()
    Map<String, dynamic>? extras =
        RecognitionApi.createRecognitionUploadOpenapiExtras,
  });

  /// Validate, decode, and sanitize an uploaded image
  @POST('/api/v1/recognition-uploads/{uploadSessionId}/complete')
  Future<CompletedRecognitionUploadResponse> completeRecognitionUpload({
    @Path('uploadSessionId') required String uploadSessionId,
    @Extras()
    Map<String, dynamic>? extras =
        RecognitionApi.completeRecognitionUploadOpenapiExtras,
  });

  /// Queue food recognition for a sanitized upload
  @POST('/api/v1/recognitions')
  Future<RecognitionResponse> createRecognition({
    @Header('Idempotency-Key') required String idempotencyKey,
    @Body() required RecognitionCreateInput body,
    @Extras()
    Map<String, dynamic>? extras =
        RecognitionApi.createRecognitionOpenapiExtras,
  });

  /// Get a food-recognition task and its structured candidates
  @GET('/api/v1/recognitions/{recognitionId}')
  Future<RecognitionResponse> getRecognition({
    @Path('recognitionId') required String recognitionId,
    @Extras()
    Map<String, dynamic>? extras = RecognitionApi.getRecognitionOpenapiExtras,
  });

  /// Replace recognition candidates with a user-reviewed result
  @PUT('/api/v1/recognitions/{recognitionId}/correction')
  Future<RecognitionResponse> correctRecognition({
    @Path('recognitionId') required String recognitionId,
    @Body() required RecognitionCorrectionInput body,
    @Extras()
    Map<String, dynamic>? extras =
        RecognitionApi.correctRecognitionOpenapiExtras,
  });
}
