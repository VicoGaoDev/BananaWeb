import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_environment.dart';
import '../core/network/app_dio.dart';
import '../core/network/image_url_resolver.dart';
import '../core/router/app_router.dart';
import '../core/storage/secure_storage_service.dart';

final appEnvironmentProvider = Provider<AppEnvironment>((ref) {
  return AppEnvironment.fromEnvironment();
});

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return const SecureStorageService();
});

final dioProvider = Provider<Dio>((ref) {
  final environment = ref.watch(appEnvironmentProvider);
  final storage = ref.watch(secureStorageProvider);
  return AppDioFactory(
    environment: environment,
    storageService: storage,
  ).create();
});

final imageUrlResolverProvider = Provider<ImageUrlResolver>((ref) {
  return ImageUrlResolver(ref.watch(appEnvironmentProvider));
});

final appRouterProvider = Provider<GoRouter>((ref) {
  return AppRouter.router;
});
