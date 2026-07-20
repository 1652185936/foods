import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/core/auth/auth_models.dart';
import 'package:foods_client/core/auth/auth_remote_api.dart';
import 'package:foods_client/core/auth/auth_repository.dart';
import 'package:foods_client/core/auth/auth_secure_storage.dart';
import 'package:foods_client/core/auth/device_installation_id_store.dart';
import 'package:foods_client/core/network/auth_tokens.dart';
import 'package:foods_client/core/network/generated/models/auth_session_response.dart';
import 'package:foods_client/core/network/generated/models/client_platform.dart';
import 'package:foods_client/core/network/generated/models/otp_challenge_input.dart';
import 'package:foods_client/core/network/generated/models/otp_challenge_response.dart';
import 'package:foods_client/core/network/generated/models/otp_verification_input.dart';
import 'package:foods_client/core/network/generated/models/refresh_token_input.dart';
import 'package:foods_client/core/network/generated/models/token_pair_response.dart';
import 'package:foods_client/core/network/generated/models/user_response.dart';

const _challengeId = '0190a123-4567-7890-8123-456789abcdef';
const _secondChallengeId = '0190a123-4567-7890-8123-456789abcdea';
const _userId = '0190a123-4567-7891-8123-456789abcdef';
const _deviceId = '550e8400-e29b-41d4-a716-446655440000';
const _operationId = '0190a123-4567-7892-8123-456789abcdef';
const _refreshToken = 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr';

void main() {
  final now = DateTime.utc(2026, 7, 20, 12);

  test(
    'validates challenge inputs and sends installation-scoped data',
    () async {
      final remote = _FakeAuthRemoteApi(now);
      final store = _MemoryTokenStore();
      final repository = _repository(remote, store, now);

      await expectLater(
        repository.requestOtpChallenge('0501234567'),
        throwsFormatException,
      );
      expect(remote.challengeCalls, 0);

      final challenge = await repository.requestOtpChallenge('+971501234567');

      expect(challenge.id, _challengeId);
      expect(challenge.expiresAtUtc, now.add(const Duration(minutes: 5)));
      expect(challenge.resendAfter, const Duration(seconds: 30));
      expect(remote.challengeCalls, 1);
      expect(remote.lastChallengeBody!.phoneNumber, '+971501234567');
      expect(remote.lastChallengeBody!.deviceInstallationId, _deviceId);
      expect(remote.lastIdempotencyKey, _operationId);
    },
  );

  test('validates verification input and persists a domain session', () async {
    final remote = _FakeAuthRemoteApi(now);
    final store = _MemoryTokenStore();
    final repository = _repository(remote, store, now);

    await expectLater(
      repository.verifyOtp(challengeId: 'not-a-uuid', code: '123456'),
      throwsFormatException,
    );
    await expectLater(
      repository.verifyOtp(challengeId: _challengeId, code: '12345x'),
      throwsFormatException,
    );
    expect(remote.verifyCalls, 0);

    final session = await repository.verifyOtp(
      challengeId: _challengeId,
      code: '654321',
    );

    _expectSession(session, accessToken: 'access-1');
    expect(store.value, same(session.tokens));
    expect(store.cachedIdentity?.userId, _userId);
    expect(store.cachedIdentity?.nickname, 'Alex');
    expect(store.cachedIdentity?.userVersion, 3);
    expect(remote.lastVerificationBody!.code, '654321');
    expect(remote.lastVerificationBody!.device.installationId, _deviceId);
    expect(
      remote.lastVerificationBody!.device.platform,
      ClientPlatform.android,
    );
    expect(remote.lastVerificationBody!.device.appVersion, '1.0.0+1');
  });

  test('a late OTP verification cannot overwrite a newer login', () async {
    final firstResponse = Completer<AuthSessionResponse>();
    final secondResponse = Completer<AuthSessionResponse>();
    final remote = _FakeAuthRemoteApi(now)
      ..verifyHandler = (challengeId, _) => switch (challengeId) {
        _challengeId => firstResponse.future,
        _secondChallengeId => secondResponse.future,
        _ => throw StateError('Unexpected challenge.'),
      };
    final store = _MemoryTokenStore();
    final repository = _repository(remote, store, now);

    final first = repository.verifyOtp(
      challengeId: _challengeId,
      code: '111111',
    );
    final firstExpectation = expectLater(
      first,
      throwsA(isA<StaleAuthenticationOperationException>()),
    );
    repository.cancelPendingAuthentication();
    final second = repository.verifyOtp(
      challengeId: _secondChallengeId,
      code: '222222',
    );
    await Future<void>.delayed(Duration.zero);

    secondResponse.complete(
      AuthSessionResponse(
        tokens: _tokenResponse('second-login', now),
        user: _user(now),
      ),
    );
    _expectSession(await second, accessToken: 'second-login');
    firstResponse.complete(
      AuthSessionResponse(
        tokens: _tokenResponse('late-first-login', now),
        user: _user(now),
      ),
    );

    await firstExpectation;
    expect(store.value!.accessToken, 'second-login');
  });

  test('cancelling OTP verification never persists its late tokens', () async {
    final response = Completer<AuthSessionResponse>();
    final remote = _FakeAuthRemoteApi(now)
      ..verifyHandler = (_, _) => response.future;
    final store = _MemoryTokenStore();
    final repository = _repository(remote, store, now);
    final verification = repository.verifyOtp(
      challengeId: _challengeId,
      code: '123456',
    );
    final verificationExpectation = expectLater(
      verification,
      throwsA(isA<StaleAuthenticationOperationException>()),
    );
    await Future<void>.delayed(Duration.zero);

    repository.cancelPendingAuthentication();
    response.complete(
      AuthSessionResponse(
        tokens: _tokenResponse('cancelled-login', now),
        user: _user(now),
      ),
    );

    await verificationExpectation;
    expect(store.value, isNull);
    expect(store.writeCount, 0);
  });

  test('coalesces concurrent session restoration', () async {
    final remote = _FakeAuthRemoteApi(now);
    final store = _MemoryTokenStore(_tokens('access-1', now));
    final userResponse = Completer<UserResponse>();
    remote.userHandler = () => userResponse.future;
    final repository = _repository(remote, store, now);

    final first = repository.restoreSession();
    final second = repository.restoreSession();
    await Future<void>.delayed(Duration.zero);

    expect(remote.userCalls, 1);
    userResponse.complete(_user(now));
    final sessions = await Future.wait([first, second]);
    expect(sessions[0], same(sessions[1]));
    _expectSession(sessions.first!);
    expect(store.cachedIdentity?.userId, _userId);
  });

  test(
    'restores cached identity for an explicit offline transport error',
    () async {
      final remote = _FakeAuthRemoteApi(now)
        ..userHandler = () async => throw _transportError(
          DioExceptionType.connectionError,
          path: '/users/me',
        );
      final original = _tokens('access-1', now);
      final store = _MemoryTokenStore(original, _cachedIdentity());

      final session = await _repository(remote, store, now).restoreSession();

      _expectSession(session!);
      expect(session.tokens, same(original));
      expect(store.clearCount, 0);
    },
  );

  test('offline restore without an identity cache remains retryable', () async {
    final failure = _transportError(
      DioExceptionType.receiveTimeout,
      path: '/users/me',
    );
    final remote = _FakeAuthRemoteApi(now)
      ..userHandler = () async => throw failure;
    final original = _tokens('access-1', now);
    final store = _MemoryTokenStore(original);

    await expectLater(
      _repository(remote, store, now).restoreSession(),
      throwsA(same(failure)),
    );

    expect(store.value, same(original));
    expect(store.clearCount, 0);
  });

  test('HTTP failure never falls back to a cached identity', () async {
    for (final status in [403, 422, 503]) {
      final failure = _dioError(status);
      final remote = _FakeAuthRemoteApi(now)
        ..userHandler = () async => throw failure;
      final store = _MemoryTokenStore(
        _tokens('access-$status', now),
        _cachedIdentity(),
      );
      final repository = _repository(remote, store, now);

      if (status == 503) {
        await expectLater(repository.restoreSession(), throwsA(same(failure)));
        expect(store.value, isNotNull);
        expect(store.cachedIdentity, isNotNull);
      } else {
        expect(await repository.restoreSession(), isNull);
        expect(store.value, isNull);
        expect(store.cachedIdentity, isNull);
      }
    }
  });

  test(
    'current-user protocol failure clears credentials without fallback',
    () async {
      final failure = const FormatException('invalid user payload');
      final remote = _FakeAuthRemoteApi(now)
        ..userHandler = () async => throw failure;
      final store = _MemoryTokenStore(
        _tokens('access-1', now),
        _cachedIdentity(),
      );

      await expectLater(
        _repository(remote, store, now).restoreSession(),
        throwsA(same(failure)),
      );

      expect(store.value, isNull);
      expect(store.cachedIdentity, isNull);
    },
  );

  test('coalesces concurrent refresh and persists only one rotation', () async {
    final remote = _FakeAuthRemoteApi(now);
    final store = _MemoryTokenStore(
      _tokens(
        'expired',
        now,
        accessExpiresAt: now.subtract(const Duration(minutes: 1)),
      ),
    );
    final tokenResponse = Completer<TokenPairResponse>();
    remote.refreshHandler = (_) => tokenResponse.future;
    final repository = _repository(remote, store, now);

    final first = repository.refreshSession();
    final second = repository.refreshSession();
    await Future<void>.delayed(Duration.zero);

    expect(remote.refreshCalls, 1);
    tokenResponse.complete(_tokenResponse('access-2', now));
    final sessions = await Future.wait([first, second]);
    _expectSession(sessions.first!, accessToken: 'access-2');
    expect(sessions.first, same(sessions.last));
    expect(store.writeCount, 1);
    expect(remote.userCalls, 1);
  });

  test('refresh 401 clears the session and returns signed out', () async {
    final remote = _FakeAuthRemoteApi(now)
      ..refreshHandler = (_) async => throw _dioError(401);
    final store = _MemoryTokenStore(_tokens('access-1', now));
    final repository = _repository(remote, store, now);

    expect(await repository.refreshSession(), isNull);
    expect(store.value, isNull);
    expect(store.clearCount, 1);
  });

  test(
    'transient refresh failures preserve the refresh token and rethrow',
    () async {
      for (final failure in [
        _dioError(500),
        DioException(
          requestOptions: RequestOptions(path: '/auth/refresh'),
          type: DioExceptionType.connectionTimeout,
        ),
      ]) {
        final remote = _FakeAuthRemoteApi(now)
          ..refreshHandler = (_) async => throw failure;
        final original = _tokens('access-1', now);
        final store = _MemoryTokenStore(original);
        final repository = _repository(remote, store, now);

        await expectLater(repository.refreshSession(), throwsA(same(failure)));
        expect(store.value, same(original));
        expect(store.clearCount, 0);
      }
    },
  );

  test('restoration 401 and logout 401 both clear local credentials', () async {
    final restoreRemote = _FakeAuthRemoteApi(now)
      ..userHandler = () async => throw _dioError(401);
    final restoreStore = _MemoryTokenStore(_tokens('access-1', now));

    expect(
      await _repository(restoreRemote, restoreStore, now).restoreSession(),
      isNull,
    );
    expect(restoreStore.value, isNull);

    final logoutRemote = _FakeAuthRemoteApi(now)
      ..logoutHandler = () async => throw _dioError(401);
    final logoutStore = _MemoryTokenStore(_tokens('access-1', now));
    await _repository(logoutRemote, logoutStore, now).logout();
    expect(logoutStore.value, isNull);
    expect(logoutStore.clearCount, 1);
  });

  test('remote logout failure is reported only after local clear', () async {
    final remote = _FakeAuthRemoteApi(now)
      ..logoutHandler = () async => throw _dioError(503);
    final store = _MemoryTokenStore(
      _tokens('access-1', now),
      _cachedIdentity(),
    );

    await expectLater(
      _repository(remote, store, now).logout(),
      throwsA(isA<RemoteLogoutFailure>()),
    );

    expect(store.value, isNull);
    expect(store.cachedIdentity, isNull);
    expect(store.clearCount, 1);
  });

  test('local credential clear failure preserves the stored session', () async {
    final remote = _FakeAuthRemoteApi(now);
    final original = _tokens('access-1', now);
    final store = _MemoryTokenStore(original, _cachedIdentity())
      ..clearCredentialEpochError = StateError('secure storage unavailable');

    await expectLater(
      _repository(remote, store, now).logout(),
      throwsA(isA<LocalCredentialClearFailure>()),
    );

    expect(store.value, same(original));
    expect(store.cachedIdentity, isNotNull);
    expect(store.clearCount, 0);
  });

  test('restore refreshes an access token inside the leeway window', () async {
    final remote = _FakeAuthRemoteApi(now);
    final store = _MemoryTokenStore(
      _tokens(
        'expiring',
        now,
        accessExpiresAt: now.add(const Duration(seconds: 10)),
      ),
    );

    final session = await _repository(remote, store, now).restoreSession();

    _expectSession(session!, accessToken: 'access-2');
    expect(remote.refreshCalls, 1);
  });

  test(
    'expired access token restores cached identity when refresh is offline',
    () async {
      final failure = _transportError(
        DioExceptionType.connectionTimeout,
        path: '/auth/refresh',
      );
      final remote = _FakeAuthRemoteApi(now)
        ..refreshHandler = (_) async => throw failure;
      final original = _tokens(
        'expired',
        now,
        accessExpiresAt: now.subtract(const Duration(minutes: 1)),
      );
      final store = _MemoryTokenStore(original, _cachedIdentity());

      final session = await _repository(remote, store, now).restoreSession();

      _expectSession(session!, accessToken: 'expired');
      expect(session.tokens, same(original));
      expect(remote.refreshCalls, 1);
      expect(remote.userCalls, 0);
      expect(store.clearCount, 0);
    },
  );

  test('refresh rejection never falls back to cached identity', () async {
    for (final status in [401, 403, 422]) {
      final remote = _FakeAuthRemoteApi(now)
        ..refreshHandler = (_) async => throw _dioError(status);
      final store = _MemoryTokenStore(
        _tokens(
          'expired-$status',
          now,
          accessExpiresAt: now.subtract(const Duration(minutes: 1)),
        ),
        _cachedIdentity(),
      );

      expect(await _repository(remote, store, now).restoreSession(), isNull);
      expect(store.value, isNull);
      expect(store.cachedIdentity, isNull);
    }
  });

  test('a stale refresh 401 cannot clear a newer token revision', () async {
    final response = Completer<TokenPairResponse>();
    final remote = _FakeAuthRemoteApi(now)
      ..refreshHandler = (_) => response.future;
    final store = _MemoryTokenStore(_tokens('old', now));
    final repository = _repository(remote, store, now);
    final staleRefresh = repository.refreshSession();
    await Future<void>.delayed(Duration.zero);

    final winner = await store.readSnapshot();
    await store.writeRefreshedIfCurrent(
      _tokens('winner', now),
      expected: winner,
    );
    response.completeError(_dioError(401));

    expect(await staleRefresh, isNull);
    expect(store.value!.accessToken, 'winner');
    expect(store.clearCount, 0);
  });

  test('a stale current-user 401 cannot clear a new login', () async {
    final response = Completer<UserResponse>();
    final remote = _FakeAuthRemoteApi(now)..userHandler = () => response.future;
    final store = _MemoryTokenStore(_tokens('old', now));
    final repository = _repository(remote, store, now);
    final staleRestore = repository.restoreSession();
    await Future<void>.delayed(Duration.zero);

    await store.write(_tokens('new-account', now));
    response.completeError(_dioError(401));

    expect(await staleRestore, isNull);
    expect(store.value!.accessToken, 'new-account');
    expect(store.clearCount, 0);
  });

  test('a late logout cannot clear replacement credentials', () async {
    final response = Completer<void>();
    final remote = _FakeAuthRemoteApi(now)
      ..logoutHandler = () => response.future;
    final store = _MemoryTokenStore(_tokens('old-account', now));
    final repository = _repository(remote, store, now);
    final oldLogout = repository.logout();
    await Future<void>.delayed(Duration.zero);

    expect(remote.lastLogoutEpoch, 0);
    await store.write(_tokens('new-account', now));
    response.complete();
    await expectLater(oldLogout, throwsA(isA<LocalCredentialClearFailure>()));

    expect(store.value!.accessToken, 'new-account');
    expect(store.clearCount, 0);
  });
}

AuthRepository _repository(
  _FakeAuthRemoteApi remote,
  _MemoryTokenStore tokenStore,
  DateTime now,
) {
  final storage = _MemoryAuthSecureStorage()
    ..values[DeviceInstallationIdStore.storageKey] = _deviceId;
  return AuthRepository(
    remote,
    tokenStore,
    DeviceInstallationIdStore(storage),
    platform: ClientPlatform.android,
    appVersion: '1.0.0+1',
    clock: () => now,
    generateOperationId: () => _operationId,
  );
}

void _expectSession(AuthSession session, {String accessToken = 'access-1'}) {
  expect(session.userId, _userId);
  expect(session.nickname, 'Alex');
  expect(session.userVersion, 3);
  expect(session.tokens.accessToken, accessToken);
}

CachedAuthIdentity _cachedIdentity() =>
    const CachedAuthIdentity(userId: _userId, nickname: 'Alex', userVersion: 3);

AuthTokens _tokens(
  String accessToken,
  DateTime now, {
  DateTime? accessExpiresAt,
}) => AuthTokens(
  accessToken: accessToken,
  accessTokenExpiresAt: accessExpiresAt ?? now.add(const Duration(hours: 1)),
  refreshToken: _refreshToken,
  refreshTokenExpiresAt: now.add(const Duration(days: 30)),
  tokenType: 'Bearer',
);

TokenPairResponse _tokenResponse(String accessToken, DateTime now) =>
    TokenPairResponse(
      accessToken: accessToken,
      accessTokenExpiresAt: now.add(const Duration(hours: 1)),
      refreshToken: _refreshToken,
      refreshTokenExpiresAt: now.add(const Duration(days: 30)),
      tokenType: 'Bearer',
    );

UserResponse _user(DateTime now) => UserResponse(
  id: _userId,
  nickname: 'Alex',
  status: 'active',
  version: 3,
  createdAt: now.subtract(const Duration(days: 1)),
  updatedAt: now,
);

DioException _dioError(int statusCode) {
  final request = RequestOptions(path: '/auth');
  return DioException(
    requestOptions: request,
    response: Response<void>(requestOptions: request, statusCode: statusCode),
    type: DioExceptionType.badResponse,
  );
}

DioException _transportError(DioExceptionType type, {required String path}) =>
    DioException(
      requestOptions: RequestOptions(path: path),
      type: type,
    );

final class _FakeAuthRemoteApi implements AuthRemoteApi {
  _FakeAuthRemoteApi(DateTime now) {
    challengeHandler = (_, _) async => OtpChallengeResponse(
      challengeId: _challengeId,
      expiresAt: now.add(const Duration(minutes: 5)),
      resendAfterSeconds: 30,
    );
    verifyHandler = (_, _) async => AuthSessionResponse(
      tokens: _tokenResponse('access-1', now),
      user: _user(now),
    );
    refreshHandler = (_) async => _tokenResponse('access-2', now);
    logoutHandler = () async {};
    userHandler = () async => _user(now);
  }

  late Future<OtpChallengeResponse> Function(OtpChallengeInput, String)
  challengeHandler;
  late Future<AuthSessionResponse> Function(String, OtpVerificationInput)
  verifyHandler;
  late Future<TokenPairResponse> Function(RefreshTokenInput) refreshHandler;
  late Future<void> Function() logoutHandler;
  late Future<UserResponse> Function() userHandler;

  int challengeCalls = 0;
  int verifyCalls = 0;
  int refreshCalls = 0;
  int logoutCalls = 0;
  int userCalls = 0;
  OtpChallengeInput? lastChallengeBody;
  String? lastIdempotencyKey;
  OtpVerificationInput? lastVerificationBody;
  int? lastLogoutEpoch;

  @override
  Future<OtpChallengeResponse> createOtpChallenge({
    required OtpChallengeInput body,
    required String idempotencyKey,
  }) {
    challengeCalls++;
    lastChallengeBody = body;
    lastIdempotencyKey = idempotencyKey;
    return challengeHandler(body, idempotencyKey);
  }

  @override
  Future<void> deleteCurrentSession({required int expectedCredentialEpoch}) {
    logoutCalls++;
    lastLogoutEpoch = expectedCredentialEpoch;
    return logoutHandler();
  }

  @override
  Future<UserResponse> getCurrentUser() {
    userCalls++;
    return userHandler();
  }

  @override
  Future<TokenPairResponse> refreshAuthToken({
    required RefreshTokenInput body,
  }) {
    refreshCalls++;
    return refreshHandler(body);
  }

  @override
  Future<AuthSessionResponse> verifyOtpChallenge({
    required String challengeId,
    required OtpVerificationInput body,
  }) {
    verifyCalls++;
    lastVerificationBody = body;
    return verifyHandler(challengeId, body);
  }
}

final class _MemoryTokenStore implements AuthSessionCredentialStore {
  _MemoryTokenStore([this.value, this.cachedIdentity]);

  AuthTokens? value;
  CachedAuthIdentity? cachedIdentity;
  int clearCount = 0;
  int writeCount = 0;
  Object? clearCredentialEpochError;
  int _epoch = 0;
  int _revision = 0;

  @override
  Future<void> clear() async {
    clearCount++;
    _epoch++;
    _revision++;
    value = null;
    cachedIdentity = null;
  }

  @override
  Future<bool> clearIfCurrent(AuthCredentialSnapshot expected) async {
    if (expected.epoch != _epoch || expected.revision != _revision) {
      return false;
    }
    await clear();
    return true;
  }

  @override
  Future<bool> clearCredentialEpoch(int expectedEpoch) async {
    final error = clearCredentialEpochError;
    if (error != null) {
      throw error;
    }
    if (expectedEpoch != _epoch) {
      return false;
    }
    await clear();
    return true;
  }

  @override
  bool isCredentialEpochCurrent(int epoch) => epoch == _epoch;

  @override
  Future<AuthTokens?> read() async => value;

  @override
  Future<AuthCredentialSnapshot> readSnapshot() async =>
      AuthCredentialSnapshot(epoch: _epoch, revision: _revision, tokens: value);

  @override
  Future<CachedAuthIdentity?> readCachedIdentity(
    AuthCredentialSnapshot expected,
  ) async {
    if (expected.epoch != _epoch ||
        expected.revision != _revision ||
        expected.tokens?.refreshToken != value?.refreshToken) {
      return null;
    }
    return cachedIdentity;
  }

  @override
  Future<AuthCredentialSnapshot?> cacheIdentityForCredentialEpoch(
    CachedAuthIdentity identity, {
    required int expectedEpoch,
  }) async {
    if (expectedEpoch != _epoch || value == null) {
      return null;
    }
    cachedIdentity = identity;
    return readSnapshot();
  }

  @override
  Future<void> write(AuthTokens tokens) async {
    writeCount++;
    _epoch++;
    _revision++;
    value = tokens;
    cachedIdentity = null;
  }

  @override
  Future<bool> replaceIfCurrent(
    AuthTokens tokens, {
    required AuthCredentialSnapshot expected,
    bool Function()? isOperationCurrent,
  }) async {
    if (expected.epoch != _epoch ||
        expected.revision != _revision ||
        isOperationCurrent?.call() == false) {
      return false;
    }
    await write(tokens);
    if (isOperationCurrent?.call() == false) {
      await clear();
      return false;
    }
    return true;
  }

  @override
  Future<bool> replaceSessionIfCurrent(
    AuthTokens tokens,
    CachedAuthIdentity identity, {
    required AuthCredentialSnapshot expected,
    bool Function()? isOperationCurrent,
  }) async {
    if (expected.epoch != _epoch ||
        expected.revision != _revision ||
        isOperationCurrent?.call() == false) {
      return false;
    }
    writeCount++;
    _epoch++;
    _revision++;
    value = tokens;
    cachedIdentity = identity;
    if (isOperationCurrent?.call() == false) {
      await clear();
      return false;
    }
    return true;
  }

  @override
  Future<AuthTokens?> writeRefreshedIfCurrent(
    AuthTokens tokens, {
    required AuthCredentialSnapshot expected,
  }) async {
    if (expected.epoch != _epoch) {
      return null;
    }
    if (expected.revision != _revision) {
      return value;
    }
    writeCount++;
    _revision++;
    value = tokens;
    return tokens;
  }
}

final class _MemoryAuthSecureStorage implements AuthSecureStorage {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
