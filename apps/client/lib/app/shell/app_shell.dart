import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _selectDestination(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 600;
        if (useRail) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  extended: constraints.maxWidth >= 980,
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: _selectDestination,
                  labelType: constraints.maxWidth >= 980
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.selected,
                  leading: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: _BrandMark(),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(LucideIcons.utensils),
                      selectedIcon: Icon(LucideIcons.utensils),
                      label: Text('吃什么'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(LucideIcons.notebookTabs),
                      selectedIcon: Icon(LucideIcons.notebookTabs),
                      label: Text('记录'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(LucideIcons.flame),
                      selectedIcon: Icon(LucideIcons.flame),
                      label: Text('断食'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(LucideIcons.circleUserRound),
                      selectedIcon: Icon(LucideIcons.circleUserRound),
                      label: Text('我的'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: navigationShell),
              ],
            ),
          );
        }

        return Scaffold(
          body: navigationShell,
          bottomNavigationBar: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _selectDestination,
            destinations: const [
              NavigationDestination(
                key: Key('nav-eat'),
                icon: Icon(LucideIcons.utensils),
                label: '吃什么',
              ),
              NavigationDestination(
                key: Key('nav-meals'),
                icon: Icon(LucideIcons.notebookTabs),
                label: '记录',
              ),
              NavigationDestination(
                key: Key('nav-fasting'),
                icon: Icon(LucideIcons.flame),
                label: '断食',
              ),
              NavigationDestination(
                key: Key('nav-profile'),
                icon: Icon(LucideIcons.circleUserRound),
                label: '我的',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '好好吃饭',
      child: const SizedBox.square(
        dimension: 44,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          child: Icon(LucideIcons.leaf, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
