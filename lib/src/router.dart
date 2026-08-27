import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'models.dart';
import 'screens/active_session_screen.dart';
import 'screens/app_selection_screen.dart';
import 'screens/group_edit_screen.dart';
import 'screens/groups_screen.dart';
import 'screens/home_screen.dart';
import 'screens/limits_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/summary_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/apps', builder: (_, _) => const AppSelectionScreen()),
      GoRoute(path: '/groups', builder: (_, _) => const GroupsScreen()),
      GoRoute(
        path: '/groups/edit',
        builder: (_, state) =>
            GroupEditScreen(group: state.extra as AppGroup?),
      ),
      GoRoute(path: '/stats', builder: (_, _) => const StatsScreen()),
      GoRoute(path: '/limits', builder: (_, _) => const LimitsScreen()),
      GoRoute(
        path: '/session',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ActiveSessionScreen(
            endTime: extra['endTime'] as DateTime? ??
                DateTime.now().add(const Duration(minutes: 25)),
            durationMinutes: extra['durationMinutes'] as int? ?? 25,
            blockedCount: extra['blockedCount'] as int? ?? 0,
          );
        },
      ),
      GoRoute(
        path: '/summary',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return SummaryScreen(
            durationMinutes: extra['durationMinutes'] as int? ?? 0,
            blockedCount: extra['blockedCount'] as int? ?? 0,
          );
        },
      ),
    ],
  );
});
