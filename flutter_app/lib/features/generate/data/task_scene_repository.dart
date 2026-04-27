import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../core/network/app_exception.dart';
import 'task_scene_models.dart';

class TaskSceneRepository {
  const TaskSceneRepository(this._dio);

  final Dio _dio;

  Future<List<TaskSceneConfig>> getTaskScenes() async {
    try {
      final response = await _dio.get<List<dynamic>>('/config/task-scenes');
      final items = response.data ?? [];
      return items
          .map((item) => TaskSceneConfig.fromJson(item as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    } on DioException catch (error) {
      throw AppException.fromDioException(error);
    }
  }
}

final taskSceneRepositoryProvider = Provider<TaskSceneRepository>((ref) {
  return TaskSceneRepository(ref.watch(dioProvider));
});

final taskSceneListProvider = FutureProvider<List<TaskSceneConfig>>((ref) async {
  return ref.watch(taskSceneRepositoryProvider).getTaskScenes();
});
