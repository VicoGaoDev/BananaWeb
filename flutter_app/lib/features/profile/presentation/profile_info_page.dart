import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/presentation/auth_controller.dart';

class ProfileInfoPage extends ConsumerWidget {
  const ProfileInfoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '个人信息',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
        children: [
          const SizedBox(height: 6),
          _ProfileInfoTile(
            label: '头像',
            trailing: CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              foregroundImage: user?.avatarUrl.isNotEmpty == true
                  ? CachedNetworkImageProvider(user!.avatarUrl)
                  : null,
              child: user?.avatarUrl.isNotEmpty == true
                  ? null
                  : const Icon(Icons.person_outline, size: 16),
            ),
          ),
          _ProfileInfoTile(
            label: '昵称',
            value: user?.username ?? '未登录',
          ),
          _ProfileInfoTile(
            label: '邮箱',
            value: user?.email ?? '暂未绑定',
          ),
          _ProfileInfoTile(
            label: '修改密码',
            value: '',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('修改密码能力暂未接入')),
              );
            },
          ),
          _ProfileInfoTile(
            label: '退出登录',
            value: '',
            onTap: authState.isAuthenticated
                ? () async {
                    await ref.read(authControllerProvider.notifier).logout();
                    if (context.mounted) {
                      context.go('/');
                    }
                  }
                : null,
          ),
          const SizedBox(height: 28),
          Center(
            child: Text(
              '版本 1.0.0',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              '用户协议 | 隐私政策',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoTile extends StatelessWidget {
  const _ProfileInfoTile({
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
  });

  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (value != null && value!.isNotEmpty)
              Text(
                value!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            if (trailing != null) trailing!,
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
