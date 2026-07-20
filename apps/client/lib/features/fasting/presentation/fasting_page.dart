import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/fasting_controller.dart';
import '../domain/fasting_plan.dart';

class FastingPage extends ConsumerStatefulWidget {
  const FastingPage({super.key});

  @override
  ConsumerState<FastingPage> createState() => _FastingPageState();
}

class _FastingPageState extends ConsumerState<FastingPage>
    with WidgetsBindingObserver {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !ref.read(fastingProvider).isActive) {
        return;
      }
      ref.read(fastingProvider.notifier).completeIfNeeded();
      if (TickerMode.valuesOf(context).enabled) {
        setState(() {});
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(fastingProvider.notifier).completeIfNeeded();
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fasting = ref.watch(fastingProvider);
    final now = DateTime.now();
    final remaining = fasting.isActive
        ? fasting.remainingAt(now)
        : fasting.plan.fastingDuration;
    final totalSeconds = fasting.plan.fastingDuration.inSeconds;
    final progress = fasting.isActive
        ? (1 - (remaining.inSeconds / totalSeconds)).clamp(0.0, 1.0)
        : 0.0;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.pageMaxWidth),
          child: CustomScrollView(
            key: const PageStorageKey('fasting-page-scroll'),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '轻断食',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        fasting.isActive ? '身体正在使用储备能量' : '选择适合今天的节奏',
                        style: const TextStyle(color: AppColors.muted),
                      ),
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
                              .toList(),
                          selected: {fasting.plan},
                          showSelectedIcon: false,
                          expandedInsets: EdgeInsets.zero,
                          onSelectionChanged: (selection) {
                            ref
                                .read(fastingProvider.notifier)
                                .selectPlan(selection.single);
                          },
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
                                                fasting.isActive
                                                    ? LucideIcons.flame
                                                    : LucideIcons.timer,
                                                color: AppColors.green,
                                                size: 24,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                fasting.isActive
                                                    ? '剩余时间'
                                                    : '${fasting.plan.label} 计划',
                                                style: const TextStyle(
                                                  color: AppColors.muted,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Semantics(
                                                liveRegion: true,
                                                label:
                                                    '断食剩余 ${_formatDuration(remaining)}',
                                                child: ExcludeSemantics(
                                                  child: FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: Text(
                                                      _formatDuration(
                                                        remaining,
                                                      ),
                                                      key: const Key(
                                                        'fasting-countdown',
                                                      ),
                                                      maxLines: 1,
                                                      style: const TextStyle(
                                                        fontSize: 30,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontFeatures: [
                                                          FontFeature.tabularFigures(),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              if (fasting.isActive) ...[
                                                const SizedBox(height: 5),
                                                Text(
                                                  '目标 ${_formatTime(fasting.targetEndAt!)}',
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
                              onPressed: () =>
                                  ref.read(fastingProvider.notifier).stop(),
                              icon: const Icon(
                                LucideIcons.circleStop,
                                size: 19,
                              ),
                              label: const Text('结束本次断食'),
                            )
                          else
                            FilledButton.icon(
                              key: const Key('start-fasting'),
                              onPressed: () =>
                                  ref.read(fastingProvider.notifier).start(),
                              icon: const Icon(LucideIcons.play, size: 19),
                              label: Text(
                                '开始 ${fasting.plan.fastingHours} 小时断食',
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
                  child: Text(
                    '最近状态',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 36),
                sliver: SliverToBoxAdapter(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Row(
                        children: [
                          Expanded(
                            child: _FastingMetric(
                              icon: LucideIcons.calendarDays,
                              value: '5 天',
                              label: '本周完成',
                            ),
                          ),
                          SizedBox(height: 42, child: VerticalDivider()),
                          Expanded(
                            child: _FastingMetric(
                              icon: LucideIcons.flame,
                              value: '3 天',
                              label: '连续完成',
                            ),
                          ),
                          SizedBox(height: 42, child: VerticalDivider()),
                          Expanded(
                            child: _FastingMetric(
                              icon: LucideIcons.target,
                              value: '82%',
                              label: '计划达成',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String _formatTime(DateTime time) {
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
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ],
    );
  }
}
