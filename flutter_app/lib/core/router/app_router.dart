import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/welcome_page.dart';
import '../../features/history/data/history_models.dart';
import '../../features/history/presentation/history_detail_page.dart';
import '../../features/history/presentation/history_page.dart';
import '../../features/generate/data/task_models.dart';
import '../../features/generate/presentation/generate_result_page.dart';
import '../../features/home/presentation/home_shell_page.dart';
import '../../features/image_preview/presentation/image_preview_page.dart';
import '../../features/profile/presentation/profile_info_page.dart';
import '../../features/templates/presentation/template_detail_page.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/welcome',
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomePage(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeShellPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryPage(),
      ),
      GoRoute(
        path: '/history/detail',
        builder: (context, state) {
          final item = state.extra as UserHistoryCardItem?;
          if (item == null) {
            return const HistoryPage();
          }
          return HistoryDetailPage(item: item);
        },
      ),
      GoRoute(
        path: '/preview',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return ImagePreviewPage(
            imageUrl: extra?['url'] as String? ?? '',
            title: extra?['title'] as String? ?? '图片预览',
          );
        },
      ),
      GoRoute(
        path: '/generate/result',
        builder: (context, state) {
          final task = state.extra as TaskResult?;
          if (task == null) {
            return const HomeShellPage();
          }
          return GenerateResultPage(task: task);
        },
      ),
      GoRoute(
        path: '/templates/:templateId',
        builder: (context, state) {
          return TemplateDetailPage(
            templateId: state.pathParameters['templateId'] ?? 'unknown',
          );
        },
      ),
      GoRoute(
        path: '/profile/info',
        builder: (context, state) => const ProfileInfoPage(),
      ),
    ],
  );
}
