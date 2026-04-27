import 'package:dio/dio.dart';

import '../config/app_environment.dart';
import '../storage/secure_storage_service.dart';

class AppDioFactory {
  const AppDioFactory({
    required this.environment,
    required this.storageService,
  });

  final AppEnvironment environment;
  final SecureStorageService storageService;

  Dio create() {
    final dio = Dio(
      BaseOptions(
        baseUrl: '${environment.apiBaseUrl}/api',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: const {'Accept': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await storageService.readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          handler.next(error);
        },
      ),
    );

    if (environment.enableDioLog) {
      dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: false,
        ),
      );
    }

    return dio;
  }
}
