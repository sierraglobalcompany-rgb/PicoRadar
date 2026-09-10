import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/theme/app_tokens.dart';
import 'package:picoradar/features/driving/application/driving_controller.dart';
import 'package:picoradar/features/driving/data/camera_pack_loader.dart';
import 'package:picoradar/features/driving/data/driving_preferences.dart';
import 'package:picoradar/features/driving/domain/camera_matcher.dart';
import 'package:picoradar/features/driving/domain/traffic_camera.dart';
import 'package:picoradar/features/driving/platform/driving_feedback_gateway.dart';
import 'package:picoradar/features/driving/platform/driving_location_gateway.dart';
import 'package:picoradar/features/driving/presentation/driving_map_episode.dart';
import 'package:picoradar/features/driving/presentation/driving_proximity_map.dart'
    show drivingViewportTiles;
import 'package:picoradar/features/driving/presentation/driving_screen.dart';
import 'package:picoradar/features/location/platform/device_location_gateway.dart';
import 'package:picoradar/features/vehicle_status/platform/external_launcher.dart';

import '../../../test_app_harness.dart';
import '../../home/presentation/v01b_test_font.dart';

void main() {
  setUpAll(() async {
    await loadV01bTestFont();
    final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
    final iconFont = Directory('${artifacts.path}/material_fonts')
        .listSync()
        .whereType<File>()
        .singleWhere(
          (file) =>
              file.path.toLowerCase().endsWith('materialicons-regular.otf'),
        );
    final icons = FontLoader('MaterialIcons')
      ..addFont(iconFont.readAsBytes().then(ByteData.sublistView));
    await icons.load();
  });
  test('live GPS stream error publishes location-unavailable state', () async {
    final stages = <String>[];
    final gateway = _ControlledErrorGateway(stages);
    final feedback = _ObservedFeedbackGateway(stages);
    final container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(MemoryPreferences()),
        cameraPackProvider.overrideWith((ref) async => _emptyPack()),
        drivingLocationGatewayProvider.overrideWithValue(gateway),
        drivingFeedbackGatewayProvider.overrideWithValue(feedback),
      ],
    );
    ProviderSubscription<AsyncValue<DrivingState>>? subscription;

    try {
      await container.read(drivingControllerProvider.future);
      final unavailable = Completer<DrivingState>();
      subscription = container.listen<AsyncValue<DrivingState>>(
        drivingControllerProvider,
        (_, next) {
          final value = next.asData?.value;
          if (value != null) {
            stages.add('state:${value.status.name}:${value.errorMessage}');
          }
          if (value?.status == DrivingSessionStatus.locationUnavailable &&
              !unavailable.isCompleted) {
            unavailable.complete(value);
          }
        },
      );

      await container.read(drivingControllerProvider.notifier).start();
      await gateway.whenListening;
      expect(
        container.read(drivingControllerProvider).requireValue.status,
        DrivingSessionStatus.active,
      );

      gateway.emitError();
      final observed = await unavailable.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          final current = container.read(drivingControllerProvider);
          throw TestFailure(
            'Timed out waiting for locationUnavailable. '
            'provider=$current; stages=$stages',
          );
        },
      );

      expect(observed.status, DrivingSessionStatus.locationUnavailable);
      expect(
        observed.errorMessage,
        'No se pudo leer la ubicación en tiempo real.',
      );
      expect(stages, contains('stream:onCancel'));
      expect(stages, contains('feedback:stop'));
      expect(stages, contains('feedback:screen:false'));
    } finally {
      subscription?.close();
      container.dispose();
      await gateway.close();
    }
  });

  setUp(CameraMapEpisodeCache.resetForTesting);

  testWidgets('shows the driving start surface without requesting GPS', (
    tester,
  ) async {
    final gateway = _IdleGateway();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _emptyPack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(
            _NoopDrivingFeedbackGateway(),
          ),
          drivingMapConfigProvider.overrideWithValue(
            _testMapConfig(tileProvider: _OnePixelTileProvider()),
          ),
        ],
        child: const MaterialApp(home: DrivingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ready-speed-coverage')), findsOneWidget);
    expect(find.textContaining('cámaras disponibles'), findsOneWidget);
    expect(find.textContaining('fuente oficial'), findsOneWidget);
    expect(find.textContaining('Base de cámaras actualizada'), findsOneWidget);
    expect(find.byKey(const ValueKey('start-driving')), findsOneWidget);
    expect(find.byKey(const ValueKey('debug-driving-route')), findsNothing);
    expect(
      find.byKey(const ValueKey('debug-driving-route-gps-weak')),
      findsNothing,
    );
    expect(find.textContaining('2026-08-31T'), findsNothing);
    expect(find.textContaining('No se guarda recorrido'), findsOneWidget);
    expect(gateway.requestPermissionCalls, 0);
  });

  testWidgets('idle legal notice opens and closes without starting driving', (
    tester,
  ) async {
    final gateway = _IdleGateway();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _emptyPack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(
            _NoopDrivingFeedbackGateway(),
          ),
        ],
        child: const MaterialApp(home: DrivingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('driving-legal-notice-action')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('driving-legal-notice-sheet')),
      findsOneWidget,
    );
    expect(
      find.textContaining('PicoRadar ofrece información de apoyo'),
      findsOneWidget,
    );
    expect(gateway.requestPermissionCalls, 0);

    await tester.tap(find.byKey(const ValueKey('driving-legal-notice-close')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('driving-legal-notice-sheet')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('start-driving')), findsOneWidget);
  });

  testWidgets('start button requests foreground GPS permission', (
    tester,
  ) async {
    final gateway = _IdleGateway();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _emptyPack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(
            _NoopDrivingFeedbackGateway(),
          ),
        ],
        child: const MaterialApp(home: DrivingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('start-driving')));
    await tester.pump();

    expect(gateway.requestPermissionCalls, 1);
    await tester.pumpAndSettle();
    expect(
      find.text('PicoRadar solo usa GPS mientras Conducir está activo.'),
      findsOneWidget,
    );
    expect(find.text('Sin cámara objetivo'), findsNothing);
  });

  testWidgets('GPS stream failure message remains visible', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          drivingControllerProvider.overrideWith(
            _LocationErrorDrivingController.new,
          ),
        ],
        child: const MaterialApp(home: DrivingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No se pudo leer la ubicación en tiempo real.'),
      findsOneWidget,
    );
    expect(find.text('Sin cámara objetivo'), findsNothing);
  });

  testWidgets(
    'settings expose camera visualization, cone, and alert controls',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPreferencesProvider.overrideWithValue(MemoryPreferences()),
            cameraPackProvider.overrideWith((ref) async => _emptyPack()),
            drivingLocationGatewayProvider.overrideWithValue(_IdleGateway()),
            drivingFeedbackGatewayProvider.overrideWithValue(
              _NoopDrivingFeedbackGateway(),
            ),
            drivingMapConfigProvider.overrideWithValue(
              _testMapConfig(tileProvider: _OnePixelTileProvider()),
            ),
          ],
          child: const MaterialApp(home: DrivingScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Alertas'));
      await tester.pumpAndSettle();

      expect(find.text('Visualización de cámara'), findsOneWidget);
      expect(find.text('Automático'), findsOneWidget);
      expect(find.text('Radar'), findsOneWidget);
      expect(find.text('Mapa'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('driving-visualization-auto')),
        findsOneWidget,
      );
      expect(find.text('Ángulo de detección'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('driving-cone-preview-90')),
        findsOneWidget,
      );
      expect(find.text('45°'), findsOneWidget);
      expect(find.text('90°'), findsOneWidget);
      expect(find.text('180°'), findsOneWidget);
      expect(find.text('360°'), findsOneWidget);
      for (final degrees in [45, 90, 180, 360]) {
        await tester.tap(find.text('$degrees°'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(ValueKey('driving-cone-preview-$degrees')),
          findsOneWidget,
        );
      }

      await tester.ensureVisible(find.text('Personalizado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Personalizado'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('custom-alert-500')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('custom-alert-500')), findsOneWidget);
      expect(find.byKey(const ValueKey('custom-alert-400')), findsOneWidget);
      expect(find.byKey(const ValueKey('custom-alert-300')), findsOneWidget);
      expect(find.byKey(const ValueKey('custom-alert-200')), findsOneWidget);
      expect(find.byKey(const ValueKey('custom-alert-100')), findsOneWidget);
      expect(find.byKey(const ValueKey('custom-alert-50')), findsOneWidget);
      expect(find.text('250 m'), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('driving-visual-alert-toggle')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Alerta visual'), findsOneWidget);
      expect(
        find.text('Ilumina suavemente el fondo al avisar de cámaras y peajes.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('driving-visual-alert-preview')),
        findsOneWidget,
      );
      expect(find.textContaining('Datos ANSV'), findsOneWidget);
    },
  );

  testWidgets('camera visualization preference persists from settings', (
    tester,
  ) async {
    final preferences = MemoryPreferences();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(preferences),
          cameraPackProvider.overrideWith((ref) async => _emptyPack()),
          drivingLocationGatewayProvider.overrideWithValue(_IdleGateway()),
          drivingFeedbackGatewayProvider.overrideWithValue(
            _NoopDrivingFeedbackGateway(),
          ),
        ],
        child: const MaterialApp(home: DrivingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Alertas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Radar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('180°'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('driving-visual-alert-toggle')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('driving-visual-alert-toggle')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Guardar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    final loaded = await loadDrivingPreferences(preferences);
    expect(loaded.cameraVisualizationMode, CameraVisualizationMode.radar);
    expect(loaded.cameraTargetingConeDegrees, 180);
    expect(loaded.visualAlertsEnabled, isTrue);
  });

  testWidgets('normal HUD is not mirrored', (tester) async {
    final gateway = _StreamingGateway();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(
            _NoopDrivingFeedbackGateway(),
          ),
        ],
        child: const MaterialApp(home: DrivingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('start-driving')));
    await tester.pump();
    await tester.tap(find.byTooltip('HUD'));
    await tester.pumpAndSettle();

    final transform = tester.widget<Transform>(
      find.byKey(const ValueKey('hud-content-transform')),
    );
    expect(transform.transform.storage[0], 1);
  });

  testWidgets('operating wording is shown for approved camera source', (
    tester,
  ) async {
    final gateway = _StreamingGateway();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(
            _NoopDrivingFeedbackGateway(),
          ),
          drivingMapConfigProvider.overrideWithValue(
            _testMapConfig(tileProvider: _OnePixelTileProvider()),
          ),
        ],
        child: const MaterialApp(home: DrivingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('start-driving')));
    await tester.pump();
    gateway.add(_point(latitude: 6.239, seconds: 0));
    await tester.pump();
    gateway.add(_point(latitude: 6.241, seconds: 20, speedKmh: 0));
    await _pumpMapFrames(tester);

    expect(find.text('Cámara de fotomulta'), findsOneWidget);
    expect(find.textContaining('Operando'), findsNothing);
    expect(
      find.byKey(const ValueKey('driving-camera-alert-panel')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('driving-mini-map')), findsOneWidget);
    expect(find.byKey(const ValueKey('driving-real-mini-map')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('driving-map-user-marker')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('driving-map-camera-marker')),
      findsOneWidget,
    );
    expect(find.textContaining('OpenStreetMap'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('driving-map-offline-fallback')),
      findsNothing,
    );
  });

  testWidgets('alert panel stays hidden without an active target camera', (
    tester,
  ) async {
    final gateway = _StreamingGateway();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(
            _NoopDrivingFeedbackGateway(),
          ),
        ],
        child: const MaterialApp(home: DrivingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('start-driving')));
    await tester.pump();
    gateway.add(_point(latitude: 6.239, seconds: 0));
    await tester.pump();

    expect(find.byKey(const ValueKey('driving-state-chip')), findsOneWidget);
    expect(find.text('Sin cámara objetivo'), findsNothing);
    expect(
      find.byKey(const ValueKey('driving-camera-alert-panel')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('driving-mini-map')), findsNothing);
  });

  testWidgets('low-confidence lateral target does not show the rich panel', (
    tester,
  ) async {
    final gateway = _StreamingGateway();
    final lateralPoint = _point(latitude: 6.241, seconds: 20, speedKmh: 52);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith(
            (ref) async => _pack(
              cameraLatitude: 6.241 + _northDegrees(500, 65),
              cameraLongitude: -75.57 + _eastDegrees(6.241, 500, 65),
            ),
          ),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(
            _NoopDrivingFeedbackGateway(),
          ),
        ],
        child: const MaterialApp(home: DrivingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('start-driving')));
    await tester.pump();
    gateway.add(_point(latitude: 6.241, seconds: 0, speedKmh: 50));
    await tester.pump();
    gateway.add(lateralPoint);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('driving-camera-alert-panel')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('driving-mini-map')), findsNothing);
  });

  testWidgets('legacy camera without operation status uses generic wording', (
    tester,
  ) async {
    final gateway = _StreamingGateway();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith(
            (ref) async => _pack(operationStatus: null),
          ),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(
            _NoopDrivingFeedbackGateway(),
          ),
        ],
        child: const MaterialApp(home: DrivingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('start-driving')));
    await tester.pump();
    gateway.add(_point(latitude: 6.239, seconds: 0));
    await tester.pump();
    gateway.add(_point(latitude: 6.241, seconds: 20, speedKmh: 0));
    await tester.pump();

    expect(find.text('Cámara de fotomulta'), findsOneWidget);
    expect(find.textContaining('Operando'), findsNothing);
  });

  testWidgets('ANSV speed is not a current limit or an overspeed warning', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = _StreamingGateway();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(
            _NoopDrivingFeedbackGateway(),
          ),
          drivingMapConfigProvider.overrideWithValue(
            _testMapConfig(tileProvider: _OnePixelTileProvider()),
          ),
        ],
        child: const MaterialApp(home: DrivingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('start-driving')));
    await tester.pump();
    gateway.add(_point(latitude: 6.239, seconds: 0, speedKmh: 50));
    await tester.pump();
    gateway.add(_point(latitude: 6.241, seconds: 20, speedKmh: 80));
    await tester.pump();

    expect(find.byKey(const ValueKey('driving-speed-gauge')), findsOneWidget);
    expect(find.byKey(const ValueKey('camera-speed-sign')), findsNothing);
    expect(
      find.byKey(const ValueKey('gauge-camera-indicator')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('camera-distance-pill')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('driving-camera-alert-icon-camera')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('driving-camera-address')),
      findsOneWidget,
    );
    expect(find.text('60'), findsNothing);
    expect(find.text('80'), findsOneWidget);
    expect(find.text('Vel. Max.'), findsNothing);
    expect(find.text('ANSV'), findsNothing);
    expect(find.textContaining('Velocidad máxima'), findsNothing);
    expect(find.byKey(const ValueKey('camera-speed-pill')), findsNothing);
    expect(find.text('Velocidad reportada'), findsNothing);
    expect(find.text('60 km/h · ANSV'), findsNothing);
    expect(find.textContaining('Reduce velocidad'), findsNothing);
    expect(find.textContaining('300 m ·'), findsNothing);
    expect(find.byKey(const ValueKey('driving-overspeed-delta')), findsNothing);
    expect(find.text('+20 km/h'), findsNothing);
    expect(find.byKey(const ValueKey('overspeed-pulse')), findsNothing);
  });

  testWidgets('within reported speed keeps alert visually non-urgent', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = _StreamingGateway();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(
            _NoopDrivingFeedbackGateway(),
          ),
          drivingMapConfigProvider.overrideWithValue(
            _testMapConfig(tileProvider: _OnePixelTileProvider()),
          ),
        ],
        child: const MaterialApp(home: DrivingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('start-driving')));
    await tester.pump();
    gateway.add(_point(latitude: 6.239, seconds: 0, speedKmh: 48));
    await tester.pump();
    gateway.add(_point(latitude: 6.241, seconds: 20, speedKmh: 54));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byKey(const ValueKey('driving-camera-alert-panel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('driving-camera-alert-icon-camera')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('driving-camera-alert-icon-urgent')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('driving-overspeed-delta')), findsNothing);
    expect(
      find.byKey(const ValueKey('gauge-camera-indicator')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('camera-speed-sign')), findsNothing);
    expect(find.text('Vel. Max.'), findsNothing);
    expect(find.text('ANSV'), findsNothing);
  });

  testWidgets(
    'unknown camera speed omits speed sign and avoids overspeed claim',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final gateway = _StreamingGateway();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPreferencesProvider.overrideWithValue(MemoryPreferences()),
            cameraPackProvider.overrideWith(
              (ref) async => _pack(speedLimitKmh: null),
            ),
            drivingLocationGatewayProvider.overrideWithValue(gateway),
            drivingFeedbackGatewayProvider.overrideWithValue(
              _NoopDrivingFeedbackGateway(),
            ),
            drivingMapConfigProvider.overrideWithValue(
              _testMapConfig(tileProvider: _OnePixelTileProvider()),
            ),
          ],
          child: const MaterialApp(home: DrivingScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('start-driving')));
      await tester.pump();
      gateway.add(_point(latitude: 6.239, seconds: 0, speedKmh: 100));
      await tester.pump();
      gateway.add(_point(latitude: 6.241, seconds: 20, speedKmh: 100));
      await tester.pump();

      expect(find.byKey(const ValueKey('camera-speed-sign')), findsNothing);
      expect(find.byKey(const ValueKey('camera-speed-pill')), findsNothing);
      expect(find.text('Velocidad reportada'), findsNothing);
      expect(find.text('No publicada por ANSV'), findsNothing);
      expect(
        find.byKey(const ValueKey('driving-camera-address')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('camera-authority-row')),
        findsOneWidget,
      );
      expect(find.textContaining('Reduce velocidad'), findsNothing);
      expect(find.textContaining('Velocidad máxima'), findsNothing);
      expect(
        find.byKey(const ValueKey('driving-camera-alert-icon-camera')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('driving-camera-alert-icon-urgent')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('driving-overspeed-delta')),
        findsNothing,
      );
    },
  );

  testWidgets('dismiss button hides the panel for the current camera episode', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = _StreamingGateway();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(
            _NoopDrivingFeedbackGateway(),
          ),
          drivingMapConfigProvider.overrideWithValue(
            _testMapConfig(tileProvider: _OnePixelTileProvider()),
          ),
        ],
        child: const MaterialApp(home: DrivingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('start-driving')));
    await tester.pump();
    gateway.add(_point(latitude: 6.239, seconds: 0, speedKmh: 50));
    await tester.pump();
    gateway.add(_point(latitude: 6.241, seconds: 20, speedKmh: 70));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byKey(const ValueKey('driving-camera-alert-panel')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('driving-camera-dismiss-action')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('driving-camera-alert-panel')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('driving-camera-dismissed')),
      findsOneWidget,
    );

    gateway.add(_point(latitude: 6.242, seconds: 21, speedKmh: 68));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const ValueKey('driving-camera-alert-panel')),
      findsNothing,
    );
  });

  testWidgets('swipe down dismisses the active camera panel', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = _StreamingGateway();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(
            _NoopDrivingFeedbackGateway(),
          ),
          drivingMapConfigProvider.overrideWithValue(
            _testMapConfig(tileProvider: _OnePixelTileProvider()),
          ),
        ],
        child: const MaterialApp(home: DrivingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('start-driving')));
    await tester.pump();
    gateway.add(_point(latitude: 6.239, seconds: 0, speedKmh: 50));
    await tester.pump();
    gateway.add(_point(latitude: 6.241, seconds: 20, speedKmh: 70));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.fling(
      find.byKey(const ValueKey('driving-camera-alert-header')),
      const Offset(0, 220),
      900,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));

    expect(
      find.byKey(const ValueKey('driving-camera-alert-panel')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('driving-camera-dismissed')),
      findsOneWidget,
    );
    final centeredGauge = tester.getRect(
      find.byKey(const ValueKey('driving-speed-gauge')),
    );
    final content = tester.getRect(
      find.byKey(const ValueKey('driving-active-layout')),
    );
    expect(centeredGauge.width, closeTo(324, 0.1));
    expect(centeredGauge.center.dy, closeTo(content.center.dy, 1));
  });

  testWidgets('minor downward movement does not dismiss the alert panel', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = _StreamingGateway();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(
            _NoopDrivingFeedbackGateway(),
          ),
          drivingMapConfigProvider.overrideWithValue(
            _testMapConfig(tileProvider: _NeverTileProvider()),
          ),
        ],
        child: const MaterialApp(home: DrivingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('start-driving')));
    await tester.pump();
    gateway.add(_point(latitude: 6.239, seconds: 0, speedKmh: 50));
    await tester.pump();
    gateway.add(_point(latitude: 6.241, seconds: 20, speedKmh: 70));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.drag(
      find.byKey(const ValueKey('driving-camera-alert-header')),
      const Offset(0, 20),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('driving-camera-alert-panel')),
      findsOneWidget,
    );
  });

  testWidgets('forced offline fallback shows radar without hiding alert', (
    tester,
  ) async {
    final gateway = _StreamingGateway();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(
            _NoopDrivingFeedbackGateway(),
          ),
          drivingMapConfigProvider.overrideWithValue(
            _testMapConfig(forceOfflineFallback: true),
          ),
        ],
        child: const MaterialApp(home: DrivingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('start-driving')));
    await tester.pump();
    gateway.add(_point(latitude: 6.239, seconds: 0, speedKmh: 50));
    await tester.pump();
    gateway.add(_point(latitude: 6.241, seconds: 20, speedKmh: 54));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('driving-camera-alert-panel')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('driving-mini-map')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('driving-map-offline-fallback')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('driving-real-mini-map')), findsNothing);
    expect(
      find.byKey(const ValueKey('driving-map-fallback-label')),
      findsOneWidget,
    );
    expect(find.text('Mapa no disponible · Radar'), findsOneWidget);
    expect(find.byType(TileLayer), findsNothing);
  });

  testWidgets(
    'auto map tile error uses the real handler and latches radar for GPS updates',
    (tester) async {
      final gateway = _StreamingGateway();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPreferencesProvider.overrideWithValue(MemoryPreferences()),
            cameraPackProvider.overrideWith((ref) async => _pack()),
            drivingLocationGatewayProvider.overrideWithValue(gateway),
            drivingFeedbackGatewayProvider.overrideWithValue(
              _NoopDrivingFeedbackGateway(),
            ),
            drivingMapConfigProvider.overrideWithValue(
              _testMapConfig(tileProvider: _NeverTileProvider()),
            ),
          ],
          child: const MaterialApp(home: DrivingScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('start-driving')));
      await tester.pump();
      gateway.add(_point(latitude: 6.239, seconds: 0, speedKmh: 50));
      await tester.pump();
      gateway.add(_point(latitude: 6.241, seconds: 20, speedKmh: 54));
      await _pumpMapFrames(tester);
      final tileLayer = tester.widget<TileLayer>(find.byType(TileLayer));
      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      final failedTile = _testTileImage(
        coordinates: drivingViewportTiles(map.mapController!.camera).first,
      )..loadError = true;
      addTearDown(failedTile.dispose);
      tileLayer.errorTileCallback!(
        failedTile,
        Exception('controlled tile failure'),
        StackTrace.current,
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey('driving-camera-alert-panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('driving-map-offline-fallback')),
        findsOneWidget,
      );
      _expectFailedCoveredMap();

      gateway.add(_point(latitude: 6.2412, seconds: 45, speedKmh: 54));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('driving-map-offline-fallback')),
        findsOneWidget,
      );
      _expectFailedCoveredMap();
    },
  );

  testWidgets('auto map timeout falls back to radar without blank exposure', (
    tester,
  ) async {
    final gateway = _StreamingGateway();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(
            _NoopDrivingFeedbackGateway(),
          ),
          drivingMapConfigProvider.overrideWithValue(
            _testMapConfig(tileProvider: _NeverTileProvider()),
          ),
        ],
        child: const MaterialApp(home: DrivingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('start-driving')));
    await tester.pump();
    gateway.add(_point(latitude: 6.239, seconds: 0, speedKmh: 50));
    await tester.pump();
    gateway.add(_point(latitude: 6.241, seconds: 20, speedKmh: 54));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('driving-map-offline-fallback')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('driving-real-mini-map')), findsOneWidget);

    await tester.pump(drivingMapTileReadinessTimeout);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('driving-map-offline-fallback')),
      findsOneWidget,
    );
    _expectFailedCoveredMap();
  });

  testWidgets(
    'auto map timeout keeps original deadline across later GPS points',
    (tester) async {
      final gateway = _StreamingGateway();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPreferencesProvider.overrideWithValue(MemoryPreferences()),
            cameraPackProvider.overrideWith((ref) async => _pack()),
            drivingLocationGatewayProvider.overrideWithValue(gateway),
            drivingFeedbackGatewayProvider.overrideWithValue(
              _NoopDrivingFeedbackGateway(),
            ),
            drivingMapConfigProvider.overrideWithValue(
              _testMapConfig(tileProvider: _NeverTileProvider()),
            ),
          ],
          child: const MaterialApp(home: DrivingScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('start-driving')));
      await tester.pump();
      gateway.add(_point(latitude: 6.239, seconds: 0, speedKmh: 50));
      await tester.pump();
      gateway.add(_point(latitude: 6.241, seconds: 20, speedKmh: 54));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('driving-map-offline-fallback')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('driving-real-mini-map')),
        findsOneWidget,
      );

      await tester.pump(const Duration(seconds: 1));
      gateway.add(_point(latitude: 6.2412, seconds: 21, speedKmh: 54));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      gateway.add(_point(latitude: 6.2414, seconds: 22, speedKmh: 54));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));

      expect(
        find.byKey(const ValueKey('driving-map-offline-fallback')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('driving-real-mini-map')),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('driving-map-offline-fallback')),
        findsOneWidget,
      );
      _expectFailedCoveredMap();

      gateway.add(_point(latitude: 6.2416, seconds: 23, speedKmh: 54));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('driving-map-offline-fallback')),
        findsOneWidget,
      );
      _expectFailedCoveredMap();
    },
  );

  testWidgets('new camera episode starts a fresh controlled map timeout', (
    tester,
  ) async {
    final gateway = _StreamingGateway();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith(
            (ref) async => _pack(
              cameras: [
                _camera(id: 'cam-1', latitude: 6.244),
                _camera(id: 'cam-2', latitude: 6.249),
              ],
            ),
          ),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(
            _NoopDrivingFeedbackGateway(),
          ),
          drivingMapConfigProvider.overrideWithValue(
            _testMapConfig(tileProvider: _NeverTileProvider()),
          ),
        ],
        child: const MaterialApp(home: DrivingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('start-driving')));
    await tester.pump();
    gateway.add(_point(latitude: 6.239, seconds: 0, speedKmh: 50));
    await tester.pump();
    gateway.add(_point(latitude: 6.241, seconds: 20, speedKmh: 54));
    await tester.pump();
    await tester.pump(drivingMapTileReadinessTimeout);
    await tester.pump();
    _expectFailedCoveredMap();

    gateway.add(_point(latitude: 6.246, seconds: 45, speedKmh: 54));
    await tester.pump();
    expect(find.byKey(const ValueKey('camera-panel-cam-2')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('camera-panel-cam-2')),
        matching: find.byKey(const ValueKey('driving-real-mini-map')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('camera-panel-cam-2')),
        matching: find.byType(TileLayer),
      ),
      findsOneWidget,
    );

    await tester.pump(drivingMapTileReadinessTimeout);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('driving-map-offline-fallback')),
      findsOneWidget,
    );
    _expectFailedCoveredMap();
  });

  testWidgets('radar visualization mode never builds a tile layer', (
    tester,
  ) async {
    final gateway = _StreamingGateway();
    final preferences = MemoryPreferences();
    await saveDrivingPreferences(
      preferences,
      defaultDrivingPreferences.copyWith(
        cameraVisualizationMode: CameraVisualizationMode.radar,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(preferences),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(
            _NoopDrivingFeedbackGateway(),
          ),
          drivingMapConfigProvider.overrideWithValue(
            _testMapConfig(tileProvider: _OnePixelTileProvider()),
          ),
        ],
        child: const MaterialApp(home: DrivingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('start-driving')));
    await tester.pump();
    gateway.add(_point(latitude: 6.239, seconds: 0, speedKmh: 50));
    await tester.pump();
    gateway.add(_point(latitude: 6.241, seconds: 20, speedKmh: 54));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('driving-camera-alert-panel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('driving-map-offline-fallback')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('driving-radar-cone-90')), findsOneWidget);
    expect(find.byKey(const ValueKey('driving-real-mini-map')), findsNothing);
    expect(
      find.byKey(const ValueKey('driving-map-fallback-label')),
      findsNothing,
    );
    expect(find.byType(TileLayer), findsNothing);
  });

  testWidgets(
    'map visualization mode forced fallback shows radar when configured',
    (tester) async {
      final gateway = _StreamingGateway();
      final preferences = MemoryPreferences();
      await saveDrivingPreferences(
        preferences,
        defaultDrivingPreferences.copyWith(
          cameraVisualizationMode: CameraVisualizationMode.map,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPreferencesProvider.overrideWithValue(preferences),
            cameraPackProvider.overrideWith((ref) async => _pack()),
            drivingLocationGatewayProvider.overrideWithValue(gateway),
            drivingFeedbackGatewayProvider.overrideWithValue(
              _NoopDrivingFeedbackGateway(),
            ),
            drivingMapConfigProvider.overrideWithValue(
              _testMapConfig(forceOfflineFallback: true),
            ),
          ],
          child: const MaterialApp(home: DrivingScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('start-driving')));
      await tester.pump();
      gateway.add(_point(latitude: 6.239, seconds: 0, speedKmh: 50));
      await tester.pump();
      gateway.add(_point(latitude: 6.241, seconds: 20, speedKmh: 54));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('driving-camera-alert-panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('driving-map-offline-fallback')),
        findsOneWidget,
      );
      expect(find.text('Mapa no disponible · Radar'), findsOneWidget);
      expect(find.byType(TileLayer), findsNothing);
    },
  );

  testWidgets('mirror HUD is mirrored and shows current camera distance', (
    tester,
  ) async {
    final gateway = _StreamingGateway();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(
            _NoopDrivingFeedbackGateway(),
          ),
          drivingMapConfigProvider.overrideWithValue(
            _testMapConfig(tileProvider: _OnePixelTileProvider()),
          ),
        ],
        child: const MaterialApp(home: DrivingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('start-driving')));
    await tester.pump();
    gateway.add(_point(latitude: 6.239, seconds: 0));
    await tester.pump();
    gateway.add(_point(latitude: 6.241, seconds: 20));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('hud-mirror-action')));
    await tester.pumpAndSettle();

    final transform = tester.widget<Transform>(
      find.byKey(const ValueKey('hud-content-transform')),
    );
    expect(transform.transform.storage[0], -1);
    expect(find.byKey(const ValueKey('hud-camera-distance')), findsOneWidget);
    expect(find.byKey(const ValueKey('hud-camera-speed-sign')), findsNothing);
    expect(find.text('Respeta la señalización'), findsOneWidget);
    expect(find.byKey(const ValueKey('hud-camera-address')), findsOneWidget);
    expect(find.byKey(const ValueKey('driving-mini-map')), findsNothing);
    expect(find.byKey(const ValueKey('driving-real-mini-map')), findsNothing);
    expect(find.text('Vel. Max.'), findsNothing);
    expect(find.text('ANSV'), findsNothing);
    expect(find.textContaining('Cámara'), findsOneWidget);
    expect(find.text('Dentro del valor'), findsNothing);
  });

  testWidgets('camera detail sheet can render future B05 source fields', (
    tester,
  ) async {
    final gateway = _StreamingGateway();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(
            _NoopDrivingFeedbackGateway(),
          ),
        ],
        child: const MaterialApp(home: DrivingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('start-driving')));
    await tester.pump();
    gateway.add(_point(latitude: 6.239, seconds: 0));
    await tester.pump();
    gateway.add(_point(latitude: 6.241, seconds: 20));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('driving-camera-detail-action')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('driving-camera-detail-action')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('driving-camera-detail-sheet')),
      findsOneWidget,
    );
    expect(find.text('Avenida 80'), findsWidgets);
    expect(find.text('Secretaría de Movilidad de Medellín'), findsWidgets);
    expect(find.text('Cámara'), findsOneWidget);
    expect(find.text('Operando'), findsOneWidget);
    expect(find.text('Equipo 123'), findsOneWidget);
    expect(find.text('Velocidad reportada por ANSV'), findsOneWidget);
    expect(find.text('60 km/h'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('driving-camera-map-action-sheet')),
      findsOneWidget,
    );
  });

  testWidgets('camera detail sheet preserves unknown ANSV speed truth', (
    tester,
  ) async {
    final gateway = _StreamingGateway();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith(
            (ref) async => _pack(speedLimitKmh: null),
          ),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(
            _NoopDrivingFeedbackGateway(),
          ),
        ],
        child: const MaterialApp(home: DrivingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('start-driving')));
    await tester.pump();
    gateway.add(_point(latitude: 6.239, seconds: 0));
    await tester.pump();
    gateway.add(_point(latitude: 6.241, seconds: 20));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('driving-camera-detail-action')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('driving-camera-detail-action')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Velocidad reportada por ANSV'), findsOneWidget);
    expect(find.text('No informada'), findsOneWidget);
    expect(find.byKey(const ValueKey('camera-speed-sign')), findsNothing);
  });

  for (final textScale in const [1.0, 1.5, 2.0]) {
    testWidgets('camera indicator fits at text scale $textScale', (
      tester,
    ) async {
      final gateway = _StreamingGateway();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPreferencesProvider.overrideWithValue(MemoryPreferences()),
            cameraPackProvider.overrideWith((ref) async => _pack()),
            drivingLocationGatewayProvider.overrideWithValue(gateway),
            drivingFeedbackGatewayProvider.overrideWithValue(
              _NoopDrivingFeedbackGateway(),
            ),
            drivingMapConfigProvider.overrideWithValue(
              _testMapConfig(tileProvider: _OnePixelTileProvider()),
            ),
          ],
          child: MaterialApp(
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              );
            },
            home: const DrivingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('start-driving')));
      await tester.pump();
      gateway.add(_point(latitude: 6.239, seconds: 0, speedKmh: 48));
      await tester.pump();
      gateway.add(_point(latitude: 6.241, seconds: 20, speedKmh: 54));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('gauge-camera-indicator')),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('gauge-camera-indicator'))),
        const Size(72, 72),
      );
      expect(find.byKey(const ValueKey('camera-speed-sign')), findsNothing);
      expect(find.text('Vel. Max.'), findsNothing);
      expect(find.text('ANSV'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('camera indicator respects reduced motion', (tester) async {
    final gateway = _StreamingGateway();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(
            _NoopDrivingFeedbackGateway(),
          ),
          drivingMapConfigProvider.overrideWithValue(
            _testMapConfig(tileProvider: _OnePixelTileProvider()),
          ),
        ],
        child: MaterialApp(
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            );
          },
          home: const DrivingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('start-driving')));
    await tester.pump();
    gateway.add(_point(latitude: 6.239, seconds: 0, speedKmh: 48));
    await tester.pump();
    gateway.add(_point(latitude: 6.241, seconds: 20, speedKmh: 54));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('gauge-camera-indicator')),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('gauge-camera-indicator'))),
      const Size(72, 72),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('active camera layout keeps the alert above fixed controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = _StreamingGateway();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(
            _NoopDrivingFeedbackGateway(),
          ),
          drivingMapConfigProvider.overrideWithValue(
            _testMapConfig(tileProvider: _OnePixelTileProvider()),
          ),
        ],
        child: const MaterialApp(home: DrivingScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('start-driving')));
    await tester.pump();
    gateway.add(_point(latitude: 6.239, seconds: 0, speedKmh: 48));
    await tester.pump();
    gateway.add(_point(latitude: 6.241, seconds: 20, speedKmh: 54));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Cámara de fotomulta'), findsOneWidget);
    expect(find.text('Cámara cercana'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('driving-active-controls')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('driving-active-settings')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('driving-active-hud')), findsOneWidget);
    expect(find.byKey(const ValueKey('driving-active-mirror')), findsOneWidget);
    final panel = tester.getRect(
      find.byKey(const ValueKey('driving-camera-alert-panel')),
    );
    final controls = tester.getRect(
      find.byKey(const ValueKey('driving-active-controls')),
    );
    expect(panel.bottom, lessThanOrEqualTo(controls.top));
    expect(tester.takeException(), isNull);
  });

  for (final viewport in const [
    Size(360, 780),
    Size(360, 800),
    Size(390, 844),
    Size(412, 915),
  ]) {
    for (final textScale in const [1.0, 1.5, 2.0]) {
      testWidgets(
        'camera layout fits ${viewport.width}x${viewport.height} at $textScale',
        (tester) async {
          await tester.binding.setSurfaceSize(viewport);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final gateway = _StreamingGateway();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                appPreferencesProvider.overrideWithValue(MemoryPreferences()),
                cameraPackProvider.overrideWith(
                  (ref) async => _pack(
                    address:
                        'AVENIDA REGIONAL CON CALLE 67 SUR Sentido SUR - NORTE',
                  ),
                ),
                drivingControllerProvider.overrideWith(
                  _LabelledDrivingController.new,
                ),
                drivingLocationGatewayProvider.overrideWithValue(gateway),
                drivingFeedbackGatewayProvider.overrideWithValue(
                  _NoopDrivingFeedbackGateway(),
                ),
                drivingMapConfigProvider.overrideWithValue(
                  _testMapConfig(tileProvider: _OnePixelTileProvider()),
                ),
              ],
              child: MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    size: viewport,
                    padding: const EdgeInsets.only(top: 35, bottom: 48),
                    textScaler: TextScaler.linear(textScale),
                  ),
                  child: RepaintBoundary(
                    key: const ValueKey('compact-evidence-root'),
                    child: child!,
                  ),
                ),
                home: const DrivingScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (find.byKey(const ValueKey('start-driving')).evaluate().isEmpty) {
            await tester.drag(find.byType(ListView), const Offset(0, -500));
            await tester.pumpAndSettle();
          }
          await tester.tap(find.byKey(const ValueKey('start-driving')));
          await tester.pump();
          gateway.add(_point(latitude: 6.239, seconds: 0, speedKmh: 48));
          await tester.pump();
          gateway.add(_point(latitude: 6.241, seconds: 20, speedKmh: 54));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          final labelled =
              ProviderScope.containerOf(
                    tester.element(find.byType(DrivingScreen)),
                  ).read(drivingControllerProvider.notifier)
                  as _LabelledDrivingController;
          labelled.labelSimulation();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          final controls = tester.getRect(
            find.byKey(const ValueKey('driving-active-controls')),
          );
          expect(
            tester
                .widget<Scaffold>(find.byType(Scaffold).first)
                .backgroundColor,
            const Color(0xFF03090D),
          );
          expect(find.textContaining('(reportado)'), findsNothing);
          if (textScale <= 1.5) {
            final map = tester.getRect(
              find.byKey(const ValueKey('driving-mini-map')),
            );
            final address = tester.getRect(
              find.byKey(const ValueKey('driving-camera-address')),
            );
            expect(address.left, greaterThan(map.right));
            expect(address.top, closeTo(map.top, 1));
          }
          expect(controls.left, greaterThanOrEqualTo(0));
          expect(controls.right, lessThanOrEqualTo(viewport.width));
          expect(controls.bottom, lessThanOrEqualTo(viewport.height));
          await _captureCompactEvidence(
            tester,
            '${viewport.width.toInt()}x${viewport.height.toInt()}-$textScale-camera',
          );
          expect(
            find.byKey(const ValueKey('driving-active-layout')),
            findsOneWidget,
          );

          if (textScale == 1) {
            final gauge = tester.getRect(
              find.byKey(const ValueKey('driving-speed-gauge')),
            );
            final indicator = tester.getRect(
              find.byKey(const ValueKey('gauge-camera-indicator')),
            );
            final speed = tester.getRect(
              find.byKey(const ValueKey('driving-speed')),
            );
            expect(gauge.width, closeTo(viewport.width * 0.8 + 12, 0.1));
            expect(gauge.center.dx, closeTo(viewport.width / 2, 0.1));
            expect(speed.center.dx, closeTo(gauge.center.dx, 0.1));
            expect(speed.overlaps(indicator), isFalse);
            expect(indicator.center.dy, closeTo(speed.center.dy - 24, 0.1));
            final brand = tester.getRect(
              find.byKey(const ValueKey('driving-brand')),
            );
            final gps = tester.getRect(
              find.byKey(const ValueKey('driving-connection-chip')),
            );
            final voice = tester.getRect(
              find.byKey(const ValueKey('driving-voice-chip')),
            );
            expect(gps.center.dy, closeTo(brand.center.dy, 3));
            expect(voice.center.dy, closeTo(gps.center.dy, 0.1));
            expect(brand.right + 8, lessThanOrEqualTo(gps.left));
            expect(find.text('Voz activa'), findsNothing);
            expect(find.text('Configuración'), findsNothing);
            expect(find.text('HUD'), findsNothing);
            expect(find.text('Espejo'), findsNothing);
            for (final key in [
              'driving-active-settings',
              'driving-active-hud',
              'driving-active-mirror',
            ]) {
              expect(
                tester.getSize(find.byKey(ValueKey(key))),
                const Size(48, 56),
              );
            }
            final stop = tester.getRect(
              find.byKey(const ValueKey('stop-driving')),
            );
            expect(stop.width, greaterThanOrEqualTo(160));
            expect(stop.height, 56);
            final panel = tester.getRect(
              find.byKey(const ValueKey('driving-camera-alert-panel')),
            );
            expect(panel.top, greaterThanOrEqualTo(0));
            expect(panel.top, greaterThanOrEqualTo(gauge.bottom));
            expect(panel.bottom, lessThanOrEqualTo(controls.top));
          }
          for (final key in [
            'driving-camera-address',
            'camera-authority-row',
          ]) {
            final facts = tester.getRect(find.byKey(ValueKey(key)));
            expect(facts.bottom + 8, lessThanOrEqualTo(controls.top));
          }
          expect(find.byType(Scrollable), findsNothing);
          final addressParagraph = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.text(
                'AVENIDA REGIONAL CON CALLE 67 SUR Sentido SUR - NORTE',
              ),
              matching: find.byType(RichText),
            ),
          );
          final renderedFontSize =
              addressParagraph.textScaler.scale(14) *
              addressParagraph.getTransformTo(null).getMaxScaleOnAxis();
          expect(renderedFontSize, greaterThanOrEqualTo(12));
          final info = tester.getRect(
            find.byKey(const ValueKey('driving-camera-detail-action')),
          );
          final close = tester.getRect(
            find.byKey(const ValueKey('driving-camera-dismiss-action')),
          );
          expect(info.size.shortestSide, greaterThanOrEqualTo(48));
          expect(close.size.shortestSide, greaterThanOrEqualTo(48));
          expect(info.right + 4, lessThanOrEqualTo(close.left));
          expect(info.center.dy, closeTo(close.center.dy, 0.1));
          expect(tester.takeException(), isNull);
          gateway.add(_point(latitude: 6.2411, seconds: 21, speedKmh: 123));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          final speed = tester.getRect(
            find.byKey(const ValueKey('driving-speed')),
          );
          final gauge = tester.getRect(
            find.byKey(const ValueKey('driving-speed-gauge')),
          );
          final indicator = tester.getRect(
            find.byKey(const ValueKey('gauge-camera-indicator')),
          );
          expect(gauge.contains(speed.center), isTrue);
          expect(speed.overlaps(indicator), isFalse);
          expect(speed.left, greaterThan(gauge.left + gauge.width * 0.20));
          expect(speed.right, lessThan(gauge.right - gauge.width * 0.20));
          expect(tester.takeException(), isNull);
          expect(
            tester.widget<Text>(find.text('GPS')).style!.color,
            AppColors.green,
          );
          final container = ProviderScope.containerOf(
            tester.element(find.byType(DrivingScreen)),
          );
          final notifier = container.read(drivingControllerProvider.notifier);
          final preferences = container
              .read(drivingControllerProvider)
              .requireValue
              .preferences;
          await notifier.savePreferences(
            preferences.copyWith(voiceEnabled: false),
          );
          await tester.pump();
          expect(
            tester.widget<Text>(find.text('Voz')).style!.color,
            AppColors.red,
          );
          expect(find.byTooltip('Voz deshabilitada'), findsOneWidget);
          for (final sample in [
            (40.0, AppColors.orange),
            (90.0, AppColors.red),
          ]) {
            gateway.add(
              _point(
                latitude: 6.242,
                seconds: sample.$1.toInt(),
                accuracyMeters: sample.$1,
              ),
            );
            await tester.pump();
            expect(
              tester.widget<Text>(find.text('GPS')).style!.color,
              sample.$2,
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('visual alert repeats while approaching and stops on dismissal', (
    tester,
  ) async {
    final gateway = _StreamingGateway();
    final preferences = MemoryPreferences();
    await saveDrivingPreferences(
      preferences,
      defaultDrivingPreferences.copyWith(
        visualAlertsEnabled: true,
        voiceEnabled: false,
        soundEnabled: false,
        vibrationEnabled: false,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(preferences),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(
            _NoopDrivingFeedbackGateway(),
          ),
          drivingMapConfigProvider.overrideWithValue(
            _testMapConfig(tileProvider: _OnePixelTileProvider()),
          ),
        ],
        child: const MaterialApp(home: DrivingScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('start-driving')));
    await tester.pump();
    gateway.add(_point(latitude: 6.239, seconds: 0, speedKmh: 48));
    await tester.pump();
    gateway.add(_point(latitude: 6.241, seconds: 20, speedKmh: 54));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    Color overlayColor() => tester
        .widget<ColoredBox>(
          find.byKey(const ValueKey('driving-visual-alert-overlay')),
        )
        .color;
    expect(overlayColor().a, greaterThan(0));
    expect(overlayColor().b, greaterThan(overlayColor().r));

    await tester.pump(const Duration(milliseconds: 800));
    expect(overlayColor().a, closeTo(0, 0.001));
    await tester.pump(const Duration(milliseconds: 400));
    expect(overlayColor().a, greaterThan(0));
    expect(overlayColor().r, closeTo(overlayColor().b, 0.001));

    await tester.pump(const Duration(milliseconds: 800));
    expect(overlayColor().a, closeTo(0, 0.001));
    await tester.pump(const Duration(milliseconds: 400));
    expect(overlayColor().a, greaterThan(0));
    expect(overlayColor().b, greaterThan(overlayColor().r));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DrivingScreen)),
    );
    container
        .read(drivingControllerProvider.notifier)
        .dismissCurrentCameraAlert();
    await tester.pump();
    expect(overlayColor().a, closeTo(0, 0.001));
    await tester.pump(const Duration(seconds: 3));
    expect(overlayColor().a, closeTo(0, 0.001));
    expect(tester.takeException(), isNull);
  });

  for (final cancellation in ['passed', 'disabled', 'stopped', 'background']) {
    testWidgets('continuous camera pulse cancels when $cancellation', (
      tester,
    ) async {
      final gateway = _StreamingGateway();
      final preferences = MemoryPreferences();
      await saveDrivingPreferences(
        preferences,
        defaultDrivingPreferences.copyWith(
          visualAlertsEnabled: true,
          cameraTargetingConeDegrees: 360,
          voiceEnabled: false,
          soundEnabled: false,
          vibrationEnabled: false,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPreferencesProvider.overrideWithValue(preferences),
            cameraPackProvider.overrideWith((ref) async => _pack()),
            drivingLocationGatewayProvider.overrideWithValue(gateway),
            drivingFeedbackGatewayProvider.overrideWithValue(
              _NoopDrivingFeedbackGateway(),
            ),
            drivingMapConfigProvider.overrideWithValue(
              _testMapConfig(tileProvider: _OnePixelTileProvider()),
            ),
          ],
          child: const MaterialApp(home: DrivingScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('start-driving')));
      await tester.pump();
      gateway.add(_point(latitude: 6.239, seconds: 0, speedKmh: 48));
      await tester.pump();
      gateway.add(_point(latitude: 6.241, seconds: 20, speedKmh: 54));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrivingScreen)),
      );
      final controller = container.read(drivingControllerProvider.notifier);
      double opacity() => tester
          .widget<ColoredBox>(
            find.byKey(const ValueKey('driving-visual-alert-overlay')),
          )
          .color
          .a;
      expect(opacity(), greaterThan(0));
      switch (cancellation) {
        case 'passed':
          gateway.add(_point(latitude: 6.245, seconds: 40, speedKmh: 54));
          await tester.pump();
          gateway.add(_point(latitude: 6.246, seconds: 50, speedKmh: 54));
        case 'disabled':
          await controller.savePreferences(
            container
                .read(drivingControllerProvider)
                .requireValue
                .preferences
                .copyWith(visualAlertsEnabled: false),
          );
        case 'stopped':
          unawaited(controller.stop());
        case 'background':
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
      }
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(opacity(), closeTo(0, 0.001));
      if (cancellation == 'background') {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(opacity(), closeTo(0, 0.001));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('visual alert stays static when reduced motion is enabled', (
    tester,
  ) async {
    final gateway = _StreamingGateway();
    final preferences = MemoryPreferences();
    await saveDrivingPreferences(
      preferences,
      defaultDrivingPreferences.copyWith(visualAlertsEnabled: true),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(preferences),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(
            _NoopDrivingFeedbackGateway(),
          ),
          drivingMapConfigProvider.overrideWithValue(
            _testMapConfig(tileProvider: _OnePixelTileProvider()),
          ),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const DrivingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('start-driving')));
    await tester.pump();
    gateway.add(_point(latitude: 6.239, seconds: 0, speedKmh: 48));
    await tester.pump();
    gateway.add(_point(latitude: 6.241, seconds: 20, speedKmh: 54));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final overlay = tester.widget<ColoredBox>(
      find.byKey(const ValueKey('driving-visual-alert-overlay')),
    );
    expect(overlay.color.a, closeTo(0, 0.001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('all camera actions open source before explicit Google Maps', (
    tester,
  ) async {
    final gateway = _StreamingGateway();
    final launcher = _FakeExternalLauncher();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(
            _NoopDrivingFeedbackGateway(),
          ),
          externalLauncherProvider.overrideWithValue(launcher),
        ],
        child: const MaterialApp(home: DrivingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('start-driving')));
    await tester.pump();
    gateway.add(_point(latitude: 6.239, seconds: 0));
    await tester.pump();
    gateway.add(_point(latitude: 6.241, seconds: 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    for (final key in [
      'gauge-camera-indicator',
      'driving-camera-detail-action',
      'real-map-tap-callback',
      'driving-camera-map-action',
    ]) {
      if (key == 'real-map-tap-callback') {
        final map = tester.widget<FlutterMap>(
          find.byKey(const ValueKey('driving-real-mini-map')),
        );
        expect(map.options.onTap, isNotNull);
        map.options.onTap!(
          const TapPosition(Offset.zero, Offset.zero),
          map.options.initialCenter,
        );
      } else {
        await tester.tap(find.byKey(ValueKey(key)));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Fuente de cámara'), findsOneWidget);
      expect(launcher.opened, isEmpty);
      if (key != 'driving-camera-map-action') {
        Navigator.of(
          tester.element(
            find.byKey(const ValueKey('driving-camera-detail-sheet')),
          ),
        ).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }
    }
    await tester.tap(
      find.byKey(const ValueKey('driving-camera-map-action-sheet')),
    );
    await tester.pump();

    expect(launcher.opened, hasLength(1));
    final uri = Uri.parse(launcher.opened.single);
    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/search/');
    expect(uri.queryParameters['query'], '6.244,-75.57');
  });

  testWidgets('camera map action reports launcher failure', (tester) async {
    final gateway = _StreamingGateway();
    final launcher = _FakeExternalLauncher(openResult: false);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(
            _NoopDrivingFeedbackGateway(),
          ),
          externalLauncherProvider.overrideWithValue(launcher),
        ],
        child: const MaterialApp(home: DrivingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('start-driving')));
    await tester.pump();
    gateway.add(_point(latitude: 6.239, seconds: 0));
    await tester.pump();
    gateway.add(_point(latitude: 6.241, seconds: 20));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('driving-camera-map-action')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('driving-camera-map-action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Fuente de cámara'), findsOneWidget);
    expect(launcher.opened, isEmpty);
    await tester.tap(
      find.byKey(const ValueKey('driving-camera-map-action-sheet')),
    );
    await tester.pump();

    expect(find.text('No pudimos abrir Google Maps.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('camera map action reports launcher exception', (tester) async {
    final gateway = _StreamingGateway();
    final launcher = _FakeExternalLauncher(throwOnOpen: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(
            _NoopDrivingFeedbackGateway(),
          ),
          externalLauncherProvider.overrideWithValue(launcher),
        ],
        child: const MaterialApp(home: DrivingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('start-driving')));
    await tester.pump();
    gateway.add(_point(latitude: 6.239, seconds: 0));
    await tester.pump();
    gateway.add(_point(latitude: 6.241, seconds: 20));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('driving-camera-map-action')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('driving-camera-map-action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Fuente de cámara'), findsOneWidget);
    expect(launcher.opened, isEmpty);
    await tester.tap(
      find.byKey(const ValueKey('driving-camera-map-action-sheet')),
    );
    await tester.pump();

    expect(find.text('No pudimos abrir Google Maps.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HUD with unknown speed omits the speed sign', (tester) async {
    final gateway = _StreamingGateway();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith(
            (ref) async => _pack(speedLimitKmh: null),
          ),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(
            _NoopDrivingFeedbackGateway(),
          ),
        ],
        child: const MaterialApp(home: DrivingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('start-driving')));
    await tester.pump();
    gateway.add(_point(latitude: 6.239, seconds: 0));
    await tester.pump();
    gateway.add(_point(latitude: 6.241, seconds: 20));
    await tester.pump();
    await tester.tap(find.byTooltip('HUD'));
    await tester.pumpAndSettle();

    final transform = tester.widget<Transform>(
      find.byKey(const ValueKey('hud-content-transform')),
    );
    expect(transform.transform.storage[0], 1);
    expect(find.byKey(const ValueKey('hud-camera-speed-sign')), findsNothing);
    expect(find.byKey(const ValueKey('hud-camera-distance')), findsOneWidget);
    expect(find.byKey(const ValueKey('driving-mini-map')), findsNothing);
    expect(find.byKey(const ValueKey('driving-real-mini-map')), findsNothing);
    expect(find.text('Velocidad no publicada'), findsNothing);
    expect(find.text('Respeta la señalización'), findsOneWidget);
  });

  testWidgets('inactive lifecycle state does not stop an active session', (
    tester,
  ) async {
    final gateway = _StreamingGateway();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(
            _NoopDrivingFeedbackGateway(),
          ),
          drivingMapConfigProvider.overrideWithValue(
            _testMapConfig(forceOfflineFallback: true),
          ),
        ],
        child: const MaterialApp(home: DrivingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('start-driving')));
    await tester.pump();
    expect(find.byKey(const ValueKey('stop-driving')), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    expect(find.byKey(const ValueKey('stop-driving')), findsOneWidget);
  });
}

class _NoopDrivingFeedbackGateway implements DrivingFeedbackGateway {
  @override
  Future<void> playSound() async {}

  @override
  Future<void> setKeepScreenOn(bool enabled) async {}

  @override
  Future<void> speak(String message) async {}

  @override
  Future<void> stopOngoingFeedback() async {}

  @override
  Future<void> vibrate() async {}
}

class _FakeExternalLauncher implements ExternalLauncher {
  _FakeExternalLauncher({this.openResult = true, this.throwOnOpen = false});

  final bool openResult;
  final bool throwOnOpen;
  final opened = <String>[];

  @override
  Future<bool> callPhone(String phone) async => false;

  @override
  Future<bool> openExternal(String uri) async {
    if (throwOnOpen) {
      throw StateError('launcher failed');
    }
    opened.add(uri);
    return openResult;
  }
}

DrivingMapConfig _testMapConfig({
  bool forceOfflineFallback = false,
  TileProvider? tileProvider,
}) {
  return DrivingMapConfig(
    tileUrlTemplate: 'https://tiles.test/{z}/{x}/{y}.png',
    attributionLabel: 'OpenStreetMap contributors',
    userAgentPackageName: 'co.picoradar.app.dev',
    forceOfflineFallback: forceOfflineFallback,
    tileProvider: tileProvider,
  );
}

class _OnePixelTileProvider extends TileProvider {
  @override
  ImageProvider<Object> getImage(
    TileCoordinates coordinates,
    TileLayer options,
  ) {
    return const _ImmediateImageProvider();
  }
}

Future<void> _pumpMapFrames(WidgetTester tester) async {
  for (var frame = 0; frame < 8; frame++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}

void _expectFailedCoveredMap() {
  expect(find.byKey(const ValueKey('driving-real-mini-map')), findsOneWidget);
  expect(
    find.byKey(const ValueKey('driving-map-offline-fallback')),
    findsOneWidget,
  );
  expect(find.text('Mapa no disponible · Radar'), findsOneWidget);
  expect(find.byKey(const ValueKey('driving-map-attribution')), findsNothing);
  expect(find.byType(TileLayer), findsNothing);
}

TileImage _testTileImage({required TileCoordinates coordinates}) {
  return TileImage(
    vsync: const TestVSync(),
    coordinates: coordinates,
    imageProvider: const _NeverImageProvider(),
    onLoadComplete: (_) {},
    onLoadError: (_, _, _) {},
    tileDisplay: const TileDisplay.instantaneous(),
    errorImage: null,
    cancelLoading: Completer<void>(),
  );
}

class _NeverTileProvider extends TileProvider {
  @override
  ImageProvider<Object> getImage(
    TileCoordinates coordinates,
    TileLayer options,
  ) {
    return const _NeverImageProvider();
  }
}

class _NeverImageProvider extends ImageProvider<_NeverImageProvider> {
  const _NeverImageProvider();

  @override
  Future<_NeverImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_NeverImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _NeverImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
  }
}

class _ImmediateImageProvider extends ImageProvider<_ImmediateImageProvider> {
  const _ImmediateImageProvider();

  @override
  Future<_ImmediateImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_ImmediateImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _ImmediateImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(_onePixelImage());
  }
}

Future<ImageInfo> _onePixelImage() {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 1, 1),
    ui.Paint()..color = const Color(0xFF75B884),
  );
  final picture = recorder.endRecording();
  final image = picture.toImageSync(1, 1);
  picture.dispose();
  return SynchronousFuture(ImageInfo(image: image));
}

Future<void> _captureCompactEvidence(WidgetTester tester, String name) async {
  const directory = String.fromEnvironment('DRIVING_VISUAL_EVIDENCE_DIR');
  if (directory.isEmpty) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('compact-evidence-root')),
    );
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final output = Directory(directory);
    await output.create(recursive: true);
    await File('${output.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
  });
}

CameraPack _emptyPack() {
  return const CameraPack(
    source: CameraPackSource(
      name: 'ANSV',
      pageUrl: 'https://fotodeteccion.ansv.gov.co/ubicaciones-aprobadas.html',
      dataUrl: 'https://fotodeteccion.ansv.gov.co/map/data/sast.json',
      fetchedAtUtc: '2026-08-31T00:00:00Z',
    ),
    cameras: [],
  );
}

CameraPack _pack({
  String address = 'Avenida 80',
  int? speedLimitKmh = 60,
  String? operationStatus = 'Operando',
  double cameraLatitude = 6.244,
  double cameraLongitude = -75.57,
  List<TrafficCamera>? cameras,
}) {
  return CameraPack(
    source: const CameraPackSource(
      name: 'ANSV',
      pageUrl: 'https://fotodeteccion.ansv.gov.co/ubicaciones-aprobadas.html',
      dataUrl: 'https://fotodeteccion.ansv.gov.co/map/data/sast.json',
      fetchedAtUtc: '2026-08-31T00:00:00Z',
    ),
    cameras:
        cameras ??
        [
          _camera(
            id: 'cam-1',
            address: address,
            latitude: cameraLatitude,
            longitude: cameraLongitude,
            speedLimitKmh: speedLimitKmh,
            operationStatus: operationStatus,
          ),
        ],
  );
}

TrafficCamera _camera({
  String address = 'Avenida 80',
  required String id,
  required double latitude,
  double longitude = -75.57,
  int? speedLimitKmh = 60,
  String? operationStatus = 'Operando',
}) {
  return TrafficCamera(
    id: id,
    department: 'ANTIOQUIA',
    municipality: 'MEDELLIN',
    jurisdiction: 'Municipal',
    address: address,
    latitude: latitude,
    longitude: longitude,
    status: 'Aprobada',
    technology: 'Camara',
    kind: CameraKind.mixed,
    speedLimitKmh: speedLimitKmh,
    operationStatus: operationStatus,
    trafficAuthority: 'Secretaría de Movilidad de Medellín',
    installationType: 'Fija',
    equipmentName: 'Equipo 123',
    rawInfractionCodes: const ['C29'],
  );
}

double _northDegrees(double distanceMeters, double bearingDegrees) {
  return math.cos(bearingDegrees * math.pi / 180) * distanceMeters / 111320.0;
}

double _eastDegrees(
  double latitude,
  double distanceMeters,
  double bearingDegrees,
) {
  final metersPerLongitude = 111320.0 * math.cos(latitude * math.pi / 180);
  return math.sin(bearingDegrees * math.pi / 180) *
      distanceMeters /
      metersPerLongitude;
}

DrivingPoint _point({
  required double latitude,
  required int seconds,
  double speedKmh = 42,
  double accuracyMeters = 12,
}) {
  return DrivingPoint(
    latitude: latitude,
    longitude: -75.57,
    accuracyMeters: accuracyMeters,
    speedKmh: speedKmh,
    headingDegrees: 0,
    recordedAt: DateTime.utc(2026, 8, 31, 12, 0, seconds),
  );
}

class _IdleGateway implements DrivingLocationGateway {
  var requestPermissionCalls = 0;

  @override
  Future<DeviceLocationPermission> checkPermission() async {
    return DeviceLocationPermission.denied;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Stream<DrivingPoint> positionStream() {
    throw UnimplementedError();
  }

  @override
  Future<DeviceLocationPermission> requestPermission() async {
    requestPermissionCalls += 1;
    return DeviceLocationPermission.denied;
  }
}

class _StreamingGateway implements DrivingLocationGateway {
  final _controller = StreamController<DrivingPoint>();

  void add(DrivingPoint point) {
    _controller.add(point);
  }

  @override
  Future<DeviceLocationPermission> checkPermission() async {
    return DeviceLocationPermission.granted;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Stream<DrivingPoint> positionStream() {
    return _controller.stream;
  }

  @override
  Future<DeviceLocationPermission> requestPermission() async {
    return DeviceLocationPermission.granted;
  }
}

class _ControlledErrorGateway implements DrivingLocationGateway {
  _ControlledErrorGateway(this.stages);

  final List<String> stages;
  final Completer<void> _listening = Completer<void>();
  late final StreamController<DrivingPoint> _controller =
      StreamController<DrivingPoint>(
        onListen: () {
          stages.add('stream:onListen');
          if (!_listening.isCompleted) _listening.complete();
        },
        onCancel: () {
          stages.add('stream:onCancel');
        },
      );

  Future<void> get whenListening => _listening.future.timeout(
    const Duration(seconds: 5),
    onTimeout: () => throw TestFailure(
      'Timed out waiting for stream onListen. stages=$stages',
    ),
  );

  void emitError() {
    stages.add('stream:addError');
    _controller.addError(StateError('GPS unavailable'));
  }

  Future<void> close() => _controller.close();

  @override
  Future<DeviceLocationPermission> checkPermission() async =>
      DeviceLocationPermission.granted;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Stream<DrivingPoint> positionStream() => _controller.stream;

  @override
  Future<DeviceLocationPermission> requestPermission() async =>
      DeviceLocationPermission.granted;
}

class _ObservedFeedbackGateway extends _NoopDrivingFeedbackGateway {
  _ObservedFeedbackGateway(this.stages);

  final List<String> stages;

  @override
  Future<void> setKeepScreenOn(bool enabled) async {
    stages.add('feedback:screen:$enabled');
  }

  @override
  Future<void> stopOngoingFeedback() async {
    stages.add('feedback:stop');
  }
}

class _LocationErrorDrivingController extends DrivingController {
  @override
  Future<DrivingState> build() async => const DrivingState(
    status: DrivingSessionStatus.locationUnavailable,
    preferences: defaultDrivingPreferences,
    cameraCount: 0,
    cameraSpeedKnownCount: 0,
    errorMessage: 'No se pudo leer la ubicación en tiempo real.',
  );
}

class _LabelledDrivingController extends DrivingController {
  void labelSimulation() {
    state = AsyncData(
      state.requireValue.copyWith(simulationName: 'Con velocidad'),
    );
  }
}
