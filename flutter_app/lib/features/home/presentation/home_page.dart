import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../core/network/image_url_resolver.dart';
import '../../../shared/widgets/shell_tab_header.dart';
import '../../../shared/widgets/smooth_child_switcher.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../generate/presentation/task_controller.dart';
import '../../templates/data/template_models.dart';
import '../../templates/presentation/template_home_controller.dart';

const double _templateGridGap = 6;

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _selectedTagIndex = 0;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 180) {
      ref.read(templateHomeControllerProvider.notifier).loadMore();
    }
  }

  int? _tagIdForChipIndex(int index, List<TemplateTag> tags) {
    if (index <= 0) return null;
    final vis = tags.take(5).toList();
    if (index - 1 >= vis.length) return null;
    return vis[index - 1].id;
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(templateHomeControllerProvider);
    final imageResolver = ref.watch(imageUrlResolverProvider);
    final authState = ref.watch(authControllerProvider);
    final taskFlow = ref.watch(taskControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: ShellTabHeader(
            onHistory: () {
              if (taskFlow.isPolling) {
                ref.read(taskControllerProvider.notifier).pollOnce();
              } else {
                Scaffold.of(context).openDrawer();
              }
            },
            creditsValue: authState.user?.credits ?? 0,
            authenticated: authState.isAuthenticated,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(templateHomeControllerProvider.notifier).refresh(),
            child: _buildBody(
              context,
              homeState,
              imageResolver,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    TemplateHomeState homeState,
    ImageUrlResolver imageResolver,
  ) {
    if (homeState.isInitialLoading && homeState.templates.isEmpty && homeState.error == null) {
      return ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [_TemplateHomeSkeleton()],
      );
    }

    if (homeState.error != null && homeState.templates.isEmpty && !homeState.isInitialLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text('模板加载失败：${homeState.error}'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () =>
                ref.read(templateHomeControllerProvider.notifier).loadFilter(
                      _tagIdForChipIndex(_selectedTagIndex, homeState.tags),
                    ),
            child: const Text('重试'),
          ),
        ],
      );
    }

    final filterLabels = [
      '全部',
      ...homeState.tags.take(5).map((tag) => tag.name),
    ];

    final selectedLabel = filterLabels[_selectedTagIndex.clamp(0, filterLabels.length - 1)];
    final templates = homeState.templates;

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: filterLabels.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final selected = index == _selectedTagIndex;
              return InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () {
                  final tagId = _tagIdForChipIndex(index, homeState.tags);
                  setState(() => _selectedTagIndex = index);
                  ref.read(templateHomeControllerProvider.notifier).loadFilter(tagId);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected ? Colors.black : const Color(0xFFF3F3F3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    filterLabels[index],
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF555555),
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        SmoothChildSwitcher(
          contentKey: selectedLabel,
          child: templates.isEmpty
              ? const Card(
                  child: ListTile(
                    title: Text('暂无模板'),
                    subtitle: Text('当前分类下还没有可展示的模板。'),
                  ),
                )
              : _StaggeredTemplateGrid(
                  templates: templates,
                  imageResolver: imageResolver,
                ),
        ),
        if (homeState.hasMore) ...[
          const SizedBox(height: 20),
          Center(
            child: homeState.isLoadingMore
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }
}

class _TemplateHomeSkeleton extends StatelessWidget {
  const _TemplateHomeSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, __) => Container(
              width: 72,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _skeletonColumn(context, c, const [9 / 16, 3 / 4, 3 / 4])),
            const SizedBox(width: _templateGridGap),
            Expanded(child: _skeletonColumn(context, c, const [3 / 4, 3 / 4, 3 / 4])),
          ],
        ),
      ],
    );
  }

  static Widget _skeletonColumn(
    BuildContext context,
    Color c,
    List<double> ratios,
  ) {
    return Column(
      children: [
        for (var i = 0; i < ratios.length; i++) ...[
          if (i > 0) const SizedBox(height: _templateGridGap),
          AspectRatio(
            aspectRatio: ratios[i],
            child: Container(
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StaggeredTemplateGrid extends StatelessWidget {
  const _StaggeredTemplateGrid({
    required this.templates,
    required this.imageResolver,
  });

  final List<CreativeTemplate> templates;
  final ImageUrlResolver imageResolver;

  @override
  Widget build(BuildContext context) {
    final leftIndices = <int>[
      for (var i = 0; i < templates.length; i += 2) i,
    ];
    final rightIndices = <int>[
      for (var i = 1; i < templates.length; i += 2) i,
    ];

    String urlFor(int index) {
      final t = templates[index];
      return imageResolver.resolveThumbnailLayers(
        thumbUrl: t.resultImageThumb,
        imageUrl: t.resultImage,
      );
    }

    Widget columnFor(List<int> indices) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var j = 0; j < indices.length; j++) ...[
            if (j > 0) const SizedBox(height: _templateGridGap),
            _TemplateCard(
              template: templates[indices[j]],
              imageUrl: urlFor(indices[j]),
              aspectRatio: indices[j] == 0 ? 9 / 16 : 3 / 4,
            ),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: columnFor(leftIndices)),
        const SizedBox(width: _templateGridGap),
        Expanded(child: columnFor(rightIndices)),
      ],
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.imageUrl,
    required this.aspectRatio,
  });

  final CreativeTemplate template;
  final String imageUrl;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    const cardRadius = 6.0;
    final prompt = template.prompt.isEmpty ? '未命名模板' : template.prompt;

    return InkWell(
      borderRadius: BorderRadius.circular(cardRadius),
      onTap: () => context.push('/templates/${template.id}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(cardRadius),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: imageUrl.isEmpty
                    ? ColoredBox(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Center(child: Icon(Icons.image_outlined)),
                      )
                    : CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorWidget: (context, url, error) => ColoredBox(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: const Center(child: Icon(Icons.image_outlined)),
                        ),
                      ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  width: double.infinity,
                  color: Colors.transparent,
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  child: Text(
                    prompt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.normal,
                          height: 1.25,
                          shadows: const [
                            Shadow(
                              color: Color(0x80000000),
                              blurRadius: 6,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
