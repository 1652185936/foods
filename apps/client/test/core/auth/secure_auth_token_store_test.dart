import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/core/auth/auth_models.dart';
import 'package:foods_client/core/auth/auth_secure_storage.dart';
import 'package:foods_client/core/auth/secure_auth_token_store.dart';
import 'package:foods_client/core/network/auth_tokens.dart';

const _refreshToken = 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr';
const _userId = '0190a123-4567-7891-8123-456789abcdef';

void main() {
  final now = DateTime.utc(2026, 7, 20, 12);

  test(
    'persists the complete rotation unit under the isolated auth key',
    () async {
      final storage = _MemoryAuthSecureStorage();
      final store = SecureAuthTokenStore(storage, clock: () => now);

      await store.write(_tokens(now));

      expect(storage.values.keys, [SecureAuthTokenStore.storageKey]);
      final encoded = storage.values[SecureAuthTokenStore.storageKey]!;
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      expect(decoded.keys, {
        'schemaVersion',
        'tokenType',
        'accessToken',
        'accessTokenExpiresAt',
        'refreshToken',
        'refreshTokenExpiresAt',
        'cachedIdentity',
      });
      expect(decoded['schemaVersion'], 2);
      expect(decoded['cachedIdentity'], isNull);
      expect((await store.read())!.accessToken, 'access-token');
    },
  );

  test(
    'persists and reads a strictly versioned identity in the token record',
    () async {
      final storage = _MemoryAuthSecureStorage();
      final store = SecureAuthTokenStore(storage, clock: () => now);
      final expected = await store.readSnapshot();

      expect(
        await store.replaceSessionIfCurrent(
          _tokens(now),
          _identity(),
          expected: expected,
        ),
        isTrue,
      );
      final snapshot = await store.readSnapshot();
      final cached = await store.readCachedIdentity(snapshot);
      final decoded =
          jsonDecode(storage.values[SecureAuthTokenStore.storageKey]!)
              as Map<String, dynamic>;
      final encodedIdentity = decoded['cachedIdentity'] as Map<String, dynamic>;

      expect(decoded['schemaVersion'], 2);
      expect(encodedIdentity.keys, {
        'schemaVersion',
        'userId',
        'nickname',
        'userVersion',
      });
      expect(encodedIdentity['schemaVersion'], 1);
      expect(cached?.userId, _userId);
      expect(cached?.nickname, 'Alex');
      expect(cached?.userVersion, 3);
    },
  );

  test('accepts legacy token records without inventing an identity', () async {
    final storage = _MemoryAuthSecureStorage()
      ..values[SecureAuthTokenStore.storageKey] = _encodedTokens(now);
    final store = SecureAuthTokenStore(storage, clock: () => now);

    final snapshot = await store.readSnapshot();

    expect(snapshot.tokens, isNotNull);
    expect(await store.readCachedIdentity(snapshot), isNull);
    expect(storage.deleteCount, 0);
  });

  test(
    'allows an expired access token while its refresh token remains valid',
    () async {
      final storage = _MemoryAuthSecureStorage();
      storage.values[SecureAuthTokenStore.storageKey] = _encodedTokens(
        now,
        accessExpiresAt: now.subtract(const Duration(minutes: 1)),
      );

      final restored = await SecureAuthTokenStore(
        storage,
        clock: () => now,
      ).read();

      expect(restored, isNotNull);
      expect(restored!.accessTokenExpiresAt.isAfter(now), isFalse);
      expect(storage.deleteCount, 0);
    },
  );

  test(
    'fails closed and deletes malformed or expired persisted data',
    () async {
      final invalidValues = <String>[
        'not-json',
        jsonEncode({..._tokenJson(now), 'unexpected': true}),
        jsonEncode({..._tokenJson(now), 'schemaVersion': 1.0}),
        jsonEncode({..._tokenJson(now), 'schemaVersion': 2}),
        jsonEncode({..._tokenJson(now), 'tokenType': 'Basic'}),
        jsonEncode({..._tokenJson(now), 'accessToken': 'secret with space'}),
        jsonEncode({
          ..._tokenJson(now),
          'accessTokenExpiresAt': '2026-07-20T13:00:00+00:00',
        }),
        _encodedTokens(
          now,
          accessExpiresAt: now.subtract(const Duration(days: 2)),
          refreshExpiresAt: now.subtract(const Duration(days: 1)),
        ),
      ];

      for (final encoded in invalidValues) {
        final storage = _MemoryAuthSecureStorage()
          ..values[SecureAuthTokenStore.storageKey] = encoded;
        final store = SecureAuthTokenStore(storage, clock: () => now);

        expect(await store.read(), isNull);
        expect(storage.values, isEmpty);
        expect(storage.deleteCount, 1);
      }
    },
  );

  test(
    'fails closed on malformed or unversioned cached identity data',
    () async {
      final invalidIdentities = <Object?>[
        {..._identityJson(), 'unexpected': true},
        {..._identityJson(), 'schemaVersion': 2},
        {..._identityJson(), 'userId': 'not-a-uuid'},
        {..._identityJson(), 'nickname': ' Alex '},
        {..._identityJson(), 'userVersion': 0},
        'not-an-object',
      ];

      for (final identity in invalidIdentities) {
        final storage = _MemoryAuthSecureStorage()
          ..values[SecureAuthTokenStore.storageKey] = jsonEncode({
            ..._tokenJson(now),
            'schemaVersion': 2,
            'cachedIdentity': identity,
          });
        final store = SecureAuthTokenStore(storage, clock: () => now);

        expect((await store.readSnapshot()).tokens, isNull);
        expect(storage.values, isEmpty);
        expect(storage.deleteCount, 1);
      }
    },
  );

  test('rejects invalid writes without exposing token values', () async {
    final storage = _MemoryAuthSecureStorage();
    final store = SecureAuthTokenStore(storage, clock: () => now);
    final invalid = AuthTokens(
      accessToken: 'do-not-leak',
      accessTokenExpiresAt: now.subtract(const Duration(seconds: 1)),
      refreshToken: _refreshToken,
      refreshTokenExpiresAt: now.add(const Duration(days: 1)),
      tokenType: 'Bearer',
    );

    Object? error;
    try {
      await store.write(invalid);
    } catch (caught) {
      error = caught;
    }

    expect(error, isA<FormatException>());
    expect(error.toString(), isNot(contains('do-not-leak')));
    expect(storage.values, isEmpty);
  });

  test('clear deletes rather than writing an empty sentinel', () async {
    final storage = _MemoryAuthSecureStorage()
      ..values[SecureAuthTokenStore.storageKey] = 'value';
    final store = SecureAuthTokenStore(storage, clock: () => now);
    var clearEvents = 0;
    final subscription = store.cleared.listen((_) => clearEvents++);

    await store.clear();

    expect(storage.values, isEmpty);
    expect(storage.deleteCount, 1);
    expect(storage.writeCount, 0);
    expect(clearEvents, 1);
    await subscription.cancel();
    await store.dispose();
  });

  test(
    'a failed secure delete keeps the credential record and emits no clear',
    () async {
      final storage = _MemoryAuthSecureStorage();
      final store = SecureAuthTokenStore(storage, clock: () => now);
      final expected = await store.readSnapshot();
      await store.replaceSessionIfCurrent(
        _tokens(now),
        _identity(),
        expected: expected,
      );
      var clearEvents = 0;
      final subscription = store.cleared.listen((_) => clearEvents++);
      storage.deleteError = StateError('secure storage unavailable');

      await expectLater(store.clear(), throwsStateError);

      expect(storage.values, isNotEmpty);
      expect(clearEvents, 0);
      storage.deleteError = null;
      await store.clear();
      expect(storage.values, isEmpty);
      expect(clearEvents, 1);
      await subscription.cancel();
      await store.dispose();
    },
  );

  test('a stale refresh cannot overwrite replacement credentials', () async {
    final storage = _MemoryAuthSecureStorage();
    final store = SecureAuthTokenStore(storage, clock: () => now);
    await store.write(_tokens(now, accessToken: 'old-access'));
    final stale = await store.readSnapshot();

    await store.clear();
    await store.write(
      _tokens(
        now,
        accessToken: 'new-account-access',
        refreshToken: 'nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn',
      ),
    );
    final result = await store.writeRefreshedIfCurrent(
      _tokens(
        now,
        accessToken: 'late-old-access',
        refreshToken: 'oooooooooooooooooooooooooooooooooooooooo',
      ),
      expected: stale,
    );

    expect(result, isNull);
    expect((await store.read())!.accessToken, 'new-account-access');
  });

  test('a stale failure cannot clear a winning refresh revision', () async {
    final storage = _MemoryAuthSecureStorage();
    final store = SecureAuthTokenStore(storage, clock: () => now);
    await store.write(_tokens(now, accessToken: 'old-access'));
    final stale = await store.readSnapshot();

    final committed = await store.writeRefreshedIfCurrent(
      _tokens(
        now,
        accessToken: 'winner-access',
        refreshToken: 'wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww',
      ),
      expected: stale,
    );
    final cleared = await store.clearIfCurrent(stale);

    expect(committed!.accessToken, 'winner-access');
    expect(cleared, isFalse);
    expect((await store.read())!.accessToken, 'winner-access');
  });

  test('refresh rotation preserves the cached identity', () async {
    final storage = _MemoryAuthSecureStorage();
    final store = SecureAuthTokenStore(storage, clock: () => now);
    final empty = await store.readSnapshot();
    await store.replaceSessionIfCurrent(
      _tokens(now),
      _identity(),
      expected: empty,
    );
    final beforeRefresh = await store.readSnapshot();

    await store.writeRefreshedIfCurrent(
      _tokens(
        now,
        accessToken: 'refreshed-access',
        refreshToken: 'wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww',
      ),
      expected: beforeRefresh,
    );
    final afterRefresh = await store.readSnapshot();

    expect((await store.readCachedIdentity(afterRefresh))?.userId, _userId);
  });

  test('login replacement and logout clearing are epoch guarded', () async {
    final storage = _MemoryAuthSecureStorage();
    final store = SecureAuthTokenStore(storage, clock: () => now);
    final firstLogin = await store.readSnapshot();
    final secondLogin = await store.readSnapshot();

    expect(
      await store.replaceIfCurrent(
        _tokens(now, accessToken: 'second-login'),
        expected: secondLogin,
      ),
      isTrue,
    );
    expect(
      await store.replaceIfCurrent(
        _tokens(now, accessToken: 'late-first-login'),
        expected: firstLogin,
      ),
      isFalse,
    );
    expect(await store.clearCredentialEpoch(firstLogin.epoch), isFalse);
    expect((await store.read())!.accessToken, 'second-login');
  });

  test('uses an auth namespace independent from database secure storage', () {
    expect(FlutterAuthSecureStorage.storageNamespace, 'foods_auth');
    expect(SecureAuthTokenStore.storageKey, startsWith('foods.auth.'));
  });
}

AuthTokens _tokens(
  DateTime now, {
  String accessToken = 'access-token',
  String refreshToken = _refreshToken,
}) => AuthTokens(
  accessToken: accessToken,
  accessTokenExpiresAt: now.add(const Duration(hours: 1)),
  refreshToken: refreshToken,
  refreshTokenExpiresAt: now.add(const Duration(days: 30)),
  tokenType: 'Bearer',
);

CachedAuthIdentity _identity() =>
    const CachedAuthIdentity(userId: _userId, nickname: 'Alex', userVersion: 3);

String _encodedTokens(
  DateTime now, {
  DateTime? accessExpiresAt,
  DateTime? refreshExpiresAt,
}) => jsonEncode(
  _tokenJson(
    now,
    accessExpiresAt: accessExpiresAt,
    refreshExpiresAt: refreshExpiresAt,
  ),
);

Map<String, Object> _tokenJson(
  DateTime now, {
  DateTime? accessExpiresAt,
  DateTime? refreshExpiresAt,
}) => {
  'schemaVersion': 1,
  'tokenType': 'Bearer',
  'accessToken': 'access-token',
  'accessTokenExpiresAt': (accessExpiresAt ?? now.add(const Duration(hours: 1)))
      .toUtc()
      .toIso8601String(),
  'refreshToken': _refreshToken,
  'refreshTokenExpiresAt':
      (refreshExpiresAt ?? now.add(const Duration(days: 30)))
          .toUtc()
          .toIso8601String(),
};

Map<String, Object?> _identityJson() => const {
  'schemaVersion': 1,
  'userId': _userId,
  'nickname': 'Alex',
  'userVersion': 3,
};

final class _MemoryAuthSecureStorage implements AuthSecureStorage {
  final Map<String, String> values = {};
  int deleteCount = 0;
  int writeCount = 0;
  Object? deleteError;

  @override
  Future<void> delete(String key) async {
    deleteCount++;
    final error = deleteError;
    if (error != null) {
      throw error;
    }
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    writeCount++;
    values[key] = value;
  }
}
