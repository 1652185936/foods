import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../network/auth_tokens.dart';
import 'auth_models.dart';
import 'auth_secure_storage.dart';

final class SecureAuthTokenStore implements AuthSessionCredentialStore {
  SecureAuthTokenStore(this._storage, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const storageKey = 'foods.auth.tokens.v1';
  static const _legacySchemaVersion = 1;
  static const _schemaVersion = 2;
  static const _identitySchemaVersion = 1;
  static const _legacyFieldNames = <String>{
    'schemaVersion',
    'tokenType',
    'accessToken',
    'accessTokenExpiresAt',
    'refreshToken',
    'refreshTokenExpiresAt',
  };
  static const _fieldNames = <String>{..._legacyFieldNames, 'cachedIdentity'};
  static const _identityFieldNames = <String>{
    'schemaVersion',
    'userId',
    'nickname',
    'userVersion',
  };
  static final _canonicalUuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );

  final AuthSecureStorage _storage;
  final DateTime Function() _clock;
  final _mutex = _AsyncMutex();
  final StreamController<void> _cleared = StreamController<void>.broadcast(
    sync: true,
  );
  var _epoch = 0;
  var _revision = 0;

  Stream<void> get cleared => _cleared.stream;

  @override
  Future<AuthTokens?> read() async => (await readSnapshot()).tokens;

  @override
  Future<AuthCredentialSnapshot> readSnapshot() => _mutex.run(() async {
    final record = await _readRecordLocked();
    return _snapshot(record?.tokens);
  });

  @override
  Future<CachedAuthIdentity?> readCachedIdentity(
    AuthCredentialSnapshot expected,
  ) => _mutex.run(() async {
    if (!_isCurrent(expected) || expected.tokens == null) {
      return null;
    }
    final record = await _readRecordLocked();
    if (!_isCurrent(expected) ||
        record == null ||
        record.tokens.refreshToken != expected.tokens!.refreshToken) {
      return null;
    }
    return record.identity;
  });

  @override
  Future<AuthCredentialSnapshot?> cacheIdentityForCredentialEpoch(
    CachedAuthIdentity identity, {
    required int expectedEpoch,
  }) async {
    _validateIdentity(identity);
    return _mutex.run(() async {
      if (expectedEpoch != _epoch) {
        return null;
      }
      final record = await _readRecordLocked();
      if (expectedEpoch != _epoch || record == null) {
        return null;
      }
      await _writeLocked(record.tokens, identity: identity);
      return _snapshot(record.tokens);
    });
  }

  @override
  bool isCredentialEpochCurrent(int epoch) => epoch == _epoch;

  @override
  Future<bool> replaceIfCurrent(
    AuthTokens tokens, {
    required AuthCredentialSnapshot expected,
    bool Function()? isOperationCurrent,
  }) async {
    _validateTokens(tokens, now: _clock(), requireCurrentAccessToken: true);
    return _mutex.run(() async {
      if (!_isCurrent(expected) || isOperationCurrent?.call() == false) {
        return false;
      }
      _epoch++;
      _revision++;
      await _writeLocked(tokens, identity: null);
      if (isOperationCurrent?.call() == false) {
        _epoch++;
        _revision++;
        await _deleteLocked();
        return false;
      }
      return true;
    });
  }

  @override
  Future<bool> replaceSessionIfCurrent(
    AuthTokens tokens,
    CachedAuthIdentity identity, {
    required AuthCredentialSnapshot expected,
    bool Function()? isOperationCurrent,
  }) async {
    _validateTokens(tokens, now: _clock(), requireCurrentAccessToken: true);
    _validateIdentity(identity);
    return _mutex.run(() async {
      if (!_isCurrent(expected) || isOperationCurrent?.call() == false) {
        return false;
      }
      _epoch++;
      _revision++;
      await _writeLocked(tokens, identity: identity);
      if (isOperationCurrent?.call() == false) {
        _epoch++;
        _revision++;
        await _deleteLocked();
        return false;
      }
      return true;
    });
  }

  @override
  Future<void> write(AuthTokens tokens) async {
    _validateTokens(tokens, now: _clock(), requireCurrentAccessToken: true);
    await _mutex.run(() async {
      _epoch++;
      _revision++;
      await _writeLocked(tokens, identity: null);
    });
  }

  @override
  Future<void> clear() => _mutex.run(() async {
    _epoch++;
    _revision++;
    await _deleteLocked();
  });

  @override
  Future<AuthTokens?> writeRefreshedIfCurrent(
    AuthTokens tokens, {
    required AuthCredentialSnapshot expected,
  }) async {
    _validateTokens(tokens, now: _clock(), requireCurrentAccessToken: true);
    return _mutex.run(() async {
      if (!_isCurrent(expected)) {
        return expected.epoch == _epoch ? await _readLocked() : null;
      }
      final current = await _readRecordLocked();
      if (!_isCurrent(expected) || current == null) {
        return null;
      }
      if (current.tokens.refreshToken != expected.tokens?.refreshToken) {
        return current.tokens;
      }
      _revision++;
      await _writeLocked(tokens, identity: current.identity);
      return tokens;
    });
  }

  @override
  Future<bool> clearIfCurrent(AuthCredentialSnapshot expected) {
    return _mutex.run(() async {
      if (!_isCurrent(expected)) {
        return false;
      }
      final current = await _readRecordLocked();
      if (!_isCurrent(expected) ||
          current?.tokens.refreshToken != expected.tokens?.refreshToken) {
        return false;
      }
      _epoch++;
      _revision++;
      await _deleteLocked();
      return true;
    });
  }

  @override
  Future<bool> clearCredentialEpoch(int expectedEpoch) {
    return _mutex.run(() async {
      if (expectedEpoch != _epoch) {
        return false;
      }
      _epoch++;
      _revision++;
      await _deleteLocked();
      return true;
    });
  }

  Future<void> dispose() => _cleared.close();

  AuthCredentialSnapshot _snapshot(AuthTokens? tokens) =>
      AuthCredentialSnapshot(
        epoch: _epoch,
        revision: _revision,
        tokens: tokens,
      );

  bool _isCurrent(AuthCredentialSnapshot snapshot) =>
      snapshot.epoch == _epoch && snapshot.revision == _revision;

  Future<AuthTokens?> _readLocked() async =>
      (await _readRecordLocked())?.tokens;

  Future<_StoredAuthRecord?> _readRecordLocked() async {
    final encoded = await _storage.read(storageKey);
    if (encoded == null) {
      return null;
    }
    try {
      return _decode(encoded, now: _clock());
    } on FormatException {
      _epoch++;
      _revision++;
      await _deleteLocked();
      return null;
    }
  }

  Future<void> _writeLocked(
    AuthTokens tokens, {
    required CachedAuthIdentity? identity,
  }) {
    final encoded = jsonEncode({
      'schemaVersion': _schemaVersion,
      'tokenType': tokens.tokenType,
      'accessToken': tokens.accessToken,
      'accessTokenExpiresAt': _encodeUtc(tokens.accessTokenExpiresAt),
      'refreshToken': tokens.refreshToken,
      'refreshTokenExpiresAt': _encodeUtc(tokens.refreshTokenExpiresAt),
      'cachedIdentity': identity == null
          ? null
          : <String, Object?>{
              'schemaVersion': _identitySchemaVersion,
              'userId': identity.userId,
              'nickname': identity.nickname,
              'userVersion': identity.userVersion,
            },
    });
    return _storage.write(storageKey, encoded);
  }

  Future<void> _deleteLocked() async {
    await _storage.delete(storageKey);
    if (!_cleared.isClosed) {
      _cleared.add(null);
    }
  }

  static _StoredAuthRecord _decode(String encoded, {required DateTime now}) {
    final Object? decoded;
    try {
      decoded = jsonDecode(encoded);
    } on FormatException {
      throw const FormatException('Stored authentication data is malformed.');
    }
    if (decoded is! Map<String, dynamic> || decoded['schemaVersion'] is! int) {
      throw const FormatException(
        'Stored authentication data has an invalid schema.',
      );
    }
    final schemaVersion = decoded['schemaVersion'] as int;
    final validFields = switch (schemaVersion) {
      _legacySchemaVersion => _legacyFieldNames,
      _schemaVersion => _fieldNames,
      _ => null,
    };
    if (validFields == null ||
        decoded.length != validFields.length ||
        !decoded.keys.every(validFields.contains) ||
        decoded['tokenType'] is! String ||
        decoded['accessToken'] is! String ||
        decoded['accessTokenExpiresAt'] is! String ||
        decoded['refreshToken'] is! String ||
        decoded['refreshTokenExpiresAt'] is! String) {
      throw const FormatException(
        'Stored authentication data has an invalid schema.',
      );
    }

    final tokens = AuthTokens(
      tokenType: decoded['tokenType'] as String,
      accessToken: decoded['accessToken'] as String,
      accessTokenExpiresAt: _decodeUtc(
        decoded['accessTokenExpiresAt'] as String,
      ),
      refreshToken: decoded['refreshToken'] as String,
      refreshTokenExpiresAt: _decodeUtc(
        decoded['refreshTokenExpiresAt'] as String,
      ),
    );
    _validateTokens(tokens, now: now, requireCurrentAccessToken: false);
    final CachedAuthIdentity? identity;
    if (schemaVersion == _legacySchemaVersion) {
      identity = null;
    } else {
      identity = _decodeIdentity(decoded['cachedIdentity']);
    }
    return _StoredAuthRecord(tokens: tokens, identity: identity);
  }

  static CachedAuthIdentity? _decodeIdentity(Object? decoded) {
    if (decoded == null) {
      return null;
    }
    if (decoded is! Map<String, dynamic> ||
        decoded.length != _identityFieldNames.length ||
        !decoded.keys.every(_identityFieldNames.contains) ||
        decoded['schemaVersion'] is! int ||
        decoded['schemaVersion'] != _identitySchemaVersion ||
        decoded['userId'] is! String ||
        (decoded['nickname'] != null && decoded['nickname'] is! String) ||
        decoded['userVersion'] is! int) {
      throw const FormatException(
        'Stored authentication identity has an invalid schema.',
      );
    }
    final identity = CachedAuthIdentity(
      userId: decoded['userId'] as String,
      nickname: decoded['nickname'] as String?,
      userVersion: decoded['userVersion'] as int,
    );
    _validateIdentity(identity);
    return identity;
  }

  static void _validateIdentity(CachedAuthIdentity identity) {
    final nickname = identity.nickname;
    if (identity.userId != identity.userId.toLowerCase() ||
        !_canonicalUuid.hasMatch(identity.userId) ||
        !Uuid.isValidUUID(fromString: identity.userId) ||
        identity.userVersion < 1 ||
        (nickname != null &&
            (nickname.isEmpty ||
                nickname.length > 40 ||
                nickname.trim() != nickname))) {
      throw const FormatException('Authentication identity data is invalid.');
    }
  }

  static void _validateTokens(
    AuthTokens tokens, {
    required DateTime now,
    required bool requireCurrentAccessToken,
  }) {
    if (tokens.tokenType != 'Bearer' ||
        !_validOpaqueToken(tokens.accessToken, minLength: 1, maxLength: 8192) ||
        !_validOpaqueToken(
          tokens.refreshToken,
          minLength: 32,
          maxLength: 512,
        ) ||
        !tokens.accessTokenExpiresAt.isUtc ||
        !tokens.refreshTokenExpiresAt.isUtc ||
        !tokens.refreshTokenExpiresAt.isAfter(tokens.accessTokenExpiresAt) ||
        !tokens.refreshTokenExpiresAt.isAfter(now.toUtc()) ||
        (requireCurrentAccessToken &&
            !tokens.accessTokenExpiresAt.isAfter(now.toUtc()))) {
      throw const FormatException('Authentication token data is invalid.');
    }
  }

  static bool _validOpaqueToken(
    String value, {
    required int minLength,
    required int maxLength,
  }) =>
      value.length >= minLength &&
      value.length <= maxLength &&
      !RegExp(r'\s').hasMatch(value);

  static String _encodeUtc(DateTime value) => value.toUtc().toIso8601String();

  static DateTime _decodeUtc(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null || !parsed.isUtc || parsed.toIso8601String() != value) {
      throw const FormatException('Stored authentication expiry is invalid.');
    }
    return parsed;
  }
}

final class _StoredAuthRecord {
  const _StoredAuthRecord({required this.tokens, required this.identity});

  final AuthTokens tokens;
  final CachedAuthIdentity? identity;
}

final class _AsyncMutex {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() operation) {
    final previous = _tail;
    final release = Completer<void>();
    _tail = release.future;
    return (() async {
      await previous;
      try {
        return await operation();
      } finally {
        release.complete();
      }
    })();
  }
}
