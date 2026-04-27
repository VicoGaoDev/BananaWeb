import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../data/task_models.dart';

class GenerateResultPage extends ConsumerWidget {
  const GenerateResultPage({
    super.key,
    required this.task,
  });

  final TaskResult task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageResolver = ref.watch(imageUrlResolverProvider);
    final primaryImage = task.images.isEmpty
        ? ''
        : imageResolver.resolve(
            task.images.first.previewUrl.isNotEmpty
                ? task.images.first.previewUrl
                : task.images.first.imageUrl,
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
          Container(
            height: 284,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(24),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: primaryImage.isEmpty
                  ? const Center(child: Icon(Icons.image_outlined, size: 32))
                  : CachedNetworkImage(
                      imageUrl: primaryImage,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) =>
                          const Center(child: Icon(Icons.broken_image_outlined)),
                    ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ActionIcon(
                icon: Icons.refresh,
                label: '重新生成',
                onTap: () => context.pop(),
              ),
              _ActionIcon(
                icon: Icons.zoom_out_map_outlined,
                label: '高清放大',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('高清放大能力暂未接入')),
                  );
                },
              ),
              _ActionIcon(
                icon: Icons.download_outlined,
                label: '下载',
                onTap: primaryImage.isEmpty
                    ? null
                    : () => context.push(
                          '/preview',
                          extra: {
                            'url': primaryImage,
                            'title': '生成结果',
                          },
                        ),
              ),
              _ActionIcon(
                icon: Icons.share_outlined,
                label: '分享',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('分享能力暂未接入')),
                  );
                },
              ),
              _ActionIcon(
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
          const SizedBox(height: 10),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          if (task.images.length > 1) ...[
            const SizedBox(height: 18),
            SizedBox(
              height: 82,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: task.images.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final image = task.images[index];
                  final imageUrl = imageResolver.resolve(
                    image.previewUrl.isNotEmpty ? image.previewUrl : image.imageUrl,
                  );
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: imageUrl.isEmpty
                        ? null
                        : () => context.push(
                              '/preview',
                              extra: {
                                'url': imageUrl,
                                'title': '结果预览',
                              },
                            ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 82,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: imageUrl.isEmpty
                            ? const Icon(Icons.image_outlined)
                            : CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.broken_image_outlined),
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 18),
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
                _InfoRow(label: '模型', value: task.model),
                _InfoRow(label: '尺寸', value: task.size),
                _InfoRow(label: '状态', value: task.status),
                _InfoRow(label: '生成时间', value: task.createdAt),
                _InfoRow(label: '数量', value: '${task.numImages} 张'),
              ],
            ),
          ),
          if (task.prompt.isNotEmpty) ...[
            const SizedBox(height: 18),
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
                    '提示词',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    task.prompt,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.55,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
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
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: SizedBox(
        width: 60,
        child: Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              textAlign: TextAlign.center,
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
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
