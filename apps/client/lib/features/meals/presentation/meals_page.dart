import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/time/time_zone_converter.dart';
import '../application/meals_controller.dart';
import '../domain/meal_log.dart';
import 'manual_meal_sheet.dart';
import 'recognition_sheet.dart';

class MealsPage extends ConsumerStatefulWidget {
  const MealsPage({super.key});

  @override
  ConsumerState<MealsPage> createState() => _MealsPageState();
}

class _MealsPageState extends ConsumerState<MealsPage> {
  bool _composerOpen = false;

  Future<void> _openComposer({required bool recognition}) async {
    if (_composerOpen) {
      return;
    }
    _composerOpen = true;
    try {
      final active = await ref.read(fastingRepositoryProvider).loadActive();
      if (!mounted) {
        return;
      }
      final nowUtc = ref.read(appClockProvider).now().toUtc();
      final timeZoneId = ref.read(currentTimeZoneIdProvider);
      final isWithinEatingWindow =
          active == null ||
          nowUtc.isBefore(active.startedAtUtc) ||
          !nowUtc.isBefore(active.targetEndAtUtc);
      final draft = recognition
          ? await showRecognitionFlow(
              context,
              nowUtc: nowUtc,
              timeZoneId: timeZoneId,
              isWithinEatingWindow: isWithinEatingWindow,
            )
          : await showManualMealFlow(
              context,
              nowUtc: nowUtc,
              timeZoneId: timeZoneId,
              isWithinEatingWindow: isWithinEatingWindow,
            );
      if (draft == null || !mounted) {
        return;
      }
      final saved = await ref.read(mealMutationProvider.notifier).save(draft);
      if (!mounted) {
        return;
      }
      if (saved) {
        _showMessage(isWithinEatingWindow ? '已记录这餐' : '已记录，并标记为断食期间进食');
      } else {
        _showSaveFailure();
      }
    } catch (_) {
      if (mounted) {
        _showMessage('暂时无法读取断食状态，请重试');
      }
    } finally {
      _composerOpen = false;
    }
  }

  Future<void> _deleteMeal(MealLog meal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这条记录？'),
        content: Text(meal.items.map((item) => item.name).join('、')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final deleted = await ref
        .read(mealMutationProvider.notifier)
        .delete(meal.id);
    if (mounted) {
      _showMessage(deleted ? '记录已删除' : '删除失败，请重试');
    }
  }

  void _showSaveFailure() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('保存失败'),
        action: SnackBarAction(
          label: '重试',
          onPressed: () async {
            final saved = await ref
                .read(mealMutationProvider.notifier)
                .retryLastSave();
            if (mounted) {
              _showMessage(saved ? '已记录这餐' : '仍未保存，请稍后重试');
            }
          },
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final day = ref.watch(currentMealDayProvider);
    final meals = ref.watch(todayMealsProvider);
    final isSaving = ref.watch(mealMutationProvider).isSaving;
    final timeZones = ref.watch(timeZoneConverterProvider);

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.pageMaxWidth),
          child: CustomScrollView(
            key: const PageStorageKey('meals-page-scroll'),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
                sliver: SliverToBoxAdapter(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [
                      Text(
                        '今日记录',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      Text(
                        '${day.month} 月 ${day.day} 日',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: meals.when(
                    data: (snapshot) =>
                        _EnergySummary(summary: snapshot.summary),
                    loading: () => const _SummaryLoading(),
                    error: (_, _) => _LoadError(
                      onRetry: () => ref.invalidate(todayMealsProvider),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                sliver: SliverToBoxAdapter(
                  child: _MealActions(
                    enabled: !isSaving,
                    onRecognition: () => _openComposer(recognition: true),
                    onManual: () => _openComposer(recognition: false),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    '今天吃过',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              meals.when(
                data: (snapshot) => snapshot.meals.isEmpty
                    ? const SliverPadding(
                        padding: EdgeInsets.fromLTRB(20, 0, 20, 36),
                        sliver: SliverToBoxAdapter(child: _EmptyMeals()),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
                        sliver: SliverList.separated(
                          itemCount: snapshot.meals.length,
                          itemBuilder: (context, index) => _MealCard(
                            meal: snapshot.meals[index],
                            timeZones: timeZones,
                            onDelete: () => _deleteMeal(snapshot.meals[index]),
                          ),
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                        ),
                      ),
                loading: () =>
                    const SliverToBoxAdapter(child: SizedBox(height: 36)),
                error: (_, _) =>
                    const SliverToBoxAdapter(child: SizedBox(height: 36)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MealActions extends StatelessWidget {
  const _MealActions({
    required this.enabled,
    required this.onRecognition,
    required this.onManual,
  });

  final bool enabled;
  final VoidCallback onRecognition;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            key: const Key('open-recognition'),
            onTap: enabled ? onRecognition : null,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: 48,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      child: Icon(LucideIcons.camera, color: Colors.white),
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '拍照记录',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 3),
                        Text(
                          '识别菜品、份量和营养',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(LucideIcons.chevronRight, color: AppColors.muted),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          TextButton.icon(
            key: const Key('open-manual-meal'),
            onPressed: enabled ? onManual : null,
            icon: const Icon(LucideIcons.pencil, size: 18),
            label: const Text('手动记录'),
          ),
        ],
      ),
    );
  }
}

class _EnergySummary extends StatelessWidget {
  const _EnergySummary({required this.summary});

  final DailyNutritionSummary summary;

  @override
  Widget build(BuildContext context) {
    final target = summary.targetEnergyKcal;
    final remaining = (target - summary.energyKcal).clamp(0, target);
    final progress = target <= 0
        ? 0.0
        : (summary.energyKcal / target).clamp(0.0, 1.0).toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 18,
              runSpacing: 18,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox.square(
                  dimension: 82,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        strokeCap: StrokeCap.round,
                        backgroundColor: AppColors.greenSoft,
                        color: AppColors.green,
                      ),
                      Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${summary.energyKcal}',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const Text(
                                '已摄入',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '还可摄入',
                        style: TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$remaining kcal',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '目标 $target kcal',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _NutrientMetric(
                  label: '蛋白质',
                  value: _formatGrams(summary.proteinMg),
                  color: AppColors.blue,
                ),
                _NutrientMetric(
                  label: '碳水',
                  value: _formatGrams(summary.carbsMg),
                  color: AppColors.yellow,
                ),
                _NutrientMetric(
                  label: '脂肪',
                  value: _formatGrams(summary.fatMg),
                  color: AppColors.tomato,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatGrams(int milligrams) {
    final grams = milligrams / 1000;
    return grams == grams.roundToDouble()
        ? '${grams.toInt()} g'
        : '${grams.toStringAsFixed(1)} g';
  }
}

class _NutrientMetric extends StatelessWidget {
  const _NutrientMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 24, height: 3, color: color),
          const SizedBox(height: 7),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.meal,
    required this.timeZones,
    required this.onDelete,
  });

  final MealLog meal;
  final TimeZoneConverter timeZones;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final image = meal.items
        .map((item) => item.imageReference)
        .whereType<String>()
        .firstOrNull;
    final name = meal.items.map((item) => item.name).join('、');
    final energy = meal.items.fold<int>(
      0,
      (total, item) => total + item.energyKcal,
    );
    final time = timeZones.toTimeZone(meal.occurredAtUtc, meal.timeZoneId);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox.square(
                dimension: 60,
                child: image == null
                    ? const ColoredBox(
                        color: AppColors.greenSoft,
                        child: Icon(
                          LucideIcons.utensils,
                          color: AppColors.green,
                        ),
                      )
                    : Image.asset(
                        image,
                        fit: BoxFit.cover,
                        semanticLabel: name,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: AppColors.greenSoft,
                          child: Icon(
                            LucideIcons.utensils,
                            color: AppColors.green,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${meal.type.label} · ${_formatTime(time)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 8,
                    runSpacing: 3,
                    children: [
                      Text(
                        '$energy kcal',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                      if (!meal.isWithinEatingWindow)
                        const Text(
                          '断食期间',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.tomato,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '删除记录',
              onPressed: onDelete,
              icon: const Icon(LucideIcons.trash2, size: 19),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _SummaryLoading extends StatelessWidget {
  const _SummaryLoading();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: SizedBox(
        height: 178,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Expanded(child: Text('今日记录加载失败')),
            IconButton(
              tooltip: '重试',
              onPressed: onRetry,
              icon: const Icon(LucideIcons.refreshCw),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyMeals extends StatelessWidget {
  const _EmptyMeals();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text('今天还没有记录', style: TextStyle(color: AppColors.muted)),
      ),
    );
  }
}
