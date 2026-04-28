import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../data/history_models.dart';

class HistoryDetailPage extends ConsumerWidget {
  const HistoryDetailPage({
    super.key,
    required this.item,
  });

  final UserHistoryCardItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageResolver = ref.watch(imageUrlResolverProvider);
    final previewUrl = imageResolver.resolveThumbnailLayers(
      thumbUrl: item.thumbUrl,
      previewUrl: item.previewUrl,
      imageUrl: item.imageUrl,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('生成结果'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.home_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          if (previewUrl.isNotEmpty)
            InkWell(
              onTap: () => context.push(
                '/preview',
                extra: {
                  'url': previewUrl,
                  'title': '任务 ${item.taskId} 预览',
                },
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: AspectRatio(
                  aspectRatio: 1.02,
                  child: CachedNetworkImage(
                    imageUrl: previewUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    errorWidget: (context, url, error) =>
                        const Center(child: Text('图片加载失败')),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ResultAction(
                icon: Icons.refresh,
                label: '重新生成',
                onTap: () => context.go('/'),
              ),
              _ResultAction(
                icon: Icons.zoom_out_map_outlined,
                label: '高清放大',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('高清放大能力暂未接入')),
                  );
                },
              ),
              _ResultAction(
                icon: Icons.download_outlined,
                label: '下载',
                onTap: previewUrl.isEmpty
                    ? null
                    : () => context.push(
                          '/preview',
                          extra: {
                            'url': previewUrl,
                            'title': '图片预览',
                          },
                        ),
              ),
              _ResultAction(
                icon: Icons.share_outlined,
                label: '分享',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('分享能力暂未接入')),
                  );
                },
              ),
              _ResultAction(
                icon: Icons.favorite_border,
                label: '收藏',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('收藏能力暂未接入')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '生成信息',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 14),
                _InfoRow(label: '模型', value: item.model),
                _InfoRow(label: '尺寸', value: item.size),
                _InfoRow(label: '风格', value: item.status),
                _InfoRow(label: '生成时间', value: item.createdAt),
              ],
            ),
          ),
          if (item.prompt.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              '提示词',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              item.prompt,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
            ),
          ],
          if (item.images.length > 1) ...[
            const SizedBox(height: 18),
            Text(
              '更多结果',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 82,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: item.images.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final image = item.images[index];
                  final url = imageResolver.resolveThumbnailLayers(
                    thumbUrl: image.thumbUrl,
                    previewUrl: image.previewUrl,
                    imageUrl: image.imageUrl,
                  );
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: url.isEmpty
                        ? null
                        : () => context.push(
                              '/preview',
                              extra: {
                                'url': url,
                                'title': '图片 #${image.id}',
                              },
                            ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 82,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: url.isEmpty
                            ? const Icon(Icons.image_outlined)
                            : CachedNetworkImage(
                                imageUrl: url,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.image_outlined),
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultAction extends StatelessWidget {
  const _ResultAction({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = onTap == null
        ? Theme.of(context).disabledColor
        : Theme.of(context).colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(child: Text(value.isEmpty ? '-' : value)),
        ],
      ),
    );
  }
}
