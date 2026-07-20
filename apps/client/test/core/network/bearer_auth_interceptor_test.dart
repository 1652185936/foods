import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/core/network/auth_tokens.dart';
import 'package:foods_client/core/network/bearer_auth_interceptor.dart';

void main() {
  final now = DateTime.utc(2026, 7, 20, 12);

  test('injects the stored access token', () async {
    final store = _MemoryTokenStore(_tokens('current', now));
    final adapter = _RecordingAdapter((_) => ResponseBody.fromString('', 204));
    final dio = _authenticatedDio(
      adapter: adapter,
      store: store,
      refresher: _FakeRefresher(store, _tokens('unused', now)),
      now: now,
    );

    await dio.get<void>('/profile');

    expect(_authorization(adapter.requests.single), 'Bearer current');
  });

  test(
    'refreshes concurrent 401 responses once and retries each request',
    () async {
      final store = _MemoryTokenStore(_tokens('old', now));
      final refresher = _FakeRefresher(store, _tokens('new', now));
      final adapter = _RecordingAdapter((request) async {
        if (_authorization(request) == 'Bearer old') {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          return _jsonResponse(401, {'error': 'expired'});
        }
        return _jsonResponse(200, {'ok': true});
      });
      final dio = _authenticatedDio(
        adapter: adapter,
        store: store,
        refresher: refresher,
        now: now,
      );

      final responses = await Future.wait([
        dio.get<Map<String, Object?>>('/one'),
        dio.get<Map<String, Object?>>('/two'),
      ]);

      expect(
        responses.map((response) => response.data!['ok']),
        everyElement(true),
      );
      expect(refresher.calls, 1);
      expect(
        adapter.requests.where(
          (request) => _authorization(request) == 'Bearer new',
        ),
        hasLength(2),
      );
    },
  );

  test('retries a rejected request at most once', () async {
    final store = _MemoryTokenStore(_tokens('old', now));
    final refresher = _FakeRefresher(store, _tokens('new', now));
    final adapter = _RecordingAdapter(
      (_) => _jsonResponse(401, {'error': 'still rejected'}),
    );
    final dio = _authenticatedDio(
      adapter: adapter,
      store: store,
      refresher: refresher,
      now: now,
    );

    await expectLater(
      dio.get<void>('/protected'),
      throwsA(isA<DioException>()),
    );

    expect(refresher.calls, 1);
    expect(adapter.requests, hasLength(2));
  });

  test('refreshes an expiring access token before sending', () async {
    final expiring = _tokens(
      'expiring',
      now,
      accessExpiresAt: now.add(const Duration(seconds: 10)),
    );
    final store = _MemoryTokenStore(expiring);
    final refresher = _FakeRefresher(store, _tokens('fresh', now));
    final adapter = _RecordingAdapter((_) => ResponseBody.fromString('', 204));
    final dio = _authenticatedDio(
      adapter: adapter,
      store: store,
      refresher: refresher,
      now: now,
    );

    await dio.get<void>('/profile');

    expect(refresher.calls, 1);
    expect(_authorization(adapter.requests.single), 'Bearer fresh');
  });

  test('never replays an old-account 401 with new-account tokens', () async {
    final oldResponse = Completer<void>();
    final store = _MemoryTokenStore(_tokens('old-account', now));
    final adapter = _RecordingAdapter((request) async {
      if (_authorization(request) == 'Bearer old-account') {
        await oldResponse.future;
        return _jsonResponse(401, {'error': 'expired'});
      }
      return _jsonResponse(200, {'ok': true});
    });
    final dio = _authenticatedDio(
      adapter: adapter,
      store: store,
      refresher: _FakeRefresher(store, _tokens('unused', now)),
      now: now,
    );

    final oldRequest = dio.post<Map<String, Object?>>(
      '/sync',
      data: {'ownerPayload': 'old-account-data'},
    );
    while (adapter.requests.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    await store.clear();
    await store.write(_tokens('new-account', now));
    oldResponse.complete();

    await expectLater(oldRequest, throwsA(isA<DioException>()));
    expect(adapter.requests, hasLength(1));
    expect(
      adapter.requests.where(
        (request) => _authorization(request) == 'Bearer new-account',
      ),
      isEmpty,
    );
  });

  test('a late old-account refresh cannot overwrite a new login', () async {
    final store = _MemoryTokenStore(
      _tokens(
        'expiring-old',
        now,
        accessExpiresAt: now.add(const Duration(seconds: 5)),
      ),
    );
    final refresher = _ControlledRefresher(store, _tokens('rotated-old', now));
    final adapter = _RecordingAdapter((_) => _jsonResponse(200, {'ok': true}));
    final dio = _authenticatedDio(
      adapter: adapter,
      store: store,
      refresher: refresher,
      now: now,
    );

    final oldRequest = dio.get<Map<String, Object?>>('/profile');
    await refresher.started.future;
    await store.clear();
    await store.write(_tokens('new-account', now));
    refresher.release.complete();

    await expectLater(
      oldRequest,
      throwsA(
        isA<DioException>().having(
          (error) => error.type,
          'type',
          DioExceptionType.cancel,
        ),
      ),
    );
    expect(store.value!.accessToken, 'new-account');
    expect(adapter.requests, isEmpty);
  });

  test(
    'an epoch-bound logout cannot be sent with replacement tokens',
    () async {
      final store = _MemoryTokenStore(_tokens('old-account', now));
      final old = await store.readSnapshot();
      await store.write(_tokens('new-account', now));
      final adapter = _RecordingAdapter(
        (_) => ResponseBody.fromString('', 204),
      );
      final dio = _authenticatedDio(
        adapter: adapter,
        store: store,
        refresher: _FakeRefresher(store, _tokens('unused', now)),
        now: now,
      );

      await expectLater(
        dio.delete<void>(
          '/api/v1/auth/sessions/current',
          options: Options(
            extra: {authRequiredCredentialEpochExtraKey: old.epoch},
          ),
        ),
        throwsA(
          isA<DioException>().having(
            (error) => error.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );

      expect(adapter.requests, isEmpty);
      expect(store.value!.accessToken, 'new-account');
    },
  );
}

Dio _authenticatedDio({
  required HttpClientAdapter adapter,
  required AuthCredentialStore store,
  required AccessTokenRefresher refresher,
  required DateTime now,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
  dio.httpClientAdapter = adapter;
  dio.interceptors.add(
    BearerAuthInterceptor(
      authenticatedDio: dio,
      tokenStore: store,
      tokenRefresher: refresher,
      clock: () => now,
    ),
  );
  return dio;
}

AuthTokens _tokens(
  String accessToken,
  DateTime now, {
  DateTime? accessExpiresAt,
}) => AuthTokens(
  accessToken: accessToken,
  accessTokenExpiresAt: accessExpiresAt ?? now.add(const Duration(hours: 1)),
  refreshToken: 'refresh-$accessToken',
  refreshTokenExpiresAt: now.add(const Duration(days: 30)),
  tokenType: 'Bearer',
);

String? _authorization(RequestOptions request) {
  for (final entry in request.headers.entries) {
    if (entry.key.toLowerCase() == 'authorization') {
      return entry.value?.toString();
    }
  }
  return null;
}

ResponseBody _jsonResponse(int statusCode, Map<String, Object?> body) =>
    ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

final class _MemoryTokenStore implements AuthCredentialStore {
  _MemoryTokenStore(this.value);

  AuthTokens? value;
  int _epoch = 0;
  int _revision = 0;

  @override
  Future<void> clear() async {
    _epoch++;
    _revision++;
    value = null;
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
  Future<void> write(AuthTokens tokens) async {
    _epoch++;
    _revision++;
    value = tokens;
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
    _revision++;
    value = tokens;
    return tokens;
  }
}

final class _FakeRefresher implements AccessTokenRefresher {
  _FakeRefresher(this.store, this.result);

  final AuthCredentialStore store;
  final AuthTokens? result;
  int calls = 0;

  @override
  Future<AuthTokens?> refreshAccessToken({required int expectedEpoch}) async {
    calls++;
    final snapshot = await store.readSnapshot();
    if (snapshot.epoch != expectedEpoch) {
      return null;
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final value = result;
    if (value != null) {
      return store.writeRefreshedIfCurrent(value, expected: snapshot);
    }
    return value;
  }
}

final class _ControlledRefresher implements AccessTokenRefresher {
  _ControlledRefresher(this.store, this.result);

  final AuthCredentialStore store;
  final AuthTokens result;
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<AuthTokens?> refreshAccessToken({required int expectedEpoch}) async {
    final snapshot = await store.readSnapshot();
    if (!started.isCompleted) {
      started.complete();
    }
    await release.future;
    if (snapshot.epoch != expectedEpoch) {
      return null;
    }
    return store.writeRefreshedIfCurrent(result, expected: snapshot);
  }
}

final class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.handler);

  final FutureOr<ResponseBody> Function(RequestOptions request) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}
