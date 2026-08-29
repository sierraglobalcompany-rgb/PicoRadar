import '../../../core/storage/app_preferences.dart';

const selectedAvatarPreferenceKey = 'profile_avatar_id_v1';
const vehicleVisualPreferencePrefix = 'vehicle_visual_v1_';

String vehicleVisualPreferenceKey(String vehicleId) {
  return '$vehicleVisualPreferencePrefix$vehicleId';
}

Future<String?> loadSelectedAvatarId(AppPreferences preferences) {
  return preferences.getString(selectedAvatarPreferenceKey);
}

Future<void> saveSelectedAvatarId(AppPreferences preferences, String avatarId) {
  return preferences.setString(selectedAvatarPreferenceKey, avatarId);
}

Future<String?> loadVehicleVisualOverride(
  AppPreferences preferences,
  String vehicleId,
) {
  return preferences.getString(vehicleVisualPreferenceKey(vehicleId));
}

Future<void> saveVehicleVisualOverride(
  AppPreferences preferences,
  String vehicleId,
  String visualId,
) {
  return preferences.setString(vehicleVisualPreferenceKey(vehicleId), visualId);
}

Future<void> clearVehicleVisualOverride(
  AppPreferences preferences,
  String vehicleId,
) {
  return preferences.remove(vehicleVisualPreferenceKey(vehicleId));
}
