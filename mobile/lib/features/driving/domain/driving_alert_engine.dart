import 'camera_matcher.dart';

enum DrivingAlertProfile {
  calm('Tranquilo', [500, 200, 50]),
  normal('Normal', [500, 300, 100]),
  detailed('Detallado', [500, 400, 300, 200, 100, 50]),
  custom('Personalizado', [500, 300, 100]);

  const DrivingAlertProfile(this.label, this.defaultThresholdsMeters);

  final String label;
  final List<int> defaultThresholdsMeters;
}

const allowedCustomAlertThresholdsMeters = [500, 400, 300, 200, 100, 50];

enum DrivingAlertSeverity { calm, headsUp, urgent }

class DrivingAlert {
  const DrivingAlert({
    required this.cameraId,
    required this.title,
    required this.message,
    required this.thresholdMeters,
    required this.severity,
    required this.overspeed,
    required this.currentSpeedKmh,
    required this.reportedSpeedKmh,
  });

  final String cameraId;
  final String title;
  final String message;
  final int thresholdMeters;
  final DrivingAlertSeverity severity;
  final bool overspeed;
  final int currentSpeedKmh;
  final int? reportedSpeedKmh;
}

class DrivingAlertEngine {
  DrivingAlertEngine({
    this.profile = DrivingAlertProfile.normal,
    List<int>? customThresholdsMeters,
    this.now,
  }) : customThresholdsMeters =
           customThresholdsMeters ??
           DrivingAlertProfile.custom.defaultThresholdsMeters;

  final DrivingAlertProfile profile;
  final List<int> customThresholdsMeters;
  final DateTime? now;
  final Map<String, _CameraAlertEpisode> _episodesByCamera = {};

  DrivingAlert? evaluate({
    required CameraMatch? match,
    required double speedKmh,
    DateTime? now,
  }) {
    final currentInstant = now ?? this.now ?? DateTime.now().toUtc();
    _closeLostEpisodes(currentInstant);
    if (match == null) {
      return null;
    }
    if (match.distanceMeters > cameraAwarenessRadiusMeters) {
      return null;
    }
    final camera = match.camera;
    final episode = _episodesByCamera.putIfAbsent(
      camera.id,
      () => _CameraAlertEpisode(),
    )..lastSeenAt = currentInstant;

    // Visual episodes exist even when stopped, behind, or outside voice stages.
    if (!match.approaching || speedKmh < 5) return null;

    final threshold = _nextThreshold(episode, match.distanceMeters);
    if (threshold == null) {
      return null;
    }

    final lastAlertAt = episode.lastAlertAt;
    if (lastAlertAt != null &&
        currentInstant.difference(lastAlertAt) < const Duration(seconds: 18)) {
      _markCrossedThresholds(episode, match.distanceMeters);
      return null;
    }

    final speedLimit = camera.speedLimitKmh;
    final currentSpeed = speedKmh.round();
    _markCrossedThresholds(episode, match.distanceMeters);
    episode.lastAlertAt = currentInstant;
    return DrivingAlert(
      cameraId: camera.id,
      title: 'Cámara cerca',
      message: 'Cámara a $threshold metros. Respeta la señalización de la vía.',
      thresholdMeters: threshold,
      severity: threshold <= 100
          ? DrivingAlertSeverity.urgent
          : DrivingAlertSeverity.headsUp,
      overspeed: false,
      currentSpeedKmh: currentSpeed,
      reportedSpeedKmh: speedLimit,
    );
  }

  void markNoMatch(DateTime now) {
    _closeLostEpisodes(now);
  }

  bool hasActiveEpisode(String cameraId, DateTime now) {
    final episode = _episodesByCamera[cameraId];
    return episode != null &&
        now.difference(episode.lastSeenAt) <= const Duration(seconds: 25);
  }

  int? _nextThreshold(_CameraAlertEpisode episode, double distanceMeters) {
    final crossed = _crossedThresholds(episode, distanceMeters);
    if (crossed.isEmpty) {
      return null;
    }
    return crossed.reduce((a, b) => a < b ? a : b);
  }

  void _markCrossedThresholds(
    _CameraAlertEpisode episode,
    double distanceMeters,
  ) {
    episode.firedThresholds.addAll(_crossedThresholds(episode, distanceMeters));
  }

  List<int> _crossedThresholds(
    _CameraAlertEpisode episode,
    double distanceMeters,
  ) {
    final thresholds = [
      ...(profile == DrivingAlertProfile.custom
          ? _normalizedCustomThresholds()
          : profile.defaultThresholdsMeters),
    ]..sort((a, b) => b.compareTo(a));
    return [
      for (final threshold in thresholds)
        if (distanceMeters <= threshold &&
            !episode.firedThresholds.contains(threshold))
          threshold,
    ];
  }

  void _closeLostEpisodes(DateTime now) {
    _episodesByCamera.removeWhere(
      (_, episode) =>
          now.difference(episode.lastSeenAt) > const Duration(seconds: 25),
    );
  }

  List<int> _normalizedCustomThresholds() {
    final selected =
        customThresholdsMeters
            .where(allowedCustomAlertThresholdsMeters.contains)
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    return selected.isEmpty
        ? DrivingAlertProfile.custom.defaultThresholdsMeters
        : selected;
  }
}

class _CameraAlertEpisode {
  final Set<int> firedThresholds = {};
  DateTime lastSeenAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  DateTime? lastAlertAt;
}
