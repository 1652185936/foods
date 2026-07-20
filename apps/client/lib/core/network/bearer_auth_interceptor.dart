import 'dart:async';

import 'package:dio/dio.dart';

import 'auth_tokens.dart';

/// Adds bearer credentials and retries one 401 after a single-flight refresh.
final class BearerAuthInterceptor extends Interceptor {
  factory BearerAuthInterceptor({
    required Dio authenticatedDio,
    required AuthCredentialStore tokenStore,
    required AccessTokenRefresher tokenRefresher,
    DateTime Function()? clock,
    Duration refreshLeeway = const Duration(seconds: 30),
  }) => BearerAuthInterceptor._(
    authenticatedDio,
    tokenStore,
    tokenRefresher,
    clock ?? DateTime.now,
    refreshLeeway,
  );

  BearerAuthInterceptor._(
    this._authenticatedDio,
    this._tokenStore,
    this._tokenRefresher,
    this._clock,
    this.refreshLeeway,
  );

  static const _retryExtraKey = 'ordin.auth.refresh-retry';
  static const _credentialEpochExtraKey = 'ordin.auth.credential-epoch';
  static const _managedAuthorizationExtraKey =
      'ordin.auth.managed-authorization';

  final Dio _authenticatedDio;
  final AuthCredentialStore _tokenStore;
  final AccessTokenRefresher _tokenRefresher;
  final DateTime Function() _clock;
  final Duration refreshLeeway;

  Future<AuthTokens?>? _refreshInFlight;
  int? _refreshInFlightEpoch;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final snapshot = await _tokenStore.readSnapshot();
      final requiredEpoch = options.extra[authRequiredCredentialEpochExtraKey];
      if (requiredEpoch != null &&
          (requiredEpoch is! int || requiredEpoch != snapshot.epoch)) {
        handler.reject(_credentialChanged(options));
        return;
      }
      options.extra[_credentialEpochExtraKey] = snapshot.epoch;
      final existingAuthorization = _authorizationHeader(options.headers);
      options.extra[_managedAuthorizationExtraKey] =
          existingAuthorization == null;
      if (existingAuthorization == null) {
        var tokens = snapshot.tokens;
        if (tokens != null && !_isAccessTokenUsable(tokens)) {
          tokens = await _refreshOnce(snapshot.epoch);
        }
        if (!_tokenStore.isCredentialEpochCurrent(snapshot.epoch)) {
          handler.reject(_credentialChanged(options));
          return;
        }
        if (tokens != null && _isAccessTokenUsable(tokens)) {
          options.headers['Authorization'] = _bearer(tokens.accessToken);
        }
      }
      handler.next(options);
    } catch (error, stackTrace) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          stackTrace: stackTrace,
          type: DioExceptionType.unknown,
        ),
      );
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final request = err.requestOptions;
    if (err.response?.statusCode != 401 ||
        request.extra[_retryExtraKey] == true ||
        request.extra[_managedAuthorizationExtraKey] != true) {
      handler.next(err);
      return;
    }

    final requestEpoch = request.extra[_credentialEpochExtraKey];
    if (requestEpoch is! int ||
        !_tokenStore.isCredentialEpochCurrent(requestEpoch)) {
      handler.next(err);
      return;
    }

    try {
      final failedAuthorization = _authorizationHeader(request.headers);
      final latestSnapshot = await _tokenStore.readSnapshot();
      if (latestSnapshot.epoch != requestEpoch) {
        handler.next(err);
        return;
      }
      final latest = latestSnapshot.tokens;
      final AuthTokens? usableTokens;
      if (latest != null &&
          _isAccessTokenUsable(latest) &&
          _bearer(latest.accessToken) != failedAuthorization) {
        usableTokens = latest;
      } else {
        usableTokens = await _refreshOnce(requestEpoch);
      }
      if (!_tokenStore.isCredentialEpochCurrent(requestEpoch) ||
          usableTokens == null ||
          !_isAccessTokenUsable(usableTokens)) {
        handler.next(err);
        return;
      }

      final response = await _authenticatedDio.fetch<Object?>(
        request.copyWith(
          headers: {
            ...request.headers,
            'Authorization': _bearer(usableTokens.accessToken),
          },
          extra: {...request.extra, _retryExtraKey: true},
        ),
      );
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    } catch (_) {
      handler.next(err);
    }
  }

  bool _isAccessTokenUsable(AuthTokens tokens) =>
      tokens.accessToken.isNotEmpty &&
      tokens.accessTokenExpiresAt.isAfter(_clock().add(refreshLeeway));

  Future<AuthTokens?> _refreshOnce(int expectedEpoch) {
    final running = _refreshInFlight;
    if (running != null && _refreshInFlightEpoch == expectedEpoch) {
      return running;
    }

    final started = Future<AuthTokens?>.sync(
      () => _tokenRefresher.refreshAccessToken(expectedEpoch: expectedEpoch),
    );
    _refreshInFlight = started;
    _refreshInFlightEpoch = expectedEpoch;
    return started.whenComplete(() {
      if (identical(_refreshInFlight, started)) {
        _refreshInFlight = null;
        _refreshInFlightEpoch = null;
      }
    });
  }

  static DioException _credentialChanged(RequestOptions request) =>
      DioException(
        requestOptions: request,
        type: DioExceptionType.cancel,
        error: const AuthCredentialChangedException(),
      );

  static String _bearer(String accessToken) => 'Bearer $accessToken';

  static String? _authorizationHeader(Map<String, Object?> headers) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == 'authorization') {
        return entry.value?.toString();
      }
    }
    return null;
  }
}

final class AuthCredentialChangedException implements Exception {
  const AuthCredentialChangedException();

  @override
  String toString() => 'Authentication credentials changed during the request.';
}
