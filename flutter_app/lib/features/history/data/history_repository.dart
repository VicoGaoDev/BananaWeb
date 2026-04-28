import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../core/network/app_exception.dart';
import 'history_models.dart';

class HistoryRepository {
  const HistoryRepository(this._dio);

  final Dio _dio;

  Future<UserHistoryResponse> fetchHistory({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/history',
        queryParameters: {
          'page': page,
          'page_size': pageSize,
        },
      );
      return UserHistoryResponse.fromJson(response.data ?? {});
    } on DioException catch (error) {
      throw AppException.fromDioException(error);
    }
  }

  Future<void> deleteTask(int taskId) async {
    try {
      await _dio.delete<void>('/history/tasks/$taskId');
    } on DioException catch (error) {
      throw AppException.fromDioException(error);
    }
  }

  Future<void> deletePromptHistoryItem(int historyId) async {
    try {
      await _dio.delete<void>('/auth/prompt-history/$historyId');
    } on DioException catch (error) {
      throw AppException.fromDioException(error);
    }
  }
}

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepository(ref.watch(dioProvider));
});
