import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/storage/app_preferences.dart';
import 'package:picoradar/features/peritajes/data/peritajes_draft_store.dart';

void main() {
  test('uses one AppPreferences key per vehicle', () {
    expect(
      peritajesDraftPreferenceKey(' vehicle-1 '),
      'peritajes.draft.v1.vehicle-1',
    );
  });

  test('saves restores and deletes a vehicle draft', () async {
    final preferences = _MemoryPreferences();
    final store = PeritajesDraftStore(preferences);

    await store.saveDraft(
      'vehicle-1',
      PeritajesDraft(
        checkedItems: const {'motor/transmision', 'sistemas electricos'},
        notes: 'Revisar ruido al acelerar.',
        updatedAt: DateTime.utc(2026),
      ),
    );

    expect(preferences.values.keys, contains('peritajes.draft.v1.vehicle-1'));
    expect(await store.loadDraft('vehicle-2'), isNull);

    final restored = await store.loadDraft('vehicle-1');
    expect(restored?.checkedItems, {
      'motor/transmision',
      'sistemas electricos',
    });
    expect(restored?.notes, 'Revisar ruido al acelerar.');

    await store.deleteDraft('vehicle-1');
    expect(await store.loadDraft('vehicle-1'), isNull);
  });

  test('deletes malformed draft instead of throwing', () async {
    final preferences = _MemoryPreferences();
    final store = PeritajesDraftStore(preferences);
    await preferences.setString('peritajes.draft.v1.vehicle-1', 'not-json');

    expect(await store.loadDraft('vehicle-1'), isNull);
    expect(preferences.values, isNot(contains('peritajes.draft.v1.vehicle-1')));
  });
}

class _MemoryPreferences implements AppPreferences {
  final values = <String, Object?>{};

  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;

  @override
  Future<int?> getInt(String key) async => values[key] as int?;

  @override
  Future<String?> getString(String key) async => values[key] as String?;

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<void> setBool(String key, bool value) async {
    values[key] = value;
  }

  @override
  Future<void> setInt(String key, int value) async {
    values[key] = value;
  }

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}
