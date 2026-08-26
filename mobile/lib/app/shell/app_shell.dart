import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    icon: Icons.route_outlined,
    selectedIcon: Icons.route,
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
      bottomNavigationBar: NavigationBar(
        key: const ValueKey('app-bottom-navigation'),
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: [
          for (final tab in AppTab.values)
            NavigationDestination(
              key: ValueKey('tab-${tab.name}'),
              icon: Icon(tab.icon, size: AppIconSize.m),
              selectedIcon: Icon(tab.selectedIcon, size: AppIconSize.m),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}
