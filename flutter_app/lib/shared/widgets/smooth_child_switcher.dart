import 'package:flutter/material.dart';

/// Cross-fades between children when [contentKey] changes (e.g. filter / tab data).
class SmoothChildSwitcher extends StatelessWidget {
  const SmoothChildSwitcher({
    super.key,
    required this.contentKey,
    required this.child,
    this.duration = const Duration(milliseconds: 280),
  });

  final Object contentKey;
  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.015),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(contentKey),
        child: child,
      ),
    );
  }
}
