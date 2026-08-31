import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/features/driving/application/driving_controller.dart';
import 'package:picoradar/features/driving/data/camera_pack_loader.dart';
import 'package:picoradar/features/driving/domain/camera_matcher.dart';
import 'package:picoradar/features/driving/domain/traffic_camera.dart';
import 'package:picoradar/features/driving/platform/driving_feedback_gateway.dart';
import 'package:picoradar/features/driving/platform/driving_location_gateway.dart';
import 'package:picoradar/features/location/platform/device_location_gateway.dart';

import '../../../test_app_harness.dart';

void main() {
  test(
    'requests location only when the driver starts a foreground session',
    () async {
      final gateway = _FakeDrivingLocationGateway();
      final feedback = _FakeDrivingFeedbackGateway();
      final container = ProviderContainer(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(feedback),
        ],
      );
      addTearDown(container.dispose);

      await container.read(drivingControllerProvider.future);
      expect(gateway.requestPermissionCalls, 0);

      await container.read(drivingControllerProvider.notifier).start();
      expect(gateway.requestPermissionCalls, 1);
      expect(
        container.read(drivingControllerProvider).value!.status,
        DrivingSessionStatus.active,
      );
      expect(feedback.keepScreenOnStates, [true]);

      gateway.add(
        DrivingPoint(
          latitude: 6.239,
          longitude: -75.57,
          accuracyMeters: 14,
          speedKmh: 42,
          headingDegrees: 0,
          recordedAt: DateTime.utc(2026, 8, 31, 12),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      gateway.add(
        DrivingPoint(
          latitude: 6.241,
          longitude: -75.57,
          accuracyMeters: 14,
          speedKmh: 42,
          headingDegrees: 0,
          recordedAt: DateTime.utc(2026, 8, 31, 12, 1),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(drivingControllerProvider).value!;
      expect(state.nearestCamera, isNotNull);
      expect(state.speedKmh, 42);
      expect(state.speedState, DrivingSpeedState.within);
      expect(feedback.spokenMessages.single, contains('500 metros'));
      expect(feedback.spokenMessages.single, contains('Velocidad reportada'));
      expect(feedback.soundCalls, 1);
      expect(feedback.vibrationCalls, 1);

      await container.read(drivingControllerProvider.notifier).stop();
      expect(gateway.cancelled, isTrue);
      expect(feedback.keepScreenOnStates, [true, false]);
      expect(
        container.read(drivingControllerProvider).value!.status,
        DrivingSessionStatus.idle,
      );
    },
  );

  test('first movement sample does not emit a camera alert', () async {
    final gateway = _FakeDrivingLocationGateway();
    final feedback = _FakeDrivingFeedbackGateway();
    final container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(MemoryPreferences()),
        cameraPackProvider.overrideWith((ref) async => _pack()),
        drivingLocationGatewayProvider.overrideWithValue(gateway),
        drivingFeedbackGatewayProvider.overrideWithValue(feedback),
      ],
    );
    addTearDown(container.dispose);

    await container.read(drivingControllerProvider.notifier).start();
    gateway.add(
      DrivingPoint(
        latitude: 6.2434,
        longitude: -75.57,
        accuracyMeters: 14,
        speedKmh: 42,
        headingDegrees: 0,
        recordedAt: DateTime.utc(2026, 8, 31, 12),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final state = container.read(drivingControllerProvider).value!;
    expect(state.nearestCamera, isNull);
    expect(state.lastAlert, isNull);
    expect(feedback.spokenMessages, isEmpty);
  });

  test(
    'poor GPS accuracy keeps speed but blocks camera alert stages',
    () async {
      final gateway = _FakeDrivingLocationGateway();
      final feedback = _FakeDrivingFeedbackGateway();
      final container = ProviderContainer(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(feedback),
        ],
      );
      addTearDown(container.dispose);

      await container.read(drivingControllerProvider.notifier).start();
      for (final latitude in [6.241, 6.242]) {
        gateway.add(
          DrivingPoint(
            latitude: latitude,
            longitude: -75.57,
            accuracyMeters: 90,
            speedKmh: 42,
            headingDegrees: 0,
            recordedAt: DateTime.utc(
              2026,
              8,
              31,
              12,
              latitude == 6.241 ? 0 : 1,
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);
      }

      final state = container.read(drivingControllerProvider).value!;
      expect(state.speedKmh, 42);
      expect(state.gpsQuality, GpsQuality.weak);
      expect(state.nearestCamera, isNull);
      expect(state.lastAlert, isNull);
      expect(feedback.spokenMessages, isEmpty);
    },
  );

  test(
    'continuous speed state updates while the camera episode persists',
    () async {
      final gateway = _FakeDrivingLocationGateway();
      final feedback = _FakeDrivingFeedbackGateway();
      final container = ProviderContainer(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
          drivingFeedbackGatewayProvider.overrideWithValue(feedback),
        ],
      );
      addTearDown(container.dispose);

      await container.read(drivingControllerProvider.notifier).start();
      gateway.add(_point(latitude: 6.239, speedKmh: 50, seconds: 0));
      await Future<void>.delayed(Duration.zero);
      gateway.add(_point(latitude: 6.241, speedKmh: 50, seconds: 20));
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(drivingControllerProvider).value!.speedState,
        DrivingSpeedState.within,
      );

      gateway.add(_point(latitude: 6.242, speedKmh: 70, seconds: 21));
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(drivingControllerProvider).value!.speedState,
        DrivingSpeedState.over,
      );

      gateway.add(_point(latitude: 6.243, speedKmh: 54, seconds: 22));
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(drivingControllerProvider).value!.speedState,
        DrivingSpeedState.within,
      );
    },
  );

  test('unknown reported speed keeps comparison fail-closed', () async {
    final gateway = _FakeDrivingLocationGateway();
    final feedback = _FakeDrivingFeedbackGateway();
    final container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(MemoryPreferences()),
        cameraPackProvider.overrideWith(
          (ref) async => _pack(speedLimitKmh: null),
        ),
        drivingLocationGatewayProvider.overrideWithValue(gateway),
        drivingFeedbackGatewayProvider.overrideWithValue(feedback),
      ],
    );
    addTearDown(container.dispose);

    await container.read(drivingControllerProvider.notifier).start();
    gateway.add(_point(latitude: 6.239, speedKmh: 100, seconds: 0));
    await Future<void>.delayed(Duration.zero);
    gateway.add(_point(latitude: 6.241, speedKmh: 100, seconds: 20));
    await Future<void>.delayed(Duration.zero);

    final state = container.read(drivingControllerProvider).value!;
    expect(state.speedState, DrivingSpeedState.unknownReportedSpeed);
    expect(state.isOverspeeding, isFalse);
    expect(
      feedback.spokenMessages.single,
      isNot(contains('Velocidad reportada')),
    );
  });

  test(
    'overspeed pulse gate fires only on transition and respects reduced motion',
    () {
      final gate = OverspeedPulseGate();

      expect(
        gate.shouldPulse(
          current: DrivingSpeedState.within,
          reducedMotion: false,
        ),
        isFalse,
      );
      expect(
        gate.shouldPulse(current: DrivingSpeedState.over, reducedMotion: false),
        isTrue,
      );
      expect(
        gate.shouldPulse(current: DrivingSpeedState.over, reducedMotion: false),
        isFalse,
      );
      expect(
        gate.shouldPulse(
          current: DrivingSpeedState.within,
          reducedMotion: false,
        ),
        isFalse,
      );
      expect(
        gate.shouldPulse(current: DrivingSpeedState.over, reducedMotion: true),
        isFalse,
      );
    },
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
  required double speedKmh,
  required int seconds,
}) {
  return DrivingPoint(
    latitude: latitude,
    longitude: -75.57,
    accuracyMeters: 14,
    speedKmh: speedKmh,
    headingDegrees: 0,
    recordedAt: DateTime.utc(2026, 8, 31, 12, 0, seconds),
  );
}

class _FakeDrivingFeedbackGateway implements DrivingFeedbackGateway {
  final spokenMessages = <String>[];
  final keepScreenOnStates = <bool>[];
  var soundCalls = 0;
  var vibrationCalls = 0;

  @override
  Future<void> playSound() async {
    soundCalls += 1;
  }

  @override
  Future<void> setKeepScreenOn(bool enabled) async {
    keepScreenOnStates.add(enabled);
  }

  @override
  Future<void> speak(String message) async {
    spokenMessages.add(message);
  }

  @override
  Future<void> vibrate() async {
    vibrationCalls += 1;
  }
}

class _FakeDrivingLocationGateway implements DrivingLocationGateway {
  final _controller = StreamController<DrivingPoint>();
  var requestPermissionCalls = 0;
  var cancelled = false;

  void add(DrivingPoint point) {
    _controller.add(point);
  }

  @override
  Future<DeviceLocationPermission> checkPermission() async {
    return DeviceLocationPermission.denied;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Stream<DrivingPoint> positionStream() {
    return _controller.stream.map((point) => point).doOnCancel(() {
      cancelled = true;
    });
  }

  @override
  Future<DeviceLocationPermission> requestPermission() async {
    requestPermissionCalls += 1;
    return DeviceLocationPermission.granted;
  }
}

extension _CancelAwareStream<T> on Stream<T> {
  Stream<T> doOnCancel(void Function() onCancel) {
    late StreamController<T> controller;
    StreamSubscription<T>? subscription;
    controller = StreamController<T>(
      onListen: () {
        subscription = listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
      },
      onCancel: () async {
        onCancel();
        await subscription?.cancel();
      },
    );
    return controller.stream;
  }
}
