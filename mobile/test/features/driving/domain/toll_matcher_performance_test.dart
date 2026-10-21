import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/driving/domain/camera_matcher.dart';
import 'package:picoradar/features/driving/domain/toll_matcher.dart';

import '../toll_test_fixtures.dart';

void main() {
  for (final cone in [90, 360]) {
    test(
      'performance: far toll skips previous-position geometry (cone=$cone)',
      () {
        final previous = _CountingPoint(tollPoint(2200, 0));
        final match = matchNearestToll(
          current: tollPoint(2000, 20),
          previous: previous,
          tolls: [cocorna],
          targetingConeDegrees: cone,
        );

        expect(match, isNull);
        expect(previous.coordinateReads, 0);
      },
    );

    for (final approaching in [false, true]) {
      test(
        'performance: near toll retains exact matching semantics (cone=$cone approaching=$approaching)',
        () {
          final previous = tollPoint(approaching ? 650 : 290, 0);
          final current = tollPoint(490, 20);
          final measured = measureToll(
            current: current,
            previous: previous,
            toll: cocorna,
          );
          final match = matchNearestToll(
            current: current,
            previous: previous,
            tolls: [cocorna],
            targetingConeDegrees: cone,
          );
          if (!approaching && cone != 360) {
            expect(match, isNull);
          } else {
            expect(match, isNotNull);
            expect(match!.toll.id, cocorna.id);
            expect(match.approaching, approaching);
            expect(match.distanceMeters, measured.distanceMeters);
            expect(match.distanceDeltaMeters, measured.distanceDeltaMeters);
            expect(
              match.relativeBearingDegrees,
              measured.relativeBearingDegrees,
            );
          }
        },
      );
    }
  }
}

class _CountingPoint extends DrivingPoint {
  _CountingPoint(DrivingPoint point)
    : super(
        latitude: point.latitude,
        longitude: point.longitude,
        accuracyMeters: point.accuracyMeters,
        speedKmh: point.speedKmh,
        headingDegrees: point.headingDegrees,
        recordedAt: point.recordedAt,
      );

  int coordinateReads = 0;

  @override
  double get latitude {
    coordinateReads++;
    return super.latitude;
  }

  @override
  double get longitude {
    coordinateReads++;
    return super.longitude;
  }
}
