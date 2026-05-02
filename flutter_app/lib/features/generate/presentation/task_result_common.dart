import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/task_scene_models.dart';
import '../data/task_scene_repository.dart';

DateTime? _parseTaskCreatedAtLocal(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  try {
    return DateTime.parse(t).toLocal();
  } catch (_) {
    return null;
  }
}

/// 与历史列表一致的任务生成时间可读格式。
String formatTaskCreatedAtDisplay(String raw) {
  final dt = _parseTaskCreatedAtLocal(raw);
  if (dt == null) return raw.trim().isEmpty ? '—' : raw;

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final yesterdayStart = todayStart.subtract(const Duration(days: 1));
  final dayStart = DateTime(dt.year, dt.month, dt.day);

  String two(int n) => n.toString().padLeft(2, '0');
  final hm = '${two(dt.hour)}:${two(dt.minute)}';

  if (dayStart == todayStart) {
    return '今天 $hm';
  }
  if (dayStart == yesterdayStart) {
    return '昨天 $hm';
  }
  if (dt.year == now.year) {
    return '${dt.month}月${dt.day}日 $hm';
  }
  return '${dt.year}-${two(dt.month)}-${two(dt.day)} $hm';
}

String labelForSceneOption(List<SceneOptionItem> options, String value) {
  final v = value.trim();
  if (v.isEmpty) return '';
  for (final o in options) {
    if (o.value == v) return o.label.isNotEmpty ? o.label : o.value;
  }
  return v;
}

TaskSceneConfig? _findGenerateScene(List<TaskSceneConfig> scenes, String modelKey) {
  final key = modelKey.trim();
  if (key.isEmpty) return null;
  for (final s in scenes) {
    if (s.sceneType == 'generate' && s.sceneKey == key) return s;
  }
  return null;
}

/// 生成结果页：模型（显示名）、按场景控制展示的尺寸/分辨率/自定义尺寸、生成时间。
class TaskGenerationMetaCard extends ConsumerWidget {
  const TaskGenerationMetaCard({
    super.key,
    required this.modelKey,
    required this.size,
    required this.resolution,
    required this.customSize,
    required this.createdAt,
  });

  final String modelKey;
  final String size;
  final String resolution;
  final String customSize;
  final String createdAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    Widget cardBody(List<TaskSceneConfig> scenes) {
      final scene = _findGenerateScene(scenes, modelKey);
      final modelDisplay = scene?.displayName.isNotEmpty == true
          ? scene!.displayName
          : (scene?.sceneLabel.isNotEmpty == true
              ? scene!.sceneLabel
              : (modelKey.trim().isEmpty ? '—' : modelKey));

      final children = <Widget>[
        _MetaInfoRow(label: '模型', value: modelDisplay),
      ];

      if (scene != null) {
        if (!scene.hideAspectRatio && size.trim().isNotEmpty) {
          children.add(
            _MetaInfoRow(
              label: '尺寸',
              value: labelForSceneOption(scene.aspectRatioOptions, size),
            ),
          );
        }
        if (!scene.hideResolution && resolution.trim().isNotEmpty) {
          children.add(
            _MetaInfoRow(
              label: '分辨率',
              value: labelForSceneOption(scene.imageSizeOptions, resolution),
            ),
          );
        }
        if (!scene.hideCustomSize && customSize.trim().isNotEmpty) {
          children.add(
            _MetaInfoRow(
              label: '自定义尺寸',
              value: labelForSceneOption(scene.customSizeOptions, customSize),
            ),
          );
        }
      } else {
        if (size.trim().isNotEmpty) {
          children.add(_MetaInfoRow(label: '尺寸', value: size.trim()));
        }
        if (resolution.trim().isNotEmpty) {
          children.add(_MetaInfoRow(label: '分辨率', value: resolution.trim()));
        }
        if (customSize.trim().isNotEmpty) {
          children.add(_MetaInfoRow(label: '自定义尺寸', value: customSize.trim()));
        }
      }

      children.add(
        _MetaInfoRow(label: '生成时间', value: formatTaskCreatedAtDisplay(createdAt)),
      );

      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '生成消息',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      );
    }

    return ref.watch(taskSceneListProvider).when(
          data: cardBody,
          loading: () => Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scheme.outlineVariant),
            ),
            alignment: Alignment.centerLeft,
            child: Text(
              '配置加载中…',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
          error: (_, __) => cardBody(const []),
        );
  }
}

class TaskPromptCopyCard extends StatelessWidget {
  const TaskPromptCopyCard({
    super.key,
    required this.prompt,
  });

  final String prompt;

  @override
  Widget build(BuildContext context) {
    final p = prompt.trim();
    if (p.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 8, 18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '提示词',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              IconButton(
                tooltip: '复制',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: p));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制到剪贴板')),
                  );
                },
                icon: Icon(
                  Icons.copy_outlined,
                  color: scheme.onSurfaceVariant,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            p,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.55,
                ),
          ),
        ],
      ),
    );
  }
}

class _MetaInfoRow extends StatelessWidget {
  const _MetaInfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final v = value.trim().isEmpty ? '—' : value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
