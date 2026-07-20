import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/foods_app.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/bootstrap/app_lifecycle_coordinator.dart';
import '../../../core/db/account_scope.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../meals/recognition/recognition_lost_data_recovery_host.dart';
import 'login_page.dart';

class AuthSessionGate extends ConsumerWidget {
  const AuthSessionGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (auth case AuthAuthenticated()) {
      return AuthenticatedAccountScope(
        key: ValueKey('account:${auth.session.userId}:${auth.scopeGeneration}'),
        auth: auth,
      );
    }

    return MaterialApp(
      title: '好好吃饭',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: switch (auth) {
        AuthRestoring() => const _RestoreProgress(),
        AuthRestoreFailed() => _RestoreFailure(
          message: auth.message,
          onRetry: () =>
              ref.read(authControllerProvider.notifier).retryRestore(),
        ),
        AuthConfigurationFailed() => const _ConfigurationFailure(),
        AuthSignedOut() => const LoginPage(),
        AuthAuthenticated() => const SizedBox.shrink(),
      },
    );
  }
}

class _ConfigurationFailure extends StatelessWidget {
  const _ConfigurationFailure();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.settings2, size: 38),
                  const SizedBox(height: 16),
                  Text(
                    '应用服务配置不完整',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '当前版本无法安全连接服务，请安装配置完整的版本。',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthenticatedAccountScope extends StatelessWidget {
  const AuthenticatedAccountScope({required this.auth, this.child, super.key});

  final AuthAuthenticated auth;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        accountScopeProvider.overrideWithValue(
          AccountScope.authenticated(auth.session.userId),
        ),
        currentAuthSessionProvider.overrideWithValue(auth),
      ],
      child:
          child ??
          const RecognitionLostDataRecoveryHost(
            child: AppLifecycleCoordinator(child: FoodsApp()),
          ),
    );
  }
}

class _RestoreProgress extends StatelessWidget {
  const _RestoreProgress();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Semantics(
            liveRegion: true,
            label: '正在恢复登录状态',
            child: const CircularProgressIndicator(),
          ),
        ),
      ),
    );
  }
}

class _RestoreFailure extends StatelessWidget {
  const _RestoreFailure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.cloudOff, size: 38),
                  const SizedBox(height: 16),
                  Text(
                    '暂时无法确认登录状态',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const Key('auth-restore-retry'),
                    onPressed: onRetry,
                    icon: const Icon(LucideIcons.refreshCw, size: 19),
                    label: const Text('重试'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
