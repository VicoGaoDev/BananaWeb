import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../../generate/presentation/generate_page.dart';
import '../../generate/presentation/task_controller.dart';
import '../../history/presentation/history_list_controller.dart';
import '../../history/presentation/history_tasks_panel.dart';
import '../../profile/presentation/profile_page.dart';
import 'home_page.dart';
import 'home_shell_controller.dart';

class HomeShellPage extends ConsumerWidget {
  const HomeShellPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<TaskFlowState>(taskControllerProvider, (previous, next) {
      if (previous?.isPolling != true || next.isPolling) return;
      if (!ref.read(authControllerProvider).isAuthenticated) return;
      ref.read(historyListControllerProvider.notifier).refresh();
    });

    const pages = [
      HomePage(),
      GeneratePage(),
      ProfilePage(),
    ];
    final currentIndex = ref.watch(homeTabIndexProvider);

    return Scaffold(
      extendBody: true,
      drawer: Drawer(
        width: MediaQuery.sizeOf(context).width * 4 / 5,
        child: const HistoryTasksDrawer(),
      ),
      body: SafeArea(
        bottom: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            for (var i = 0; i < pages.length; i++)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: currentIndex != i,
                  child: AnimatedOpacity(
                    opacity: currentIndex == i ? 1 : 0,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    child: pages[i],
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: Material(
        elevation: 0,
        color: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        child: SafeArea(
          top: false,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surface
                  .withValues(alpha: 0.8),
            ),
            child: SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _NavItem(
                      tooltip: '模板',
                      icon: Icons.grid_view_rounded,
                      selected: currentIndex == 0,
                      onTap: () =>
                          ref.read(homeTabIndexProvider.notifier).state = 0,
                    ),
                    _NavItem(
                      tooltip: '创作',
                      icon: Icons.auto_awesome_rounded,
                      selected: currentIndex == 1,
                      onTap: () =>
                          ref.read(homeTabIndexProvider.notifier).state = 1,
                    ),
                    _NavItem(
                      tooltip: '我的',
                      icon: Icons.person_outline_rounded,
                      selected: currentIndex == 2,
                      onTap: () =>
                          ref.read(homeTabIndexProvider.notifier).state = 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        selected: selected,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: SizedBox(
              width: 72,
              height: 56,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: selected
                        ? theme.colorScheme.surfaceContainerHighest
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 21,
                    color: selected
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
