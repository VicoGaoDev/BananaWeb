import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../templates/data/template_models.dart';
import '../../templates/data/template_repository.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _selectedTagIndex = 0;

  @override
  Widget build(BuildContext context) {
    final homeDataAsync = ref.watch(templateHomeProvider);
    final imageResolver = ref.watch(imageUrlResolverProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(templateHomeProvider);
        await ref.read(templateHomeProvider.future);
      },
      child: homeDataAsync.when(
        loading: () => const _LoadingListView(message: '模板加载中...'),
        error: (error, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('模板加载失败：$error'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => ref.invalidate(templateHomeProvider),
              child: const Text('重试'),
            ),
          ],
        ),
        data: (homeData) {
          final filterLabels = [
            '全部',
            ...homeData.tags.take(5).map((tag) => tag.name),
          ];
          final selectedLabel = filterLabels[_selectedTagIndex];
          final templates = selectedLabel == '全部'
              ? homeData.templates
              : homeData.templates
                  .where((item) => item.tags.any((tag) => tag.name == selectedLabel))
                  .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              Row(
                children: [
                  Text(
                    '模板',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const Spacer(),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      onPressed: () {},
                      icon: const Icon(Icons.search, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '搜索模板',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8A8A8A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
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
                        setState(() {
                          _selectedTagIndex = index;
                        });
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
              if (templates.isEmpty)
                const Card(
                  child: ListTile(
                    title: Text('暂无模板'),
                    subtitle: Text('当前分类下还没有可展示的模板。'),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: templates.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.72,
                  ),
                  itemBuilder: (context, index) {
                    final template = templates[index];
                    final imageUrl = template.resultImageThumb.isNotEmpty
                        ? template.resultImageThumb
                        : template.resultImage;
                    return _TemplateCard(
                      template: template,
                      imageUrl: imageResolver.resolve(imageUrl),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.imageUrl,
  });

  final CreativeTemplate template;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.push('/templates/${template.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.08,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: imageUrl.isEmpty
                    ? const Center(child: Icon(Icons.image_outlined))
                    : CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorWidget: (context, url, error) =>
                            const Center(child: Icon(Icons.image_outlined)),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            template.prompt.isEmpty ? '未命名模板' : template.prompt,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            template.tags.isEmpty ? '默认分类' : template.tags.first.name,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 3),
          Text(
            '${template.model} · ${template.size.isEmpty ? '1:1' : template.size}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
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
