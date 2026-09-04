import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shell/app_shell.dart';
import '../../features/apps_launcher/presentation/apps_screen.dart';
import '../../features/apps_launcher/presentation/module_placeholder_screen.dart';
import '../../features/cda/presentation/cda_finder_screen.dart';
import '../../features/comparendos/presentation/comparendos_screen.dart';
import '../../features/documents/presentation/documents_screen.dart';
import '../../features/driving/presentation/driving_screen.dart';
import '../../features/fotomultas/presentation/fotomultas_screen.dart';
import '../../features/garage/presentation/garage_screen.dart';
import '../../features/garage/presentation/vehicle_detail_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/maintenance/presentation/maintenance_screen.dart';
import '../../features/onboarding/presentation/onboarding_vehicle_screen.dart';
import '../../features/pico_placa/presentation/pico_detail_screen.dart';
import '../../features/services/presentation/services_screen.dart';
import '../../features/tramites/presentation/tramites_screen.dart';
import '../../features/trip/presentation/trip_screen.dart';
import '../../features/vehicle_status/presentation/vehicle_status_screen.dart';
import 'app_routes.dart';
import 'immersive_placeholder_screen.dart';

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
        redirect: (context, state) => picoCompatibilityLocation(state.uri),
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
            AppTab.trip => const TripScreen(),
            AppTab.drive => const DrivingScreen(),
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
      _picoRoute(),
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
      _picoRoute(),
      GoRoute(
        path: 'cda',
        builder: (context, state) => const CdaFinderScreen(),
      ),
      GoRoute(
        path: 'module/:id',
        builder: (context, state) {
          final moduleId = state.pathParameters['id']!;
          if (moduleId == 'fotomultas') {
            return const FotomultasScreen();
          }
          if (moduleId == 'comparendos') {
            return ComparendosScreen(
              vehicleId: state.uri.queryParameters['vehicleId'],
            );
          }
          if (moduleId == 'tramites') {
            return const TramitesScreen();
          }
          if (moduleId == 'documentos') {
            return DocumentsScreen(state.uri.queryParameters['vehicleId']);
          }
          if (moduleId == 'servicios') {
            return ServicesScreen(onOpenCda: () => context.push('/apps/cda'));
          }
          if (moduleId == 'talleres') {
            return MaintenanceScreen(
              vehicleId: state.uri.queryParameters['vehicleId'],
            );
          }
          if (_vehicleStatusModules.contains(moduleId)) {
            return VehicleStatusScreen(
              moduleId: moduleId,
              vehicleId: state.uri.queryParameters['vehicleId'],
            );
          }
          return ModulePlaceholderScreen(
            moduleId: moduleId,
            category: state.uri.queryParameters['category'],
          );
        },
      ),
    ],
    AppTab.home => [_picoRoute()],
    _ => const [],
  };
}

GoRoute _picoRoute() {
  return GoRoute(
    path: 'pico',
    builder: (context, state) => PicoDetailScreen(
      vehicleId: state.uri.queryParameters['vehicleId'],
      jurisdictionId: state.uri.queryParameters['jurisdictionId'],
    ),
  );
}

const _vehicleStatusModules = {
  'soat',
  'tecnomecanica',
  'seguro_asistencia',
  'impuestos',
};
