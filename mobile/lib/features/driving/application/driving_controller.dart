import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../location/platform/device_location_gateway.dart';
import '../../trip/data/toll_inventory.dart';
import '../../trip/data/toll_tariff_catalog.dart';
import '../data/camera_pack_loader.dart';
import '../data/driving_preferences.dart';
import '../data/driving_regional_demo.dart';
import '../domain/camera_matcher.dart';
import '../domain/driving_alert_engine.dart';
import '../domain/traffic_camera.dart';
import '../domain/toll_matcher.dart';
import '../domain/toll_alert_session.dart';
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
  cocorna,
  niquiaToEstrella,
  estrellaToNiquia;

  String get label => switch (this) {
    knownSpeed => 'Con velocidad',
    unknownSpeed => 'Sin velocidad',
    sidePass => 'Cámara lateral',
    lateralApproach => 'Radar 500 m',
    turnAway => 'Giro antes',
    gpsWeak => 'GPS débil',
    cocorna => 'Simulación · Peaje Cocorná',
    niquiaToEstrella => 'Niquía → La Estrella',
    estrellaToNiquia => 'La Estrella → Niquía',
  };

  bool get isRegional => this == niquiaToEstrella || this == estrellaToNiquia;
}

enum DrivingSpeedState { noCamera, unknownReportedSpeed, within, near, over }

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
    this.simulationName,
    this.nearestToll,
    this.referenceCharge,
    this.tollEpisodeKey,
    this.tollDataError,
    this.reliableHeadingDegrees,
    this.visualAlertPulseKey,
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
  final String? simulationName;
  final TollMatch? nearestToll;
  final LocalTollPricingCharge? referenceCharge;
  final String? tollEpisodeKey;
  final String? tollDataError;
  final double? reliableHeadingDegrees;
  final String? visualAlertPulseKey;

  bool get showTollAlertPanel =>
      isActive &&
      canEvaluateAlerts &&
      preferences.tollAlertsEnabled &&
      nearestToll != null &&
      !showCameraAlertPanel;

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

  int get speedDeltaKmh => 0;

  DrivingSpeedState get speedState {
    final camera = currentCamera;
    if (!isActive || camera == null) {
      return DrivingSpeedState.noCamera;
    }
    // ANSV metadata is not a verified speed limit for the current road.
    return DrivingSpeedState.unknownReportedSpeed;
  }

  bool get isOverspeeding => speedState == DrivingSpeedState.over;

  bool get hasTargetCamera =>
      isActive && canEvaluateAlerts && nearestCamera != null;

  bool get showCameraAlertPanel =>
      hasTargetCamera && dismissedCameraId != nearestCamera!.camera.id;

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
    String? cameraEpisodeKey,
    DrivingAlert? lastAlert,
    String? dismissedCameraId,
    String? errorMessage,
    String? simulationName,
    bool clearSimulation = false,
    bool clearCurrentPoint = false,
    bool clearNearestCamera = false,
    bool clearLastAlert = false,
    bool clearDismissedCamera = false,
    bool clearErrorMessage = false,
    TollMatch? nearestToll,
    LocalTollPricingCharge? referenceCharge,
    String? tollEpisodeKey,
    String? tollDataError,
    double? reliableHeadingDegrees,
    bool clearNearestToll = false,
    bool clearTollDataError = false,
    bool clearReliableHeading = false,
    String? visualAlertPulseKey,
    bool clearVisualAlertPulse = false,
  }) {
    return DrivingState(
      status: status ?? this.status,
      nearestToll: clearNearestToll ? null : nearestToll ?? this.nearestToll,
      referenceCharge: clearNearestToll
          ? null
          : referenceCharge ?? this.referenceCharge,
      tollEpisodeKey: clearNearestToll
          ? null
          : tollEpisodeKey ?? this.tollEpisodeKey,
      tollDataError: clearTollDataError
          ? null
          : tollDataError ?? this.tollDataError,
      reliableHeadingDegrees: clearReliableHeading
          ? null
          : reliableHeadingDegrees ?? this.reliableHeadingDegrees,
      visualAlertPulseKey: clearVisualAlertPulse
          ? null
          : visualAlertPulseKey ?? this.visualAlertPulseKey,
      preferences: preferences ?? this.preferences,
      cameraCount: cameraCount ?? this.cameraCount,
      cameraSpeedKnownCount:
          cameraSpeedKnownCount ?? this.cameraSpeedKnownCount,
      cameraPackSource: cameraPackSource ?? this.cameraPackSource,
      currentPoint: clearCurrentPoint
          ? null
          : currentPoint ?? this.currentPoint,
      simulationName: clearSimulation
          ? null
          : simulationName ?? this.simulationName,
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
    );
  }
}

class DrivingController extends AsyncNotifier<DrivingState> {
  static var _nextMapSessionId = 0;
  var _mapSessionId = 0;
  StreamSubscription<DrivingPoint>? _subscription;
  DrivingPoint? _previousPoint;
  DrivingAlertEngine? _alertEngine;
  String? _activeCameraId;
  var _cameraEpisodeSerial = 0;
  var _sessionSerial = 0;
  Future<void> _pointProcessing = Future<void>.value();
  CameraPack? _sessionPack;
  TollAlertSession _tollSession = TollAlertSession();
  List<TollInventoryRecord> _tolls = const [];
  Map<String, LocalTollPricingCharge> _tollCharges = const {};
  Future<void>? _tollLoading;
  var _tollLoadGeneration = 0;
  String? _tollLoadError;
  String? _feedbackTarget;
  var _feedbackSerial = 0;
  var _visualPulseSerial = 0;
  Future<void> _feedbackStop = Future<void>.value();

  @override
  Future<DrivingState> build() async {
    final cleanupFeedback = ref.read(drivingFeedbackGatewayProvider);
    ref.onDispose(() {
      _sessionSerial += 1;
      _pointProcessing = Future<void>.value();
      unawaited(_cancelSubscription());
      unawaited(_stopNativeSessionCleanup(gateway: cleanupFeedback));
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
    final wantsSimulation = simulated || simulationScenario != null;
    if (wantsSimulation && !canUseDebugDrivingSimulation) {
      state = AsyncData(
        current.copyWith(
          status: DrivingSessionStatus.locationUnavailable,
          errorMessage:
              'La simulación solo está disponible en debug habilitado.',
          clearSimulation: true,
          clearCurrentPoint: true,
        ),
      );
      return;
    }
    final scenario = wantsSimulation
        ? simulationScenario ?? DrivingSimulationScenario.knownSpeed
        : null;
    _sessionSerial += 1;
    final sessionSerial = _sessionSerial;
    _mapSessionId = ++_nextMapSessionId;
    _tollLoadGeneration++;
    _tollLoading = null;
    _tolls = const [];
    _tollCharges = const {};
    _tollLoadError = null;
    // Loading is independent of GPS startup and never happens per location.
    if (current.preferences.tollAlertsEnabled ||
        scenario == DrivingSimulationScenario.cocorna) {
      unawaited(_ensureTollData());
    }
    _pointProcessing = Future<void>.value();
    state = AsyncData(
      current.copyWith(
        status: DrivingSessionStatus.starting,
        clearErrorMessage: true,
        simulationName: scenario?.label,
        clearSimulation: !wantsSimulation,
        clearCurrentPoint: true,
        clearVisualAlertPulse: true,
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
      simulationName: scenario?.label,
      clearSimulation: !wantsSimulation,
      clearCurrentPoint: true,
    );
    if (scenario == DrivingSimulationScenario.cocorna) {
      await _ensureTollData();
      if (!_isCurrentStart(sessionSerial)) return;
      final toll = _tolls
          .where((toll) => toll.id == 'INV-COCORNA-6A6F1282D1')
          .firstOrNull;
      if (toll == null) {
        await _setStopped(
          readyState,
          DrivingSessionStatus.locationUnavailable,
          'No se pudo cargar el peaje real para la simulación.',
        );
        return;
      }
      drivingStream = _simulatedTollStream(toll);
    } else if (scenario != null && scenario.isRegional) {
      try {
        final route = await ref.read(drivingRegionalDemoLoaderProvider)(
          scenario.name,
        );
        if (!_isCurrentStart(sessionSerial)) return;
        drivingStream = route.play();
      } catch (_) {
        if (!_isCurrentStart(sessionSerial)) return;
        await _setStopped(
          readyState,
          DrivingSessionStatus.locationUnavailable,
          'No se pudo cargar la ruta de simulación local.',
        );
        return;
      }
    } else if (scenario != null) {
      final camera = _simulationCamera(pack, scenario);
      if (camera == null) {
        await _setStopped(
          current,
          DrivingSessionStatus.locationUnavailable,
          'No hay cámaras locales compatibles para simular la ruta.',
        );
        return;
      }
      drivingStream = _simulatedApproachStream(camera, scenario);
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
    _sessionPack = pack;
    _tollSession = TollAlertSession();
    _activeCameraId = null;
    final latestPreferences =
        state.asData?.value.preferences ?? readyState.preferences;
    _alertEngine = _alertEngineFor(latestPreferences);
    state = AsyncData(
      readyState.copyWith(
        status: DrivingSessionStatus.active,
        preferences: latestPreferences,
        clearNearestCamera: true,
        clearNearestToll: true,
        clearReliableHeading: true,
        tollDataError: _tollLoadError,
        clearTollDataError: _tollLoadError == null,
        clearLastAlert: true,
        clearDismissedCamera: true,
        clearErrorMessage: true,
      ),
    );
    await ref.read(drivingFeedbackGatewayProvider).setKeepScreenOn(true);
    if (!_isActiveSession(sessionSerial)) {
      await _stopNativeSessionCleanup(onlyWhenInactive: true);
      return;
    }
    _subscription = drivingStream.listen(
      (point) => _enqueuePoint(point, sessionSerial),
      onError: (_) {
        if (!_isActiveSession(sessionSerial)) return;
        final latest = state.asData?.value ?? current;
        unawaited(
          _setStopped(
            latest,
            DrivingSessionStatus.locationUnavailable,
            'No se pudo leer la ubicación en tiempo real.',
          ),
        );
      },
      onDone:
          scenario?.isRegional == true ||
              scenario == DrivingSimulationScenario.cocorna
          ? () => unawaited(_finishSimulation(sessionSerial))
          : null,
      cancelOnError: false,
    );
  }

  Future<void> _finishSimulation(int sessionSerial) async {
    await _pointProcessing;
    if (_isActiveSession(sessionSerial)) await stop();
  }

  Future<void> stop() async {
    final current = state.asData?.value ?? await build();
    _sessionSerial += 1;
    final sessionSerial = _sessionSerial;
    _pointProcessing = Future<void>.value();
    await _cancelSubscription();
    await _stopNativeSessionCleanup();
    if (!ref.mounted || sessionSerial != _sessionSerial) return;
    state = AsyncData(
      current.copyWith(
        status: DrivingSessionStatus.idle,
        clearNearestToll: true,
        clearReliableHeading: true,
        clearNearestCamera: true,
        clearLastAlert: true,
        clearDismissedCamera: true,
        clearErrorMessage: true,
        clearSimulation: true,
        clearCurrentPoint: true,
        clearVisualAlertPulse: true,
      ),
    );
  }

  Future<void> dismissCurrentCameraAlert() async {
    final current = state.asData?.value ?? await build();
    final cameraId = current.nearestCamera?.camera.id;
    if (cameraId == null) {
      return;
    }
    state = AsyncData(
      current.copyWith(
        dismissedCameraId: cameraId,
        clearVisualAlertPulse: true,
      ),
    );
    await _invalidateFeedback();
  }

  Future<void> dismissCurrentToll() async {
    final current = state.asData?.value;
    if (current == null || current.nearestToll == null) return;
    _tollSession.dismissCurrent();
    state = AsyncData(
      current.copyWith(clearNearestToll: true, clearVisualAlertPulse: true),
    );
    if (_feedbackTarget?.startsWith('toll:') == true) {
      await _invalidateFeedback();
    }
  }

  Future<void> savePreferences(DrivingPreferences preferences) async {
    final storage = ref.read(appPreferencesProvider);
    final current = state.asData?.value ?? await build();
    if (_shouldResetAlertEngine(current.preferences, preferences, current)) {
      _alertEngine = _alertEngineFor(preferences);
    }
    if (!preferences.tollAlertsEnabled) _tollSession.disable();
    state = AsyncData(
      current.copyWith(
        preferences: preferences,
        clearNearestToll: !preferences.tollAlertsEnabled,
        clearVisualAlertPulse: !preferences.visualAlertsEnabled,
      ),
    );
    if (current.preferences.tollAlertsEnabled !=
            preferences.tollAlertsEnabled ||
        current.preferences.voiceEnabled != preferences.voiceEnabled ||
        current.preferences.soundEnabled != preferences.soundEnabled ||
        current.preferences.vibrationEnabled != preferences.vibrationEnabled ||
        current.preferences.cameraTargetingConeDegrees !=
            preferences.cameraTargetingConeDegrees) {
      await _invalidateFeedback();
    }
    if (preferences.tollAlertsEnabled &&
        (current.isActive || current.status == DrivingSessionStatus.starting) &&
        ref.mounted) {
      unawaited(_ensureTollData());
    }
    await saveDrivingPreferences(storage, preferences);
  }

  void _enqueuePoint(DrivingPoint point, int sessionSerial) {
    _pointProcessing = _pointProcessing
        .catchError((_) {})
        .then((_) => _onPoint(point, sessionSerial))
        .catchError((_) {
          if (!_isActiveSession(sessionSerial)) {
            return;
          }
          final latest = state.asData?.value;
          if (latest == null) {
            return;
          }
          unawaited(
            _setStopped(
              latest,
              DrivingSessionStatus.locationUnavailable,
              'No se pudo leer la ubicación en tiempo real.',
            ),
          );
        });
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
    final pack = _sessionPack;
    if (pack == null) return;
    if (!_isActiveSession(sessionSerial)) {
      return;
    }
    final alertEngine = _alertEngine ??= _alertEngineFor(current.preferences);
    if (point.accuracyMeters > 60) {
      unawaited(_invalidateFeedback());
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
          clearNearestToll: true,
          clearReliableHeading: true,
          clearLastAlert: !keepLastAlert,
          clearDismissedCamera: !keepDismissal,
          clearErrorMessage: true,
          clearVisualAlertPulse: true,
        ),
      );
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
          clearNearestToll: true,
          clearReliableHeading: true,
          clearLastAlert: current.lastAlert == null,
          clearDismissedCamera: !keepDismissal,
          clearErrorMessage: true,
          clearVisualAlertPulse: true,
        ),
      );
      return;
    }

    final match = matchNearestCamera(
      current: point,
      previous: _previousPoint,
      cameras: pack.cameras,
      targetingConeDegrees: current.preferences.cameraTargetingConeDegrees,
    );
    final reliableHeading = reliableDrivingCourseDegrees(
      current: point,
      previous: _previousPoint,
    );
    final sameActiveEpisode =
        match != null &&
        alertEngine.hasActiveEpisode(match.camera.id, point.recordedAt);
    final episodeKey = match == null
        ? current.cameraEpisodeKey
        : _episodeKeyFor(match.camera.id, sameActiveEpisode);
    final alert = alertEngine.evaluate(
      match: match,
      speedKmh: point.speedKmh,
      now: point.recordedAt,
    );
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
      reliableHeadingDegrees: reliableHeading,
      clearReliableHeading: reliableHeading == null,
    );
    final tollThreshold = current.preferences.tollAlertsEnabled
        ? _tollSession.evaluate(
            current: point,
            previous: _previousPoint,
            tolls: _tolls,
            targetingConeDegrees:
                current.preferences.cameraTargetingConeDegrees,
            thresholdsMeters: current.preferences.activeThresholdsMeters,
            cameraHasPriority: nextState.showCameraAlertPanel,
          )
        : null;
    _previousPoint = point;
    final toll = current.preferences.tollAlertsEnabled
        ? _tollSession.nearestToll
        : null;
    var updated = nextState.copyWith(
      nearestToll: toll,
      referenceCharge: _tollCharges[toll?.toll.id],
      tollEpisodeKey: _tollSession.episodeKey == null
          ? null
          : '$_mapSessionId:toll:${_tollSession.episodeKey}',
      clearNearestToll: toll == null,
      clearVisualAlertPulse: !nextState.showCameraAlertPanel && toll == null,
    );
    final target = updated.showCameraAlertPanel && match!.approaching
        ? 'camera:${updated.cameraEpisodeKey}'
        : updated.showTollAlertPanel && toll!.approaching
        ? 'toll:${updated.tollEpisodeKey}'
        : null;
    final pendingStop = target != _feedbackTarget
        ? _invalidateFeedback()
        : _feedbackStop;
    _feedbackTarget = target;
    final message = visibleAlert != null
        ? _voiceMessage(visibleAlert)
        : tollThreshold != null && updated.showTollAlertPanel
        ? 'Peaje ${toll!.toll.name} a $tollThreshold metros.'
        : null;
    if (updated.preferences.visualAlertsEnabled &&
        message != null &&
        target != null) {
      _visualPulseSerial += 1;
      updated = updated.copyWith(
        visualAlertPulseKey: '$target:${_visualPulseSerial.toString()}',
      );
    }
    state = AsyncData(updated);
    if (message != null && target != null) {
      final feedbackSerial = ++_feedbackSerial;
      // Native speech completion must not block GPS or priority changes.
      unawaited(
        _notifyMessage(message, sessionSerial, feedbackSerial, pendingStop),
      );
    }
  }

  bool _isActiveSession(int sessionSerial) {
    return ref.mounted &&
        sessionSerial == _sessionSerial &&
        state.asData?.value.status == DrivingSessionStatus.active;
  }

  bool _isCurrentStart(int sessionSerial) {
    return ref.mounted &&
        sessionSerial == _sessionSerial &&
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
    return '$_mapSessionId:camera:$cameraId:$_cameraEpisodeSerial';
  }

  Future<void> _notifyMessage(
    String message,
    int sessionSerial,
    int feedbackSerial,
    Future<void> pendingStop,
  ) async {
    bool valid() =>
        _isActiveSession(sessionSerial) && feedbackSerial == _feedbackSerial;
    try {
      await pendingStop;
      if (!valid()) return;
      final feedback = ref.read(drivingFeedbackGatewayProvider);
      if (state.asData!.value.preferences.voiceEnabled) {
        await feedback.speak(message);
      }
      if (!valid()) return;
      if (state.asData!.value.preferences.soundEnabled) {
        await feedback.playSound();
      }
      if (!valid()) return;
      if (state.asData!.value.preferences.vibrationEnabled) {
        await feedback.vibrate();
      }
    } catch (_) {
      if (valid()) _reportFeedbackError();
    }
  }

  Future<void> _invalidateFeedback() {
    _feedbackSerial++;
    final hadTarget = _feedbackTarget != null;
    _feedbackTarget = null;
    if (!hadTarget || !ref.mounted) return _feedbackStop;
    final feedback = ref.read(drivingFeedbackGatewayProvider);
    _feedbackStop = _feedbackStop
        .then((_) => feedback.stopOngoingFeedback())
        .catchError((Object _) {
          if (ref.mounted) _reportFeedbackError();
        });
    return _feedbackStop;
  }

  void _reportFeedbackError() {
    final current = state.asData?.value;
    if (current != null) {
      state = AsyncData(
        current.copyWith(
          errorMessage:
              'No se pudo reproducir o detener el aviso de conducción.',
        ),
      );
    }
  }

  Future<void> _ensureTollData() {
    final pending = _tollLoading;
    if (pending != null) return pending;
    // Retry failed providers only at a session/setting boundary, never per GPS fix.
    final inventory = ref.read(tripTollInventoryProvider);
    if (inventory.hasError && !inventory.isLoading) {
      ref.invalidate(tripTollInventoryProvider);
    }
    final tariffs = ref.read(tripTollTariffCatalogProvider);
    if (tariffs.hasError && !tariffs.isLoading) {
      ref.invalidate(tripTollTariffCatalogProvider);
    }
    return _tollLoading = _loadTollData(_tollLoadGeneration);
  }

  Future<void> _loadTollData(int generation) async {
    TollInventoryDataset? inventory;
    TollTariffCatalog? catalog;
    final errors = <String>[];
    await Future.wait([
      ref
          .read(tripTollInventoryProvider.future)
          .then((value) {
            inventory = value;
          })
          .catchError((Object _) {
            errors.add('Inventario de peajes no disponible.');
          }),
      ref
          .read(tripTollTariffCatalogProvider.future)
          .then((value) {
            catalog = value;
          })
          .catchError((Object _) {
            errors.add('Tarifas de referencia no disponibles.');
          }),
    ]);
    if (!ref.mounted || generation != _tollLoadGeneration) return;
    _tolls = inventory?.records ?? const [];
    _tollCharges = catalog == null
        ? {
            for (final toll in _tolls)
              toll.id: LocalTollPricingCharge(
                stationId: toll.id,
                name: toll.name,
                categoryCode: 'I',
                amountMinor: null,
                publicationControl: null,
                sourceType: null,
                sourceDate: null,
                sourceUrl: null,
                pendingReason: 'Tarifa de referencia no disponible',
              ),
          }
        : {
            for (final charge in priceExplicitTollPassages(
              catalog: catalog!,
              passages: _tolls,
              operatorCategoryCode: 'I',
            ).charges)
              charge.stationId: _referenceCharge(charge),
          };
    _tollLoadError = errors.isEmpty ? null : errors.join(' ');
    final current = state.asData?.value;
    if (current != null) {
      state = AsyncData(
        current.copyWith(
          tollDataError: _tollLoadError,
          clearTollDataError: _tollLoadError == null,
        ),
      );
    }
  }

  LocalTollPricingCharge _referenceCharge(LocalTollPricingCharge charge) {
    final station = charge.station;
    final rate = station?.categoryI;
    final blocked = [station?.publicationControl, rate?.publicationControl].any(
      (control) =>
          control?.startsWith('BLOQUEADO_') == true ||
          control == 'EXCLUIR_ESTACION_RETIRADA',
    );
    if (!blocked && rate != null) return charge;
    return LocalTollPricingCharge(
      stationId: charge.stationId,
      name: charge.name,
      categoryCode: 'I',
      amountMinor: null,
      nominalMinor: null,
      station: station,
      publicationControl: charge.publicationControl,
      sourceType: charge.sourceType,
      sourceDate: charge.sourceDate,
      sourceUrl: charge.sourceUrl,
      pendingReason: blocked
          ? 'Importe bloqueado por revisión de datos'
          : 'Tarifa de referencia de Categoría I no disponible',
    );
  }

  Future<void> _setStopped(
    DrivingState previous,
    DrivingSessionStatus status,
    String message,
  ) async {
    _sessionSerial += 1;
    final sessionSerial = _sessionSerial;
    _pointProcessing = Future<void>.value();
    await _cancelSubscription();
    await _stopNativeSessionCleanup();
    if (!ref.mounted || sessionSerial != _sessionSerial) return;
    state = AsyncData(
      previous.copyWith(
        status: status,
        errorMessage: message,
        clearNearestToll: true,
        clearReliableHeading: true,
        clearNearestCamera: true,
        clearLastAlert: true,
        clearDismissedCamera: true,
        clearSimulation: true,
        clearCurrentPoint: true,
        clearVisualAlertPulse: true,
      ),
    );
  }

  Future<void> _stopNativeSessionCleanup({
    DrivingFeedbackGateway? gateway,
    bool onlyWhenInactive = false,
  }) async {
    bool canCleanUp() {
      if (!onlyWhenInactive) return true;
      if (!ref.mounted) return false;
      final status = state.asData?.value.status;
      return status != DrivingSessionStatus.starting &&
          status != DrivingSessionStatus.active;
    }

    if (!canCleanUp()) return;
    final DrivingFeedbackGateway feedback =
        gateway ?? ref.read(drivingFeedbackGatewayProvider);
    try {
      await feedback.stopOngoingFeedback();
    } catch (_) {
      // Cleanup must be idempotent and must not crash the UI.
    }
    if (!canCleanUp()) return;
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
    final subscription = _subscription;
    _subscription = null;
    _previousPoint = null;
    _alertEngine = null;
    _activeCameraId = null;
    _sessionPack = null;
    _tollSession = TollAlertSession();
    _feedbackSerial++;
    _feedbackTarget = null;
    await subscription?.cancel();
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
    return 'Cámara a ${alert.thresholdMeters} metros. '
        'Respeta la señalización de la vía.';
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
      DrivingSimulationScenario.niquiaToEstrella ||
      DrivingSimulationScenario.cocorna ||
      DrivingSimulationScenario.estrellaToNiquia => null,
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
      DrivingSimulationScenario.niquiaToEstrella ||
      DrivingSimulationScenario.cocorna ||
      DrivingSimulationScenario.estrellaToNiquia => throw StateError(
        'Regional demo uses road geometry.',
      ),
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

  Stream<DrivingPoint> _simulatedTollStream(TollInventoryRecord toll) {
    final now = DateTime.now().toUtc();
    const south = [650.0, 490.0, 290.0, 90.0, 40.0, -60.0, -180.0, -750.0];
    return Stream<DrivingPoint>.periodic(
      const Duration(milliseconds: 1000),
      (index) => DrivingPoint(
        latitude: toll.latitude - south[index] / 111320,
        longitude: toll.longitude,
        accuracyMeters: 12,
        speedKmh: 50,
        headingDegrees: 0,
        recordedAt: now.add(Duration(seconds: index * 20)),
      ),
    ).take(south.length);
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
