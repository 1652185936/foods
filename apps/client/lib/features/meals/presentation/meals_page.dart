import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import 'recognition_sheet.dart';

class MealsPage extends StatefulWidget {
  const MealsPage({super.key});

  @override
  State<MealsPage> createState() => _MealsPageState();
}

class _MealsPageState extends State<MealsPage> {
  bool _recognitionOpen = false;

  Future<void> _openRecognition() async {
    if (_recognitionOpen) {
      return;
    }
    _recognitionOpen = true;
    try {
      final saved = await showRecognitionFlow(context);
      if (saved == true && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已记为午餐')));
      }
    } finally {
      _recognitionOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
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
                        '${today.month} 月 ${today.day} 日',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(child: _EnergySummary()),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                sliver: SliverToBoxAdapter(
                  child: Card(
                    child: InkWell(
                      key: const Key('open-recognition'),
                      borderRadius: BorderRadius.circular(8),
                      onTap: _openRecognition,
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            SizedBox.square(
                              dimension: 48,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(8),
                                  ),
                                ),
                                child: Icon(
                                  LucideIcons.camera,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '拍一拍，自动记一餐',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
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
                            Icon(
                              LucideIcons.chevronRight,
                              color: AppColors.muted,
                            ),
                          ],
                        ),
                      ),
                    ),
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
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 36),
                sliver: SliverToBoxAdapter(
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _MealRow(
                          meal: '早餐',
                          time: '08:10',
                          name: '水果燕麦酸奶碗',
                          calories: '380 kcal',
                          imageAsset: 'assets/images/oats-breakfast.webp',
                        ),
                        Divider(),
                        _MealRow(
                          meal: '午餐',
                          time: '12:32',
                          name: '鸡胸牛油果沙拉',
                          calories: '420 kcal',
                          imageAsset: 'assets/images/chicken-salad.webp',
                        ),
                      ],
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
}

class _EnergySummary extends StatelessWidget {
  const _EnergySummary();

  @override
  Widget build(BuildContext context) {
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
                      const CircularProgressIndicator(
                        value: 0.45,
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
                                '800',
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
                const SizedBox(
                  width: 190,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('还可摄入', style: TextStyle(color: AppColors.muted)),
                      SizedBox(height: 2),
                      Text(
                        '980 kcal',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        '目标 1,780 kcal',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Row(
              children: [
                Expanded(
                  child: _NutrientMetric(
                    label: '蛋白质',
                    value: '62 / 110 g',
                    color: AppColors.blue,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _NutrientMetric(
                    label: '碳水',
                    value: '91 / 210 g',
                    color: AppColors.yellow,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _NutrientMetric(
                    label: '脂肪',
                    value: '31 / 59 g',
                    color: AppColors.tomato,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 24, height: 3, color: color),
        const SizedBox(height: 7),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _MealRow extends StatelessWidget {
  const _MealRow({
    required this.meal,
    required this.time,
    required this.name,
    required this.calories,
    required this.imageAsset,
  });

  final String meal;
  final String time;
  final String name;
  final String calories;
  final String imageAsset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset(
              imageAsset,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              semanticLabel: name,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$meal · $time',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
                const SizedBox(height: 4),
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(
                  calories,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
