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
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final double speedKmh;
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

    final courseDegrees = reliableDrivingCourseDegrees(
      current: current,
      previous: previous,
    );
    if (courseDegrees == null && coneDegrees != 360) {
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
    relativeBearing = courseDegrees == null
        ? null
        : signedAngleDeltaDegrees(courseDegrees, bearing);
    headingDiff = relativeBearing?.abs();
    if (!isRelativeBearingInsideTargetingCone(
      relativeBearingDegrees: relativeBearing ?? 0,
      targetingConeDegrees: coneDegrees,
    )) {
      continue;
    }
    crossTrack = headingDiff == null
        ? null
        : distance * math.sin(headingDiff * math.pi / 180).abs();
    final corridorFactor = coneDegrees <= 45 ? 0.38 : 0.68;
    final dynamicCorridor = math.max(70.0, distance * corridorFactor);
    final maxCorridor = math.min(cameraMaxCrossTrackMeters, dynamicCorridor);
    if (coneDegrees != 360 && (crossTrack ?? 0) > maxCorridor) {
      continue;
    }

    final ahead = headingDiff != null && headingDiff <= 90;
    var approaching = distance <= cameraNearRadiusMeters && ahead;
    if (previous != null) {
      final previousDistance = distanceMeters(
        fromLatitude: previous.latitude,
        fromLongitude: previous.longitude,
        toLatitude: camera.latitude,
        toLongitude: camera.longitude,
      );
      final distanceDelta = previousDistance - distance;
      if (distanceDelta < -cameraRecedingOverrideMeters) {
        if (coneDegrees != 360) continue;
        approaching = false;
      } else {
        approaching = ahead && (approaching || distanceDelta > 3);
      }
      if (coneDegrees != 360 &&
          !approaching &&
          distance > cameraNearRadiusMeters) {
        continue;
      }
    } else if (coneDegrees != 360 && !approaching) {
      continue;
    }

    final score = distance + (headingDiff ?? 180) * 4 + (crossTrack ?? 0) * 1.2;
    // Approaching targets always win over purely visual all-around targets.
    if (best != null && best.approaching && !approaching) continue;
    if (best != null && !best.approaching && approaching) {
      bestScore = double.infinity;
    }
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

double? reliableDrivingCourseDegrees({
  required DrivingPoint current,
  required DrivingPoint? previous,
}) {
  final heading = current.headingDegrees;
  if (!current.accuracyMeters.isFinite || current.accuracyMeters > 60) {
    return null;
  }
  if (heading != null &&
      heading.isFinite &&
      heading >= 0 &&
      heading < 360 &&
      current.speedKmh >= 8) {
    return heading;
  }
  if (previous == null ||
      previous.accuracyMeters > 60 ||
      !current.recordedAt.isAfter(previous.recordedAt)) {
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
