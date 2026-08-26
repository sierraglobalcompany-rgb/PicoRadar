import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shell/app_shell.dart';
import 'app_routes.dart';
import 'immersive_placeholder_screen.dart';
import 'root_placeholder_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoute.home.path,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          _rootBranch(AppTab.home),
          _rootBranch(AppTab.garage),
          _rootBranch(AppTab.apps),
          _rootBranch(AppTab.trip),
          _rootBranch(AppTab.drive),
        ],
      ),
      GoRoute(
        path: AppRoute.immersivePreview.path,
        builder: (context, state) => const ImmersivePlaceholderScreen(),
      ),
    ],
  );
});

StatefulShellBranch _rootBranch(AppTab tab) {
  return StatefulShellBranch(
    routes: [
      GoRoute(
        path: tab.route.path,
        builder: (context, state) => RootPlaceholderScreen(tab: tab),
      ),
    ],
  );
}
