// Physical QA entrypoint only. Never import this file from lib/.
// Build: flutter build apk --profile --flavor dev -t test/performance/driving_profile.dart
// Private output: getApplicationSupportDirectory()/driving_profile/summary.json.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/theme/app_theme.dart';
import 'package:picoradar/core/storage/app_preferences.dart';
import 'package:picoradar/features/driving/application/driving_controller.dart';
import 'package:picoradar/features/driving/data/camera_pack_loader.dart';
import 'package:picoradar/features/driving/data/driving_preferences.dart';
import 'package:picoradar/features/driving/domain/camera_matcher.dart';
import 'package:picoradar/features/driving/platform/driving_location_gateway.dart';
import 'package:picoradar/features/driving/presentation/driving_map_episode.dart';
import 'package:picoradar/features/driving/presentation/driving_screen.dart';
import 'package:picoradar/features/location/platform/device_location_gateway.dart';
import 'package:picoradar/features/trip/data/toll_inventory.dart';
import 'package:picoradar/features/trip/data/toll_tariff_catalog.dart';

const _sessionSeconds = 60;
const _firstLoadSeconds = 5;
const _frameBudgetUs = 16700;
const _operationTimeout = Duration(seconds: 15);
const _context =
    'test-only physical profile harness; simulated local points; '
    'real bundled catalogs; not production release or road QA';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  if (!kProfileMode) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'QA PROFILE · SIMULADO\nRequiere compilación --profile',
            ),
          ),
        ),
      ),
    );
    return;
  }
  final replay = _ReplayLocation();
  final status = ValueNotifier<String>('QA PROFILE · SIMULADO · Preparando');
  final container = ProviderContainer(
    overrides: [
      appPreferencesProvider.overrideWithValue(_MemoryPreferences()),
      // Bypass the on-device database/snapshot store, not the real asset parser.
      tripTollInventoryProvider.overrideWith(
        (ref) async => TollInventoryDataset.fromJsonString(
          await rootBundle.loadString(bundledTollInventoryAsset),
        ),
      ),
      tripTollTariffCatalogProvider.overrideWith(
        (ref) => loadTollTariffCatalog(rootBundle),
      ),
      drivingLocationGatewayProvider.overrideWithValue(replay),
      drivingControllerProvider.overrideWith(() => _ProfileController(replay)),
    ],
  );
  final runner = _ProfileRunner(container, replay, status);
  FlutterError.onError = (_) {
    runner.frameworkErrors++;
  };
  PlatformDispatcher.instance.onError = (_, _) {
    runner.asyncErrors++;
    return true;
  };
  WidgetsBinding.instance.addTimingsCallback(runner.onTimings);
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildPicoRadarTheme(),
        home: Stack(
          children: [
            const AbsorbPointer(child: DrivingScreen()),
            // This QA label is an overlay, so the production viewport is unchanged.
            Positioned(
              left: 8,
              right: 8,
              bottom: 4,
              child: SafeArea(
                top: false,
                child: IgnorePointer(
                  child: ValueListenableBuilder<String>(
                    valueListenable: status,
                    builder: (context, value, _) => ColoredBox(
                      color: Colors.black87,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          value,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(runner.run()));
}

class _ProfileController extends DrivingController {
  _ProfileController(this.replay);
  final _ReplayLocation replay;

  @override
  Future<DrivingState> build() async =>
      (await super.build()).copyWith(simulationName: 'QA PROFILE · SIMULADO');

  @override
  Future<void> start({
    bool simulated = false,
    DrivingSimulationScenario? simulationScenario,
  }) async {
    // The normal controller still enforces its original debug simulation guard.
    // Profile uses a local gateway injection, never its simulation entrypoint.
    if (simulated || simulationScenario != null || !replay.configured) return;
    await super.start();
    if (!ref.mounted || state.asData?.value.isActive != true) return;
    state = AsyncData(
      state.asData!.value.copyWith(simulationName: replay.label),
    );
    replay.begin();
  }
}

class _ReplayLocation implements DrivingLocationGateway {
  StreamController<DrivingPoint>? _stream;
  Timer? _timer;
  double _latitude = 0;
  double _longitude = 0;
  var _tick = 0;
  var emitted = 0;
  var configured = false;
  String label = 'QA PROFILE · SIMULADO';

  void configure(double latitude, double longitude, String name) {
    _latitude = latitude;
    _longitude = longitude;
    label = 'QA PROFILE · SIMULADO · $name';
    emitted = 0;
    configured = true;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<DeviceLocationPermission> checkPermission() async =>
      DeviceLocationPermission.granted;
  @override
  Future<DeviceLocationPermission> requestPermission() async =>
      DeviceLocationPermission.granted;

  @override
  Stream<DrivingPoint> positionStream() {
    _timer?.cancel();
    _tick = 0;
    final stream = StreamController<DrivingPoint>();
    _stream = stream;
    stream.onCancel = () {
      _timer?.cancel();
      _timer = null;
      if (identical(_stream, stream)) _stream = null;
      unawaited(stream.close());
    };
    return stream.stream;
  }

  void begin() {
    if (_timer != null) return;
    _emit();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _emit());
  }

  void _emit() {
    final stream = _stream;
    if (stream == null || stream.isClosed) return;
    // One synthetic straight approach, held within awareness for the 60 s run.
    // No list of positions or route history is retained.
    final southMeters = (580.0 - _tick * 8.5).clamp(40.0, 580.0);
    _tick++;
    emitted++;
    stream.add(
      DrivingPoint(
        latitude: _latitude - southMeters / 111320,
        longitude: _longitude,
        accuracyMeters: 12,
        speedKmh: 30.6,
        headingDegrees: 0,
        recordedAt: DateTime.now().toUtc(),
      ),
    );
  }
}

class _ProfileRunner {
  _ProfileRunner(this.container, this.replay, this.status);
  final ProviderContainer container;
  final _ReplayLocation replay;
  final ValueNotifier<String> status;
  final _bootstrap = _FrameWindow(
    'bootstrap',
    DateTime.now().microsecondsSinceEpoch,
  );
  final List<_FrameWindow> _sessions = [];
  int frameworkErrors = 0;
  int asyncErrors = 0;
  int interruptedSessions = 0;
  Directory? _output;
  DrivingController get controller =>
      container.read(drivingControllerProvider.notifier);
  DrivingState? get current =>
      container.read(drivingControllerProvider).asData?.value;

  void onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      // Wall timestamps associate delayed batches with the original session,
      // not whichever session is active when the callback eventually arrives.
      final wall = timing.timestampInMicroseconds(
        FramePhase.rasterFinishWallTime,
      );
      for (final window in [_bootstrap, ..._sessions]) {
        if (wall >= window.startUs &&
            (window.endUs == null || wall < window.endUs!)) {
          window.add(timing, wall);
          break;
        }
      }
    }
  }

  Future<void> run() async {
    String outcome = 'complete';
    Map<String, Object?>? memory;
    try {
      final root = await getApplicationSupportDirectory().timeout(
        _operationTimeout,
      );
      _output = await Directory('${root.path}/driving_profile')
          .create(recursive: true)
          .timeout(_operationTimeout);
      // Replace the readiness marker immediately so a prior run cannot be
      // mistaken for completion of this run.
      await _write('summary', {'status': 'running', 'jsonReady': false});
      await container
          .read(drivingControllerProvider.future)
          .timeout(_operationTimeout);
      final cameras = await container
          .read(cameraPackProvider.future)
          .timeout(_operationTimeout);
      final inventory = await container
          .read(tripTollInventoryProvider.future)
          .timeout(_operationTimeout);
      await container
          .read(tripTollTariffCatalogProvider.future)
          .timeout(_operationTimeout);
      final camera = cameras.cameras.first;
      final toll = inventory.records.singleWhere(
        (toll) => toll.id == 'INV-COCORNA-6A6F1282D1',
      );
      _bootstrap.endUs = DateTime.now().microsecondsSinceEpoch;
      _bootstrap.completed = true;

      await _session(
        'camera_map',
        'Cámara · Mapa',
        camera.latitude,
        camera.longitude,
        CameraVisualizationMode.map,
        90,
        false,
      );
      await _session(
        'camera_radar_360',
        'Cámara · Radar 360',
        camera.latitude,
        camera.longitude,
        CameraVisualizationMode.radar,
        360,
        false,
      );
      await _session(
        'cocorna_map',
        'Cocorná · Mapa',
        toll.latitude,
        toll.longitude,
        CameraVisualizationMode.map,
        90,
        true,
      );

      status.value = 'QA PROFILE · SIMULADO · Memoria: 10 ciclos';
      final baseline = ProcessInfo.currentRss;
      final samples = <int>[];
      for (var cycle = 0; cycle < 10; cycle++) {
        final withToll = cycle % 3 == 2;
        final radar = cycle % 3 == 1;
        replay.configure(
          withToll ? toll.latitude : camera.latitude,
          withToll ? toll.longitude : camera.longitude,
          'Memoria ${cycle + 1}/10',
        );
        await controller.savePreferences(
          defaultDrivingPreferences.copyWith(
            cameraVisualizationMode: radar
                ? CameraVisualizationMode.radar
                : CameraVisualizationMode.map,
            cameraTargetingConeDegrees: radar ? 360 : 90,
            tollAlertsEnabled: withToll,
            voiceEnabled: false,
            soundEnabled: false,
            vibrationEnabled: false,
          ),
        );
        await controller.start().timeout(_operationTimeout);
        await Future<void>.delayed(const Duration(seconds: 2));
        if (current?.isActive != true) {
          throw StateError('qa_session_interrupted');
        }
        await controller.stop().timeout(_operationTimeout);
        await Future<void>.delayed(const Duration(seconds: 1));
        if (current?.currentPoint != null ||
            current?.nearestCamera != null ||
            current?.nearestToll != null) {
          throw StateError('qa_cleanup_incomplete');
        }
        samples.add(ProcessInfo.currentRss);
      }
      memory = {
        'cyclesCompleted': samples.length,
        'baselineRssBytes': baseline,
        'afterCycleRssBytes': samples,
        'finalRssBytes': samples.last,
        'deltaRssBytes': samples.last - baseline,
        'forcedGc': false,
        'cycleModes': 'camera map, camera radar 360, toll map, repeated',
        'scope': 'process RSS after warm sessions, 2 s active + 1 s idle per cycle; not Dart heap or leak proof',
      };
    } catch (_) {
      outcome = 'incomplete';
      // Never serialize exception text, request URLs, coordinates or stacks.
    } finally {
      try {
        await controller.stop().timeout(_operationTimeout);
      } catch (_) {
        outcome = 'cleanup_failed';
      }
      replay.configured = false;
      _bootstrap.endUs ??= DateTime.now().microsecondsSinceEpoch;
      for (final window in _sessions) {
        window.endUs ??= DateTime.now().microsecondsSinceEpoch;
      }
      // Flutter can batch timings for about one second in profile builds.
      await Future<void>.delayed(const Duration(seconds: 2));
      WidgetsBinding.instance.removeTimingsCallback(onTimings);
      if (frameworkErrors + asyncErrors > 0) outcome = 'runtime_errors';
      if (outcome == 'complete' &&
          _sessions.any(
            (session) =>
                session.all.count == 0 ||
                (session.name == 'cocorna_map'
                        ? session.tollPanelSamples
                        : session.cameraPanelSamples) ==
                    0,
          )) {
        outcome = 'missing_visual_evidence';
      }
      try {
        await _write('bootstrap', _bootstrap.toJson());
        for (final session in _sessions) {
          await _write(session.name, session.toJson());
        }
        if (memory != null) await _write('memory', memory);
        await _write('summary', {
          'status': outcome,
          'jsonReady': true,
          'idle': current?.status == DrivingSessionStatus.idle,
          'sessionsCompleted': _sessions.where((s) => s.completed).length,
          'sessionDurationSeconds': _sessionSeconds,
          'firstLoadSecondsPerSession': _firstLoadSeconds,
          'frameBudgetMicroseconds': _frameBudgetUs,
          'frameworkErrorCount': frameworkErrors,
          'asyncErrorCount': asyncErrors,
          'interruptedSessionCount': interruptedSessions,
          'memoryCyclesCompleted': memory?['cyclesCompleted'] ?? 0,
          'mapSessionsWithReadySamples': _sessions
              .where((s) => s.mapReadySamples > 0)
              .length,
          'sessions': [for (final session in _sessions) session.toJson()],
        });
        status.value = 'QA PROFILE · SIMULADO · JSON listo · $outcome';
        debugPrint(
          'PICORADAR_QA_PROFILE_JSON_READY ${_output!.path}/summary.json',
        );
      } catch (_) {
        status.value = 'QA PROFILE · SIMULADO · Error al guardar JSON';
        debugPrint('PICORADAR_QA_PROFILE_WRITE_FAILED');
      }
    }
  }

  Future<void> _session(
    String id,
    String label,
    double latitude,
    double longitude,
    CameraVisualizationMode mode,
    int cone,
    bool tolls,
  ) async {
    status.value = 'QA PROFILE · SIMULADO · $label · 60 s';
    replay.configure(latitude, longitude, label);
    await controller.savePreferences(
      defaultDrivingPreferences.copyWith(
        cameraVisualizationMode: mode,
        cameraTargetingConeDegrees: cone,
        tollAlertsEnabled: tolls,
        voiceEnabled: false,
        soundEnabled: false,
        vibrationEnabled: false,
      ),
    );
    final session = _FrameWindow(id, DateTime.now().microsecondsSinceEpoch);
    _sessions.add(session);
    final elapsed = Stopwatch()..start();
    await controller.start().timeout(_operationTimeout);
    while (elapsed.elapsed < const Duration(seconds: _sessionSeconds)) {
      await Future<void>.delayed(const Duration(seconds: 1));
      final value = current;
      if (value?.isActive != true) {
        interruptedSessions++;
        throw StateError('qa_session_interrupted');
      }
      session.stateSamples++;
      if (value!.showCameraAlertPanel) session.cameraPanelSamples++;
      if (value.showTollAlertPanel) session.tollPanelSamples++;
      if (mode == CameraVisualizationMode.map) {
        final key = value.showCameraAlertPanel
            ? value.cameraEpisodeKey
            : value.tollEpisodeKey;
        switch (key == null ? null : CameraMapEpisodeCache.read(key)) {
          case CameraMapEpisodeViewState.ready:
            session.mapReadySamples++;
          case CameraMapEpisodeViewState.fallback:
            session.mapFallbackSamples++;
          case CameraMapEpisodeViewState.pending:
            session.mapPendingSamples++;
          case null:
            session.noMapSamples++;
        }
      }
    }
    session.endUs = DateTime.now().microsecondsSinceEpoch;
    session.pointsEmitted = replay.emitted;
    session.completed = true;
    await controller.stop().timeout(_operationTimeout);
    await Future<void>.delayed(const Duration(seconds: 2));
    await _write(id, session.toJson());
  }

  Future<void> _write(String name, Map<String, Object?> data) async {
    final directory = _output;
    if (directory == null) throw StateError('qa_output_unavailable');
    await File('${directory.path}/$name.json')
        .writeAsString(
          jsonEncode({
            'schemaVersion': 1,
            'harnessContext': _context,
            'profileMode': kProfileMode,
            'simulated': true,
            'deviceGps': false,
            'audioEnabled': false,
            ...data,
          }),
          flush: true,
        )
        .timeout(_operationTimeout);
  }
}

class _FrameWindow {
  _FrameWindow(this.name, this.startUs);
  final String name;
  final int startUs;
  int? endUs;
  bool completed = false;
  final all = _FrameCounts();
  final firstLoad = _FrameCounts();
  final steady = _FrameCounts();
  int pointsEmitted = 0;
  int stateSamples = 0;
  int cameraPanelSamples = 0;
  int tollPanelSamples = 0;
  int mapReadySamples = 0;
  int mapFallbackSamples = 0;
  int mapPendingSamples = 0;
  int noMapSamples = 0;

  void add(FrameTiming timing, int wall) {
    all.add(timing);
    (wall - startUs < _firstLoadSeconds * 1000000 ? firstLoad : steady).add(
      timing,
    );
  }

  Map<String, Object?> toJson() => {
    'session': name,
    'completed': completed,
    'elapsedMilliseconds': endUs == null ? null : (endUs! - startUs) ~/ 1000,
    'allFrames': all.toJson(),
    'firstLoadFrames': firstLoad.toJson(),
    'steadyFrames': steady.toJson(),
    'pointsEmitted': pointsEmitted,
    'stateSamples': stateSamples,
    'cameraPanelSamples': cameraPanelSamples,
    'tollPanelSamples': tollPanelSamples,
    'mapReadySamples': mapReadySamples,
    'mapFallbackSamples': mapFallbackSamples,
    'mapPendingSamples': mapPendingSamples,
    'noMapSamples': noMapSamples,
    'mapReadySampleFraction': name == 'camera_radar_360' || stateSamples == 0
        ? null
        : mapReadySamples / stateSamples,
  };
}

class _FrameCounts {
  int count = 0;
  int uiWithin = 0;
  int rasterWithin = 0;
  int bothWithin = 0;
  int totalUiUs = 0;
  int totalRasterUs = 0;
  int maxUiUs = 0;
  int maxRasterUs = 0;
  void add(FrameTiming timing) {
    final ui = timing.buildDuration.inMicroseconds;
    final raster = timing.rasterDuration.inMicroseconds;
    count++;
    if (ui <= _frameBudgetUs) uiWithin++;
    if (raster <= _frameBudgetUs) rasterWithin++;
    if (ui <= _frameBudgetUs && raster <= _frameBudgetUs) bothWithin++;
    totalUiUs += ui;
    totalRasterUs += raster;
    if (ui > maxUiUs) maxUiUs = ui;
    if (raster > maxRasterUs) maxRasterUs = raster;
  }

  Map<String, Object?> toJson() => {
    'count': count,
    'uiWithinBudgetCount': uiWithin,
    'rasterWithinBudgetCount': rasterWithin,
    'bothWithinBudgetCount': bothWithin,
    'uiWithinBudgetFraction': count == 0 ? null : uiWithin / count,
    'rasterWithinBudgetFraction': count == 0 ? null : rasterWithin / count,
    'bothWithinBudgetFraction': count == 0 ? null : bothWithin / count,
    'meanUiMicroseconds': count == 0 ? null : totalUiUs / count,
    'meanRasterMicroseconds': count == 0 ? null : totalRasterUs / count,
    'maxUiMicroseconds': count == 0 ? null : maxUiUs,
    'maxRasterMicroseconds': count == 0 ? null : maxRasterUs,
  };
}

class _MemoryPreferences extends AppPreferences {
  final Map<String, Object> _values = {};
  @override
  Future<bool?> getBool(String key) async => _values[key] as bool?;
  @override
  Future<int?> getInt(String key) async => _values[key] as int?;
  @override
  Future<String?> getString(String key) async => _values[key] as String?;
  @override
  Future<void> setBool(String key, bool value) async {
    _values[key] = value;
  }

  @override
  Future<void> setInt(String key, int value) async {
    _values[key] = value;
  }

  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }
}
