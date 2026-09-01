import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../application/driving_controller.dart';
import '../data/driving_preferences.dart';
import '../domain/camera_matcher.dart';
import '../domain/driving_alert_engine.dart';
import '../domain/traffic_camera.dart';
import '../../vehicle_status/platform/external_launcher.dart';

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
        state == AppLifecycleState.inactive ||
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

class _DrivingDashboard extends StatelessWidget {
  const _DrivingDashboard({
    required this.state,
    required this.onStart,
    required this.onDebugRouteKnown,
    required this.onDebugRouteUnknown,
    required this.onStop,
    required this.onSettings,
    required this.onHud,
    required this.onMirrorHud,
  });

  final DrivingState state;
  final VoidCallback onStart;
  final VoidCallback? onDebugRouteKnown;
  final VoidCallback? onDebugRouteUnknown;
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
              AppSpacing.l,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        state.gpsQuality.label,
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white70,
                        ),
                      ),
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
                ),
                Expanded(
                  child: Center(
                    child: _SpeedGauge(
                      key: const ValueKey('driving-speed-gauge'),
                      state: state,
                      diameter: 236,
                      speedFontSize: 108,
                    ),
                  ),
                ),
                _CameraPanel(state: state),
                const SizedBox(height: AppSpacing.m),
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
          if (onDebugRouteKnown != null || onDebugRouteUnknown != null) ...[
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
          ],
          const SizedBox(height: AppSpacing.m),
          Text(
            'GPS foreground. No se guarda recorrido ni se envía ubicación al servidor.',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.navy.withValues(alpha: 0.66),
            ),
          ),
        ],
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
              'Cámaras ANSV locales: ${state.cameraCount}',
              style: AppTextStyles.caption.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Velocidad reportada: ${state.cameraSpeedKnownCount} de '
              '${state.cameraCount}',
              key: const ValueKey('ready-speed-coverage'),
              style: AppTextStyles.caption.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Actualizado: ${state.cameraPackSource?.fetchedAtUtc ?? 'pendiente'}',
              style: AppTextStyles.caption.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraPanel extends ConsumerWidget {
  const _CameraPanel({required this.state});

  final DrivingState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alert = state.lastAlert;
    final match = state.nearestCamera;
    final weakForAlerts = state.isActive && !state.canEvaluateAlerts;
    final colors = _DrivingColors.forSpeedState(state.speedState);
    final urgent =
        state.isOverspeeding || alert?.severity == DrivingAlertSeverity.urgent;
    final color = urgent ? AppColors.red : colors.accent;
    final hasCamera = match != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: state.isActive ? const Color(0xFF0F2335) : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: hasCamera || alert != null
              ? color.withValues(alpha: 0.72)
              : AppColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  weakForAlerts
                      ? Icons.gps_not_fixed
                      : state.isOverspeeding
                      ? Icons.warning_amber_rounded
                      : Icons.videocam_outlined,
                  color: weakForAlerts ? AppColors.blue : color,
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Text(
                    weakForAlerts
                        ? 'GPS débil'
                        : hasCamera
                        ? 'Fotodetección en operación'
                        : 'Sin cámara inmediata',
                    style: AppTextStyles.h2.copyWith(
                      color: state.isActive ? Colors.white : AppColors.navy,
                    ),
                  ),
                ),
                if (hasCamera)
                  IconButton(
                    key: const ValueKey('driving-camera-map-action'),
                    tooltip: 'Ver en Google Maps',
                    color: state.isActive ? Colors.white70 : AppColors.navy,
                    onPressed: () => _openCameraMap(ref, match.camera),
                    icon: const Icon(Icons.near_me_outlined),
                  ),
                if (hasCamera)
                  IconButton(
                    key: const ValueKey('driving-camera-detail-action'),
                    tooltip: 'Fuente de cámara',
                    color: state.isActive ? Colors.white70 : AppColors.navy,
                    onPressed: () =>
                        _showCameraDetails(context, ref, match.camera),
                    icon: const Icon(Icons.info_outline),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            if (weakForAlerts)
              Text(
                'Esperando mejor precisión para alertas',
                key: const ValueKey('driving-camera-message'),
                style: _panelTextStyle(state),
              )
            else if (hasCamera)
              _CameraFacts(state: state, match: match)
            else
              Text(
                'PicoRadar revisa rumbo, distancia y aproximación desde el pack local.',
                key: const ValueKey('driving-camera-message'),
                style: _panelTextStyle(state),
              ),
          ],
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
      showDragHandle: true,
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
                  _CameraDetailLine(
                    label: 'Jurisdicción',
                    value: camera.jurisdiction ?? 'No publicada',
                  ),
                  _CameraDetailLine(
                    label: 'Tecnología',
                    value: _cameraDetailValue(
                      camera.technology,
                      'No publicada',
                    ),
                  ),
                  _CameraDetailLine(
                    label: 'Tipo de instalación',
                    value: _cameraDetailValue(
                      camera.installationType,
                      'No publicado',
                    ),
                  ),
                  _CameraDetailLine(
                    label: 'Equipo',
                    value: camera.equipmentName ?? 'No publicado',
                  ),
                  _CameraDetailLine(
                    label: 'Estado operación',
                    value: camera.operationStatus ?? 'No publicado',
                  ),
                  _CameraDetailLine(
                    label: 'Velocidad reportada',
                    value: camera.speedLimitKmh == null
                        ? 'No publicada'
                        : '${camera.speedLimitKmh} km/h',
                  ),
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

class _CameraFacts extends StatelessWidget {
  const _CameraFacts({required this.state, required this.match});

  final DrivingState state;
  final CameraMatch match;

  @override
  Widget build(BuildContext context) {
    final camera = match.camera;
    final distance = match.distanceMeters.round();
    final reported = camera.speedLimitKmh;
    final locationText = _cameraLocationText(camera);
    final status = switch (state.speedState) {
      DrivingSpeedState.over => 'Reduce velocidad',
      DrivingSpeedState.near => 'Cerca del valor reportado',
      DrivingSpeedState.within => 'Dentro del valor',
      DrivingSpeedState.unknownReportedSpeed => 'Velocidad no publicada',
      DrivingSpeedState.noCamera => 'Sin cámara inmediata',
    };
    final delta = state.speedDeltaKmh > 0 ? '+${state.speedDeltaKmh} km/h' : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.s,
          runSpacing: AppSpacing.s,
          children: [
            _FactPill(
              key: const ValueKey('camera-distance-pill'),
              label: 'Distancia',
              value: '$distance m',
              active: state.isActive,
            ),
            _FactPill(
              key: const ValueKey('camera-speed-pill'),
              label: 'Velocidad ANSV',
              value: reported == null ? 'No publicada' : '$reported km/h',
              active: state.isActive,
            ),
            _FactPill(
              key: const ValueKey('camera-status-pill'),
              label: 'Estado',
              value: delta.isEmpty ? status : '$status · $delta',
              active: state.isActive,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        Text(
          '${camera.locality} · ${camera.kind.label} · ANSV',
          key: const ValueKey('driving-camera-message'),
          style: _panelCaptionStyle(state),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          key: const ValueKey('driving-camera-address'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.place_outlined,
              size: 16,
              color: state.isActive
                  ? Colors.white.withValues(alpha: 0.68)
                  : AppColors.navy.withValues(alpha: 0.66),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                locationText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _panelCaptionStyle(state),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _cameraLocationText(TrafficCamera camera) {
  final address = camera.address?.trim();
  if (address != null && address.isNotEmpty) {
    return address;
  }
  return camera.locality;
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
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(value),
        ],
      ),
    );
  }
}

class _FactPill extends StatelessWidget {
  const _FactPill({
    required this.label,
    required this.value,
    required this.active,
    super.key,
  });

  final String label;
  final String value;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active
            ? Colors.white.withValues(alpha: 0.08)
            : AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: active ? Colors.white24 : AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.s,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: _pillLabelStyle(active)),
            Text(value, style: _pillValueStyle(active)),
          ],
        ),
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
    final colors = _DrivingColors.forSpeedState(widget.state.speedState);
    final reported = widget.state.reportedCameraSpeedKmh;
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = 1 - _pulseController.value;
        return SizedBox(
          width: widget.diameter,
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
                painter: _SpeedRingPainter(color: colors.accent),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${widget.state.speedKmh}',
                    key: const ValueKey('driving-speed'),
                    style: TextStyle(
                      color: colors.speedColor,
                      fontSize: widget.speedFontSize,
                      fontWeight: FontWeight.w900,
                      height: 0.82,
                    ),
                  ),
                  Text(
                    'km/h',
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: Colors.white70,
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
              if (reported != null)
                Positioned(
                  right: -4,
                  top: 12,
                  child: _CameraSpeedSign(
                    key: const ValueKey('camera-speed-sign'),
                    speedKmh: reported,
                    size: 68,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SpeedRingPainter extends CustomPainter {
  const _SpeedRingPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 14
      ..color = Colors.white.withValues(alpha: 0.14);
    final activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 14
      ..color = color;
    canvas.drawArc(rect.deflate(10), -2.35, 4.7, false, basePaint);
    canvas.drawArc(rect.deflate(10), -2.35, 3.65, false, activePaint);
  }

  @override
  bool shouldRepaint(covariant _SpeedRingPainter oldDelegate) {
    return oldDelegate.color != color;
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
      label: 'Velocidad de control reportada $speedKmh kilómetros por hora',
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
        child: Text(
          '$speedKmh',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: size * 0.42,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ),
    );
  }
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

TextStyle _panelTextStyle(DrivingState state) {
  return AppTextStyles.body.copyWith(
    color: state.isActive ? Colors.white : AppColors.navy,
  );
}

TextStyle _panelCaptionStyle(DrivingState state) {
  return AppTextStyles.caption.copyWith(
    color: state.isActive
        ? Colors.white.withValues(alpha: 0.68)
        : AppColors.navy.withValues(alpha: 0.66),
  );
}

TextStyle _pillLabelStyle(bool active) {
  return AppTextStyles.caption.copyWith(
    fontSize: 11,
    color: active
        ? Colors.white.withValues(alpha: 0.64)
        : AppColors.navy.withValues(alpha: 0.64),
  );
}

TextStyle _pillValueStyle(bool active) {
  return AppTextStyles.bodyStrong.copyWith(
    color: active ? Colors.white : AppColors.navy,
  );
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
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                      ),
                      child: Text(
                        _hudMessage(state),
                        key: const ValueKey('hud-speed-state'),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.h2.copyWith(color: Colors.white70),
                      ),
                    ),
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

  String _hudMessage(DrivingState state) {
    return switch (state.speedState) {
      DrivingSpeedState.over => 'Reduce velocidad',
      DrivingSpeedState.near => 'Cerca del valor reportado',
      DrivingSpeedState.within => 'Dentro del valor',
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
              const Text('Alertas', style: AppTextStyles.h2),
              const SizedBox(height: AppSpacing.l),
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
