import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/db/account_scope.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/network/auth_tokens.dart';
import '../../../core/sync/sync_coordinator.dart';
import '../data/account_export_file_sharer.dart';
import '../data/account_privacy_api.dart';
import '../data/drift_account_local_data_cleaner.dart';

const accountDeletionUserPhrase = '删除我的账号';

final accountPrivacyApiProvider = Provider<AccountPrivacyApi>((ref) {
  _requireAuthenticatedScope(ref.watch(accountScopeProvider));
  return GeneratedAccountPrivacyApi(ref.watch(ordinApiClientsProvider).users);
}, dependencies: [accountScopeProvider, ordinApiClientsProvider]);

final accountExportFileSharerProvider = Provider<AccountExportFileSharer>((
  ref,
) {
  _requireAuthenticatedScope(ref.watch(accountScopeProvider));
  return NativeAccountExportFileSharer();
}, dependencies: [accountScopeProvider]);

final accountLocalDataCleanerProvider = Provider<AccountLocalDataCleaner>((
  ref,
) {
  _requireAuthenticatedScope(ref.watch(accountScopeProvider));
  return DriftAccountLocalDataCleaner(ref.watch(appDatabaseProvider));
}, dependencies: [accountScopeProvider, appDatabaseProvider]);

typedef AccountDeletedSessionTransition = void Function();

final accountDeletedSessionTransitionProvider =
    Provider<AccountDeletedSessionTransition>((ref) {
      _requireAuthenticatedScope(ref.watch(accountScopeProvider));
      final controller = ref.watch(authControllerProvider.notifier);
      return controller.completeAccountDeletion;
    }, dependencies: [accountScopeProvider, authControllerProvider]);

final accountPrivacyControllerProvider =
    NotifierProvider<AccountPrivacyController, AccountPrivacyState>(
      AccountPrivacyController.new,
      dependencies: [
        accountScopeProvider,
        accountPrivacyApiProvider,
        accountExportFileSharerProvider,
        accountLocalDataCleanerProvider,
        authSessionRepositoryProvider,
        authTokenStoreProvider,
        deviceInstallationIdStoreProvider,
        notificationServiceProvider,
        accountSyncRunnerProvider,
        accountDeletedSessionTransitionProvider,
      ],
    );

enum AccountPrivacyOperation { idle, exporting, deleting }

enum AccountExportFailure { tooLarge, unavailable }

enum AccountDeletionFailure {
  refreshFailed,
  requestFailed,
  localCredentialClearFailed,
}

final class AccountPrivacyState {
  const AccountPrivacyState({
    this.operation = AccountPrivacyOperation.idle,
    this.exportFailure,
    this.deletionFailure,
  });

  final AccountPrivacyOperation operation;
  final AccountExportFailure? exportFailure;
  final AccountDeletionFailure? deletionFailure;

  bool get isBusy => operation != AccountPrivacyOperation.idle;
  bool get isExporting => operation == AccountPrivacyOperation.exporting;
  bool get isDeleting => operation == AccountPrivacyOperation.deleting;
}

enum AccountExportResult { applied, ignored, tooLarge, failed }

enum AccountDeletionResult {
  applied,
  appliedWithLocalCleanupWarning,
  ignored,
  invalidConfirmation,
  failed,
}

final class AccountPrivacyController extends Notifier<AccountPrivacyState> {
  var _operationEpoch = 0;
  var _disposed = false;
  var _remoteDeletionCompleted = false;
  var _localCleanupFailed = false;

  @override
  AccountPrivacyState build() {
    _disposed = false;
    _remoteDeletionCompleted = false;
    _localCleanupFailed = false;
    _requireAuthenticatedScope(ref.watch(accountScopeProvider));
    ref.onDispose(() {
      _disposed = true;
      _operationEpoch++;
    });
    return const AccountPrivacyState();
  }

  void clearFailures() {
    if (!state.isBusy &&
        (state.exportFailure != null || state.deletionFailure != null)) {
      state = const AccountPrivacyState();
    }
  }

  Future<AccountExportResult> exportData({Rect? sharePositionOrigin}) async {
    if (state.isBusy) {
      return AccountExportResult.ignored;
    }

    state = const AccountPrivacyState(
      operation: AccountPrivacyOperation.exporting,
    );
    final operation = ++_operationEpoch;
    final api = ref.read(accountPrivacyApiProvider);
    final sharer = ref.read(accountExportFileSharerProvider);
    try {
      final exported = await api.exportCurrentUserData();
      if (!_isCurrent(operation)) {
        return AccountExportResult.ignored;
      }
      await sharer.share(exported, sharePositionOrigin: sharePositionOrigin);
      if (!_isCurrent(operation)) {
        return AccountExportResult.ignored;
      }
      state = const AccountPrivacyState();
      return AccountExportResult.applied;
    } catch (error) {
      if (!_isCurrent(operation)) {
        return AccountExportResult.ignored;
      }
      final tooLarge = _isPayloadTooLarge(error);
      state = AccountPrivacyState(
        exportFailure: tooLarge
            ? AccountExportFailure.tooLarge
            : AccountExportFailure.unavailable,
      );
      return tooLarge
          ? AccountExportResult.tooLarge
          : AccountExportResult.failed;
    }
  }

  Future<AccountDeletionResult> deleteAccount(String confirmation) async {
    if (confirmation != accountDeletionUserPhrase) {
      return AccountDeletionResult.invalidConfirmation;
    }
    if (state.isBusy) {
      return AccountDeletionResult.ignored;
    }

    final scope = ref.read(accountScopeProvider);
    final repository = ref.read(authSessionRepositoryProvider);
    final tokenStore = ref.read(authTokenStoreProvider);
    final installationIds = ref.read(deviceInstallationIdStoreProvider);
    final api = ref.read(accountPrivacyApiProvider);
    final syncRunner = ref.read(accountSyncRunnerProvider);
    final cleaner = ref.read(accountLocalDataCleanerProvider);
    final notifications = ref.read(notificationServiceProvider);
    final completeAccountDeletion = ref.read(
      accountDeletedSessionTransitionProvider,
    );

    state = const AccountPrivacyState(
      operation: AccountPrivacyOperation.deleting,
    );
    final operation = ++_operationEpoch;

    if (!_remoteDeletionCompleted) {
      try {
        final refreshed = await repository.refreshSession();
        if (!_isCurrent(operation)) {
          return AccountDeletionResult.ignored;
        }
        if (refreshed == null || refreshed.userId != scope.ownerUserId) {
          state = const AccountPrivacyState(
            deletionFailure: AccountDeletionFailure.refreshFailed,
          );
          return AccountDeletionResult.failed;
        }
      } catch (_) {
        if (!_isCurrent(operation)) {
          return AccountDeletionResult.ignored;
        }
        state = const AccountPrivacyState(
          deletionFailure: AccountDeletionFailure.refreshFailed,
        );
        return AccountDeletionResult.failed;
      }

      final AuthTokens tokens;
      final String deviceInstallationId;
      try {
        final latestTokens = await tokenStore.read();
        if (latestTokens == null) {
          state = const AccountPrivacyState(
            deletionFailure: AccountDeletionFailure.refreshFailed,
          );
          return AccountDeletionResult.failed;
        }
        tokens = latestTokens;
        deviceInstallationId = await installationIds.loadOrCreate();
        if (!_isCurrent(operation)) {
          return AccountDeletionResult.ignored;
        }
        await api.deleteCurrentUser(
          refreshToken: tokens.refreshToken,
          deviceInstallationId: deviceInstallationId,
        );
      } catch (_) {
        if (!_isCurrent(operation)) {
          return AccountDeletionResult.ignored;
        }
        state = const AccountPrivacyState(
          deletionFailure: AccountDeletionFailure.requestFailed,
        );
        return AccountDeletionResult.failed;
      }

      _remoteDeletionCompleted = true;
      try {
        syncRunner.cancel();
      } catch (_) {
        // Server deletion succeeded; remaining local teardown must continue.
      }
      try {
        await cleaner.deleteAllForOwner(scope.ownerUserId);
      } catch (_) {
        _localCleanupFailed = true;
      }
      try {
        await notifications.cancelFastingReminder();
      } catch (_) {
        // Notification plugins are best-effort during irreversible teardown.
      }
    }

    try {
      await tokenStore.clear();
    } catch (_) {
      if (_isCurrent(operation)) {
        state = const AccountPrivacyState(
          deletionFailure: AccountDeletionFailure.localCredentialClearFailed,
        );
      }
      return AccountDeletionResult.failed;
    }
    completeAccountDeletion();

    return _localCleanupFailed
        ? AccountDeletionResult.appliedWithLocalCleanupWarning
        : AccountDeletionResult.applied;
  }

  static bool _isPayloadTooLarge(Object error) =>
      error is DioException && error.response?.statusCode == 413;

  bool _isCurrent(int operation) => !_disposed && operation == _operationEpoch;
}

void _requireAuthenticatedScope(AccountScope scope) {
  if (!scope.canSync) {
    throw StateError('Account privacy operations require authentication.');
  }
}
