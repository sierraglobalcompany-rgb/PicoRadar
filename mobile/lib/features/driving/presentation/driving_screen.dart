import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../application/driving_controller.dart';
import '../data/driving_preferences.dart';
import '../domain/camera_matcher.dart';
import '../domain/driving_alert_engine.dart';
import '../domain/traffic_camera.dart';

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
        onDebugRoute: canUseDebugDrivingSimulation
            ? () => ref
                  .read(drivingControllerProvider.notifier)
                  .start(simulated: true)
            : null,
        onStop: () => ref.read(drivingControllerProvider.notifier).stop(),
        onSettings: () => _showSettings(context, defaultDrivingPreferences),
        onHud: null,
        onMirrorHud: null,
      ),
      error: (error, stackTrace) => _DrivingError(message: error.toString()),
      data: (state) {
        if (_hudMode) {
          return _HudView(
            state: state,
            mirror: _hudMirror,
            onExit: _leaveHudMode,
          );
        }
        return _DrivingDashboard(
          state: state,
          onStart: () => ref.read(drivingControllerProvider.notifier).start(),
          onDebugRoute: canUseDebugDrivingSimulation
              ? () => ref
                    .read(drivingControllerProvider.notifier)
                    .start(simulated: true)
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
);

class _DrivingDashboard extends StatelessWidget {
  const _DrivingDashboard({
    required this.state,
    required this.onStart,
    required this.onDebugRoute,
    required this.onStop,
    required this.onSettings,
    required this.onHud,
    required this.onMirrorHud,
  });

  final DrivingState state;
  final VoidCallback onStart;
  final VoidCallback? onDebugRoute;
  final VoidCallback onStop;
  final VoidCallback onSettings;
  final VoidCallback? onHud;
  final VoidCallback? onMirrorHud;

  @override
  Widget build(BuildContext context) {
    final active = state.isActive;
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
              IconButton(
                tooltip: 'HUD',
                onPressed: onHud,
                icon: const Icon(Icons.flip_to_front),
              ),
            ],
          ),
          if (active) ...[
            const SizedBox(height: AppSpacing.s),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('hud-mirror-action'),
                onPressed: onMirrorHud,
                icon: const Icon(Icons.flip),
                label: const Text('HUD espejo'),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.l),
          _SpeedPanel(state: state),
          const SizedBox(height: AppSpacing.l),
          _CameraPanel(state: state),
          if (state.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.l),
            _StatusMessage(message: state.errorMessage!),
          ],
          const SizedBox(height: AppSpacing.l),
          FilledButton.icon(
            key: ValueKey(active ? 'stop-driving' : 'start-driving'),
            onPressed: state.status == DrivingSessionStatus.starting
                ? null
                : active
                ? onStop
                : onStart,
            icon: Icon(active ? Icons.stop : Icons.play_arrow),
            label: Text(active ? 'Detener' : 'Iniciar'),
          ),
          if (!active && onDebugRoute != null) ...[
            const SizedBox(height: AppSpacing.s),
            OutlinedButton.icon(
              key: const ValueKey('debug-driving-route'),
              onPressed: state.status == DrivingSessionStatus.starting
                  ? null
                  : onDebugRoute,
              icon: const Icon(Icons.route),
              label: const Text('Ruta demo'),
            ),
          ],
          const SizedBox(height: AppSpacing.m),
          Text(
            'GPS foreground. No se guarda recorrido ni se envia ubicacion al servidor.',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.navy.withValues(alpha: 0.66),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedPanel extends StatelessWidget {
  const _SpeedPanel({required this.state});

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
              state.status == DrivingSessionStatus.starting
                  ? 'Preparando GPS'
                  : state.gpsQuality.label,
              style: AppTextStyles.caption.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: AppSpacing.s),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${state.speedKmh}',
                  key: const ValueKey('driving-speed'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 72,
                    fontWeight: FontWeight.w800,
                    height: 0.96,
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s),
                  child: Text(
                    'km/h',
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            Text(
              'Camaras ANSV locales: ${state.cameraCount}',
              style: AppTextStyles.caption.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraPanel extends StatelessWidget {
  const _CameraPanel({required this.state});

  final DrivingState state;

  @override
  Widget build(BuildContext context) {
    final alert = state.lastAlert;
    final match = state.nearestCamera;
    final weakForAlerts = state.isActive && !state.canEvaluateAlerts;
    final urgent = alert?.severity == DrivingAlertSeverity.urgent;
    final color = urgent ? AppColors.red : AppColors.orange;
    final hasCamera = match != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: alert == null ? Colors.white : color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: alert == null
              ? AppColors.border
              : color.withValues(alpha: 0.6),
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
                      : alert == null
                      ? Icons.videocam_outlined
                      : Icons.warning,
                  color: weakForAlerts
                      ? AppColors.blue
                      : alert == null
                      ? AppColors.navy
                      : color,
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Text(
                    weakForAlerts
                        ? 'GPS debil'
                        : alert?.title ??
                              (hasCamera
                                  ? 'Fotodeteccion autorizada'
                                  : 'No hay camaras proximas'),
                    style: AppTextStyles.h2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              weakForAlerts
                  ? 'Esperando mejor precision para alertas'
                  : alert?.message ?? _cameraMessage(match),
              key: const ValueKey('driving-camera-message'),
              style: AppTextStyles.body,
            ),
          ],
        ),
      ),
    );
  }

  String _cameraMessage(CameraMatch? match) {
    if (match == null) {
      return 'PicoRadar revisa rumbo, distancia y aproximacion desde el pack local.';
    }
    final camera = match.camera;
    final distance = match.distanceMeters.round();
    final direction = match.approaching ? 'Aproximandote' : 'En zona';
    final speedLimit = camera.speedLimitKmh == null
        ? ''
        : ' · ${camera.speedLimitKmh} km/h';
    return '${camera.locality} · $distance m · $direction · '
        '${camera.kind.label}$speedLimit · ANSV';
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 104,
                        fontWeight: FontWeight.w800,
                        height: 0.9,
                      ),
                    ),
                    Text(
                      'km/h',
                      style: AppTextStyles.h2.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                      ),
                      child: Text(
                        _hudMessage(state),
                        key: const ValueKey('hud-camera-distance'),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.h2.copyWith(
                          color: state.lastAlert == null
                              ? Colors.white70
                              : AppColors.plateYellow,
                        ),
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
    final match = state.nearestCamera;
    if (match != null) {
      return 'Camara ${match.distanceMeters.round()} m';
    }
    if (state.lastAlert != null) {
      return state.lastAlert!.title;
    }
    return state.gpsQuality.label;
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
                title: const Text('Vibracion'),
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
