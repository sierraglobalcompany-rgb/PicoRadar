import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/app_components.dart';
import '../router/app_routes.dart';
import '../theme/app_tokens.dart';

enum AppTab {
  home(
    label: 'Inicio',
    route: AppRoute.home,
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    color: AppColors.teal,
    placeholderText: 'Raiz diaria de PicoRadar.',
  ),
  garage(
    label: 'Garaje',
    route: AppRoute.garage,
    icon: Icons.directions_car_outlined,
    selectedIcon: Icons.directions_car,
    color: AppColors.blue,
    placeholderText: 'Vehiculos, documentos y obligaciones.',
  ),
  apps(
    label: 'Apps',
    route: AppRoute.apps,
    icon: Icons.apps_outlined,
    selectedIcon: Icons.apps,
    color: AppColors.navy,
    placeholderText: 'Launcher central de modulos secundarios.',
  ),
  trip(
    label: 'Viaje',
    route: AppRoute.trip,
    icon: Icons.location_on_outlined,
    selectedIcon: Icons.location_on,
    color: AppColors.orange,
    placeholderText: 'Planeacion de ruta sin mapa propio.',
  ),
  drive(
    label: 'Conducir',
    route: AppRoute.drive,
    icon: Icons.speed_outlined,
    selectedIcon: Icons.speed,
    color: AppColors.red,
    placeholderText: 'Modo de conduccion de alta concentracion.',
  );

  const AppTab({
    required this.label,
    required this.route,
    required this.icon,
    required this.selectedIcon,
    required this.color,
    required this.placeholderText,
  });

  final String label;
  final AppRoute route;
  final IconData icon;
  final IconData selectedIcon;
  final Color color;
  final String placeholderText;
}

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AppBottomNav(
        destinations: [
          for (final tab in AppTab.values)
            AppBottomNavDestination(
              label: tab.label,
              icon: tab.icon,
              selectedIcon: tab.selectedIcon,
              color: tab.color,
              keyName: tab.name,
            ),
        ],
        currentIndex: navigationShell.currentIndex,
        onSelect: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}
