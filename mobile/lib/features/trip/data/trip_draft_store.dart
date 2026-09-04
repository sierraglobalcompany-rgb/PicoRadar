import 'dart:convert';

import '../../../core/storage/app_preferences.dart';
import '../domain/trip_draft.dart';

const tripDraftPreferenceKey = 'trip.draft.v1';

class TripDraftStore {
  const TripDraftStore(this._preferences);

  final AppPreferences _preferences;

  Future<TripDraft?> loadDraft() async {
    final raw = await _preferences.getString(tripDraftPreferenceKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('Trip draft must be a JSON object.');
      }
      return TripDraft.fromJson(decoded);
    } on FormatException {
      await deleteDraft();
      return null;
    } on TypeError {
      await deleteDraft();
      return null;
    }
  }

  Future<void> saveDraft(TripDraft draft) {
    return _preferences.setString(
      tripDraftPreferenceKey,
      jsonEncode(draft.toJson()),
    );
  }

  Future<void> deleteDraft() {
    return _preferences.remove(tripDraftPreferenceKey);
  }
}
