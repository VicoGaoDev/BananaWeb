import 'package:dio/dio.dart';

class AppException implements Exception {
  const AppException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  factory AppException.fromDioException(DioException exception) {
    final response = exception.response;
    final data = response?.data;

    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) {
        return AppException(detail, statusCode: response?.statusCode);
      }
    }

    if (data is String && data.isNotEmpty) {
      return AppException(data, statusCode: response?.statusCode);
    }

    return AppException(
      exception.message ?? 'Request failed. Please try again.',
      statusCode: response?.statusCode,
    );
  }

  @override
  String toString() => message;
}
