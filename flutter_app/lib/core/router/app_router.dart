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
import 'app_page_transitions.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/welcome',
    routes: [
      GoRoute(
        path: '/welcome',
        pageBuilder: (context, state) =>
            AppPageTransitions.fadeThrough(state, const WelcomePage()),
      ),
      GoRoute(
        path: '/',
        pageBuilder: (context, state) =>
            AppPageTransitions.fadeThrough(state, const HomeShellPage()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            AppPageTransitions.fadeThrough(state, const LoginPage()),
      ),
      GoRoute(
        path: '/history',
        pageBuilder: (context, state) =>
            AppPageTransitions.fadeThrough(state, const HistoryPage()),
      ),
      GoRoute(
        path: '/history/detail',
        pageBuilder: (context, state) {
          final item = state.extra as UserHistoryCardItem?;
          if (item == null) {
            return AppPageTransitions.fadeThrough(state, const HistoryPage());
          }
          return AppPageTransitions.fadeThrough(
            state,
            HistoryDetailPage(item: item),
          );
        },
      ),
      GoRoute(
        path: '/preview',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final fromList = extra?['urls'];
          final urls = <String>[];
          if (fromList is List && fromList.isNotEmpty) {
            for (final e in fromList) {
              final s = e.toString().trim();
              if (s.isNotEmpty) urls.add(s);
            }
          } else {
            final u = extra?['url'] as String? ?? '';
            if (u.trim().isNotEmpty) urls.add(u.trim());
          }
          final rawInitial = extra?['initialIndex'];
          var initial = 0;
          if (rawInitial is int) {
            initial = rawInitial;
          } else if (rawInitial is num) {
            initial = rawInitial.toInt();
          }
          if (urls.isNotEmpty) {
            initial = initial.clamp(0, urls.length - 1);
          } else {
            initial = 0;
          }

          return AppPageTransitions.fadeThrough(
            state,
            ImagePreviewPage(
              imageUrls: urls,
              initialIndex: initial,
              title: extra?['title'] as String? ?? '图片预览',
            ),
          );
        },
      ),
      GoRoute(
        path: '/generate/result',
        pageBuilder: (context, state) {
          final task = state.extra as TaskResult?;
          if (task == null) {
            return AppPageTransitions.fadeThrough(state, const HomeShellPage());
          }
          return AppPageTransitions.fadeThrough(
            state,
            GenerateResultPage(task: task),
          );
        },
      ),
      GoRoute(
        path: '/templates/:templateId',
        pageBuilder: (context, state) {
          return AppPageTransitions.fadeThrough(
            state,
            TemplateDetailPage(
              templateId: state.pathParameters['templateId'] ?? 'unknown',
            ),
          );
        },
      ),
      GoRoute(
        path: '/profile/info',
        pageBuilder: (context, state) =>
            AppPageTransitions.fadeThrough(state, const ProfileInfoPage()),
      ),
    ],
  );
}
