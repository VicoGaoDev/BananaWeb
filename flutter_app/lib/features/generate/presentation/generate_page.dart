import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/task_scene_repository.dart';
import '../data/task_scene_models.dart';
import 'generate_draft_controller.dart';
import 'reference_upload_controller.dart';
import 'task_controller.dart';

class GeneratePage extends ConsumerStatefulWidget {
  const GeneratePage({super.key});

  @override
  ConsumerState<GeneratePage> createState() => _GeneratePageState();
}

class _GeneratePageState extends ConsumerState<GeneratePage> {
  late final TextEditingController _promptController;
  late final TextEditingController _customSizeController;
  late final FocusNode _promptFocusNode;

  /// 本次会话已发起任务时的提示词（用于聊天区展示；输入框已清空）
  final List<String> _chatSubmittedPrompts = [];

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController();
    _customSizeController = TextEditingController();
    _promptFocusNode = FocusNode()..addListener(_onPromptFocusChanged);
  }

  void _onPromptFocusChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _promptFocusNode
      ..removeListener(_onPromptFocusChanged)
      ..dispose();
    _promptController.dispose();
    _customSizeController.dispose();
    super.dispose();
  }

  Widget _promptField(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: TextField(
        controller: _promptController,
        focusNode: _promptFocusNode,
        minLines: 1,
        maxLines: 4,
        onChanged: (value) {
          ref.read(generateDraftControllerProvider.notifier).updatePrompt(value);
        },
        decoration: const InputDecoration(
          hintText: '描述你想生成的图片...',
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskScenesAsync = ref.watch(taskSceneListProvider);
    final draft = ref.watch(generateDraftControllerProvider);
    final taskFlow = ref.watch(taskControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final uploadState = ref.watch(referenceUploadControllerProvider);
    final imageResolver = ref.watch(imageUrlResolverProvider);

    if (_promptController.text != draft.prompt) {
      _promptController.value = TextEditingValue(
        text: draft.prompt,
        selection: TextSelection.collapsed(offset: draft.prompt.length),
      );
    }

    if (_customSizeController.text != draft.customSize) {
      _customSizeController.value = TextEditingValue(
        text: draft.customSize,
        selection: TextSelection.collapsed(offset: draft.customSize.length),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(taskSceneListProvider);
        await ref.read(taskSceneListProvider.future);
      },
      child: taskScenesAsync.when(
        loading: () => const _LoadingListView(message: '场景配置加载中...'),
        error: (error, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('配置加载失败：$error'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => ref.invalidate(taskSceneListProvider),
              child: const Text('重试'),
            ),
          ],
        ),
        data: (taskScenes) {
          final generateScenes = taskScenes
              .where((item) => item.sceneType == 'generate')
              .toList();
          final selectedScene = _resolveSelectedScene(generateScenes, draft.model);

          if (selectedScene != null &&
              (draft.model.isEmpty || draft.size.isEmpty || draft.resolution.isEmpty)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              ref.read(generateDraftControllerProvider.notifier).ensureDefaults(
                    model: selectedScene.sceneKey,
                    size: selectedScene.aspectRatioOptions.isNotEmpty
                        ? selectedScene.aspectRatioOptions.first.value
                        : '1:1',
                    resolution: selectedScene.imageSizeOptions.isNotEmpty
                        ? selectedScene.imageSizeOptions.first.value
                        : '2K',
                  );
            });
          }

          final currentModel = selectedScene?.sceneKey ?? draft.model;
          final currentSize = _resolveSelection(
            currentValue: draft.size,
            options: selectedScene?.aspectRatioOptions.map((item) => item.value).toList() ?? const [],
          );
          final currentResolution = _resolveSelection(
            currentValue: draft.resolution,
            options: selectedScene?.imageSizeOptions.map((item) => item.value).toList() ?? const [],
          );
          final latestTask = taskFlow.latestTask;
          final firstGenImage =
              (latestTask != null && latestTask.images.isNotEmpty) ? latestTask.images.first : null;
          var resolvedThumb = '';
          var resolvedFull = '';
          if (firstGenImage != null) {
            if (firstGenImage.thumbUrl.isNotEmpty) {
              resolvedThumb = imageResolver.resolve(firstGenImage.thumbUrl);
            } else if (firstGenImage.previewUrl.isNotEmpty) {
              resolvedThumb = imageResolver.resolve(firstGenImage.previewUrl);
            } else if (firstGenImage.imageUrl.isNotEmpty) {
              resolvedThumb = imageResolver.resolve(firstGenImage.imageUrl);
            }
            if (firstGenImage.imageUrl.isNotEmpty) {
              resolvedFull = imageResolver.resolve(firstGenImage.imageUrl);
            } else if (firstGenImage.previewUrl.isNotEmpty) {
              resolvedFull = imageResolver.resolve(firstGenImage.previewUrl);
            } else {
              resolvedFull = resolvedThumb;
            }
          }
          final hasCompletedImage = latestTask != null &&
              latestTask.status == 'success' &&
              resolvedThumb.isNotEmpty;
          final showGeneratingSkeleton = taskFlow.isSubmitting ||
              (latestTask?.status != 'failed' &&
                  taskFlow.isPolling &&
                  !hasCompletedImage);

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 128),
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => context.go('/'),
                          icon: const Icon(Icons.auto_awesome, size: 18),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'AI 生图',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          onPressed: taskFlow.isPolling
                              ? () => ref.read(taskControllerProvider.notifier).pollOnce()
                              : null,
                          icon: const Icon(Icons.history_toggle_off, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const _AssistantBubble(
                    text: '你好! 我是你的 AI 绘图助手\n描述你的想法，我来帮你生成图片。',
                  ),
                  const SizedBox(height: 12),
                  if (draft.prompt.trim().isEmpty &&
                      !showGeneratingSkeleton &&
                      !hasCompletedImage)
                    Padding(
                      padding: const EdgeInsets.only(left: 38, bottom: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _SuggestionChip(
                            label: '赛博城市雨夜',
                            onTap: () => _applySuggestion('赛博城市雨夜，霓虹灯映照湿润街道，电影感，高细节'),
                          ),
                          _SuggestionChip(
                            label: '国风山水',
                            onTap: () => _applySuggestion('国风山水，云雾缭绕，留白构图，水墨质感'),
                          ),
                          _SuggestionChip(
                            label: '人像写真',
                            onTap: () => _applySuggestion('电影级人像写真，柔光，干净背景，真实肤质'),
                          ),
                        ],
                      ),
                    ),
                  if (draft.templateId != null)
                    _UserBubble(
                      text: draft.templatePrompt?.isNotEmpty == true
                          ? '使用模板开始创作：${draft.templatePrompt}'
                          : '已带入模板参数，准备开始创作。',
                    ),
                  if (draft.templateId != null) const SizedBox(height: 12),
                  for (final line in _chatSubmittedPrompts) ...[
                    _UserBubble(text: line),
                    const SizedBox(height: 12),
                  ],
                  if (showGeneratingSkeleton) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: const _GeneratingImageSkeleton(),
                    ),
                  ] else if (hasCompletedImage) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _ChatResultThumb(
                        thumbUrl: resolvedThumb,
                        onTap: () {
                          if (resolvedFull.isEmpty) return;
                          context.push(
                            '/preview',
                            extra: {
                              'url': resolvedFull,
                              'title': '生成结果',
                            },
                          );
                        },
                      ),
                    ),
                  ],
                  if (taskFlow.infoMessage != null && !showGeneratingSkeleton && !hasCompletedImage) ...[
                    const SizedBox(height: 12),
                    Text(
                      taskFlow.infoMessage!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                  if (taskFlow.errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      taskFlow.errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ],
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (uploadState.images.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: SizedBox(
                              height: 56,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: uploadState.images.length,
                                separatorBuilder: (context, index) => const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final item = uploadState.images[index];
                                  final url = imageResolver.resolve(item.remoteUrl);
                                  return Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          url,
                                          width: 56,
                                          height: 56,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: -6,
                                        right: -6,
                                        child: IconButton(
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () => ref
                                              .read(referenceUploadControllerProvider.notifier)
                                              .removeAt(index),
                                          icon: const Icon(Icons.cancel, size: 18),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        if (_promptFocusNode.hasFocus || draft.prompt.trim().isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _promptField(context, ref),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _ComposerIconButton(
                                    icon: Icons.tune,
                                    onTap: () => _showConfigSheet(
                                      context: context,
                                      generateScenes: generateScenes,
                                      selectedScene: selectedScene,
                                      currentModel: currentModel,
                                      currentSize: currentSize,
                                      currentResolution: currentResolution,
                                      draft: draft,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      selectedScene?.displayName.isNotEmpty == true
                                          ? selectedScene!.displayName
                                          : (selectedScene?.sceneLabel.isNotEmpty == true
                                              ? selectedScene!.sceneLabel
                                              : (draft.model.isNotEmpty
                                                  ? draft.model
                                                  : '未选择模型')),
                                      textAlign: TextAlign.right,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  _ComposerIconButton(
                                    icon: uploadState.isUploading
                                        ? null
                                        : Icons.add_photo_alternate_outlined,
                                    loading: uploadState.isUploading,
                                    onTap: uploadState.isUploading
                                        ? null
                                        : () async {
                                            if (!authState.isAuthenticated) {
                                              context.push('/login');
                                              return;
                                            }
                                            await ref
                                                .read(
                                                  referenceUploadControllerProvider.notifier,
                                                )
                                                .pickAndUpload();
                                          },
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: const BoxDecoration(
                                      color: Colors.black,
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      onPressed: taskFlow.isSubmitting
                                          ? null
                                          : () => _submitTask(
                                                context: context,
                                                authState: authState,
                                                selectedScene: selectedScene,
                                                draft: draft,
                                              ),
                                      icon: const Icon(
                                        Icons.send_rounded,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: _promptField(context, ref),
                              ),
                              const SizedBox(width: 8),
                              _ComposerIconButton(
                                icon: Icons.tune,
                                onTap: () => _showConfigSheet(
                                  context: context,
                                  generateScenes: generateScenes,
                                  selectedScene: selectedScene,
                                  currentModel: currentModel,
                                  currentSize: currentSize,
                                  currentResolution: currentResolution,
                                  draft: draft,
                                ),
                              ),
                              const SizedBox(width: 6),
                              _ComposerIconButton(
                                icon: uploadState.isUploading
                                    ? null
                                    : Icons.add_photo_alternate_outlined,
                                loading: uploadState.isUploading,
                                onTap: uploadState.isUploading
                                    ? null
                                    : () async {
                                        if (!authState.isAuthenticated) {
                                          context.push('/login');
                                          return;
                                        }
                                        await ref
                                            .read(referenceUploadControllerProvider.notifier)
                                            .pickAndUpload();
                                      },
                              ),
                              Container(
                                width: 42,
                                height: 42,
                                decoration: const BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  onPressed: taskFlow.isSubmitting
                                      ? null
                                      : () => _submitTask(
                                            context: context,
                                            authState: authState,
                                            selectedScene: selectedScene,
                                            draft: draft,
                                          ),
                                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                                ),
                              ),
                            ],
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
    );
  }

  Future<void> _showConfigSheet({
    required BuildContext context,
    required List<TaskSceneConfig> generateScenes,
    required TaskSceneConfig? selectedScene,
    required String currentModel,
    required String currentSize,
    required String currentResolution,
    required GenerateDraftState draft,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final modalScene = _resolveSelectedScene(
              generateScenes,
              ref.read(generateDraftControllerProvider).model,
            );
            final modalSize = _resolveSelection(
              currentValue: ref.read(generateDraftControllerProvider).size,
              options: modalScene?.aspectRatioOptions.map((item) => item.value).toList() ?? const [],
            );
            final modalResolution = _resolveSelection(
              currentValue: ref.read(generateDraftControllerProvider).resolution,
              options: modalScene?.imageSizeOptions.map((item) => item.value).toList() ?? const [],
            );

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Spacer(),
                          Text(
                            '配置',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '模型',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: currentModel.isEmpty ? null : currentModel,
                        items: generateScenes
                            .map(
                              (scene) => DropdownMenuItem(
                                value: scene.sceneKey,
                                child: Text(
                                  scene.displayName.isEmpty
                                      ? scene.sceneLabel
                                      : scene.displayName,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          final nextScene = _resolveSelectedScene(generateScenes, value);
                          ref.read(generateDraftControllerProvider.notifier)
                            ..updateModel(value)
                            ..updateSize(
                              nextScene?.aspectRatioOptions.isNotEmpty ?? false
                                  ? nextScene!.aspectRatioOptions.first.value
                                  : draft.size,
                            )
                            ..updateResolution(
                              nextScene?.imageSizeOptions.isNotEmpty ?? false
                                  ? nextScene!.imageSizeOptions.first.value
                                  : draft.resolution,
                            );
                          setModalState(() {});
                        },
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '尺寸',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final option in modalScene?.aspectRatioOptions ?? const [])
                            _SelectableChip(
                              label: option.label,
                              selected: modalSize == option.value,
                              onTap: () {
                                ref
                                    .read(generateDraftControllerProvider.notifier)
                                    .updateSize(option.value);
                                setModalState(() {});
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '分辨率',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final option in modalScene?.imageSizeOptions ?? const [])
                            _SelectableChip(
                              label: option.label,
                              selected: modalResolution == option.value,
                              onTap: () {
                                ref
                                    .read(generateDraftControllerProvider.notifier)
                                    .updateResolution(option.value);
                                setModalState(() {});
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '参考图',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final item in ref.watch(referenceUploadControllerProvider).images)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(
                                ref.read(imageUrlResolverProvider).resolve(item.remoteUrl),
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                              ),
                            ),
                          InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () async {
                              final authState = ref.read(authControllerProvider);
                              if (!authState.isAuthenticated) {
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                  context.push('/login');
                                }
                                return;
                              }
                              await ref
                                  .read(referenceUploadControllerProvider.notifier)
                                  .pickAndUpload();
                              setModalState(() {});
                            },
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outlineVariant,
                                ),
                              ),
                              child: const Icon(Icons.add),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _customSizeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '高级设置 / 自定义尺寸',
                          hintText: '例如 1024x1024',
                        ),
                        onChanged: (value) {
                          ref
                              .read(generateDraftControllerProvider.notifier)
                              .updateCustomSize(value);
                        },
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('确定'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _applySuggestion(String value) {
    _promptController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    ref.read(generateDraftControllerProvider.notifier).updatePrompt(value);
  }

  Future<void> _submitTask({
    required BuildContext context,
    required AuthState authState,
    required TaskSceneConfig? selectedScene,
    required GenerateDraftState draft,
  }) async {
    if (!authState.isAuthenticated) {
      if (mounted) {
        context.push('/login');
      }
      return;
    }

    if (draft.prompt.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先填写提示词')),
      );
      return;
    }

    if (selectedScene == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前没有可用的生成场景')),
      );
      return;
    }

    final promptText = draft.prompt.trim();
    final success = await ref.read(taskControllerProvider.notifier).createTask(
          model: selectedScene.sceneKey,
          prompt: promptText,
          numImages: draft.numImages,
          size: _resolveSelection(
            currentValue: draft.size,
            options: selectedScene.aspectRatioOptions.map((item) => item.value).toList(),
          ),
          resolution: _resolveSelection(
            currentValue: draft.resolution,
            options: selectedScene.imageSizeOptions.map((item) => item.value).toList(),
          ),
          customSize: draft.customSize.trim(),
          referenceImages: ref
              .read(referenceUploadControllerProvider)
              .images
              .map((item) => item.remoteUrl)
              .toList(),
        );

    if (!context.mounted) {
      return;
    }
    if (success) {
      setState(() {
        _chatSubmittedPrompts.add(promptText);
      });
      ref.read(generateDraftControllerProvider.notifier).updatePrompt('');
      _promptController.value = const TextEditingValue();
      _promptFocusNode.unfocus();
    }
  }

  TaskSceneConfig? _resolveSelectedScene(
    List<TaskSceneConfig> generateScenes,
    String selectedModel,
  ) {
    if (generateScenes.isEmpty) {
      return null;
    }

    return generateScenes.cast<TaskSceneConfig?>().firstWhere(
          (scene) => scene?.sceneKey == selectedModel,
          orElse: () => generateScenes.first,
        );
  }

  String _resolveSelection({
    required String currentValue,
    required List<String> options,
  }) {
    if (currentValue.isNotEmpty && options.contains(currentValue)) {
      return currentValue;
    }
    if (options.isNotEmpty) {
      return options.first;
    }
    return '';
  }
}

class _GeneratingImageSkeleton extends StatelessWidget {
  const _GeneratingImageSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      width: 200,
      height: 120,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: c.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.outlineVariant),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: c.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '图片生成中…',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: c.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

class _ChatResultThumb extends StatelessWidget {
  const _ChatResultThumb({
    required this.thumbUrl,
    required this.onTap,
  });

  final String thumbUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outlineVariant;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 200,
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: outline),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: thumbUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '全屏',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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

class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(6),
              ),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ),
        ),
      ],
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 248),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(6),
          ),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                height: 1.45,
              ),
        ),
      ),
    );
  }
}

class _SelectableChip extends StatelessWidget {
  const _SelectableChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.black : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({
    required this.onTap,
    this.icon,
    this.loading = false,
  });

  final VoidCallback? onTap;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: loading
            ? const Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, size: 18),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4F4),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
      ),
    );
  }
}
