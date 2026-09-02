import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../app/theme/app_tokens.dart';
import '../application/driving_controller.dart';
import '../data/driving_preferences.dart';
import '../domain/camera_matcher.dart';
import '../domain/driving_alert_engine.dart';
import '../domain/traffic_camera.dart';
import '../../vehicle_status/platform/external_launcher.dart';
import 'driving_map_episode.dart';
import 'driving_radar.dart';

class DrivingScreen extends ConsumerStatefulWidget {
  const DrivingScreen({super.key});

  @override
  ConsumerState<DrivingScreen> createState() => _DrivingScreenState();
}

class _DrivingScreenState extends ConsumerState<DrivingScreen>
    with WidgetsBindingObserver {
  late final DrivingHudActiveNotifier _hudActiveNotifier;
  bool _hudMode = false;
  bool _hudMirror = false;

  @override
  void initState() {
    super.initState();
    _hudActiveNotifier = ref.read(drivingHudActiveProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _leaveHudMode(updateState: false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      ref.read(drivingControllerProvider.notifier).stop();
      _leaveHudMode();
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(drivingControllerProvider);
    return asyncState.when(
      loading: () => _DrivingDashboard(
        state: _initialDrivingState,
        onStart: () => ref.read(drivingControllerProvider.notifier).start(),
        onDebugRouteKnown: canUseDebugDrivingSimulation
            ? () => ref
                  .read(drivingControllerProvider.notifier)
                  .start(
                    simulationScenario: DrivingSimulationScenario.knownSpeed,
                  )
            : null,
        onDebugRouteUnknown: canUseDebugDrivingSimulation
            ? () => ref
                  .read(drivingControllerProvider.notifier)
                  .start(
                    simulationScenario: DrivingSimulationScenario.unknownSpeed,
                  )
            : null,
        onDebugRouteSide: canUseDebugDrivingSimulation
            ? () => ref
                  .read(drivingControllerProvider.notifier)
                  .start(simulationScenario: DrivingSimulationScenario.sidePass)
            : null,
        onDebugRouteLateralApproach: canUseDebugDrivingSimulation
            ? () => ref
                  .read(drivingControllerProvider.notifier)
                  .start(
                    simulationScenario:
                        DrivingSimulationScenario.lateralApproach,
                  )
            : null,
        onDebugRouteTurnAway: canUseDebugDrivingSimulation
            ? () => ref
                  .read(drivingControllerProvider.notifier)
                  .start(simulationScenario: DrivingSimulationScenario.turnAway)
            : null,
        onDebugRouteGpsWeak: canUseDebugDrivingSimulation
            ? () => ref
                  .read(drivingControllerProvider.notifier)
                  .start(simulationScenario: DrivingSimulationScenario.gpsWeak)
            : null,
        onStop: () => ref.read(drivingControllerProvider.notifier).stop(),
        onSettings: () => _showSettings(context, defaultDrivingPreferences),
        onHud: null,
        onMirrorHud: null,
      ),
      error: (error, stackTrace) => _DrivingError(message: error.toString()),
      data: (state) {
        if (_hudMode) {
          _setImmersiveActive(true);
          return _HudView(
            state: state,
            mirror: _hudMirror,
            onExit: _leaveHudMode,
          );
        }
        _setImmersiveActive(state.isActive);
        return _DrivingDashboard(
          state: state,
          onStart: () => ref.read(drivingControllerProvider.notifier).start(),
          onDebugRouteKnown: canUseDebugDrivingSimulation
              ? () => ref
                    .read(drivingControllerProvider.notifier)
                    .start(
                      simulationScenario: DrivingSimulationScenario.knownSpeed,
                    )
              : null,
          onDebugRouteUnknown: canUseDebugDrivingSimulation
              ? () => ref
                    .read(drivingControllerProvider.notifier)
                    .start(
                      simulationScenario:
                          DrivingSimulationScenario.unknownSpeed,
                    )
              : null,
          onDebugRouteSide: canUseDebugDrivingSimulation
              ? () => ref
                    .read(drivingControllerProvider.notifier)
                    .start(
                      simulationScenario: DrivingSimulationScenario.sidePass,
                    )
              : null,
          onDebugRouteLateralApproach: canUseDebugDrivingSimulation
              ? () => ref
                    .read(drivingControllerProvider.notifier)
                    .start(
                      simulationScenario:
                          DrivingSimulationScenario.lateralApproach,
                    )
              : null,
          onDebugRouteTurnAway: canUseDebugDrivingSimulation
              ? () => ref
                    .read(drivingControllerProvider.notifier)
                    .start(
                      simulationScenario: DrivingSimulationScenario.turnAway,
                    )
              : null,
          onDebugRouteGpsWeak: canUseDebugDrivingSimulation
              ? () => ref
                    .read(drivingControllerProvider.notifier)
                    .start(
                      simulationScenario: DrivingSimulationScenario.gpsWeak,
                    )
              : null,
          onStop: () => ref.read(drivingControllerProvider.notifier).stop(),
          onSettings: () => _showSettings(context, state.preferences),
          onHud: state.isActive
              ? () => _enterHudMode(mirror: state.preferences.hudMirrorEnabled)
              : null,
          onMirrorHud: state.isActive
              ? () => _enterHudMode(mirror: true)
              : null,
        );
      },
    );
  }

  Future<void> _showSettings(
    BuildContext context,
    DrivingPreferences preferences,
  ) async {
    final updated = await showModalBottomSheet<DrivingPreferences>(
      context: context,
      showDragHandle: true,
      builder: (context) => _DrivingSettingsSheet(
        initial: preferences,
        cameraPackSource: ref
            .read(drivingControllerProvider)
            .asData
            ?.value
            .cameraPackSource,
      ),
    );
    if (updated != null) {
      await ref
          .read(drivingControllerProvider.notifier)
          .savePreferences(updated);
    }
  }

  void _enterHudMode({required bool mirror}) {
    setState(() {
      _hudMode = true;
      _hudMirror = mirror;
    });
    _hudActiveNotifier.setActive(true);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  void _setImmersiveActive(bool value) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _hudActiveNotifier.setActive(value);
      }
    });
  }

  void _leaveHudMode({bool updateState = true}) {
    _hudActiveNotifier.setActive(false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    if (updateState && mounted && _hudMode) {
      setState(() {
        _hudMode = false;
        _hudMirror = false;
      });
    }
  }
}

const _initialDrivingState = DrivingState(
  status: DrivingSessionStatus.idle,
  preferences: defaultDrivingPreferences,
  cameraCount: 0,
  cameraSpeedKnownCount: 0,
);

final drivingMapConfigProvider = Provider<DrivingMapConfig>(
  (ref) => DrivingMapConfig.fromEnvironment(),
);

class DrivingMapConfig {
  const DrivingMapConfig({
    required this.tileUrlTemplate,
    required this.attributionLabel,
    required this.userAgentPackageName,
    required this.forceOfflineFallback,
    this.tileProvider,
  });

  factory DrivingMapConfig.fromEnvironment() {
    return const DrivingMapConfig(
      tileUrlTemplate: String.fromEnvironment(
        'PICORADAR_DRIVING_TILE_URL_TEMPLATE',
        defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      ),
      attributionLabel: 'OpenStreetMap contributors',
      userAgentPackageName: String.fromEnvironment(
        'PICORADAR_DRIVING_TILE_USER_AGENT',
        defaultValue: 'co.picoradar.app.dev',
      ),
      forceOfflineFallback: bool.fromEnvironment(
        'PICORADAR_FORCE_CAMERA_MAP_FALLBACK',
      ),
    );
  }

  final String tileUrlTemplate;
  final String attributionLabel;
  final String userAgentPackageName;
  final bool forceOfflineFallback;
  final TileProvider? tileProvider;
}

Duration _motionDuration(BuildContext context, Duration duration) {
  return (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
      ? Duration.zero
      : duration;
}

class _DrivingDashboard extends StatelessWidget {
  const _DrivingDashboard({
    required this.state,
    required this.onStart,
    required this.onDebugRouteKnown,
    required this.onDebugRouteUnknown,
    required this.onDebugRouteSide,
    required this.onDebugRouteLateralApproach,
    required this.onDebugRouteTurnAway,
    required this.onDebugRouteGpsWeak,
    required this.onStop,
    required this.onSettings,
    required this.onHud,
    required this.onMirrorHud,
  });

  final DrivingState state;
  final VoidCallback onStart;
  final VoidCallback? onDebugRouteKnown;
  final VoidCallback? onDebugRouteUnknown;
  final VoidCallback? onDebugRouteSide;
  final VoidCallback? onDebugRouteLateralApproach;
  final VoidCallback? onDebugRouteTurnAway;
  final VoidCallback? onDebugRouteGpsWeak;
  final VoidCallback onStop;
  final VoidCallback onSettings;
  final VoidCallback? onHud;
  final VoidCallback? onMirrorHud;

  @override
  Widget build(BuildContext context) {
    final active = state.isActive;
    if (active) {
      return ColoredBox(
        color: const Color(0xFF071622),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              AppSpacing.m,
              AppSpacing.l,
              AppSpacing.m,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final hasAlertSpace =
                    state.showCameraAlertPanel ||
                    state.dismissedCameraId != null;
                final motionDuration = _motionDuration(
                  context,
                  const Duration(milliseconds: 320),
                );
                final gaugeHeight = hasAlertSpace
                    ? (constraints.maxHeight * 0.48)
                          .clamp(282.0, 344.0)
                          .toDouble()
                    : math.max(360.0, constraints.maxHeight - 168);
                return Column(
                  children: [
                    _DrivingTopBar(
                      state: state,
                      onHud: onHud,
                      onMirrorHud: onMirrorHud,
                    ),
                    AnimatedContainer(
                      duration: motionDuration,
                      curve: Curves.easeOutCubic,
                      height: gaugeHeight,
                      child: LayoutBuilder(
                        builder: (context, gaugeConstraints) {
                          final showSpeedBadge =
                              state.showCameraAlertPanel &&
                              state.reportedCameraSpeedKmh != null;
                          final diameter = math.min(
                            showSpeedBadge
                                ? 288.0
                                : hasAlertSpace
                                ? 270.0
                                : 316.0,
                            math.min(
                              gaugeConstraints.maxWidth * 0.88,
                              gaugeConstraints.maxHeight * 0.98,
                            ),
                          );
                          if (showSpeedBadge) {
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                AnimatedAlign(
                                  duration: motionDuration,
                                  curve: Curves.easeOutCubic,
                                  alignment: const Alignment(0, -0.05),
                                  child: _SpeedGauge(
                                    key: const ValueKey('driving-speed-gauge'),
                                    state: state,
                                    diameter: diameter,
                                    speedFontSize: math.max(
                                      88.0,
                                      diameter * 0.46,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 102,
                                  right: 0,
                                  child: _GaugeSpeedLimitBadge(
                                    speedKmh: state.reportedCameraSpeedKmh!,
                                  ),
                                ),
                              ],
                            );
                          }
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              AnimatedAlign(
                                duration: motionDuration,
                                curve: Curves.easeOutCubic,
                                alignment: hasAlertSpace
                                    ? Alignment.topCenter
                                    : Alignment.center,
                                child: _SpeedGauge(
                                  key: const ValueKey('driving-speed-gauge'),
                                  state: state,
                                  diameter: diameter,
                                  speedFontSize: math.max(
                                    72.0,
                                    diameter * 0.42,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (hasAlertSpace)
                      Flexible(
                        child: LayoutBuilder(
                          builder: (context, alertConstraints) {
                            return SingleChildScrollView(
                              physics: const ClampingScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: alertConstraints.maxHeight,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    _CameraAlertSwitcher(state: state),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    else
                      const Spacer(),
                    const SizedBox(height: AppSpacing.s),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const ValueKey('stop-driving'),
                        onPressed: onStop,
                        icon: const Icon(Icons.stop),
                        label: const Text('Finalizar'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    }
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          Row(
            children: [
              const Expanded(child: Text('Conducir', style: AppTextStyles.h1)),
              IconButton(
                tooltip: 'Alertas',
                onPressed: onSettings,
                icon: const Icon(Icons.tune),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          _ReadySummary(state: state),
          if (state.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.l),
            _StatusMessage(message: state.errorMessage!),
          ],
          const SizedBox(height: AppSpacing.l),
          FilledButton.icon(
            key: const ValueKey('start-driving'),
            onPressed: state.status == DrivingSessionStatus.starting
                ? null
                : onStart,
            icon: const Icon(Icons.play_arrow),
            label: Text(
              state.status == DrivingSessionStatus.starting
                  ? 'Preparando'
                  : 'Iniciar conducción',
            ),
          ),
          if (onDebugRouteKnown != null ||
              onDebugRouteUnknown != null ||
              onDebugRouteSide != null ||
              onDebugRouteLateralApproach != null ||
              onDebugRouteTurnAway != null ||
              onDebugRouteGpsWeak != null) ...[
            const SizedBox(height: AppSpacing.s),
            OutlinedButton.icon(
              key: const ValueKey('debug-driving-route'),
              onPressed: state.status == DrivingSessionStatus.starting
                  ? null
                  : onDebugRouteKnown,
              icon: const Icon(Icons.route),
              label: const Text('Ruta demo · con velocidad'),
            ),
            const SizedBox(height: AppSpacing.s),
            OutlinedButton.icon(
              key: const ValueKey('debug-driving-route-unknown'),
              onPressed: state.status == DrivingSessionStatus.starting
                  ? null
                  : onDebugRouteUnknown,
              icon: const Icon(Icons.route_outlined),
              label: const Text('Ruta demo · sin velocidad'),
            ),
            const SizedBox(height: AppSpacing.s),
            OutlinedButton.icon(
              key: const ValueKey('debug-driving-route-side'),
              onPressed: state.status == DrivingSessionStatus.starting
                  ? null
                  : onDebugRouteSide,
              icon: const Icon(Icons.alt_route),
              label: const Text('Ruta demo · cámara lateral'),
            ),
            const SizedBox(height: AppSpacing.s),
            OutlinedButton.icon(
              key: const ValueKey('debug-driving-route-lateral-approach'),
              onPressed: state.status == DrivingSessionStatus.starting
                  ? null
                  : onDebugRouteLateralApproach,
              icon: const Icon(Icons.radar),
              label: const Text('Ruta demo · radar 500 m'),
            ),
            const SizedBox(height: AppSpacing.s),
            OutlinedButton.icon(
              key: const ValueKey('debug-driving-route-turn-away'),
              onPressed: state.status == DrivingSessionStatus.starting
                  ? null
                  : onDebugRouteTurnAway,
              icon: const Icon(Icons.turn_right),
              label: const Text('Ruta demo · giro antes'),
            ),
            const SizedBox(height: AppSpacing.s),
            OutlinedButton.icon(
              key: const ValueKey('debug-driving-route-gps-weak'),
              onPressed: state.status == DrivingSessionStatus.starting
                  ? null
                  : onDebugRouteGpsWeak,
              icon: const Icon(Icons.gps_off),
              label: const Text('Ruta demo · GPS débil'),
            ),
          ],
          const SizedBox(height: AppSpacing.m),
          Text(
            'Ubicación activa solo mientras conduces. No se guarda recorrido '
            'ni se envía al servidor.',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.navy.withValues(alpha: 0.66),
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugeSpeedLimitBadge extends StatelessWidget {
  const _GaugeSpeedLimitBadge({required this.speedKmh});

  final int speedKmh;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: _CameraSpeedSign(
        key: const ValueKey('camera-speed-sign'),
        speedKmh: speedKmh,
        size: 72,
      ),
    );
  }
}

class _CameraAlertSwitcher extends StatelessWidget {
  const _CameraAlertSwitcher({required this.state});

  final DrivingState state;

  @override
  Widget build(BuildContext context) {
    final motionDuration = _motionDuration(
      context,
      const Duration(milliseconds: 260),
    );
    return AnimatedSwitcher(
      duration: motionDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.18),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: state.showCameraAlertPanel
          ? _CameraPanel(
              key: ValueKey('camera-panel-${state.nearestCamera!.camera.id}'),
              state: state,
            )
          : state.dismissedCameraId != null
          ? _DismissedAlertChip(
              key: const ValueKey('driving-camera-dismissed'),
              state: state,
            )
          : const SizedBox(
              key: ValueKey('driving-camera-alert-empty'),
              height: 0,
            ),
    );
  }
}

class _ReadySummary extends StatelessWidget {
  const _ReadySummary({required this.state});

  final DrivingState state;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Listo para conducir',
              style: AppTextStyles.caption.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: AppSpacing.s),
            const Text(
              'Conducir',
              style: TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            Text(
              '${state.cameraCount} cámaras disponibles',
              style: AppTextStyles.caption.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${state.cameraSpeedKnownCount} con velocidad reportada por la '
              'fuente oficial',
              key: const ValueKey('ready-speed-coverage'),
              style: AppTextStyles.caption.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Base de cámaras actualizada: '
              '${_formatCameraPackDate(state.cameraPackSource)}',
              style: AppTextStyles.caption.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrivingTopBar extends StatelessWidget {
  const _DrivingTopBar({
    required this.state,
    required this.onHud,
    required this.onMirrorHud,
  });

  final DrivingState state;
  final VoidCallback? onHud;
  final VoidCallback? onMirrorHud;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TopStatusChip(
          key: const ValueKey('driving-connection-chip'),
          icon: Icons.circle,
          label: state.gpsQuality.label,
          color: state.canEvaluateAlerts ? AppColors.teal : AppColors.orange,
        ),
        const Spacer(),
        _TopStatusChip(
          key: const ValueKey('driving-country-chip'),
          icon: Icons.flag_outlined,
          label: 'Colombia',
          color: AppColors.plateYellow,
        ),
        IconButton(
          tooltip: 'HUD',
          onPressed: onHud,
          color: Colors.white,
          icon: const Icon(Icons.flip_to_front),
        ),
        IconButton(
          key: const ValueKey('hud-mirror-action'),
          tooltip: 'HUD espejo',
          onPressed: onMirrorHud,
          color: Colors.white,
          icon: const Icon(Icons.flip),
        ),
      ],
    );
  }
}

class _TopStatusChip extends StatelessWidget {
  const _TopStatusChip({
    required this.icon,
    required this.label,
    required this.color,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrivingStatusChip extends StatelessWidget {
  const _DrivingStatusChip({required this.state});

  final DrivingState state;

  @override
  Widget build(BuildContext context) {
    final colors = _DrivingColors.forSpeedState(state.speedState);
    final label = switch (state.speedState) {
      DrivingSpeedState.over => 'Reduce velocidad',
      DrivingSpeedState.near => 'Cerca del valor reportado',
      DrivingSpeedState.within => 'Vía clara',
      DrivingSpeedState.unknownReportedSpeed => 'Fotodetección sin velocidad',
      DrivingSpeedState.noCamera =>
        state.canEvaluateAlerts
            ? 'Sin cámara objetivo'
            : state.gpsQuality.label,
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: DecoratedBox(
        key: const ValueKey('driving-state-chip'),
        decoration: BoxDecoration(
          color: colors.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.accent.withValues(alpha: 0.62)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: AppSpacing.xs,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyStrong.copyWith(color: colors.accent),
          ),
        ),
      ),
    );
  }
}

class _DismissedAlertChip extends StatelessWidget {
  const _DismissedAlertChip({required this.state, super.key});

  final DrivingState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: AppSpacing.s,
          ),
          child: Text(
            'Alerta silenciada para esta cámara',
            style: AppTextStyles.caption.copyWith(color: Colors.white70),
          ),
        ),
      ),
    );
  }
}

class _CameraPanel extends ConsumerWidget {
  const _CameraPanel({required this.state, super.key});

  final DrivingState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final match = state.nearestCamera!;
    final urgent = state.isOverspeeding;
    final color = _cameraPanelAccent(state);
    final compactPanel = MediaQuery.sizeOf(context).height < 820;
    final mapHeight = compactPanel ? 156.0 : 184.0;
    void dismissAlert() {
      ref.read(drivingControllerProvider.notifier).dismissCurrentCameraAlert();
    }

    return GestureDetector(
      key: const ValueKey('driving-camera-alert-panel'),
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 180) {
          dismissAlert();
        }
      },
      onVerticalDragUpdate: (details) {
        if ((details.primaryDelta ?? 0) > 64) {
          dismissAlert();
        }
      },
      child: Padding(
        padding: EdgeInsets.zero,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xEA0B1D2C),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: color.withValues(alpha: 0.78)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.2),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.m,
              AppSpacing.s,
              AppSpacing.m,
              AppSpacing.m,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  key: const ValueKey('driving-camera-alert-header'),
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragEnd: (details) {
                    if ((details.primaryVelocity ?? 0) > 180) {
                      dismissAlert();
                    }
                  },
                  onVerticalDragUpdate: (details) {
                    if ((details.primaryDelta ?? 0) > 64) {
                      dismissAlert();
                    }
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AlertIcon(
                        key: ValueKey(
                          urgent
                              ? 'driving-camera-alert-icon-urgent'
                              : 'driving-camera-alert-icon-camera',
                        ),
                        color: color,
                        urgent: urgent,
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _cameraTitle(match.camera),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyStrong.copyWith(
                                color: Colors.white,
                                height: 1.08,
                              ),
                            ),
                            Text(
                              _cameraDistanceLabel(match),
                              key: const ValueKey('camera-distance-pill'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyStrong.copyWith(
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filled(
                        key: const ValueKey('driving-camera-map-action'),
                        tooltip: 'Cómo llegar',
                        onPressed: () => _openCameraMap(ref, match.camera),
                        iconSize: 16,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.square(30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.near_me_outlined),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      IconButton.filled(
                        key: const ValueKey('driving-camera-detail-action'),
                        tooltip: 'Fuente de cámara',
                        onPressed: () =>
                            _showCameraDetails(context, ref, match.camera),
                        iconSize: 16,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.square(30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.info_outline),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      IconButton.filled(
                        key: const ValueKey('driving-camera-dismiss-action'),
                        tooltip: 'Cerrar alerta de fotodetección',
                        onPressed: dismissAlert,
                        iconSize: 16,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.square(30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      flex: 4,
                      child: _CameraMiniMap(
                        key: const ValueKey('driving-mini-map'),
                        match: match,
                        episodeKey: state.cameraEpisodeKey ?? match.camera.id,
                        currentPoint: state.currentPoint!,
                        targetingConeDegrees:
                            state.preferences.cameraTargetingConeDegrees,
                        visualizationMode:
                            state.preferences.cameraVisualizationMode,
                        alertColor: color,
                        height: mapHeight,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Flexible(
                      flex: 5,
                      child: _CameraPanelFacts(state: state, match: match),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCameraDetails(
    BuildContext context,
    WidgetRef ref,
    TrafficCamera camera,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              key: const ValueKey('driving-camera-detail-sheet'),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.l,
                0,
                AppSpacing.l,
                AppSpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Fuente de cámara', style: AppTextStyles.h2),
                  const SizedBox(height: AppSpacing.m),
                  _CameraDetailLine(label: 'Ubicación', value: camera.locality),
                  _CameraDetailLine(
                    label: 'Dirección',
                    value: camera.address ?? 'No publicada',
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  OutlinedButton.icon(
                    key: const ValueKey('driving-camera-map-action-sheet'),
                    onPressed: () => _openCameraMap(ref, camera),
                    icon: const Icon(Icons.near_me_outlined),
                    label: const Text('Ver en Google Maps'),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  _CameraDetailLine(
                    label: 'Autoridad de tránsito',
                    value: camera.trafficAuthority ?? 'No publicada',
                  ),
                  _CameraDetailGrid(camera: camera),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCameraMap(WidgetRef ref, TrafficCamera camera) async {
    await ref
        .read(externalLauncherProvider)
        .openExternal(_cameraMapUri(camera).toString());
  }
}

class _AlertIcon extends StatelessWidget {
  const _AlertIcon({required this.color, required this.urgent, super.key});

  final Color color;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.58)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s),
        child: Icon(
          urgent ? Icons.warning_amber_rounded : Icons.videocam_outlined,
          color: color,
        ),
      ),
    );
  }
}

class _CameraMiniMap extends ConsumerStatefulWidget {
  const _CameraMiniMap({
    required this.match,
    required this.episodeKey,
    required this.currentPoint,
    required this.targetingConeDegrees,
    required this.visualizationMode,
    required this.alertColor,
    required this.height,
    super.key,
  });

  final CameraMatch match;
  final String episodeKey;
  final DrivingPoint currentPoint;
  final int targetingConeDegrees;
  final CameraVisualizationMode visualizationMode;
  final Color alertColor;
  final double height;

  @override
  ConsumerState<_CameraMiniMap> createState() => _CameraMiniMapState();
}

class _CameraMiniMapState extends ConsumerState<_CameraMiniMap> {
  late final CameraMapEpisodeStateMachine _mapEpisode;
  Timer? _mapTimeoutTimer;
  String? _mapTimeoutEpisodeKey;

  @override
  void initState() {
    super.initState();
    _mapEpisode = CameraMapEpisodeStateMachine();
    _beginMapEpisode();
  }

  @override
  void didUpdateWidget(covariant _CameraMiniMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.episodeKey != widget.episodeKey) {
      _cancelMapTimeout();
      _beginMapEpisode();
    }
  }

  @override
  void dispose() {
    _cancelMapTimeout();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mapConfig = ref.watch(drivingMapConfigProvider);
    final radarOnly = widget.visualizationMode == CameraVisualizationMode.radar;
    final canTryMap =
        widget.visualizationMode == CameraVisualizationMode.auto ||
        widget.visualizationMode == CameraVisualizationMode.map;
    final forcedFallback =
        radarOnly ||
        mapConfig.forceOfflineFallback ||
        mapConfig.tileUrlTemplate.trim().isEmpty;
    final mapState =
        CameraMapEpisodeCache.read(widget.episodeKey) ?? _mapEpisode.state;
    final showFallback =
        forcedFallback || mapState == CameraMapEpisodeViewState.fallback;
    final showPendingRadar =
        !forcedFallback &&
        canTryMap &&
        mapState == CameraMapEpisodeViewState.pending;
    if (showPendingRadar) {
      _ensureMapTimeoutScheduled();
    } else {
      _cancelMapTimeout();
    }
    final showFallbackLabel = !radarOnly && canTryMap && showFallback;
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: showFallback || showPendingRadar
            ? Stack(
                fit: StackFit.expand,
                children: [
                  _CameraOfflineRadar(
                    key: const ValueKey('driving-map-offline-fallback'),
                    match: widget.match,
                    currentPoint: widget.currentPoint,
                    targetingConeDegrees: widget.targetingConeDegrees,
                    alertColor: widget.alertColor,
                    fallbackLabel: showFallbackLabel
                        ? 'Sin conexión · Radar'
                        : null,
                  ),
                  if (showPendingRadar)
                    Opacity(
                      opacity: 0,
                      child: IgnorePointer(
                        child: _RealCameraMiniMap(
                          key: const ValueKey('driving-real-mini-map'),
                          match: widget.match,
                          currentPoint: widget.currentPoint,
                          alertColor: widget.alertColor,
                          config: mapConfig,
                          episodeKey: widget.episodeKey,
                          onTileReady: _markMapReady,
                          onTileError: _markMapFallback,
                        ),
                      ),
                    ),
                ],
              )
            : _RealCameraMiniMap(
                key: const ValueKey('driving-real-mini-map'),
                match: widget.match,
                currentPoint: widget.currentPoint,
                alertColor: widget.alertColor,
                config: mapConfig,
                episodeKey: widget.episodeKey,
                onTileReady: _markMapReady,
                onTileError: _markMapFallback,
              ),
      ),
    );
  }

  void _beginMapEpisode() {
    final now = DateTime.now().toUtc();
    _mapEpisode.begin(widget.episodeKey, now);
    final cachedState = CameraMapEpisodeCache.read(widget.episodeKey);
    if (cachedState != null) {
      if (cachedState == CameraMapEpisodeViewState.ready) {
        _mapEpisode.markReady(widget.episodeKey);
      } else if (cachedState == CameraMapEpisodeViewState.fallback) {
        _mapEpisode.markFallback(widget.episodeKey);
      }
    }
  }

  void _ensureMapTimeoutScheduled() {
    if (_mapTimeoutTimer != null &&
        _mapTimeoutEpisodeKey == widget.episodeKey) {
      return;
    }
    _cancelMapTimeout();
    if (_mapEpisode.state != CameraMapEpisodeViewState.pending) {
      return;
    }
    final episodeKey = widget.episodeKey;
    _mapTimeoutEpisodeKey = episodeKey;
    _mapTimeoutTimer = Timer(drivingMapTileReadinessTimeout, () {
      if (!mounted ||
          _mapTimeoutEpisodeKey != episodeKey ||
          !_mapEpisode.markFallback(episodeKey)) {
        return;
      }
      CameraMapEpisodeCache.write(episodeKey, _mapEpisode.state);
      _cancelMapTimeout();
      setState(() {});
    });
  }

  void _markMapReady(String episodeKey) {
    if (!mounted ||
        episodeKey != widget.episodeKey ||
        !_mapEpisode.markReady(episodeKey)) {
      return;
    }
    CameraMapEpisodeCache.write(episodeKey, _mapEpisode.state);
    _cancelMapTimeout();
    setState(() {});
  }

  void _markMapFallback(String episodeKey) {
    if (!mounted ||
        episodeKey != widget.episodeKey ||
        !_mapEpisode.markFallback(episodeKey)) {
      return;
    }
    CameraMapEpisodeCache.write(episodeKey, _mapEpisode.state);
    _cancelMapTimeout();
    setState(() {});
  }

  void _cancelMapTimeout() {
    _mapTimeoutTimer?.cancel();
    _mapTimeoutTimer = null;
    _mapTimeoutEpisodeKey = null;
  }
}

class _RealCameraMiniMap extends StatelessWidget {
  const _RealCameraMiniMap({
    required this.match,
    required this.currentPoint,
    required this.alertColor,
    required this.config,
    required this.episodeKey,
    required this.onTileReady,
    required this.onTileError,
    super.key,
  });

  final CameraMatch match;
  final DrivingPoint currentPoint;
  final Color alertColor;
  final DrivingMapConfig config;
  final String episodeKey;
  final ValueChanged<String> onTileReady;
  final ValueChanged<String> onTileError;

  @override
  Widget build(BuildContext context) {
    final ownerEpisodeKey = episodeKey;
    final userPoint = LatLng(currentPoint.latitude, currentPoint.longitude);
    final cameraPoint = LatLng(match.camera.latitude, match.camera.longitude);
    final initialCenter = LatLng(
      (userPoint.latitude + cameraPoint.latitude) / 2,
      (userPoint.longitude + cameraPoint.longitude) / 2,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: _initialMiniMapZoom(match.distanceMeters),
            initialCameraFit: CameraFit.coordinates(
              coordinates: [userPoint, cameraPoint],
              padding: const EdgeInsets.fromLTRB(26, 24, 26, 38),
              maxZoom: _maxMiniMapZoom(match.distanceMeters),
              minZoom: 13,
            ),
            minZoom: 10,
            maxZoom: 18,
            backgroundColor: const Color(0xFF07111B),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: config.tileUrlTemplate,
              userAgentPackageName: config.userAgentPackageName,
              tileProvider: config.tileProvider,
              keepBuffer: 0,
              panBuffer: 0,
              tileDisplay: const TileDisplay.instantaneous(),
              tileBuilder: (context, tileWidget, tile) {
                if (!tile.loadError && tile.readyToDisplay) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    onTileReady(ownerEpisodeKey);
                  });
                }
                return tileWidget;
              },
              errorTileCallback: (tile, error, stackTrace) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  onTileError(ownerEpisodeKey);
                });
              },
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: userPoint,
                  width: 34,
                  height: 34,
                  child: _MiniMapUserMarker(
                    key: const ValueKey('driving-map-user-marker'),
                    headingDegrees: currentPoint.headingDegrees,
                  ),
                ),
                Marker(
                  point: cameraPoint,
                  width: 34,
                  height: 34,
                  child: _MiniMapCameraMarker(
                    key: const ValueKey('driving-map-camera-marker'),
                    color: alertColor,
                  ),
                ),
              ],
            ),
          ],
        ),
        Positioned(
          right: 6,
          bottom: 5,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.52),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                '© ${config.attributionLabel}',
                key: const ValueKey('driving-map-attribution'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniMapUserMarker extends StatelessWidget {
  const _MiniMapUserMarker({required this.headingDegrees, super.key});

  final double? headingDegrees;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: 0.22),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.blue.withValues(alpha: 0.34),
            blurRadius: 16,
          ),
        ],
      ),
      child: Center(
        child: Transform.rotate(
          angle: (headingDegrees ?? 0) * math.pi / 180,
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: AppColors.blue,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.navigation_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniMapCameraMarker extends StatelessWidget {
  const _MiniMapCameraMarker({required this.color, super.key});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.24),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.36), blurRadius: 16),
        ],
      ),
      child: Center(
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const Icon(Icons.photo_camera, color: Colors.white, size: 15),
        ),
      ),
    );
  }
}

class _CameraOfflineRadar extends StatelessWidget {
  const _CameraOfflineRadar({
    required this.match,
    required this.currentPoint,
    required this.targetingConeDegrees,
    required this.alertColor,
    this.fallbackLabel,
    super.key,
  });

  final CameraMatch match;
  final DrivingPoint currentPoint;
  final int targetingConeDegrees;
  final Color alertColor;
  final String? fallbackLabel;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DrivingRadarView(
          match: match,
          currentPoint: currentPoint,
          targetingConeDegrees: targetingConeDegrees,
          alertColor: alertColor,
        ),
        if (fallbackLabel case final label?)
          Positioned(
            left: 8,
            right: 8,
            bottom: 7,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.52),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  label,
                  key: const ValueKey('driving-map-fallback-label'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CameraPanelFacts extends StatelessWidget {
  const _CameraPanelFacts({required this.state, required this.match});

  final DrivingState state;
  final CameraMatch match;

  @override
  Widget build(BuildContext context) {
    final camera = match.camera;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CameraFactBlock(
          key: const ValueKey('driving-camera-address'),
          label: 'Dirección',
          value: _cameraLocationText(camera),
          maxLines: 3,
        ),
        const SizedBox(height: AppSpacing.m),
        _CameraFactBlock(
          key: const ValueKey('camera-authority-row'),
          label: 'Autoridad',
          value: _compactTrafficAuthority(camera.trafficAuthority),
          maxLines: 2,
        ),
      ],
    );
  }
}

class _CameraFactBlock extends StatelessWidget {
  const _CameraFactBlock({
    required this.label,
    required this.value,
    this.maxLines = 2,
    super.key,
  });

  final String label;
  final String value;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(
            color: Colors.white.withValues(alpha: 0.58),
            height: 1.05,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            height: 1.12,
          ),
        ),
      ],
    );
  }
}

String _cameraLocationText(TrafficCamera camera) {
  final address = camera.address?.trim();
  if (address != null && address.isNotEmpty) {
    return address
        .replaceAll(' (TRAMO DE VÍA, SENTIDO ', '\nSentido ')
        .replaceAll(' (TRAMO DE VIA, SENTIDO ', '\nSentido ')
        .replaceAll(')', '');
  }
  return camera.locality;
}

String _compactTrafficAuthority(String? authority) {
  final text = authority?.trim();
  if (text == null || text.isEmpty) {
    return 'No publicada';
  }
  final normalized = text
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll('SECRETARIA', 'Secretaría')
      .replaceAll('TRANSITO', 'Tránsito');
  return normalized
      .replaceAll(
        'Secretaría DE MOVILIDAD Y Tránsito DE ',
        'Movilidad y Tránsito ',
      )
      .replaceAll(
        'SECRETARÍA DE MOVILIDAD Y TRÁNSITO DE ',
        'Movilidad y Tránsito ',
      );
}

String _cameraTitle(TrafficCamera camera) {
  return 'Cámara detectada';
}

String _cameraDistanceLabel(CameraMatch match) {
  final status = match.camera.operationStatus?.trim();
  if (status == null || status.isEmpty) {
    return 'A ${match.distanceMeters.round()} m';
  }
  return 'A ${match.distanceMeters.round()} m · $status';
}

Uri _cameraMapUri(TrafficCamera camera) {
  return Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': '${camera.latitude},${camera.longitude}',
  });
}

String _cameraDetailValue(String? value, String fallback) {
  final text = value?.trim();
  if (text == null || text.isEmpty) {
    return fallback;
  }
  return text
      .replaceAll('Camara', 'Cámara')
      .replaceAll('camara', 'cámara')
      .replaceAll('Fotodeteccion', 'Fotodetección')
      .replaceAll('fotodeteccion', 'fotodetección')
      .replaceAll('Semaforo', 'Semáforo')
      .replaceAll('semaforo', 'semáforo');
}

class _CameraDetailLine extends StatelessWidget {
  const _CameraDetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          Text(value, style: const TextStyle(fontSize: 14, height: 1.16)),
        ],
      ),
    );
  }
}

class _CameraDetailGrid extends StatelessWidget {
  const _CameraDetailGrid({required this.camera});

  final TrafficCamera camera;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - AppSpacing.s) / 2;
        return Wrap(
          spacing: AppSpacing.s,
          runSpacing: AppSpacing.xs,
          children: [
            _CameraDetailTile(
              width: tileWidth,
              label: 'Jurisdicción',
              value: camera.jurisdiction ?? 'No publicada',
            ),
            _CameraDetailTile(
              width: tileWidth,
              label: 'Tecnología',
              value: _cameraDetailValue(camera.technology, 'No publicada'),
            ),
            _CameraDetailTile(
              width: tileWidth,
              label: 'Tipo de instalación',
              value: _cameraDetailValue(
                camera.installationType,
                'No publicado',
              ),
            ),
            _CameraDetailTile(
              width: tileWidth,
              label: 'Equipo',
              value: camera.equipmentName ?? 'No publicado',
            ),
            _CameraDetailTile(
              width: tileWidth,
              label: 'Estado operación',
              value: camera.operationStatus ?? 'No publicado',
            ),
            _CameraDetailTile(
              width: tileWidth,
              label: 'Velocidad reportada por ANSV',
              value: camera.speedLimitKmh == null
                  ? 'No publicada'
                  : '${camera.speedLimitKmh} km/h',
            ),
          ],
        );
      },
    );
  }
}

class _CameraDetailTile extends StatelessWidget {
  const _CameraDetailTile({
    required this.width,
    required this.label,
    required this.value,
  });

  final double width;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1.08,
            ),
          ),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, height: 1.08),
          ),
        ],
      ),
    );
  }
}

class _SpeedGauge extends StatefulWidget {
  const _SpeedGauge({
    required this.state,
    required this.diameter,
    required this.speedFontSize,
    super.key,
  });

  final DrivingState state;
  final double diameter;
  final double speedFontSize;

  @override
  State<_SpeedGauge> createState() => _SpeedGaugeState();
}

class _SpeedGaugeState extends State<_SpeedGauge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  final _pulseGate = OverspeedPulseGate();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didUpdateWidget(covariant _SpeedGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybePulse();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybePulse();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _maybePulse() {
    final reducedMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_pulseGate.shouldPulse(
      current: widget.state.speedState,
      reducedMotion: reducedMotion,
    )) {
      _pulseController
        ..reset()
        ..forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final gaugeColor = widget.state.isOverspeeding
        ? AppColors.red
        : AppColors.teal;
    final speedColor = widget.state.isOverspeeding
        ? AppColors.red
        : Colors.white;
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = 1 - _pulseController.value;
        return SizedBox(
          width: widget.diameter,
          height: widget.diameter,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (_pulseController.isAnimating)
                Container(
                  key: const ValueKey('overspeed-pulse'),
                  width: widget.diameter + 28 * pulse,
                  height: widget.diameter + 28 * pulse,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.red.withValues(alpha: 0.38 * pulse),
                      width: 8,
                    ),
                  ),
                ),
              CustomPaint(
                size: Size.square(widget.diameter),
                painter: _SpeedRingPainter(
                  color: gaugeColor,
                  speedKmh: widget.state.speedKmh,
                ),
              ),
              Positioned.fill(
                child: Align(
                  alignment: const Alignment(0, -0.04),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: widget.diameter * 0.64,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${widget.state.speedKmh}',
                            key: const ValueKey('driving-speed'),
                            maxLines: 1,
                            style: TextStyle(
                              color: speedColor,
                              fontSize: widget.speedFontSize * 0.88,
                              fontWeight: FontWeight.w900,
                              height: 0.78,
                              shadows: [
                                Shadow(
                                  color: speedColor.withValues(alpha: 0.34),
                                  blurRadius: 14,
                                ),
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.44),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Text(
                        'km/h',
                        style: AppTextStyles.bodyStrong.copyWith(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontSize: 18,
                        ),
                      ),
                      if (widget.state.isOverspeeding) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '+${widget.state.speedDeltaKmh} km/h',
                          key: const ValueKey('driving-overspeed-delta'),
                          style: AppTextStyles.bodyStrong.copyWith(
                            color: AppColors.red,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (!widget.state.showCameraAlertPanel)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: widget.diameter * 0.08,
                  child: Center(child: _DrivingStatusChip(state: widget.state)),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SpeedRingPainter extends CustomPainter {
  const _SpeedRingPainter({required this.color, required this.speedKmh});

  final Color color;
  final int speedKmh;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 18;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = 2.48;
    const sweepAngle = 4.60;
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10
      ..color = Colors.white.withValues(alpha: 0.16);
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 20
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14)
      ..color = color.withValues(alpha: 0.34);
    final activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 13
      ..color = color;
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.38);
    final fillPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.black.withValues(alpha: 0.03),
          Colors.black.withValues(alpha: 0.28),
          Colors.black.withValues(alpha: 0.52),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius - 2, fillPaint);
    canvas.drawArc(rect, startAngle, sweepAngle, false, basePaint);
    final progress = (speedKmh / 200).clamp(0.0, 1.0);
    final activeSweep = sweepAngle * progress;
    canvas.drawArc(rect, startAngle, activeSweep, false, glowPaint);
    canvas.drawArc(rect, startAngle, activeSweep, false, activePaint);
    if (progress > 0.04) {
      final endAngle = startAngle + activeSweep;
      canvas.drawArc(
        rect,
        endAngle - 0.025,
        0.05,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 3
          ..color = Colors.white.withValues(alpha: 0.78),
      );
    }
    for (var tick = 0; tick <= 40; tick += 1) {
      final angle = startAngle + sweepAngle * tick / 40;
      final major = tick % 10 == 0;
      final innerRadius = radius - (major ? 28 : 18);
      final outerRadius = radius - 8;
      final start = Offset(
        center.dx + math.cos(angle) * innerRadius,
        center.dy + math.sin(angle) * innerRadius,
      );
      final end = Offset(
        center.dx + math.cos(angle) * outerRadius,
        center.dy + math.sin(angle) * outerRadius,
      );
      canvas.drawLine(start, end, tickPaint..strokeWidth = major ? 2.6 : 1.1);
    }
    for (final mark in const [0, 50, 100, 150, 200]) {
      _drawMarkLabel(canvas, center, radius, startAngle, sweepAngle, mark);
    }
  }

  void _drawMarkLabel(
    Canvas canvas,
    Offset center,
    double radius,
    double startAngle,
    double sweepAngle,
    int mark,
  ) {
    final angle = startAngle + sweepAngle * (mark / 200);
    final labelRadius = radius - 32;
    final offset = Offset(
      center.dx + math.cos(angle) * labelRadius,
      center.dy + math.sin(angle) * labelRadius,
    );
    final painter = TextPainter(
      text: TextSpan(
        text: '$mark',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.86),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(offset.dx - painter.width / 2, offset.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _SpeedRingPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.speedKmh != speedKmh;
  }
}

class _CameraSpeedSign extends StatelessWidget {
  const _CameraSpeedSign({
    required this.speedKmh,
    required this.size,
    super.key,
  });

  final int speedKmh;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Velocidad reportada por ANSV: $speedKmh kilómetros por hora',
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.red, width: size * 0.09),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.26),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Padding(
            padding: EdgeInsets.all(size * 0.15),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  flex: 6,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$speedKmh',
                      maxLines: 1,
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: size * 0.42,
                        fontWeight: FontWeight.w900,
                        height: 0.86,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: size * 0.02),
                Flexible(
                  flex: 2,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Vel. Max.',
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.navy.withValues(alpha: 0.76),
                        fontSize: size * 0.12,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Color _cameraPanelAccent(DrivingState state) {
  if (state.isOverspeeding) {
    return AppColors.red;
  }
  if (state.speedState == DrivingSpeedState.unknownReportedSpeed) {
    return AppColors.orange;
  }
  return _DrivingColors.forSpeedState(state.speedState).accent;
}

double _maxMiniMapZoom(double distanceMeters) {
  if (distanceMeters <= 40) {
    return 17;
  }
  if (distanceMeters <= 120) {
    return 16;
  }
  if (distanceMeters <= 320) {
    return 15;
  }
  return 14;
}

double _initialMiniMapZoom(double distanceMeters) {
  if (distanceMeters <= 40) {
    return 17;
  }
  if (distanceMeters <= 120) {
    return 16;
  }
  if (distanceMeters <= 320) {
    return 15;
  }
  return 14;
}

String _formatCameraPackDate(CameraPackSource? source) {
  final raw = source?.fetchedAtUtc.trim();
  if (raw == null || raw.isEmpty) {
    return 'pendiente';
  }
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    return raw.contains('T') ? raw.split('T').first : raw;
  }
  final date = parsed.toLocal();
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class _DrivingColors {
  const _DrivingColors({required this.accent, required this.speedColor});

  final Color accent;
  final Color speedColor;

  static _DrivingColors forSpeedState(DrivingSpeedState state) {
    return switch (state) {
      DrivingSpeedState.over => const _DrivingColors(
        accent: AppColors.red,
        speedColor: AppColors.red,
      ),
      DrivingSpeedState.near => const _DrivingColors(
        accent: AppColors.orange,
        speedColor: AppColors.plateYellow,
      ),
      DrivingSpeedState.within => const _DrivingColors(
        accent: AppColors.teal,
        speedColor: Colors.white,
      ),
      DrivingSpeedState.unknownReportedSpeed || DrivingSpeedState.noCamera =>
        const _DrivingColors(accent: AppColors.blue, speedColor: Colors.white),
    };
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.32)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Text(message, style: AppTextStyles.body),
      ),
    );
  }
}

class _HudView extends StatelessWidget {
  const _HudView({
    required this.state,
    required this.mirror,
    required this.onExit,
  });

  final DrivingState state;
  final bool mirror;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final colors = _DrivingColors.forSpeedState(state.speedState);
    final cameraSpeed = state.reportedCameraSpeedKmh;
    final distance = state.nearestCamera?.distanceMeters.round();
    final camera = state.nearestCamera?.camera;
    final cameraLocation = camera == null ? null : _cameraLocationText(camera);
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Transform(
                key: const ValueKey('hud-content-transform'),
                alignment: Alignment.center,
                transform: mirror
                    ? Matrix4.diagonal3Values(-1, 1, 1)
                    : Matrix4.identity(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${state.speedKmh}',
                      key: const ValueKey('hud-speed'),
                      style: TextStyle(
                        color: colors.speedColor,
                        fontSize: 168,
                        fontWeight: FontWeight.w800,
                        height: 0.82,
                      ),
                    ),
                    Text(
                      'km/h',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.l),
                    if (cameraSpeed != null)
                      _CameraSpeedSign(
                        key: const ValueKey('hud-camera-speed-sign'),
                        speedKmh: cameraSpeed,
                        size: 88,
                      ),
                    const SizedBox(height: AppSpacing.l),
                    if (distance != null)
                      Text(
                        'Cámara $distance m',
                        key: const ValueKey('hud-camera-distance'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.accent,
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    if (cameraLocation != null) ...[
                      const SizedBox(height: AppSpacing.s),
                      SizedBox(
                        width: 320,
                        child: Text(
                          cameraLocation,
                          key: const ValueKey('hud-camera-address'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            height: 1.08,
                          ),
                        ),
                      ),
                    ],
                    if (_hudMessage(state) case final hudMessage?) ...[
                      const SizedBox(height: AppSpacing.s),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl,
                        ),
                        child: Text(
                          hudMessage,
                          key: const ValueKey('hud-speed-state'),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.h2.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Positioned(
              top: AppSpacing.s,
              right: AppSpacing.s,
              child: IconButton(
                tooltip: 'Salir de HUD',
                onPressed: onExit,
                color: Colors.white,
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _hudMessage(DrivingState state) {
    return switch (state.speedState) {
      DrivingSpeedState.over => 'Reduce velocidad',
      DrivingSpeedState.near => 'Cerca del valor reportado',
      DrivingSpeedState.within => null,
      DrivingSpeedState.unknownReportedSpeed => 'Velocidad no publicada',
      DrivingSpeedState.noCamera => state.gpsQuality.label,
    };
  }
}

class _DrivingSettingsSheet extends StatefulWidget {
  const _DrivingSettingsSheet({
    required this.initial,
    required this.cameraPackSource,
  });

  final DrivingPreferences initial;
  final CameraPackSource? cameraPackSource;

  @override
  State<_DrivingSettingsSheet> createState() => _DrivingSettingsSheetState();
}

class _DrivingSettingsSheetState extends State<_DrivingSettingsSheet> {
  late DrivingPreferences _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.s,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Visualización de cámara', style: AppTextStyles.h2),
              const SizedBox(height: AppSpacing.s),
              SegmentedButton<CameraVisualizationMode>(
                key: const ValueKey('driving-visualization-mode-control'),
                segments: [
                  for (final mode in CameraVisualizationMode.values)
                    ButtonSegment(
                      value: mode,
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(mode.label, maxLines: 1),
                      ),
                    ),
                ],
                selected: {_value.cameraVisualizationMode},
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  setState(
                    () => _value = _value.copyWith(
                      cameraVisualizationMode: selection.first,
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _value.cameraVisualizationMode.description,
                key: ValueKey(
                  'driving-visualization-${_value.cameraVisualizationMode.name}',
                ),
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.navy.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: AppSpacing.l),
              const Text('Ángulo de detección', style: AppTextStyles.h2),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Centrado en el rumbo del vehículo.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.navy.withValues(alpha: 0.66),
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ConePreview(
                    key: ValueKey(
                      'driving-cone-preview-${_value.cameraTargetingConeDegrees}',
                    ),
                    degrees: _value.cameraTargetingConeDegrees,
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SegmentedButton<int>(
                          key: const ValueKey('driving-detection-cone-control'),
                          segments: [
                            for (final degrees
                                in allowedCameraTargetingConeDegrees)
                              ButtonSegment(
                                value: degrees,
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('$degrees°', maxLines: 1),
                                ),
                              ),
                          ],
                          selected: {_value.cameraTargetingConeDegrees},
                          showSelectedIcon: false,
                          onSelectionChanged: (selection) {
                            setState(
                              () => _value = _value.copyWith(
                                cameraTargetingConeDegrees: selection.first,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _coneDescription(_value.cameraTargetingConeDegrees),
                          key: ValueKey(
                            'driving-detection-${_value.cameraTargetingConeDegrees}',
                          ),
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.navy.withValues(alpha: 0.72),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.l),
              const Text('Alertas', style: AppTextStyles.h2),
              const SizedBox(height: AppSpacing.s),
              SegmentedButton<DrivingAlertProfile>(
                segments: [
                  for (final profile in DrivingAlertProfile.values)
                    ButtonSegment(
                      value: profile,
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(profile.label, maxLines: 1),
                      ),
                    ),
                ],
                selected: {_value.profile},
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  setState(
                    () => _value = _value.copyWith(profile: selection.first),
                  );
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Voz'),
                value: _value.voiceEnabled,
                onChanged: (value) => setState(
                  () => _value = _value.copyWith(voiceEnabled: value),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sonido'),
                value: _value.soundEnabled,
                onChanged: (value) => setState(
                  () => _value = _value.copyWith(soundEnabled: value),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Vibración'),
                value: _value.vibrationEnabled,
                onChanged: (value) => setState(
                  () => _value = _value.copyWith(vibrationEnabled: value),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('HUD espejo por defecto'),
                value: _value.hudMirrorEnabled,
                onChanged: (value) => setState(
                  () => _value = _value.copyWith(hudMirrorEnabled: value),
                ),
              ),
              if (_value.profile == DrivingAlertProfile.custom) ...[
                const SizedBox(height: AppSpacing.s),
                Text(
                  'Distancias',
                  style: AppTextStyles.caption.copyWith(color: AppColors.navy),
                ),
                const SizedBox(height: AppSpacing.s),
                Wrap(
                  spacing: AppSpacing.s,
                  runSpacing: AppSpacing.s,
                  children: [
                    for (final threshold in allowedCustomAlertThresholdsMeters)
                      FilterChip(
                        key: ValueKey('custom-alert-$threshold'),
                        label: Text('$threshold m'),
                        selected: _value.customThresholdsMeters.contains(
                          threshold,
                        ),
                        onSelected: (selected) {
                          final thresholds = _value.customThresholdsMeters
                              .toSet();
                          if (selected) {
                            thresholds.add(threshold);
                          } else if (thresholds.length > 1) {
                            thresholds.remove(threshold);
                          }
                          final ordered = thresholds.toList()
                            ..sort((a, b) => b.compareTo(a));
                          setState(
                            () => _value = _value.copyWith(
                              customThresholdsMeters: ordered,
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ],
              if (widget.cameraPackSource != null) ...[
                const SizedBox(height: AppSpacing.m),
                Text(
                  'Datos ANSV · ${widget.cameraPackSource!.fetchedAtUtc}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.navy.withValues(alpha: 0.66),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.s),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_value),
                  child: const Text('Guardar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _coneDescription(int degrees) {
  return switch (degrees) {
    45 => 'Preciso · prioriza cámaras casi directamente al frente.',
    90 => 'Normal · detecta al frente con margen para curvas.',
    180 => 'Amplio · incluye todo lo que queda delante.',
    360 =>
      'Alrededor · muestra cámaras alrededor; puede aumentar avisos cercanos.',
    _ => 'Normal · detecta al frente con margen para curvas.',
  };
}

class _ConePreview extends StatelessWidget {
  const _ConePreview({required this.degrees, super.key});

  final int degrees;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Vista del ángulo de detección de $degrees grados',
      child: SizedBox.square(
        dimension: 72,
        child: CustomPaint(painter: _ConePreviewPainter(degrees)),
      ),
    );
  }
}

class _ConePreviewPainter extends CustomPainter {
  const _ConePreviewPainter(this.degrees);

  final int degrees;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.62);
    final radius = size.width * 0.38;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.navy.withValues(alpha: 0.16),
    );
    final normalized = degrees.clamp(45, 360);
    final conePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = AppColors.teal.withValues(alpha: 0.22);
    if (normalized >= 360) {
      canvas.drawCircle(center, radius, conePaint);
    } else {
      final half = normalized * math.pi / 360;
      final rect = Rect.fromCircle(center: center, radius: radius);
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(rect, -math.pi / 2 - half, half * 2, false)
        ..close();
      canvas.drawPath(path, conePaint);
    }
    canvas.drawLine(
      center,
      Offset(center.dx, center.dy - radius),
      Paint()
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = AppColors.teal,
    );
    canvas.drawCircle(center, 4, Paint()..color = AppColors.blue);
  }

  @override
  bool shouldRepaint(covariant _ConePreviewPainter oldDelegate) {
    return oldDelegate.degrees != degrees;
  }
}

class _DrivingError extends StatelessWidget {
  const _DrivingError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: _StatusMessage(message: message),
      ),
    );
  }
}
