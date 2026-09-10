import 'dart:math' as math;

import '../../trip/data/toll_inventory.dart';
import 'camera_matcher.dart';
import 'geo_math.dart';

class TollMatch {
  const TollMatch({
    required this.toll,
    required this.distanceMeters,
    required this.approaching,
    required this.relativeBearingDegrees,
    required this.distanceDeltaMeters,
  });

  final TollInventoryRecord toll;
  final double distanceMeters;
  final bool approaching;
  final double? relativeBearingDegrees;
  final double? distanceDeltaMeters;
  double? get bearingDifferenceDegrees => relativeBearingDegrees?.abs();
}

TollMatch? matchNearestToll({
  required DrivingPoint current,
  required Iterable<TollInventoryRecord> tolls,
  DrivingPoint? previous,
  int targetingConeDegrees = 90,
}) {
  if (!current.accuracyMeters.isFinite || current.accuracyMeters > 60) {
    return null;
  }
  final course = reliableDrivingCourseDegrees(
    current: current,
    previous: previous,
  );
  final allAround = targetingConeDegrees == 360;
  if (course == null && !allAround) return null;
  TollMatch? best;
  var bestScore = double.infinity;
  for (final toll in tolls) {
    if (toll.operationClassification ==
        TollOperationClassification.nonOperationalHistorical) {
      continue;
    }
    final match = measureToll(current: current, previous: previous, toll: toll);
    if (match.distanceMeters > cameraAwarenessRadiusMeters) continue;
    final angle = match.relativeBearingDegrees;
    if (!allAround) {
      if (angle == null ||
          !isRelativeBearingInsideTargetingCone(
            relativeBearingDegrees: angle,
            targetingConeDegrees: targetingConeDegrees,
          )) {
        continue;
      }
      final crossTrack =
          match.distanceMeters * math.sin(angle * math.pi / 180).abs();
      final corridor = math.min(
        cameraMaxCrossTrackMeters,
        math.max(
          70.0,
          match.distanceMeters * (targetingConeDegrees <= 45 ? 0.38 : 0.68),
        ),
      );
      if (crossTrack > corridor || !match.approaching) continue;
    }
    if (best != null && best.approaching && !match.approaching) continue;
    final score = match.distanceMeters + (angle?.abs() ?? 180) * 4;
    if (best == null ||
        (!best.approaching && match.approaching) ||
        score < bestScore) {
      best = match;
      bestScore = score;
    }
  }
  return best;
}

TollMatch measureToll({
  required DrivingPoint current,
  required DrivingPoint? previous,
  required TollInventoryRecord toll,
}) {
  double distanceFrom(DrivingPoint point) => distanceMeters(
    fromLatitude: point.latitude,
    fromLongitude: point.longitude,
    toLatitude: toll.latitude,
    toLongitude: toll.longitude,
  );
  final distance = distanceFrom(current);
  final delta = previous == null ? null : distanceFrom(previous) - distance;
  final course = reliableDrivingCourseDegrees(
    current: current,
    previous: previous,
  );
  final relative = course == null
      ? null
      : signedAngleDeltaDegrees(
          course,
          bearingDegrees(
            fromLatitude: current.latitude,
            fromLongitude: current.longitude,
            toLatitude: toll.latitude,
            toLongitude: toll.longitude,
          ),
        );
  return TollMatch(
    toll: toll,
    distanceMeters: distance,
    relativeBearingDegrees: relative,
    distanceDeltaMeters: delta,
    approaching:
        relative != null &&
        relative.abs() <= 90 &&
        (delta == null || delta >= -cameraRecedingOverrideMeters) &&
        ((delta ?? 0) > 3 || distance <= cameraNearRadiusMeters),
  );
}
