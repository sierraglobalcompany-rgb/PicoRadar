import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/trip/application/route_geometry_index.dart';
import 'package:picoradar/features/trip/domain/trip_plan.dart';

void main() {
  for (final quality in [
    RouteGeometryQuality.polyline,
    RouteGeometryQuality.pointOnly,
    RouteGeometryQuality.unavailable,
  ]) {
    test(
      'performance: immutable geometry quality is computed once ($quality)',
      () {
        final points = [
          _CountingCoordinate(
            quality == RouteGeometryQuality.unavailable ? double.nan : 6.24,
            -75.58,
          ),
          if (quality != RouteGeometryQuality.pointOnly)
            _CountingCoordinate(6.25, -75.57),
        ];
        final index = RouteGeometryIndex(points);
        expect(index.quality, quality);
        for (final point in points) {
          point.reads = 0;
        }

        for (var i = 0; i < 20; i++) {
          expect(index.quality, quality);
        }
        expect(points.fold<int>(0, (sum, point) => sum + point.reads), 0);
      },
    );
  }
}

// Counts repeated validation without a machine-dependent stopwatch budget.
class _CountingCoordinate extends TripCoordinate {
  _CountingCoordinate(double latitude, double longitude)
    : super(latitude: latitude, longitude: longitude);

  int reads = 0;

  @override
  double get latitude {
    reads++;
    return super.latitude;
  }

  @override
  double get longitude {
    reads++;
    return super.longitude;
  }
}
