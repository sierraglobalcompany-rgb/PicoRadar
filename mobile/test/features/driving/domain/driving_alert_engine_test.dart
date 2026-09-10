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
    expect(first!.thresholdMeters, 300);
    expect(repeated, isNull);
  });

  test('a GPS jump from 520 to 180 meters only announces 200 meters', () {
    final engine = DrivingAlertEngine(profile: DrivingAlertProfile.detailed);
    final camera = _camera(speedLimitKmh: null);

    final outside = engine.evaluate(
      match: CameraMatch(
        camera: camera,
        distanceMeters: 520,
        approaching: true,
        bearingDifferenceDegrees: 0,
      ),
      speedKmh: 36,
      now: DateTime.utc(2026, 8, 31, 12),
    );
    final jumped = engine.evaluate(
      match: CameraMatch(
        camera: camera,
        distanceMeters: 180,
        approaching: true,
        bearingDifferenceDegrees: 0,
      ),
      speedKmh: 36,
      now: DateTime.utc(2026, 8, 31, 12, 0, 5),
    );

    expect(outside, isNull);
    expect(jumped!.thresholdMeters, 200);
  });

  test(
    'cooldown consumes crossed thresholds instead of delaying stale alerts',
    () {
      final engine = DrivingAlertEngine(profile: DrivingAlertProfile.normal);
      final camera = _camera(speedLimitKmh: null);

      final first = engine.evaluate(
        match: CameraMatch(
          camera: camera,
          distanceMeters: 480,
          approaching: true,
          bearingDifferenceDegrees: 0,
        ),
        speedKmh: 36,
        now: DateTime.utc(2026, 8, 31, 12),
      );
      final suppressed = engine.evaluate(
        match: CameraMatch(
          camera: camera,
          distanceMeters: 180,
          approaching: true,
          bearingDifferenceDegrees: 0,
        ),
        speedKmh: 36,
        now: DateTime.utc(2026, 8, 31, 12, 0, 5),
      );
      final nextFresh = engine.evaluate(
        match: CameraMatch(
          camera: camera,
          distanceMeters: 90,
          approaching: true,
          bearingDifferenceDegrees: 0,
        ),
        speedKmh: 36,
        now: DateTime.utc(2026, 8, 31, 12, 0, 20),
      );

      expect(first!.thresholdMeters, 500);
      expect(suppressed, isNull);
      expect(nextFresh!.thresholdMeters, 100);
    },
  );

  test('camera episode closes and rearms after a real second approach', () {
    final engine = DrivingAlertEngine(profile: DrivingAlertProfile.detailed);
    final camera = _camera(speedLimitKmh: null);

    final firstApproach = engine.evaluate(
      match: CameraMatch(
        camera: camera,
        distanceMeters: 180,
        approaching: true,
        bearingDifferenceDegrees: 0,
      ),
      speedKmh: 36,
      now: DateTime.utc(2026, 8, 31, 12),
    );
    engine.markNoMatch(DateTime.utc(2026, 8, 31, 12, 0, 31));
    final secondApproach = engine.evaluate(
      match: CameraMatch(
        camera: camera,
        distanceMeters: 180,
        approaching: true,
        bearingDifferenceDegrees: 0,
      ),
      speedKmh: 36,
      now: DateTime.utc(2026, 8, 31, 12, 0, 32),
    );

    expect(firstApproach!.thresholdMeters, 200);
    expect(secondApproach!.thresholdMeters, 200);
  });

  test(
    'expired episode purges before a direct valid match without no-match',
    () {
      final engine = DrivingAlertEngine(profile: DrivingAlertProfile.detailed);
      final camera = _camera(speedLimitKmh: null);

      final firstApproach = engine.evaluate(
        match: CameraMatch(
          camera: camera,
          distanceMeters: 180,
          approaching: true,
          bearingDifferenceDegrees: 0,
        ),
        speedKmh: 36,
        now: DateTime.utc(2026, 8, 31, 12),
      );
      final directSecondApproach = engine.evaluate(
        match: CameraMatch(
          camera: camera,
          distanceMeters: 180,
          approaching: true,
          bearingDifferenceDegrees: 0,
        ),
        speedKmh: 36,
        now: DateTime.utc(2026, 8, 31, 12, 0, 31),
      );

      expect(firstApproach!.thresholdMeters, 200);
      expect(directSecondApproach!.thresholdMeters, 200);
    },
  );

  test('ANSV amounts remain metadata and never produce overspeed', () {
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

    expect(withLimit!.overspeed, isFalse);
    expect(withLimit.title, 'Cámara cerca');
    expect(
      withLimit.message,
      'Cámara a 100 metros. Respeta la señalización de la vía.',
    );
    expect(withLimit.currentSpeedKmh, 50);
    expect(withLimit.reportedSpeedKmh, 40);
    expect(withoutLimit!.overspeed, isFalse);
    expect(withoutLimit.reportedSpeedKmh, isNull);
  });

  test('no speed delta can enable an ANSV overspeed alert', () {
    final camera = _camera(speedLimitKmh: 60);

    bool overspeedAt(double speed) {
      return DrivingAlertEngine()
          .evaluate(
            match: CameraMatch(
              camera: camera,
              distanceMeters: 90,
              approaching: true,
              bearingDifferenceDegrees: 0,
            ),
            speedKmh: speed,
            now: DateTime.utc(2026, 8, 31, 12),
          )!
          .overspeed;
    }

    expect(overspeedAt(50), isFalse);
    expect(overspeedAt(60), isFalse);
    expect(overspeedAt(62), isFalse);
    expect(overspeedAt(70), isFalse);
    expect(overspeedAt(150), isFalse);
  });

  test('null and red light without speed never claim overspeed', () {
    final nullLimit = DrivingAlertEngine().evaluate(
      match: CameraMatch(
        camera: _camera(speedLimitKmh: null),
        distanceMeters: 90,
        approaching: true,
        bearingDifferenceDegrees: 0,
      ),
      speedKmh: 100,
      now: DateTime.utc(2026, 8, 31, 12),
    );
    final redLightOnly = DrivingAlertEngine().evaluate(
      match: CameraMatch(
        camera: _camera(speedLimitKmh: null, kind: CameraKind.redLight),
        distanceMeters: 90,
        approaching: true,
        bearingDifferenceDegrees: 0,
      ),
      speedKmh: 100,
      now: DateTime.utc(2026, 8, 31, 12),
    );

    expect(nullLimit!.overspeed, isFalse);
    expect(redLightOnly!.overspeed, isFalse);
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

  test('custom profile uses only owner-approved thresholds', () {
    final engine = DrivingAlertEngine(
      profile: DrivingAlertProfile.custom,
      customThresholdsMeters: const [400, 250, 50],
    );

    final first = engine.evaluate(
      match: CameraMatch(
        camera: _camera(speedLimitKmh: null),
        distanceMeters: 390,
        approaching: true,
        bearingDifferenceDegrees: 0,
      ),
      speedKmh: 36,
      now: DateTime.utc(2026, 8, 31, 12),
    );
    final unsupported = engine.evaluate(
      match: CameraMatch(
        camera: _camera(speedLimitKmh: null),
        distanceMeters: 240,
        approaching: true,
        bearingDifferenceDegrees: 0,
      ),
      speedKmh: 36,
      now: DateTime.utc(2026, 8, 31, 12, 0, 5),
    );
    final finalStage = engine.evaluate(
      match: CameraMatch(
        camera: _camera(speedLimitKmh: null),
        distanceMeters: 45,
        approaching: true,
        bearingDifferenceDegrees: 0,
      ),
      speedKmh: 36,
      now: DateTime.utc(2026, 8, 31, 12, 2),
    );

    expect(first!.thresholdMeters, 400);
    expect(unsupported, isNull);
    expect(finalStage!.thresholdMeters, 50);
  });
}

TrafficCamera _camera({
  required int? speedLimitKmh,
  CameraKind kind = CameraKind.mixed,
}) {
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
    kind: kind,
    speedLimitKmh: speedLimitKmh,
  );
}
