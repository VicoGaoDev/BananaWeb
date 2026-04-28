import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;

import '../data/template_models.dart';
import '../data/template_repository.dart';

class TemplateHomeState {
  const TemplateHomeState({
    this.tags = const [],
    this.templates = const [],
    this.total = 0,
    this.isInitialLoading = true,
    this.isLoadingMore = false,
    this.error,
    this.filterTagId,
  });

  final List<TemplateTag> tags;
  final List<CreativeTemplate> templates;
  final int total;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final Object? error;
  final int? filterTagId;

  bool get hasMore => total > 0 && templates.length < total;

  TemplateHomeState copyWith({
    List<TemplateTag>? tags,
    List<CreativeTemplate>? templates,
    int? total,
    bool? isInitialLoading,
    bool? isLoadingMore,
    Object? error,
    int? filterTagId,
    bool clearError = false,
  }) {
    return TemplateHomeState(
      tags: tags ?? this.tags,
      templates: templates ?? this.templates,
      total: total ?? this.total,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      filterTagId: filterTagId ?? this.filterTagId,
    );
  }
}

class TemplateHomeController extends StateNotifier<TemplateHomeState> {
  TemplateHomeController(this.ref) : super(const TemplateHomeState()) {
    Future.microtask(_bootstrap);
  }

  final Ref ref;
  static const _pageSize = 20;
  int _loadedPage = 0;

  Future<void> _bootstrap() async {
    await loadFilter(null);
  }

  Future<void> loadFilter(int? tagId) async {
    var tags = state.tags;
    state = TemplateHomeState(
      tags: tags,
      isInitialLoading: true,
      templates: const [],
      total: 0,
      error: null,
      filterTagId: tagId,
    );
    try {
      final repo = ref.read(templateRepositoryProvider);
      if (tags.isEmpty) {
        tags = await repo.fetchTags();
      }
      final res =
          await repo.fetchTemplatesPage(page: 1, pageSize: _pageSize, tagId: tagId);
      _loadedPage = 1;
      state = TemplateHomeState(
        tags: tags,
        templates: res.items,
        total: res.total,
        isInitialLoading: false,
        filterTagId: tagId,
      );
    } catch (e) {
      state = TemplateHomeState(
        tags: tags,
        isInitialLoading: false,
        error: e,
        filterTagId: tagId,
      );
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(clearError: true);
    try {
      final repo = ref.read(templateRepositoryProvider);
      final tags = await repo.fetchTags();
      final res = await repo.fetchTemplatesPage(
        page: 1,
        pageSize: _pageSize,
        tagId: state.filterTagId,
      );
      _loadedPage = 1;
      state = state.copyWith(
        tags: tags,
        templates: res.items,
        total: res.total,
        isInitialLoading: false,
      );
    } catch (e) {
      state = state.copyWith(error: e, isInitialLoading: false);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || state.isInitialLoading || !state.hasMore) {
      return;
    }
    state = state.copyWith(isLoadingMore: true);
    try {
      final nextPage = _loadedPage + 1;
      final res = await ref.read(templateRepositoryProvider).fetchTemplatesPage(
            page: nextPage,
            pageSize: _pageSize,
            tagId: state.filterTagId,
          );
      if (res.items.isEmpty) {
        state = state.copyWith(isLoadingMore: false, total: res.total);
        return;
      }
      _loadedPage = nextPage;
      state = state.copyWith(
        templates: [...state.templates, ...res.items],
        total: res.total,
        isLoadingMore: false,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }
}

final templateHomeControllerProvider =
    StateNotifierProvider<TemplateHomeController, TemplateHomeState>((ref) {
  return TemplateHomeController(ref);
});
