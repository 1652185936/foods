import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/core/auth/auth_controller.dart';
import 'package:foods_client/core/auth/auth_providers.dart';
import 'package:foods_client/core/db/account_scope.dart';
import 'package:foods_client/core/db/database_provider.dart';
import 'package:foods_client/features/profile/presentation/profile_page.dart';

import '../../support/auth_test_support.dart';
import '../../support/test_dependencies.dart';

void main() {
  final now = DateTime.utc(2026, 7, 20, 12);

  testWidgets('logout requires explicit confirmation', (tester) async {
    final repository = FakeAuthSessionRepository(now)
      ..restoreHandler = () async => authTestSession(authTestUserA, now);
    final events = AuthEventFixture();
    addTearDown(events.dispose);
    final auth = AuthAuthenticated(
      session: authTestSession(authTestUserA, now),
      scopeGeneration: 1,
    );

    await tester.pumpWidget(
      testProviderScope(
        child: ProviderScope(
          overrides: [
            authSessionRepositoryProvider.overrideWithValue(repository),
            authSessionClearedEventsProvider.overrideWithValue(
              events.events.stream,
            ),
            authClockProvider.overrideWithValue(() => now),
            accountScopeProvider.overrideWithValue(
              AccountScope.authenticated(authTestUserA),
            ),
            currentAuthSessionProvider.overrideWithValue(auth),
          ],
          child: const MaterialApp(home: _ProfileHarness()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-logout')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -160));
    await tester.pump();
    await tester.tap(find.byKey(const Key('profile-logout')));
    await tester.pumpAndSettle();
    expect(find.text('确认退出登录？'), findsOneWidget);
    expect(find.byKey(const Key('logout-confirm')), findsOneWidget);

    await tester.tap(find.byKey(const Key('logout-cancel')));
    await tester.pumpAndSettle();
    expect(repository.logoutCalls, 0);

    await tester.tap(find.byKey(const Key('profile-logout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logout-confirm')));
    await tester.pumpAndSettle();
    expect(repository.logoutCalls, 1);
  });

  testWidgets('local credential clear failure stays visible and retryable', (
    tester,
  ) async {
    final repository = FakeAuthSessionRepository(now)
      ..restoreHandler = () async => authTestSession(authTestUserA, now);
    final events = AuthEventFixture();
    addTearDown(events.dispose);
    const errorMessage = '无法清除本机登录凭据，当前账号仍保持登录。请重试退出。';
    final auth = AuthAuthenticated(
      session: authTestSession(authTestUserA, now),
      scopeGeneration: 1,
      logoutErrorMessage: errorMessage,
    );

    await tester.pumpWidget(
      testProviderScope(
        child: ProviderScope(
          overrides: [
            authSessionRepositoryProvider.overrideWithValue(repository),
            authSessionClearedEventsProvider.overrideWithValue(
              events.events.stream,
            ),
            authClockProvider.overrideWithValue(() => now),
            accountScopeProvider.overrideWithValue(
              AccountScope.authenticated(authTestUserA),
            ),
            currentAuthSessionProvider.overrideWithValue(auth),
          ],
          child: const MaterialApp(home: _ProfileHarness()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-logout')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('profile-logout-error')), findsOneWidget);
    expect(find.text(errorMessage), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -160));
    await tester.pump();
    await tester.tap(find.byKey(const Key('profile-logout')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('logout-confirm')), findsOneWidget);
  });
}

class _ProfileHarness extends ConsumerWidget {
  const _ProfileHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authControllerProvider);
    return const ProfilePage();
  }
}
