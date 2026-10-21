import 'dart:convert';

import '../../../core/storage/app_preferences.dart';

const garageFavoriteVehicleIdsPreferenceKey = 'garage_favorite_vehicle_ids_v1';
final _favoriteUpdates = Expando<Future<Object?>>();

Future<Set<String>> loadGarageFavoriteVehicleIds(
  AppPreferences preferences,
) async {
  final raw = await preferences.getString(
    garageFavoriteVehicleIdsPreferenceKey,
  );
  if (raw == null || raw.trim().isEmpty) {
    return {};
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    // Corrupt legacy data cannot nominate a favorite; storage errors propagate.
    return {};
  }
  if (decoded is! List) {
    return {};
  }
  return decoded.whereType<String>().toSet();
}

Future<T> serializeGarageFavoriteMutation<T>(
  AppPreferences preferences,
  Future<T> Function() mutation,
) {
  final previous = _favoriteUpdates[preferences] ?? Future<Object?>.value();
  // Include deletion/rollback in the same queue. Errors still reach each caller.
  final update = previous.then<T>(
    (_) => mutation(),
    onError: (Object error, StackTrace stack) => mutation(),
  );
  _favoriteUpdates[preferences] = update;
  return update;
}
