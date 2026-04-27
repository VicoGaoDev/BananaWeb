import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/app_providers.dart';
import '../../../core/network/app_exception.dart';
import 'upload_models.dart';

class UploadRepository {
  const UploadRepository(this._dio);

  final Dio _dio;

  Future<UploadedReferenceImage> uploadReferenceImage(XFile file) async {
    try {
      final extension = file.name.split('.').last.toLowerCase();
      final mediaType = switch (extension) {
        'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
        'png' => MediaType('image', 'png'),
        'webp' => MediaType('image', 'webp'),
        'gif' => MediaType('image', 'gif'),
        _ => MediaType('application', 'octet-stream'),
      };

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.name,
          contentType: mediaType,
        ),
      });

      final response = await _dio.post<Map<String, dynamic>>('/upload', data: formData);
      return UploadedReferenceImage(
        localPath: file.path,
        remoteUrl: response.data?['url'] as String? ?? '',
        fileName: file.name,
      );
    } on DioException catch (error) {
      throw AppException.fromDioException(error);
    } on FileSystemException {
      throw const AppException('读取本地图片失败，请重试。');
    }
  }
}

final uploadRepositoryProvider = Provider<UploadRepository>((ref) {
  return UploadRepository(ref.watch(dioProvider));
});
