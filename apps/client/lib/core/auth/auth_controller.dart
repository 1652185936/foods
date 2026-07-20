import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database_provider.dart';
import 'auth_models.dart';
import 'auth_providers.dart';
import 'auth_repository.dart';

final authClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final authControllerProvider = NotifierProvider<AuthController, AuthViewState>(
  AuthController.new,
  dependencies: [
    authSessionRepositoryProvider,
    authSessionClearedEventsProvider,
    authClockProvider,
    notificationServiceProvider,
  ],
);

final currentAuthSessionProvider = Provider<AuthAuthenticated?>(
  (ref) => null,
  dependencies: const [],
);

sealed class AuthViewState {
  const AuthViewState();
}

final class AuthRestoring extends AuthViewState {
  const AuthRestoring();
}

final class AuthRestoreFailed extends AuthViewState {
  const AuthRestoreFailed({required this.message});

  final String message;
}

final class AuthConfigurationFailed extends AuthViewState {
  const AuthConfigurationFailed();
}

final class AuthSignedOut extends AuthViewState {
  const AuthSignedOut({
    this.phoneNumber = '',
    this.challenge,
    this.resendAvailableAtUtc,
    this.busy = false,
    this.errorMessage,
    this.noticeMessage,
  });

  final String phoneNumber;
  final OtpChallenge? challenge;
  final DateTime? resendAvailableAtUtc;
  final bool busy;
  final String? errorMessage;
  final String? noticeMessage;

  bool get isCodeEntry => challenge != null;

  bool isChallengeExpired(DateTime now) =>
      challenge != null && !challenge!.expiresAtUtc.isAfter(now.toUtc());

  int resendSecondsRemaining(DateTime now) {
    final availableAt = resendAvailableAtUtc;
    if (availableAt == null || !availableAt.isAfter(now.toUtc())) {
      return 0;
    }
    return (availableAt.difference(now.toUtc()).inMilliseconds / 1000).ceil();
  }
}

final class AuthAuthenticated extends AuthViewState {
  const AuthAuthenticated({
    required this.session,
    required this.scopeGeneration,
    this.isLoggingOut = false,
    this.logoutErrorMessage,
  });

  final AuthSession session;
  final int scopeGeneration;
  final bool isLoggingOut;
  final String? logoutErrorMessage;
}

enum AuthActionResult { applied, ignored, failed }

final class AuthController extends Notifier<AuthViewState> {
  static final _e164 = RegExp(r'^\+[1-9][0-9]{7,14}$');
  static final _otp = RegExp(r'^[0-9]{6}$');

  StreamSubscription<void>? _clearedSubscription;
  var _operationEpoch = 0;
  var _scopeGeneration = 0;
  var _disposed = false;
  var _logoutInProgress = false;

  AuthSessionRepository get _repository =>
      ref.read(authSessionRepositoryProvider);

  DateTime get _now => ref.read(authClockProvider)().toUtc();

  @override
  AuthViewState build() {
    _clearedSubscription = ref
        .watch(authSessionClearedEventsProvider)
        .listen((_) => _handleCredentialsCleared());
    ref.onDispose(() {
      _disposed = true;
      _operationEpoch++;
      unawaited(_clearedSubscription?.cancel());
    });
    scheduleMicrotask(_restoreSession);
    return const AuthRestoring();
  }

  Future<void> retryRestore() async {
    if (state is AuthRestoring) {
      return;
    }
    state = const AuthRestoring();
    await _restoreSession();
  }

  Future<AuthActionResult> requestOtp(String phoneNumber) {
    final current = state;
    if (current is! AuthSignedOut || current.busy) {
      return Future.value(AuthActionResult.ignored);
    }
    if (!_e164.hasMatch(phoneNumber)) {
      state = AuthSignedOut(
        phoneNumber: phoneNumber,
        errorMessage: '请输入含国家/地区码的手机号（如 +8613812345678）',
        noticeMessage: current.noticeMessage,
      );
      return Future.value(AuthActionResult.failed);
    }
    return _requestOtp(
      phoneNumber: phoneNumber,
      previous: AuthSignedOut(
        phoneNumber: phoneNumber,
        noticeMessage: current.noticeMessage,
      ),
    );
  }

  Future<AuthActionResult> resendOtp() {
    final current = state;
    if (current is! AuthSignedOut ||
        !current.isCodeEntry ||
        current.busy ||
        (!current.isChallengeExpired(_now) &&
            current.resendSecondsRemaining(_now) > 0)) {
      return Future.value(AuthActionResult.ignored);
    }
    return _requestOtp(phoneNumber: current.phoneNumber, previous: current);
  }

  void editPhoneNumber() {
    final current = state;
    if (current is! AuthSignedOut) {
      return;
    }
    _operationEpoch++;
    _repository.cancelPendingAuthentication();
    state = AuthSignedOut(
      phoneNumber: current.phoneNumber,
      noticeMessage: current.noticeMessage,
    );
  }

  Future<AuthActionResult> verifyOtp(String code) async {
    final current = state;
    if (current is! AuthSignedOut || !current.isCodeEntry || current.busy) {
      return AuthActionResult.ignored;
    }
    if (!_otp.hasMatch(code)) {
      state = AuthSignedOut(
        phoneNumber: current.phoneNumber,
        challenge: current.challenge,
        resendAvailableAtUtc: current.resendAvailableAtUtc,
        errorMessage: '请输入6位验证码',
      );
      return AuthActionResult.failed;
    }
    if (current.isChallengeExpired(_now)) {
      state = AuthSignedOut(
        phoneNumber: current.phoneNumber,
        challenge: current.challenge,
        resendAvailableAtUtc: current.resendAvailableAtUtc,
        errorMessage: '验证码已过期，请重新获取',
      );
      return AuthActionResult.failed;
    }

    final operation = ++_operationEpoch;
    state = AuthSignedOut(
      phoneNumber: current.phoneNumber,
      challenge: current.challenge,
      resendAvailableAtUtc: current.resendAvailableAtUtc,
      busy: true,
    );
    try {
      final session = await _repository.verifyOtp(
        challengeId: current.challenge!.id,
        code: code,
      );
      if (!_isCurrent(operation)) {
        return AuthActionResult.ignored;
      }
      _scopeGeneration++;
      state = AuthAuthenticated(
        session: session,
        scopeGeneration: _scopeGeneration,
      );
      return AuthActionResult.applied;
    } catch (error) {
      if (_isCurrent(operation)) {
        state = AuthSignedOut(
          phoneNumber: current.phoneNumber,
          challenge: current.challenge,
          resendAvailableAtUtc: current.resendAvailableAtUtc,
          errorMessage: _actionError(error, verification: true),
        );
      }
      return AuthActionResult.failed;
    }
  }

  Future<AuthActionResult> logout() async {
    final current = state;
    if (current is! AuthAuthenticated || current.isLoggingOut) {
      return AuthActionResult.ignored;
    }
    _operationEpoch++;
    _logoutInProgress = true;
    state = AuthAuthenticated(
      session: current.session,
      scopeGeneration: current.scopeGeneration,
      isLoggingOut: true,
    );
    var remoteFailed = false;
    try {
      await _repository.logout();
    } on RemoteLogoutFailure {
      remoteFailed = true;
    } catch (_) {
      _logoutInProgress = false;
      if (!_disposed) {
        state = AuthAuthenticated(
          session: current.session,
          scopeGeneration: current.scopeGeneration,
          logoutErrorMessage: '无法清除本机登录凭据，当前账号仍保持登录。请重试退出。',
        );
      }
      return AuthActionResult.failed;
    }
    await _cancelReminderBestEffort();
    _logoutInProgress = false;
    if (!_disposed) {
      state = AuthSignedOut(
        noticeMessage: remoteFailed ? '已在本机退出，服务器暂时未响应' : '已安全退出当前账号',
      );
    }
    return remoteFailed ? AuthActionResult.failed : AuthActionResult.applied;
  }

  void completeAccountDeletion() {
    if (_disposed) {
      return;
    }
    _operationEpoch++;
    _logoutInProgress = false;
    state = const AuthSignedOut(noticeMessage: '账号已删除');
  }

  Future<void> _restoreSession() async {
    final operation = ++_operationEpoch;
    try {
      final session = await _repository.restoreSession();
      if (!_isCurrent(operation)) {
        return;
      }
      if (session == null) {
        await _cancelReminderBestEffort();
        state = const AuthSignedOut();
        return;
      }
      _scopeGeneration++;
      state = AuthAuthenticated(
        session: session,
        scopeGeneration: _scopeGeneration,
      );
    } on StateError {
      if (_isCurrent(operation)) {
        state = const AuthConfigurationFailed();
      }
    } on ArgumentError {
      if (_isCurrent(operation)) {
        state = const AuthConfigurationFailed();
      }
    } on UnsupportedError {
      if (_isCurrent(operation)) {
        state = const AuthConfigurationFailed();
      }
    } catch (_) {
      if (_isCurrent(operation)) {
        state = const AuthRestoreFailed(message: '网络暂时不可用，登录凭据仍保留在本机');
      }
    }
  }

  Future<AuthActionResult> _requestOtp({
    required String phoneNumber,
    required AuthSignedOut previous,
  }) async {
    final operation = ++_operationEpoch;
    state = AuthSignedOut(
      phoneNumber: phoneNumber,
      challenge: previous.challenge,
      resendAvailableAtUtc: previous.resendAvailableAtUtc,
      busy: true,
      noticeMessage: previous.noticeMessage,
    );
    try {
      final challenge = await _repository.requestOtpChallenge(phoneNumber);
      if (!_isCurrent(operation)) {
        return AuthActionResult.ignored;
      }
      state = AuthSignedOut(
        phoneNumber: phoneNumber,
        challenge: challenge,
        resendAvailableAtUtc: _now.add(challenge.resendAfter),
      );
      return AuthActionResult.applied;
    } catch (error) {
      if (_isCurrent(operation)) {
        state = AuthSignedOut(
          phoneNumber: phoneNumber,
          challenge: previous.challenge,
          resendAvailableAtUtc: previous.resendAvailableAtUtc,
          errorMessage: _actionError(error),
          noticeMessage: previous.noticeMessage,
        );
      }
      return AuthActionResult.failed;
    }
  }

  void _handleCredentialsCleared() {
    if (_disposed || _logoutInProgress || state is AuthSignedOut) {
      return;
    }
    _operationEpoch++;
    state = const AuthSignedOut();
    unawaited(_cancelReminderBestEffort());
  }

  Future<void> _cancelReminderBestEffort() async {
    try {
      await ref.read(notificationServiceProvider).cancelFastingReminder();
    } catch (_) {
      // Authentication state must still be cleared if the platform plugin is
      // unavailable. The next signed-out restore will retry this cancellation.
    }
  }

  bool _isCurrent(int operation) => !_disposed && operation == _operationEpoch;

  static String _actionError(Object error, {bool verification = false}) {
    if (error is FormatException) {
      return verification ? '暂时无法完成登录，请重试' : '暂时无法发送验证码，请重试';
    }
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 429) {
        return '操作过于频繁，请稍后再试';
      }
      if (verification && (status == 401 || status == 422)) {
        return '验证码不正确或已失效';
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.connectionError) {
        return '网络暂时不可用，请检查连接后重试';
      }
    }
    return verification ? '暂时无法完成登录，请重试' : '暂时无法发送验证码，请重试';
  }
}
