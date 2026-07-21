import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/core/auth/auth_controller.dart';
import 'package:foods_client/core/auth/auth_models.dart';
import 'package:foods_client/core/auth/auth_providers.dart';
import 'package:foods_client/features/auth/presentation/auth_session_gate.dart';

import '../../support/auth_test_support.dart';

void main() {
  final now = DateTime.utc(2026, 7, 20, 12);

  testWidgets('restore failure keeps credentials behind an explicit retry', (
    tester,
  ) async {
    var fail = true;
    final repository = FakeAuthSessionRepository(now)
      ..restoreHandler = () async {
        if (fail) {
          throw DioException(
            requestOptions: RequestOptions(path: '/users/me'),
            type: DioExceptionType.connectionError,
          );
        }
        return null;
      };
    final events = AuthEventFixture();
    addTearDown(events.dispose);

    await tester.pumpWidget(_authGate(repository, events, now));
    await tester.pumpAndSettle();

    expect(find.text('暂时无法确认登录状态'), findsOneWidget);
    expect(find.textContaining('凭据仍保留'), findsOneWidget);
    expect(find.text('登录好好吃饭'), findsNothing);

    fail = false;
    await tester.tap(find.byKey(const Key('auth-restore-retry')));
    await tester.pumpAndSettle();
    expect(find.text('登录好好吃饭'), findsOneWidget);
  });

  testWidgets(
    'phone and OTP flow supports busy cancellation without late login',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 700);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final verification = Completer<AuthSession>();
      String? requestedPhoneNumber;
      final repository = FakeAuthSessionRepository(now)
        ..challengeHandler = (phoneNumber) async {
          requestedPhoneNumber = phoneNumber;
          return authTestChallenge(now);
        }
        ..verifyHandler = (_, _) => verification.future;
      final events = AuthEventFixture();
      addTearDown(events.dispose);

      await tester.pumpWidget(_authGate(repository, events, now));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('auth-phone-input')),
        '13812345678',
      );
      await tester.ensureVisible(find.byKey(const Key('auth-request-code')));
      await tester.tap(find.byKey(const Key('auth-request-code')));
      await tester.pumpAndSettle();
      expect(find.text('输入验证码'), findsOneWidget);
      expect(find.textContaining('30s 后重发'), findsOneWidget);
      expect(requestedPhoneNumber, '+8613812345678');

      await tester.enterText(
        find.byKey(const Key('auth-code-input')),
        '123456',
      );
      await tester.ensureVisible(find.byKey(const Key('auth-verify-code')));
      await tester.tap(find.byKey(const Key('auth-verify-code')));
      await tester.pump();
      expect(repository.verifyCalls, 1);

      await tester.ensureVisible(find.byKey(const Key('auth-edit-phone')));
      await tester.tap(find.byKey(const Key('auth-edit-phone')));
      await tester.pump();
      expect(find.text('登录好好吃饭'), findsOneWidget);
      verification.complete(authTestSession(authTestUserA, now));
      await tester.pumpAndSettle();
      expect(find.text('登录好好吃饭'), findsOneWidget);

      final errors = <Object>[];
      Object? error;
      while ((error = tester.takeException()) != null) {
        errors.add(error!);
      }
      expect(errors, isEmpty);
    },
  );
}

Widget _authGate(
  FakeAuthSessionRepository repository,
  AuthEventFixture events,
  DateTime now,
) {
  return ProviderScope(
    overrides: [
      authSessionRepositoryProvider.overrideWithValue(repository),
      authSessionClearedEventsProvider.overrideWithValue(events.events.stream),
      authClockProvider.overrideWithValue(() => now),
    ],
    child: const AuthSessionGate(),
  );
}
