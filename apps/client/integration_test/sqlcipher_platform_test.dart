import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/core/db/database_connection.dart';
import 'package:foods_client/core/security/database_key_store.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SQLCipher encrypts the file and rejects a different key', (
    tester,
  ) async {
    final directory = await Directory.systemTemp.createTemp(
      'ordin-sqlcipher-platform-',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final path = '${directory.path}${Platform.pathSeparator}probe.sqlite';
    final secureStore = _MemorySecureValueStore();
    final opener = AppDatabaseOpener(
      DatabaseKeyStore(secureStore),
      () async => path,
    );

    final created = await opener.open();
    await created.customStatement(
      'CREATE TABLE IF NOT EXISTS cipher_probe ('
      'id INTEGER PRIMARY KEY, value TEXT NOT NULL)',
    );
    await created.customStatement(
      'INSERT INTO cipher_probe (id, value) VALUES (1, ?)',
      <Object?>['encrypted-on-device'],
    );
    await created.close();

    final header = await File(path)
        .openRead(0, 16)
        .fold<List<int>>(<int>[], (bytes, chunk) => bytes..addAll(chunk));
    expect(String.fromCharCodes(header), isNot('SQLite format 3\u0000'));

    final reopened = await opener.open();
    final value = await reopened
        .customSelect('SELECT value FROM cipher_probe WHERE id = 1')
        .getSingle();
    expect(value.read<String>('value'), 'encrypted-on-device');
    await reopened.close();

    final wrongKeyStore = _MemorySecureValueStore(initialValue: '0' * 64);
    final wrongKeyOpener = AppDatabaseOpener(
      DatabaseKeyStore(wrongKeyStore),
      () async => path,
    );
    await expectLater(
      wrongKeyOpener.open(),
      throwsA(isA<UnreadableEncryptedDatabaseException>()),
    );
  });
}

final class _MemorySecureValueStore implements SecureValueStore {
  _MemorySecureValueStore({String? initialValue}) : _value = initialValue;

  String? _value;

  @override
  Future<void> delete(String key) async {
    _value = null;
  }

  @override
  Future<String?> read(String key) async => _value;

  @override
  Future<void> write(String key, String value) async {
    _value = value;
  }
}
