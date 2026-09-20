import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/storage/app_preferences.dart';
import 'package:picoradar/features/maintenance/data/maintenance_notification_preferences.dart';

void main() {
  test('maintenance date reminders require per-vehicle opt-in', () async {
    final memory = _MemoryPreferences();
    final preferences = MaintenanceNotificationPreferences(memory);

    expect(await preferences.isEnabled('vehicle-1'), isFalse);

    await preferences.setEnabled('vehicle-1', true);

    expect(await preferences.isEnabled('vehicle-1'), isTrue);
    expect(await preferences.isEnabled('vehicle-2'), isFalse);
  });
}

class _MemoryPreferences implements AppPreferences {
  final values = <String, Object?>{};

  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;

  @override
  Future<void> setBool(String key, bool value) async {
    values[key] = value;
  }

  @override
  Future<String?> getString(String key) async => values[key] as String?;

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<int?> getInt(String key) async => values[key] as int?;

  @override
  Future<void> setInt(String key, int value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}
