import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/eat/presentation/eat_decision_page.dart';
import '../../features/eat/presentation/recipe_detail_page.dart';
import '../../features/fasting/presentation/fasting_page.dart';
import '../../features/meals/presentation/meals_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../shell/app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = createAppRouter();
  ref.onDispose(router.dispose);
  return router;
});

GoRouter createAppRouter() {
  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  final eatKey = GlobalKey<NavigatorState>(debugLabel: 'eat');
  final mealsKey = GlobalKey<NavigatorState>(debugLabel: 'meals');
  final fastingKey = GlobalKey<NavigatorState>(debugLabel: 'fasting');
  final profileKey = GlobalKey<NavigatorState>(debugLabel: 'profile');

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: '/eat',
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            navigatorKey: eatKey,
            routes: <RouteBase>[
              GoRoute(
                path: '/eat',
                builder: (context, state) => const EatDecisionPage(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'recipe/:id',
                    builder: (context, state) =>
                        RecipeDetailPage(recipeId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: mealsKey,
            routes: <RouteBase>[
              GoRoute(
                path: '/meals',
                builder: (context, state) => const MealsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: fastingKey,
            routes: <RouteBase>[
              GoRoute(
                path: '/fasting',
                builder: (context, state) => const FastingPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: profileKey,
            routes: <RouteBase>[
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
