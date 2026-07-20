import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import 'router/app_router.dart';

class FoodsApp extends ConsumerWidget {
  const FoodsApp({super.key, this.routerConfig});

  final GoRouter? routerConfig;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: '好好吃饭',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: routerConfig ?? ref.watch(appRouterProvider),
    );
  }
}
