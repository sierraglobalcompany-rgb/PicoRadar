import 'dart:math' as math;

import '../domain/trip_plan.dart';

const _earthRadiusMeters = 6371008.8;

enum RouteGeometryQuality { unavailable, pointOnly, polyline }

class RouteProjection {
  const RouteProjection({
    required this.coordinate,
    required this.segmentIndex,
    required this.segmentFraction,
    required this.crossTrackMeters,
    required this.alongRouteMeters,
    required this.isPointFallback,
  });

  final TripCoordinate coordinate;
  final int segmentIndex;
  final double segmentFraction;
  final double crossTrackMeters;
  final double alongRouteMeters;
  final bool isPointFallback;
}

/// Spatial index for deterministic pre-trip proximity checks.
///
/// The default 75 m corridor is deliberately conservative. A geometric hit
/// means only "near the route"; it does not prove road, carriageway, direction,
/// operation, tariff, or a charge event.
class RouteGeometryIndex {
  RouteGeometryIndex(List<TripCoordinate> geometry)
    : geometry = List.unmodifiable(geometry),
      _segments = _buildSegments(geometry);

  static const defaultCorridorMeters = 75.0;

  final List<TripCoordinate> geometry;
  final List<_RouteSegment> _segments;

  RouteGeometryQuality get quality {
    if (geometry.isEmpty || geometry.any((point) => !point.isFinite)) {
      return RouteGeometryQuality.unavailable;
    }
    if (geometry.length == 1) {
      return RouteGeometryQuality.pointOnly;
    }
    return _segments.any((segment) => segment.isUsable)
        ? RouteGeometryQuality.polyline
        : RouteGeometryQuality.unavailable;
  }

  double get lengthMeters => quality == RouteGeometryQuality.polyline
      ? _segments.last.cumulativeEndMeters
      : 0;

  RouteProjection? nearest(
    TripCoordinate point, {
    double corridorMeters = defaultCorridorMeters,
  }) {
    final passages = projectPassages(point, corridorMeters: corridorMeters);
    if (passages.isEmpty) {
      return null;
    }
    return passages.reduce(
      (best, candidate) =>
          candidate.crossTrackMeters < best.crossTrackMeters ? candidate : best,
    );
  }

  List<RouteProjection> projectPassages(
    TripCoordinate point, {
    double corridorMeters = defaultCorridorMeters,
  }) {
    if (!corridorMeters.isFinite ||
        corridorMeters <= 0 ||
        quality == RouteGeometryQuality.unavailable) {
      return const [];
    }
    if (quality == RouteGeometryQuality.pointOnly) {
      final distance = _distanceMeters(geometry.single, point);
      if (distance > corridorMeters) {
        return const [];
      }
      return [
        RouteProjection(
          coordinate: geometry.single,
          segmentIndex: 0,
          segmentFraction: 0,
          crossTrackMeters: distance,
          alongRouteMeters: 0,
          isPointFallback: true,
        ),
      ];
    }

    final candidates = <_ProjectionCandidate>[];
    var usableSegmentIndex = 0;
    for (final segment in _segments) {
      if (!segment.isUsable) {
        continue;
      }
      final currentUsableSegmentIndex = usableSegmentIndex++;
      if (!segment.mayContain(point, corridorMeters)) {
        continue;
      }
      final projection = segment.project(point);
      if (projection.crossTrackMeters <= corridorMeters) {
        candidates.add(
          _ProjectionCandidate(
            projection: projection,
            usableSegmentIndex: currentUsableSegmentIndex,
          ),
        );
      }
    }
    if (candidates.isEmpty) {
      return const [];
    }

    final passages = <RouteProjection>[];
    var groupBest = candidates.first.projection;
    var previousUsableSegment = candidates.first.usableSegmentIndex;
    for (final candidate in candidates.skip(1)) {
      if (candidate.usableSegmentIndex == previousUsableSegment + 1) {
        if (candidate.projection.crossTrackMeters <
            groupBest.crossTrackMeters) {
          groupBest = candidate.projection;
        }
      } else {
        passages.add(groupBest);
        groupBest = candidate.projection;
      }
      previousUsableSegment = candidate.usableSegmentIndex;
    }
    passages.add(groupBest);
    passages.sort(_compareProjection);
    return List.unmodifiable(passages);
  }

  static List<_RouteSegment> _buildSegments(List<TripCoordinate> geometry) {
    if (geometry.length < 2) {
      return const [];
    }
    final result = <_RouteSegment>[];
    var cumulative = 0.0;
    for (var index = 0; index < geometry.length - 1; index++) {
      final segment = _RouteSegment(
        index: index,
        start: geometry[index],
        end: geometry[index + 1],
        cumulativeStartMeters: cumulative,
      );
      result.add(segment);
      cumulative = segment.cumulativeEndMeters;
    }
    return List.unmodifiable(result);
  }
}

class _ProjectionCandidate {
  const _ProjectionCandidate({
    required this.projection,
    required this.usableSegmentIndex,
  });

  final RouteProjection projection;
  final int usableSegmentIndex;
}

class _RouteSegment {
  _RouteSegment({
    required this.index,
    required this.start,
    required this.end,
    required this.cumulativeStartMeters,
  }) : referenceLatitudeRadians = _toRadians(
         (start.latitude + end.latitude) / 2,
       ),
       deltaX = _longitudeMeters(
         end.longitude - start.longitude,
         _toRadians((start.latitude + end.latitude) / 2),
       ),
       deltaY = _latitudeMeters(end.latitude - start.latitude) {
    lengthMeters = math.sqrt(deltaX * deltaX + deltaY * deltaY);
    cumulativeEndMeters = cumulativeStartMeters + lengthMeters;
  }

  final int index;
  final TripCoordinate start;
  final TripCoordinate end;
  final double cumulativeStartMeters;
  final double referenceLatitudeRadians;
  final double deltaX;
  final double deltaY;
  late final double lengthMeters;
  late final double cumulativeEndMeters;

  bool get isUsable => lengthMeters.isFinite && lengthMeters > 0;

  bool mayContain(TripCoordinate point, double corridorMeters) {
    final latitudePadding = corridorMeters / 111320;
    final longitudeScale = math.max(
      0.15,
      math.cos(referenceLatitudeRadians).abs(),
    );
    final longitudePadding = corridorMeters / (111320 * longitudeScale);
    return point.latitude >=
            math.min(start.latitude, end.latitude) - latitudePadding &&
        point.latitude <=
            math.max(start.latitude, end.latitude) + latitudePadding &&
        point.longitude >=
            math.min(start.longitude, end.longitude) - longitudePadding &&
        point.longitude <=
            math.max(start.longitude, end.longitude) + longitudePadding;
  }

  RouteProjection project(TripCoordinate point) {
    if (lengthMeters == 0) {
      return RouteProjection(
        coordinate: start,
        segmentIndex: index,
        segmentFraction: 0,
        crossTrackMeters: _distanceMeters(start, point),
        alongRouteMeters: cumulativeStartMeters,
        isPointFallback: false,
      );
    }
    final pointX = _longitudeMeters(
      point.longitude - start.longitude,
      referenceLatitudeRadians,
    );
    final pointY = _latitudeMeters(point.latitude - start.latitude);
    final fraction =
        ((pointX * deltaX + pointY * deltaY) / (lengthMeters * lengthMeters))
            .clamp(0.0, 1.0);
    final projectedX = deltaX * fraction;
    final projectedY = deltaY * fraction;
    final crossX = pointX - projectedX;
    final crossY = pointY - projectedY;
    return RouteProjection(
      coordinate: TripCoordinate(
        latitude: start.latitude + (end.latitude - start.latitude) * fraction,
        longitude:
            start.longitude + (end.longitude - start.longitude) * fraction,
      ),
      segmentIndex: index,
      segmentFraction: fraction,
      crossTrackMeters: math.sqrt(crossX * crossX + crossY * crossY),
      alongRouteMeters: cumulativeStartMeters + lengthMeters * fraction,
      isPointFallback: false,
    );
  }
}

int _compareProjection(RouteProjection left, RouteProjection right) {
  final along = left.alongRouteMeters.compareTo(right.alongRouteMeters);
  return along != 0 ? along : left.segmentIndex.compareTo(right.segmentIndex);
}

double _distanceMeters(TripCoordinate left, TripCoordinate right) {
  final reference = _toRadians((left.latitude + right.latitude) / 2);
  final x = _longitudeMeters(right.longitude - left.longitude, reference);
  final y = _latitudeMeters(right.latitude - left.latitude);
  return math.sqrt(x * x + y * y);
}

double _longitudeMeters(double degrees, double referenceLatitudeRadians) =>
    _toRadians(degrees) *
    _earthRadiusMeters *
    math.cos(referenceLatitudeRadians);

double _latitudeMeters(double degrees) =>
    _toRadians(degrees) * _earthRadiusMeters;

double _toRadians(double degrees) => degrees * math.pi / 180;

extension on TripCoordinate {
  bool get isFinite => latitude.isFinite && longitude.isFinite;
}
