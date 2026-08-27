import 'package:shared_preferences/shared_preferences.dart';

/// Stores only non-sensitive local settings.
class AppPreferences {
  AppPreferences({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  Future<bool?> getBool(String key) => _preferences.getBool(key);

  Future<void> setBool(String key, bool value) =>
      _preferences.setBool(key, value);

  Future<String?> getString(String key) => _preferences.getString(key);

  Future<void> setString(String key, String value) =>
      _preferences.setString(key, value);

  Future<int?> getInt(String key) => _preferences.getInt(key);

  Future<void> setInt(String key, int value) => _preferences.setInt(key, value);

  Future<void> remove(String key) => _preferences.remove(key);
}
