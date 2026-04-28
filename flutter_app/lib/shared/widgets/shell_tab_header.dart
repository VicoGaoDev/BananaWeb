import 'package:flutter/material.dart';

/// 模版 / 创作 Tab 共用顶栏：左侧历史，右侧积分余额。
class ShellTabHeader extends StatelessWidget {
  const ShellTabHeader({
    super.key,
    required this.onHistory,
    required this.creditsValue,
    this.authenticated = true,
  });

  final VoidCallback onHistory;
  /// 已登录时为积分数；未登录时可传 0，由 [authenticated] 控制展示。
  final int creditsValue;
  final bool authenticated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final creditsLabel = authenticated ? '$creditsValue' : '—';

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: onHistory,
            icon: const Icon(Icons.history_toggle_off, size: 18),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bolt_rounded,
                color: Colors.black,
                size: (theme.textTheme.labelMedium?.fontSize ?? 14) + 2,
              ),
              const SizedBox(width: 4),
              Text(
                creditsLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
