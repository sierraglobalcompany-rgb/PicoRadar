import 'dart:convert';

import '../../../core/storage/app_preferences.dart';

const garageFavoriteVehicleIdsPreferenceKey = 'garage_favorite_vehicle_ids_v1';

Future<Set<String>> loadGarageFavoriteVehicleIds(
  AppPreferences preferences,
) async {
  final raw = await preferences.getString(
    garageFavoriteVehicleIdsPreferenceKey,
  );
  if (raw == null || raw.trim().isEmpty) {
    return {};
  }
  final decoded = jsonDecode(raw);
  if (decoded is! List) {
    return {};
  }
  return decoded.whereType<String>().toSet();
}

Future<void> saveGarageFavoriteVehicleIds(
  AppPreferences preferences,
  Set<String> vehicleIds,
) {
  final sorted = vehicleIds.toList()..sort();
  return preferences.setString(
    garageFavoriteVehicleIdsPreferenceKey,
    jsonEncode(sorted),
  );
}

Future<Set<String>> toggleGarageFavoriteVehicleId(
  AppPreferences preferences,
  String vehicleId,
) async {
  final current = await loadGarageFavoriteVehicleIds(preferences);
  final next = {...current};
  if (!next.add(vehicleId)) {
    next.remove(vehicleId);
  }
  await saveGarageFavoriteVehicleIds(preferences, next);
  return next;
}
