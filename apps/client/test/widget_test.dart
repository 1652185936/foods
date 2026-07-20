import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foods_client/app/foods_app.dart';
import 'package:foods_client/app/router/app_router.dart';

void main() {
  testWidgets('mobile shell opens and safely dismisses recognition', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = createAppRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(child: FoodsApp(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recognition-sheet')), findsNothing);

    final navigationBarFinder = find.byType(NavigationBar);
    expect(navigationBarFinder, findsOneWidget);
    final navigationBar = tester.widget<NavigationBar>(navigationBarFinder);
    expect(navigationBar.destinations, hasLength(4));
    expect(
      navigationBar.destinations.whereType<NavigationDestination>().map(
        (destination) => destination.label,
      ),
      orderedEquals(const ['吃什么', '记录', '断食', '我的']),
    );
    expect(find.text('好友'), findsNothing);

    await tester.tap(find.byKey(const Key('nav-meals')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('open-recognition')), findsOneWidget);

    await tester.tap(find.byKey(const Key('open-recognition')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recognition-sheet')), findsOneWidget);

    await tester.tap(find.byKey(const Key('recognition-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recognition-sheet')), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('recognition-sheet')), findsNothing);
    expect(find.byKey(const ValueKey('result')), findsNothing);
  });

  testWidgets('wide shell uses a navigation rail', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = createAppRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(child: FoodsApp(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
