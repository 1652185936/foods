import 'package:dio/dio.dart';

import 'auth_tokens.dart';
import 'generated/authentication/authentication_api.dart';
import 'generated/models/refresh_token_input.dart';

/// Rotates tokens through the public Dio client, avoiding interceptor recursion.
final class ApiAccessTokenRefresher implements AccessTokenRefresher {
  factory ApiAccessTokenRefresher({
    required AuthenticationApi authenticationApi,
    required AuthCredentialStore tokenStore,
    required DeviceInstallationIdLoader loadDeviceInstallationId,
    DateTime Function()? clock,
  }) => ApiAccessTokenRefresher._(
    authenticationApi,
    tokenStore,
    loadDeviceInstallationId,
    clock ?? DateTime.now,
  );

  ApiAccessTokenRefresher._(
    this._authenticationApi,
    this._tokenStore,
    this._loadDeviceInstallationId,
    this._clock,
  );

  final AuthenticationApi _authenticationApi;
  final AuthCredentialStore _tokenStore;
  final DeviceInstallationIdLoader _loadDeviceInstallationId;
  final DateTime Function() _clock;

  @override
  Future<AuthTokens?> refreshAccessToken({required int expectedEpoch}) async {
    final snapshot = await _tokenStore.readSnapshot();
    if (snapshot.epoch != expectedEpoch) {
      return null;
    }
    final current = snapshot.tokens;
    if (current == null) {
      return null;
    }
    if (!current.refreshTokenExpiresAt.isAfter(_clock())) {
      await _tokenStore.clearIfCurrent(snapshot);
      return null;
    }

    final installationId = await _loadDeviceInstallationId();
    if (installationId.isEmpty) {
      throw StateError('Device installation ID must not be empty.');
    }

    try {
      final response = await _authenticationApi.refreshAuthToken(
        body: RefreshTokenInput(
          deviceInstallationId: installationId,
          refreshToken: current.refreshToken,
        ),
      );
      final rotated = AuthTokens.fromResponse(response, now: _clock());
      return _tokenStore.writeRefreshedIfCurrent(rotated, expected: snapshot);
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await _tokenStore.clearIfCurrent(snapshot);
        return null;
      }
      rethrow;
    } on FormatException {
      await _tokenStore.clearIfCurrent(snapshot);
      rethrow;
    }
  }
}
