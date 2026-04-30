import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;

import '../../../core/network/app_exception.dart';
import '../data/task_models.dart';
import '../data/task_repository.dart';

class TaskFlowState {
  const TaskFlowState({
    this.isSubmitting = false,
    this.isPolling = false,
    this.activeTaskIds = const [],
    this.tasks = const [],
    this.errorMessage,
  });

  final bool isSubmitting;
  final bool isPolling;
  final List<int> activeTaskIds;
  final List<TaskResult> tasks;
  final String? errorMessage;

  TaskResult? get latestTask => tasks.isEmpty ? null : tasks.first;

  TaskFlowState copyWith({
    bool? isSubmitting,
    bool? isPolling,
    List<int>? activeTaskIds,
    List<TaskResult>? tasks,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TaskFlowState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isPolling: isPolling ?? this.isPolling,
      activeTaskIds: activeTaskIds ?? this.activeTaskIds,
      tasks: tasks ?? this.tasks,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class TaskController extends StateNotifier<TaskFlowState> {
  TaskController(this.ref) : super(const TaskFlowState());

  final Ref ref;
  Timer? _pollTimer;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<bool> createTask({
    required String model,
    required String prompt,
    required int numImages,
    required String size,
    required String resolution,
    required String customSize,
    List<String> referenceImages = const [],
  }) async {
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
    );

    try {
      final result = await ref.read(taskRepositoryProvider).createTask(
            model: model,
            prompt: prompt,
            numImages: numImages,
            size: size,
            resolution: resolution,
            customSize: customSize,
            referenceImages: referenceImages,
          );

      if (result.taskIds.isEmpty) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: '任务创建成功，但未返回任务 ID。',
        );
        return false;
      }

      state = state.copyWith(
        isSubmitting: false,
        isPolling: true,
        activeTaskIds: result.taskIds,
        tasks: const [],
      );

      await pollOnce();
      _startPolling();
      return true;
    } on AppException catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: error.message,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: '任务创建失败，请稍后重试。',
      );
      return false;
    }
  }

  Future<void> pollOnce() async {
    if (state.activeTaskIds.isEmpty) {
      return;
    }

    try {
      final tasks = await ref.read(taskRepositoryProvider).getTasks(state.activeTaskIds);
      final allTerminal = tasks.isNotEmpty && tasks.every((item) => item.isTerminal);
      state = state.copyWith(
        tasks: tasks,
        isPolling: !allTerminal,
        clearError: true,
      );

      if (allTerminal) {
        _pollTimer?.cancel();
      }
    } on AppException catch (error) {
      state = state.copyWith(errorMessage: error.message);
    }
  }

  void clearMessages() {
    state = state.copyWith(clearError: true);
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      pollOnce();
    });
  }
}

final taskControllerProvider =
    StateNotifierProvider<TaskController, TaskFlowState>((ref) {
  return TaskController(ref);
});
