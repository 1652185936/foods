// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';

import 'authentication/authentication_api.dart';
import 'fasting/fasting_api.dart';
import 'system/system_api.dart';
import 'meals/meals_api.dart';
import 'recognition/recognition_api.dart';
import 'synchronization/synchronization_api.dart';
import 'users/users_api.dart';

/// Ordin API `v0.1.0`
class OrdinApiClient {
  OrdinApiClient(Dio dio, {String? baseUrl}) : _dio = dio, _baseUrl = baseUrl;

  final Dio _dio;
  final String? _baseUrl;

  static String get version => '0.1.0';

  AuthenticationApi? _authentication;
  FastingApi? _fasting;
  SystemApi? _system;
  MealsApi? _meals;
  RecognitionApi? _recognition;
  SynchronizationApi? _synchronization;
  UsersApi? _users;

  AuthenticationApi get authentication =>
      _authentication ??= AuthenticationApi(_dio, baseUrl: _baseUrl);

  FastingApi get fasting => _fasting ??= FastingApi(_dio, baseUrl: _baseUrl);

  SystemApi get system => _system ??= SystemApi(_dio, baseUrl: _baseUrl);

  MealsApi get meals => _meals ??= MealsApi(_dio, baseUrl: _baseUrl);

  RecognitionApi get recognition =>
      _recognition ??= RecognitionApi(_dio, baseUrl: _baseUrl);

  SynchronizationApi get synchronization =>
      _synchronization ??= SynchronizationApi(_dio, baseUrl: _baseUrl);

  UsersApi get users => _users ??= UsersApi(_dio, baseUrl: _baseUrl);
}
