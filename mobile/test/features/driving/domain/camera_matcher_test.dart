import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/driving/domain/camera_matcher.dart';
import 'package:picoradar/features/driving/domain/traffic_camera.dart';

void main() {
  test('matches an approaching camera using distance and heading', () {
    final camera = _camera(latitude: 6.244, longitude: -75.57);

    final match = matchNearestCamera(
      previous: _point(latitude: 6.238, longitude: -75.57, heading: 0),
      current: _point(latitude: 6.241, longitude: -75.57, heading: 0),
      cameras: [camera],
    );

    expect(match, isNotNull);
    expect(match!.camera.id, 'cam-1');
    expect(match.approaching, isTrue);
  });

  test('rejects nearby cameras when travel heading points away', () {
    final camera = _camera(latitude: 6.244, longitude: -75.57);

    final match = matchNearestCamera(
      current: _point(latitude: 6.241, longitude: -75.57, heading: 180),
      cameras: [camera],
    );

    expect(match, isNull);
  });

  test('rejects a camera that is close but getting farther away', () {
    final camera = _camera(latitude: 6.244, longitude: -75.57);

    final match = matchNearestCamera(
      previous: _point(latitude: 6.242, longitude: -75.57, heading: 0),
      current: _point(latitude: 6.240, longitude: -75.57, heading: 0),
      cameras: [camera],
    );

    expect(match, isNull);
  });
}

TrafficCamera _camera({required double latitude, required double longitude}) {
  return TrafficCamera(
    id: 'cam-1',
    department: 'ANTIOQUIA',
    municipality: 'MEDELLIN',
    jurisdiction: 'Municipal',
    address: 'Avenida 80',
    latitude: latitude,
    longitude: longitude,
    status: 'Aprobada',
    technology: 'Camara',
    kind: CameraKind.mixed,
    speedLimitKmh: 60,
  );
}

DrivingPoint _point({
  required double latitude,
  required double longitude,
  required double heading,
}) {
  return DrivingPoint(
    latitude: latitude,
    longitude: longitude,
    accuracyMeters: 12,
    speedKmh: 42,
    headingDegrees: heading,
    recordedAt: DateTime.utc(2026, 8, 31, 12),
  );
}
