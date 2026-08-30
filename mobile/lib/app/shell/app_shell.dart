import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/app_components.dart';
import '../../features/apps_launcher/presentation/apps_launcher_panel.dart';
import '../../features/home/presentation/home_screen.dart';
import '../app_providers.dart';
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

class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _launcherOpen = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_launcherOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _launcherOpen) {
          _closeLauncher();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            widget.navigationShell,
            if (_launcherOpen) ...[
              Positioned.fill(
                child: Semantics(
                  button: true,
                  label: 'Cerrar Apps',
                  child: GestureDetector(
                    key: const ValueKey('apps-launcher-scrim'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _closeLauncher,
                    child: ColoredBox(
                      color: AppColors.navy.withValues(alpha: 0.24),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: AppsLauncherPanel(
                  key: const ValueKey('apps-launcher-overlay'),
                  vehicleId: _launcherVehicleId(),
                  onDismiss: _closeLauncher,
                  onNavigate: _openLauncherLocation,
                ),
              ),
            ],
          ],
        ),
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
          currentIndex: _launcherOpen
              ? AppTab.apps.index
              : widget.navigationShell.currentIndex,
          onSelect: _selectTab,
        ),
      ),
    );
  }

  Future<void> _selectTab(int index) async {
    if (index == AppTab.apps.index) {
      setState(() => _launcherOpen = !_launcherOpen);
      return;
    }

    final wasLauncherOpen = _launcherOpen;
    if (wasLauncherOpen) {
      setState(() => _launcherOpen = false);
    }
    if (widget.navigationShell.currentIndex == AppTab.home.index &&
        index == AppTab.drive.index) {
      await _promoteHomeFocusedVehicle();
    }
    if (!wasLauncherOpen || index != widget.navigationShell.currentIndex) {
      widget.navigationShell.goBranch(
        index,
        initialLocation: index == widget.navigationShell.currentIndex,
      );
    }
  }

  String? _launcherVehicleId() {
    final activeVehicleId = ref.watch(activeVehicleProvider).asData?.value?.id;
    final vehicles = ref.watch(vehicleListProvider).asData?.value;
    return resolveAppsLauncherVehicleId(
      currentIndex: widget.navigationShell.currentIndex,
      homeIndex: AppTab.home.index,
      focusedVehicleId: ref.watch(homeFocusedVehicleIdProvider),
      activeVehicleId: activeVehicleId,
      vehicleIds: [for (final vehicle in vehicles ?? const []) vehicle.id],
    );
  }

  void _closeLauncher() {
    if (!_launcherOpen) {
      return;
    }
    setState(() => _launcherOpen = false);
  }

  void _openLauncherLocation(String location) {
    _closeLauncher();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final branchIndex = _branchIndexForLocation(location);
      if (branchIndex != null) {
        widget.navigationShell.goBranch(branchIndex);
        return;
      }
      if (_isTopLevelOverlayLocation(location)) {
        context.push(location);
        return;
      }
      context.go(location);
    });
  }

  Future<void> _promoteHomeFocusedVehicle() async {
    final focusedVehicleId = ref.read(homeFocusedVehicleIdProvider);
    final activeVehicleId = ref.read(activeVehicleProvider).asData?.value?.id;
    if (focusedVehicleId == null || focusedVehicleId == activeVehicleId) {
      return;
    }
    await ref
        .read(vehicleRepositoryProvider)
        .setActiveVehicle(focusedVehicleId);
    ref.invalidate(activeVehicleProvider);
  }
}

int? _branchIndexForLocation(String location) {
  final path = Uri.parse(location).path;
  for (final tab in AppTab.values) {
    if (tab == AppTab.apps) {
      continue;
    }
    if (path == tab.route.path) {
      return tab.index;
    }
  }
  return null;
}

bool _isTopLevelOverlayLocation(String location) {
  final path = Uri.parse(location).path;
  return path == AppRoute.pico.path;
}

String? resolveAppsLauncherVehicleId({
  required int currentIndex,
  required int homeIndex,
  required String? focusedVehicleId,
  required String? activeVehicleId,
  required List<String> vehicleIds,
}) {
  final firstVehicleId = vehicleIds.isEmpty ? null : vehicleIds.first;
  if (currentIndex != homeIndex) {
    return activeVehicleId ?? firstVehicleId;
  }
  if (focusedVehicleId != null && vehicleIds.contains(focusedVehicleId)) {
    return focusedVehicleId;
  }
  return activeVehicleId ?? firstVehicleId;
}
