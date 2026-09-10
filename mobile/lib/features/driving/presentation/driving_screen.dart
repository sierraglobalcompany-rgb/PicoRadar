import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/design_system/branding.dart';
import '../../trip/presentation/trip_toll_sheet.dart';
import '../application/driving_controller.dart';
import '../data/driving_preferences.dart';
import '../domain/camera_matcher.dart';
import '../domain/driving_alert_engine.dart';
import '../domain/traffic_camera.dart';
import '../../vehicle_status/platform/external_launcher.dart';
import 'driving_proximity_map.dart';

export 'driving_proximity_map.dart'
    show DrivingMapConfig, drivingMapConfigProvider;

class DrivingScreen extends ConsumerStatefulWidget {
  const DrivingScreen({super.key});

  @override
  ConsumerState<DrivingScreen> createState() => _DrivingScreenState();
}

class _DrivingScreenState extends ConsumerState<DrivingScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final DrivingHudActiveNotifier _hudActiveNotifier;
  late final AnimationController _visualPulseController;
  final _activeScrollController = ScrollController(keepScrollOffset: false);
  bool _hudMode = false;
  bool _hudMirror = false;

  @override
  void initState() {
    super.initState();
    _hudActiveNotifier = ref.read(drivingHudActiveProvider.notifier);
    _visualPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _visualPulseController.dispose();
    _activeScrollController.dispose();
    _leaveHudMode(updateState: false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      ref.read(drivingControllerProvider.notifier).stop();
      _visualPulseController
        ..stop()
        ..value = 0;
      _leaveHudMode();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(drivingControllerProvider, (previous, next) {
      final previousKey = previous?.asData?.value.visualAlertPulseKey;
      final current = next.asData?.value;
      final currentKey = current?.visualAlertPulseKey;
      if (current == null ||
          !current.preferences.visualAlertsEnabled ||
          currentKey == null) {
        _visualPulseController
          ..stop()
          ..value = 0;
      } else if (currentKey != previousKey) {
        if (MediaQuery.disableAnimationsOf(context)) {
          _visualPulseController
            ..stop()
            ..value = 0;
        } else {
          _visualPulseController.forward(from: 0);
        }
      }
    });
    final asyncState = ref.watch(drivingControllerProvider);
    final content = asyncState.when(
      loading: () => _DrivingDashboard(
        scrollController: _activeScrollController,
        state: _initialDrivingState,
        onDebugRegional: canUseDebugDrivingSimulation ? _startRegional : null,
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
        if (_hudMode && !state.isActive) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _hudMode) _leaveHudMode();
          });
        }
        if (_hudMode && state.isActive) {
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
          scrollController: _activeScrollController,
          onDebugRegional: canUseDebugDrivingSimulation ? _startRegional : null,
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
    return AnimatedBuilder(
      animation: _visualPulseController,
      child: content,
      builder: (context, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            child!,
            IgnorePointer(
              child: ColoredBox(
                key: const ValueKey('driving-visual-alert-overlay'),
                color: _visualPulseColor(_visualPulseController.value),
              ),
            ),
          ],
        );
      },
    );
  }

  void _startRegional(DrivingSimulationScenario scenario) {
    unawaited(
      ref
          .read(drivingControllerProvider.notifier)
          .start(simulated: true, simulationScenario: scenario),
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

class _DrivingDashboard extends StatelessWidget {
  const _DrivingDashboard({
    required this.state,
    required this.scrollController,
    required this.onStart,
    required this.onDebugRouteKnown,
    required this.onDebugRouteUnknown,
    required this.onDebugRouteSide,
    required this.onDebugRouteLateralApproach,
    required this.onDebugRouteTurnAway,
    required this.onDebugRouteGpsWeak,
    required this.onDebugRegional,
    required this.onStop,
    required this.onSettings,
    required this.onHud,
    required this.onMirrorHud,
  });

  final DrivingState state;
  final ScrollController scrollController;
  final VoidCallback onStart;
  final VoidCallback? onDebugRouteKnown;
  final VoidCallback? onDebugRouteUnknown;
  final VoidCallback? onDebugRouteSide;
  final VoidCallback? onDebugRouteLateralApproach;
  final VoidCallback? onDebugRouteTurnAway;
  final VoidCallback? onDebugRouteGpsWeak;
  final ValueChanged<DrivingSimulationScenario>? onDebugRegional;
  final VoidCallback onStop;
  final VoidCallback onSettings;
  final VoidCallback? onHud;
  final VoidCallback? onMirrorHud;

  @override
  Widget build(BuildContext context) {
    final active = state.isActive;
    if (active) {
      return Scaffold(
        backgroundColor: const Color(0xFF03090D),
        body: ColoredBox(
          color: const Color(0xFF03090D),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.m,
                AppSpacing.s,
                AppSpacing.m,
                AppSpacing.s,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final hasAlertSpace =
                      state.showCameraAlertPanel ||
                      state.showTollAlertPanel ||
                      (state.preferences.tollAlertsEnabled &&
                          state.tollDataError != null);
                  final motionDuration = _motionDuration(
                    context,
                    const Duration(milliseconds: 280),
                  );
                  final simulationName = state.simulationName;
                  final simulationHeight = simulationName == null
                      ? 0.0
                      : _simulationLabelHeight(
                          context,
                          constraints.maxWidth,
                          simulationName,
                        );
                  return Column(
                    children: [
                      _DrivingTopBar(state: state),
                      if (state.simulationName case final name?)
                        SizedBox(
                          height: simulationHeight,
                          child: Center(
                            child: Text(
                              'SIMULACION · $name',
                              key: const ValueKey('driving-simulation-label'),
                              textAlign: TextAlign.center,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.plateYellow,
                              ),
                            ),
                          ),
                        ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, mainConstraints) {
                            final diameter = math.min(
                              mainConstraints.maxWidth,
                              (mainConstraints.maxWidth + 24) * 0.8 + 12,
                            );
                            final gaugeHeight = hasAlertSpace
                                ? diameter + 8
                                : math.max(
                                    diameter +
                                        (state.dismissedCameraId != null
                                            ? 88
                                            : 8),
                                    mainConstraints.maxHeight,
                                  );
                            return Scrollbar(
                              controller: scrollController,
                              thumbVisibility:
                                  MediaQuery.textScalerOf(context).scale(14) >
                                  17,
                              thickness: 3,
                              interactive: false,
                              child: SingleChildScrollView(
                                key: const ValueKey('driving-active-scroll'),
                                controller: scrollController,
                                physics: const ClampingScrollPhysics(),
                                padding: EdgeInsets.only(
                                  bottom:
                                      MediaQuery.textScalerOf(context)
                                              .scale(14) >
                                          17
                                      ? 16
                                      : 0,
                                ),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: mainConstraints.maxHeight,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: hasAlertSpace
                                        ? MainAxisAlignment.start
                                        : MainAxisAlignment.center,
                                    children: [
                                      AnimatedContainer(
                                        duration: motionDuration,
                                        curve: Curves.easeOutCubic,
                                        height: gaugeHeight,
                                        child: LayoutBuilder(
                                          builder: (context, gaugeConstraints) {
                                            return Stack(
                                              clipBehavior: Clip.none,
                                              alignment: Alignment.center,
                                              children: [
                                                AnimatedAlign(
                                                  duration: motionDuration,
                                                  curve: Curves.easeOutCubic,
                                                  alignment: hasAlertSpace
                                                      ? Alignment.topCenter
                                                      : Alignment.center,
                                                  child: _SpeedGauge(
                                                    key: const ValueKey(
                                                      'driving-speed-gauge',
                                                    ),
                                                    state: state,
                                                    diameter: diameter,
                                                    speedFontSize:
                                                        diameter * 0.46,
                                                  ),
                                                ),
                                                if (!hasAlertSpace &&
                                                    state.dismissedCameraId !=
                                                        null)
                                                  Positioned(
                                                    bottom: 0,
                                                    left: 0,
                                                    right: 0,
                                                    child: _CameraAlertSwitcher(
                                                      state: state,
                                                    ),
                                                  ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                      if (hasAlertSpace) ...[
                                        const SizedBox(height: AppSpacing.xs),
                                        _CameraAlertSwitcher(state: state),
                                        if (state
                                                .preferences
                                                .tollAlertsEnabled &&
                                            state.tollDataError != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: AppSpacing.s,
                                            ),
                                            child: Text(
                                              state.tollDataError!,
                                              style: AppTextStyles.caption
                                                  .copyWith(
                                                    color: Colors.white70,
                                                  ),
                                            ),
                                          ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s),
                      _DrivingControlsBar(
                        onSettings: onSettings,
                        onHud: onHud,
                        onMirrorHud: onMirrorHud,
                        onStop: onStop,
                      ),
                    ],
                  );
                },
              ),
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
          if (onDebugRegional != null)
            for (final scenario in [
              DrivingSimulationScenario.niquiaToEstrella,
              DrivingSimulationScenario.estrellaToNiquia,
              DrivingSimulationScenario.cocorna,
            ]) ...[
              const SizedBox(height: AppSpacing.s),
              OutlinedButton.icon(
                key: ValueKey('debug-driving-${scenario.name}'),
                onPressed: state.status == DrivingSessionStatus.starting
                    ? null
                    : () => onDebugRegional!(scenario),
                icon: const Icon(Icons.route),
                label: Text('SIMULACION · ${scenario.label}'),
              ),
            ],
          const SizedBox(height: AppSpacing.m),
          TextButton.icon(
            key: const ValueKey('driving-legal-notice-action'),
            onPressed: () => _showDrivingLegalNotice(context),
            icon: const Icon(Icons.gavel_outlined),
            label: const Text('Aviso legal'),
          ),
          const SizedBox(height: AppSpacing.s),
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

class _GaugeCameraIndicator extends StatelessWidget {
  const _GaugeCameraIndicator();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cámara cercana',
      child: Container(
        key: const ValueKey('gauge-camera-indicator'),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.red, width: 4),
          boxShadow: [
            BoxShadow(
              color: AppColors.red.withValues(alpha: 0.28),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Padding(
          padding: EdgeInsets.all(9),
          child: CustomPaint(
            painter: _RoadCameraPainter(color: Color(0xFF15191F)),
          ),
        ),
      ),
    );
  }
}

class _RoadCameraGlyph extends StatelessWidget {
  const _RoadCameraGlyph({required this.color, this.size = 38, super.key});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _RoadCameraPainter(color: color)),
    );
  }
}

class _RoadCameraPainter extends CustomPainter {
  const _RoadCameraPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final contrast = Paint()
      ..color = color == Colors.white ? const Color(0xFF851926) : Colors.white;
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    // Long side housing and a broad lens face follow the owner's road camera.
    canvas.drawPath(
      Path()
        ..moveTo(8, 31)
        ..lineTo(57, 14)
        ..lineTo(57, 63)
        ..lineTo(12, 70)
        ..quadraticBezierTo(6, 70, 6, 64)
        ..lineTo(5, 38)
        ..quadraticBezierTo(5, 33, 8, 31)
        ..close(),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(57, 14)
        ..lineTo(97, 22)
        ..quadraticBezierTo(100, 23, 99, 27)
        ..lineTo(94, 73)
        ..quadraticBezierTo(93, 77, 89, 76)
        ..lineTo(58, 67)
        ..close(),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(66, 25)
        ..lineTo(89, 30)
        ..quadraticBezierTo(93, 31, 92, 35)
        ..lineTo(88, 64)
        ..quadraticBezierTo(88, 68, 84, 67)
        ..lineTo(65, 62)
        ..quadraticBezierTo(62, 61, 62, 58)
        ..lineTo(63, 29)
        ..quadraticBezierTo(63, 25, 66, 25)
        ..close(),
      Paint()
        ..color = contrast.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawOval(const Rect.fromLTWH(68, 33, 18, 26), contrast);
    canvas.drawOval(const Rect.fromLTWH(71, 37, 12, 18), paint);
    canvas.drawPath(
      Path()
        ..moveTo(11, 41)
        ..lineTo(51, 28),
      Paint()
        ..color = contrast.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(27, 71, 23, 10),
        const Radius.circular(3),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(34, 77, 11, 23),
        const Radius.circular(2),
      ),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RoadCameraPainter oldDelegate) =>
      oldDelegate.color != color;
}

double _simulationLabelHeight(BuildContext context, double width, String name) {
  final painter = TextPainter(
    text: TextSpan(text: 'SIMULACION · $name', style: AppTextStyles.caption),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: width);
  final height = painter.height + AppSpacing.s;
  painter.dispose();
  return height;
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
          : state.showTollAlertPanel
          ? _TollPanel(
              key: ValueKey('toll-panel-${state.tollEpisodeKey}'),
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

class _TollPanel extends ConsumerWidget {
  const _TollPanel({required this.state, super.key});

  final DrivingState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final match = state.nearestToll!;
    final charge = state.referenceCharge;
    final amount = charge?.nominalMinor ?? charge?.amountMinor;
    return Material(
      key: const ValueKey('driving-toll-alert-panel'),
      color: const Color(0xEA0B1D2C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.teal),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .88,
          ),
          builder: (context) => _DrivingTollDetails(
            episodeKey: state.tollEpisodeKey,
            initialState: state,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked = MediaQuery.textScalerOf(context).scale(14) > 17;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.toll, color: AppColors.teal),
                      const SizedBox(width: AppSpacing.s),
                      Expanded(
                        child: Text(
                          match.toll.name,
                          style: AppTextStyles.bodyStrong.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('driving-toll-dismiss'),
                        tooltip: 'Cerrar alerta de peaje',
                        onPressed: () => ref
                            .read(drivingControllerProvider.notifier)
                            .dismissCurrentToll(),
                        color: Colors.white,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  Text(
                    'A ${match.distanceMeters.round()} m',
                    key: const ValueKey('driving-toll-distance'),
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: AppColors.teal,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Wrap(
                    spacing: AppSpacing.s,
                    runSpacing: AppSpacing.s,
                    children: [
                      SizedBox(
                        width: stacked
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 8) * 4 / 9,
                        child: DrivingProximityMap(
                          key: const ValueKey('driving-toll-map'),
                          target: DrivingVisualTarget(
                            id: match.toll.id,
                            latitude: match.toll.latitude,
                            longitude: match.toll.longitude,
                            distanceMeters: match.distanceMeters,
                            relativeBearingDegrees:
                                match.relativeBearingDegrees,
                            kind: DrivingVisualTargetKind.toll,
                          ),
                          currentPoint: state.currentPoint!,
                          reliableHeadingDegrees: state.reliableHeadingDegrees,
                          targetingConeDegrees:
                              state.preferences.cameraTargetingConeDegrees,
                          episodeKey: state.tollEpisodeKey ?? match.toll.id,
                          visualizationMode:
                              state.preferences.cameraVisualizationMode,
                          alertColor: AppColors.teal,
                          height: stacked ? 156 : 120,
                          config: ref.watch(drivingMapConfigProvider),
                        ),
                      ),
                      SizedBox(
                        width: stacked
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 8) * 5 / 9,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              match.toll.department,
                              key: const ValueKey('driving-toll-location'),
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s),
                            Text(
                              amount == null
                                  ? 'Categoría I · Tarifa no disponible'
                                  : 'Categoría I · ${tripTollMoney(amount)}',
                              key: const ValueKey(
                                'driving-toll-reference-price',
                              ),
                              style: AppTextStyles.bodyStrong.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              charge?.pendingReason ?? 'Tarifa de referencia',
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          'Todas las tarifas',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DrivingTollDetails extends ConsumerStatefulWidget {
  const _DrivingTollDetails({
    required this.episodeKey,
    required this.initialState,
  });

  final String? episodeKey;
  final DrivingState initialState;

  @override
  ConsumerState<_DrivingTollDetails> createState() =>
      _DrivingTollDetailsState();
}

class _DrivingTollDetailsState extends ConsumerState<_DrivingTollDetails> {
  bool _closing = false;

  void _checkEpisode(DrivingState? state) {
    if (_closing || state == null) return;
    if (!state.showTollAlertPanel ||
        state.tollEpisodeKey != widget.episodeKey) {
      _closing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      drivingControllerProvider,
      (_, next) => _checkEpisode(next.asData?.value),
    );
    _checkEpisode(ref.read(drivingControllerProvider).asData?.value);
    final charge = widget.initialState.referenceCharge;
    return SafeArea(
      child: SingleChildScrollView(
        key: const ValueKey('driving-toll-details'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          0,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.initialState.nearestToll!.toll.name,
                    style: AppTextStyles.h2,
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (charge == null)
              const Text('Tarifas no disponibles.')
            else
              TripTollChargeDetails(
                charge: charge,
                referenceOnly: true,
                onSource: (url) async {
                  var opened = false;
                  try {
                    opened = await ref
                        .read(externalLauncherProvider)
                        .openExternal(url);
                  } catch (_) {
                    opened = false;
                  }
                  if (context.mounted && !opened) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No pudimos abrir el enlace.'),
                      ),
                    );
                  }
                },
              ),
          ],
        ),
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
  const _DrivingTopBar({required this.state});

  final DrivingState state;

  @override
  Widget build(BuildContext context) {
    final quality = state.gpsQuality;
    final gpsColor = switch (quality) {
      GpsQuality.good => AppColors.green,
      GpsQuality.fair => AppColors.orange,
      GpsQuality.weak || GpsQuality.waiting => AppColors.red,
    };
    final brand = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const PicoRadarBrandMark(size: 28),
        const SizedBox(width: 8),
        Text(
          'PicoRadar',
          key: const ValueKey('driving-brand'),
          style: AppTextStyles.h2.copyWith(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
    final statuses = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TopStatusChip(
          key: const ValueKey('driving-connection-chip'),
          icon: switch (quality) {
            GpsQuality.good => Icons.gps_fixed,
            GpsQuality.fair => Icons.location_searching,
            GpsQuality.weak || GpsQuality.waiting => Icons.gps_not_fixed,
          },
          label: 'GPS',
          description: quality.label,
          color: gpsColor,
        ),
        const SizedBox(width: 8),
        _TopStatusChip(
          key: const ValueKey('driving-voice-chip'),
          icon: state.preferences.voiceEnabled
              ? Icons.volume_up_outlined
              : Icons.volume_off_outlined,
          label: 'Voz',
          description: state.preferences.voiceEnabled
              ? 'Voz habilitada en preferencias'
              : 'Voz deshabilitada',
          color: state.preferences.voiceEnabled
              ? AppColors.green
              : AppColors.red,
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final brandText = TextPainter(
          text: TextSpan(
            text: 'PicoRadar',
            style: DefaultTextStyle.of(context).style.merge(
              AppTextStyles.h2.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final statusText = TextPainter(
          text: TextSpan(
            text: 'GPSVoz',
            style: DefaultTextStyle.of(context).style
                .merge(AppTextStyles.caption.copyWith(fontSize: 13)),
          ),
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final fits =
            brandText.width + statusText.width + 132 <= constraints.maxWidth;
        brandText.dispose();
        statusText.dispose();
        return fits
            ? Row(children: [brand, const Spacer(), statuses])
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [brand, const SizedBox(height: 8), statuses],
              );
      },
    );
  }
}

class _DrivingControlsBar extends StatelessWidget {
  const _DrivingControlsBar({
    required this.onSettings,
    required this.onHud,
    required this.onMirrorHud,
    required this.onStop,
  });

  final VoidCallback onSettings;
  final VoidCallback? onHud;
  final VoidCallback? onMirrorHud;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stopText = TextPainter(
          text: TextSpan(
            text: 'Finalizar',
            style: DefaultTextStyle.of(context).style.merge(
              AppTextStyles.caption.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final useGrid =
            stopText.width + 26 + 8 + 16 > constraints.maxWidth - 168;
        stopText.dispose();
        final settings = _DrivingControlTile(
          key: const ValueKey('driving-active-settings'),
          icon: Icons.tune,
          label: 'Configuración',
          tooltip: 'Configuración',
          onPressed: onSettings,
        );
        final hud = _DrivingControlTile(
          key: const ValueKey('driving-active-hud'),
          icon: Icons.flip_to_front,
          label: 'HUD',
          tooltip: 'HUD',
          onPressed: onHud,
        );
        final mirror = KeyedSubtree(
          key: const ValueKey('driving-active-mirror'),
          child: _DrivingControlTile(
            key: const ValueKey('hud-mirror-action'),
            icon: Icons.flip,
            label: 'Espejo',
            tooltip: 'HUD espejo',
            onPressed: onMirrorHud,
          ),
        );
        final stop = _DrivingControlTile(
          key: const ValueKey('stop-driving'),
          icon: Icons.stop,
          label: 'Finalizar',
          onPressed: onStop,
          primary: true,
        );
        return Semantics(
          container: true,
          label: 'Controles de conducción',
          child: KeyedSubtree(
            key: const ValueKey('driving-active-controls'),
            child: useGrid
                ? Column(
                    children: [
                      Row(
                        children: [
                          SizedBox(width: 48, child: settings),
                          const SizedBox(width: AppSpacing.s),
                          SizedBox(width: 48, child: hud),
                          const SizedBox(width: AppSpacing.s),
                          SizedBox(width: 48, child: mirror),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s),
                      SizedBox(width: double.infinity, child: stop),
                    ],
                  )
                : Row(
                    children: [
                      SizedBox(width: 48, child: settings),
                      const SizedBox(width: AppSpacing.s),
                      SizedBox(width: 48, child: hud),
                      const SizedBox(width: AppSpacing.s),
                      SizedBox(width: 48, child: mirror),
                      const SizedBox(width: AppSpacing.s),
                      Expanded(child: stop),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _DrivingControlTile extends StatelessWidget {
  const _DrivingControlTile({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.tooltip,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final foreground = onPressed == null ? Colors.white38 : Colors.white;
    final tile = Material(
      color: primary
          ? AppColors.teal
          : Colors.white.withValues(alpha: onPressed == null ? 0.03 : 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
        side: BorderSide(
          color: primary
              ? AppColors.teal
              : Colors.white.withValues(alpha: 0.18),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.s,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: foreground, size: 26),
                if (primary) ...[
                  const SizedBox(width: 8),
                  Text(
                    label,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      height: 1.05,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return Semantics(
      label: label,
      button: true,
      enabled: onPressed != null,
      onTap: onPressed,
      excludeSemantics: true,
      child: tooltip == null ? tile : Tooltip(message: tooltip!, child: tile),
    );
  }
}

class _TopStatusChip extends StatelessWidget {
  const _TopStatusChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.description,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: description,
      excludeSemantics: true,
      child: Tooltip(
        message: description,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    label,
                    style: AppTextStyles.caption.copyWith(
                      color: color,
                      fontSize: 13,
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

class _DrivingStatusChip extends StatelessWidget {
  const _DrivingStatusChip({required this.state});

  final DrivingState state;

  @override
  Widget build(BuildContext context) {
    if (state.canEvaluateAlerts) {
      return const SizedBox(key: ValueKey('driving-state-chip'), height: 0);
    }
    final label = state.gpsQuality.label;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: DecoratedBox(
        key: const ValueKey('driving-state-chip'),
        decoration: BoxDecoration(
          color: AppColors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.orange.withValues(alpha: 0.62)),
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
            style: AppTextStyles.bodyStrong.copyWith(color: AppColors.orange),
          ),
        ),
      ),
    );
  }
}

Future<void> _showDrivingLegalNotice(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => const _DrivingLegalNoticeSheet(),
  );
}

class _DrivingLegalNoticeSheet extends StatelessWidget {
  const _DrivingLegalNoticeSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        key: const ValueKey('driving-legal-notice-sheet'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          0,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Aviso legal', style: AppTextStyles.h2)),
                IconButton(
                  key: const ValueKey('driving-legal-notice-close'),
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s),
            const Text(
              'PicoRadar ofrece información de apoyo que puede ser incompleta '
              'o estar desactualizada. No garantiza detectar todas las cámaras '
              'ni evitar comparendos. La señalización y las disposiciones '
              'vigentes de la autoridad prevalecen. Conduce respetando las '
              'normas y configura la app con el vehículo detenido. Este aviso '
              'no limita los derechos ni las responsabilidades establecidos '
              'por la ley.',
              style: AppTextStyles.body,
            ),
          ],
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

class _CameraPanel extends ConsumerStatefulWidget {
  const _CameraPanel({required this.state, super.key});

  final DrivingState state;

  @override
  ConsumerState<_CameraPanel> createState() => _CameraPanelState();
}

class _CameraPanelState extends ConsumerState<_CameraPanel> {
  double _verticalDragOffset = 0;
  bool _dismissedByDrag = false;

  void _resetDrag() {
    _verticalDragOffset = 0;
    _dismissedByDrag = false;
  }

  void _dismissAlert() {
    if (_dismissedByDrag) return;
    _dismissedByDrag = true;
    ref.read(drivingControllerProvider.notifier).dismissCurrentCameraAlert();
  }

  void _handlePointerMove(PointerMoveEvent event) {
    _verticalDragOffset += event.delta.dy;
    if (_verticalDragOffset > 64) _dismissAlert();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final match = state.nearestCamera!;
    final color = _cameraPanelAccent(state);
    final compactPanel = MediaQuery.sizeOf(context).height < 860;
    final mapHeight = compactPanel ? 132.0 : 156.0;

    return KeyedSubtree(
      key: const ValueKey('driving-camera-alert-panel'),
      child: Listener(
        onPointerDown: (_) => _resetDrag(),
        onPointerMove: _handlePointerMove,
        child: Material(
          color: const Color(0xFF061118),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            side: const BorderSide(color: Color(0xFFF43E49), width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  MediaQuery.textScalerOf(context).scale(14) > 21 ||
                  constraints.maxWidth < 330;
              final map = DrivingProximityMap(
                key: const ValueKey('driving-mini-map'),
                target: DrivingVisualTarget.fromCameraMatch(match),
                reliableHeadingDegrees: state.reliableHeadingDegrees,
                config: ref.watch(drivingMapConfigProvider),
                episodeKey: state.cameraEpisodeKey ?? match.camera.id,
                currentPoint: state.currentPoint!,
                targetingConeDegrees:
                    state.preferences.cameraTargetingConeDegrees,
                visualizationMode: state.preferences.cameraVisualizationMode,
                alertColor: color,
                height: mapHeight,
              );
              final facts = _CameraPanelFacts(state: state, match: match);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  KeyedSubtree(
                    key: const ValueKey('driving-camera-alert-header'),
                    child: ColoredBox(
                      color: const Color(0xFF59121C),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.m,
                          AppSpacing.xs,
                          AppSpacing.xs,
                          AppSpacing.xs,
                        ),
                        child: Row(
                          children: [
                            const _RoadCameraGlyph(
                              key: ValueKey('driving-camera-alert-icon-camera'),
                              color: Colors.white,
                              size: 38,
                            ),
                            const SizedBox(width: AppSpacing.s),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _cameraTitle(match.camera),
                                    style: AppTextStyles.bodyStrong.copyWith(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'Cámara cercana',
                                    style: AppTextStyles.caption.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.82,
                                      ),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              key: const ValueKey(
                                'driving-camera-dismiss-action',
                              ),
                              tooltip: 'Cerrar alerta de fotodetección',
                              onPressed: _dismissAlert,
                              color: Colors.white,
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.m,
                      AppSpacing.xs,
                      AppSpacing.m,
                      AppSpacing.s,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _cameraDistanceLabel(match),
                                key: const ValueKey('camera-distance-pill'),
                                style: AppTextStyles.bodyStrong.copyWith(
                                  color: const Color(0xFFFF6B72),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              key: const ValueKey('driving-camera-map-action'),
                              tooltip: 'Ver ubicación en Google Maps',
                              onPressed: () =>
                                  _openCameraMap(context, ref, match.camera),
                              color: Colors.white,
                              icon: const Icon(Icons.near_me_outlined),
                            ),
                            IconButton(
                              key: const ValueKey(
                                'driving-camera-detail-action',
                              ),
                              tooltip: 'Fuente de cámara',
                              onPressed: () => _showCameraDetails(
                                context,
                                ref,
                                match.camera,
                              ),
                              color: Colors.white,
                              icon: const Icon(Icons.info_outline),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        if (stacked) ...[
                          map,
                          const SizedBox(height: AppSpacing.m),
                          facts,
                        ] else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Flexible(flex: 4, child: map),
                              const SizedBox(width: AppSpacing.m),
                              Flexible(flex: 5, child: facts),
                            ],
                          ),
                      ],
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
                    onPressed: () => _openCameraMap(context, ref, camera),
                    icon: const Icon(Icons.near_me_outlined),
                    label: const Text('Ver en Google Maps'),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  _CameraDetailLine(
                    label: 'Autoridad de tránsito',
                    value: camera.trafficAuthority ?? 'No publicada',
                  ),
                  _CameraDetailGrid(camera: camera),
                  const SizedBox(height: AppSpacing.m),
                  const Text(
                    'Este dato no confirma el límite vigente de esta vía. '
                    'Respeta la señalización',
                    key: ValueKey('camera-speed-disclaimer'),
                  ),
                  if (widget.state.cameraPackSource case final source?) ...[
                    const SizedBox(height: AppSpacing.m),
                    _CameraDetailLine(label: 'Fuente', value: source.name),
                    _CameraDetailLine(
                      label: 'Fecha del snapshot',
                      value: source.fetchedAtUtc,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCameraMap(
    BuildContext context,
    WidgetRef ref,
    TrafficCamera camera,
  ) async {
    final launcher = ref.read(externalLauncherProvider);
    var opened = false;
    try {
      opened = await launcher.openExternal(_cameraMapUri(camera).toString());
    } catch (_) {
      opened = false;
    }
    if (!context.mounted || opened) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No pudimos abrir Google Maps.')),
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
        ),
        const SizedBox(height: AppSpacing.m),
        _CameraFactBlock(
          key: const ValueKey('camera-authority-row'),
          label: 'Autoridad',
          value: _compactTrafficAuthority(camera.trafficAuthority),
        ),
      ],
    );
  }
}

class _CameraFactBlock extends StatelessWidget {
  const _CameraFactBlock({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: Colors.white.withValues(alpha: 0.58),
            fontSize: 13,
            fontWeight: FontWeight.w400,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.caption.copyWith(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
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
  return 'Cámara de fotomulta';
}

String _cameraDistanceLabel(CameraMatch match) {
  final status = match.camera.operationStatus?.trim();
  if (status == null || status.isEmpty) {
    return 'A ${match.distanceMeters.round()} m';
  }
  return 'A ${match.distanceMeters.round()} m · $status (reportado)';
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
        final tileWidth = MediaQuery.textScalerOf(context).scale(12) > 18
            ? constraints.maxWidth
            : (constraints.maxWidth - AppSpacing.s) / 2;
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
                  ? 'No informada'
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
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1.08,
            ),
          ),
          Text(value, style: const TextStyle(fontSize: 13, height: 1.08)),
        ],
      ),
    );
  }
}

class _SpeedGauge extends StatelessWidget {
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
  Widget build(BuildContext context) {
    const gaugeColor = AppColors.teal;
    const speedColor = Colors.white;
    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(diameter),
            painter: _SpeedRingPainter(
              color: gaugeColor,
              speedKmh: state.speedKmh,
              fontFamily: DefaultTextStyle.of(context).style.fontFamily,
            ),
          ),
          Positioned.fill(
            child: Align(
              alignment: const Alignment(0, -0.04),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      SizedBox(
                        width: diameter * 0.58,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${state.speedKmh}',
                            key: const ValueKey('driving-speed'),
                            maxLines: 1,
                            style: TextStyle(
                              color: speedColor,
                              fontSize: speedFontSize * 0.88,
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
                      if (state.showCameraAlertPanel)
                        Positioned(
                          top: 0,
                          bottom: 0,
                          right: -diameter * 0.21 - 12,
                          child: const Center(child: _GaugeCameraIndicator()),
                        ),
                    ],
                  ),
                  Text(
                    'km/h',
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!state.showCameraAlertPanel)
            Positioned(
              left: 0,
              right: 0,
              bottom: diameter * 0.08,
              child: Center(child: _DrivingStatusChip(state: state)),
            ),
        ],
      ),
    );
  }
}

class _SpeedRingPainter extends CustomPainter {
  const _SpeedRingPainter({
    required this.color,
    required this.speedKmh,
    required this.fontFamily,
  });

  final Color color;
  final int speedKmh;
  final String? fontFamily;

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
          fontFamily: fontFamily,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(offset.dx - painter.width / 2, offset.dy - painter.height / 2),
    );
    painter.dispose();
  }

  @override
  bool shouldRepaint(covariant _SpeedRingPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.speedKmh != speedKmh ||
        oldDelegate.fontFamily != fontFamily;
  }
}

Color _cameraPanelAccent(DrivingState state) {
  return (state.nearestCamera?.distanceMeters ?? double.infinity) <= 100
      ? AppColors.orange
      : const Color(0xFFFF6B72);
}

String _formatCameraPackDate(CameraPackSource? source) {
  final raw = source?.fetchedAtUtc.trim();
  if (raw == null || raw.isEmpty) return 'pendiente';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw.contains('T') ? raw.split('T').first : raw;
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

Duration _motionDuration(BuildContext context, Duration duration) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;

Color _visualPulseColor(double value) {
  final firstPulse = value < 0.5;
  final local = firstPulse ? value * 2 : (value - 0.5) * 2;
  final envelope = switch (local) {
    < 1 / 3 => Curves.easeInOut.transform(local * 3),
    < 1 / 2 => 1.0,
    < 5 / 6 => Curves.easeInOut.transform((5 / 6 - local) * 3),
    _ => 0.0,
  };
  final base = firstPulse ? const Color(0xFF2F80ED) : Colors.white;
  final maximumAlpha = firstPulse ? 0.22 : 0.12;
  return base.withValues(alpha: maximumAlpha * envelope);
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
    final distance = state.showCameraAlertPanel
        ? state.nearestCamera?.distanceMeters.round()
        : null;
    final camera = state.showCameraAlertPanel
        ? state.nearestCamera?.camera
        : null;
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
                        color: Colors.white,
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
                    if (distance != null)
                      Text(
                        'Cámara $distance m',
                        key: const ValueKey('hud-camera-distance'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _cameraPanelAccent(state),
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    if (state.showTollAlertPanel) ...[
                      const SizedBox(height: AppSpacing.s),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.l,
                        ),
                        child: Text(
                          'Peaje ${state.nearestToll!.toll.name} · ${state.nearestToll!.distanceMeters.round()} m',
                          key: const ValueKey('hud-toll-distance'),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.h2.copyWith(color: Colors.white),
                        ),
                      ),
                    ],
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
            if (state.simulationName case final name?)
              Positioned(
                top: AppSpacing.l,
                left: AppSpacing.l,
                right: 64,
                child: Text(
                  'SIMULACION · $name',
                  key: const ValueKey('driving-simulation-label'),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.plateYellow,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String? _hudMessage(DrivingState state) {
    return state.showCameraAlertPanel
        ? 'Respeta la señalización'
        : state.gpsQuality.label;
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
                key: const ValueKey('driving-toll-alerts-toggle'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Peajes'),
                value: _value.tollAlertsEnabled,
                onChanged: (value) => setState(
                  () => _value = _value.copyWith(tollAlertsEnabled: value),
                ),
              ),
              SwitchListTile(
                key: const ValueKey('driving-visual-alert-toggle'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Alerta visual'),
                subtitle: const Text(
                  'Ilumina suavemente el fondo al avisar de cámaras y peajes.',
                ),
                value: _value.visualAlertsEnabled,
                onChanged: (value) => setState(
                  () => _value = _value.copyWith(visualAlertsEnabled: value),
                ),
              ),
              _VisualAlertPreviewButton(enabled: _value.visualAlertsEnabled),
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

class _VisualAlertPreviewButton extends StatefulWidget {
  const _VisualAlertPreviewButton({required this.enabled});

  final bool enabled;

  @override
  State<_VisualAlertPreviewButton> createState() =>
      _VisualAlertPreviewButtonState();
}

class _VisualAlertPreviewButtonState extends State<_VisualAlertPreviewButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didUpdateWidget(covariant _VisualAlertPreviewButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && oldWidget.enabled) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.button),
          child: Stack(
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const ValueKey('driving-visual-alert-preview'),
                  onPressed: widget.enabled
                      ? () {
                          if (MediaQuery.disableAnimationsOf(context)) return;
                          _controller.forward(from: 0);
                        }
                      : null,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Probar alerta visual'),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: _visualPulseColor(_controller.value),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
