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
    final distance = distanceMeters(
      fromLatitude: current.latitude,
      fromLongitude: current.longitude,
      toLatitude: toll.latitude,
      toLongitude: toll.longitude,
    );
    if (distance > cameraAwarenessRadiusMeters) continue;
    final match = _measureToll(
      current: current,
      previous: previous,
      toll: toll,
      distance: distance,
      course: course,
    );
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
  return _measureToll(
    current: current,
    previous: previous,
    toll: toll,
    distance: distanceMeters(
      fromLatitude: current.latitude,
      fromLongitude: current.longitude,
      toLatitude: toll.latitude,
      toLongitude: toll.longitude,
    ),
    course: reliableDrivingCourseDegrees(current: current, previous: previous),
  );
}

TollMatch _measureToll({
  required DrivingPoint current,
  required DrivingPoint? previous,
  required TollInventoryRecord toll,
  required double distance,
  required double? course,
}) {
  final delta = previous == null
      ? null
      : distanceMeters(
              fromLatitude: previous.latitude,
              fromLongitude: previous.longitude,
              toLatitude: toll.latitude,
              toLongitude: toll.longitude,
            ) -
            distance;
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
