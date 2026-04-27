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
}

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepository(ref.watch(dioProvider));
});

final userHistoryProvider = FutureProvider<UserHistoryResponse>((ref) async {
  return ref.watch(historyRepositoryProvider).fetchHistory();
});
