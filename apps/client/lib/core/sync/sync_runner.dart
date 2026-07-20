import 'sync_models.dart';

abstract interface class AccountSyncRunner {
  Future<SyncRunResult> run();

  Future<int> countConflicts();

  void cancel();
}

final class SyncCancelledException implements Exception {
  const SyncCancelledException();
}
