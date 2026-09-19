import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/app_components.dart';
import '../../features/apps_launcher/presentation/apps_launcher_panel.dart';
import '../../features/driving/application/driving_controller.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/documents/application/wallet_providers.dart';
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
  ),
  garage(
    label: 'Garaje',
    route: AppRoute.garage,
    icon: Icons.directions_car_outlined,
    selectedIcon: Icons.directions_car,
    color: AppColors.blue,
  ),
  apps(
    label: 'Apps',
    route: AppRoute.apps,
    icon: Icons.apps_outlined,
    selectedIcon: Icons.apps,
    color: AppColors.navy,
  ),
  trip(
    label: 'Viaje',
    route: AppRoute.trip,
    icon: Icons.location_on_outlined,
    selectedIcon: Icons.location_on,
    color: AppColors.orange,
  ),
  drive(
    label: 'Conducir',
    route: AppRoute.drive,
    icon: Icons.speed_outlined,
    selectedIcon: Icons.speed,
    color: AppColors.red,
  );

  const AppTab({
    required this.label,
    required this.route,
    required this.icon,
    required this.selectedIcon,
    required this.color,
  });

  final String label;
  final AppRoute route;
  final IconData icon;
  final IconData selectedIcon;
  final Color color;
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

// Keep the last branch when a root route temporarily replaces the shell.
final _shellBranchStateProvider = Provider((ref) => _ShellBranchState());

class _ShellBranchState {
  int? index;
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _launcherOpen = false;
  AppsLauncherMode _launcherMode = AppsLauncherMode.primary;
  bool _branchEntryScheduled = false;
  bool _drivingExitPending = false;

  @override
  void initState() {
    super.initState();
    _scheduleBranchEntry();
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationShell.currentIndex !=
        widget.navigationShell.currentIndex) {
      _scheduleBranchEntry();
    }
  }

  void _scheduleBranchEntry() {
    if (_branchEntryScheduled) return;
    _branchEntryScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _branchEntryScheduled = false;
      if (!mounted) return;
      final branch = ref.read(_shellBranchStateProvider);
      final previous = branch.index;
      final current = widget.navigationShell.currentIndex;
      branch.index = current;
      if (previous != null &&
          previous != AppTab.home.index &&
          current == AppTab.home.index) {
        ref.read(homePriorityEntryProvider.notifier).enterFromAnotherTab();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final drivingHudActive = ref.watch(drivingHudActiveProvider);
    final drivingActive = ref.watch(
      drivingControllerProvider.select(
        (value) => value.asData?.value.isActive ?? false,
      ),
    );
    final path = GoRouterState.of(context).uri.path;
    final isTabRoot = AppTab.values.any((tab) => tab.route.path == path);
    final handlesRootBack =
        isTabRoot &&
        (drivingActive ||
            widget.navigationShell.currentIndex != AppTab.home.index);
    return PopScope(
      canPop: !_launcherOpen && !handlesRootBack,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_launcherOpen) {
          _closeLauncher();
          return;
        }
        if (handlesRootBack) {
          unawaited(_handleRootBack(drivingActive: drivingActive));
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
                  mode: _launcherMode,
                  onModeChanged: (mode) => setState(() => _launcherMode = mode),
                ),
              ),
            ],
          ],
        ),
        bottomNavigationBar: drivingHudActive
            ? null
            : AppBottomNav(
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
                currentIndex:
                    _launcherOpen ||
                        GoRouterState.of(context).uri.path
                            .startsWith('${AppRoute.apps.path}/')
                    ? AppTab.apps.index
                    : widget.navigationShell.currentIndex,
                onSelect: _selectTab,
              ),
      ),
    );
  }

  Future<void> _selectTab(int index) async {
    final drivingActive =
        ref.read(drivingControllerProvider).asData?.value.isActive ?? false;
    if (drivingActive && index != AppTab.drive.index) {
      if (!await _stopDrivingBeforeLeaving()) return;
    }
    if (!mounted) return;
    if (ref.exists(walletSessionProvider)) {
      ref.read(walletSessionProvider).lock();
    }
    if (index == AppTab.apps.index) {
      setState(() {
        if (!_launcherOpen) {
          _launcherMode = AppsLauncherMode.primary;
        }
        _launcherOpen = !_launcherOpen;
      });
      return;
    }

    final wasLauncherOpen = _launcherOpen;
    if (wasLauncherOpen) {
      setState(() => _launcherOpen = false);
    }
    final fromPico = _isPicoShellLocation(GoRouterState.of(context).uri.path);
    if (!wasLauncherOpen || index != widget.navigationShell.currentIndex) {
      widget.navigationShell.goBranch(
        index,
        initialLocation:
            fromPico || index == widget.navigationShell.currentIndex,
      );
    }
  }

  Future<void> _handleRootBack({required bool drivingActive}) async {
    if (drivingActive && !await _stopDrivingBeforeLeaving()) return;
    if (!mounted) return;
    widget.navigationShell.goBranch(AppTab.home.index, initialLocation: true);
  }

  Future<bool> _stopDrivingBeforeLeaving() async {
    if (_drivingExitPending) return false;
    _drivingExitPending = true;
    try {
      final shouldStop = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Finalizar conducción'),
          content: const Text(
            'Para salir de Conducir, detén primero las alertas y el GPS de alta precisión.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Seguir conduciendo'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Finalizar y salir'),
            ),
          ],
        ),
      );
      if (shouldStop != true || !mounted) return false;
      await ref.read(drivingControllerProvider.notifier).stop();
      return mounted;
    } finally {
      _drivingExitPending = false;
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

  Future<void> _openLauncherLocation(String location) async {
    final origin = AppLaunchOrigin(
      tab: AppTab.values[widget.navigationShell.currentIndex],
      route: GoRouterState.of(context).uri.toString(),
      launcherMode: _launcherMode,
    );
    _closeLauncher();
    if (!location.startsWith('${AppRoute.apps.path}/')) {
      context.go(location);
      return;
    }
    await context.push<void>(location);
    if (!mounted) {
      return;
    }
    setState(() {
      _launcherMode = origin.launcherMode;
      _launcherOpen = true;
    });
  }
}

class AppLaunchOrigin {
  const AppLaunchOrigin({
    required this.tab,
    required this.route,
    required this.launcherMode,
  });

  final AppTab tab;
  final String route;
  final AppsLauncherMode launcherMode;
}

bool _isPicoShellLocation(String path) {
  return path == '${AppRoute.home.path}/pico' ||
      path == '${AppRoute.garage.path}/pico' ||
      path == '${AppRoute.apps.path}/pico';
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
