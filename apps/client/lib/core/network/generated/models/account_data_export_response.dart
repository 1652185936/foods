// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'account_export_meal.dart';
import 'account_export_recognition.dart';
import 'app_preferences_response.dart';
import 'fasting_session_response.dart';
import 'health_profile_response.dart';
import 'user_response.dart';

part 'account_data_export_response.g.dart';

@JsonSerializable()
class AccountDataExportResponse {
  const AccountDataExportResponse({
    required this.exportedAt,
    required this.fastingSessions,
    required this.healthProfile,
    required this.meals,
    required this.preferences,
    required this.recognitions,
    required this.user,
    this.schemaVersion = 1,
  });

  factory AccountDataExportResponse.fromJson(Map<String, Object?> json) =>
      _$AccountDataExportResponseFromJson(json);

  final DateTime exportedAt;
  final List<FastingSessionResponse> fastingSessions;
  final HealthProfileResponse? healthProfile;
  final List<AccountExportMeal> meals;
  final AppPreferencesResponse? preferences;
  final List<AccountExportRecognition> recognitions;
  final int schemaVersion;
  final UserResponse user;

  Map<String, Object?> toJson() => _$AccountDataExportResponseToJson(this);
}
