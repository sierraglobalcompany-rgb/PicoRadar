import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/trip/application/route_geometry_index.dart';
import 'package:picoradar/features/trip/domain/trip_plan.dart';

void main() {
  group('RouteGeometryIndex', () {
    test('projects onto the correct leg of an L-shaped route', () {
      final index = RouteGeometryIndex(const [
        TripCoordinate(latitude: 6.24, longitude: -75.58),
        TripCoordinate(latitude: 6.24, longitude: -75.57),
        TripCoordinate(latitude: 6.25, longitude: -75.57),
      ]);

      final hit = index.nearest(
        const TripCoordinate(latitude: 6.245, longitude: -75.5699),
        corridorMeters: 30,
      );

      expect(hit, isNotNull);
      expect(hit!.segmentIndex, 1);
      expect(hit.crossTrackMeters, lessThan(12));
      expect(hit.alongRouteMeters, greaterThan(1500));
    });

    test('rejects a point on a parallel road outside the corridor', () {
      final index = RouteGeometryIndex(const [
        TripCoordinate(latitude: 6.24, longitude: -75.58),
        TripCoordinate(latitude: 6.25, longitude: -75.58),
      ]);

      final hits = index.projectPassages(
        const TripCoordinate(latitude: 6.245, longitude: -75.578),
        corridorMeters: 75,
      );

      expect(hits, isEmpty);
    });

    test('keeps a near-parallel point as geometrically nearby only', () {
      final index = RouteGeometryIndex(const [
        TripCoordinate(latitude: 6.24, longitude: -75.58),
        TripCoordinate(latitude: 6.25, longitude: -75.58),
      ]);

      final hit = index.nearest(
        const TripCoordinate(latitude: 6.245, longitude: -75.5797),
        corridorMeters: 75,
      );

      expect(hit, isNotNull);
      expect(hit!.crossTrackMeters, inInclusiveRange(30, 36));
    });

    test(
      'merges adjacent hits and preserves non-adjacent repeated passages',
      () {
        final index = RouteGeometryIndex(const [
          TripCoordinate(latitude: 6.240, longitude: -75.580),
          TripCoordinate(latitude: 6.240, longitude: -75.570),
          TripCoordinate(latitude: 6.250, longitude: -75.570),
          TripCoordinate(latitude: 6.250, longitude: -75.580),
          TripCoordinate(latitude: 6.240, longitude: -75.580),
          TripCoordinate(latitude: 6.240, longitude: -75.570),
        ]);

        final hits = index.projectPassages(
          const TripCoordinate(latitude: 6.2401, longitude: -75.575),
          corridorMeters: 30,
        );

        expect(hits, hasLength(2));
        expect(hits[0].segmentIndex, 0);
        expect(hits[1].segmentIndex, 4);
        expect(hits[0].alongRouteMeters, lessThan(hits[1].alongRouteMeters));
      },
    );

    test('empty and one-point geometries remain honest', () {
      final empty = RouteGeometryIndex(const []);
      final point = RouteGeometryIndex(const [
        TripCoordinate(latitude: 6.24, longitude: -75.58),
      ]);

      expect(empty.quality, RouteGeometryQuality.unavailable);
      expect(
        empty.nearest(const TripCoordinate(latitude: 6.24, longitude: -75.58)),
        isNull,
      );
      expect(point.quality, RouteGeometryQuality.pointOnly);
      expect(
        point
            .nearest(
              const TripCoordinate(latitude: 6.2401, longitude: -75.58),
              corridorMeters: 20,
            )!
            .isPointFallback,
        isTrue,
      );
    });

    test('repeated or non-finite points are not usable route geometry', () {
      final repeated = RouteGeometryIndex(const [
        TripCoordinate(latitude: 6.24, longitude: -75.58),
        TripCoordinate(latitude: 6.24, longitude: -75.58),
        TripCoordinate(latitude: 6.24, longitude: -75.58),
      ]);
      final nonFinite = RouteGeometryIndex(const [
        TripCoordinate(latitude: 6.24, longitude: -75.58),
        TripCoordinate(latitude: double.nan, longitude: -75.57),
      ]);

      expect(repeated.quality, RouteGeometryQuality.unavailable);
      expect(nonFinite.quality, RouteGeometryQuality.unavailable);
      expect(
        repeated.nearest(
          const TripCoordinate(latitude: 6.24, longitude: -75.58),
        ),
        isNull,
      );
    });
  });
}
