import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../core/network/image_url_resolver.dart';
import '../../generate/presentation/generate_draft_controller.dart';
import '../../generate/presentation/task_result_common.dart';
import '../../home/presentation/home_shell_controller.dart';
import '../data/history_models.dart';

String _historyImageFullUrl(ImageUrlResolver r, HistoryImage image) {
  var full = r.resolveFullImageLayers(
    imageUrl: image.imageUrl,
    previewUrl: image.previewUrl,
    thumbUrl: image.thumbUrl,
  );
  if (full.isEmpty) {
    full = r.resolveThumbnailLayers(
      thumbUrl: image.thumbUrl,
      previewUrl: image.previewUrl,
      imageUrl: image.imageUrl,
    );
  }
  return full.trim();
}

/// 与同页条目顺序一致的非空大图 URL。
List<String> _historyGalleryFullUrls(ImageUrlResolver r, UserHistoryCardItem item) {
  if (item.images.isNotEmpty) {
    return [
      for (final im in item.images) _historyImageFullUrl(r, im),
    ].where((u) => u.isNotEmpty).toList();
  }
  final displayUrl = r.resolveThumbnailLayers(
    thumbUrl: item.thumbUrl,
    previewUrl: item.previewUrl,
    imageUrl: item.imageUrl,
  );
  var solo = r.resolveFullImageLayers(
    imageUrl: item.imageUrl,
    previewUrl: item.previewUrl,
    thumbUrl: item.thumbUrl,
  );
  if (solo.isEmpty) solo = displayUrl;
  return solo.trim().isNotEmpty ? [solo.trim()] : <String>[];
}

int _historyGalleryTapIndex(ImageUrlResolver r, UserHistoryCardItem item, int tapIndex) {
  if (item.images.isEmpty) return 0;
  if (tapIndex < 0 || tapIndex >= item.images.length) return 0;
  if (_historyImageFullUrl(r, item.images[tapIndex]).isEmpty) return 0;
  var g = 0;
  for (var j = 0; j < tapIndex; j++) {
    if (_historyImageFullUrl(r, item.images[j]).isNotEmpty) g++;
  }
  return g;
}

class HistoryDetailPage extends ConsumerWidget {
  const HistoryDetailPage({
    super.key,
    required this.item,
  });

  final UserHistoryCardItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageResolver = ref.watch(imageUrlResolverProvider);
    final galleryUrls = _historyGalleryFullUrls(imageResolver, item);
    final displayUrl = imageResolver.resolveThumbnailLayers(
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
          if (displayUrl.isNotEmpty)
            InkWell(
              onTap: galleryUrls.isEmpty
                  ? null
                  : () => context.push(
                        '/preview',
                        extra: {
                          'urls': galleryUrls,
                          'initialIndex': 0,
                          'title': '任务 ${item.taskId} 预览',
                        },
                      ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: AspectRatio(
                  aspectRatio: 1.02,
                  child: CachedNetworkImage(
                    imageUrl: displayUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    errorWidget: (context, url, error) => Center(
                      child: Text(
                        '图片加载失败',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: '重新生成',
                iconSize: 28,
                onPressed: item.mode != 'generate' || item.prompt.trim().isEmpty
                    ? null
                    : () {
                        ref.read(generateDraftControllerProvider.notifier).applyFromRegenerate(
                              prompt: item.prompt.trim(),
                              model: item.model,
                              numImages: item.numImages < 1 ? 1 : item.numImages,
                              size: item.size,
                              resolution: item.resolution,
                              customSize: item.customSize.trim(),
                            );
                        ref.read(homeTabIndexProvider.notifier).state = 1;
                        context.go('/');
                      },
                icon: Icon(
                  Icons.refresh,
                  color: item.mode != 'generate' || item.prompt.trim().isEmpty
                      ? Theme.of(context).disabledColor
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 40),
              IconButton(
                tooltip: '下载',
                iconSize: 28,
                onPressed: galleryUrls.isEmpty
                    ? null
                    : () => context.push(
                          '/preview',
                          extra: {
                            'urls': galleryUrls,
                            'initialIndex': 0,
                            'title': '图片预览',
                          },
                        ),
                icon: Icon(
                  Icons.download_outlined,
                  color: galleryUrls.isEmpty
                      ? Theme.of(context).disabledColor
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          if (item.images.length > 1) ...[
            const SizedBox(height: 18),
            Divider(color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 18),
            SizedBox(
              height: 82,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: item.images.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final image = item.images[index];
                  final thumb = imageResolver.resolveThumbnailLayers(
                    thumbUrl: image.thumbUrl,
                    previewUrl: image.previewUrl,
                    imageUrl: image.imageUrl,
                  );
                  final full = _historyImageFullUrl(imageResolver, image);
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: full.isEmpty
                        ? null
                        : () => context.push(
                              '/preview',
                              extra: {
                                'urls': galleryUrls,
                                'initialIndex': _historyGalleryTapIndex(
                                  imageResolver,
                                  item,
                                  index,
                                ),
                                'title': '图片 #${image.id}',
                              },
                            ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 82,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: thumb.isEmpty
                            ? const Icon(Icons.image_outlined)
                            : CachedNetworkImage(
                                imageUrl: thumb,
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
          const SizedBox(height: 18),
          TaskGenerationMetaCard(
            modelKey: item.model,
            size: item.size,
            resolution: item.resolution,
            customSize: item.customSize,
            createdAt: item.createdAt,
          ),
          if (item.prompt.trim().isNotEmpty) ...[
            const SizedBox(height: 18),
            TaskPromptCopyCard(prompt: item.prompt),
          ],
        ],
      ),
    );
  }
}
