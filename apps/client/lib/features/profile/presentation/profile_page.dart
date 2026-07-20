import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/sync/sync_coordinator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../fasting/application/fasting_controller.dart';
import '../../fasting/domain/fasting_session.dart';
import '../../meals/application/meals_controller.dart';
import '../../meals/domain/meal_log.dart';
import '../application/account_privacy_controller.dart';
import '../application/preferences_controller.dart';
import '../domain/app_preferences.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesProvider);
    final mealStatistics = ref.watch(mealStatisticsProvider);
    final fastingStatistics = ref.watch(fastingStatisticsProvider);
    final isSaving = ref.watch(preferencesMutationProvider);
    final notificationAvailability = ref.watch(
      notificationAvailabilityProvider,
    );
    final currentPreferences = preferences.asData?.value;
    final auth = ref.watch(currentAuthSessionProvider);
    final syncState = auth == null ? null : ref.watch(syncCoordinatorProvider);
    final privacyState = auth == null
        ? const AccountPrivacyState()
        : ref.watch(accountPrivacyControllerProvider);

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.pageMaxWidth),
          child: CustomScrollView(
            key: const PageStorageKey('profile-page-scroll'),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    '我的',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: _ProfileSummary(
                    mealStatistics: mealStatistics.asData?.value,
                    fastingStatistics: fastingStatistics.asData?.value,
                    preferences: currentPreferences,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    '健康目标',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _ProfileInfoRow(
                          icon: LucideIcons.target,
                          label: '每日营养目标',
                          value: currentPreferences == null
                              ? '--'
                              : '${currentPreferences.dailyEnergyTargetKcal} kcal',
                        ),
                        const Divider(height: 1),
                        _ProfileInfoRow(
                          icon: LucideIcons.timer,
                          label: '默认断食计划',
                          value:
                              currentPreferences?.selectedFastingPlan.label ??
                              '--',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    '应用设置',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, auth == null ? 36 : 12),
                sliver: SliverToBoxAdapter(
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: preferences.when(
                      data: (value) => SwitchListTile(
                        key: const Key('fasting-reminder-switch'),
                        secondary: const Icon(
                          LucideIcons.bell,
                          color: AppColors.green,
                        ),
                        title: const Text('断食提醒偏好'),
                        subtitle: Text(
                          _notificationStatusText(
                            value.fastingReminderEnabled,
                            notificationAvailability,
                          ),
                          key: const Key('fasting-reminder-status'),
                        ),
                        value:
                            value.fastingReminderEnabled &&
                            notificationAvailability.asData?.value ==
                                NotificationAvailability.enabled,
                        onChanged: isSaving
                            ? null
                            : (enabled) async {
                                final result = await ref
                                    .read(preferencesMutationProvider.notifier)
                                    .setFastingReminder(enabled);
                                if (!context.mounted) {
                                  return;
                                }
                                final message = switch (result) {
                                  PreferencesMutationResult.permissionDenied =>
                                    '未获得系统通知权限，请在系统设置中允许通知',
                                  PreferencesMutationResult
                                      .notificationUnavailable =>
                                    '通知服务暂时不可用，请稍后重试',
                                  PreferencesMutationResult.failed =>
                                    '设置保存失败，请重试',
                                  PreferencesMutationResult.applied ||
                                  PreferencesMutationResult.ignored => null,
                                };
                                if (message != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(message)),
                                  );
                                }
                              },
                      ),
                      loading: () => const SizedBox(
                        height: 64,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (_, _) => ListTile(
                        leading: const Icon(LucideIcons.circleAlert),
                        title: const Text('设置加载失败'),
                        trailing: IconButton(
                          tooltip: '重试',
                          onPressed: () => ref.invalidate(preferencesProvider),
                          icon: const Icon(LucideIcons.refreshCw),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (auth != null) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      '账号',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
                  sliver: SliverToBoxAdapter(
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          _SyncStatusTile(
                            state: syncState!,
                            onRetry: () => ref
                                .read(syncCoordinatorProvider.notifier)
                                .retry(),
                          ),
                          const Divider(height: 1),
                          Builder(
                            builder: (tileContext) => ListTile(
                              key: const Key('profile-export-data'),
                              minTileHeight: 64,
                              leading: const Icon(
                                LucideIcons.fileDown,
                                color: AppColors.green,
                              ),
                              title: const Text('导出我的数据'),
                              subtitle: Text(
                                _exportStatusText(privacyState),
                                key: const Key('profile-export-status'),
                              ),
                              trailing: privacyState.isExporting
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      LucideIcons.chevronRight,
                                      size: 20,
                                    ),
                              enabled:
                                  !privacyState.isBusy && !auth.isLoggingOut,
                              onTap: privacyState.isBusy || auth.isLoggingOut
                                  ? null
                                  : () => _exportData(tileContext, ref),
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            key: const Key('profile-delete-account'),
                            minTileHeight: 64,
                            leading: const Icon(
                              LucideIcons.userRoundX,
                              color: AppColors.tomato,
                            ),
                            title: const Text('删除账号'),
                            subtitle: const Text('永久删除云端和本机的账号数据'),
                            trailing: privacyState.isDeleting
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    LucideIcons.chevronRight,
                                    size: 20,
                                  ),
                            enabled: !privacyState.isBusy && !auth.isLoggingOut,
                            onTap: privacyState.isBusy || auth.isLoggingOut
                                ? null
                                : () => _confirmAccountDeletion(context, ref),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            key: const Key('profile-logout'),
                            minTileHeight: 64,
                            leading: const Icon(
                              LucideIcons.logOut,
                              color: AppColors.tomato,
                            ),
                            title: const Text('退出登录'),
                            subtitle: Text(
                              key: auth.logoutErrorMessage == null
                                  ? null
                                  : const Key('profile-logout-error'),
                              auth.logoutErrorMessage ??
                                  auth.session.nickname ??
                                  '当前账号',
                              style: auth.logoutErrorMessage == null
                                  ? null
                                  : TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                            ),
                            trailing: auth.isLoggingOut
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    LucideIcons.chevronRight,
                                    size: 20,
                                  ),
                            enabled: !auth.isLoggingOut && !privacyState.isBusy,
                            onTap: auth.isLoggingOut || privacyState.isBusy
                                ? null
                                : () => _confirmLogout(context, ref),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _notificationStatusText(
    bool preferenceEnabled,
    AsyncValue<NotificationAvailability> availability,
  ) {
    if (!preferenceEnabled) {
      return '已关闭';
    }
    return switch (availability) {
      AsyncLoading() => '正在检查系统通知权限',
      AsyncError() => '通知服务暂时不可用',
      AsyncData(value: NotificationAvailability.enabled) => '断食结束时提醒我',
      AsyncData(value: NotificationAvailability.disabled) =>
        '系统通知权限已关闭，请在系统设置中允许通知',
      AsyncData(value: NotificationAvailability.unavailable) => '通知服务暂时不可用',
    };
  }

  static String _exportStatusText(AccountPrivacyState state) {
    if (state.isExporting) {
      return '正在准备安全导出文件';
    }
    return switch (state.exportFailure) {
      AccountExportFailure.tooLarge => '数据量过大，无法自动导出，请联系支持',
      AccountExportFailure.unavailable => '导出失败，请稍后重试',
      null => '生成 JSON 文件并打开系统分享面板',
    };
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    final renderObject = context.findRenderObject();
    final origin = renderObject is RenderBox && renderObject.hasSize
        ? renderObject.localToGlobal(Offset.zero) & renderObject.size
        : null;
    final result = await ref
        .read(accountPrivacyControllerProvider.notifier)
        .exportData(sharePositionOrigin: origin);
    if (!context.mounted) {
      return;
    }
    final message = switch (result) {
      AccountExportResult.applied => '数据文件已交给系统分享面板',
      AccountExportResult.tooLarge => '数据量过大，无法自动导出，请联系支持',
      AccountExportResult.failed => '导出失败，请稍后重试',
      AccountExportResult.ignored => null,
    };
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _confirmAccountDeletion(
    BuildContext context,
    WidgetRef ref,
  ) async {
    ref.read(accountPrivacyControllerProvider.notifier).clearFailures();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DeleteAccountDialog(),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认退出登录？'),
        content: const Text('退出后将停止使用当前账号，未同步的本地记录仍会按账号隔离保留。'),
        actions: [
          TextButton(
            key: const Key('logout-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            key: const Key('logout-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(LucideIcons.logOut, size: 18),
            label: const Text('退出登录'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }
}

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _confirmationController = TextEditingController();
  var _confirmation = '';

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final privacy = ref.watch(accountPrivacyControllerProvider);
    final confirmed = _confirmation == accountDeletionUserPhrase;
    final errorMessage = switch (privacy.deletionFailure) {
      AccountDeletionFailure.refreshFailed => '无法刷新登录凭据，账号和本机数据均未删除，请重试',
      AccountDeletionFailure.requestFailed => '删除请求失败，账号和本机数据均未删除，请重试',
      AccountDeletionFailure.localCredentialClearFailed =>
        '云端账号已删除，但本机登录凭据清除失败。当前界面仍保持登录，请重试本机清理',
      null => null,
    };

    return AlertDialog(
      scrollable: true,
      title: const Text('永久删除账号？'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('此操作会永久删除云端和本机的饮食、断食及识别数据，无法撤销。'),
            const SizedBox(height: 16),
            Text('请输入“$accountDeletionUserPhrase”以确认'),
            const SizedBox(height: 8),
            TextField(
              key: const Key('delete-account-confirmation-input'),
              controller: _confirmationController,
              enabled: !privacy.isDeleting,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onChanged: (value) => setState(() => _confirmation = value),
              onSubmitted: confirmed && !privacy.isDeleting
                  ? (_) => _deleteAccount()
                  : null,
              decoration: const InputDecoration(
                hintText: accountDeletionUserPhrase,
                border: OutlineInputBorder(),
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                errorMessage,
                key: const Key('delete-account-error'),
                style: const TextStyle(color: AppColors.tomato),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('delete-account-cancel'),
          onPressed: privacy.isDeleting
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          key: const Key('delete-account-confirm'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.tomato),
          onPressed: confirmed && !privacy.isBusy ? _deleteAccount : null,
          icon: privacy.isDeleting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(LucideIcons.trash2, size: 18),
          label: const Text('永久删除'),
        ),
      ],
    );
  }

  Future<void> _deleteAccount() async {
    final result = await ref
        .read(accountPrivacyControllerProvider.notifier)
        .deleteAccount(_confirmation);
    if (!mounted) {
      return;
    }
    if (result == AccountDeletionResult.invalidConfirmation) {
      setState(() {});
    }
  }
}

class _SyncStatusTile extends StatelessWidget {
  const _SyncStatusTile({required this.state, required this.onRetry});

  final AccountSyncState state;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final running = state.isRunning;
    return ListTile(
      key: const Key('profile-sync-status'),
      minTileHeight: 64,
      leading: Icon(_icon, color: _color, size: 21),
      title: const Text('数据同步'),
      subtitle: Text(_subtitle),
      trailing: running
          ? Semantics(
              label: '正在同步数据',
              child: const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : IconButton(
              key: const Key('profile-sync-retry'),
              tooltip: '立即同步',
              onPressed: onRetry,
              icon: const Icon(LucideIcons.refreshCw, size: 20),
            ),
    );
  }

  IconData get _icon => switch (state.phase) {
    AccountSyncPhase.idle => LucideIcons.cloud,
    AccountSyncPhase.running => LucideIcons.refreshCw,
    AccountSyncPhase.success => LucideIcons.cloudCheck,
    AccountSyncPhase.offline => LucideIcons.cloudOff,
    AccountSyncPhase.error => LucideIcons.circleAlert,
    AccountSyncPhase.conflict => LucideIcons.triangleAlert,
  };

  Color get _color => switch (state.phase) {
    AccountSyncPhase.success => AppColors.green,
    AccountSyncPhase.conflict || AccountSyncPhase.error => AppColors.tomato,
    _ => AppColors.muted,
  };

  String get _subtitle {
    final message = state.message ?? '等待同步';
    final lastSuccess = state.lastSuccessfulAtUtc;
    if (lastSuccess == null || state.phase == AccountSyncPhase.running) {
      return message;
    }
    final local = lastSuccess.toLocal();
    final date =
        '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)}';
    final time = '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
    return '$message · 最近成功 $date $time';
  }

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({
    required this.mealStatistics,
    required this.fastingStatistics,
    required this.preferences,
  });

  final MealStatistics? mealStatistics;
  final FastingStatistics? fastingStatistics;
  final AppPreferences? preferences;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox.square(
                  dimension: 58,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.greenSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.circleUserRound,
                      color: AppColors.primary,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '今天也好好吃饭',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preferences == null
                            ? '正在读取目标'
                            : '断食计划 ${preferences!.selectedFastingPlan.label}',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ProfileMetric(
                    value: _value(mealStatistics?.recordedDays),
                    label: '记录天数',
                  ),
                ),
                Expanded(
                  child: _ProfileMetric(
                    value: _value(mealStatistics?.mealCount),
                    label: '累计餐次',
                  ),
                ),
                Expanded(
                  child: _ProfileMetric(
                    value: _value(fastingStatistics?.completedCount),
                    label: '断食完成',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _value(int? value) => value?.toString() ?? '--';
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 56,
      leading: Icon(icon, color: AppColors.green, size: 21),
      title: Text(label),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 120),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            value,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
