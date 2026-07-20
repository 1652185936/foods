import 'sync_models.dart';

abstract interface class SynchronizationAdapter {
  Future<SyncWriteReceipt> push(PendingSyncOperation operation);

  Future<SyncPullPage> pull({required int cursor, required int limit});
}

final class RejectedSyncOperationException implements Exception {
  const RejectedSyncOperationException({
    required this.statusCode,
    required this.problemCode,
  }) : assert(statusCode == 400 || statusCode == 422);

  final int statusCode;
  final String problemCode;

  @override
  String toString() =>
      'RejectedSyncOperationException($statusCode, $problemCode)';
}
