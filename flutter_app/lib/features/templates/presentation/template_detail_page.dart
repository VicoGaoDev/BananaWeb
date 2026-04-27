import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../generate/data/task_scene_models.dart';
import '../../generate/data/task_scene_repository.dart';
import '../../generate/presentation/generate_draft_controller.dart';
import '../../home/presentation/home_shell_controller.dart';
import '../data/template_repository.dart';

String _modelDisplayName(String modelKey, List<TaskSceneConfig> scenes) {
  if (modelKey.isEmpty) return '';
  for (final s in scenes) {
    if (s.sceneKey == modelKey) {
      if (s.displayName.isNotEmpty) return s.displayName;
      if (s.sceneLabel.isNotEmpty) return s.sceneLabel;
    }
  }
  return modelKey;
}

class TemplateDetailPage extends ConsumerWidget {
  const TemplateDetailPage({
    super.key,
    required this.templateId,
  });

  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parsedId = int.tryParse(templateId);
    final imageResolver = ref.watch(imageUrlResolverProvider);
    final scenesAsync = ref.watch(taskSceneListProvider);

    final appBar = AppBar(
      title: const Text(''),
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('分享功能暂未接入')),
                );
              },
              icon: const Icon(Icons.ios_share_outlined, size: 18),
            ),
          ),
        ),
      ],
    );

    if (parsedId == null) {
      return Scaffold(
        appBar: appBar,
        body: Center(
          child: Text('无效的模板 ID：$templateId'),
        ),
      );
    }

    return ref.watch(templateDetailProvider(parsedId)).when(
          loading: () => Scaffold(
            appBar: appBar,
            body: const Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Scaffold(
            appBar: appBar,
            body: Center(child: Text('模板加载失败：$error')),
          ),
          data: (template) {
            final coverUrl = imageResolver.resolve(
              template.resultImage.isNotEmpty
                  ? template.resultImage
                  : template.resultImageThumb,
            );
            final modelLabel = scenesAsync.maybeWhen(
              data: (scenes) => _modelDisplayName(template.model, scenes),
              orElse: () => template.model,
            );
            final modelForCopy = modelLabel.isNotEmpty
                ? modelLabel
                : (template.model.isEmpty ? '图像生成' : template.model);

            return Scaffold(
              appBar: appBar,
              body: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  if (coverUrl.isNotEmpty)
                    InkWell(
                      onTap: () => context.push(
                        '/preview',
                        extra: {
                          'url': coverUrl,
                          'title': '模板 ${template.id}',
                        },
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: AspectRatio(
                          aspectRatio: 1.18,
                          child: CachedNetworkImage(
                            imageUrl: coverUrl,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) =>
                                const Center(child: Icon(Icons.image_outlined, size: 32)),
                          ),
                        ),
                      ),
                    ),
                  if (coverUrl.isNotEmpty) const SizedBox(height: 16),
                  if (template.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: template.tags
                            .take(3)
                            .map(
                              (tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  tag.name,
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  Text(
                    template.prompt.isEmpty ? '未命名模板' : template.prompt,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.45,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department_outlined, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${(template.id * 137).toStringAsFixed(0)} 人使用',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        template.tags.isEmpty ? '默认分类' : template.tags.first.name,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '适合生成具有同类美感取向的内容，尤其适合 $modelForCopy 风格。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.55,
                        ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      children: [
                        _SpecRow(
                          label: '模型',
                          value: modelLabel.isNotEmpty ? modelLabel : template.model,
                        ),
                        _SpecRow(label: '尺寸', value: template.size),
                        _SpecRow(label: '分辨率', value: template.resolution),
                        _SpecRow(
                          label: '标签',
                          value: template.tags.map((tag) => tag.name).join(' / '),
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: Material(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      child: FilledButton.icon(
                        onPressed: () {
                          ref
                              .read(generateDraftControllerProvider.notifier)
                              .applyTemplate(template);
                          ref.read(homeTabIndexProvider.notifier).state = 1;
                          context.go('/');
                        },
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('使用模板'),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
              ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(value.isEmpty ? '-' : value),
          ),
        ],
      ),
    );
  }
}
