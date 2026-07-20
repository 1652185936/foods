import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class RecipeDetailPage extends StatelessWidget {
  const RecipeDetailPage({required this.recipeId, super.key});

  final String recipeId;

  @override
  Widget build(BuildContext context) {
    if (recipeId != 'tomato-eggs') {
      return const _RecipeNotFound();
    }

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.pageMaxWidth),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 8, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: '返回',
                        onPressed: context.pop,
                        icon: const Icon(LucideIcons.arrowLeft),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '家常菜谱',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AspectRatio(
                      aspectRatio: 1.45,
                      child: Image.asset(
                        'assets/images/tomato-eggs-hero.webp',
                        fit: BoxFit.cover,
                        semanticLabel: '番茄炒蛋配米饭',
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '番茄炒蛋配米饭',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 10),
                      const Wrap(
                        spacing: 18,
                        runSpacing: 12,
                        children: [
                          _RecipeMetric(
                            label: '20 分钟',
                            icon: LucideIcons.clock3,
                          ),
                          _RecipeMetric(
                            label: '约 430 kcal',
                            icon: LucideIcons.flame,
                          ),
                          _RecipeMetric(
                            label: '简单',
                            icon: LucideIcons.sparkles,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _RecipeSection(
                    title: '食材',
                    lines: ['番茄 2 个', '鸡蛋 3 个', '米饭 1 碗', '盐、糖和葱花 少许'],
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 26, 20, 40),
                sliver: SliverToBoxAdapter(
                  child: _RecipeSection(
                    title: '步骤',
                    numbered: true,
                    lines: [
                      '番茄切块，鸡蛋加少许盐打散。',
                      '热锅下油，把鸡蛋炒至刚凝固后盛出。',
                      '番茄炒出汁，调味后倒回鸡蛋快速翻匀。',
                      '搭配一碗米饭，撒上葱花即可。',
                    ],
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

class _RecipeMetric extends StatelessWidget {
  const _RecipeMetric({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.green),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _RecipeNotFound extends StatelessWidget {
  const _RecipeNotFound();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.circleHelp, size: 32),
              const SizedBox(height: 12),
              Text('没有找到这份菜谱', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: context.pop,
                icon: const Icon(LucideIcons.arrowLeft),
                label: const Text('返回推荐'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipeSection extends StatelessWidget {
  const _RecipeSection({
    required this.title,
    required this.lines,
    this.numbered = false,
  });

  final String title;
  final List<String> lines;
  final bool numbered;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 14),
        for (var index = 0; index < lines.length; index++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  numbered ? '${index + 1}.' : '·',
                  style: const TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(child: Text(lines[index])),
            ],
          ),
          if (index != lines.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}
