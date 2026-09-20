import '../../../core/storage/app_preferences.dart';

class MaintenanceNotificationPreferences {
  const MaintenanceNotificationPreferences(this._preferences);

  static const _prefix = 'maintenance.notifications.date.';

  final AppPreferences _preferences;

  Future<bool> isEnabled(String vehicleId) async {
    return await _preferences.getBool(_key(vehicleId)) ?? false;
  }

  Future<void> setEnabled(String vehicleId, bool enabled) {
    return _preferences.setBool(_key(vehicleId), enabled);
  }

  String _key(String vehicleId) => '$_prefix$vehicleId';
}
