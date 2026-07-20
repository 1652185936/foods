import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/core/db/database_connection.dart';
import 'package:foods_client/core/security/database_key_store.dart';

void main() {
  test('reset removes the database, sidecars, and encryption key', () async {
    final directory = await Directory.systemTemp.createTemp(
      'foods-database-reset-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final databasePath =
        '${directory.path}${Platform.pathSeparator}foods-v1.sqlite';
    final files = <File>[
      for (final suffix in const <String>['', '-wal', '-shm', '-journal'])
        File('$databasePath$suffix'),
    ];
    for (final file in files) {
      await file.writeAsString('test');
    }
    final secureStore = _MemorySecureValueStore('a' * 64);
    final opener = AppDatabaseOpener(
      DatabaseKeyStore(secureStore),
      () async => databasePath,
    );

    await opener.reset();

    for (final file in files) {
      expect(await file.exists(), isFalse);
    }
    expect(secureStore.value, isNull);
    expect(secureStore.deleteCount, 1);
  });

  test('classifies an unreadable database as recoverable damage', () async {
    final directory = await Directory.systemTemp.createTemp(
      'foods-database-unreadable-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final databasePath =
        '${directory.path}${Platform.pathSeparator}foods-v1.sqlite';
    await File(databasePath).writeAsString('not a sqlite database');
    final opener = AppDatabaseOpener(
      DatabaseKeyStore(_MemorySecureValueStore('a' * 64)),
      () async => databasePath,
    );

    await expectLater(
      opener.open(),
      throwsA(isA<UnreadableEncryptedDatabaseException>()),
    );
  });

  test('does not classify filesystem failures as recoverable damage', () async {
    final directory = await Directory.systemTemp.createTemp(
      'foods-database-filesystem-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final opener = AppDatabaseOpener(
      DatabaseKeyStore(_MemorySecureValueStore(null)),
      () async => directory.path,
    );

    await expectLater(
      opener.open(),
      throwsA(isNot(isA<UnreadableEncryptedDatabaseException>())),
    );
  });
}

final class _MemorySecureValueStore implements SecureValueStore {
  _MemorySecureValueStore(this.value);

  String? value;
  int deleteCount = 0;

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
  }
}
