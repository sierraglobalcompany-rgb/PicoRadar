import 'camera_matcher.dart';

enum DrivingAlertProfile {
  calm('Tranquilo', [500, 200, 50]),
  normal('Normal', [500, 300, 100]),
  detailed('Detallado', [500, 400, 300, 200, 100, 50]),
  custom('Personalizado', [500, 250, 100]);

  const DrivingAlertProfile(this.label, this.defaultThresholdsMeters);

  final String label;
  final List<int> defaultThresholdsMeters;
}

enum DrivingAlertSeverity { calm, headsUp, urgent }

class DrivingAlert {
  const DrivingAlert({
    required this.cameraId,
    required this.title,
    required this.message,
    required this.thresholdMeters,
    required this.severity,
    required this.overspeed,
  });

  final String cameraId;
  final String title;
  final String message;
  final int thresholdMeters;
  final DrivingAlertSeverity severity;
  final bool overspeed;
}

class DrivingAlertEngine {
  DrivingAlertEngine({this.profile = DrivingAlertProfile.normal, this.now});

  final DrivingAlertProfile profile;
  final DateTime? now;
  final Map<String, Set<int>> _firedThresholdsByCamera = {};
  final Map<String, DateTime> _lastAlertByCamera = {};

  DrivingAlert? evaluate({
    required CameraMatch? match,
    required double speedKmh,
    DateTime? now,
  }) {
    if (match == null || !match.approaching || speedKmh < 5) {
      return null;
    }
    if (match.distanceMeters > cameraAwarenessRadiusMeters) {
      return null;
    }
    final camera = match.camera;
    if (match.distanceMeters > cameraAwarenessRadiusMeters + 80) {
      _firedThresholdsByCamera.remove(camera.id);
      _lastAlertByCamera.remove(camera.id);
    }

    final currentInstant = now ?? this.now ?? DateTime.now().toUtc();
    final lastAlert = _lastAlertByCamera[camera.id];
    if (lastAlert != null &&
        currentInstant.difference(lastAlert) < const Duration(seconds: 18)) {
      return null;
    }

    final threshold = _nextThreshold(camera.id, match.distanceMeters);
    if (threshold == null) {
      return null;
    }

    final speedLimit = camera.speedLimitKmh;
    final overspeed = speedLimit != null && speedKmh > speedLimit + 3;
    _firedThresholdsByCamera
        .putIfAbsent(camera.id, () => <int>{})
        .add(threshold);
    _lastAlertByCamera[camera.id] = currentInstant;
    return DrivingAlert(
      cameraId: camera.id,
      title: overspeed ? 'Reduce la velocidad' : 'Camara cerca',
      message: _message(match, threshold, speedKmh),
      thresholdMeters: threshold,
      severity: overspeed || threshold <= 100
          ? DrivingAlertSeverity.urgent
          : DrivingAlertSeverity.headsUp,
      overspeed: overspeed,
    );
  }

  int? _nextThreshold(String cameraId, double distanceMeters) {
    final fired = _firedThresholdsByCamera[cameraId] ?? const <int>{};
    final thresholds = [...profile.defaultThresholdsMeters]
      ..sort((a, b) => b.compareTo(a));
    for (final threshold in thresholds) {
      if (distanceMeters <= threshold && !fired.contains(threshold)) {
        return threshold;
      }
    }
    return null;
  }

  String _message(CameraMatch match, int threshold, double speedKmh) {
    final camera = match.camera;
    final speed = speedKmh.round();
    final limit = camera.speedLimitKmh;
    final locality = camera.locality;
    if (limit == null) {
      return '$locality · $threshold m · $speed km/h';
    }
    return '$locality · $threshold m · $speed/$limit km/h';
  }
}
