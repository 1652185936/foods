import '../../../core/db/app_database.dart';

abstract interface class AccountLocalDataCleaner {
  Future<void> deleteAllForOwner(String ownerUserId);
}

final class DriftAccountLocalDataCleaner implements AccountLocalDataCleaner {
  const DriftAccountLocalDataCleaner(this._database);

  final AppDatabase _database;

  @override
  Future<void> deleteAllForOwner(String ownerUserId) {
    return _database.transaction(() async {
      await (_database.delete(
        _database.mealItems,
      )..where((row) => row.ownerUserId.equals(ownerUserId))).go();
      await (_database.delete(
        _database.mealLogs,
      )..where((row) => row.ownerUserId.equals(ownerUserId))).go();
      await (_database.delete(
        _database.fastingSessions,
      )..where((row) => row.ownerUserId.equals(ownerUserId))).go();
      await (_database.delete(
        _database.appPreferencesTable,
      )..where((row) => row.ownerUserId.equals(ownerUserId))).go();
      await (_database.delete(
        _database.syncOutbox,
      )..where((row) => row.ownerUserId.equals(ownerUserId))).go();
      await (_database.delete(
        _database.syncState,
      )..where((row) => row.ownerUserId.equals(ownerUserId))).go();
    });
  }
}
