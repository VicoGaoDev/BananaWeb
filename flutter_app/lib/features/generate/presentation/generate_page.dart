import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../core/theme/app_typography_extension.dart';
import '../../../shared/widgets/shell_tab_header.dart';
import '../../../shared/widgets/smooth_async_switcher.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/task_scene_repository.dart';
import '../data/task_scene_models.dart';
import 'generate_chat_turns_controller.dart';
import 'generate_draft_controller.dart';
import 'reference_upload_controller.dart';
import 'task_controller.dart';

String _chatPreviewOpenUrl(GenerateChatTurnResultImage img) {
  final f = img.fullImageUrl.trim();
  if (f.isNotEmpty) return f;
  return img.displayUrl.trim();
}

List<String> _chatTurnGalleryUrls(List<GenerateChatTurnResultImage> imgs) {
  return [
    for (final img in imgs) _chatPreviewOpenUrl(img),
  ].where((u) => u.isNotEmpty).toList();
}

int _chatGalleryIndexForTap(List<GenerateChatTurnResultImage> imgs, int tapIndex) {
  if (tapIndex < 0 || tapIndex >= imgs.length) return 0;
  if (_chatPreviewOpenUrl(imgs[tapIndex]).isEmpty) return 0;
  var g = 0;
  for (var j = 0; j < tapIndex; j++) {
    if (_chatPreviewOpenUrl(imgs[j]).isNotEmpty) g++;
  }
  return g;
}

/// 用户提示词气泡与图片区共用最大宽度（与聊天气泡上限 248 一致；窄屏随列表内宽变窄）。
double _chatBubbleImageMaxWidth(BuildContext context) {
  final screenW = MediaQuery.sizeOf(context).width;
  const listHorizontalPadding = 32.0;
  final inner = screenW - listHorizontalPadding;
  if (inner <= 0) return 120.0;
  return inner < 248.0 ? inner : 248.0;
}

bool _draftNeedsSceneSync(GenerateDraftState d, TaskSceneConfig s) {
  if (d.model.isEmpty) return true;
  if (!s.hideAspectRatio && s.aspectRatioOptions.isNotEmpty) {
    if (d.size.isEmpty || !s.aspectRatioOptions.any((o) => o.value == d.size)) {
      return true;
    }
  }
  if (s.hideAspectRatio && d.size.isNotEmpty) return true;
  if (!s.hideResolution && s.imageSizeOptions.isNotEmpty) {
    if (d.resolution.isEmpty ||
        !s.imageSizeOptions.any((o) => o.value == d.resolution)) {
      return true;
    }
  }
  if (s.hideResolution && d.resolution.isNotEmpty) return true;
  if (!s.hideCustomSize && s.customSizeOptions.isNotEmpty) {
    if (d.customSize.isEmpty ||
        !s.customSizeOptions.any((o) => o.value == d.customSize)) {
      return true;
    }
  }
  if (s.hideCustomSize && d.customSize.isNotEmpty) return true;
  return false;
}

/// 配置页：居中圆角卡片列表（不占满屏宽），用于替代全宽下拉菜单。
Future<void> showConfigCardPicker({
  required BuildContext context,
  required String title,
  required List<({String value, String label})> options,
  required String currentValue,
  required ValueChanged<String> onPick,
}) async {
  final mqSize = MediaQuery.sizeOf(context);
  final mqPad = MediaQuery.paddingOf(context);
  final maxW = (mqSize.width - 48).clamp(280.0, 400.0);
  final maxListH = mqSize.height * 0.45;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      final sheetH = MediaQuery.sizeOf(ctx).height;
      return SizedBox(
        width: double.infinity,
        height: sheetH,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(ctx),
                child: const ColoredBox(color: Color(0x00000000)),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: mqPad.bottom + 16,
                ),
                child: Center(
                  child: Material(
                    elevation: 10,
                    surfaceTintColor: scheme.surfaceTint,
                    shadowColor: Colors.black38,
                    borderRadius: BorderRadius.circular(20),
                    clipBehavior: Clip.antiAlias,
                    color: scheme.surface,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxW),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 14, 4, 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  icon: const Icon(Icons.close),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          ),
                          Divider(height: 1, color: Theme.of(ctx).dividerColor),
                          ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: maxListH),
                            child: ListView.builder(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              itemCount: options.length,
                              itemBuilder: (c, i) {
                                final o = options[i];
                                final sel = o.value == currentValue;
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 4,
                                  ),
                                  minTileHeight: 52,
                                  title: Text(o.label),
                                  trailing: sel
                                      ? Icon(
                                          Icons.check_circle,
                                          color: scheme.primary,
                                          size: 22,
                                        )
                                      : null,
                                  onTap: () {
                                    onPick(o.value);
                                    Navigator.pop(ctx);
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class GeneratePage extends ConsumerStatefulWidget {
  const GeneratePage({super.key});

  @override
  ConsumerState<GeneratePage> createState() => _GeneratePageState();
}

class _GeneratePageState extends ConsumerState<GeneratePage> {
  late final TextEditingController _promptController;
  late final FocusNode _promptFocusNode;
  late final ScrollController _chatScrollController;
  bool _chatHydrateScheduled = false;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController();
    _promptFocusNode = FocusNode()..addListener(_onPromptFocusChanged);
    _chatScrollController = ScrollController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_chatHydrateScheduled) return;
    _chatHydrateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(generateChatTurnsProvider.notifier).hydrateIfEmpty();
    });
  }

  void _onPromptFocusChanged() {
    setState(() {});
  }

  /// 历史加载或首条消息后滚到聊天列表底部（等列表完成布局后再滚）。
  void _scrollChatToBottom() {
    void jump() {
      if (!mounted) return;
      if (!_chatScrollController.hasClients) return;
      final pos = _chatScrollController.position;
      _chatScrollController.jumpTo(
        pos.maxScrollExtent.clamp(pos.minScrollExtent, pos.maxScrollExtent),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      jump();
      WidgetsBinding.instance.addPostFrameCallback((_) => jump());
    });
  }

  @override
  void dispose() {
    _promptFocusNode
      ..removeListener(_onPromptFocusChanged)
      ..dispose();
    _promptController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Widget _promptField(BuildContext context, WidgetRef ref, GenerateDraftState draft) {
    final scheme = Theme.of(context).colorScheme;
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
        decoration: InputDecoration(
          hintText: '描述你想生成的图片...',
          hintStyle: AppTypographyTokens.of(context).composerBody.copyWith(
                color: Theme.of(context).hintColor,
              ),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          suffixIcon: draft.prompt.isEmpty
              ? null
              : IconButton(
                  tooltip: '清除',
                  onPressed: () {
                    _promptController.clear();
                    ref.read(generateDraftControllerProvider.notifier).updatePrompt('');
                    setState(() {});
                  },
                  icon: Icon(
                    Icons.cancel_rounded,
                    size: 22,
                    color: scheme.onSurfaceVariant,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
        ),
        style: AppTypographyTokens.of(context).composerBody,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskScenesAsync = ref.watch(taskSceneListProvider);
    final draft = ref.watch(generateDraftControllerProvider);
    final taskFlow = ref.watch(taskControllerProvider);
    final chatTurns = ref.watch(generateChatTurnsProvider);
    final authState = ref.watch(authControllerProvider);
    final uploadState = ref.watch(referenceUploadControllerProvider);
    final imageResolver = ref.watch(imageUrlResolverProvider);

    ref.listen<TaskFlowState>(taskControllerProvider, (_, next) {
      ref
          .read(generateChatTurnsProvider.notifier)
          .syncFromTaskFlow(next, imageResolver);
    });

    // 首帧 hydrate 往往在会话恢复完成之前执行，需在就绪后重试。
    ref.listen<AuthState>(authControllerProvider, (_, next) {
      if (!next.isAuthenticated || next.isInitializing) return;
      ref.read(generateChatTurnsProvider.notifier).hydrateIfEmpty();
    });

    ref.listen<List<GenerateChatTurn>>(generateChatTurnsProvider, (prev, next) {
      if (next.isEmpty) return;
      final wasEmpty = prev == null || prev.isEmpty;
      if (!wasEmpty) return;
      _scrollChatToBottom();
    });

    if (_promptController.text != draft.prompt) {
      _promptController.value = TextEditingValue(
        text: draft.prompt,
        selection: TextSelection.collapsed(offset: draft.prompt.length),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: ShellTabHeader(
            onHistory: () {
              if (taskFlow.isPolling) {
                ref.read(taskControllerProvider.notifier).pollOnce();
              }
              Scaffold.of(context).openDrawer();
            },
            creditsValue: authState.user?.credits ?? 0,
            authenticated: authState.isAuthenticated,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(taskSceneListProvider);
              await ref.read(taskSceneListProvider.future);
            },
            child: SmoothAsyncSwitcher<List<TaskSceneConfig>>(
              asyncValue: taskScenesAsync,
              loading: () => const _LoadingListView(message: '场景配置加载中...'),
              error: (error, _) => ListView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Text(
                    '配置加载失败：$error',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
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
                    _draftNeedsSceneSync(draft, selectedScene)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    ref
                        .read(generateDraftControllerProvider.notifier)
                        .applySceneDefaults(selectedScene);
                  });
                }

                final currentSize = _resolveSelection(
                  currentValue: draft.size,
                  options:
                      selectedScene?.aspectRatioOptions.map((item) => item.value).toList() ??
                          const [],
                );
                final currentResolution = _resolveSelection(
                  currentValue: draft.resolution,
                  options:
                      selectedScene?.imageSizeOptions.map((item) => item.value).toList() ??
                          const [],
                );
                final anyTurnGenerating = chatTurns.any((t) => t.isGenerating);
                final showSuggestionsHeader = draft.prompt.trim().isEmpty &&
                    !taskFlow.isSubmitting &&
                    !taskFlow.isPolling &&
                    !anyTurnGenerating &&
                    chatTurns.isEmpty;

                final templateBubbleDisplay = draft.templatePrompt?.isNotEmpty == true
                    ? '使用模板开始创作：${draft.templatePrompt}'
                    : '已带入模板参数，准备开始创作。';
                final templateBubblePayload = draft.templatePrompt?.trim().isNotEmpty == true
                    ? draft.templatePrompt!.trim()
                    : templateBubbleDisplay;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ListView(
                        controller: _chatScrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        children: [
                  const _AssistantBubble(
                    text: '你好! 我是你的 AI 绘图助手\n描述你的想法，我来帮你生成图片。',
                  ),
                  const SizedBox(height: 12),
                  if (showSuggestionsHeader)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
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
                      text: templateBubbleDisplay,
                      actionPayload: templateBubblePayload,
                      onEdit: () {
                        ref
                            .read(generateDraftControllerProvider.notifier)
                            .updatePrompt(templateBubblePayload);
                        _promptFocusNode.requestFocus();
                      },
                    ),
                  if (draft.templateId != null) const SizedBox(height: 12),
                  for (final turn in chatTurns) ...[
                    _ExpandableUserPromptBubble(
                      text: turn.prompt,
                      onEdit: () {
                        ref
                            .read(generateDraftControllerProvider.notifier)
                            .updatePrompt(turn.prompt);
                        _promptFocusNode.requestFocus();
                      },
                    ),
                    const SizedBox(height: 12),
                    if (turn.isGenerating) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (var i = 0; i < turn.generatingSlotCount; i++)
                              _GeneratingImageSkeleton(
                                aspectRatio: turn.generatingAspectRatio,
                              ),
                          ],
                        ),
                      ),
                    ] else ...[
                      if (turn.errorMessage != null) ...[
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: turn.resultImages.isNotEmpty ? 8 : 0,
                          ),
                          child: _ErrorBubble(text: turn.errorMessage!),
                        ),
                      ],
                      if (turn.resultImages.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final entry in turn.resultImages.asMap().entries)
                                _ChatResultThumb(
                                  displayUrl: entry.value.displayUrl,
                                  onTap: () {
                                    final i = entry.key;
                                    final galleryUrls = _chatTurnGalleryUrls(
                                      turn.resultImages,
                                    );
                                    if (galleryUrls.isEmpty) return;
                                    final u = _chatPreviewOpenUrl(turn.resultImages[i]);
                                    if (u.isEmpty) return;
                                    context.push(
                                      '/preview',
                                      extra: {
                                        'urls': galleryUrls,
                                        'initialIndex': _chatGalleryIndexForTap(
                                          turn.resultImages,
                                          i,
                                        ),
                                        'title': '生成结果',
                                      },
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 12),
                  ],
                  if (taskFlow.errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      taskFlow.errorMessage!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                    ),
                  ],
                ],
                      ),
                    ),
                    SafeArea(
                      top: false,
                      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(18),
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
                              _promptField(context, ref, draft),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _ComposerIconButton(
                                    icon: Icons.tune,
                                    onTap: () => _showConfigSheet(
                                      context: context,
                                      generateScenes: generateScenes,
                                      selectedScene: selectedScene,
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
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary,
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
                                      icon: Icon(
                                        Icons.send_rounded,
                                        color: Theme.of(context).colorScheme.onPrimary,
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
                                child: _promptField(context, ref, draft),
                              ),
                              const SizedBox(width: 8),
                              _ComposerIconButton(
                                icon: Icons.tune,
                                onTap: () => _showConfigSheet(
                                  context: context,
                                  generateScenes: generateScenes,
                                  selectedScene: selectedScene,
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
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
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
                                  icon: Icon(
                                    Icons.send_rounded,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showConfigSheet({
    required BuildContext context,
    required List<TaskSceneConfig> generateScenes,
    required TaskSceneConfig? selectedScene,
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
            final modalDraft = ref.watch(generateDraftControllerProvider);
            final modalNumImages = modalDraft.numImages.clamp(1, 4);
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
                            style: Theme.of(context).textTheme.titleMedium!.copyWith(
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
                        style: Theme.of(context).textTheme.titleSmall!.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Builder(
                        builder: (context) {
                          if (generateScenes.isEmpty) {
                            return _ConfigSelectField(
                              text: '暂无可用模型',
                              onTap: null,
                            );
                          }
                          final sceneForRow = _resolveSelectedScene(
                            generateScenes,
                            modalDraft.model,
                          )!;
                          final modelLabel = sceneForRow.displayName.isNotEmpty
                              ? sceneForRow.displayName
                              : sceneForRow.sceneLabel;
                          return _ConfigSelectField(
                            text: modelLabel,
                            onTap: () async {
                              await showConfigCardPicker(
                                context: context,
                                title: '选择模型',
                                options: [
                                  for (final s in generateScenes)
                                    (
                                      value: s.sceneKey,
                                      label: s.displayName.isNotEmpty
                                          ? s.displayName
                                          : s.sceneLabel,
                                    ),
                                ],
                                currentValue: sceneForRow.sceneKey,
                                onPick: (v) {
                                  final nextScene =
                                      _resolveSelectedScene(generateScenes, v);
                                  if (nextScene == null) return;
                                  ref
                                      .read(generateDraftControllerProvider.notifier)
                                      .updateModel(v);
                                  ref
                                      .read(generateDraftControllerProvider.notifier)
                                      .applySceneDefaults(nextScene);
                                  setModalState(() {});
                                },
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '生图数量',
                        style: Theme.of(context).textTheme.titleSmall!.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final n in [1, 2, 3, 4])
                            _SelectableChip(
                              label: '$n 张',
                              selected: modalNumImages == n,
                              onTap: () {
                                ref
                                    .read(generateDraftControllerProvider.notifier)
                                    .updateNumImages(n);
                                setModalState(() {});
                              },
                            ),
                        ],
                      ),
                      if (modalScene != null &&
                          !modalScene.hideAspectRatio &&
                          modalScene.aspectRatioOptions.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Text(
                          '尺寸',
                          style: Theme.of(context).textTheme.titleSmall!.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final option in modalScene.aspectRatioOptions)
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
                      ],
                      if (modalScene != null &&
                          !modalScene.hideResolution &&
                          modalScene.imageSizeOptions.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Text(
                          '分辨率',
                          style: Theme.of(context).textTheme.titleSmall!.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final option in modalScene.imageSizeOptions)
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
                      ],
                      const SizedBox(height: 18),
                      Text(
                        '参考图',
                        style: Theme.of(context).textTheme.titleSmall!.copyWith(
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
                              ),
                              child: const Icon(Icons.add),
                            ),
                          ),
                        ],
                      ),
                      if (modalScene != null &&
                          !modalScene.hideCustomSize &&
                          modalScene.customSizeOptions.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Text(
                          '自定义尺寸',
                          style: Theme.of(context).textTheme.titleSmall!.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Builder(
                          builder: (context) {
                            final opts = modalScene.customSizeOptions;
                            final draftCustom =
                                ref.read(generateDraftControllerProvider).customSize;
                            final validVal = opts.any((o) => o.value == draftCustom)
                                ? draftCustom
                                : opts.first.value;
                            String labelFor(String v) {
                              for (final o in opts) {
                                if (o.value == v) {
                                  return o.label.isNotEmpty ? o.label : o.value;
                                }
                              }
                              return opts.first.label.isNotEmpty
                                  ? opts.first.label
                                  : opts.first.value;
                            }

                            return _ConfigSelectField(
                              text: labelFor(validVal),
                              onTap: () async {
                                await showConfigCardPicker(
                                  context: context,
                                  title: '自定义尺寸',
                                  options: [
                                    for (final o in opts)
                                      (
                                        value: o.value,
                                        label: o.label.isNotEmpty
                                            ? o.label
                                            : o.value,
                                      ),
                                  ],
                                  currentValue: validVal,
                                  onPick: (v) {
                                    ref
                                        .read(
                                          generateDraftControllerProvider.notifier,
                                        )
                                        .updateCustomSize(v);
                                    setModalState(() {});
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 18),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          textStyle: Theme.of(context).textTheme.labelLarge,
                        ),
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
    final sizeForApi =
        selectedScene.hideAspectRatio || selectedScene.aspectRatioOptions.isEmpty
            ? ''
            : _resolveSelection(
                currentValue: draft.size,
                options:
                    selectedScene.aspectRatioOptions.map((item) => item.value).toList(),
              );
    final resolutionForApi =
        selectedScene.hideResolution || selectedScene.imageSizeOptions.isEmpty
            ? ''
            : _resolveSelection(
                currentValue: draft.resolution,
                options:
                    selectedScene.imageSizeOptions.map((item) => item.value).toList(),
              );
    final customSizeForApi =
        selectedScene.hideCustomSize || selectedScene.customSizeOptions.isEmpty
            ? ''
            : _resolveSelection(
                currentValue: draft.customSize,
                options:
                    selectedScene.customSizeOptions.map((item) => item.value).toList(),
              );
    final success = await ref.read(taskControllerProvider.notifier).createTask(
          model: selectedScene.sceneKey,
          prompt: promptText,
          numImages: draft.numImages.clamp(1, 4),
          size: sizeForApi,
          resolution: resolutionForApi,
          customSize: customSizeForApi,
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
      final ids = ref.read(taskControllerProvider).activeTaskIds;
      final slots = draft.numImages.clamp(1, 4);
      final ar = layoutAspectRatioFromSizeParams(sizeForApi, customSizeForApi);
      ref.read(generateChatTurnsProvider.notifier).appendRunning(
            promptText,
            ids,
            slotCount: slots,
            aspectRatio: ar,
          );
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
  const _GeneratingImageSkeleton({this.aspectRatio = 4 / 3});

  /// 宽 / 高
  final double aspectRatio;

  Size _fitBox(double maxW, double maxH, double ar) {
    var w = maxW;
    var h = w / ar;
    if (h > maxH) {
      h = maxH;
      w = h * ar;
    }
    return Size(w, h);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final mq = MediaQuery.sizeOf(context);
    final maxW = _chatBubbleImageMaxWidth(context);
    final maxH = (mq.height * 0.55).clamp(160.0, 560.0);
    final ar = aspectRatio.clamp(0.25, 4.0);
    final s = _fitBox(maxW, maxH, ar);
    return Container(
      width: s.width,
      height: s.height,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: c.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
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

class _ChatResultThumb extends StatefulWidget {
  const _ChatResultThumb({
    required this.displayUrl,
    required this.onTap,
  });

  final String displayUrl;
  final VoidCallback onTap;

  @override
  State<_ChatResultThumb> createState() => _ChatResultThumbState();
}

class _ChatResultThumbState extends State<_ChatResultThumb> {
  /// 宽 / 高；解码完成前为 null。
  double? _aspectRatio;
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;

  @override
  void initState() {
    super.initState();
    _resolveAspectRatio();
  }

  @override
  void didUpdateWidget(covariant _ChatResultThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.displayUrl != widget.displayUrl) {
      _detachListener();
      _aspectRatio = null;
      _resolveAspectRatio();
    }
  }

  @override
  void dispose() {
    _detachListener();
    super.dispose();
  }

  void _detachListener() {
    final stream = _imageStream;
    final listener = _imageStreamListener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _imageStream = null;
    _imageStreamListener = null;
  }

  void _resolveAspectRatio() {
    if (widget.displayUrl.isEmpty) return;
    _detachListener();
    final provider = CachedNetworkImageProvider(widget.displayUrl);
    final stream = provider.resolve(ImageConfiguration.empty);
    _imageStreamListener = ImageStreamListener(
      (ImageInfo info, bool _) {
        final w = info.image.width.toDouble();
        final h = info.image.height.toDouble();
        if (!mounted || w <= 0 || h <= 0) return;
        setState(() => _aspectRatio = w / h);
      },
      onError: (_, __) {
        if (mounted) setState(() => _aspectRatio = 1.0);
      },
    );
    _imageStream = stream;
    stream.addListener(_imageStreamListener!);
  }

  Size _fitBox(double maxW, double maxH, double aspectWOverH) {
    var w = maxW;
    var h = w / aspectWOverH;
    if (h > maxH) {
      h = maxH;
      w = h * aspectWOverH;
    }
    return Size(w, h);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.sizeOf(context);
    final maxW = _chatBubbleImageMaxWidth(context);
    final maxH = (mq.height * 0.55).clamp(160.0, 560.0);
    final aspect = _aspectRatio ?? (4 / 3);
    final s = _fitBox(maxW, maxH, aspect);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: s.width,
            height: s.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                CachedNetworkImage(
                  imageUrl: widget.displayUrl,
                  fit: BoxFit.contain,
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
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '全屏',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary,
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
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 16),
        Center(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
        ),
      ),
    );
  }
}

/// 生图失败等业务提示：与助手气泡同形态，正文用错误色。
class _ErrorBubble extends StatelessWidget {
  const _ErrorBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: _chatBubbleImageMaxWidth(context)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.45,
                color: scheme.error,
                fontWeight: FontWeight.w500,
              ),
        ),
      ),
    );
  }
}

class _PromptBubbleActions extends StatelessWidget {
  const _PromptBubbleActions({
    required this.payload,
    required this.onEdit,
    this.startChild,
  });

  final String payload;
  final VoidCallback onEdit;
  final Widget? startChild;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: payload));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconColor = scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (startChild != null) startChild!,
          const Spacer(),
          IconButton(
            tooltip: '复制',
            onPressed: () => _copy(context),
            icon: Icon(Icons.copy_rounded, size: 17, color: iconColor),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: '填入输入框',
            onPressed: onEdit,
            icon: Icon(Icons.edit_rounded, size: 17, color: iconColor),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          ),
        ],
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({
    required this.text,
    required this.actionPayload,
    required this.onEdit,
  });

  final String text;
  final String actionPayload;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: _chatBubbleImageMaxWidth(context)),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: AppTypographyTokens.of(context).chatBubbleBody,
            ),
            _PromptBubbleActions(payload: actionPayload, onEdit: onEdit),
          ],
        ),
      ),
    );
  }
}

/// 用户提交的提示词气泡：默认至多三行，超出可展开/收起。
class _ExpandableUserPromptBubble extends StatefulWidget {
  const _ExpandableUserPromptBubble({
    required this.text,
    required this.onEdit,
  });

  final String text;
  final VoidCallback onEdit;

  @override
  State<_ExpandableUserPromptBubble> createState() =>
      _ExpandableUserPromptBubbleState();
}

class _ExpandableUserPromptBubbleState extends State<_ExpandableUserPromptBubble> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant _ExpandableUserPromptBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = AppTypographyTokens.of(context);
    final bodyStyle = tokens.chatBubbleBody;
    final linkStyle = tokens.chatBubbleLink;

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: _chatBubbleImageMaxWidth(context)),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(6),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final measure = TextPainter(
              text: TextSpan(text: widget.text, style: bodyStyle),
              maxLines: 3,
              textDirection: Directionality.of(context),
            )..layout(maxWidth: w);
            final needsExpand = measure.didExceedMaxLines;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.text,
                  style: bodyStyle,
                  maxLines: (_expanded || !needsExpand) ? null : 3,
                  overflow: (_expanded || !needsExpand)
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                ),
                _PromptBubbleActions(
                  payload: widget.text,
                  onEdit: widget.onEdit,
                  startChild: needsExpand
                      ? InkWell(
                          onTap: () => setState(() => _expanded = !_expanded),
                          borderRadius: BorderRadius.circular(4),
                          splashColor: scheme.onSurface.withValues(alpha: 0.08),
                          highlightColor: scheme.onSurface.withValues(alpha: 0.06),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 2,
                            ),
                            child: Text(
                              _expanded ? '收起' : '显示全部',
                              style: linkStyle,
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 配置页：加高的选项条，点击后弹出 [showConfigCardPicker]。
class _ConfigSelectField extends StatelessWidget {
  const _ConfigSelectField({
    required this.text,
    required this.onTap,
  });

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: enabled
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 26,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: selected ? scheme.onPrimary : scheme.onSurface,
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
