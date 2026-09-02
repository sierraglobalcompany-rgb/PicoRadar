import 'dart:math' as math;

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

  test('rejects a camera outside the forward driving corridor', () {
    final camera = _camera(latitude: 6.2428, longitude: -75.5669);

    final match = matchNearestCamera(
      previous: _point(latitude: 6.239, longitude: -75.57, heading: 0),
      current: _point(latitude: 6.241, longitude: -75.57, heading: 0),
      cameras: [camera],
    );

    expect(match, isNull);
  });

  test('rejects a side-pass camera roughly 400 meters away', () {
    final camera = _camera(latitude: 6.244, longitude: -75.5664);

    final match = matchNearestCamera(
      previous: _point(latitude: 6.2393, longitude: -75.57, heading: 0),
      current: _point(latitude: 6.244, longitude: -75.57, heading: 0),
      cameras: [camera],
    );

    expect(match, isNull);
  });

  test('targeting cone does not bypass the road corridor gate', () {
    final camera = _camera(latitude: 6.244, longitude: -75.5664);
    final previous = _point(latitude: 6.2393, longitude: -75.57, heading: 0);
    final current = _point(latitude: 6.244, longitude: -75.57, heading: 0);

    final narrow = matchNearestCamera(
      previous: previous,
      current: current,
      cameras: [camera],
      targetingConeDegrees: 45,
    );
    final wideButOffCorridor = matchNearestCamera(
      previous: previous,
      current: current,
      cameras: [camera],
      targetingConeDegrees: 180,
    );
    final aroundButOffCorridor = matchNearestCamera(
      previous: previous,
      current: current,
      cameras: [camera],
      targetingConeDegrees: 360,
    );

    expect(narrow, isNull);
    expect(wideButOffCorridor, isNull);
    expect(aroundButOffCorridor, isNull);
    expect(
      isRelativeBearingInsideTargetingCone(
        relativeBearingDegrees: 90,
        targetingConeDegrees: 180,
      ),
      isTrue,
    );
    expect(
      isRelativeBearingInsideTargetingCone(
        relativeBearingDegrees: 90,
        targetingConeDegrees: 360,
      ),
      isTrue,
    );
  });

  test('45 degree cone accepts 20 degrees and rejects 30 degrees', () {
    final current = _point(latitude: 6.241, longitude: -75.57, heading: 0);
    final previous = _point(latitude: 6.2405, longitude: -75.57, heading: 0);

    final accepted = matchNearestCamera(
      previous: previous,
      current: current,
      cameras: [
        _cameraAtBearingDistance(
          current: current,
          bearingDegrees: 20,
          distanceMeters: 240,
        ),
      ],
      targetingConeDegrees: 45,
    );
    final rejected = matchNearestCamera(
      previous: previous,
      current: current,
      cameras: [
        _cameraAtBearingDistance(
          current: current,
          bearingDegrees: 30,
          distanceMeters: 240,
        ),
      ],
      targetingConeDegrees: 45,
    );

    expect(accepted, isNotNull);
    expect(rejected, isNull);
  });

  test('90 degree cone accepts 40 degrees and rejects 60 degrees', () {
    final current = _point(latitude: 6.241, longitude: -75.57, heading: 0);
    final previous = _point(latitude: 6.2405, longitude: -75.57, heading: 0);

    final accepted = matchNearestCamera(
      previous: previous,
      current: current,
      cameras: [
        _cameraAtBearingDistance(
          current: current,
          bearingDegrees: 40,
          distanceMeters: 240,
        ),
      ],
      targetingConeDegrees: 90,
    );
    final rejected = matchNearestCamera(
      previous: previous,
      current: current,
      cameras: [
        _cameraAtBearingDistance(
          current: current,
          bearingDegrees: 60,
          distanceMeters: 240,
        ),
      ],
      targetingConeDegrees: 90,
    );

    expect(accepted, isNotNull);
    expect(rejected, isNull);
  });

  test('180 degree angular gate accepts 80 degrees and rejects behind', () {
    expect(
      isRelativeBearingInsideTargetingCone(
        relativeBearingDegrees: 80,
        targetingConeDegrees: 180,
      ),
      isTrue,
    );
    expect(
      isRelativeBearingInsideTargetingCone(
        relativeBearingDegrees: 120,
        targetingConeDegrees: 180,
      ),
      isFalse,
    );
  });

  test('360 degree angular gate allows every relative bearing', () {
    for (final bearing in [-180.0, -120.0, 0.0, 150.0, 180.0]) {
      expect(
        isRelativeBearingInsideTargetingCone(
          relativeBearingDegrees: bearing,
          targetingConeDegrees: 360,
        ),
        isTrue,
      );
    }
  });

  test(
    '360 degree cone allows side bearing but still rejects receding target',
    () {
      final camera = _camera(latitude: 6.244, longitude: -75.57);
      final approachingPrevious = _pointBehindCamera(
        camera: camera,
        bearingDegrees: 150,
        distanceMeters: 300,
      );
      final current = _pointBehindCamera(
        camera: camera,
        bearingDegrees: 150,
        distanceMeters: 240,
      );
      final recedingPrevious = _pointBehindCamera(
        camera: camera,
        bearingDegrees: 150,
        distanceMeters: 180,
      );

      final accepted = matchNearestCamera(
        previous: approachingPrevious,
        current: current,
        cameras: [camera],
        targetingConeDegrees: 360,
      );
      final rejected = matchNearestCamera(
        previous: recedingPrevious,
        current: current,
        cameras: [camera],
        targetingConeDegrees: 360,
      );

      expect(accepted, isNotNull);
      expect(accepted!.relativeBearingDegrees, closeTo(150, 1));
      expect(rejected, isNull);
    },
  );

  test('180 degree cone excludes a 150 degree rear-side camera', () {
    final current = _point(latitude: 6.241, longitude: -75.57, heading: 0);
    final camera = _cameraAtBearingDistance(
      current: current,
      bearingDegrees: 150,
      distanceMeters: 300,
    );

    final frontHemisphere = matchNearestCamera(
      current: current,
      cameras: [camera],
      targetingConeDegrees: 180,
    );
    final fullRadar = matchNearestCamera(
      current: current,
      cameras: [camera],
      targetingConeDegrees: 360,
    );

    expect(frontHemisphere, isNull);
    expect(fullRadar, isNull);
    expect(
      isRelativeBearingInsideTargetingCone(
        relativeBearingDegrees: 150,
        targetingConeDegrees: 360,
      ),
      isTrue,
    );
  });

  test('keeps close curve cameras visible inside the driving corridor', () {
    final current = _point(latitude: 6.241, longitude: -75.57, heading: 0);
    final camera = _cameraAtBearingDistance(
      current: current,
      bearingDegrees: 20,
      distanceMeters: 100,
    );

    final match = matchNearestCamera(current: current, cameras: [camera]);

    expect(match, isNotNull);
    expect(match!.distanceMeters, lessThan(cameraNearRadiusMeters));
    expect(match.crossTrackMeters, lessThan(cameraMaxCrossTrackMeters));
  });

  test(
    'suppresses a 500 meter lateral camera until it enters the corridor',
    () {
      final camera = _camera(latitude: 6.244, longitude: -75.57);
      final previous = _pointBehindCamera(
        camera: camera,
        bearingDegrees: 65,
        distanceMeters: 560,
      );
      final lateral = _pointBehindCamera(
        camera: camera,
        bearingDegrees: 65,
        distanceMeters: 500,
      );

      final suppressed = matchNearestCamera(
        previous: previous,
        current: lateral,
        cameras: [camera],
      );

      expect(suppressed, isNull);

      final entering = _pointBehindCamera(
        camera: camera,
        bearingDegrees: 20,
        distanceMeters: 380,
      );
      final enteringMatch = matchNearestCamera(
        previous: lateral,
        current: entering,
        cameras: [camera],
      );

      expect(enteringMatch, isNotNull);
      expect(enteringMatch!.distanceMeters, closeTo(380, 2));
      expect(enteringMatch.approaching, isTrue);
      expect(enteringMatch.relativeBearingDegrees, closeTo(20, 1));
      expect(
        enteringMatch.crossTrackMeters,
        lessThan(cameraMaxCrossTrackMeters),
      );

      final near = _pointBehindCamera(
        camera: camera,
        bearingDegrees: 0,
        distanceMeters: 60,
      );
      final nearMatch = matchNearestCamera(
        previous: entering,
        current: near,
        cameras: [camera],
      );

      expect(nearMatch, isNotNull);
      expect(nearMatch!.distanceMeters, closeTo(60, 1));
      expect(nearMatch.relativeBearingDegrees, closeTo(0, 1));
    },
  );

  test('prefers the confirmed camera ahead over a closer side camera', () {
    final ahead = _camera(id: 'ahead', latitude: 6.244, longitude: -75.57);
    final side = _camera(id: 'side', latitude: 6.2425, longitude: -75.5682);

    final match = matchNearestCamera(
      previous: _point(latitude: 6.239, longitude: -75.57, heading: 0),
      current: _point(latitude: 6.241, longitude: -75.57, heading: 0),
      cameras: [side, ahead],
    );

    expect(match, isNotNull);
    expect(match!.camera.id, 'ahead');
    expect(match.crossTrackMeters, lessThan(1));
  });

  test(
    'cross-track gate rejects a 450 meter lateral camera for every cone',
    () {
      final current = _point(latitude: 6.241, longitude: -75.57, heading: 0);
      final previous = _point(latitude: 6.2405, longitude: -75.57, heading: 0);
      final camera = _cameraAtBearingDistance(
        current: current,
        bearingDegrees: 88,
        distanceMeters: 450,
      );

      for (final cone in [45, 90, 180, 360]) {
        final match = matchNearestCamera(
          previous: previous,
          current: current,
          cameras: [camera],
          targetingConeDegrees: cone,
        );

        expect(match, isNull, reason: 'cone $cone');
      }
    },
  );

  test(
    'close parallel cameras at 90 and 110 meters stay rejected for every cone',
    () {
      final current = _point(latitude: 6.241, longitude: -75.57, heading: 0);
      final previous = _point(latitude: 6.2409, longitude: -75.57, heading: 0);

      for (final distance in [90.0, 110.0]) {
        final camera = _cameraAtBearingDistance(
          current: current,
          bearingDegrees: 88,
          distanceMeters: distance,
        );

        for (final cone in [45, 90, 180, 360]) {
          final match = matchNearestCamera(
            previous: previous,
            current: current,
            cameras: [camera],
            targetingConeDegrees: cone,
          );

          expect(match, isNull, reason: 'distance $distance cone $cone');
        }
      }
    },
  );

  test('near cameras outside 45 90 and 180 degree cones are rejected', () {
    final current = _point(latitude: 6.241, longitude: -75.57, heading: 0);
    final previous = _point(latitude: 6.2409, longitude: -75.57, heading: 0);

    for (final cone in [45, 90, 180]) {
      final camera = _cameraAtBearingDistance(
        current: current,
        bearingDegrees: cone == 180 ? 120 : 70,
        distanceMeters: 90,
      );

      final match = matchNearestCamera(
        previous: previous,
        current: current,
        cameras: [camera],
        targetingConeDegrees: cone,
      );

      expect(match, isNull, reason: 'cone $cone');
    }
  });

  test('exact rear 90 meter camera is rejected for non-360 cones', () {
    final current = _point(latitude: 6.241, longitude: -75.57, heading: 0);
    final previous = _point(latitude: 6.2409, longitude: -75.57, heading: 0);
    final camera = _cameraAtBearingDistance(
      current: current,
      bearingDegrees: 180,
      distanceMeters: 90,
    );

    for (final cone in [45, 90, 180]) {
      final match = matchNearestCamera(
        previous: previous,
        current: current,
        cameras: [camera],
        targetingConeDegrees: cone,
      );

      expect(match, isNull, reason: 'cone $cone');
    }
  });

  test(
    '360 degree cone rejects rear or side cameras without real approach',
    () {
      final current = _point(latitude: 6.241, longitude: -75.57, heading: 0);
      final rear = _cameraAtBearingDistance(
        current: current,
        bearingDegrees: 180,
        distanceMeters: 90,
      );
      final side = _cameraAtBearingDistance(
        current: current,
        bearingDegrees: 90,
        distanceMeters: 90,
      );

      expect(
        matchNearestCamera(
          current: current,
          cameras: [rear],
          targetingConeDegrees: 360,
        ),
        isNull,
      );
      expect(
        matchNearestCamera(
          current: current,
          cameras: [side],
          targetingConeDegrees: 360,
        ),
        isNull,
      );
    },
  );

  test(
    '360 degree cone can match a rear camera with real approach evidence',
    () {
      final current = _point(latitude: 6.241, longitude: -75.57, heading: 0);
      final previous = _point(latitude: 6.242, longitude: -75.57, heading: 0);
      final camera = _cameraAtBearingDistance(
        current: current,
        bearingDegrees: 180,
        distanceMeters: 90,
      );

      final match = matchNearestCamera(
        previous: previous,
        current: current,
        cameras: [camera],
        targetingConeDegrees: 360,
      );

      expect(match, isNotNull);
      expect(match!.approaching, isTrue);
    },
  );

  test('first point without reliable heading cannot make a full alert', () {
    final current = _point(latitude: 6.241, longitude: -75.57, heading: null);
    final camera = _cameraAtBearingDistance(
      current: current,
      bearingDegrees: 0,
      distanceMeters: 90,
    );

    final match = matchNearestCamera(current: current, cameras: [camera]);

    expect(match, isNull);
  });

  test('movement-derived course can evaluate the driving corridor', () {
    final previous = _point(
      latitude: 6.240,
      longitude: -75.57,
      heading: null,
      seconds: 0,
    );
    final current = _point(
      latitude: 6.241,
      longitude: -75.57,
      heading: null,
      seconds: 10,
    );
    final camera = _cameraAtBearingDistance(
      current: current,
      bearingDegrees: 0,
      distanceMeters: 240,
    );

    final match = matchNearestCamera(
      previous: previous,
      current: current,
      cameras: [camera],
    );

    expect(match, isNotNull);
    expect(match!.crossTrackMeters, closeTo(0, 1));
  });

  test('small movement without heading fails closed for full alert', () {
    final previous = _point(
      latitude: 6.241,
      longitude: -75.57,
      heading: null,
      seconds: 0,
    );
    final current = _point(
      latitude: 6.24103,
      longitude: -75.57,
      heading: null,
      seconds: 10,
    );
    final camera = _cameraAtBearingDistance(
      current: current,
      bearingDegrees: 0,
      distanceMeters: 90,
    );

    final match = matchNearestCamera(
      previous: previous,
      current: current,
      cameras: [camera],
    );

    expect(match, isNull);
  });

  test('same-corridor approaching camera remains eligible for every cone', () {
    final current = _point(latitude: 6.241, longitude: -75.57, heading: 0);
    final previous = _point(latitude: 6.2405, longitude: -75.57, heading: 0);
    final camera = _cameraAtBearingDistance(
      current: current,
      bearingDegrees: 0,
      distanceMeters: 300,
    );

    for (final cone in [45, 90, 180, 360]) {
      final match = matchNearestCamera(
        previous: previous,
        current: current,
        cameras: [camera],
        targetingConeDegrees: cone,
      );

      expect(match, isNotNull, reason: 'cone $cone');
      expect(match!.crossTrackMeters, closeTo(0, 1));
    }
  });

  test(
    'receding overrides near-radius grace while still inside 120 meters',
    () {
      final camera = _camera(latitude: 6.244, longitude: -75.57);

      final match = matchNearestCamera(
        previous: _point(latitude: 6.2437, longitude: -75.57, heading: 0),
        current: _point(latitude: 6.2446, longitude: -75.57, heading: 0),
        cameras: [camera],
      );

      expect(match, isNull);
    },
  );

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

TrafficCamera _camera({
  String id = 'cam-1',
  required double latitude,
  required double longitude,
}) {
  return TrafficCamera(
    id: id,
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
  required double? heading,
  int seconds = 0,
}) {
  return DrivingPoint(
    latitude: latitude,
    longitude: longitude,
    accuracyMeters: 12,
    speedKmh: 42,
    headingDegrees: heading,
    recordedAt: DateTime.utc(2026, 8, 31, 12, 0, seconds),
  );
}

TrafficCamera _cameraAtBearingDistance({
  required DrivingPoint current,
  required double bearingDegrees,
  required double distanceMeters,
}) {
  final northMeters = math.cos(bearingDegrees * math.pi / 180) * distanceMeters;
  final eastMeters = math.sin(bearingDegrees * math.pi / 180) * distanceMeters;
  final metersPerLatitude = 111320.0;
  final metersPerLongitude =
      111320.0 * math.cos(current.latitude * math.pi / 180);
  return _camera(
    latitude: current.latitude + northMeters / metersPerLatitude,
    longitude: current.longitude + eastMeters / metersPerLongitude,
  );
}

DrivingPoint _pointBehindCamera({
  required TrafficCamera camera,
  required double bearingDegrees,
  required double distanceMeters,
}) {
  final northMeters = math.cos(bearingDegrees * math.pi / 180) * distanceMeters;
  final eastMeters = math.sin(bearingDegrees * math.pi / 180) * distanceMeters;
  final metersPerLatitude = 111320.0;
  final metersPerLongitude =
      111320.0 * math.cos(camera.latitude * math.pi / 180);
  return _point(
    latitude: camera.latitude - northMeters / metersPerLatitude,
    longitude: camera.longitude - eastMeters / metersPerLongitude,
    heading: 0,
  );
}
