import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../features/auth/presentation/auth_session_gate.dart';
import '../db/app_database.dart';
import '../db/database_connection.dart';
import '../db/database_provider.dart';
import '../security/database_key_store.dart';
import '../theme/app_theme.dart';
import '../time/device_time_zone.dart';

final secureValueStoreProvider = Provider<SecureValueStore>(
  (ref) => FlutterSecureValueStore(),
);

final databaseKeyStoreProvider = Provider<DatabaseKeyStore>((ref) {
  return DatabaseKeyStore(ref.watch(secureValueStoreProvider));
});

final appDatabaseOpenerProvider = Provider<AppDatabaseOpener>((ref) {
  return AppDatabaseOpener(ref.watch(databaseKeyStoreProvider));
});

final appBootstrapServiceProvider = Provider<AppBootstrapService>((ref) {
  return AppBootstrapService(
    ref.watch(appDatabaseOpenerProvider),
    ref.watch(deviceTimeZoneProvider),
  );
});

final appBootstrapProvider =
    AsyncNotifierProvider<AppBootstrapController, AppBootstrapDependencies>(
      AppBootstrapController.new,
    );

class AppBootstrapDependencies {
  const AppBootstrapDependencies({
    required this.database,
    required this.timeZoneId,
  });

  final AppDatabase database;
  final String timeZoneId;

  Future<void> dispose() => database.close();
}

class AppBootstrapService {
  const AppBootstrapService(this._databaseFactory, this._deviceTimeZone);

  final AppDatabaseFactory _databaseFactory;
  final DeviceTimeZone _deviceTimeZone;

  Future<void> resetLocalData() => _databaseFactory.reset();

  Future<AppBootstrapDependencies> initialize() async {
    final database = await _databaseFactory.open();
    try {
      final timeZoneId = await _deviceTimeZone.currentIdentifier();
      return AppBootstrapDependencies(
        database: database,
        timeZoneId: timeZoneId,
      );
    } catch (_) {
      await database.close();
      rethrow;
    }
  }
}

class AppBootstrapController extends AsyncNotifier<AppBootstrapDependencies> {
  @override
  Future<AppBootstrapDependencies> build() => _initialize();

  Future<void> retry() async {
    if (state.isLoading) {
      return;
    }
    state = const AsyncLoading<AppBootstrapDependencies>();
    state = await AsyncValue.guard(_initialize);
  }

  Future<void> resetLocalData() async {
    if (state.isLoading) {
      return;
    }
    state = const AsyncLoading<AppBootstrapDependencies>();
    try {
      await ref.read(appBootstrapServiceProvider).resetLocalData();
    } catch (error, stackTrace) {
      state = AsyncError<AppBootstrapDependencies>(error, stackTrace);
      return;
    }
    state = await AsyncValue.guard(_initialize);
  }

  Future<AppBootstrapDependencies> _initialize() async {
    final dependencies = await ref
        .read(appBootstrapServiceProvider)
        .initialize();
    ref.onDispose(() => unawaited(dependencies.dispose()));
    return dependencies;
  }
}

class AppBootstrapHost extends ConsumerWidget {
  const AppBootstrapHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(appBootstrapProvider);
    return bootstrap.when(
      data: (dependencies) => ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(dependencies.database),
          initialTimeZoneIdProvider.overrideWithValue(dependencies.timeZoneId),
        ],
        child: const AuthSessionGate(),
      ),
      loading: () => const _BootstrapMaterial(child: _BootstrapLoading()),
      error: (error, _) => _BootstrapMaterial(
        child: _BootstrapError(
          canResetLocalData:
              error is DatabaseKeyException ||
              error is UnreadableEncryptedDatabaseException,
          onRetry: () => ref.read(appBootstrapProvider.notifier).retry(),
          onResetLocalData: () =>
              ref.read(appBootstrapProvider.notifier).resetLocalData(),
        ),
      ),
    );
  }
}

class _BootstrapMaterial extends StatelessWidget {
  const _BootstrapMaterial({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(body: SafeArea(child: child)),
    );
  }
}

class _BootstrapLoading extends StatelessWidget {
  const _BootstrapLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        liveRegion: true,
        label: '正在打开本地数据',
        child: const CircularProgressIndicator(),
      ),
    );
  }
}

class _BootstrapError extends StatelessWidget {
  const _BootstrapError({
    required this.canResetLocalData,
    required this.onRetry,
    required this.onResetLocalData,
  });

  final bool canResetLocalData;
  final VoidCallback onRetry;
  final Future<void> Function() onResetLocalData;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.databaseZap, size: 34),
            const SizedBox(height: 14),
            Text('本地数据暂时无法打开', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('请重试。现有记录不会被自动清除。', textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const Key('bootstrap-retry'),
              onPressed: onRetry,
              icon: const Icon(LucideIcons.refreshCw, size: 19),
              label: const Text('重试'),
            ),
            if (canResetLocalData) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                key: const Key('bootstrap-reset-local-data'),
                onPressed: () => _confirmReset(context),
                icon: const Icon(LucideIcons.trash2, size: 18),
                label: const Text('重置本机数据'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('重置本机数据？'),
        content: const Text(
          '这会永久删除此设备上尚未同步的饮食和断食记录，并重新创建加密数据库。'
          '云端账号和已同步数据不会被删除。',
        ),
        actions: [
          TextButton(
            key: const Key('bootstrap-reset-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            key: const Key('bootstrap-reset-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(LucideIcons.trash2, size: 18),
            label: const Text('删除并重建'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await onResetLocalData();
    }
  }
}
