import 'dart:math' as math;

import 'geo_math.dart';
import 'traffic_camera.dart';

const cameraAwarenessRadiusMeters = 600.0;
const cameraNearRadiusMeters = 120.0;
const cameraMaxCrossTrackMeters = 160.0;
const cameraRecedingOverrideMeters = 5.0;
const cameraCourseMinMovementMeters = 12.0;

class DrivingPoint {
  const DrivingPoint({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.speedKmh,
    required this.recordedAt,
    this.headingDegrees,
    this.speedAccuracyKmh,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final double? speedKmh;
  final double? speedAccuracyKmh;
  final double? headingDegrees;
  final DateTime recordedAt;
}

class CameraMatch {
  const CameraMatch({
    required this.camera,
    required this.distanceMeters,
    required this.approaching,
    required this.bearingDifferenceDegrees,
    this.relativeBearingDegrees,
    this.crossTrackMeters,
  });

  final TrafficCamera camera;
  final double distanceMeters;
  final bool approaching;
  final double? bearingDifferenceDegrees;
  final double? relativeBearingDegrees;
  final double? crossTrackMeters;
}

CameraMatch? matchNearestCamera({
  required DrivingPoint current,
  required Iterable<TrafficCamera> cameras,
  DrivingPoint? previous,
  int targetingConeDegrees = 90,
}) {
  CameraMatch? best;
  var bestScore = double.infinity;
  final coneDegrees = targetingConeDegrees.clamp(45, 360);
  for (final camera in cameras) {
    final distance = distanceMeters(
      fromLatitude: current.latitude,
      fromLongitude: current.longitude,
      toLatitude: camera.latitude,
      toLongitude: camera.longitude,
    );
    if (distance > cameraAwarenessRadiusMeters) {
      continue;
    }

    final courseDegrees = _reliableCourseDegrees(
      current: current,
      previous: previous,
    );
    if (courseDegrees == null) {
      continue;
    }

    double? headingDiff;
    double? relativeBearing;
    double? crossTrack;
    final bearing = bearingDegrees(
      fromLatitude: current.latitude,
      fromLongitude: current.longitude,
      toLatitude: camera.latitude,
      toLongitude: camera.longitude,
    );
    relativeBearing = signedAngleDeltaDegrees(courseDegrees, bearing);
    headingDiff = relativeBearing.abs();
    if (!isRelativeBearingInsideTargetingCone(
      relativeBearingDegrees: relativeBearing,
      targetingConeDegrees: coneDegrees,
    )) {
      continue;
    }
    crossTrack = distance * math.sin(headingDiff * math.pi / 180).abs();
    final corridorFactor = coneDegrees <= 45 ? 0.38 : 0.68;
    final dynamicCorridor = math.max(70.0, distance * corridorFactor);
    final maxCorridor = math.min(cameraMaxCrossTrackMeters, dynamicCorridor);
    if (crossTrack > maxCorridor) {
      continue;
    }

    var approaching = distance <= cameraNearRadiusMeters && headingDiff <= 90.0;
    if (previous != null) {
      final previousDistance = distanceMeters(
        fromLatitude: previous.latitude,
        fromLongitude: previous.longitude,
        toLatitude: camera.latitude,
        toLongitude: camera.longitude,
      );
      final distanceDelta = previousDistance - distance;
      if (distanceDelta < -cameraRecedingOverrideMeters) {
        continue;
      }
      approaching = approaching || distanceDelta > 3;
      if (!approaching && distance > cameraNearRadiusMeters) {
        continue;
      }
    } else if (!approaching) {
      continue;
    }

    final score =
        distance + headingDiff * 4 + crossTrack * 1.2 + (approaching ? 0 : 120);
    if (score < bestScore) {
      bestScore = score;
      best = CameraMatch(
        camera: camera,
        distanceMeters: distance,
        approaching: approaching,
        bearingDifferenceDegrees: headingDiff,
        relativeBearingDegrees: relativeBearing,
        crossTrackMeters: crossTrack,
      );
    }
  }
  return best;
}

double? _reliableCourseDegrees({
  required DrivingPoint current,
  required DrivingPoint? previous,
}) {
  final heading = current.headingDegrees;
  if (heading != null && heading.isFinite && (current.speedKmh ?? 0) >= 8) {
    return heading;
  }
  if (previous == null || !current.recordedAt.isAfter(previous.recordedAt)) {
    return null;
  }
  final movementMeters = distanceMeters(
    fromLatitude: previous.latitude,
    fromLongitude: previous.longitude,
    toLatitude: current.latitude,
    toLongitude: current.longitude,
  );
  final accuracyFloor = math.min(
    30.0,
    math.max(previous.accuracyMeters, current.accuracyMeters) * 0.5,
  );
  final minMovement = math.max(cameraCourseMinMovementMeters, accuracyFloor);
  if (movementMeters < minMovement) {
    return null;
  }
  return bearingDegrees(
    fromLatitude: previous.latitude,
    fromLongitude: previous.longitude,
    toLatitude: current.latitude,
    toLongitude: current.longitude,
  );
}

bool isRelativeBearingInsideTargetingCone({
  required double relativeBearingDegrees,
  required int targetingConeDegrees,
}) {
  final coneDegrees = targetingConeDegrees.clamp(45, 360);
  if (coneDegrees >= 360) {
    return true;
  }
  return relativeBearingDegrees.abs() <= coneDegrees / 2.0;
}
