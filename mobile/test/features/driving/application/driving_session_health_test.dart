import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/driving/application/driving_controller.dart';
import 'package:picoradar/features/driving/data/camera_pack_loader.dart';
import 'package:picoradar/features/driving/data/driving_preferences.dart';
import 'package:picoradar/features/driving/domain/camera_matcher.dart';
import 'package:picoradar/features/driving/domain/traffic_camera.dart';
import 'package:picoradar/features/driving/platform/driving_feedback_gateway.dart';
import 'package:picoradar/features/driving/platform/driving_location_gateway.dart';
import 'package:picoradar/features/location/platform/device_location_gateway.dart';

void main() {
  for (final stage in ['service', 'check', 'request', 'stream', 'screen']) {
    testWidgets('start failure at $stage cleans up and allows retry', (
      tester,
    ) async {
      final h = _Session();
      addTearDown(h.dispose);
      await h.container.read(drivingControllerProvider.future);
      h.location.failure = stage;
      h.feedback.failScreen = stage == 'screen';
      await expectLater(h.controller.start(), completes);
      expect(h.state.status, DrivingSessionStatus.locationUnavailable);
      expect(h.location.points.hasListener, isFalse);
      expect(h.feedback.screenOn, isFalse);
      h.location.failure = null;
      h.feedback.failScreen = false;
      await h.controller.start();
      expect(h.state.isActive, isTrue);
      expect(h.location.points.hasListener, isTrue);
    });
  }

  testWidgets(
    'silent GPS expires live values and recovers with a fresh baseline',
    (tester) async {
      final h = _Session();
      addTearDown(h.dispose);
      await h.container.read(drivingControllerProvider.future);
      await h.controller.start();
      h.location.points.add(
        _point(6.239, h.now.subtract(const Duration(seconds: 1))),
      );
      await tester.pump();
      h.location.points.add(_point(6.241, h.now));
      await tester.pump();
      expect(h.state.showCameraAlertPanel, isTrue);
      await tester.pump(const Duration(seconds: 16));
      h.now = h.now.add(const Duration(seconds: 16));
      expect(h.state.currentPoint, isNull);
      expect(h.state.canEvaluateAlerts, isFalse);
      expect(h.state.visualAlertPulseKey, isNull);
      expect(h.state.gpsQuality, isNot(GpsQuality.good));
      h.location.points.add(_point(6.242, h.now));
      await tester.pump();
      expect(h.state.currentPoint, isNotNull);
      expect(h.state.nearestCamera, isNull);
      expect(h.state.isActive, isTrue);
      await tester.runAsync(h.controller.stop);
    },
  );

  testWidgets('cached stale GPS sample cannot become live speed', (
    tester,
  ) async {
    final h = _Session();
    addTearDown(h.dispose);
    await h.container.read(drivingControllerProvider.future);
    await h.controller.start();
    h.location.points.add(
      _point(6.241, h.now.subtract(const Duration(minutes: 2))),
    );
    await tester.pump();
    expect(h.state.currentPoint, isNull);
    expect(h.state.canEvaluateAlerts, isFalse);
  });

  testWidgets('real GPS stream completion stops the session', (tester) async {
    final h = _Session();
    addTearDown(h.dispose);
    await h.container.read(drivingControllerProvider.future);
    await h.controller.start();
    await tester.runAsync(h.location.points.close);
    await tester.pump();
    expect(h.state.isActive, isFalse);
    expect(h.state.status, DrivingSessionStatus.locationUnavailable);
    expect(h.feedback.screenOn, isFalse);
  });

  testWidgets('sample age consumes the freshness budget', (tester) async {
    final h = _Session();
    addTearDown(h.dispose);
    await h.container.read(drivingControllerProvider.future);
    await h.controller.start();
    h.location.points.add(
      _point(6.241, h.now.subtract(const Duration(seconds: 12))),
    );
    await tester.pump();
    expect(h.state.currentPoint, isNotNull);
    await tester.pump(const Duration(seconds: 4));
    expect(h.state.currentPoint, isNull);
    await tester.runAsync(h.controller.stop);
  });

  testWidgets('future GPS timestamp cannot pin the live session', (
    tester,
  ) async {
    final h = _Session();
    addTearDown(h.dispose);
    await h.container.read(drivingControllerProvider.future);
    await h.controller.start();
    h.location.points.add(_point(6.241, h.now.add(const Duration(minutes: 1))));
    await tester.pump();
    expect(h.state.currentPoint, isNull);
    h.location.points.add(_point(6.241, h.now));
    await tester.pump();
    expect(h.state.currentPoint, isNotNull);
    await tester.runAsync(h.controller.stop);
  });
}

DrivingPoint _point(double latitude, DateTime time) => DrivingPoint(
  latitude: latitude,
  longitude: -75.57,
  accuracyMeters: 10,
  speedKmh: 50,
  headingDegrees: 0,
  recordedAt: time,
);

class _Session {
  _Session() {
    container = ProviderContainer(
      overrides: [
        drivingPreferencesProvider.overrideWith(
          (ref) async => defaultDrivingPreferences,
        ),
        cameraPackProvider.overrideWith(
          (ref) async => const CameraPack(
            source: CameraPackSource(
              name: 'Test',
              pageUrl: '',
              dataUrl: '',
              fetchedAtUtc: '',
            ),
            cameras: [
              TrafficCamera(
                id: 'test',
                department: null,
                municipality: null,
                jurisdiction: null,
                address: null,
                latitude: 6.244,
                longitude: -75.57,
                status: 'Aprobada',
                technology: null,
                kind: CameraKind.mixed,
                speedLimitKmh: null,
              ),
            ],
          ),
        ),
        drivingLocationGatewayProvider.overrideWithValue(location),
        drivingClockProvider.overrideWithValue(() => now),
        drivingFeedbackGatewayProvider.overrideWithValue(feedback),
      ],
    );
  }
  final location = _Location();
  DateTime now = DateTime.utc(2026, 9, 19, 12);
  final feedback = _Feedback();
  late final ProviderContainer container;
  DrivingController get controller =>
      container.read(drivingControllerProvider.notifier);
  DrivingState get state => container.read(drivingControllerProvider).value!;
  void dispose() => container.dispose();
}

class _Location implements DrivingLocationGateway {
  final points = StreamController<DrivingPoint>.broadcast();
  String? failure;
  void check(String stage) {
    if (failure == stage) throw StateError('Native failure');
  }

  @override
  Future<bool> isLocationServiceEnabled() async {
    check('service');
    return true;
  }

  @override
  Future<DeviceLocationPermission> checkPermission() async {
    check('check');
    return DeviceLocationPermission.denied;
  }

  @override
  Future<DeviceLocationPermission> requestPermission() async {
    check('request');
    return DeviceLocationPermission.granted;
  }

  @override
  Stream<DrivingPoint> positionStream() {
    check('stream');
    return points.stream;
  }
}

class _Feedback implements DrivingFeedbackGateway {
  bool screenOn = false;
  bool failScreen = false;
  @override
  Future<void> setKeepScreenOn(bool enabled) async {
    if (enabled && failScreen) throw StateError('Native screen failure');
    screenOn = enabled;
  }

  @override
  Future<void> speak(String message) async {}
  @override
  Future<void> stopOngoingFeedback() async {}
  @override
  Future<void> playSound() async {}
  @override
  Future<void> vibrate() async {}
}
