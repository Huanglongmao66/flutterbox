// 路由配置，对应原项目各 Activity 跳转
import 'package:go_router/go_router.dart';

import '../features/cast/cast_page.dart';
import '../features/collect/collect_page.dart';
import '../features/detail/detail_page.dart';
import '../features/history/history_page.dart';
import '../features/home/home_page.dart';
import '../features/live/live_page.dart';
import '../features/local/local_file_page.dart';
import '../features/player/player_page.dart';
import '../features/push/push_page.dart';
import '../features/search/search_page.dart';
import '../features/settings/settings_page.dart';

class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String detail = '/detail';
  static const String search = '/search';
  static const String live = '/live';
  static const String history = '/history';
  static const String collect = '/collect';
  static const String settings = '/settings';
  static const String local = '/local';
  static const String push = '/push';
  static const String player = '/player';
  static const String cast = '/cast';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: AppRoutes.detail,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? const {};
        return DetailPage(
          sourceKey: extra['sourceKey'] as String? ?? '',
          vodId: extra['vodId'] as String? ?? '',
          title: extra['title'] as String? ?? '',
        );
      },
    ),
    GoRoute(
      path: AppRoutes.search,
      builder: (context, state) => const SearchPage(),
    ),
    GoRoute(
      path: AppRoutes.live,
      builder: (context, state) => const LivePage(),
    ),
    GoRoute(
      path: AppRoutes.history,
      builder: (context, state) => const HistoryPage(),
    ),
    GoRoute(
      path: AppRoutes.collect,
      builder: (context, state) => const CollectPage(),
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: AppRoutes.local,
      builder: (context, state) => const LocalFilePage(),
    ),
    GoRoute(
      path: AppRoutes.push,
      builder: (context, state) => const PushPage(),
    ),
    GoRoute(
      path: AppRoutes.player,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? const {};
        return PlayerPage(
          title: extra['title'] as String? ?? '',
          url: extra['url'] as String? ?? '',
          sourceKey: extra['sourceKey'] as String? ?? '',
          vodId: extra['vodId'] as String? ?? '',
          episodeName: extra['episodeName'] as String? ?? '',
          resumeMs: extra['resumeMs'] as int? ?? 0,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.cast,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? const {};
        return CastPage(
          castUrl: extra['url'] as String?,
          castTitle: extra['title'] as String?,
        );
      },
    ),
  ],
);
