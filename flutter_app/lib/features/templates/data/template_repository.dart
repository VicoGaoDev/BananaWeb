import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../core/network/app_exception.dart';
import 'template_models.dart';

class TemplateRepository {
  const TemplateRepository(this._dio);

  final Dio _dio;

  Future<List<TemplateTag>> fetchTags() async {
    try {
      final response = await _dio.get<List<dynamic>>('/templates/tags');
      return (response.data ?? [])
          .map((item) => TemplateTag.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw AppException.fromDioException(error);
    }
  }

  Future<TemplateListResponse> fetchTemplatesPage({
    required int page,
    int pageSize = 20,
    int? tagId,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (tagId != null) {
        queryParameters['tag_id'] = tagId;
      }
      final response = await _dio.get<Map<String, dynamic>>(
        '/templates',
        queryParameters: queryParameters,
      );
      return TemplateListResponse.fromJson(response.data ?? {});
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

final templateDetailProvider =
    FutureProvider.family<CreativeTemplate, int>((ref, templateId) async {
  return ref.watch(templateRepositoryProvider).getTemplateDetail(templateId);
});
