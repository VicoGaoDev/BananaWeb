import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/network/image_url_resolver.dart';
import '../../../shared/widgets/smooth_child_switcher.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../generate/presentation/task_controller.dart';
import '../../home/presentation/home_shell_controller.dart';
import '../data/history_models.dart';
import '../data/history_repository.dart';
import 'history_list_controller.dart';

/// 将 [UserHistoryCardItem] 按本地日历分为今天 / 昨天 / 更早（保持原列表顺序）。
typedef _HistoryDayBuckets = ({
  List<UserHistoryCardItem> today,
  List<UserHistoryCardItem> yesterday,
  List<UserHistoryCardItem> earlier,
});

_HistoryDayBuckets _groupHistoryItemsByDay(List<UserHistoryCardItem> items) {
  final today = <UserHistoryCardItem>[];
  final yesterday = <UserHistoryCardItem>[];
  final earlier = <UserHistoryCardItem>[];

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final yesterdayStart = todayStart.subtract(const Duration(days: 1));

  for (final item in items) {
    final dt = _parseHistoryLocalDate(item.createdAt);
    if (dt == null) {
      earlier.add(item);
      continue;
    }
    final day = DateTime(dt.year, dt.month, dt.day);
    if (day == todayStart) {
      today.add(item);
    } else if (day == yesterdayStart) {
      yesterday.add(item);
    } else {
      earlier.add(item);
    }
  }

  return (today: today, yesterday: yesterday, earlier: earlier);
}

DateTime? _parseHistoryLocalDate(String raw) {
  if (raw.trim().isEmpty) return null;
  try {
    return DateTime.parse(raw).toLocal();
  } catch (_) {
    return null;
  }
}

/// 列表中的任务时间展示（与分组「今天/昨天/更早」配合）。
String _formatHistoryTaskTime(String raw) {
  final dt = _parseHistoryLocalDate(raw);
  if (dt == null) return raw.trim().isEmpty ? '—' : raw;

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final yesterdayStart = todayStart.subtract(const Duration(days: 1));
  final dayStart = DateTime(dt.year, dt.month, dt.day);

  String two(int n) => n.toString().padLeft(2, '0');
  final hm = '${two(dt.hour)}:${two(dt.minute)}';

  if (dayStart == todayStart) {
    return hm;
  }
  if (dayStart == yesterdayStart) {
    return '昨天 $hm';
  }
  if (dt.year == now.year) {
    return '${dt.month}月${dt.day}日 $hm';
  }
  return '${dt.year}-${two(dt.month)}-${two(dt.day)} $hm';
}

bool _historyItemStatusIsRunning(String status) {
  final s = status.toLowerCase();
  return s == 'pending' || s == 'queued' || s == 'processing';
}

/// 历史任务列表（全屏页与侧边抽屉共用）。
class HistoryTasksPanel extends ConsumerStatefulWidget {
  const HistoryTasksPanel({super.key});

  @override
  ConsumerState<HistoryTasksPanel> createState() => _HistoryTasksPanelState();
}

class _HistoryTasksPanelState extends ConsumerState<HistoryTasksPanel> {
  Timer? _pollTimer;
  late final ScrollController _scrollController;
  bool _historyLoadScheduled = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onHistoryScroll);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _scrollController.removeListener(_onHistoryScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onHistoryScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 220) {
      ref.read(historyListControllerProvider.notifier).loadMore();
    }
  }

  void _syncHistoryPolling(List<UserHistoryCardItem> items) {
    final needs = items.any((e) => _historyItemStatusIsRunning(e.status));
    if (!needs) {
      _pollTimer?.cancel();
      _pollTimer = null;
      return;
    }
    if (_pollTimer != null) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      ref.read(historyListControllerProvider.notifier).syncLoadedPages();
    });
  }

  Future<void> _regenerateTask(UserHistoryCardItem item) async {
    if (item.mode != 'generate') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该类型暂不支持重新生成')),
      );
      return;
    }
    if (item.taskId <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该记录无法重新生成')),
      );
      return;
    }
    if (item.prompt.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('提示词为空，无法重新生成')),
      );
      return;
    }
    final n = item.numImages < 1 ? 1 : item.numImages;
    final ok = await ref.read(taskControllerProvider.notifier).createTask(
          model: item.model,
          prompt: item.prompt.trim(),
          numImages: n,
          size: item.size,
          resolution: item.resolution,
          customSize: item.customSize.trim(),
          referenceImages: item.referenceImages,
        );
    if (!mounted) return;
    final msg = ok
        ? '已重新提交生成任务'
        : (ref.read(taskControllerProvider).errorMessage ?? '提交失败');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    await ref.read(historyListControllerProvider.notifier).refresh();
    await ref.read(authControllerProvider.notifier).refreshMe();
    if (ok) {
      ref.read(homeTabIndexProvider.notifier).state = 1;
    }
  }

  Future<void> _confirmAndDeleteTask(UserHistoryCardItem item) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('删除任务'),
            content: const Text('确定删除这条记录吗？删除后不可恢复。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    try {
      if (item.taskId < 0) {
        final hid = item.historyId;
        if (hid == null) {
          throw const AppException('无法删除该记录');
        }
        await ref.read(historyRepositoryProvider).deletePromptHistoryItem(hid);
      } else {
        await ref.read(historyRepositoryProvider).deleteTask(item.taskId);
      }
      await ref.read(historyListControllerProvider.notifier).refresh();
      await ref.read(authControllerProvider.notifier).refreshMe();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已删除')),
      );
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (previous?.isAuthenticated == true && !next.isAuthenticated) {
        ref.read(historyListControllerProvider.notifier).reset();
        _historyLoadScheduled = false;
      }
    });

    final authState = ref.watch(authControllerProvider);
    final listState = ref.watch(historyListControllerProvider);
    final imageResolver = ref.watch(imageUrlResolverProvider);

    if (authState.isAuthenticated &&
        !listState.hasLoadedOnce &&
        !_historyLoadScheduled) {
      _historyLoadScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(historyListControllerProvider.notifier).loadInitial();
      });
    }

    if (authState.isAuthenticated &&
        ((listState.isInitialLoading && listState.items.isEmpty) ||
            (listState.error != null && listState.items.isEmpty))) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }

    if (!authState.isAuthenticated) {
      _pollTimer?.cancel();
      _pollTimer = null;
      _historyLoadScheduled = false;
      return ListView(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Text(
            '历史任务',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            '登录后可查看历史生成任务。',
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
      );
    }

    if (listState.isInitialLoading && listState.items.isEmpty && listState.error == null) {
      return ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [_HistoryListSkeleton()],
      );
    }

    if (listState.error != null &&
        listState.items.isEmpty &&
        !listState.isInitialLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Text('加载失败：${listState.error}'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => ref.read(historyListControllerProvider.notifier).loadInitial(),
            child: const Text('重试'),
          ),
        ],
      );
    }

    final items = listState.items;
    _syncHistoryPolling(items);
    final buckets = _groupHistoryItemsByDay(items);
    final baseSize = Theme.of(context).textTheme.titleSmall?.fontSize ?? 14;
    final promptStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: (baseSize - 4).clamp(10.0, double.infinity),
        );

    return RefreshIndicator(
      onRefresh: () => ref.read(historyListControllerProvider.notifier).refresh(),
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SmoothChildSwitcher(
            contentKey:
                '${items.length}:${items.isEmpty ? 0 : items.first.taskId}:${items.isEmpty ? 0 : items.last.taskId}',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (items.isEmpty)
                  const Card(
                    child: ListTile(
                      title: Text('暂无任务'),
                      subtitle: Text('还没有可展示的历史任务。'),
                    ),
                  )
                else ...[
                  ..._historySectionWidgets(
                    context: context,
                    title: '今天',
                    items: buckets.today,
                    imageResolver: imageResolver,
                    promptStyle: promptStyle,
                    onRegenerate: _regenerateTask,
                    onDelete: _confirmAndDeleteTask,
                  ),
                  ..._historySectionWidgets(
                    context: context,
                    title: '昨天',
                    items: buckets.yesterday,
                    imageResolver: imageResolver,
                    promptStyle: promptStyle,
                    onRegenerate: _regenerateTask,
                    onDelete: _confirmAndDeleteTask,
                    leadingSpacer: buckets.today.isNotEmpty,
                  ),
                  ..._historySectionWidgets(
                    context: context,
                    title: '更早',
                    items: buckets.earlier,
                    imageResolver: imageResolver,
                    promptStyle: promptStyle,
                    onRegenerate: _regenerateTask,
                    onDelete: _confirmAndDeleteTask,
                    leadingSpacer:
                        buckets.today.isNotEmpty || buckets.yesterday.isNotEmpty,
                  ),
                ],
                if (listState.hasMore) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: listState.isLoadingMore
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const SizedBox(height: 1),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

List<Widget> _historySectionWidgets({
  required BuildContext context,
  required String title,
  required List<UserHistoryCardItem> items,
  required ImageUrlResolver imageResolver,
  required TextStyle? promptStyle,
  required Future<void> Function(UserHistoryCardItem item) onRegenerate,
  required Future<void> Function(UserHistoryCardItem item) onDelete,
  bool leadingSpacer = false,
}) {
  if (items.isEmpty) return <Widget>[];
  return [
    if (leadingSpacer) const SizedBox(height: 11),
    Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 5),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: ((Theme.of(context).textTheme.titleSmall?.fontSize ?? 14) - 1)
                  .clamp(10.0, double.infinity),
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    ),
    for (var i = 0; i < items.length; i++) ...[
      if (i > 0) const SizedBox(height: 5),
      _HistoryTaskTile(
        item: items[i],
        imageResolver: imageResolver,
        promptStyle: promptStyle,
        onOpenDetail: () {
          if (Scaffold.of(context).isDrawerOpen) {
            Navigator.pop(context);
          }
          context.push('/history/detail', extra: items[i]);
        },
        onRegenerate: () => onRegenerate(items[i]),
        onDelete: () => onDelete(items[i]),
      ),
    ],
  ];
}

const double _historyTaskCardHeight = 72;

class _HistoryListSkeleton extends StatelessWidget {
  const _HistoryListSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            height: 13,
            width: 40,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(height: 5),
          Container(
            height: _historyTaskCardHeight,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ],
      ],
    );
  }
}

class _HistoryTaskTile extends StatelessWidget {
  const _HistoryTaskTile({
    required this.item,
    required this.imageResolver,
    required this.promptStyle,
    required this.onOpenDetail,
    required this.onRegenerate,
    required this.onDelete,
  });

  final UserHistoryCardItem item;
  final ImageUrlResolver imageResolver;
  final TextStyle? promptStyle;
  final VoidCallback onOpenDetail;
  final Future<void> Function() onRegenerate;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.surfaceContainerHighest;
    final thumbBg = theme.colorScheme.surface;
    final timeLabel = _formatHistoryTaskTime(item.createdAt);
    final hasImage = item.thumbUrl.isNotEmpty ||
        item.previewUrl.isNotEmpty ||
        item.imageUrl.isNotEmpty;
    final imageUrl = hasImage
        ? imageResolver.resolveThumbnailLayers(
            thumbUrl: item.thumbUrl,
            previewUrl: item.previewUrl,
            imageUrl: item.imageUrl,
          )
        : '';

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: _historyTaskCardHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: InkWell(
                onTap: onOpenDetail,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: _historyTaskCardHeight,
                      child: ColoredBox(
                        color: thumbBg,
                        child: hasImage && imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Center(
                                  child: Icon(
                                    Icons.history,
                                    color: theme.colorScheme.onSurfaceVariant,
                                    size: 24,
                                  ),
                                ),
                              )
                            : Center(
                                child: Icon(
                                  Icons.history,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  size: 24,
                                ),
                              ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.prompt.isEmpty ? '生成图片' : item.prompt,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: promptStyle,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              timeLabel,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: '更多',
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.more_vert_rounded,
                size: 22,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              onSelected: (value) async {
                switch (value) {
                  case 'regenerate':
                    await onRegenerate();
                  case 'delete':
                    await onDelete();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'regenerate',
                  child: Text('重新生成'),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('删除'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 主壳左侧抽屉：宽度由外层 [Drawer] 指定。
class HistoryTasksDrawer extends ConsumerWidget {
  const HistoryTasksDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 0.5,
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 52,
              child: Padding(
                padding: const EdgeInsets.only(left: 16, right: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '历史任务',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: ((Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.fontSize ??
                                      16) -
                                  2)
                                  .clamp(12.0, double.infinity),
                            ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const Expanded(child: HistoryTasksPanel()),
      ],
    );
  }
}

/// 路由全屏「历史任务」页。
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('历史任务')),
      body: const HistoryTasksPanel(),
    );
  }
}
