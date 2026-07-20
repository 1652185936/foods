import 'package:dio/dio.dart';

import 'api_access_token_refresher.dart';
import 'auth_tokens.dart';
import 'bearer_auth_interceptor.dart';
import 'generated/authentication/authentication_api.dart';
import 'generated/fasting/fasting_api.dart';
import 'generated/meals/meals_api.dart';
import 'generated/ordin_api_client.dart';
import 'generated/recognition/recognition_api.dart';
import 'generated/synchronization/synchronization_api.dart';
import 'generated/system/system_api.dart';
import 'generated/users/users_api.dart';

/// Owns isolated public and authenticated transports for the Ordin API.
final class OrdinApiClients {
  OrdinApiClients._({
    required this.publicDio,
    required this.authenticatedDio,
    required OrdinApiClient publicApi,
    required OrdinApiClient authenticatedApi,
  }) : publicAuthentication = publicApi.authentication,
       authenticatedAuthentication = authenticatedApi.authentication,
       system = publicApi.system,
       meals = authenticatedApi.meals,
       fasting = authenticatedApi.fasting,
       recognition = authenticatedApi.recognition,
       synchronization = authenticatedApi.synchronization,
       users = authenticatedApi.users;

  factory OrdinApiClients.create({
    required Uri baseUri,
    required AuthCredentialStore tokenStore,
    required DeviceInstallationIdLoader loadDeviceInstallationId,
    Duration connectTimeout = const Duration(seconds: 10),
    Duration receiveTimeout = const Duration(seconds: 20),
    Duration sendTimeout = const Duration(seconds: 20),
  }) {
    _validateBaseUri(baseUri);
    BaseOptions options() => BaseOptions(
      baseUrl: baseUri.toString(),
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      sendTimeout: sendTimeout,
      headers: const {'Accept': 'application/json, application/problem+json'},
    );

    final publicDio = Dio(options());
    final publicApi = OrdinApiClient(publicDio);
    final authenticatedDio = Dio(options());
    final refresher = ApiAccessTokenRefresher(
      authenticationApi: publicApi.authentication,
      tokenStore: tokenStore,
      loadDeviceInstallationId: loadDeviceInstallationId,
    );
    authenticatedDio.interceptors.add(
      BearerAuthInterceptor(
        authenticatedDio: authenticatedDio,
        tokenStore: tokenStore,
        tokenRefresher: refresher,
      ),
    );

    return OrdinApiClients._(
      publicDio: publicDio,
      authenticatedDio: authenticatedDio,
      publicApi: publicApi,
      authenticatedApi: OrdinApiClient(authenticatedDio),
    );
  }

  final Dio publicDio;
  final Dio authenticatedDio;

  /// OTP and refresh calls use this API so a refresh 401 cannot recurse.
  final AuthenticationApi publicAuthentication;

  /// Logout uses this API because the operation requires a bearer token.
  final AuthenticationApi authenticatedAuthentication;

  final SystemApi system;
  final MealsApi meals;
  final FastingApi fasting;
  final RecognitionApi recognition;
  final SynchronizationApi synchronization;
  final UsersApi users;

  void close({bool force = false}) {
    publicDio.close(force: force);
    authenticatedDio.close(force: force);
  }

  static void _validateBaseUri(Uri value) {
    final isLocalHttp = value.scheme == 'http' && _isLoopback(value.host);
    if (!value.isAbsolute ||
        (value.scheme != 'https' && !isLocalHttp) ||
        value.host.isEmpty ||
        value.userInfo.isNotEmpty ||
        (value.path.isNotEmpty && value.path != '/') ||
        value.hasQuery ||
        value.hasFragment) {
      throw ArgumentError.value(
        value,
        'baseUri',
        'Must be an HTTPS origin, or an HTTP localhost/loopback origin.',
      );
    }
  }

  static bool _isLoopback(String host) {
    final normalized = host.toLowerCase();
    if (normalized == 'localhost' ||
        normalized == '::1' ||
        normalized == '0:0:0:0:0:0:0:1') {
      return true;
    }
    final octets = normalized.split('.');
    if (octets.length != 4 || octets.first != '127') {
      return false;
    }
    return octets.every((octet) {
      final value = int.tryParse(octet);
      return value != null && value >= 0 && value <= 255;
    });
  }
}
