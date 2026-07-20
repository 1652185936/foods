// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/account_data_export_response.dart';
import '../models/account_deletion_input.dart';
import '../models/app_preferences_response.dart';
import '../models/health_profile_input_model.dart';
import '../models/health_profile_response.dart';
import '../models/user_patch_input.dart';
import '../models/user_response.dart';

part 'users_api.g.dart';

@RestApi()
abstract class UsersApi {
  factory UsersApi(Dio dio, {String? baseUrl}) = _UsersApi;

  static const Map<String, dynamic> deleteCurrentUserOpenapiExtras =
      <String, dynamic>{
        'openapi': <String, dynamic>{
          'tags': <String>["users"],
          'operationId': "deleteCurrentUser",
          'externalDocsUrl': null,
        },
      };
  static const Map<String, dynamic> getCurrentUserOpenapiExtras =
      <String, dynamic>{
        'openapi': <String, dynamic>{
          'tags': <String>["users"],
          'operationId': "getCurrentUser",
          'externalDocsUrl': null,
        },
      };
  static const Map<String, dynamic> updateCurrentUserOpenapiExtras =
      <String, dynamic>{
        'openapi': <String, dynamic>{
          'tags': <String>["users"],
          'operationId': "updateCurrentUser",
          'externalDocsUrl': null,
        },
      };
  static const Map<String, dynamic> exportCurrentUserDataOpenapiExtras =
      <String, dynamic>{
        'openapi': <String, dynamic>{
          'tags': <String>["users"],
          'operationId': "exportCurrentUserData",
          'externalDocsUrl': null,
        },
      };
  static const Map<String, dynamic> getCurrentHealthProfileOpenapiExtras =
      <String, dynamic>{
        'openapi': <String, dynamic>{
          'tags': <String>["users"],
          'operationId': "getCurrentHealthProfile",
          'externalDocsUrl': null,
        },
      };
  static const Map<String, dynamic> putCurrentHealthProfileOpenapiExtras =
      <String, dynamic>{
        'openapi': <String, dynamic>{
          'tags': <String>["users"],
          'operationId': "putCurrentHealthProfile",
          'externalDocsUrl': null,
        },
      };
  static const Map<String, dynamic> getCurrentAppPreferencesOpenapiExtras =
      <String, dynamic>{
        'openapi': <String, dynamic>{
          'tags': <String>["users"],
          'operationId': "getCurrentAppPreferences",
          'externalDocsUrl': null,
        },
      };

  /// Permanently delete the current account and all of its data
  @DELETE('/api/v1/users/me')
  Future<void> deleteCurrentUser({
    @Body() required AccountDeletionInput body,
    @Extras()
    Map<String, dynamic>? extras = UsersApi.deleteCurrentUserOpenapiExtras,
  });

  /// Get the current user
  @GET('/api/v1/users/me')
  Future<UserResponse> getCurrentUser({
    @Extras()
    Map<String, dynamic>? extras = UsersApi.getCurrentUserOpenapiExtras,
  });

  /// Update the current user
  @PATCH('/api/v1/users/me')
  Future<UserResponse> updateCurrentUser({
    @Body() required UserPatchInput body,
    @Extras()
    Map<String, dynamic>? extras = UsersApi.updateCurrentUserOpenapiExtras,
  });

  /// Export a bounded, consistent snapshot of the current user's data
  @GET('/api/v1/users/me/data-export')
  Future<AccountDataExportResponse> exportCurrentUserData({
    @Extras()
    Map<String, dynamic>? extras = UsersApi.exportCurrentUserDataOpenapiExtras,
  });

  /// Get the current health profile
  @GET('/api/v1/users/me/health-profile')
  Future<HealthProfileResponse> getCurrentHealthProfile({
    @Extras()
    Map<String, dynamic>? extras =
        UsersApi.getCurrentHealthProfileOpenapiExtras,
  });

  /// Create or replace the current health profile
  @PUT('/api/v1/users/me/health-profile')
  Future<HealthProfileResponse> putCurrentHealthProfile({
    @Body() required HealthProfileInputModel body,
    @Extras()
    Map<String, dynamic>? extras =
        UsersApi.putCurrentHealthProfileOpenapiExtras,
  });

  /// Get the current application preferences
  @GET('/api/v1/users/me/preferences')
  Future<AppPreferencesResponse> getCurrentAppPreferences({
    @Extras()
    Map<String, dynamic>? extras =
        UsersApi.getCurrentAppPreferencesOpenapiExtras,
  });
}
