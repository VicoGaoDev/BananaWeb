import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shared durations and [CustomTransitionPage] builders for route changes.
abstract final class AppPageTransitions {
  static const Duration enterDuration = Duration(milliseconds: 340);
  static const Duration exitDuration = Duration(milliseconds: 280);

  static Page<void> fadeThrough(GoRouterState state, Widget child) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: enterDuration,
      reverseTransitionDuration: exitDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.035),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}
