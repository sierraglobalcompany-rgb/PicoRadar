import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/driving/domain/camera_matcher.dart';
import 'package:picoradar/features/driving/domain/driving_alert_engine.dart';
import 'package:picoradar/features/driving/domain/toll_alert_session.dart';
import 'package:picoradar/features/driving/domain/toll_matcher.dart';

import '../toll_test_fixtures.dart';

void main() {
  test('heading changes far from the booth do not rearm toll stages', () {
    final session = TollAlertSession();
    int? step(double south, int seconds, double heading) => session.evaluate(
      current: tollPoint(south, seconds, heading: heading),
      previous: tollPoint(south + 20, seconds - 1, heading: heading),
      tolls: [cocorna],
      targetingConeDegrees: 360,
      thresholdsMeters: [500, 300, 100],
      cameraHasPriority: false,
    );
    expect(step(490, 20, 0), 500);
    final key = session.episodeKey;
    expect(step(480, 40, 180), isNull);
    expect(step(470, 60, 0), isNull);
    expect(session.episodeKey, key);
  });

  test('Cocorna demo resolves the real inventory coordinates', () {
    expect(cocorna.latitude, closeTo(6.124607098, 0.000000001));
    expect(cocorna.longitude, closeTo(-75.243039628, 0.000000001));
  });

  test('all angular gates use full aperture on both sides', () {
    for (final cone in [45, 90, 180]) {
      for (final sign in [-1, 1]) {
        expect(
          isRelativeBearingInsideTargetingCone(
            relativeBearingDegrees: sign * cone / 2,
            targetingConeDegrees: cone,
          ),
          isTrue,
        );
        expect(
          isRelativeBearingInsideTargetingCone(
            relativeBearingDegrees: sign * (cone / 2 + 0.01),
            targetingConeDegrees: cone,
          ),
          isFalse,
        );
      }
    }
  });

  test('360 keeps rear toll visual only and narrow cones reject it', () {
    final current = tollPoint(-100, 20);
    final previous = tollPoint(-80, 0);
    final match = matchNearestToll(
      current: current,
      previous: previous,
      tolls: [cocorna],
      targetingConeDegrees: 360,
    );
    expect(match!.toll, same(cocorna));
    expect(match.approaching, isFalse);
    expect(match.distanceDeltaMeters, lessThan(0));
    expect(
      matchNearestToll(
        current: current,
        previous: previous,
        tolls: [cocorna],
        targetingConeDegrees: 180,
      ),
      isNull,
    );
  });

  test('unreliable compass cannot create a spoken approach', () {
    final current = tollPoint(100, 20, heading: -1, speed: 0);
    expect(
      reliableDrivingCourseDegrees(
        current: current,
        previous: tollPoint(101, 0),
      ),
      isNull,
    );
    final match = matchNearestToll(
      current: current,
      previous: tollPoint(101, 0),
      tolls: [cocorna],
      targetingConeDegrees: 360,
    );
    expect(match!.relativeBearingDegrees, isNull);
    expect(match.approaching, isFalse);
    expect(
      matchNearestToll(
        current: tollPoint(100, 20, accuracy: 95),
        tolls: [cocorna],
        targetingConeDegrees: 360,
      ),
      isNull,
    );
  });

  for (final profile in DrivingAlertProfile.values) {
    test('${profile.name} thresholds fire once and rearm only on new pass', () {
      final session = TollAlertSession();
      DrivingPoint previous = tollPoint(650, 0);
      var seconds = 0;
      int? step(double south, {double heading = 0}) {
        final current = tollPoint(south, seconds += 20, heading: heading);
        final threshold = session.evaluate(
          current: current,
          previous: previous,
          tolls: [cocorna],
          targetingConeDegrees: 360,
          thresholdsMeters: profile.defaultThresholdsMeters,
          cameraHasPriority: false,
        );
        previous = current;
        return threshold;
      }

      String? key;
      for (final threshold in profile.defaultThresholdsMeters) {
        expect(step(threshold - 5), threshold);
        key ??= session.episodeKey;
        expect(session.episodeKey, key);
        expect(step(threshold - 4), isNull);
      }
      expect(step(-40), isNull);
      expect(session.nearestToll, isNull);
      expect(step(-200), isNull);
      expect(step(-190, heading: 180), isNotNull);
      expect(session.episodeKey, isNot(key));
    });
  }

  test(
    'camera priority consumes stages instead of queueing stale toll voice',
    () {
      final session = TollAlertSession();
      int? step(double south, int seconds, bool priority) => session.evaluate(
        current: tollPoint(south, seconds),
        previous: tollPoint(south + 30, seconds - 1),
        tolls: [cocorna],
        targetingConeDegrees: 90,
        thresholdsMeters: [500, 300, 100],
        cameraHasPriority: priority,
      );
      expect(step(490, 20, true), isNull);
      expect(session.nearestToll, isNotNull);
      expect(step(480, 40, false), isNull);
      expect(step(290, 60, false), 300);
      expect(step(80, 65, false), isNull);
      expect(step(70, 90, false), isNull);
    },
  );

  for (final disable in [false, true]) {
    test(
      'dismiss/disable $disable survives jitter and timeout until leaving',
      () {
        final session = TollAlertSession();
        int? step(double south, int seconds) => session.evaluate(
          current: tollPoint(south, seconds),
          previous: tollPoint(south + 20, seconds - 1),
          tolls: [cocorna],
          targetingConeDegrees: 90,
          thresholdsMeters: [500, 300, 100],
          cameraHasPriority: false,
        );
        expect(step(490, 20), 500);
        if (disable) {
          session.disable();
        } else {
          session.dismissCurrent();
        }
        expect(session.nearestToll, isNull);
        expect(step(290, 1000), isNull);
        expect(session.nearestToll, isNull);
        step(800, 1020);
        expect(step(490, 1040), 500);
      },
    );
  }
}
