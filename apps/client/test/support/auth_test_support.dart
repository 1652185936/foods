import 'dart:async';

import 'package:foods_client/core/auth/auth_models.dart';
import 'package:foods_client/core/auth/auth_repository.dart';
import 'package:foods_client/core/network/auth_tokens.dart';

const testUserAId = '0190a123-4567-7891-8123-456789abcdef';
const testUserBId = '0190a123-4567-7892-8123-456789abcdef';
const authTestUserA = testUserAId;
const authTestUserB = testUserBId;
const _refreshToken = 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr';

OtpChallenge authTestChallenge(DateTime now) => OtpChallenge(
  id: '0190a123-4567-7890-8123-456789abcdef',
  expiresAtUtc: now.add(const Duration(minutes: 5)),
  resendAfter: const Duration(seconds: 30),
);

AuthSession authTestSession(String userId, DateTime now) => AuthSession(
  userId: userId,
  nickname: userId == authTestUserA ? '用户 A' : '用户 B',
  userVersion: 1,
  tokens: AuthTokens(
    accessToken: 'access-$userId',
    accessTokenExpiresAt: now.add(const Duration(hours: 1)),
    refreshToken: _refreshToken,
    refreshTokenExpiresAt: now.add(const Duration(days: 30)),
    tokenType: 'Bearer',
  ),
);

final class FakeAuthSessionRepository implements AuthSessionRepository {
  FakeAuthSessionRepository(DateTime now) {
    restoreHandler = () async => null;
    challengeHandler = (_) async => authTestChallenge(now);
    verifyHandler = (_, _) async => authTestSession(authTestUserA, now);
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

  @override
  void cancelPendingAuthentication() {}

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

final class AuthEventFixture {
  AuthEventFixture() : events = StreamController<void>.broadcast(sync: true);

  final StreamController<void> events;

  Future<void> dispose() => events.close();
}
