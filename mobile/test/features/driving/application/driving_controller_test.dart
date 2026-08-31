import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/features/driving/application/driving_controller.dart';
import 'package:picoradar/features/driving/data/camera_pack_loader.dart';
import 'package:picoradar/features/driving/domain/camera_matcher.dart';
import 'package:picoradar/features/driving/domain/traffic_camera.dart';
import 'package:picoradar/features/driving/platform/driving_location_gateway.dart';
import 'package:picoradar/features/location/platform/device_location_gateway.dart';

import '../../../test_app_harness.dart';

void main() {
  test(
    'requests location only when the driver starts a foreground session',
    () async {
      final gateway = _FakeDrivingLocationGateway();
      final container = ProviderContainer(
        overrides: [
          appPreferencesProvider.overrideWithValue(MemoryPreferences()),
          cameraPackProvider.overrideWith((ref) async => _pack()),
          drivingLocationGatewayProvider.overrideWithValue(gateway),
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

      gateway.add(
        DrivingPoint(
          latitude: 6.241,
          longitude: -75.57,
          accuracyMeters: 14,
          speedKmh: 42,
          headingDegrees: 0,
          recordedAt: DateTime.utc(2026, 8, 31, 12),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(drivingControllerProvider).value!;
      expect(state.nearestCamera, isNotNull);
      expect(state.speedKmh, 42);

      await container.read(drivingControllerProvider.notifier).stop();
      expect(gateway.cancelled, isTrue);
      expect(
        container.read(drivingControllerProvider).value!.status,
        DrivingSessionStatus.idle,
      );
    },
  );
}

CameraPack _pack() {
  return CameraPack(
    source: const CameraPackSource(
      name: 'ANSV',
      pageUrl: 'https://fotodeteccion.ansv.gov.co/ubicaciones-aprobadas.html',
      dataUrl: 'https://fotodeteccion.ansv.gov.co/map/data/sast.json',
      fetchedAtUtc: '2026-08-31T00:00:00Z',
    ),
    cameras: [
      const TrafficCamera(
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
        speedLimitKmh: 60,
      ),
    ],
  );
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
