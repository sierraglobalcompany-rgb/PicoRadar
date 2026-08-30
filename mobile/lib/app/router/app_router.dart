import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shell/app_shell.dart';
import '../../features/apps_launcher/presentation/apps_screen.dart';
import '../../features/apps_launcher/presentation/module_placeholder_screen.dart';
import '../../features/garage/presentation/garage_screen.dart';
import '../../features/garage/presentation/vehicle_detail_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/presentation/onboarding_vehicle_screen.dart';
import '../../features/pico_placa/presentation/pico_detail_screen.dart';
import '../../features/vehicle_status/presentation/vehicle_status_screen.dart';
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
        path: AppRoute.pico.path,
        builder: (context, state) => PicoDetailScreen(
          vehicleId: state.uri.queryParameters['vehicleId'],
          jurisdictionId: state.uri.queryParameters['jurisdictionId'],
        ),
      ),
      GoRoute(
        path: AppRoute.vehicleOnboarding.path,
        builder: (context, state) {
          final returnTarget = state.uri.queryParameters['return'];
          return OnboardingVehicleScreen(
            returnPath: switch (returnTarget) {
              'apps' => AppRoute.apps.path,
              'garage' => AppRoute.garage.path,
              _ => AppRoute.home.path,
            },
          );
        },
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
        builder: (context, state) {
          return switch (tab) {
            AppTab.home => const HomeScreen(),
            AppTab.garage => const GarageScreen(),
            AppTab.apps => const AppsScreen(),
            _ => RootPlaceholderScreen(tab: tab),
          };
        },
        routes: _tabRoutes(tab),
      ),
    ],
  );
}

List<RouteBase> _tabRoutes(AppTab tab) {
  return switch (tab) {
    AppTab.garage => [
      GoRoute(
        path: 'vehicle/:id',
        builder: (context, state) {
          return VehicleDetailScreen(vehicleId: state.pathParameters['id']!);
        },
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return OnboardingVehicleScreen(
                vehicleId: id,
                returnPath: '/garage/vehicle/$id',
              );
            },
          ),
        ],
      ),
    ],
    AppTab.apps => [
      GoRoute(
        path: 'module/:id',
        builder: (context, state) {
          final moduleId = state.pathParameters['id']!;
          if (_vehicleStatusModules.contains(moduleId)) {
            return VehicleStatusScreen(
              moduleId: moduleId,
              vehicleId: state.uri.queryParameters['vehicleId'],
            );
          }
          return ModulePlaceholderScreen(moduleId: moduleId);
        },
      ),
    ],
    _ => const [],
  };
}

const _vehicleStatusModules = {
  'soat',
  'tecnomecanica',
  'seguro_asistencia',
  'impuestos',
};
