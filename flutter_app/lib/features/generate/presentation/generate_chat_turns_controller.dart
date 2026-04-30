import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;

import '../../../app/app_providers.dart';
import '../../../core/network/image_url_resolver.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../history/data/history_repository.dart';
import 'task_controller.dart';

const int _kMaxChatTurns = 10;

/// 由「尺寸比例 + 自定义尺寸(如 WxH)」推断占位/预览用的宽/高比。
double layoutAspectRatioFromSizeParams(String size, String customSize) {
  final cs = customSize.trim();
  if (cs.isNotEmpty) {
    final norm = cs
        .replaceAll('×', 'x')
        .replaceAll('X', 'x')
        .replaceAll('*', 'x')
        .replaceAll(',', 'x');
    final sep = norm.split('x');
    if (sep.length >= 2) {
      final w = double.tryParse(sep[0].trim());
      final h = double.tryParse(sep[1].trim());
      if (w != null && h != null && w > 0 && h > 0) {
        return (w / h).clamp(0.25, 4.0);
      }
    }
  }
  final sz = size.trim();
  if (sz.contains(':')) {
    final p = sz.split(':');
    if (p.length == 2) {
      final a = double.tryParse(p[0].trim());
      final b = double.tryParse(p[1].trim());
      if (a != null && b != null && a > 0 && b > 0) {
        return (a / b).clamp(0.25, 4.0);
      }
    }
  }
  return 4 / 3;
}

/// 创作页聊天区一条「提示词 + 生成结果」记录（最多保留 [_kMaxChatTurns] 条）。
class GenerateChatTurn {
  const GenerateChatTurn({
    required this.prompt,
    required this.taskIds,
    required this.isGenerating,
    this.resultThumbUrls = const [],
    this.errorMessage,
    this.generatingSlotCount = 1,
    this.generatingAspectRatio = 4 / 3,
  });

  final String prompt;
  final List<int> taskIds;
  final bool isGenerating;
  final List<String> resultThumbUrls;
  final String? errorMessage;
  /// 生成中占位卡片数量（与本次提交的 num_images 一致）。
  final int generatingSlotCount;
  /// 占位卡片宽高比（宽/高），与自定义尺寸或比例尺寸一致。
  final double generatingAspectRatio;
}

bool _sameIdSet(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  final aa = [...a]..sort();
  final bb = [...b]..sort();
  for (var i = 0; i < aa.length; i++) {
    if (aa[i] != bb[i]) return false;
  }
  return true;
}

class GenerateChatTurnsNotifier extends StateNotifier<List<GenerateChatTurn>> {
  GenerateChatTurnsNotifier(this.ref) : super(const []);

  final Ref ref;

  void clear() {
    state = const [];
  }

  void appendRunning(
    String prompt,
    List<int> taskIds, {
    required int slotCount,
    required double aspectRatio,
  }) {
    final t = prompt.trim();
    if (t.isEmpty || taskIds.isEmpty) return;
    final slots = slotCount.clamp(1, 4);
    final ar = aspectRatio.clamp(0.25, 4.0);
    var next = [
      ...state,
      GenerateChatTurn(
        prompt: t,
        taskIds: List<int>.from(taskIds),
        isGenerating: true,
        generatingSlotCount: slots,
        generatingAspectRatio: ar,
      ),
    ];
    if (next.length > _kMaxChatTurns) {
      next = next.sublist(next.length - _kMaxChatTurns);
    }
    state = next;
  }

  void syncFromTaskFlow(TaskFlowState flow, ImageUrlResolver resolver) {
    if (flow.activeTaskIds.isEmpty) return;

    var idx = state.lastIndexWhere(
      (turn) => turn.isGenerating && _sameIdSet(turn.taskIds, flow.activeTaskIds),
    );
    if (idx < 0) {
      idx = state.lastIndexWhere((turn) => turn.isGenerating);
    }
    if (idx < 0) return;

    final turn = state[idx];
    if (!turn.isGenerating) return;
    if (flow.tasks.isEmpty) return;

    final allTerminal =
        flow.tasks.isNotEmpty && flow.tasks.every((item) => item.isTerminal);
    if (!allTerminal) return;

    final urls = <String>[];
    var anyFailed = false;
    for (final tr in flow.tasks) {
      if (tr.status == 'failed') {
        anyFailed = true;
      } else if (tr.status == 'success') {
        for (final img in tr.images) {
          final u = resolver.resolveThumbnailLayers(
            thumbUrl: img.thumbUrl,
            previewUrl: img.previewUrl,
            imageUrl: img.imageUrl,
          );
          if (u.isNotEmpty) urls.add(u);
        }
      }
    }

    final err = anyFailed ? '生图失败，请重新发起试试呢！' : null;

    state = [
      ...state.take(idx),
      GenerateChatTurn(
        prompt: turn.prompt,
        taskIds: turn.taskIds,
        isGenerating: false,
        resultThumbUrls: urls,
        errorMessage: err,
        generatingSlotCount: turn.generatingSlotCount,
        generatingAspectRatio: turn.generatingAspectRatio,
      ),
      ...state.skip(idx + 1),
    ];
  }

  /// 进入创作页且本地尚无记录时，拉取最近 [_kMaxChatTurns] 条历史填充聊天区。
  Future<void> hydrateIfEmpty() async {
    if (state.isNotEmpty) return;
    if (!ref.read(authControllerProvider).isAuthenticated) return;

    try {
      final repo = ref.read(historyRepositoryProvider);
      final res = await repo.fetchHistory(page: 1, pageSize: _kMaxChatTurns);
      if (state.isNotEmpty) return;

      final resolver = ref.read(imageUrlResolverProvider);
      final items = res.items.where((e) => e.mode == 'generate').take(_kMaxChatTurns).toList();
      final chronological = items.reversed;

      final turns = <GenerateChatTurn>[];
      for (final item in chronological) {
        final p = item.prompt.trim();
        if (p.isEmpty) continue;

        final urls = <String>[];
        if (item.images.isNotEmpty) {
          for (final im in item.images) {
            final u = resolver.resolveThumbnailLayers(
              thumbUrl: im.thumbUrl,
              previewUrl: im.previewUrl,
              imageUrl: im.imageUrl,
            );
            if (u.isNotEmpty) urls.add(u);
          }
        } else {
          final u = resolver.resolveThumbnailLayers(
            thumbUrl: item.thumbUrl,
            previewUrl: item.previewUrl,
            imageUrl: item.imageUrl,
          );
          if (u.isNotEmpty) urls.add(u);
        }

        final st = item.status.toLowerCase();
        final failed = st == 'failed';

        turns.add(
          GenerateChatTurn(
            prompt: p,
            taskIds: item.taskId > 0 ? [item.taskId] : const [],
            isGenerating: false,
            resultThumbUrls: urls,
            errorMessage: failed ? '生图失败，请重新发起试试呢！' : null,
          ),
        );
      }

      state = turns;
    } catch (_) {
      // 离线/接口失败时保持空列表，用户仍可正常发任务
    }
  }
}

final generateChatTurnsProvider =
    StateNotifierProvider<GenerateChatTurnsNotifier, List<GenerateChatTurn>>(
        (ref) {
  return GenerateChatTurnsNotifier(ref);
});
