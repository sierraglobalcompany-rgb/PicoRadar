import 'dart:convert';

import '../../../core/storage/app_preferences.dart';

const peritajesDraftPreferencePrefix = 'peritajes.draft.v1.';

String peritajesDraftPreferenceKey(String vehicleId) {
  return '$peritajesDraftPreferencePrefix${vehicleId.trim()}';
}

class PeritajesDraft {
  const PeritajesDraft({
    required this.checkedItems,
    required this.notes,
    required this.updatedAt,
  });

  final Set<String> checkedItems;
  final String notes;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
    'checkedItems': checkedItems.toList()..sort(),
    'notes': notes,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  static PeritajesDraft fromJson(Map<String, Object?> json) {
    final rawItems = json['checkedItems'];
    final notes = json['notes'];
    final updatedAt = json['updatedAt'];
    if (rawItems is! List || notes is! String || updatedAt is! String) {
      throw const FormatException('Invalid peritajes draft.');
    }
    return PeritajesDraft(
      checkedItems: rawItems.whereType<String>().toSet(),
      notes: notes,
      updatedAt: DateTime.parse(updatedAt).toUtc(),
    );
  }
}

class PeritajesDraftStore {
  const PeritajesDraftStore(this._preferences);

  final AppPreferences _preferences;

  Future<PeritajesDraft?> loadDraft(String vehicleId) async {
    final raw = await _preferences.getString(
      peritajesDraftPreferenceKey(vehicleId),
    );
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('Peritajes draft must be a JSON object.');
      }
      return PeritajesDraft.fromJson(decoded);
    } on FormatException {
      await deleteDraft(vehicleId);
      return null;
    } on TypeError {
      await deleteDraft(vehicleId);
      return null;
    }
  }

  Future<void> saveDraft(String vehicleId, PeritajesDraft draft) {
    return _preferences.setString(
      peritajesDraftPreferenceKey(vehicleId),
      jsonEncode(draft.toJson()),
    );
  }

  Future<void> deleteDraft(String vehicleId) {
    return _preferences.remove(peritajesDraftPreferenceKey(vehicleId));
  }
}
