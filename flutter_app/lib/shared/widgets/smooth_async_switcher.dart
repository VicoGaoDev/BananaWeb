import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cross-fades and lightly slides between loading, error, and data slots for an [AsyncValue].
class SmoothAsyncSwitcher<T> extends StatelessWidget {
  const SmoothAsyncSwitcher({
    super.key,
    required this.asyncValue,
    required this.loading,
    required this.error,
    required this.data,
    this.duration = const Duration(milliseconds: 320),
  });

  final AsyncValue<T> asyncValue;
  final Widget Function() loading;
  final Widget Function(Object error, StackTrace? stackTrace) error;
  final Widget Function(T data) data;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final Widget body;
    final Key switchKey;

    if (asyncValue.isLoading) {
      switchKey = const ValueKey('_smooth_async_loading');
      body = loading();
    } else if (asyncValue.hasError) {
      final e = asyncValue.error!;
      final st = asyncValue.stackTrace;
      switchKey = ValueKey('_smooth_async_err_${e.hashCode}');
      body = error(e, st);
    } else {
      final v = asyncValue.requireValue;
      switchKey = ValueKey('_smooth_async_data_${v.hashCode}');
      body = data(v);
    }

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
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: switchKey,
        child: body,
      ),
    );
  }
}
