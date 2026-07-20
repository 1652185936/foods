import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foods_client/main.dart' as app;
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'real API login, meal sync, and account deletion complete end to end',
    (tester) async {
      app.main();

      final phoneInput = find.byKey(const Key('auth-phone-input'));
      await _waitFor(tester, phoneInput);
      final suffix = DateTime.now().millisecondsSinceEpoch
          .remainder(10000000)
          .toString()
          .padLeft(7, '0');
      await tester.enterText(phoneInput, '+97150$suffix');
      await tester.tap(find.byKey(const Key('auth-request-code')));

      final codeInput = find.byKey(const Key('auth-code-input'));
      await _waitFor(tester, codeInput);
      await tester.enterText(codeInput, '123456');
      await tester.tap(find.byKey(const Key('auth-verify-code')));

      final mealsNavigation = find.byKey(const Key('nav-meals'));
      await _waitFor(tester, mealsNavigation);
      await tester.tap(mealsNavigation);
      final manualMeal = find.byKey(const Key('open-manual-meal'));
      await _waitFor(tester, manualMeal);
      await tester.tap(manualMeal);

      final mealName = '发布验证餐-$suffix';
      await _waitFor(tester, find.byKey(const Key('manual-meal-name')));
      await tester.enterText(
        find.byKey(const Key('manual-meal-name')),
        mealName,
      );
      await tester.enterText(
        find.byKey(const Key('manual-meal-energy')),
        '520',
      );
      final saveMeal = find.byKey(const Key('manual-meal-save'));
      await tester.ensureVisible(saveMeal);
      await tester.tap(saveMeal);
      await _waitForAbsent(tester, find.byKey(const Key('manual-meal-save')));
      await _waitFor(tester, find.text(mealName));

      FocusManager.instance.primaryFocus?.unfocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await tester.pumpAndSettle();
      final profileNavigation = find.byKey(const Key('nav-profile'));
      await _waitFor(tester, profileNavigation.hitTestable());
      await tester.tap(profileNavigation.hitTestable());
      await _waitFor(tester, find.byKey(const Key('profile-sync-status')));
      await _waitFor(
        tester,
        find.textContaining('数据已同步'),
        timeout: const Duration(seconds: 45),
      );

      final deleteAccount = find.byKey(const Key('profile-delete-account'));
      await tester.ensureVisible(deleteAccount);
      await tester.drag(
        find.byKey(const PageStorageKey<String>('profile-page-scroll')),
        const Offset(0, -180),
      );
      await tester.pumpAndSettle();
      await _waitFor(tester, deleteAccount.hitTestable());
      await tester.tap(deleteAccount.hitTestable());
      final confirmation = find.byKey(
        const Key('delete-account-confirmation-input'),
      );
      await _waitFor(tester, confirmation);
      await tester.enterText(confirmation, '删除我的账号');
      final confirmDelete = find.byKey(const Key('delete-account-confirm'));
      FocusManager.instance.primaryFocus?.unfocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await tester.pumpAndSettle();
      await _waitFor(tester, confirmDelete.hitTestable());
      await tester.tap(confirmDelete.hitTestable());

      await _waitFor(
        tester,
        find.byKey(const Key('auth-phone-input')),
        timeout: const Duration(seconds: 45),
      );
      expect(find.text('账号已删除'), findsOneWidget);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(finder, findsWidgets);
}

Future<void> _waitForAbsent(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isNotEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(finder, findsNothing);
}
