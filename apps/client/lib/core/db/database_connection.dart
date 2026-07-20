import 'dart:io';

import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' show SqlError, SqliteException;

import '../security/database_key_store.dart';
import 'app_database.dart';

typedef DatabasePathResolver = Future<String> Function();

abstract interface class AppDatabaseFactory {
  Future<AppDatabase> open();

  Future<void> reset();
}

Future<String> resolveProductionDatabasePath() async {
  final directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  return p.join(directory.path, 'foods-v1.sqlite');
}

final class AppDatabaseOpener implements AppDatabaseFactory {
  AppDatabaseOpener(
    this._keyStore, [
    this._pathResolver = resolveProductionDatabasePath,
  ]);

  final DatabaseKeyStore _keyStore;
  final DatabasePathResolver _pathResolver;

  @override
  Future<void> reset() async {
    final path = await _pathResolver();
    for (final suffix in const <String>['', '-wal', '-shm', '-journal']) {
      final file = File('$path$suffix');
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _keyStore.reset();
  }

  @override
  Future<AppDatabase> open() async {
    final path = await _pathResolver();
    final file = File(path);
    final key = await _keyStore.loadOrCreate(
      databaseExists: await file.exists(),
    );

    final connection = NativeDatabase.createInBackground(
      file,
      setup: (database) {
        database.execute('PRAGMA key = "x\'$key\'"');
        final cipherVersion = database.select('PRAGMA cipher_version');
        if (cipherVersion.isEmpty) {
          throw StateError('The bundled SQLite library has no SQLCipher.');
        }
      },
    );
    final database = AppDatabase(connection);
    try {
      await database.customSelect('SELECT 1').getSingle();
      return database;
    } catch (error, stackTrace) {
      await database.close();
      if (_isUnreadableDatabase(error)) {
        Error.throwWithStackTrace(
          UnreadableEncryptedDatabaseException(error),
          stackTrace,
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  static bool _isUnreadableDatabase(Object error) {
    final cause = error is DriftRemoteException ? error.remoteCause : error;
    return cause is SqliteException &&
        (cause.resultCode == SqlError.SQLITE_NOTADB ||
            cause.resultCode == SqlError.SQLITE_CORRUPT);
  }
}

final class UnreadableEncryptedDatabaseException implements Exception {
  const UnreadableEncryptedDatabaseException(this.cause);

  final Object cause;
}
