import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../core/network/app_exception.dart';
import 'template_models.dart';

class TemplateRepository {
  const TemplateRepository(this._dio);

  final Dio _dio;

  Future<TemplateHomeData> getHomeData() async {
    try {
      final tagsResponse = await _dio.get<List<dynamic>>('/templates/tags');
      final templatesResponse = await _dio.get<Map<String, dynamic>>(
        '/templates',
        queryParameters: {
          'page': 1,
          'page_size': 20,
        },
      );

      return TemplateHomeData(
        tags: (tagsResponse.data ?? [])
            .map((item) => TemplateTag.fromJson(item as Map<String, dynamic>))
            .toList(),
        templates: TemplateListResponse.fromJson(templatesResponse.data ?? {}).items,
      );
    } on DioException catch (error) {
      throw AppException.fromDioException(error);
    }
  }

  Future<CreativeTemplate> getTemplateDetail(int templateId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/templates/$templateId');
      return CreativeTemplate.fromJson(response.data ?? {});
    } on DioException catch (error) {
      throw AppException.fromDioException(error);
    }
  }
}

final templateRepositoryProvider = Provider<TemplateRepository>((ref) {
  return TemplateRepository(ref.watch(dioProvider));
});

final templateHomeProvider = FutureProvider<TemplateHomeData>((ref) async {
  return ref.watch(templateRepositoryProvider).getHomeData();
});

final templateDetailProvider =
    FutureProvider.family<CreativeTemplate, int>((ref, templateId) async {
  return ref.watch(templateRepositoryProvider).getTemplateDetail(templateId);
});
