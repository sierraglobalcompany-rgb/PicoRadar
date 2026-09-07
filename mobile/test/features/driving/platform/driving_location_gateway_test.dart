import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:picoradar/features/driving/platform/driving_location_gateway.dart';

void main() {
  test('Android driving requests one-second fixes without distance gating', () {
    final settings = drivingLocationSettings(TargetPlatform.android);

    expect(settings, isA<geo.AndroidSettings>());
    final android = settings as geo.AndroidSettings;
    expect(android.accuracy, geo.LocationAccuracy.bestForNavigation);
    expect(android.distanceFilter, 0);
    expect(android.intervalDuration, const Duration(seconds: 1));
    expect(android.foregroundNotificationConfig, isNull);
  });

  test(
    'speed conversion distinguishes unavailable values from a real stop',
    () {
      expect(drivingSpeedKmh(0), 0);
      expect(drivingSpeedKmh(10), 36);
      expect(drivingSpeedKmh(-1), isNull);
      expect(drivingSpeedKmh(double.nan), isNull);
      expect(drivingSpeedKmh(double.infinity), isNull);
    },
  );
}
