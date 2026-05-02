import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../core/network/image_url_resolver.dart';
import '../../home/presentation/home_shell_controller.dart';
import '../data/task_models.dart';
import 'generate_draft_controller.dart';
import 'task_result_common.dart';

/// 单张任务图的可预览大图 URL。
String taskImageFullPreviewUrl(ImageUrlResolver r, GeneratedImage image) {
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

/// 与同页横向缩略列表顺序一致的、非空大图 URL（用于纵向滑动预览）。
List<String> previewFullUrlsForTaskImages(
  ImageUrlResolver resolver,
  List<GeneratedImage> images,
) {
  return [
    for (final im in images) taskImageFullPreviewUrl(resolver, im),
  ].where((u) => u.isNotEmpty).toList();
}

/// 点到第 [tapIndex] 张图时，在 [previewFullUrlsForTaskImages] 里的下标。
int galleryIndexForTaskImageTap(
  ImageUrlResolver r,
  List<GeneratedImage> images,
  int tapIndex,
) {
  if (tapIndex < 0 || tapIndex >= images.length) return 0;
  if (taskImageFullPreviewUrl(r, images[tapIndex]).isEmpty) return 0;
  var g = 0;
  for (var j = 0; j < tapIndex; j++) {
    if (taskImageFullPreviewUrl(r, images[j]).isNotEmpty) g++;
  }
  return g;
}

class GenerateResultPage extends ConsumerWidget {
  const GenerateResultPage({
    super.key,
    required this.task,
  });

  final TaskResult task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageResolver = ref.watch(imageUrlResolverProvider);
    final previewUrls = previewFullUrlsForTaskImages(imageResolver, task.images);
    final openPrimaryUrl = previewUrls.isNotEmpty ? previewUrls.first : '';

    final GeneratedImage? first = task.images.isEmpty ? null : task.images.first;
    final primaryDisplay = first == null
        ? ''
        : imageResolver.resolveThumbnailLayers(
            thumbUrl: first.thumbUrl,
            previewUrl: first.previewUrl,
            imageUrl: first.imageUrl,
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
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: openPrimaryUrl.isEmpty
                  ? null
                  : () => context.push(
                        '/preview',
                        extra: {
                          'urls': previewUrls,
                          'initialIndex': 0,
                          'title': '生成结果',
                        },
                      ),
              child: Container(
                height: 284,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: primaryDisplay.isEmpty
                      ? const Center(child: Icon(Icons.image_outlined, size: 32))
                      : CachedNetworkImage(
                          imageUrl: primaryDisplay,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) =>
                              const Center(child: Icon(Icons.broken_image_outlined)),
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
                onPressed: () {
                  ref.read(generateDraftControllerProvider.notifier).applyFromRegenerate(
                        prompt: task.prompt,
                        model: task.model,
                        numImages: task.numImages,
                        size: task.size,
                        resolution: task.resolution,
                        customSize: task.customSize,
                      );
                  ref.read(homeTabIndexProvider.notifier).state = 1;
                  context.go('/');
                },
                icon: Icon(
                  Icons.refresh,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 40),
              IconButton(
                tooltip: '下载',
                iconSize: 28,
                onPressed: openPrimaryUrl.isEmpty
                    ? null
                    : () => context.push(
                          '/preview',
                          extra: {
                            'urls': previewUrls,
                            'initialIndex': 0,
                            'title': '生成结果',
                          },
                        ),
                icon: Icon(
                  Icons.download_outlined,
                  color: openPrimaryUrl.isEmpty
                      ? Theme.of(context).disabledColor
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          if (task.images.length > 1) ...[
            const SizedBox(height: 18),
            Divider(color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 18),
            SizedBox(
              height: 82,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: task.images.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final image = task.images[index];
                  final displayUrl = imageResolver.resolveThumbnailLayers(
                    thumbUrl: image.thumbUrl,
                    previewUrl: image.previewUrl,
                    imageUrl: image.imageUrl,
                  );
                  final fullUrl = taskImageFullPreviewUrl(imageResolver, image);
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: fullUrl.isEmpty
                        ? null
                        : () => context.push(
                              '/preview',
                              extra: {
                                'urls': previewUrls,
                                'initialIndex': galleryIndexForTaskImageTap(
                                  imageResolver,
                                  task.images,
                                  index,
                                ),
                                'title': '结果预览',
                              },
                            ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 82,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: displayUrl.isEmpty
                            ? const Icon(Icons.image_outlined)
                            : CachedNetworkImage(
                                imageUrl: displayUrl,
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
          TaskGenerationMetaCard(
            modelKey: task.model,
            size: task.size,
            resolution: task.resolution,
            customSize: task.customSize,
            createdAt: task.createdAt,
          ),
          if (task.prompt.trim().isNotEmpty) ...[
            const SizedBox(height: 18),
            TaskPromptCopyCard(prompt: task.prompt),
          ],
        ],
      ),
    );
  }
}
