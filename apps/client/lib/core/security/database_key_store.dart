import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SecureValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

final class FlutterSecureValueStore implements SecureValueStore {
  FlutterSecureValueStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(
              resetOnError: false,
              migrateWithBackup: true,
              storageNamespace: 'foods_database',
            ),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

final class DatabaseKeyStore {
  DatabaseKeyStore(this._secureStore, {Random? random})
    : _random = random ?? Random.secure();

  static const _storageIdentifier = 'foods.sqlcipher.key.v1';
  static final _validKey = RegExp(r'^[0-9a-f]{64}$');

  final SecureValueStore _secureStore;
  final Random _random;

  Future<void> reset() => _secureStore.delete(_storageIdentifier);

  Future<String> loadOrCreate({required bool databaseExists}) async {
    final stored = await _secureStore.read(_storageIdentifier);
    if (stored != null) {
      final normalized = stored.trim().toLowerCase();
      if (!_validKey.hasMatch(normalized)) {
        throw const InvalidDatabaseKeyException();
      }
      return normalized;
    }

    if (databaseExists) {
      throw const MissingDatabaseKeyException();
    }

    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    final key = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    await _secureStore.write(_storageIdentifier, key);
    return key;
  }
}

sealed class DatabaseKeyException implements Exception {
  const DatabaseKeyException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

final class MissingDatabaseKeyException extends DatabaseKeyException {
  const MissingDatabaseKeyException()
    : super('An existing database has no matching key in secure storage.');
}

final class InvalidDatabaseKeyException extends DatabaseKeyException {
  const InvalidDatabaseKeyException()
    : super('The database key in secure storage is malformed.');
}
