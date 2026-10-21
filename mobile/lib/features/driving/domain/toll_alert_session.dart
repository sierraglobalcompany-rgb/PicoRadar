import '../../trip/data/toll_inventory.dart';
import 'camera_matcher.dart';
import 'driving_alert_engine.dart';
import 'toll_matcher.dart';

/// Memory lasts only for this driving session, never for a stored GPS track.
class TollAlertSession {
  final Map<String, _TollEpisode> _episodes = {};
  var _serial = 0;
  TollMatch? nearestToll;
  String? episodeKey;

  int? evaluate({
    required DrivingPoint current,
    required DrivingPoint? previous,
    required Iterable<TollInventoryRecord> tolls,
    required int targetingConeDegrees,
    required List<int> thresholdsMeters,
    required bool cameraHasPriority,
  }) {
    nearestToll = null;
    episodeKey = null;
    if (current.accuracyMeters > 60) return null;
    // A timeout alone cannot establish a new pass. Rearm only after leaving
    // awareness range, or a measured return after receding from the station.
    for (final episode in _episodes.values.toList()) {
      final measured = measureToll(
        current: current,
        previous: previous,
        toll: episode.toll,
      );
      if (measured.distanceMeters > cameraAwarenessRadiusMeters + 100) {
        _episodes.remove(episode.toll.id);
        continue;
      }
      if (episode.passed &&
          measured.approaching &&
          measured.distanceMeters > cameraNearRadiusMeters) {
        _episodes.remove(episode.toll.id);
        continue;
      }
      if (measured.distanceMeters < episode.closestMeters) {
        episode.closestMeters = measured.distanceMeters;
      }
      final crossedBehind =
          episode.seenApproaching &&
          episode.closestMeters <= cameraNearRadiusMeters &&
          (measured.relativeBearingDegrees?.abs() ?? 0) > 90;
      if (crossedBehind) episode.passed = true;
      if (episode.closestMeters <= cameraNearRadiusMeters &&
          (measured.distanceDeltaMeters ?? 0) < -cameraRecedingOverrideMeters &&
          (measured.relativeBearingDegrees?.abs() ?? 0) > 90 &&
          measured.distanceMeters > episode.closestMeters + 15) {
        episode.passed = true;
      }
    }
    final match = matchNearestToll(
      current: current,
      previous: previous,
      tolls: tolls,
      targetingConeDegrees: targetingConeDegrees,
    );
    if (match == null) return null;
    final episode = _episodes.putIfAbsent(
      match.toll.id,
      () => _TollEpisode(
        match.toll,
        '${match.toll.id}:${++_serial}',
        match.distanceMeters,
      ),
    );
    if (episode.dismissed || episode.passed) return null;
    episode.seenApproaching = episode.seenApproaching || match.approaching;
    nearestToll = match;
    episodeKey = episode.key;
    if (!match.approaching || current.speedKmh < 5) return null;
    final crossed =
        thresholdsMeters
            .where(
              (threshold) =>
                  allowedCustomAlertThresholdsMeters.contains(threshold) &&
                  match.distanceMeters <= threshold &&
                  !episode.fired.contains(threshold),
            )
            .toList()
          ..sort();
    if (crossed.isEmpty) return null;
    episode.fired.addAll(crossed);
    if (cameraHasPriority ||
        (episode.lastAlertAt != null &&
            current.recordedAt.difference(episode.lastAlertAt!) <
                const Duration(seconds: 18))) {
      return null;
    }
    episode.lastAlertAt = current.recordedAt;
    return crossed.first;
  }

  void dismissCurrent() {
    final id = nearestToll?.toll.id;
    if (id != null) _episodes[id]?.dismissed = true;
    nearestToll = null;
    episodeKey = null;
  }

  void disable() {
    for (final episode in _episodes.values) {
      episode.dismissed = true;
    }
    nearestToll = null;
    episodeKey = null;
  }
}

class _TollEpisode {
  _TollEpisode(this.toll, this.key, this.closestMeters);
  final TollInventoryRecord toll;
  final String key;
  final Set<int> fired = {};
  double closestMeters;
  DateTime? lastAlertAt;
  bool dismissed = false;
  bool passed = false;
  bool seenApproaching = false;
}
