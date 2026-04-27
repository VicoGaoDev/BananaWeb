import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import 'app_providers.dart';

class BananaApp extends ConsumerWidget {
  const BananaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final environment = ref.watch(appEnvironmentProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Banana App',
      debugShowCheckedModeBanner: !environment.isProduction,
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}
