import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/driving/domain/camera_matcher.dart';
import 'package:picoradar/features/driving/domain/traffic_camera.dart';
import 'package:picoradar/features/driving/presentation/driving_radar.dart';

void main() {
  test('360 radar sweep rotates continuously clockwise', () {
    final start = drivingRadarSweepSnapshot(
      targetingConeDegrees: 360,
      progress: 0,
    );
    final quarter = drivingRadarSweepSnapshot(
      targetingConeDegrees: 360,
      progress: 0.25,
    );
    final threeQuarter = drivingRadarSweepSnapshot(
      targetingConeDegrees: 360,
      progress: 0.75,
    );

    expect(start.angleDegrees, 0);
    expect(quarter.angleDegrees, 90);
    expect(threeQuarter.angleDegrees, -90);
    expect(start.direction, 1);
    expect(quarter.direction, 1);
  });

  test('45, 90 and 180 radar sweeps remain inside selected cones', () {
    for (final cone in const [45, 90, 180]) {
      for (final progress in const [0.0, 0.25, 0.5, 0.75, 0.99]) {
        final snapshot = drivingRadarSweepSnapshot(
          targetingConeDegrees: cone,
          progress: progress,
        );

        expect(snapshot.angleDegrees.abs(), lessThanOrEqualTo(cone / 2));
      }
    }
  });

  test('camera echo activates only around bearing crossing', () {
    final crossing = drivingRadarSweepSnapshot(
      targetingConeDegrees: 360,
      progress: 45 / 360,
      relativeBearingDegrees: 45,
    );
    final away = drivingRadarSweepSnapshot(
      targetingConeDegrees: 360,
      progress: 135 / 360,
      relativeBearingDegrees: 45,
    );

    expect(crossing.echoIntensity, greaterThan(0.9));
    expect(away.echoIntensity, 0);
  });

  test('reduced motion renders a static sweep without periodic echo', () {
    final first = drivingRadarSweepSnapshot(
      targetingConeDegrees: 90,
      progress: 0,
      relativeBearingDegrees: 32,
      reducedMotion: true,
    );
    final later = drivingRadarSweepSnapshot(
      targetingConeDegrees: 90,
      progress: 0.8,
      relativeBearingDegrees: 32,
      reducedMotion: true,
    );

    expect(first.angleDegrees, later.angleDegrees);
    expect(first.angleDegrees, 32);
    expect(first.echoIntensity, 0);
    expect(later.echoIntensity, 0);
  });

  test(
    'camera point scales with radar range and reaches origin only near 5 m',
    () {
      const size = Size(180, 156);
      final user = Offset(size.width / 2, size.height * 0.68);
      final near = radarCameraPoint(
        size: size,
        user: user,
        match: _match(distanceMeters: 45, relativeBearingDegrees: 0),
        radarRadius: 65,
        radarRangeMeters: radarRangeForCameraDistance(45),
      );
      final almostOnTop = radarCameraPoint(
        size: size,
        user: user,
        match: _match(distanceMeters: 5, relativeBearingDegrees: 0),
        radarRadius: 65,
        radarRangeMeters: radarRangeForCameraDistance(5),
      );
      final far = radarCameraPoint(
        size: size,
        user: user,
        match: _match(distanceMeters: 500, relativeBearingDegrees: 90),
        radarRadius: 65,
        radarRangeMeters: radarRangeForCameraDistance(500),
      );

      expect((near.dy - user.dy).abs(), greaterThan(28));
      expect(almostOnTop, user);
      expect(far.dx, greaterThan(user.dx + 40));
    },
  );

  testWidgets('radar painter animation advances when motion is enabled', (
    tester,
  ) async {
    await tester.pumpWidget(_radarHost());
    await tester.pump();
    final first = _painter(tester).sweepAnimation!.value;

    await tester.pump(const Duration(milliseconds: 350));
    final second = _painter(tester).sweepAnimation!.value;

    expect(second, isNot(first));
  });

  testWidgets(
    'radar painter disconnects animation when TickerMode is disabled',
    (tester) async {
      await tester.pumpWidget(TickerMode(enabled: false, child: _radarHost()));
      await tester.pump();

      expect(_painter(tester).sweepAnimation, isNull);
    },
  );

  testWidgets('radar view respects reduced motion', (tester) async {
    await tester.pumpWidget(_radarHost(forceReducedMotionForTesting: true));
    await tester.pump();

    final painter = _painter(tester);
    expect(painter.reducedMotion, isTrue);
    expect(painter.sweepAnimation, isNull);
  });
}

DrivingRadarPainter _painter(WidgetTester tester) {
  return tester
          .widget<CustomPaint>(
            find.byKey(const ValueKey('driving-radar-cone-90')),
          )
          .painter!
      as DrivingRadarPainter;
}

Widget _radarHost({bool forceReducedMotionForTesting = false}) {
  return MaterialApp(
    home: SizedBox(
      width: 180,
      height: 156,
      child: DrivingRadarView(
        match: _match(distanceMeters: 120, relativeBearingDegrees: 25),
        currentPoint: _point(),
        targetingConeDegrees: 90,
        alertColor: Colors.red,
        forceReducedMotionForTesting: forceReducedMotionForTesting,
      ),
    ),
  );
}

CameraMatch _match({
  required double distanceMeters,
  required double relativeBearingDegrees,
}) {
  return CameraMatch(
    camera: _camera(),
    distanceMeters: distanceMeters,
    approaching: true,
    bearingDifferenceDegrees: relativeBearingDegrees.abs(),
    relativeBearingDegrees: relativeBearingDegrees,
  );
}

TrafficCamera _camera() {
  return const TrafficCamera(
    id: 'cam-1',
    department: 'ANTIOQUIA',
    municipality: 'MEDELLIN',
    jurisdiction: 'Municipal',
    address: 'Avenida 80',
    latitude: 6.244,
    longitude: -75.57,
    status: 'Aprobada',
    technology: 'Cámara',
    kind: CameraKind.mixed,
    speedLimitKmh: 60,
  );
}

DrivingPoint _point() {
  return DrivingPoint(
    latitude: 6.241,
    longitude: -75.57,
    accuracyMeters: 12,
    speedKmh: 42,
    headingDegrees: 0,
    recordedAt: DateTime.utc(2026, 8, 31, 12),
  );
}
