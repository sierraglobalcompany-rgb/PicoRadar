import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/location/data/location_preferences.dart';

import '../../../test_app_harness.dart';

void main() {
  test(
    'location preferences default to manual with no location data',
    () async {
      final preferences = MemoryPreferences();

      final value = await loadLocationPreferences(preferences);

      expect(value.mode, LocationMode.manual);
      expect(value.lastManualJurisdictionId, isNull);
      expect(value.lastGpsRefreshAt, isNull);
    },
  );

  test(
    'location preferences persist mode, manual city, and GPS refresh time',
    () async {
      final preferences = MemoryPreferences();
      final refreshAt = DateTime.utc(2026, 8, 27, 18, 30);

      await saveLocationMode(preferences, LocationMode.gpsAuto);
      await saveLastManualJurisdiction(preferences, 'co-dc-bogota');
      await saveLastGpsRefreshAt(preferences, refreshAt);

      final value = await loadLocationPreferences(preferences);

      expect(value.mode, LocationMode.gpsAuto);
      expect(value.lastManualJurisdictionId, 'co-dc-bogota');
      expect(value.lastGpsRefreshAt, refreshAt);
    },
  );

  test('unknown persisted mode fails closed to manual', () async {
    final preferences = MemoryPreferences();
    await preferences.setString(locationModePreferenceKey, 'continuousGps');

    final value = await loadLocationPreferences(preferences);

    expect(value.mode, LocationMode.manual);
  });
}
