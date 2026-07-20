import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:foods_client/app/foods_app.dart';
import 'package:foods_client/app/router/app_router.dart';

void main() {
  testWidgets('fasting page has no errors at 320x700 and 200% text', (
    tester,
  ) async {
    await _withAccessibilityApp(
      tester,
      initialLocation: '/fasting',
      body: (router) async {
        expect(find.text('轻断食'), findsOneWidget);
        _expectNoFlutterErrors(tester, screen: '断食页');
      },
    );
  });

  testWidgets('meals page has no errors at 320x700 and 200% text', (
    tester,
  ) async {
    await _withAccessibilityApp(
      tester,
      initialLocation: '/meals',
      body: (router) async {
        expect(find.text('今日记录'), findsOneWidget);
        _expectNoFlutterErrors(tester, screen: '记录页');
      },
    );
  });

  testWidgets('home recipe flow has no errors at 320x700 and 200% text', (
    tester,
  ) async {
    await _withAccessibilityApp(
      tester,
      initialLocation: '/eat',
      body: (router) async {
        await tester.tap(find.text('在家做'));
        await tester.pumpAndSettle();

        final openRecipe = find.byKey(const Key('open-recipe'));
        expect(openRecipe, findsOneWidget);
        await tester.ensureVisible(openRecipe);
        await tester.pumpAndSettle();
        _expectNoFlutterErrors(tester, screen: '在家做推荐页');

        await tester.tap(openRecipe);
        await tester.pumpAndSettle();

        expect(find.text('番茄炒蛋配米饭'), findsOneWidget);
        _expectNoFlutterErrors(tester, screen: '在家做菜谱详情');
      },
    );
  });
}

Future<void> _withAccessibilityApp(
  WidgetTester tester, {
  required String initialLocation,
  required Future<void> Function(GoRouter router) body,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 700);
  tester.platformDispatcher.textScaleFactorTestValue = 2;

  final router = createAppRouter();
  router.go(initialLocation);

  try {
    await tester.pumpWidget(
      ProviderScope(child: FoodsApp(routerConfig: router)),
    );
    await tester.pumpAndSettle();
    await body(router);
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    router.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  }
}

void _expectNoFlutterErrors(WidgetTester tester, {required String screen}) {
  final errors = <Object>[];
  Object? error;
  while ((error = tester.takeException()) != null) {
    errors.add(error!);
  }

  expect(
    errors,
    isEmpty,
    reason:
        '$screen 在 320x700、200% 字号下出现 FlutterError 或布局溢出：\n'
        '${errors.join('\n\n')}',
  );
}
