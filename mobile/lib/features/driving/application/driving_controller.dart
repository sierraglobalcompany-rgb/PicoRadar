import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../location/platform/device_location_gateway.dart';
import '../data/camera_pack_loader.dart';
import '../data/driving_preferences.dart';
import '../domain/camera_matcher.dart';
import '../domain/driving_alert_engine.dart';
import '../domain/traffic_camera.dart';
import '../platform/driving_feedback_gateway.dart';
import '../platform/driving_location_gateway.dart';

const drivingSimulationEnabled = bool.fromEnvironment(
  'PICORADAR_DRIVING_SIMULATION',
);

bool get canUseDebugDrivingSimulation => kDebugMode && drivingSimulationEnabled;

const drivingOverspeedVisualMarginKmh = 3;

enum DrivingSimulationScenario { knownSpeed, unknownSpeed }

enum DrivingSpeedState { noCamera, unknownReportedSpeed, within, near, over }

class OverspeedPulseGate {
  DrivingSpeedState? _previous;

  bool shouldPulse({
    required DrivingSpeedState current,
    required bool reducedMotion,
  }) {
    final pulse =
        !reducedMotion &&
        current == DrivingSpeedState.over &&
        _previous != current;
    _previous = current;
    return pulse;
  }
}

final drivingLocationGatewayProvider = Provider<DrivingLocationGateway>((ref) {
  return const GeolocatorDrivingLocationGateway();
});

final drivingFeedbackGatewayProvider = Provider<DrivingFeedbackGateway>((ref) {
  return const PlatformDrivingFeedbackGateway();
});

final drivingHudActiveProvider =
    NotifierProvider<DrivingHudActiveNotifier, bool>(
      DrivingHudActiveNotifier.new,
    );

class DrivingHudActiveNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setActive(bool value) {
    state = value;
  }
}

final drivingPreferencesProvider = FutureProvider<DrivingPreferences>((
  ref,
) async {
  return loadDrivingPreferences(ref.watch(appPreferencesProvider));
});

final drivingControllerProvider =
    AsyncNotifierProvider<DrivingController, DrivingState>(
      DrivingController.new,
    );

enum DrivingSessionStatus {
  idle,
  starting,
  active,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  locationUnavailable,
}

enum GpsQuality {
  waiting('Buscando GPS'),
  good('GPS bueno'),
  fair('GPS medio'),
  weak('GPS debil');

  const GpsQuality(this.label);

  final String label;
}

class DrivingState {
  const DrivingState({
    required this.status,
    required this.preferences,
    required this.cameraCount,
    required this.cameraSpeedKnownCount,
    this.cameraPackSource,
    this.currentPoint,
    this.nearestCamera,
    this.lastAlert,
    this.errorMessage,
  });

  final DrivingSessionStatus status;
  final DrivingPreferences preferences;
  final int cameraCount;
  final int cameraSpeedKnownCount;
  final CameraPackSource? cameraPackSource;
  final DrivingPoint? currentPoint;
  final CameraMatch? nearestCamera;
  final DrivingAlert? lastAlert;
  final String? errorMessage;

  bool get isActive => status == DrivingSessionStatus.active;

  int get speedKmh => (currentPoint?.speedKmh ?? 0).round();

  int get cameraSpeedUnknownCount => cameraCount - cameraSpeedKnownCount;

  TrafficCamera? get currentCamera => nearestCamera?.camera;

  int? get reportedCameraSpeedKmh {
    final camera = currentCamera;
    if (camera == null) {
      return null;
    }
    return camera.speedLimitKmh;
  }

  int get speedDeltaKmh {
    final reported = reportedCameraSpeedKmh;
    if (reported == null) {
      return 0;
    }
    return speedKmh - reported;
  }

  DrivingSpeedState get speedState {
    final camera = currentCamera;
    if (!isActive || camera == null) {
      return DrivingSpeedState.noCamera;
    }
    final reported = camera.speedLimitKmh;
    if (reported == null) {
      return DrivingSpeedState.unknownReportedSpeed;
    }
    // UI hysteresis only: avoids color jitter. This is not a legal tolerance.
    if (speedKmh > reported + drivingOverspeedVisualMarginKmh) {
      return DrivingSpeedState.over;
    }
    if (speedKmh >= reported - 5) {
      return DrivingSpeedState.near;
    }
    return DrivingSpeedState.within;
  }

  bool get isOverspeeding => speedState == DrivingSpeedState.over;

  bool get canEvaluateAlerts {
    final accuracy = currentPoint?.accuracyMeters;
    return accuracy != null && accuracy <= 60;
  }

  GpsQuality get gpsQuality {
    final accuracy = currentPoint?.accuracyMeters;
    if (accuracy == null) {
      return GpsQuality.waiting;
    }
    if (accuracy <= 25) {
      return GpsQuality.good;
    }
    if (accuracy <= 60) {
      return GpsQuality.fair;
    }
    return GpsQuality.weak;
  }

  DrivingState copyWith({
    DrivingSessionStatus? status,
    DrivingPreferences? preferences,
    int? cameraCount,
    int? cameraSpeedKnownCount,
    CameraPackSource? cameraPackSource,
    DrivingPoint? currentPoint,
    CameraMatch? nearestCamera,
    DrivingAlert? lastAlert,
    String? errorMessage,
    bool clearNearestCamera = false,
    bool clearLastAlert = false,
    bool clearErrorMessage = false,
  }) {
    return DrivingState(
      status: status ?? this.status,
      preferences: preferences ?? this.preferences,
      cameraCount: cameraCount ?? this.cameraCount,
      cameraSpeedKnownCount:
          cameraSpeedKnownCount ?? this.cameraSpeedKnownCount,
      cameraPackSource: cameraPackSource ?? this.cameraPackSource,
      currentPoint: currentPoint ?? this.currentPoint,
      nearestCamera: clearNearestCamera
          ? null
          : nearestCamera ?? this.nearestCamera,
      lastAlert: clearLastAlert ? null : lastAlert ?? this.lastAlert,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }
}

class DrivingController extends AsyncNotifier<DrivingState> {
  StreamSubscription<DrivingPoint>? _subscription;
  DrivingPoint? _previousPoint;
  DrivingAlertEngine? _alertEngine;
  bool _wasOverspeeding = false;

  @override
  Future<DrivingState> build() async {
    ref.onDispose(_cancelSubscription);
    final preferences = await ref.watch(drivingPreferencesProvider.future);
    final pack = await ref.watch(cameraPackProvider.future);
    return DrivingState(
      status: DrivingSessionStatus.idle,
      preferences: preferences,
      cameraCount: pack.cameras.length,
      cameraSpeedKnownCount: _knownSpeedCount(pack),
      cameraPackSource: pack.source,
    );
  }

  Future<void> start({
    bool simulated = false,
    DrivingSimulationScenario? simulationScenario,
  }) async {
    final current = state.asData?.value ?? await build();
    state = AsyncData(
      current.copyWith(
        status: DrivingSessionStatus.starting,
        clearErrorMessage: true,
      ),
    );
    final pack = await ref.read(cameraPackProvider.future);
    final Stream<DrivingPoint> drivingStream;
    final scenario = simulationScenario;
    if ((simulated || scenario != null) && canUseDebugDrivingSimulation) {
      final camera = _simulationCamera(pack, scenario);
      if (camera == null) {
        _setStopped(
          current,
          DrivingSessionStatus.locationUnavailable,
          'No hay cámaras locales compatibles para simular la ruta.',
        );
        return;
      }
      drivingStream = _simulatedApproachStream(
        camera,
        scenario ?? DrivingSimulationScenario.knownSpeed,
      );
    } else {
      final gateway = ref.read(drivingLocationGatewayProvider);
      if (!await gateway.isLocationServiceEnabled()) {
        _setStopped(
          current,
          DrivingSessionStatus.serviceDisabled,
          'Activa la ubicación del teléfono para iniciar.',
        );
        return;
      }
      var permission = await gateway.checkPermission();
      if (permission != DeviceLocationPermission.granted) {
        permission = await gateway.requestPermission();
      }
      if (permission != DeviceLocationPermission.granted) {
        _setStopped(
          current,
          _permissionStatus(permission),
          _permissionMessage(permission),
        );
        return;
      }
      drivingStream = gateway.positionStream();
    }

    _previousPoint = null;
    _wasOverspeeding = false;
    _alertEngine = _alertEngineFor(current.preferences);
    state = AsyncData(
      current.copyWith(
        status: DrivingSessionStatus.active,
        clearNearestCamera: true,
        clearLastAlert: true,
        clearErrorMessage: true,
      ),
    );
    await ref.read(drivingFeedbackGatewayProvider).setKeepScreenOn(true);
    _subscription = drivingStream.listen(
      _onPoint,
      onError: (_) {
        final latest = state.asData?.value ?? current;
        _setStopped(
          latest,
          DrivingSessionStatus.locationUnavailable,
          'No se pudo leer la ubicación en tiempo real.',
        );
      },
      cancelOnError: false,
    );
  }

  Future<void> stop() async {
    final current = state.asData?.value ?? await build();
    await _cancelSubscription();
    await ref.read(drivingFeedbackGatewayProvider).setKeepScreenOn(false);
    state = AsyncData(
      current.copyWith(
        status: DrivingSessionStatus.idle,
        clearNearestCamera: true,
        clearLastAlert: true,
        clearErrorMessage: true,
      ),
    );
  }

  Future<void> savePreferences(DrivingPreferences preferences) async {
    await saveDrivingPreferences(ref.read(appPreferencesProvider), preferences);
    _alertEngine = _alertEngineFor(preferences);
    final current = state.asData?.value ?? await build();
    state = AsyncData(current.copyWith(preferences: preferences));
  }

  Future<void> _onPoint(DrivingPoint point) async {
    final current = state.asData?.value ?? await build();
    final pack = await ref.read(cameraPackProvider.future);
    final alertEngine = _alertEngine ??= _alertEngineFor(current.preferences);
    if (point.accuracyMeters > 60) {
      alertEngine.markNoMatch(point.recordedAt);
      final keepLastAlert =
          current.lastAlert != null &&
          alertEngine.hasActiveEpisode(
            current.lastAlert!.cameraId,
            point.recordedAt,
          );
      state = AsyncData(
        current.copyWith(
          status: DrivingSessionStatus.active,
          currentPoint: point,
          clearNearestCamera: true,
          clearLastAlert: !keepLastAlert,
          clearErrorMessage: true,
        ),
      );
      return;
    }

    if (_previousPoint == null) {
      _previousPoint = point;
      alertEngine.markNoMatch(point.recordedAt);
      state = AsyncData(
        current.copyWith(
          status: DrivingSessionStatus.active,
          currentPoint: point,
          clearNearestCamera: true,
          clearLastAlert: current.lastAlert == null,
          clearErrorMessage: true,
        ),
      );
      return;
    }

    final match = matchNearestCamera(
      current: point,
      previous: _previousPoint,
      cameras: pack.cameras,
    );
    final alert = alertEngine.evaluate(
      match: match,
      speedKmh: point.speedKmh,
      now: point.recordedAt,
    );
    _previousPoint = point;
    if (alert != null) {
      await _notify(current.preferences, alert);
    }
    final keepLastAlert =
        current.lastAlert != null &&
        alertEngine.hasActiveEpisode(
          current.lastAlert!.cameraId,
          point.recordedAt,
        );
    final nextState = current.copyWith(
      status: DrivingSessionStatus.active,
      currentPoint: point,
      nearestCamera: match,
      lastAlert: alert,
      clearLastAlert: alert == null && !keepLastAlert,
      clearErrorMessage: true,
    );
    if (nextState.isOverspeeding &&
        !_wasOverspeeding &&
        current.preferences.vibrationEnabled &&
        alert == null) {
      await ref.read(drivingFeedbackGatewayProvider).vibrate();
    }
    _wasOverspeeding = nextState.isOverspeeding;
    state = AsyncData(nextState);
  }

  Future<void> _notify(
    DrivingPreferences preferences,
    DrivingAlert alert,
  ) async {
    final feedback = ref.read(drivingFeedbackGatewayProvider);
    if (preferences.voiceEnabled) {
      await feedback.speak(_voiceMessage(alert));
    }
    if (preferences.soundEnabled) {
      await feedback.playSound();
    }
    if (preferences.vibrationEnabled) {
      await feedback.vibrate();
    }
  }

  void _setStopped(
    DrivingState previous,
    DrivingSessionStatus status,
    String message,
  ) {
    _cancelSubscription();
    ref.read(drivingFeedbackGatewayProvider).setKeepScreenOn(false);
    state = AsyncData(
      previous.copyWith(
        status: status,
        errorMessage: message,
        clearNearestCamera: true,
        clearLastAlert: true,
      ),
    );
  }

  DrivingSessionStatus _permissionStatus(DeviceLocationPermission permission) {
    return switch (permission) {
      DeviceLocationPermission.granted => DrivingSessionStatus.idle,
      DeviceLocationPermission.denied => DrivingSessionStatus.permissionDenied,
      DeviceLocationPermission.deniedForever =>
        DrivingSessionStatus.permissionDeniedForever,
      DeviceLocationPermission.notRequested =>
        DrivingSessionStatus.permissionDenied,
    };
  }

  String _permissionMessage(DeviceLocationPermission permission) {
    return switch (permission) {
      DeviceLocationPermission.deniedForever =>
        'Habilita el permiso de ubicación en ajustes para conducir.',
      _ => 'PicoRadar solo usa GPS mientras Conducir está activo.',
    };
  }

  Future<void> _cancelSubscription() async {
    await _subscription?.cancel();
    _subscription = null;
    _previousPoint = null;
    _alertEngine = null;
  }

  DrivingAlertEngine _alertEngineFor(DrivingPreferences preferences) {
    return DrivingAlertEngine(
      profile: preferences.profile,
      customThresholdsMeters: preferences.customThresholdsMeters,
    );
  }

  String _voiceMessage(DrivingAlert alert) {
    final reported = alert.reportedSpeedKmh;
    if (reported == null) {
      return 'Cámara de fotodetección en operación a '
          '${alert.thresholdMeters} metros.';
    }
    if (alert.overspeed) {
      return 'Cámara a ${alert.thresholdMeters} metros. '
          'Velocidad reportada: $reported. '
          'Vas a ${alert.currentSpeedKmh}. Reduce la velocidad.';
    }
    return 'Cámara de fotodetección en operación a '
        '${alert.thresholdMeters} metros. '
        'Velocidad reportada: $reported kilómetros por hora.';
  }

  int _knownSpeedCount(CameraPack pack) {
    return pack.cameras.where((camera) => camera.speedLimitKmh != null).length;
  }

  TrafficCamera? _simulationCamera(
    CameraPack pack,
    DrivingSimulationScenario? scenario,
  ) {
    if (pack.cameras.isEmpty) {
      return null;
    }
    return switch (scenario ?? DrivingSimulationScenario.knownSpeed) {
      DrivingSimulationScenario.knownSpeed =>
        _firstCameraWhere(pack, (camera) => camera.speedLimitKmh == 60) ??
            _firstCameraWhere(pack, (camera) => camera.speedLimitKmh != null),
      DrivingSimulationScenario.unknownSpeed => _firstCameraWhere(
        pack,
        (camera) => camera.speedLimitKmh == null,
      ),
    };
  }

  TrafficCamera? _firstCameraWhere(
    CameraPack pack,
    bool Function(TrafficCamera camera) predicate,
  ) {
    for (final camera in pack.cameras) {
      if (predicate(camera)) {
        return camera;
      }
    }
    return null;
  }

  Stream<DrivingPoint> _simulatedApproachStream(
    TrafficCamera camera,
    DrivingSimulationScenario scenario,
  ) {
    final now = DateTime.now().toUtc();
    final metersSouth = [520.0, 390.0, 290.0, 95.0, 45.0];
    final reported = camera.speedLimitKmh ?? 60;
    final speeds = switch (scenario) {
      DrivingSimulationScenario.knownSpeed => [
        reported - 10.0,
        reported - 2.0,
        reported + 2.0,
        reported + 10.0,
        reported - 6.0,
      ],
      DrivingSimulationScenario.unknownSpeed => [48.0, 58.0, 68.0, 78.0, 70.0],
    };
    final points = [
      for (var index = 0; index < metersSouth.length; index += 1)
        DrivingPoint(
          latitude: camera.latitude - metersSouth[index] / 111320,
          longitude: camera.longitude,
          accuracyMeters: 12,
          speedKmh: speeds[index],
          headingDegrees: 0,
          recordedAt: now.add(Duration(seconds: index * 20)),
        ),
    ];
    return Stream<DrivingPoint>.periodic(
      const Duration(milliseconds: 800),
      (index) => points[index],
    ).take(points.length);
  }
}
