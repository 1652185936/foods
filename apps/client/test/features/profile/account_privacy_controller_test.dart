import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/core/auth/auth_controller.dart';
import 'package:foods_client/core/auth/auth_models.dart';
import 'package:foods_client/core/auth/auth_providers.dart';
import 'package:foods_client/core/auth/auth_repository.dart';
import 'package:foods_client/core/auth/auth_secure_storage.dart';
import 'package:foods_client/core/auth/device_installation_id_store.dart';
import 'package:foods_client/core/db/account_scope.dart';
import 'package:foods_client/core/db/database_provider.dart';
import 'package:foods_client/core/network/auth_tokens.dart';
import 'package:foods_client/core/network/generated/models/account_data_export_response.dart';
import 'package:foods_client/core/network/generated/models/user_response.dart';
import 'package:foods_client/core/platform/notification_service.dart';
import 'package:foods_client/core/sync/sync_coordinator.dart';
import 'package:foods_client/core/sync/sync_models.dart';
import 'package:foods_client/core/sync/sync_runner.dart';
import 'package:foods_client/features/fasting/domain/fasting_session.dart';
import 'package:foods_client/features/auth/presentation/auth_session_gate.dart';
import 'package:foods_client/features/profile/application/account_privacy_controller.dart';
import 'package:foods_client/features/profile/data/account_export_file_sharer.dart';
import 'package:foods_client/features/profile/data/account_privacy_api.dart';
import 'package:foods_client/features/profile/data/drift_account_local_data_cleaner.dart';
import 'package:foods_client/features/profile/presentation/profile_page.dart';

import '../../support/auth_test_support.dart';
import '../../support/test_dependencies.dart';

void main() {
  final now = DateTime.utc(2026, 7, 21, 3);

  test('413 export is explicit and never creates a share file', () async {
    final fixture = _PrivacyFixture(now);
    final request = RequestOptions(path: '/api/v1/users/me/data-export');
    fixture.api.exportError = DioException(
      requestOptions: request,
      response: Response<void>(requestOptions: request, statusCode: 413),
    );
    final container = fixture.createContainer();

    final result = await container
        .read(accountPrivacyControllerProvider.notifier)
        .exportData();

    expect(result, AccountExportResult.tooLarge);
    expect(fixture.sharer.calls, 0);
    expect(fixture.cleaner.calls, 0);
    expect(fixture.tokenStore.clearCalls, 0);
    expect(
      container.read(accountPrivacyControllerProvider).exportFailure,
      AccountExportFailure.tooLarge,
    );
  });

  test('export is single-flight under repeated taps', () async {
    final fixture = _PrivacyFixture(now);
    final gate = Completer<AccountDataExportResponse>();
    fixture.api.exportGate = gate;
    final container = fixture.createContainer();
    final controller = container.read(
      accountPrivacyControllerProvider.notifier,
    );

    final first = controller.exportData();
    await Future<void>.delayed(Duration.zero);
    final second = await controller.exportData();
    gate.complete(_exportFixture(now));

    expect(second, AccountExportResult.ignored);
    expect(await first, AccountExportResult.applied);
    expect(fixture.api.exportCalls, 1);
    expect(fixture.sharer.calls, 1);
  });

  test('wrong confirmation never refreshes or mutates account data', () async {
    final fixture = _PrivacyFixture(now);
    final container = fixture.createContainer();

    final result = await container
        .read(accountPrivacyControllerProvider.notifier)
        .deleteAccount('删除账号');

    expect(result, AccountDeletionResult.invalidConfirmation);
    expect(fixture.repository.refreshCalls, 0);
    expect(fixture.api.deleteCalls, 0);
    expect(fixture.cleaner.calls, 0);
    expect(fixture.tokenStore.clearCalls, 0);
  });

  test('refresh failure preserves credentials and local data', () async {
    final fixture = _PrivacyFixture(now);
    fixture.repository.refreshError = StateError('offline');
    final originalTokens = fixture.tokenStore.tokens;
    final container = fixture.createContainer();

    final result = await container
        .read(accountPrivacyControllerProvider.notifier)
        .deleteAccount(accountDeletionUserPhrase);

    expect(result, AccountDeletionResult.failed);
    expect(fixture.tokenStore.tokens, same(originalTokens));
    expect(fixture.tokenStore.clearCalls, 0);
    expect(fixture.api.deleteCalls, 0);
    expect(fixture.cleaner.calls, 0);
    expect(fixture.notifications.cancelCalls, 0);
    expect(fixture.signedOut, isFalse);
  });

  test('deletion API failure preserves credentials and local data', () async {
    final fixture = _PrivacyFixture(now);
    fixture.api.deleteError = StateError('server unavailable');
    final container = fixture.createContainer();

    final result = await container
        .read(accountPrivacyControllerProvider.notifier)
        .deleteAccount(accountDeletionUserPhrase);

    expect(result, AccountDeletionResult.failed);
    expect(fixture.tokenStore.tokens, same(fixture.rotatedTokens));
    expect(fixture.tokenStore.clearCalls, 0);
    expect(fixture.cleaner.calls, 0);
    expect(fixture.syncRunner.cancelCalls, 0);
    expect(fixture.notifications.cancelCalls, 0);
    expect(fixture.signedOut, isFalse);
  });

  test(
    'success uses the rotated refresh token then clears local data, reminder and auth',
    () async {
      final fixture = _PrivacyFixture(now);
      final container = fixture.createContainer();

      final result = await container
          .read(accountPrivacyControllerProvider.notifier)
          .deleteAccount(accountDeletionUserPhrase);

      expect(result, AccountDeletionResult.applied);
      expect(fixture.repository.refreshCalls, 1);
      expect(fixture.api.deleteCalls, 1);
      expect(fixture.api.refreshToken, fixture.rotatedTokens.refreshToken);
      expect(
        fixture.api.refreshToken,
        isNot(fixture.originalTokens.refreshToken),
      );
      expect(fixture.api.deviceInstallationId, _installationId);
      expect(fixture.syncRunner.cancelCalls, 1);
      expect(fixture.cleaner.calls, 1);
      expect(fixture.cleaner.ownerUserId, authTestUserA);
      expect(fixture.notifications.cancelCalls, 1);
      expect(fixture.tokenStore.tokens, isNull);
      expect(fixture.tokenStore.clearCalls, 1);
      expect(fixture.signedOut, isTrue);
    },
  );

  test('local cleanup failure still cancels auth and signs out', () async {
    final fixture = _PrivacyFixture(now);
    fixture.cleaner.error = StateError('database unavailable');
    final container = fixture.createContainer();

    final result = await container
        .read(accountPrivacyControllerProvider.notifier)
        .deleteAccount(accountDeletionUserPhrase);

    expect(result, AccountDeletionResult.appliedWithLocalCleanupWarning);
    expect(fixture.notifications.cancelCalls, 1);
    expect(fixture.tokenStore.clearCalls, 1);
    expect(fixture.signedOut, isTrue);
  });

  test('deletion is single-flight under repeated taps', () async {
    final fixture = _PrivacyFixture(now);
    final gate = Completer<AuthSession?>();
    fixture.repository.refreshGate = gate;
    final container = fixture.createContainer();
    final controller = container.read(
      accountPrivacyControllerProvider.notifier,
    );

    final first = controller.deleteAccount(accountDeletionUserPhrase);
    await Future<void>.delayed(Duration.zero);
    final second = await controller.deleteAccount(accountDeletionUserPhrase);
    gate.complete(authTestSession(authTestUserA, now));

    expect(second, AccountDeletionResult.ignored);
    expect(await first, AccountDeletionResult.applied);
    expect(fixture.repository.refreshCalls, 1);
    expect(fixture.api.deleteCalls, 1);
  });

  testWidgets('delete dialog cancellation and a wrong phrase make no request', (
    tester,
  ) async {
    final fixture = _PrivacyFixture(now);
    final auth = AuthAuthenticated(
      session: authTestSession(authTestUserA, now),
      scopeGeneration: 1,
    );

    await tester.pumpWidget(fixture.profileApp(auth));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-delete-account')),
      240,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(find.byKey(const Key('profile-delete-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-account-cancel')));
    await tester.pumpAndSettle();
    expect(fixture.api.deleteCalls, 0);

    await tester.tap(find.byKey(const Key('profile-delete-account')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('delete-account-confirmation-input')),
      '删除账号',
    );
    await tester.pump();
    final confirm = tester.widget<FilledButton>(
      find.byKey(const Key('delete-account-confirm')),
    );
    expect(confirm.onPressed, isNull);
    await tester.tap(find.byKey(const Key('delete-account-cancel')));
    await tester.pumpAndSettle();
    expect(fixture.repository.refreshCalls, 0);
    expect(fixture.api.deleteCalls, 0);
    expect(fixture.cleaner.calls, 0);
    expect(fixture.tokenStore.clearCalls, 0);
  });

  testWidgets('profile shows export progress and an explicit 413 status', (
    tester,
  ) async {
    final fixture = _PrivacyFixture(now);
    final auth = AuthAuthenticated(
      session: authTestSession(authTestUserA, now),
      scopeGeneration: 1,
    );
    final gate = Completer<AccountDataExportResponse>();
    fixture.api.exportGate = gate;

    await tester.pumpWidget(fixture.profileApp(auth));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-export-data')),
      240,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(find.byKey(const Key('profile-export-data')));
    await tester.pump();
    expect(find.text('正在准备安全导出文件'), findsOneWidget);

    final request = RequestOptions(path: '/api/v1/users/me/data-export');
    gate.completeError(
      DioException(
        requestOptions: request,
        response: Response<void>(requestOptions: request, statusCode: 413),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('数据量过大，无法自动导出，请联系支持'), findsWidgets);
    expect(fixture.sharer.calls, 0);
    expect(fixture.cleaner.calls, 0);
    expect(fixture.tokenStore.clearCalls, 0);
  });

  testWidgets(
    'successful deletion drives the real auth controller signed out',
    (tester) async {
      final fixture = _PrivacyFixture(now);
      fixture.repository.restoreResult = authTestSession(authTestUserA, now);
      addTearDown(fixture.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionRepositoryProvider.overrideWithValue(fixture.repository),
            authSessionClearedEventsProvider.overrideWithValue(
              fixture.tokenStore.cleared,
            ),
            authTokenStoreProvider.overrideWithValue(fixture.tokenStore),
            authClockProvider.overrideWithValue(() => now),
            accountPrivacyApiProvider.overrideWithValue(fixture.api),
            accountExportFileSharerProvider.overrideWithValue(fixture.sharer),
            accountLocalDataCleanerProvider.overrideWithValue(fixture.cleaner),
            deviceInstallationIdStoreProvider.overrideWithValue(
              DeviceInstallationIdStore(
                _MemoryAuthStorage(),
                generateId: () => _installationId,
              ),
            ),
            notificationServiceProvider.overrideWithValue(
              fixture.notifications,
            ),
            accountSyncRunnerProvider.overrideWithValue(fixture.syncRunner),
          ],
          child: const _AuthPrivacyHarness(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('privacy-delete-trigger')), findsOneWidget);

      await tester.tap(find.byKey(const Key('privacy-delete-trigger')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('privacy-signed-out')), findsOneWidget);
      expect(find.text('账号已删除'), findsOneWidget);
      expect(fixture.tokenStore.tokens, isNull);
      expect(fixture.notifications.cancelCalls, greaterThanOrEqualTo(1));
    },
  );

  testWidgets(
    'secure storage failure keeps auth scope and retries local cleanup only',
    (tester) async {
      final fixture = _PrivacyFixture(now);
      fixture.repository.restoreResult = authTestSession(authTestUserA, now);
      fixture.tokenStore.failClear = true;
      addTearDown(fixture.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionRepositoryProvider.overrideWithValue(fixture.repository),
            authSessionClearedEventsProvider.overrideWithValue(
              fixture.tokenStore.cleared,
            ),
            authTokenStoreProvider.overrideWithValue(fixture.tokenStore),
            authClockProvider.overrideWithValue(() => now),
            accountPrivacyApiProvider.overrideWithValue(fixture.api),
            accountExportFileSharerProvider.overrideWithValue(fixture.sharer),
            accountLocalDataCleanerProvider.overrideWithValue(fixture.cleaner),
            deviceInstallationIdStoreProvider.overrideWithValue(
              DeviceInstallationIdStore(
                _MemoryAuthStorage(),
                generateId: () => _installationId,
              ),
            ),
            notificationServiceProvider.overrideWithValue(
              fixture.notifications,
            ),
            accountSyncRunnerProvider.overrideWithValue(fixture.syncRunner),
          ],
          child: const _AuthPrivacyHarness(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('privacy-delete-trigger')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('privacy-delete-trigger')), findsOneWidget);
      expect(find.byKey(const Key('privacy-signed-out')), findsNothing);
      expect(fixture.tokenStore.tokens, isNotNull);
      expect(fixture.tokenStore.clearCalls, 1);
      expect(fixture.cleaner.calls, 1);
      expect(fixture.notifications.cancelCalls, greaterThanOrEqualTo(1));
      expect(fixture.api.deleteCalls, 1);
      expect(fixture.repository.refreshCalls, 1);

      fixture.tokenStore.failClear = false;
      await tester.tap(find.byKey(const Key('privacy-delete-trigger')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('privacy-signed-out')), findsOneWidget);
      expect(find.text('账号已删除'), findsOneWidget);
      expect(fixture.tokenStore.tokens, isNull);
      expect(fixture.tokenStore.clearCalls, 2);
      expect(fixture.api.deleteCalls, 1);
      expect(fixture.repository.refreshCalls, 1);
      expect(fixture.cleaner.calls, 1);
    },
  );
}

class _AuthPrivacyHarness extends ConsumerWidget {
  const _AuthPrivacyHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (auth case AuthAuthenticated()) {
      return AuthenticatedAccountScope(
        auth: auth,
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, accountRef, _) => Center(
                child: FilledButton(
                  key: const Key('privacy-delete-trigger'),
                  onPressed: () => accountRef
                      .read(accountPrivacyControllerProvider.notifier)
                      .deleteAccount(accountDeletionUserPhrase),
                  child: const Text('Delete'),
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (auth is AuthSignedOut) {
      return MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const SizedBox(key: Key('privacy-signed-out')),
              Text(auth.noticeMessage ?? ''),
            ],
          ),
        ),
      );
    }
    return const MaterialApp(home: SizedBox());
  }
}

const _installationId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

final class _PrivacyFixture {
  _PrivacyFixture(this.now)
    : originalTokens = _tokens('original', now),
      rotatedTokens = _tokens('rotated', now) {
    tokenStore = _FakeTokenStore(originalTokens, () => signedOut = true);
    repository = _RefreshRepository(
      onRefresh: () async {
        await tokenStore.write(rotatedTokens);
        return authTestSession(authTestUserA, now);
      },
    );
  }

  final DateTime now;
  final AuthTokens originalTokens;
  final AuthTokens rotatedTokens;
  late final _FakeTokenStore tokenStore;
  late final _RefreshRepository repository;
  final api = _FakeAccountPrivacyApi();
  final sharer = _RecordingSharer();
  final cleaner = _RecordingCleaner();
  final notifications = _RecordingNotifications();
  final syncRunner = _RecordingSyncRunner();
  bool signedOut = false;

  Future<void> dispose() => tokenStore.dispose();

  Widget profileApp(AuthAuthenticated auth) {
    return testProviderScope(
      notifications: notifications,
      syncRunner: syncRunner,
      child: ProviderScope(
        overrides: [
          accountScopeProvider.overrideWithValue(
            AccountScope.authenticated(authTestUserA),
          ),
          currentAuthSessionProvider.overrideWithValue(auth),
          accountPrivacyApiProvider.overrideWithValue(api),
          accountExportFileSharerProvider.overrideWithValue(sharer),
          accountLocalDataCleanerProvider.overrideWithValue(cleaner),
          authSessionRepositoryProvider.overrideWithValue(repository),
          authTokenStoreProvider.overrideWithValue(tokenStore),
          deviceInstallationIdStoreProvider.overrideWithValue(
            DeviceInstallationIdStore(
              _MemoryAuthStorage(),
              generateId: () => _installationId,
            ),
          ),
          accountDeletedSessionTransitionProvider.overrideWithValue(
            () => signedOut = true,
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: ProfilePage())),
      ),
    );
  }

  ProviderContainer createContainer() {
    return ProviderContainer.test(
      overrides: [
        accountScopeProvider.overrideWithValue(
          AccountScope.authenticated(authTestUserA),
        ),
        accountPrivacyApiProvider.overrideWithValue(api),
        accountExportFileSharerProvider.overrideWithValue(sharer),
        accountLocalDataCleanerProvider.overrideWithValue(cleaner),
        authSessionRepositoryProvider.overrideWithValue(repository),
        authTokenStoreProvider.overrideWithValue(tokenStore),
        deviceInstallationIdStoreProvider.overrideWithValue(
          DeviceInstallationIdStore(
            _MemoryAuthStorage(),
            generateId: () => _installationId,
          ),
        ),
        notificationServiceProvider.overrideWithValue(notifications),
        accountSyncRunnerProvider.overrideWithValue(syncRunner),
        accountDeletedSessionTransitionProvider.overrideWithValue(
          () => signedOut = true,
        ),
      ],
    );
  }
}

AuthTokens _tokens(String label, DateTime now) => AuthTokens(
  accessToken: 'access-$label',
  accessTokenExpiresAt: now.add(const Duration(hours: 1)),
  refreshToken: '$label-${List<String>.filled(40, 'r').join()}',
  refreshTokenExpiresAt: now.add(const Duration(days: 30)),
  tokenType: 'Bearer',
);

AccountDataExportResponse _exportFixture(DateTime now) =>
    AccountDataExportResponse(
      exportedAt: now,
      fastingSessions: const [],
      healthProfile: null,
      meals: const [],
      preferences: null,
      recognitions: const [],
      user: UserResponse(
        createdAt: now,
        id: authTestUserA,
        nickname: 'User',
        status: 'active',
        updatedAt: now,
        version: 1,
      ),
    );

final class _FakeAccountPrivacyApi implements AccountPrivacyApi {
  Object? exportError;
  Object? deleteError;
  Completer<AccountDataExportResponse>? exportGate;
  int exportCalls = 0;
  int deleteCalls = 0;
  String? refreshToken;
  String? deviceInstallationId;

  @override
  Future<void> deleteCurrentUser({
    required String refreshToken,
    required String deviceInstallationId,
  }) async {
    deleteCalls++;
    this.refreshToken = refreshToken;
    this.deviceInstallationId = deviceInstallationId;
    final error = deleteError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<AccountDataExportResponse> exportCurrentUserData() {
    exportCalls++;
    final error = exportError;
    if (error != null) {
      return Future<AccountDataExportResponse>.error(error);
    }
    return exportGate?.future ??
        Future<AccountDataExportResponse>.value(
          _exportFixture(DateTime.utc(2026, 7, 21, 3)),
        );
  }
}

final class _RecordingSharer implements AccountExportFileSharer {
  int calls = 0;

  @override
  Future<void> share(
    AccountDataExportResponse export, {
    Rect? sharePositionOrigin,
  }) async {
    calls++;
  }
}

final class _RecordingCleaner implements AccountLocalDataCleaner {
  int calls = 0;
  String? ownerUserId;
  Object? error;

  @override
  Future<void> deleteAllForOwner(String ownerUserId) async {
    calls++;
    this.ownerUserId = ownerUserId;
    final currentError = error;
    if (currentError != null) {
      throw currentError;
    }
  }
}

final class _RecordingNotifications implements NotificationService {
  int cancelCalls = 0;

  @override
  Future<void> cancelFastingReminder() async => cancelCalls++;

  @override
  Future<bool> notificationsEnabled() async => true;

  @override
  Future<bool> requestNotificationPermission() async => true;

  @override
  Future<void> reconcile(
    FastingSession? activeSession, {
    bool requestPermission = false,
  }) async {}
}

final class _RecordingSyncRunner implements AccountSyncRunner {
  int cancelCalls = 0;

  @override
  void cancel() => cancelCalls++;

  @override
  Future<int> countConflicts() async => 0;

  @override
  Future<SyncRunResult> run() async => SyncRunResult(
    pushedOperations: 0,
    pulledChanges: 0,
    cursor: 0,
    conflicts: const <SyncConflict>[],
  );
}

final class _FakeTokenStore implements AuthTokenStore {
  _FakeTokenStore(this.tokens, this.onClear);

  AuthTokens? tokens;
  final void Function() onClear;
  final _cleared = StreamController<void>.broadcast(sync: true);
  int clearCalls = 0;
  bool failClear = false;

  Stream<void> get cleared => _cleared.stream;

  @override
  Future<void> clear() async {
    clearCalls++;
    if (failClear) {
      throw StateError('secure storage unavailable');
    }
    tokens = null;
    onClear();
    _cleared.add(null);
  }

  @override
  Future<AuthTokens?> read() async => tokens;

  @override
  Future<void> write(AuthTokens tokens) async => this.tokens = tokens;

  Future<void> dispose() => _cleared.close();
}

final class _RefreshRepository implements AuthSessionRepository {
  _RefreshRepository({required this.onRefresh});

  final Future<AuthSession?> Function() onRefresh;
  Completer<AuthSession?>? refreshGate;
  Object? refreshError;
  AuthSession? restoreResult;
  int refreshCalls = 0;

  @override
  void cancelPendingAuthentication() {}

  @override
  Future<AuthSession?> refreshSession() {
    refreshCalls++;
    final error = refreshError;
    if (error != null) {
      return Future<AuthSession?>.error(error);
    }
    return refreshGate?.future ?? onRefresh();
  }

  @override
  Future<void> logout() => throw UnimplementedError();

  @override
  Future<OtpChallenge> requestOtpChallenge(String phoneNumber) =>
      throw UnimplementedError();

  @override
  Future<AuthSession?> restoreSession() async => restoreResult;

  @override
  Future<AuthSession> verifyOtp({
    required String challengeId,
    required String code,
  }) => throw UnimplementedError();
}

final class _MemoryAuthStorage implements AuthSecureStorage {
  final _values = <String, String>{};

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}
