import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/time/time_zone_converter.dart';
import '../application/fasting_controller.dart';
import '../domain/fasting_plan.dart';
import '../domain/fasting_session.dart';

class FastingPage extends ConsumerStatefulWidget {
  const FastingPage({super.key});

  @override
  ConsumerState<FastingPage> createState() => _FastingPageState();
}

class _FastingPageState extends ConsumerState<FastingPage> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      final fasting = ref.read(fastingProvider).asData?.value;
      if (!mounted || fasting == null) {
        return;
      }
      final nowUtc = ref.read(appClockProvider).now().toUtc();
      final phase = fasting.phaseAt(nowUtc);
      if (phase == FastingPhase.fasting &&
          !fasting.activeSession!.targetEndAtUtc.isAfter(nowUtc)) {
        unawaited(ref.read(fastingProvider.notifier).completeIfNeeded());
      }
      if (phase != FastingPhase.idle && TickerMode.valuesOf(context).enabled) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final result = await ref.read(fastingProvider.notifier).start();
    if (mounted && result == FastingMutationResult.failed) {
      _showMessage('开始失败，请重试');
    }
  }

  Future<void> _stop() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('结束本次断食？'),
        content: const Text('本次会记录为未完成。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('继续断食'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('结束'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final result = await ref.read(fastingProvider.notifier).stop();
    if (mounted && result != FastingMutationResult.ignored) {
      _showMessage(
        result == FastingMutationResult.applied ? '本次断食已结束' : '结束失败，请重试',
      );
    }
  }

  Future<void> _selectPlan(FastingPlan plan) async {
    final result = await ref.read(fastingProvider.notifier).selectPlan(plan);
    if (mounted && result == FastingMutationResult.failed) {
      _showMessage('计划保存失败，请重试');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fastingProvider);
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.pageMaxWidth),
          child: state.when(
            data: (fasting) => _FastingContent(
              fasting: fasting,
              statistics: ref.watch(fastingStatisticsProvider),
              nowUtc: ref.watch(appClockProvider).now().toUtc(),
              timeZones: ref.watch(timeZoneConverterProvider),
              onSelectPlan: _selectPlan,
              onStart: _start,
              onStop: _stop,
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => _FastingLoadError(
              onRetry: () => ref.read(fastingProvider.notifier).retry(),
            ),
          ),
        ),
      ),
    );
  }
}

class _FastingContent extends StatelessWidget {
  const _FastingContent({
    required this.fasting,
    required this.statistics,
    required this.nowUtc,
    required this.timeZones,
    required this.onSelectPlan,
    required this.onStart,
    required this.onStop,
  });

  final FastingState fasting;
  final AsyncValue<FastingStatistics> statistics;
  final DateTime nowUtc;
  final TimeZoneConverter timeZones;
  final ValueChanged<FastingPlan> onSelectPlan;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final phase = fasting.phaseAt(nowUtc);
    final eatingSession = fasting.eatingSessionAt(nowUtc);
    final remaining = switch (phase) {
      FastingPhase.fasting => fasting.remainingAt(nowUtc),
      FastingPhase.eating => fasting.eatingWindowRemainingAt(nowUtc),
      FastingPhase.idle => fasting.plan.fastingDuration,
    };
    final totalSeconds = switch (phase) {
      FastingPhase.eating => eatingSession!.plan.eatingDuration.inSeconds,
      FastingPhase.fasting ||
      FastingPhase.idle => fasting.plan.fastingDuration.inSeconds,
    };
    final progress = phase == FastingPhase.idle
        ? 0.0
        : (1 - (remaining.inSeconds / totalSeconds)).clamp(0.0, 1.0).toDouble();
    final stats = statistics.when(
      data: (value) => value,
      loading: () => const FastingStatistics(),
      error: (_, _) => const FastingStatistics(),
    );
    final history = fasting.recentSessions
        .where((session) => session.status != FastingSessionStatus.active)
        .take(5)
        .toList(growable: false);

    return CustomScrollView(
      key: const PageStorageKey('fasting-page-scroll'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('轻断食', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text(switch (phase) {
                  FastingPhase.fasting => '本轮断食正在进行',
                  FastingPhase.eating => '当前处于进食窗口',
                  FastingPhase.idle => '选择适合今天的节奏',
                }, style: const TextStyle(color: AppColors.muted)),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          sliver: SliverToBoxAdapter(
            child: fasting.isActive
                ? _ActivePlanBanner(plan: fasting.plan)
                : SegmentedButton<FastingPlan>(
                    key: const Key('fasting-plan-selector'),
                    segments: FastingPlan.values
                        .map(
                          (plan) => ButtonSegment<FastingPlan>(
                            value: plan,
                            label: Text(plan.label),
                          ),
                        )
                        .toList(growable: false),
                    selected: <FastingPlan>{fasting.plan},
                    showSelectedIcon: false,
                    expandedInsets: EdgeInsets.zero,
                    onSelectionChanged: fasting.isMutating
                        ? null
                        : (selection) => onSelectPlan(selection.single),
                  ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverToBoxAdapter(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
                child: Column(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final diameter = constraints.maxWidth
                            .clamp(184.0, 236.0)
                            .toDouble();
                        return Center(
                          child: SizedBox.square(
                            dimension: diameter,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CircularProgressIndicator(
                                  value: progress,
                                  strokeWidth: 12,
                                  strokeCap: StrokeCap.round,
                                  backgroundColor: AppColors.greenSoft,
                                  color: AppColors.green,
                                ),
                                Center(
                                  child: MediaQuery.withClampedTextScaling(
                                    maxScaleFactor: 1.5,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          switch (phase) {
                                            FastingPhase.fasting =>
                                              LucideIcons.flame,
                                            FastingPhase.eating =>
                                              LucideIcons.utensils,
                                            FastingPhase.idle =>
                                              LucideIcons.timer,
                                          },
                                          color: AppColors.green,
                                          size: 24,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          switch (phase) {
                                            FastingPhase.fasting => '断食剩余',
                                            FastingPhase.eating => '进食窗口剩余',
                                            FastingPhase.idle =>
                                              '${fasting.plan.label} 计划',
                                          },
                                          style: const TextStyle(
                                            color: AppColors.muted,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Semantics(
                                          liveRegion: true,
                                          label: switch (phase) {
                                            FastingPhase.eating =>
                                              '进食窗口剩余 ${_formatDuration(remaining)}',
                                            FastingPhase.fasting ||
                                            FastingPhase.idle =>
                                              '断食剩余 ${_formatDuration(remaining)}',
                                          },
                                          child: ExcludeSemantics(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                _formatDuration(remaining),
                                                key: const Key(
                                                  'fasting-countdown',
                                                ),
                                                maxLines: 1,
                                                style: const TextStyle(
                                                  fontSize: 30,
                                                  fontWeight: FontWeight.w700,
                                                  fontFeatures: [
                                                    FontFeature.tabularFigures(),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (phase != FastingPhase.idle) ...[
                                          const SizedBox(height: 5),
                                          Text(
                                            phase == FastingPhase.fasting
                                                ? '目标 ${_formatTime(timeZones.toTimeZone(fasting.activeSession!.targetEndAtUtc, fasting.activeSession!.timeZoneId))}'
                                                : '窗口至 ${_formatTime(timeZones.toTimeZone(eatingSession!.targetEndAtUtc.add(eatingSession.plan.eatingDuration), eatingSession.timeZoneId))}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.muted,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    if (fasting.isActive)
                      OutlinedButton.icon(
                        key: const Key('stop-fasting'),
                        onPressed: fasting.isMutating ? null : onStop,
                        icon: fasting.isMutating
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(LucideIcons.circleStop, size: 19),
                        label: const Text('结束本次断食'),
                      )
                    else
                      FilledButton.icon(
                        key: const Key('start-fasting'),
                        onPressed: fasting.isMutating ? null : onStart,
                        icon: fasting.isMutating
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(LucideIcons.play, size: 19),
                        label: Text(
                          phase == FastingPhase.eating
                              ? '开始下一轮 ${fasting.plan.fastingHours} 小时断食'
                              : '开始 ${fasting.plan.fastingHours} 小时断食',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
          sliver: SliverToBoxAdapter(
            child: Text('最近状态', style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
          sliver: SliverToBoxAdapter(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Row(
                  children: [
                    Expanded(
                      child: _FastingMetric(
                        icon: LucideIcons.calendarDays,
                        value: '${stats.completedThisWeek} 天',
                        label: '本周完成',
                      ),
                    ),
                    const SizedBox(height: 42, child: VerticalDivider()),
                    Expanded(
                      child: _FastingMetric(
                        icon: LucideIcons.flame,
                        value: '${stats.currentStreak} 天',
                        label: '连续完成',
                      ),
                    ),
                    const SizedBox(height: 42, child: VerticalDivider()),
                    Expanded(
                      child: _FastingMetric(
                        icon: LucideIcons.target,
                        value: '${stats.completionRatePercent}%',
                        label: '计划达成',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          sliver: SliverToBoxAdapter(
            child: Text('断食历史', style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        if (history.isEmpty)
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 36),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: Text(
                  '还没有已结束的记录',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
            sliver: SliverList.separated(
              itemCount: history.length,
              itemBuilder: (context, index) =>
                  _FastingHistoryRow(session: history[index]),
              separatorBuilder: (_, _) => const SizedBox(height: 8),
            ),
          ),
      ],
    );
  }

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  static String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _ActivePlanBanner extends StatelessWidget {
  const _ActivePlanBanner({required this.plan});

  final FastingPlan plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.flame, size: 19, color: AppColors.green),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              '本轮计划 ${plan.label}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const Text('进行中', style: TextStyle(color: AppColors.green)),
        ],
      ),
    );
  }
}

class _FastingMetric extends StatelessWidget {
  const _FastingMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.green),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 2),
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

class _FastingHistoryRow extends StatelessWidget {
  const _FastingHistoryRow({required this.session});

  final FastingSession session;

  @override
  Widget build(BuildContext context) {
    final completed = session.status == FastingSessionStatus.completed;
    return Card(
      child: ListTile(
        leading: Icon(
          completed ? LucideIcons.circleCheck : LucideIcons.circleX,
          color: completed ? AppColors.green : AppColors.muted,
        ),
        title: Text('${session.plan.label} 计划'),
        subtitle: Text(session.startedLocalDay),
        trailing: Text(
          completed ? '已完成' : '未完成',
          style: TextStyle(
            color: completed ? AppColors.green : AppColors.muted,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _FastingLoadError extends StatelessWidget {
  const _FastingLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.circleAlert, size: 30),
            const SizedBox(height: 12),
            const Text('断食记录加载失败'),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
