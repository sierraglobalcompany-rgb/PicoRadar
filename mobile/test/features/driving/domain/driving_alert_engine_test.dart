import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/driving/domain/camera_matcher.dart';
import 'package:picoradar/features/driving/domain/driving_alert_engine.dart';
import 'package:picoradar/features/driving/domain/traffic_camera.dart';

void main() {
  test('alerts once per threshold while approaching', () {
    final engine = DrivingAlertEngine(
      profile: DrivingAlertProfile.normal,
      now: DateTime.utc(2026, 8, 31, 12),
    );
    final match = CameraMatch(
      camera: _camera(speedLimitKmh: 60),
      distanceMeters: 290,
      approaching: true,
      bearingDifferenceDegrees: 10,
    );

    final first = engine.evaluate(match: match, speedKmh: 50);
    final repeated = engine.evaluate(match: match, speedKmh: 50);

    expect(first, isNotNull);
    expect(first!.thresholdMeters, 500);
    expect(repeated, isNull);
  });

  test('marks overspeed only when official speed limit is present', () {
    final engine = DrivingAlertEngine();

    final withLimit = engine.evaluate(
      match: CameraMatch(
        camera: _camera(speedLimitKmh: 40),
        distanceMeters: 90,
        approaching: true,
        bearingDifferenceDegrees: 0,
      ),
      speedKmh: 50,
      now: DateTime.utc(2026, 8, 31, 12),
    );

    final withoutLimit = DrivingAlertEngine().evaluate(
      match: CameraMatch(
        camera: _camera(speedLimitKmh: null),
        distanceMeters: 90,
        approaching: true,
        bearingDifferenceDegrees: 0,
      ),
      speedKmh: 90,
      now: DateTime.utc(2026, 8, 31, 12),
    );

    expect(withLimit!.overspeed, isTrue);
    expect(withoutLimit!.overspeed, isFalse);
  });

  test('stays quiet while stopped', () {
    final alert = DrivingAlertEngine().evaluate(
      match: CameraMatch(
        camera: _camera(speedLimitKmh: 60),
        distanceMeters: 90,
        approaching: true,
        bearingDifferenceDegrees: 0,
      ),
      speedKmh: 0,
    );

    expect(alert, isNull);
  });
}

TrafficCamera _camera({required int? speedLimitKmh}) {
  return TrafficCamera(
    id: 'cam-${speedLimitKmh ?? 'none'}',
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
  );
}
