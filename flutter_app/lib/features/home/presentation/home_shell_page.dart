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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9.6),
              child: Row(
                children: [
                  _NavItem(
                    label: '模板',
                    icon: Icons.grid_view_rounded,
                    selected: currentIndex == 0,
                    onTap: () =>
                        ref.read(homeTabIndexProvider.notifier).state = 0,
                  ),
                  _NavItem(
                    label: '创作',
                    icon: Icons.brush_outlined,
                    selected: currentIndex == 1,
                    onTap: () =>
                        ref.read(homeTabIndexProvider.notifier).state = 1,
                  ),
                  _NavItem(
                    label: '我的',
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
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4.8),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 28.8,
                height: 28.8,
                decoration: BoxDecoration(
                  color: selected
                      ? theme.colorScheme.surfaceContainerHighest
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9.6),
                ),
                child: Icon(
                  icon,
                  size: 19.2,
                  color: selected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2.4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: selected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
