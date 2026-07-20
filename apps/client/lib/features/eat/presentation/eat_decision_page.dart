import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/eat_decision_controller.dart';

enum EatMode { takeout, home }

class EatDecisionPage extends ConsumerStatefulWidget {
  const EatDecisionPage({super.key});

  @override
  ConsumerState<EatDecisionPage> createState() => _EatDecisionPageState();
}

class _EatDecisionPageState extends ConsumerState<EatDecisionPage> {
  EatMode _mode = EatMode.takeout;

  @override
  Widget build(BuildContext context) {
    final decision = ref.watch(eatDecisionProvider);

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.pageMaxWidth),
          child: CustomScrollView(
            key: const PageStorageKey('eat-page-scroll'),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '今天吃什么',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '把这一顿交给当下的胃口。',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                sliver: SliverToBoxAdapter(
                  child: SegmentedButton<EatMode>(
                    key: const Key('eat-mode-selector'),
                    segments: const [
                      ButtonSegment(
                        value: EatMode.takeout,
                        label: Text('点外卖'),
                        icon: Icon(LucideIcons.utensils, size: 18),
                      ),
                      ButtonSegment(
                        value: EatMode.home,
                        label: Text('在家做'),
                        icon: Icon(LucideIcons.chefHat, size: 18),
                      ),
                    ],
                    selected: {_mode},
                    showSelectedIcon: false,
                    expandedInsets: EdgeInsets.zero,
                    onSelectionChanged: (selection) {
                      setState(() => _mode = selection.single);
                    },
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                sliver: SliverToBoxAdapter(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _mode == EatMode.takeout
                        ? _TakeoutDecisionPanel(
                            key: const ValueKey('takeout'),
                            state: decision,
                            onDecide: () {
                              ref.read(eatDecisionProvider.notifier).decide();
                            },
                          )
                        : const _HomeRecommendationPanel(key: ValueKey('home')),
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

class _TakeoutDecisionPanel extends StatelessWidget {
  const _TakeoutDecisionPanel({
    required this.state,
    required this.onDecide,
    super.key,
  });

  final EatDecisionState state;
  final VoidCallback onDecide;

  @override
  Widget build(BuildContext context) {
    final dish = state.dish;
    if (dish == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(LucideIcons.circleHelp, size: 28),
              const SizedBox(height: 12),
              Text('暂时没有可选菜品', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.35,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: Image.asset(
                    dish.imageAsset,
                    key: ValueKey(dish.id),
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    semanticLabel: dish.name,
                  ),
                ),
                Positioned(
                  left: 16,
                  top: 16,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        '今日决定',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                if (state.isRolling)
                  ColoredBox(
                    color: Colors.black.withValues(alpha: 0.4),
                    child: const Center(
                      child: SizedBox.square(
                        dimension: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  liveRegion: true,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Column(
                      key: ValueKey('details-${dish.id}'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dish.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          dish.description,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: dish.tags.map((tag) => _Tag(label: tag)).toList(),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    spacing: 18,
                    runSpacing: 10,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.clock3,
                            size: 18,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${dish.waitMinutes} 分钟',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                      Text(
                        dish.priceLabel,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  key: const Key('random-button'),
                  onPressed: state.isRolling ? null : onDecide,
                  icon: Icon(
                    state.status == EatDecisionStatus.result
                        ? LucideIcons.refreshCw
                        : LucideIcons.sparkles,
                    size: 19,
                  ),
                  label: Text(
                    state.isRolling
                        ? '正在决定'
                        : state.status == EatDecisionStatus.result
                        ? '换一个'
                        : '替我决定',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeRecommendationPanel extends StatelessWidget {
  const _HomeRecommendationPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.35,
            child: Image.asset(
              'assets/images/tomato-eggs-hero.webp',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              semanticLabel: '番茄炒蛋配米饭',
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Tag(label: '20 分钟'),
                    _Tag(label: '约 430 kcal'),
                    Icon(LucideIcons.leaf, size: 18, color: AppColors.green),
                  ],
                ),
                const SizedBox(height: 14),
                Text('番茄炒蛋配米饭', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text(
                  '酸甜开胃，食材简单，工作日也能轻松完成。',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  key: const Key('open-recipe'),
                  onPressed: () => context.push('/eat/recipe/tomato-eggs'),
                  icon: const Icon(LucideIcons.chefHat, size: 19),
                  label: const Text('查看做法'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
