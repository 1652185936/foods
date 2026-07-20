import 'dart:async';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../network/auth_tokens.dart';
import '../network/generated/models/client_platform.dart';
import '../network/generated/models/device_input.dart';
import '../network/generated/models/otp_challenge_input.dart';
import '../network/generated/models/otp_verification_input.dart';
import '../network/generated/models/refresh_token_input.dart';
import '../network/generated/models/user_response.dart';
import 'auth_models.dart';
import 'auth_remote_api.dart';
import 'device_installation_id_store.dart';

abstract interface class AuthSessionRepository {
  Future<OtpChallenge> requestOtpChallenge(String phoneNumber);

  Future<AuthSession> verifyOtp({
    required String challengeId,
    required String code,
  });

  Future<AuthSession?> restoreSession();

  Future<AuthSession?> refreshSession();

  void cancelPendingAuthentication();

  Future<void> logout();
}

final class AuthRepository implements AuthSessionRepository {
  AuthRepository(
    this._remoteApi,
    this._tokenStore,
    this._installationIds, {
    required ClientPlatform platform,
    required String appVersion,
    DateTime Function()? clock,
    String Function()? generateOperationId,
    this.accessRefreshLeeway = const Duration(seconds: 30),
  }) : _platform = platform,
       _appVersion = _validateAppVersion(appVersion),
       _clock = clock ?? DateTime.now,
       _generateOperationId = generateOperationId ?? const Uuid().v4 {
    if (platform == ClientPlatform.$unknown) {
      throw ArgumentError.value(
        platform,
        'platform',
        'Unsupported client platform.',
      );
    }
  }

  static final _e164 = RegExp(r'^\+[1-9][0-9]{7,14}$');
  static final _otp = RegExp(r'^[0-9]{6}$');
  static final _canonicalUuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );

  final AuthRemoteApi _remoteApi;
  final AuthSessionCredentialStore _tokenStore;
  final DeviceInstallationIdStore _installationIds;
  final ClientPlatform _platform;
  final String _appVersion;
  final DateTime Function() _clock;
  final String Function() _generateOperationId;
  final Duration accessRefreshLeeway;

  Future<AuthSession?>? _restoreInFlight;
  Future<AuthSession?>? _refreshInFlight;
  var _otpVerificationGeneration = 0;

  @override
  void cancelPendingAuthentication() {
    _otpVerificationGeneration++;
  }

  @override
  Future<OtpChallenge> requestOtpChallenge(String phoneNumber) async {
    if (!_e164.hasMatch(phoneNumber)) {
      throw const FormatException('Phone number must use E.164 format.');
    }
    final operationId = _generateOperationId().toLowerCase();
    _requireCanonicalUuid(operationId, fieldName: 'operationId');
    final response = await _remoteApi.createOtpChallenge(
      body: OtpChallengeInput(
        phoneNumber: phoneNumber,
        deviceInstallationId: await _installationIds.loadOrCreate(),
      ),
      idempotencyKey: operationId,
    );
    _requireCanonicalUuid(response.challengeId, fieldName: 'challengeId');
    if (!response.expiresAt.isUtc ||
        !response.expiresAt.isAfter(_clock().toUtc()) ||
        response.resendAfterSeconds < 0) {
      throw const FormatException('OTP challenge response is invalid.');
    }
    return OtpChallenge(
      id: response.challengeId,
      expiresAtUtc: response.expiresAt,
      resendAfter: Duration(seconds: response.resendAfterSeconds),
    );
  }

  @override
  Future<AuthSession> verifyOtp({
    required String challengeId,
    required String code,
  }) async {
    _requireCanonicalUuid(challengeId, fieldName: 'challengeId');
    if (!_otp.hasMatch(code)) {
      throw const FormatException('OTP code must contain exactly six digits.');
    }
    final operationGeneration = _otpVerificationGeneration;
    final expectedCredentials = await _tokenStore.readSnapshot();
    final response = await _remoteApi.verifyOtpChallenge(
      challengeId: challengeId,
      body: OtpVerificationInput(
        code: code,
        device: DeviceInput(
          installationId: await _installationIds.loadOrCreate(),
          platform: _platform,
          appVersion: _appVersion,
        ),
      ),
    );
    if (operationGeneration != _otpVerificationGeneration) {
      throw const StaleAuthenticationOperationException();
    }
    final tokens = AuthTokens.fromResponse(response.tokens, now: _clock());
    final session = _sessionFromUser(response.user, tokens);
    final committed = await _tokenStore.replaceSessionIfCurrent(
      tokens,
      CachedAuthIdentity.fromSession(session),
      expected: expectedCredentials,
      isOperationCurrent: () =>
          operationGeneration == _otpVerificationGeneration,
    );
    if (!committed) {
      throw const StaleAuthenticationOperationException();
    }
    return session;
  }

  @override
  Future<AuthSession?> restoreSession() {
    final running = _restoreInFlight;
    if (running != null) {
      return running;
    }

    final started = Future<AuthSession?>.sync(_restoreSessionOnce);
    _restoreInFlight = started;
    return started.whenComplete(() {
      if (identical(_restoreInFlight, started)) {
        _restoreInFlight = null;
      }
    });
  }

  @override
  Future<AuthSession?> refreshSession() {
    final running = _refreshInFlight;
    if (running != null) {
      return running;
    }

    final started = Future<AuthSession?>.sync(_refreshSessionOnce);
    _refreshInFlight = started;
    return started.whenComplete(() {
      if (identical(_refreshInFlight, started)) {
        _refreshInFlight = null;
      }
    });
  }

  @override
  Future<void> logout() async {
    final expected = await _tokenStore.readSnapshot();
    var remoteFailed = false;
    try {
      await _remoteApi.deleteCurrentSession(
        expectedCredentialEpoch: expected.epoch,
      );
    } on DioException catch (error) {
      if (error.response?.statusCode != 401) {
        remoteFailed = true;
      }
    } catch (_) {
      remoteFailed = true;
    }

    try {
      final cleared = await _tokenStore.clearCredentialEpoch(expected.epoch);
      if (!cleared) {
        final latest = await _tokenStore.readSnapshot();
        if (latest.tokens != null) {
          throw const LocalCredentialClearFailure();
        }
      }
    } on LocalCredentialClearFailure {
      rethrow;
    } catch (_) {
      throw const LocalCredentialClearFailure();
    }

    if (remoteFailed) {
      throw const RemoteLogoutFailure();
    }
  }

  Future<AuthSession?> _restoreSessionOnce() async {
    final snapshot = await _tokenStore.readSnapshot();
    final tokens = snapshot.tokens;
    if (tokens == null) {
      return null;
    }
    if (!tokens.accessTokenExpiresAt.isAfter(
      _clock().toUtc().add(accessRefreshLeeway),
    )) {
      return refreshSession();
    }
    return _loadCurrentSession(snapshot);
  }

  Future<AuthSession?> _refreshSessionOnce() async {
    final snapshot = await _tokenStore.readSnapshot();
    if (snapshot.tokens == null) {
      return null;
    }

    final AuthTokens? response;
    try {
      response = await _refreshTokens(snapshot);
    } on DioException catch (error) {
      if (_isOfflineTransport(error)) {
        final cached = await _loadCachedSession(snapshot);
        if (cached != null) {
          return cached;
        }
      }
      rethrow;
    }
    if (response == null) {
      return null;
    }
    final refreshed = await _tokenStore.readSnapshot();
    if (refreshed.epoch != snapshot.epoch || refreshed.tokens == null) {
      return null;
    }
    return _loadCurrentSession(refreshed);
  }

  Future<AuthTokens?> _refreshTokens(AuthCredentialSnapshot snapshot) async {
    final current = snapshot.tokens!;
    if (!current.refreshTokenExpiresAt.isAfter(_clock())) {
      await _tokenStore.clearIfCurrent(snapshot);
      return null;
    }
    try {
      final response = await _remoteApi.refreshAuthToken(
        body: RefreshTokenInput(
          refreshToken: current.refreshToken,
          deviceInstallationId: await _installationIds.loadOrCreate(),
        ),
      );
      final rotated = AuthTokens.fromResponse(response, now: _clock());
      return _tokenStore.writeRefreshedIfCurrent(rotated, expected: snapshot);
    } on DioException catch (error) {
      if (_isCredentialRejection(error.response?.statusCode)) {
        await _tokenStore.clearIfCurrent(snapshot);
        return null;
      }
      rethrow;
    } on Object {
      await _tokenStore.clearIfCurrent(snapshot);
      rethrow;
    }
  }

  Future<AuthSession?> _loadCurrentSession(
    AuthCredentialSnapshot expected,
  ) async {
    late final UserResponse user;
    try {
      user = await _remoteApi.getCurrentUser();
    } on DioException catch (error) {
      if (_isCredentialRejection(error.response?.statusCode)) {
        await _tokenStore.clearIfCurrent(expected);
        return null;
      }
      if (_isOfflineTransport(error)) {
        final cached = await _loadCachedSession(expected);
        if (cached != null) {
          return cached;
        }
      }
      rethrow;
    } on Object {
      await _tokenStore.clearIfCurrent(expected);
      rethrow;
    }

    final latest = await _tokenStore.readSnapshot();
    if (latest.epoch != expected.epoch || latest.tokens == null) {
      return null;
    }
    try {
      final session = _sessionFromUser(user, latest.tokens!);
      final cachedSnapshot = await _tokenStore.cacheIdentityForCredentialEpoch(
        CachedAuthIdentity.fromSession(session),
        expectedEpoch: expected.epoch,
      );
      if (cachedSnapshot?.tokens == null) {
        return null;
      }
      return AuthSession(
        userId: session.userId,
        nickname: session.nickname,
        userVersion: session.userVersion,
        tokens: cachedSnapshot!.tokens!,
      );
    } on FormatException {
      await _tokenStore.clearIfCurrent(latest);
      rethrow;
    }
  }

  Future<AuthSession?> _loadCachedSession(
    AuthCredentialSnapshot expected,
  ) async {
    final tokens = expected.tokens;
    if (tokens == null) {
      return null;
    }
    final identity = await _tokenStore.readCachedIdentity(expected);
    if (identity == null) {
      return null;
    }
    return AuthSession(
      userId: identity.userId,
      nickname: identity.nickname,
      userVersion: identity.userVersion,
      tokens: tokens,
    );
  }

  static bool _isOfflineTransport(DioException error) =>
      error.response == null &&
      (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError);

  static bool _isCredentialRejection(int? statusCode) =>
      statusCode == 401 || statusCode == 403 || statusCode == 422;

  static AuthSession _sessionFromUser(UserResponse user, AuthTokens tokens) {
    _requireCanonicalUuid(user.id, fieldName: 'userId');
    final nickname = user.nickname;
    if (user.status != 'active' ||
        user.version < 1 ||
        (nickname != null &&
            (nickname.isEmpty ||
                nickname.length > 40 ||
                nickname.trim() != nickname))) {
      throw const FormatException('Authenticated user response is invalid.');
    }
    return AuthSession(
      userId: user.id,
      nickname: nickname,
      userVersion: user.version,
      tokens: tokens,
    );
  }

  static String _validateAppVersion(String value) {
    if (value.isEmpty || value.length > 32 || value.trim() != value) {
      throw ArgumentError.value(
        value,
        'appVersion',
        'Must contain 1 to 32 characters.',
      );
    }
    return value;
  }

  static void _requireCanonicalUuid(String value, {required String fieldName}) {
    if (value != value.toLowerCase() ||
        !_canonicalUuid.hasMatch(value) ||
        !Uuid.isValidUUID(fromString: value)) {
      throw FormatException('$fieldName must be a canonical UUID.');
    }
  }
}

final class StaleAuthenticationOperationException implements Exception {
  const StaleAuthenticationOperationException();

  @override
  String toString() => 'The authentication operation is no longer current.';
}

final class RemoteLogoutFailure implements Exception {
  const RemoteLogoutFailure();

  @override
  String toString() => 'The remote session could not be revoked.';
}

final class LocalCredentialClearFailure implements Exception {
  const LocalCredentialClearFailure();

  @override
  String toString() => 'Local authentication credentials could not be cleared.';
}
