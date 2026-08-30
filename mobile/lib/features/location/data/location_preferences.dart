import '../../../core/storage/app_preferences.dart';

const locationModePreferenceKey = 'location_mode_v1';
const lastManualJurisdictionPreferenceKey = 'last_manual_jurisdiction_id_v1';
const lastGpsRefreshAtPreferenceKey = 'last_gps_refresh_at_v1';

enum LocationMode {
  manual('manual'),
  gpsAuto('gpsAuto');

  const LocationMode(this.value);

  final String value;

  static LocationMode fromValue(String? value) {
    return switch (value) {
      'gpsAuto' => LocationMode.gpsAuto,
      'manual' || null => LocationMode.manual,
      _ => LocationMode.manual,
    };
  }
}

class LocationPreferences {
  const LocationPreferences({
    required this.mode,
    required this.lastManualJurisdictionId,
    required this.lastGpsRefreshAt,
  });

  final LocationMode mode;
  final String? lastManualJurisdictionId;
  final DateTime? lastGpsRefreshAt;
}

Future<LocationPreferences> loadLocationPreferences(
  AppPreferences preferences,
) async {
  final refreshMillis = await preferences.getInt(lastGpsRefreshAtPreferenceKey);
  return LocationPreferences(
    mode: LocationMode.fromValue(
      await preferences.getString(locationModePreferenceKey),
    ),
    lastManualJurisdictionId: await preferences.getString(
      lastManualJurisdictionPreferenceKey,
    ),
    lastGpsRefreshAt: refreshMillis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(refreshMillis, isUtc: true),
  );
}

Future<void> saveLocationMode(
  AppPreferences preferences,
  LocationMode mode,
) async {
  await preferences.setString(locationModePreferenceKey, mode.value);
}

Future<void> saveLastManualJurisdiction(
  AppPreferences preferences,
  String jurisdictionId,
) async {
  await preferences.setString(
    lastManualJurisdictionPreferenceKey,
    jurisdictionId,
  );
}

Future<void> saveLastGpsRefreshAt(
  AppPreferences preferences,
  DateTime timestamp,
) async {
  await preferences.setInt(
    lastGpsRefreshAtPreferenceKey,
    timestamp.toUtc().millisecondsSinceEpoch,
  );
}
