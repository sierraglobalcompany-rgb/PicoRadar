import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/features/driving/application/driving_controller.dart';
import 'package:picoradar/features/driving/data/camera_pack_loader.dart';
import 'package:picoradar/features/driving/domain/camera_matcher.dart';
import 'package:picoradar/features/driving/domain/traffic_camera.dart';
import 'package:picoradar/features/driving/platform/driving_feedback_gateway.dart';
import 'package:picoradar/features/driving/platform/driving_location_gateway.dart';
import 'package:picoradar/features/driving/presentation/driving_screen.dart';
import 'package:picoradar/features/location/platform/device_location_gateway.dart';

import '../../../test_app_harness.dart';

void main() {
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
        ],
        child: const MaterialApp(home: DrivingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ready-speed-coverage')), findsOneWidget);
    expect(find.byKey(const ValueKey('start-driving')), findsOneWidget);
    expect(find.textContaining('No se guarda recorrido'), findsOneWidget);
    expect(gateway.requestPermissionCalls, 0);
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
  });

  testWidgets('settings expose custom thresholds from the approved set', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
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
    await tester.tap(find.text('Personalizado'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('custom-alert-500')), findsOneWidget);
    expect(find.byKey(const ValueKey('custom-alert-400')), findsOneWidget);
    expect(find.byKey(const ValueKey('custom-alert-300')), findsOneWidget);
    expect(find.byKey(const ValueKey('custom-alert-200')), findsOneWidget);
    expect(find.byKey(const ValueKey('custom-alert-100')), findsOneWidget);
    expect(find.byKey(const ValueKey('custom-alert-50')), findsOneWidget);
    expect(find.text('250 m'), findsNothing);
    expect(find.textContaining('Datos ANSV'), findsOneWidget);
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

  testWidgets('authorized wording is shown for approved camera source', (
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
    gateway.add(_point(latitude: 6.241, seconds: 20, speedKmh: 0));
    await tester.pump();

    expect(find.text('Fotodeteccion autorizada'), findsOneWidget);
  });

  testWidgets('known camera speed shows sign, distance, status, and delta', (
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
    gateway.add(_point(latitude: 6.239, seconds: 0, speedKmh: 50));
    await tester.pump();
    gateway.add(_point(latitude: 6.241, seconds: 20, speedKmh: 70));
    await tester.pump();

    expect(find.byKey(const ValueKey('driving-speed-gauge')), findsOneWidget);
    expect(find.byKey(const ValueKey('camera-speed-sign')), findsOneWidget);
    expect(find.byKey(const ValueKey('camera-distance-pill')), findsOneWidget);
    expect(find.text('60 km/h'), findsWidgets);
    expect(find.textContaining('Reduce velocidad'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('driving-overspeed-delta')),
      findsOneWidget,
    );
    expect(find.text('+10 km/h'), findsOneWidget);
  });

  testWidgets(
    'unknown camera speed omits speed sign and avoids overspeed claim',
    (tester) async {
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
      gateway.add(_point(latitude: 6.239, seconds: 0, speedKmh: 100));
      await tester.pump();
      gateway.add(_point(latitude: 6.241, seconds: 20, speedKmh: 100));
      await tester.pump();

      expect(find.byKey(const ValueKey('camera-speed-sign')), findsNothing);
      expect(find.text('No publicada'), findsOneWidget);
      expect(find.textContaining('Reduce velocidad'), findsNothing);
      expect(
        find.byKey(const ValueKey('driving-overspeed-delta')),
        findsNothing,
      );
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
    expect(find.byKey(const ValueKey('hud-camera-speed-sign')), findsOneWidget);
    expect(find.textContaining('Camara'), findsOneWidget);
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
    expect(find.text('Velocidad no publicada'), findsOneWidget);
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
  Future<void> vibrate() async {}
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

CameraPack _pack({int? speedLimitKmh = 60}) {
  return CameraPack(
    source: const CameraPackSource(
      name: 'ANSV',
      pageUrl: 'https://fotodeteccion.ansv.gov.co/ubicaciones-aprobadas.html',
      dataUrl: 'https://fotodeteccion.ansv.gov.co/map/data/sast.json',
      fetchedAtUtc: '2026-08-31T00:00:00Z',
    ),
    cameras: [
      TrafficCamera(
        id: 'cam-1',
        department: 'ANTIOQUIA',
        municipality: 'MEDELLIN',
        jurisdiction: 'Municipal',
        address: 'Avenida 80',
        latitude: 6.244,
        longitude: -75.57,
        status: 'Aprobada',
        technology: 'Camara',
        kind: CameraKind.mixed,
        speedLimitKmh: speedLimitKmh,
      ),
    ],
  );
}

DrivingPoint _point({
  required double latitude,
  required int seconds,
  double speedKmh = 42,
}) {
  return DrivingPoint(
    latitude: latitude,
    longitude: -75.57,
    accuracyMeters: 12,
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
