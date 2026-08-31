import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../application/driving_controller.dart';
import '../data/driving_preferences.dart';
import '../domain/camera_matcher.dart';
import '../domain/driving_alert_engine.dart';

class DrivingScreen extends ConsumerStatefulWidget {
  const DrivingScreen({super.key});

  @override
  ConsumerState<DrivingScreen> createState() => _DrivingScreenState();
}

class _DrivingScreenState extends ConsumerState<DrivingScreen>
    with WidgetsBindingObserver {
  bool _hudMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _leaveHudMode();
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
        onStop: () => ref.read(drivingControllerProvider.notifier).stop(),
        onSettings: () => _showSettings(context, defaultDrivingPreferences),
        onHud: null,
      ),
      error: (error, stackTrace) => _DrivingError(message: error.toString()),
      data: (state) {
        if (_hudMode) {
          return _HudView(state: state, onExit: _toggleHudMode);
        }
        return _DrivingDashboard(
          state: state,
          onStart: () => ref.read(drivingControllerProvider.notifier).start(),
          onStop: () => ref.read(drivingControllerProvider.notifier).stop(),
          onSettings: () => _showSettings(context, state.preferences),
          onHud: state.isActive ? _toggleHudMode : null,
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
      builder: (context) => _DrivingSettingsSheet(initial: preferences),
    );
    if (updated != null) {
      await ref
          .read(drivingControllerProvider.notifier)
          .savePreferences(updated);
    }
  }

  void _toggleHudMode() {
    setState(() => _hudMode = !_hudMode);
    if (_hudMode) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    } else {
      _leaveHudMode();
    }
  }

  void _leaveHudMode() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    if (mounted && _hudMode) {
      setState(() => _hudMode = false);
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
    required this.onStop,
    required this.onSettings,
    required this.onHud,
  });

  final DrivingState state;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onSettings;
  final VoidCallback? onHud;

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
    final urgent = alert?.severity == DrivingAlertSeverity.urgent;
    final color = urgent ? AppColors.red : AppColors.orange;
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
                  alert == null ? Icons.videocam_outlined : Icons.warning,
                  color: alert == null ? AppColors.navy : color,
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Text(
                    alert?.title ?? 'Sin camara cercana',
                    style: AppTextStyles.h2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              alert?.message ?? _cameraMessage(match),
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
    return '${camera.locality} · $distance m · ${camera.kind.label}';
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
  const _HudView({required this.state, required this.onExit});

  final DrivingState state;
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
                alignment: Alignment.center,
                transform: Matrix4.diagonal3Values(-1, 1, 1),
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
                        state.lastAlert?.title ?? state.gpsQuality.label,
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
}

class _DrivingSettingsSheet extends StatefulWidget {
  const _DrivingSettingsSheet({required this.initial});

  final DrivingPreferences initial;

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Alertas', style: AppTextStyles.h2),
            const SizedBox(height: AppSpacing.l),
            SegmentedButton<DrivingAlertProfile>(
              segments: [
                for (final profile in DrivingAlertProfile.values)
                  ButtonSegment(value: profile, label: Text(profile.label)),
              ],
              selected: {_value.profile},
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
              onChanged: (value) =>
                  setState(() => _value = _value.copyWith(voiceEnabled: value)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sonido'),
              value: _value.soundEnabled,
              onChanged: (value) =>
                  setState(() => _value = _value.copyWith(soundEnabled: value)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Vibracion'),
              value: _value.vibrationEnabled,
              onChanged: (value) => setState(
                () => _value = _value.copyWith(vibrationEnabled: value),
              ),
            ),
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
