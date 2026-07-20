import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/core/security/database_key_store.dart';

void main() {
  test('creates and persists a 256-bit key for a new database', () async {
    final store = _MemorySecureStore();
    final keyStore = DatabaseKeyStore(store, random: Random(7));

    final key = await keyStore.loadOrCreate(databaseExists: false);

    expect(key, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(store.value, key);
  });

  test('normalizes and reuses the persisted key', () async {
    final suffix = List<String>.filled(62, 'b').join();
    final store = _MemorySecureStore(' AA$suffix ');

    final key = await DatabaseKeyStore(
      store,
    ).loadOrCreate(databaseExists: true);

    expect(key, 'aa$suffix');
    expect(store.writeCount, 0);
  });

  test('does not silently replace a missing key for an existing database', () {
    expect(
      () => DatabaseKeyStore(
        _MemorySecureStore(),
      ).loadOrCreate(databaseExists: true),
      throwsA(isA<MissingDatabaseKeyException>()),
    );
  });

  test('rejects malformed persisted keys', () {
    expect(
      () => DatabaseKeyStore(
        _MemorySecureStore('not-a-key'),
      ).loadOrCreate(databaseExists: true),
      throwsA(isA<InvalidDatabaseKeyException>()),
    );
  });

  test('reset removes the persisted key', () async {
    final store = _MemorySecureStore('a' * 64);

    await DatabaseKeyStore(store).reset();

    expect(store.value, isNull);
    expect(store.deleteCount, 1);
  });
}

class _MemorySecureStore implements SecureValueStore {
  _MemorySecureStore([this.value]);

  String? value;
  int deleteCount = 0;
  int writeCount = 0;

  @override
  Future<void> delete(String key) async {
    value = null;
    deleteCount++;
  }

  @override
  Future<String?> read(String key) async => value;

  @override
  Future<void> write(String key, String value) async {
    this.value = value;
    writeCount++;
  }
}
