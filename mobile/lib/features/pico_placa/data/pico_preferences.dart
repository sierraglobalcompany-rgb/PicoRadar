import '../../../core/storage/app_preferences.dart';

const picoJurisdictionPreferenceKey = 'pico_jurisdiction_id_v1';
const picoRestrictionAlertsEnabledKey = 'pico_restriction_alerts_enabled_v1';
const picoDayBeforeAlertsEnabledKey = 'pico_day_before_alerts_enabled_v1';
const picoSameDayAlertsEnabledKey = 'pico_same_day_alerts_enabled_v1';
const picoDayBeforeMinuteKey = 'pico_day_before_minute_v1';
const picoSameDayMinuteKey = 'pico_same_day_minute_v1';
const picoNotificationPermissionRequestedKey =
    'pico_notification_permission_requested_v1';

class PicoAlertPreferences {
  const PicoAlertPreferences({
    required this.enabled,
    required this.dayBeforeEnabled,
    required this.sameDayEnabled,
    required this.dayBeforeMinute,
    required this.sameDayMinute,
    required this.permissionRequested,
  });

  final bool enabled;
  final bool dayBeforeEnabled;
  final bool sameDayEnabled;
  final int dayBeforeMinute;
  final int sameDayMinute;
  final bool permissionRequested;
}

Future<PicoAlertPreferences> loadPicoAlertPreferences(
  AppPreferences preferences,
) async {
  return PicoAlertPreferences(
    enabled: await preferences.getBool(picoRestrictionAlertsEnabledKey) ?? true,
    dayBeforeEnabled:
        await preferences.getBool(picoDayBeforeAlertsEnabledKey) ?? true,
    sameDayEnabled:
        await preferences.getBool(picoSameDayAlertsEnabledKey) ?? true,
    dayBeforeMinute:
        await preferences.getInt(picoDayBeforeMinuteKey) ?? 19 * 60,
    sameDayMinute: await preferences.getInt(picoSameDayMinuteKey) ?? 5 * 60,
    permissionRequested:
        await preferences.getBool(picoNotificationPermissionRequestedKey) ??
        false,
  );
}

Future<void> savePicoAlertPreferences(
  AppPreferences preferences,
  PicoAlertPreferences value,
) async {
  await preferences.setBool(picoRestrictionAlertsEnabledKey, value.enabled);
  await preferences.setBool(
    picoDayBeforeAlertsEnabledKey,
    value.dayBeforeEnabled,
  );
  await preferences.setBool(picoSameDayAlertsEnabledKey, value.sameDayEnabled);
  await preferences.setInt(picoDayBeforeMinuteKey, value.dayBeforeMinute);
  await preferences.setInt(picoSameDayMinuteKey, value.sameDayMinute);
  await preferences.setBool(
    picoNotificationPermissionRequestedKey,
    value.permissionRequested,
  );
}
