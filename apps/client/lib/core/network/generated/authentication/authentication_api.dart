// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/auth_session_response.dart';
import '../models/otp_challenge_input.dart';
import '../models/otp_challenge_response.dart';
import '../models/otp_verification_input.dart';
import '../models/refresh_token_input.dart';
import '../models/token_pair_response.dart';

part 'authentication_api.g.dart';

@RestApi()
abstract class AuthenticationApi {
  factory AuthenticationApi(Dio dio, {String? baseUrl}) = _AuthenticationApi;

  static const Map<String, dynamic> createOtpChallengeOpenapiExtras =
      <String, dynamic>{
        'openapi': <String, dynamic>{
          'tags': <String>["authentication"],
          'operationId': "createOtpChallenge",
          'externalDocsUrl': null,
        },
      };
  static const Map<String, dynamic> verifyOtpChallengeOpenapiExtras =
      <String, dynamic>{
        'openapi': <String, dynamic>{
          'tags': <String>["authentication"],
          'operationId': "verifyOtpChallenge",
          'externalDocsUrl': null,
        },
      };
  static const Map<String, dynamic> deleteCurrentSessionOpenapiExtras =
      <String, dynamic>{
        'openapi': <String, dynamic>{
          'tags': <String>["authentication"],
          'operationId': "deleteCurrentSession",
          'externalDocsUrl': null,
        },
      };
  static const Map<String, dynamic> refreshAuthTokenOpenapiExtras =
      <String, dynamic>{
        'openapi': <String, dynamic>{
          'tags': <String>["authentication"],
          'operationId': "refreshAuthToken",
          'externalDocsUrl': null,
        },
      };

  /// Request a sign-in code
  @POST('/api/v1/auth/otp/challenges')
  Future<OtpChallengeResponse> createOtpChallenge({
    @Body() required OtpChallengeInput body,
    @Header('Idempotency-Key') String? idempotencyKey,
    @Extras()
    Map<String, dynamic>? extras =
        AuthenticationApi.createOtpChallengeOpenapiExtras,
  });

  /// Verify a sign-in code
  @POST('/api/v1/auth/otp/challenges/{challengeId}/verify')
  Future<AuthSessionResponse> verifyOtpChallenge({
    @Path('challengeId') required String challengeId,
    @Body() required OtpVerificationInput body,
    @Extras()
    Map<String, dynamic>? extras =
        AuthenticationApi.verifyOtpChallengeOpenapiExtras,
  });

  /// Sign out the current session
  @DELETE('/api/v1/auth/sessions/current')
  Future<void> deleteCurrentSession({
    @Extras()
    Map<String, dynamic>? extras =
        AuthenticationApi.deleteCurrentSessionOpenapiExtras,
  });

  /// Rotate a refresh token
  @POST('/api/v1/auth/token/refresh')
  Future<TokenPairResponse> refreshAuthToken({
    @Body() required RefreshTokenInput body,
    @Extras()
    Map<String, dynamic>? extras =
        AuthenticationApi.refreshAuthTokenOpenapiExtras,
  });
}
