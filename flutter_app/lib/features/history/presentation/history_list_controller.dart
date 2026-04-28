import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;

import '../data/history_models.dart';
import '../data/history_repository.dart';

class HistoryListState {
  const HistoryListState({
    this.items = const [],
    this.total = 0,
    this.isInitialLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.hasLoadedOnce = false,
  });

  final List<UserHistoryCardItem> items;
  final int total;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final Object? error;
  /// 是否至少完成过一次拉取（含失败），用于避免空列表时重复触发首次加载。
  final bool hasLoadedOnce;

  bool get hasMore => total > 0 && items.length < total;

  HistoryListState copyWith({
    List<UserHistoryCardItem>? items,
    int? total,
    bool? isInitialLoading,
    bool? isLoadingMore,
    Object? error,
    bool? hasLoadedOnce,
    bool clearError = false,
  }) {
    return HistoryListState(
      items: items ?? this.items,
      total: total ?? this.total,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      hasLoadedOnce: hasLoadedOnce ?? this.hasLoadedOnce,
    );
  }
}

class HistoryListController extends StateNotifier<HistoryListState> {
  HistoryListController(this.ref) : super(const HistoryListState());

  final Ref ref;
  static const _pageSize = 20;
  int _loadedPage = 0;

  void reset() {
    _loadedPage = 0;
    state = const HistoryListState();
  }

  Future<void> loadInitial() async {
    state = HistoryListState(
      isInitialLoading: true,
      items: const [],
      total: 0,
      error: null,
      hasLoadedOnce: false,
    );
    try {
      final res =
          await ref.read(historyRepositoryProvider).fetchHistory(page: 1, pageSize: _pageSize);
      _loadedPage = 1;
      state = HistoryListState(
        items: res.items,
        total: res.total,
        isInitialLoading: false,
        hasLoadedOnce: true,
      );
    } catch (e) {
      state = HistoryListState(
        isInitialLoading: false,
        error: e,
        hasLoadedOnce: true,
      );
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(clearError: true);
    try {
      if (state.items.isEmpty || _loadedPage <= 1) {
        final res =
            await ref.read(historyRepositoryProvider).fetchHistory(page: 1, pageSize: _pageSize);
        _loadedPage = 1;
        state = state.copyWith(
          items: res.items,
          total: res.total,
          isInitialLoading: false,
          hasLoadedOnce: true,
        );
        return;
      }
      final merged = <UserHistoryCardItem>[];
      var total = state.total;
      for (var p = 1; p <= _loadedPage; p++) {
        final res =
            await ref.read(historyRepositoryProvider).fetchHistory(page: p, pageSize: _pageSize);
        total = res.total;
        merged.addAll(res.items);
        if (merged.length >= total) break;
      }
      state = state.copyWith(
        items: merged,
        total: total,
        isInitialLoading: false,
        hasLoadedOnce: true,
      );
    } catch (e) {
      state = state.copyWith(error: e, isInitialLoading: false, hasLoadedOnce: true);
    }
  }

  /// 轮询：按当前已加载页数重新拉取并替换（保留分页长度）。
  Future<void> syncLoadedPages() async {
    if (state.items.isEmpty) {
      await refresh();
      return;
    }
    final pages = (_loadedPage).clamp(1, 999);
    try {
      final merged = <UserHistoryCardItem>[];
      var total = state.total;
      for (var p = 1; p <= pages; p++) {
        final res =
            await ref.read(historyRepositoryProvider).fetchHistory(page: p, pageSize: _pageSize);
        total = res.total;
        merged.addAll(res.items);
        if (merged.length >= total) break;
      }
      state = state.copyWith(items: merged, total: total, hasLoadedOnce: true);
    } catch (_) {}
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || state.isInitialLoading || !state.hasMore) {
      return;
    }
    state = state.copyWith(isLoadingMore: true);
    try {
      final nextPage = _loadedPage + 1;
      final res = await ref
          .read(historyRepositoryProvider)
          .fetchHistory(page: nextPage, pageSize: _pageSize);
      if (res.items.isEmpty) {
        state = state.copyWith(
          isLoadingMore: false,
          total: res.total,
        );
        return;
      }
      _loadedPage = nextPage;
      state = state.copyWith(
        items: [...state.items, ...res.items],
        total: res.total,
        isLoadingMore: false,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }
}

final historyListControllerProvider =
    StateNotifierProvider<HistoryListController, HistoryListState>((ref) {
  return HistoryListController(ref);
});
