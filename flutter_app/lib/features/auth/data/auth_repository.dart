import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../core/network/app_exception.dart';
import 'auth_models.dart';

class AuthRepository {
  const AuthRepository(this._dio);

  final Dio _dio;

  Future<AuthSession> login({
    required String account,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {
          'account': account,
          'username': account,
          'password': password,
        },
      );
      return AuthSession.fromJson(response.data ?? {});
    } on DioException catch (error) {
      throw AppException.fromDioException(error);
    }
  }

  Future<AuthUser> getMe() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/auth/me');
      return AuthUser.fromJson(response.data ?? {});
    } on DioException catch (error) {
      throw AppException.fromDioException(error);
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(dioProvider));
});
