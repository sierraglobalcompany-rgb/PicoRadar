import 'geo_math.dart';
import 'traffic_camera.dart';

const cameraAwarenessRadiusMeters = 600.0;
const cameraNearRadiusMeters = 120.0;
const cameraHeadingToleranceDegrees = 100.0;

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
  });

  final TrafficCamera camera;
  final double distanceMeters;
  final bool approaching;
  final double? bearingDifferenceDegrees;
}

CameraMatch? matchNearestCamera({
  required DrivingPoint current,
  required Iterable<TrafficCamera> cameras,
  DrivingPoint? previous,
}) {
  CameraMatch? best;
  var bestScore = double.infinity;
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

    double? headingDiff;
    if (current.headingDegrees != null && current.speedKmh >= 8) {
      final bearing = bearingDegrees(
        fromLatitude: current.latitude,
        fromLongitude: current.longitude,
        toLatitude: camera.latitude,
        toLongitude: camera.longitude,
      );
      headingDiff = angleDifferenceDegrees(current.headingDegrees!, bearing);
      if (headingDiff > cameraHeadingToleranceDegrees) {
        continue;
      }
    }

    var approaching = distance <= cameraNearRadiusMeters;
    if (previous != null) {
      final previousDistance = distanceMeters(
        fromLatitude: previous.latitude,
        fromLongitude: previous.longitude,
        toLatitude: camera.latitude,
        toLongitude: camera.longitude,
      );
      approaching = approaching || previousDistance > distance + 3;
      if (!approaching && distance > cameraNearRadiusMeters) {
        continue;
      }
    }

    final score = distance + (headingDiff ?? 30) * 1.5;
    if (score < bestScore) {
      bestScore = score;
      best = CameraMatch(
        camera: camera,
        distanceMeters: distance,
        approaching: approaching,
        bearingDifferenceDegrees: headingDiff,
      );
    }
  }
  return best;
}
