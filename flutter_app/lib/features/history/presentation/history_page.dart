import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/history_repository.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  int _selectedFilterIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final imageResolver = ref.watch(imageUrlResolverProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('积分记录')),
      body: !authState.isAuthenticated
          ? ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  '积分记录',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  '登录后可查看积分消耗与历史任务记录。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.push('/login'),
                  child: const Text('去登录'),
                ),
              ],
            )
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(userHistoryProvider);
                await ref.read(userHistoryProvider.future);
              },
              child: ref.watch(userHistoryProvider).when(
                    loading: () => const _LoadingListView(message: '历史记录加载中...'),
                    error: (error, _) => ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text('历史记录加载失败：$error'),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => ref.invalidate(userHistoryProvider),
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                    data: (history) {
                      final filters = ['全部', '消耗', '获得'];
                      final items = switch (_selectedFilterIndex) {
                        1 => history.items.where((item) => item.creditCost > 0).toList(),
                        2 => history.items.where((item) => item.creditCost < 0).toList(),
                        _ => history.items,
                      };

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        children: [
                          Text(
                            '积分记录',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 34,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: filters.length,
                              separatorBuilder: (context, index) => const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final selected = _selectedFilterIndex == index;
                                return InkWell(
                                  borderRadius: BorderRadius.circular(999),
                                  onTap: () {
                                    setState(() {
                                      _selectedFilterIndex = index;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? Colors.black
                                          : const Color(0xFFF3F3F3),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      filters[index],
                                      style: TextStyle(
                                        color: selected
                                            ? Colors.white
                                            : const Color(0xFF666666),
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (items.isEmpty)
                            const Card(
                              child: ListTile(
                                title: Text('暂无记录'),
                                subtitle: Text('当前筛选条件下没有可展示的积分记录。'),
                              ),
                            )
                          else
                            ...items.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () => context.push(
                                    '/history/detail',
                                    extra: item,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          shape: BoxShape.circle,
                                        ),
                                        child: item.previewUrl.isNotEmpty || item.imageUrl.isNotEmpty
                                            ? ClipOval(
                                                child: Image.network(
                                                  imageResolver.resolve(
                                                    item.previewUrl.isNotEmpty
                                                        ? item.previewUrl
                                                        : item.imageUrl,
                                                  ),
                                                  fit: BoxFit.cover,
                                                ),
                                              )
                                            : const Icon(Icons.history, size: 16),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.prompt.isEmpty ? '生成图片' : item.prompt,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              item.createdAt,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        item.creditCost >= 0
                                            ? '-${item.creditCost}'
                                            : '+${item.creditCost.abs()}',
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
            ),
    );
  }
}

class _LoadingListView extends StatelessWidget {
  const _LoadingListView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 16),
        Center(child: Text(message)),
      ],
    );
  }
}
