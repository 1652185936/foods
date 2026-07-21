import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/core/auth/auth_controller.dart';
import 'package:foods_client/core/auth/auth_models.dart';
import 'package:foods_client/core/auth/auth_providers.dart';
import 'package:foods_client/core/auth/auth_repository.dart';
import 'package:foods_client/core/db/database_provider.dart';
import 'package:foods_client/core/network/auth_tokens.dart';
import 'package:foods_client/core/platform/notification_service.dart';
import 'package:foods_client/features/fasting/domain/fasting_session.dart';

const _userA = '0190a123-4567-7891-8123-456789abcdef';
const _refreshToken = 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr';

void main() {
  final now = DateTime.utc(2026, 7, 20, 12);

  test(
    'cold restore is single-flight and retry is ignored while loading',
    () async {
      final restore = Completer<AuthSession?>();
      final repository = _FakeAuthSessionRepository()
        ..restoreHandler = () => restore.future;
      final fixture = _fixture(repository, now);
      addTearDown(fixture.dispose);

      expect(
        fixture.container.read(authControllerProvider),
        isA<AuthRestoring>(),
      );
      await fixture.container
          .read(authControllerProvider.notifier)
          .retryRestore();
      await _flush();
      expect(repository.restoreCalls, 1);

      restore.complete(_session(_userA, now));
      await _flush();
      final state = fixture.container.read(authControllerProvider);
      expect(state, isA<AuthAuthenticated>());
      expect((state as AuthAuthenticated).session.userId, _userA);
    },
  );

  test('offline cached restore accepts an expired access token', () async {
    final cachedSession = AuthSession(
      userId: _userA,
      nickname: '测试用户',
      userVersion: 1,
      tokens: AuthTokens(
        accessToken: 'expired-access',
        accessTokenExpiresAt: now.subtract(const Duration(minutes: 1)),
        refreshToken: _refreshToken,
        refreshTokenExpiresAt: now.add(const Duration(days: 30)),
        tokenType: 'Bearer',
      ),
    );
    final repository = _FakeAuthSessionRepository()
      ..restoreHandler = () async => cachedSession;
    final fixture = _fixture(repository, now);
    addTearDown(fixture.dispose);

    await _flush();

    final state = fixture.container.read(authControllerProvider);
    expect(state, isA<AuthAuthenticated>());
    expect((state as AuthAuthenticated).session, same(cachedSession));
    expect(state.scopeGeneration, 1);
  });

  test(
    'temporary restore failure keeps a retry state instead of signing out',
    () async {
      var shouldFail = true;
      final repository = _FakeAuthSessionRepository()
        ..restoreHandler = () async {
          if (shouldFail) {
            throw _dioError(DioExceptionType.connectionError);
          }
          return null;
        };
      final fixture = _fixture(repository, now);
      addTearDown(fixture.dispose);

      await _flush();
      expect(
        fixture.container.read(authControllerProvider),
        isA<AuthRestoreFailed>(),
      );

      shouldFail = false;
      await fixture.container
          .read(authControllerProvider.notifier)
          .retryRestore();
      expect(
        fixture.container.read(authControllerProvider),
        isA<AuthSignedOut>(),
      );
      expect(repository.restoreCalls, 2);
    },
  );

  test(
    'configuration errors are not presented as retryable network failures',
    () async {
      final repository = _FakeAuthSessionRepository()
        ..restoreHandler = () async => throw StateError('missing release URL');
      final fixture = _fixture(repository, now);
      addTearDown(fixture.dispose);

      await _flush();

      expect(
        fixture.container.read(authControllerProvider),
        isA<AuthConfigurationFailed>(),
      );
    },
  );

  test('normalizes phone numbers and validates localized inputs', () async {
    String? requestedPhoneNumber;
    final repository = _FakeAuthSessionRepository()
      ..challengeHandler = (phoneNumber) async {
        requestedPhoneNumber = phoneNumber;
        return _challenge(now);
      };
    final fixture = _fixture(repository, now);
    addTearDown(fixture.dispose);
    await _flush();

    final controller = fixture.container.read(authControllerProvider.notifier);
    expect(
      await controller.requestOtp('13812345678'),
      AuthActionResult.applied,
    );
    var state = fixture.container.read(authControllerProvider) as AuthSignedOut;
    expect(requestedPhoneNumber, '+8613812345678');
    expect(state.phoneNumber, '+8613812345678');

    controller.editPhoneNumber();
    expect(
      await controller.requestOtp('+971501234567'),
      AuthActionResult.applied,
    );
    expect(requestedPhoneNumber, '+971501234567');
    expect(repository.challengeCalls, 2);

    expect(await controller.verifyOtp('12ab'), AuthActionResult.failed);
    state = fixture.container.read(authControllerProvider) as AuthSignedOut;
    expect(state.errorMessage, '请输入6位验证码');
    expect(repository.verifyCalls, 0);

    controller.editPhoneNumber();
    expect(await controller.requestOtp('12345'), AuthActionResult.failed);
    state = fixture.container.read(authControllerProvider) as AuthSignedOut;
    expect(state.errorMessage, contains('请输入正确的手机号'));
    expect(repository.challengeCalls, 2);
  });

  test(
    'double tap is coalesced and editing the phone cancels late results',
    () async {
      final pending = Completer<OtpChallenge>();
      final repository = _FakeAuthSessionRepository()
        ..challengeHandler = (_) => pending.future;
      final fixture = _fixture(repository, now);
      addTearDown(fixture.dispose);
      await _flush();
      final controller = fixture.container.read(
        authControllerProvider.notifier,
      );

      final first = controller.requestOtp('+8613812345678');
      final repeated = await controller.requestOtp('+8613812345678');
      expect(repeated, AuthActionResult.ignored);
      expect(repository.challengeCalls, 1);

      controller.editPhoneNumber();
      expect(repository.cancelPendingCalls, 1);
      pending.complete(_challenge(now));
      expect(await first, AuthActionResult.ignored);
      final state =
          fixture.container.read(authControllerProvider) as AuthSignedOut;
      expect(state.isCodeEntry, isFalse);
      expect(state.phoneNumber, '+8613812345678');
    },
  );

  test(
    'resend countdown, expiry, and verify double tap are enforced',
    () async {
      var currentTime = now;
      final verification = Completer<AuthSession>();
      final repository = _FakeAuthSessionRepository()
        ..verifyHandler = (_, _) => verification.future;
      final fixture = _fixture(repository, now, clock: () => currentTime);
      addTearDown(fixture.dispose);
      await _flush();
      final controller = fixture.container.read(
        authControllerProvider.notifier,
      );

      await controller.requestOtp('+8613812345678');
      expect(await controller.resendOtp(), AuthActionResult.ignored);
      expect(repository.challengeCalls, 1);

      final first = controller.verifyOtp('123456');
      expect(await controller.verifyOtp('123456'), AuthActionResult.ignored);
      expect(repository.verifyCalls, 1);
      verification.complete(_session(_userA, now));
      expect(await first, AuthActionResult.applied);

      fixture.events.add(null);
      expect(
        fixture.container.read(authControllerProvider),
        isA<AuthSignedOut>(),
      );

      await controller.requestOtp('+8613812345678');
      currentTime = now.add(const Duration(minutes: 6));
      expect(await controller.verifyOtp('123456'), AuthActionResult.failed);
      expect(repository.verifyCalls, 1);
      final expired =
          fixture.container.read(authControllerProvider) as AuthSignedOut;
      expect(expired.errorMessage, contains('过期'));
    },
  );

  test(
    'logout failure still destroys the local authenticated session',
    () async {
      final repository = _FakeAuthSessionRepository();
      repository.restoreHandler = () async => _session(_userA, now);
      repository.logoutHandler = () async => throw const RemoteLogoutFailure();
      final notifications = _RecordingNotificationService();
      final fixture = _fixture(
        repository,
        now,
        notificationService: notifications,
      );
      addTearDown(fixture.dispose);
      await _flush();

      final result = await fixture.container
          .read(authControllerProvider.notifier)
          .logout();

      expect(result, AuthActionResult.failed);
      final state =
          fixture.container.read(authControllerProvider) as AuthSignedOut;
      expect(state.noticeMessage, contains('本机退出'));
      expect(repository.logoutCalls, 1);
      expect(notifications.cancelCalls, 1);
    },
  );

  test('local credential clear failure keeps the account retryable', () async {
    final repository = _FakeAuthSessionRepository();
    repository.restoreHandler = () async => _session(_userA, now);
    repository.logoutHandler = () async =>
        throw const LocalCredentialClearFailure();
    final notifications = _RecordingNotificationService();
    final fixture = _fixture(
      repository,
      now,
      notificationService: notifications,
    );
    addTearDown(fixture.dispose);
    await _flush();
    final controller = fixture.container.read(authControllerProvider.notifier);

    expect(await controller.logout(), AuthActionResult.failed);
    final retained =
        fixture.container.read(authControllerProvider) as AuthAuthenticated;
    expect(retained.isLoggingOut, isFalse);
    expect(retained.logoutErrorMessage, contains('仍保持登录'));
    expect(notifications.cancelCalls, 0);

    repository.logoutHandler = () async {};
    expect(await controller.logout(), AuthActionResult.applied);
    expect(
      fixture.container.read(authControllerProvider),
      isA<AuthSignedOut>(),
    );
    expect(repository.logoutCalls, 2);
    expect(notifications.cancelCalls, 1);
  });

  test(
    'notification cancellation failure never blocks explicit logout',
    () async {
      final repository = _FakeAuthSessionRepository()
        ..restoreHandler = () async => _session(_userA, now);
      final notifications = _RecordingNotificationService(throwOnCancel: true);
      final fixture = _fixture(
        repository,
        now,
        notificationService: notifications,
      );
      addTearDown(fixture.dispose);
      await _flush();

      final result = await fixture.container
          .read(authControllerProvider.notifier)
          .logout();

      expect(result, AuthActionResult.applied);
      expect(
        fixture.container.read(authControllerProvider),
        isA<AuthSignedOut>(),
      );
      expect(notifications.cancelCalls, 1);
    },
  );

  test(
    'credential invalidation signs out and cancels the global reminder',
    () async {
      final repository = _FakeAuthSessionRepository()
        ..restoreHandler = () async => _session(_userA, now);
      final notifications = _RecordingNotificationService(throwOnCancel: true);
      final fixture = _fixture(
        repository,
        now,
        notificationService: notifications,
      );
      addTearDown(fixture.dispose);
      await _flush();

      fixture.events.add(null);
      await _flush();

      expect(
        fixture.container.read(authControllerProvider),
        isA<AuthSignedOut>(),
      );
      expect(notifications.cancelCalls, 1);
    },
  );
}

_ControllerFixture _fixture(
  _FakeAuthSessionRepository repository,
  DateTime now, {
  DateTime Function()? clock,
  NotificationService notificationService = const NoopNotificationService(),
}) {
  final events = StreamController<void>.broadcast(sync: true);
  final container = ProviderContainer.test(
    overrides: [
      authSessionRepositoryProvider.overrideWithValue(repository),
      authSessionClearedEventsProvider.overrideWithValue(events.stream),
      authClockProvider.overrideWithValue(clock ?? () => now),
      notificationServiceProvider.overrideWithValue(notificationService),
    ],
  );
  final subscription = container.listen(
    authControllerProvider,
    (_, _) {},
    fireImmediately: true,
  );
  return _ControllerFixture(container, events, subscription);
}

final class _RecordingNotificationService implements NotificationService {
  _RecordingNotificationService({this.throwOnCancel = false});

  final bool throwOnCancel;
  int cancelCalls = 0;

  @override
  Future<void> cancelFastingReminder() async {
    cancelCalls++;
    if (throwOnCancel) {
      throw StateError('notification plugin unavailable');
    }
  }

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

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

OtpChallenge _challenge(DateTime now) => OtpChallenge(
  id: '0190a123-4567-7890-8123-456789abcdef',
  expiresAtUtc: now.add(const Duration(minutes: 5)),
  resendAfter: const Duration(seconds: 30),
);

AuthSession _session(String userId, DateTime now) => AuthSession(
  userId: userId,
  nickname: '测试用户',
  userVersion: 1,
  tokens: AuthTokens(
    accessToken: 'access-token',
    accessTokenExpiresAt: now.add(const Duration(hours: 1)),
    refreshToken: _refreshToken,
    refreshTokenExpiresAt: now.add(const Duration(days: 30)),
    tokenType: 'Bearer',
  ),
);

DioException _dioError(DioExceptionType type) {
  final request = RequestOptions(path: '/auth');
  return DioException(requestOptions: request, type: type);
}

final class _ControllerFixture {
  const _ControllerFixture(this.container, this.events, this.subscription);

  final ProviderContainer container;
  final StreamController<void> events;
  final ProviderSubscription<AuthViewState> subscription;

  void dispose() {
    subscription.close();
    container.dispose();
    events.close();
  }
}

final class _FakeAuthSessionRepository implements AuthSessionRepository {
  _FakeAuthSessionRepository() {
    restoreHandler = () async => null;
    challengeHandler = (_) async => _challenge(DateTime.utc(2026, 7, 20, 12));
    verifyHandler = (_, _) async =>
        _session(_userA, DateTime.utc(2026, 7, 20, 12));
    logoutHandler = () async {};
  }

  late Future<AuthSession?> Function() restoreHandler;
  late Future<OtpChallenge> Function(String) challengeHandler;
  late Future<AuthSession> Function(String, String) verifyHandler;
  late Future<void> Function() logoutHandler;
  int restoreCalls = 0;
  int challengeCalls = 0;
  int verifyCalls = 0;
  int logoutCalls = 0;
  int cancelPendingCalls = 0;

  @override
  void cancelPendingAuthentication() => cancelPendingCalls++;

  @override
  Future<void> logout() {
    logoutCalls++;
    return logoutHandler();
  }

  @override
  Future<OtpChallenge> requestOtpChallenge(String phoneNumber) {
    challengeCalls++;
    return challengeHandler(phoneNumber);
  }

  @override
  Future<AuthSession?> restoreSession() {
    restoreCalls++;
    return restoreHandler();
  }

  @override
  Future<AuthSession?> refreshSession() => restoreSession();

  @override
  Future<AuthSession> verifyOtp({
    required String challengeId,
    required String code,
  }) {
    verifyCalls++;
    return verifyHandler(challengeId, code);
  }
}
