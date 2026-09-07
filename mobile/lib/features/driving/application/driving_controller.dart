import 'dart:async';
import 'dart:math' as math;

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

enum DrivingSimulationScenario {
  knownSpeed,
  unknownSpeed,
  sidePass,
  lateralApproach,
  turnAway,
  gpsWeak,
}

enum DrivingSpeedState {
  noCamera,
  unknownVehicleSpeed,
  unknownReportedSpeed,
  within,
  near,
  over,
}

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

final drivingGpsStaleAfterProvider = Provider<Duration>((ref) {
  return const Duration(seconds: 3);
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
  stale('GPS sin actualizar'),
  good('GPS bueno'),
  fair('GPS medio'),
  weak('GPS débil');

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
    this.cameraEpisodeKey,
    this.lastAlert,
    this.dismissedCameraId,
    this.errorMessage,
    this.gpsStale = false,
  });

  final DrivingSessionStatus status;
  final DrivingPreferences preferences;
  final int cameraCount;
  final int cameraSpeedKnownCount;
  final CameraPackSource? cameraPackSource;
  final DrivingPoint? currentPoint;
  final CameraMatch? nearestCamera;
  final String? cameraEpisodeKey;
  final DrivingAlert? lastAlert;
  final String? dismissedCameraId;
  final String? errorMessage;
  final bool gpsStale;

  bool get isActive => status == DrivingSessionStatus.active;

  int? get speedKmh => gpsStale ? null : currentPoint?.speedKmh?.round();

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
    return (speedKmh ?? reported) - reported;
  }

  DrivingSpeedState get speedState {
    final camera = currentCamera;
    if (!isActive || camera == null) {
      return DrivingSpeedState.noCamera;
    }
    final currentSpeed = speedKmh;
    if (currentSpeed == null) {
      return DrivingSpeedState.unknownVehicleSpeed;
    }
    final reported = camera.speedLimitKmh;
    if (reported == null) {
      return DrivingSpeedState.unknownReportedSpeed;
    }
    // UI hysteresis only: avoids color jitter. This is not a legal tolerance.
    if (currentSpeed > reported + drivingOverspeedVisualMarginKmh) {
      return DrivingSpeedState.over;
    }
    if (currentSpeed >= reported - 5) {
      return DrivingSpeedState.near;
    }
    return DrivingSpeedState.within;
  }

  bool get isOverspeeding => speedState == DrivingSpeedState.over;

  bool get hasTargetCamera =>
      isActive && canEvaluateAlerts && nearestCamera != null;

  bool get showCameraAlertPanel =>
      hasTargetCamera && dismissedCameraId != nearestCamera!.camera.id;

  bool get canEvaluateAlerts {
    if (gpsStale) {
      return false;
    }
    final accuracy = currentPoint?.accuracyMeters;
    return accuracy != null && accuracy <= 60;
  }

  GpsQuality get gpsQuality {
    if (gpsStale) {
      return GpsQuality.stale;
    }
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
    String? cameraEpisodeKey,
    DrivingAlert? lastAlert,
    String? dismissedCameraId,
    String? errorMessage,
    bool clearNearestCamera = false,
    bool clearLastAlert = false,
    bool clearDismissedCamera = false,
    bool clearErrorMessage = false,
    bool? gpsStale,
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
      cameraEpisodeKey: clearNearestCamera
          ? null
          : cameraEpisodeKey ?? this.cameraEpisodeKey,
      lastAlert: clearLastAlert ? null : lastAlert ?? this.lastAlert,
      dismissedCameraId: clearDismissedCamera
          ? null
          : dismissedCameraId ?? this.dismissedCameraId,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      gpsStale: gpsStale ?? this.gpsStale,
    );
  }
}

class DrivingController extends AsyncNotifier<DrivingState> {
  StreamSubscription<DrivingPoint>? _subscription;
  DrivingPoint? _previousPoint;
  DrivingAlertEngine? _alertEngine;
  bool _wasOverspeeding = false;
  String? _activeCameraId;
  var _cameraEpisodeSerial = 0;
  var _sessionSerial = 0;
  var _processingPoint = false;
  DrivingPoint? _pendingPoint;
  var _feedbackActive = false;
  ({DrivingPreferences preferences, DrivingAlert alert, int sessionSerial})?
  _pendingFeedback;
  Timer? _gpsStaleTimer;

  @override
  Future<DrivingState> build() async {
    final cleanupFeedback = ref.read(drivingFeedbackGatewayProvider);
    ref.onDispose(() {
      _sessionSerial += 1;
      _pendingPoint = null;
      _pendingFeedback = null;
      _gpsStaleTimer?.cancel();
      unawaited(_cancelSubscription());
      unawaited(_stopNativeSessionCleanup(cleanupFeedback));
    });
    final preferences = await ref.watch(drivingPreferencesProvider.future);
    final pack = await ref.watch(cameraPackProvider.future);
    final current = state.asData?.value;
    if (current != null && current.status != DrivingSessionStatus.idle) {
      return current.copyWith(
        cameraCount: pack.cameras.length,
        cameraSpeedKnownCount: _knownSpeedCount(pack),
        cameraPackSource: pack.source,
        preferences: preferences,
      );
    }
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
    final current =
        state.asData?.value ??
        const DrivingState(
          status: DrivingSessionStatus.idle,
          preferences: defaultDrivingPreferences,
          cameraCount: 0,
          cameraSpeedKnownCount: 0,
        );
    if (current.status == DrivingSessionStatus.starting ||
        current.status == DrivingSessionStatus.active) {
      return;
    }
    _sessionSerial += 1;
    final sessionSerial = _sessionSerial;
    _pendingPoint = null;
    _pendingFeedback = null;
    _gpsStaleTimer?.cancel();
    state = AsyncData(
      current.copyWith(
        status: DrivingSessionStatus.starting,
        clearErrorMessage: true,
        gpsStale: false,
      ),
    );
    final pack = await ref.read(cameraPackProvider.future);
    if (!_isCurrentStart(sessionSerial)) {
      return;
    }
    final Stream<DrivingPoint> drivingStream;
    final readyState = current.copyWith(
      cameraCount: pack.cameras.length,
      cameraSpeedKnownCount: _knownSpeedCount(pack),
      cameraPackSource: pack.source,
    );
    final scenario = simulationScenario;
    if ((simulated || scenario != null) && canUseDebugDrivingSimulation) {
      final camera = _simulationCamera(pack, scenario);
      if (camera == null) {
        await _setStopped(
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
        if (!_isCurrentStart(sessionSerial)) {
          return;
        }
        await _setStopped(
          current,
          DrivingSessionStatus.serviceDisabled,
          'Activa la ubicación del teléfono para iniciar.',
        );
        return;
      }
      if (!_isCurrentStart(sessionSerial)) {
        return;
      }
      var permission = await gateway.checkPermission();
      if (!_isCurrentStart(sessionSerial)) {
        return;
      }
      if (permission != DeviceLocationPermission.granted) {
        permission = await gateway.requestPermission();
      }
      if (!_isCurrentStart(sessionSerial)) {
        return;
      }
      if (permission != DeviceLocationPermission.granted) {
        await _setStopped(
          current,
          _permissionStatus(permission),
          _permissionMessage(permission),
        );
        return;
      }
      drivingStream = gateway.positionStream();
    }

    await _cancelSubscription();
    if (!_isCurrentStart(sessionSerial)) {
      return;
    }
    _previousPoint = null;
    _wasOverspeeding = false;
    _activeCameraId = null;
    _alertEngine = _alertEngineFor(readyState.preferences);
    state = AsyncData(
      readyState.copyWith(
        status: DrivingSessionStatus.active,
        clearNearestCamera: true,
        clearLastAlert: true,
        clearDismissedCamera: true,
        clearErrorMessage: true,
      ),
    );
    await ref.read(drivingFeedbackGatewayProvider).setKeepScreenOn(true);
    if (!_isActiveSession(sessionSerial)) {
      await _stopNativeSessionCleanup();
      return;
    }
    _subscription = drivingStream.listen(
      (point) => _enqueuePoint(point, sessionSerial),
      onError: (_) {
        final latest = state.asData?.value ?? current;
        unawaited(
          _setStopped(
            latest,
            DrivingSessionStatus.locationUnavailable,
            'No se pudo leer la ubicación en tiempo real.',
          ),
        );
      },
      cancelOnError: false,
    );
  }

  Future<void> stop() async {
    final current = state.asData?.value ?? await build();
    _sessionSerial += 1;
    _pendingPoint = null;
    _pendingFeedback = null;
    _gpsStaleTimer?.cancel();
    await _cancelSubscription();
    await _stopNativeSessionCleanup();
    state = AsyncData(
      current.copyWith(
        status: DrivingSessionStatus.idle,
        clearNearestCamera: true,
        clearLastAlert: true,
        clearDismissedCamera: true,
        clearErrorMessage: true,
      ),
    );
  }

  Future<void> dismissCurrentCameraAlert() async {
    final current = state.asData?.value ?? await build();
    final cameraId = current.nearestCamera?.camera.id;
    if (cameraId == null) {
      return;
    }
    state = AsyncData(current.copyWith(dismissedCameraId: cameraId));
  }

  Future<void> savePreferences(DrivingPreferences preferences) async {
    await saveDrivingPreferences(ref.read(appPreferencesProvider), preferences);
    final current = state.asData?.value ?? await build();
    if (_shouldResetAlertEngine(current.preferences, preferences, current)) {
      _alertEngine = _alertEngineFor(preferences);
    }
    state = AsyncData(current.copyWith(preferences: preferences));
  }

  void _enqueuePoint(DrivingPoint point, int sessionSerial) {
    if (_processingPoint) {
      final pending = _pendingPoint;
      if (pending == null || point.recordedAt.isAfter(pending.recordedAt)) {
        _pendingPoint = point;
      }
      return;
    }
    _processingPoint = true;
    unawaited(_drainPoints(point, sessionSerial));
  }

  Future<void> _drainPoints(DrivingPoint first, int sessionSerial) async {
    var point = first;
    try {
      while (_isActiveSession(sessionSerial)) {
        await _onPoint(point, sessionSerial);
        await Future<void>.value();
        final pending = _pendingPoint;
        _pendingPoint = null;
        if (pending == null) {
          break;
        }
        point = pending;
      }
    } catch (_) {
      if (_isActiveSession(sessionSerial)) {
        final latest = state.asData?.value;
        if (latest != null) {
          await _setStopped(
            latest,
            DrivingSessionStatus.locationUnavailable,
            'No se pudo leer la ubicación en tiempo real.',
          );
        }
      }
    } finally {
      _processingPoint = false;
      final pending = _pendingPoint;
      _pendingPoint = null;
      if (pending != null && _isActiveSession(sessionSerial)) {
        _enqueuePoint(pending, sessionSerial);
      }
    }
  }

  Future<void> _onPoint(DrivingPoint point, int sessionSerial) async {
    if (!_isActiveSession(sessionSerial)) {
      return;
    }
    final current = state.asData?.value ?? await build();
    if (!_isActiveSession(sessionSerial)) {
      return;
    }
    final latestPoint = current.currentPoint;
    if (latestPoint != null &&
        !point.recordedAt.isAfter(latestPoint.recordedAt)) {
      return;
    }
    final pack = await ref.read(cameraPackProvider.future);
    if (!_isActiveSession(sessionSerial)) {
      return;
    }
    final alertEngine = _alertEngine ??= _alertEngineFor(current.preferences);
    if (point.accuracyMeters > 60) {
      _previousPoint = null;
      alertEngine.markNoMatch(point.recordedAt);
      final keepLastAlert =
          current.lastAlert != null &&
          alertEngine.hasActiveEpisode(
            current.lastAlert!.cameraId,
            point.recordedAt,
          );
      final keepDismissal = _hasActiveDismissal(current, point.recordedAt);
      state = AsyncData(
        current.copyWith(
          status: DrivingSessionStatus.active,
          currentPoint: point,
          clearNearestCamera: true,
          clearLastAlert: !keepLastAlert,
          clearDismissedCamera: !keepDismissal,
          clearErrorMessage: true,
          gpsStale: false,
        ),
      );
      _armGpsStaleTimer(point, sessionSerial);
      return;
    }

    if (_previousPoint == null) {
      _previousPoint = point;
      alertEngine.markNoMatch(point.recordedAt);
      final keepDismissal = _hasActiveDismissal(current, point.recordedAt);
      state = AsyncData(
        current.copyWith(
          status: DrivingSessionStatus.active,
          currentPoint: point,
          clearNearestCamera: true,
          clearLastAlert: current.lastAlert == null,
          clearDismissedCamera: !keepDismissal,
          clearErrorMessage: true,
          gpsStale: false,
        ),
      );
      _armGpsStaleTimer(point, sessionSerial);
      return;
    }

    final match = matchNearestCamera(
      current: point,
      previous: _previousPoint,
      cameras: pack.cameras,
      targetingConeDegrees: current.preferences.cameraTargetingConeDegrees,
    );
    final sameActiveEpisode =
        match != null &&
        alertEngine.hasActiveEpisode(match.camera.id, point.recordedAt);
    final episodeKey = match == null
        ? current.cameraEpisodeKey
        : _episodeKeyFor(match.camera.id, sameActiveEpisode);
    final alert = alertEngine.evaluate(
      match: match,
      speedKmh: point.speedKmh ?? 0,
      now: point.recordedAt,
    );
    _previousPoint = point;
    final dismissedCurrentEpisode =
        match != null &&
        current.dismissedCameraId == match.camera.id &&
        sameActiveEpisode;
    final visibleAlert = dismissedCurrentEpisode ? null : alert;
    final keepLastAlert =
        current.lastAlert != null &&
        alertEngine.hasActiveEpisode(
          current.lastAlert!.cameraId,
          point.recordedAt,
        );
    final keepDismissalWithoutMatch =
        match == null && _hasActiveDismissal(current, point.recordedAt);
    final clearDismissedCamera =
        current.dismissedCameraId != null &&
        !dismissedCurrentEpisode &&
        !keepDismissalWithoutMatch;
    final nextState = current.copyWith(
      status: DrivingSessionStatus.active,
      currentPoint: point,
      nearestCamera: match,
      cameraEpisodeKey: episodeKey,
      lastAlert: visibleAlert,
      clearNearestCamera: match == null,
      clearLastAlert: visibleAlert == null && !keepLastAlert,
      clearDismissedCamera: clearDismissedCamera,
      clearErrorMessage: true,
      gpsStale: false,
    );
    final wasOverspeeding = _wasOverspeeding;
    _wasOverspeeding = nextState.isOverspeeding;
    state = AsyncData(nextState);
    _armGpsStaleTimer(point, sessionSerial);
    if (visibleAlert != null) {
      _enqueueFeedback(current.preferences, visibleAlert, sessionSerial);
    } else if (nextState.isOverspeeding &&
        !wasOverspeeding &&
        current.preferences.vibrationEnabled &&
        !dismissedCurrentEpisode) {
      unawaited(ref.read(drivingFeedbackGatewayProvider).vibrate());
    }
  }

  void _armGpsStaleTimer(DrivingPoint point, int sessionSerial) {
    _gpsStaleTimer?.cancel();
    _gpsStaleTimer = Timer(ref.read(drivingGpsStaleAfterProvider), () {
      if (!_isActiveSession(sessionSerial)) {
        return;
      }
      final current = state.asData?.value;
      if (current == null || current.currentPoint != point) {
        return;
      }
      _previousPoint = null;
      state = AsyncData(
        current.copyWith(
          gpsStale: true,
          clearNearestCamera: true,
          clearLastAlert: true,
          clearDismissedCamera: true,
        ),
      );
    });
  }

  void _enqueueFeedback(
    DrivingPreferences preferences,
    DrivingAlert alert,
    int sessionSerial,
  ) {
    if (_feedbackActive) {
      _pendingFeedback = (
        preferences: preferences,
        alert: alert,
        sessionSerial: sessionSerial,
      );
      return;
    }
    _feedbackActive = true;
    unawaited(_drainFeedback(preferences, alert, sessionSerial));
  }

  Future<void> _drainFeedback(
    DrivingPreferences preferences,
    DrivingAlert alert,
    int sessionSerial,
  ) async {
    var next = (
      preferences: preferences,
      alert: alert,
      sessionSerial: sessionSerial,
    );
    try {
      while (_isActiveSession(next.sessionSerial)) {
        try {
          await _notify(next.preferences, next.alert, next.sessionSerial);
        } catch (_) {
          // Feedback failures must never stop GPS processing.
        }
        final pending = _pendingFeedback;
        _pendingFeedback = null;
        if (pending == null) {
          break;
        }
        next = pending;
      }
    } finally {
      _feedbackActive = false;
      final pending = _pendingFeedback;
      _pendingFeedback = null;
      if (pending != null && _isActiveSession(pending.sessionSerial)) {
        _enqueueFeedback(
          pending.preferences,
          pending.alert,
          pending.sessionSerial,
        );
      }
    }
  }

  bool _isActiveSession(int sessionSerial) {
    return sessionSerial == _sessionSerial &&
        state.asData?.value.status == DrivingSessionStatus.active;
  }

  bool _isCurrentStart(int sessionSerial) {
    return sessionSerial == _sessionSerial &&
        state.asData?.value.status == DrivingSessionStatus.starting;
  }

  bool _hasActiveDismissal(DrivingState current, DateTime now) {
    final dismissedCameraId = current.dismissedCameraId;
    final alertEngine = _alertEngine;
    return dismissedCameraId != null &&
        alertEngine != null &&
        alertEngine.hasActiveEpisode(dismissedCameraId, now);
  }

  String _episodeKeyFor(String cameraId, bool sameActiveEpisode) {
    if (_activeCameraId != cameraId || !sameActiveEpisode) {
      _activeCameraId = cameraId;
      _cameraEpisodeSerial += 1;
    }
    return '$cameraId:$_cameraEpisodeSerial';
  }

  Future<void> _notify(
    DrivingPreferences preferences,
    DrivingAlert alert,
    int sessionSerial,
  ) async {
    final feedback = ref.read(drivingFeedbackGatewayProvider);
    if (preferences.voiceEnabled || preferences.soundEnabled) {
      if (!_isActiveSession(sessionSerial)) {
        return;
      }
      await feedback.playAlert(
        message: preferences.voiceEnabled ? _voiceMessage(alert) : null,
        playSound: preferences.soundEnabled,
        output: preferences.alertOutput,
        musicBehavior: preferences.musicBehavior,
        volume: preferences.alertVolume,
      );
      if (!_isActiveSession(sessionSerial)) {
        return;
      }
    }
    if (preferences.vibrationEnabled) {
      if (!_isActiveSession(sessionSerial)) {
        return;
      }
      await feedback.vibrate();
      if (!_isActiveSession(sessionSerial)) {
        return;
      }
    }
  }

  Future<void> _setStopped(
    DrivingState previous,
    DrivingSessionStatus status,
    String message,
  ) async {
    _sessionSerial += 1;
    _pendingPoint = null;
    _pendingFeedback = null;
    _gpsStaleTimer?.cancel();
    await _cancelSubscription();
    await _stopNativeSessionCleanup();
    state = AsyncData(
      previous.copyWith(
        status: status,
        errorMessage: message,
        clearNearestCamera: true,
        clearLastAlert: true,
        clearDismissedCamera: true,
      ),
    );
  }

  Future<void> _stopNativeSessionCleanup([
    DrivingFeedbackGateway? gateway,
  ]) async {
    final DrivingFeedbackGateway feedback =
        gateway ?? ref.read(drivingFeedbackGatewayProvider);
    try {
      await feedback.stopOngoingFeedback();
    } catch (_) {
      // Cleanup must be idempotent and must not crash the UI.
    }
    try {
      await feedback.setKeepScreenOn(false);
    } catch (_) {
      // Cleanup must be idempotent and must not crash the UI.
    }
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
    _activeCameraId = null;
    _gpsStaleTimer?.cancel();
    _gpsStaleTimer = null;
  }

  bool _shouldResetAlertEngine(
    DrivingPreferences previous,
    DrivingPreferences next,
    DrivingState current,
  ) {
    final alertConfigChanged =
        previous.profile != next.profile ||
        !_sameThresholds(
          previous.customThresholdsMeters,
          next.customThresholdsMeters,
        );
    return alertConfigChanged && !current.isActive;
  }

  bool _sameThresholds(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) {
        return false;
      }
    }
    return true;
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
      DrivingSimulationScenario.sidePass => _firstCameraWhere(
        pack,
        (camera) => camera.speedLimitKmh != null,
      ),
      DrivingSimulationScenario.lateralApproach => _firstCameraWhere(
        pack,
        (camera) => camera.speedLimitKmh != null,
      ),
      DrivingSimulationScenario.turnAway => _firstCameraWhere(
        pack,
        (camera) => camera.speedLimitKmh != null,
      ),
      DrivingSimulationScenario.gpsWeak => _firstCameraWhere(
        pack,
        (camera) => camera.speedLimitKmh != null,
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
    if (scenario == DrivingSimulationScenario.sidePass) {
      return _simulatedSidePassStream(camera);
    }
    if (scenario == DrivingSimulationScenario.lateralApproach) {
      return _simulatedLateralApproachStream(camera);
    }
    if (scenario == DrivingSimulationScenario.turnAway) {
      return _simulatedTurnAwayStream(camera);
    }
    if (scenario == DrivingSimulationScenario.gpsWeak) {
      return _simulatedGpsWeakStream(camera);
    }
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
      DrivingSimulationScenario.sidePass => [46.0, 52.0, 58.0, 56.0, 50.0],
      DrivingSimulationScenario.lateralApproach => [
        52.0,
        56.0,
        60.0,
        64.0,
        58.0,
      ],
      DrivingSimulationScenario.turnAway => [52.0, 56.0, 60.0, 58.0, 54.0],
      DrivingSimulationScenario.gpsWeak => [0.0, 0.0, 0.0, 0.0, 0.0],
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

  Stream<DrivingPoint> _simulatedLateralApproachStream(TrafficCamera camera) {
    final now = DateTime.now().toUtc();
    const steps = [
      _RadarDemoStep(
        distanceMeters: 560,
        relativeBearingDegrees: 65,
        speedKmh: 50,
      ),
      _RadarDemoStep(
        distanceMeters: 500,
        relativeBearingDegrees: 65,
        speedKmh: 52,
      ),
      _RadarDemoStep(
        distanceMeters: 380,
        relativeBearingDegrees: 20,
        speedKmh: 56,
      ),
      _RadarDemoStep(
        distanceMeters: 260,
        relativeBearingDegrees: 14,
        speedKmh: 60,
      ),
      _RadarDemoStep(
        distanceMeters: 140,
        relativeBearingDegrees: 8,
        speedKmh: 64,
      ),
      _RadarDemoStep(
        distanceMeters: 60,
        relativeBearingDegrees: 0,
        speedKmh: 58,
      ),
    ];
    final points = [
      for (var index = 0; index < steps.length; index += 1)
        _pointWithCameraAtRelativeBearing(
          camera: camera,
          step: steps[index],
          recordedAt: now.add(Duration(seconds: index * 20)),
        ),
    ];
    return Stream<DrivingPoint>.periodic(
      const Duration(milliseconds: 800),
      (index) => points[index],
    ).take(points.length);
  }

  Stream<DrivingPoint> _simulatedTurnAwayStream(TrafficCamera camera) {
    final now = DateTime.now().toUtc();
    const steps = [
      _RadarDemoStep(
        distanceMeters: 480,
        relativeBearingDegrees: 8,
        speedKmh: 52,
      ),
      _RadarDemoStep(
        distanceMeters: 300,
        relativeBearingDegrees: 4,
        speedKmh: 56,
      ),
      _RadarDemoStep(
        distanceMeters: 220,
        relativeBearingDegrees: 0,
        speedKmh: 60,
      ),
      _RadarDemoStep(
        distanceMeters: 260,
        relativeBearingDegrees: -82,
        speedKmh: 58,
      ),
      _RadarDemoStep(
        distanceMeters: 360,
        relativeBearingDegrees: -112,
        speedKmh: 54,
      ),
    ];
    final points = [
      for (var index = 0; index < steps.length; index += 1)
        _pointWithCameraAtRelativeBearing(
          camera: camera,
          step: steps[index],
          recordedAt: now.add(Duration(seconds: index * 20)),
        ),
    ];
    return Stream<DrivingPoint>.periodic(
      const Duration(milliseconds: 800),
      (index) => points[index],
    ).take(points.length);
  }

  DrivingPoint _pointWithCameraAtRelativeBearing({
    required TrafficCamera camera,
    required _RadarDemoStep step,
    required DateTime recordedAt,
  }) {
    final bearingRadians = step.relativeBearingDegrees * math.pi / 180;
    final northMeters = math.cos(bearingRadians) * step.distanceMeters;
    final eastMeters = math.sin(bearingRadians) * step.distanceMeters;
    final metersPerLongitude =
        111320.0 * math.cos(camera.latitude * math.pi / 180);
    return DrivingPoint(
      latitude: camera.latitude - northMeters / 111320.0,
      longitude: camera.longitude - eastMeters / metersPerLongitude,
      accuracyMeters: 12,
      speedKmh: step.speedKmh,
      headingDegrees: 0,
      recordedAt: recordedAt,
    );
  }

  Stream<DrivingPoint> _simulatedSidePassStream(TrafficCamera camera) {
    final now = DateTime.now().toUtc();
    const sideOffsetMeters = 400.0;
    final routeLongitude = camera.longitude - sideOffsetMeters / 110650;
    final metersSouth = [520.0, 260.0, 0.0, -260.0, -520.0];
    final speeds = [46.0, 52.0, 58.0, 56.0, 50.0];
    final points = [
      for (var index = 0; index < metersSouth.length; index += 1)
        DrivingPoint(
          latitude: camera.latitude - metersSouth[index] / 111320,
          longitude: routeLongitude,
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

  Stream<DrivingPoint> _simulatedGpsWeakStream(TrafficCamera camera) {
    final now = DateTime.now().toUtc();
    final metersSouth = [480.0, 360.0, 250.0, 160.0, 90.0];
    final points = [
      for (var index = 0; index < metersSouth.length; index += 1)
        DrivingPoint(
          latitude: camera.latitude - metersSouth[index] / 111320,
          longitude: camera.longitude,
          accuracyMeters: 95,
          speedKmh: 0,
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

class _RadarDemoStep {
  const _RadarDemoStep({
    required this.distanceMeters,
    required this.relativeBearingDegrees,
    required this.speedKmh,
  });

  final double distanceMeters;
  final double relativeBearingDegrees;
  final double speedKmh;
}
