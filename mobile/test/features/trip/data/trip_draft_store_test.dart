import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/trip/application/trip_services.dart';
import 'package:picoradar/features/trip/data/trip_draft_store.dart';
import 'package:picoradar/features/trip/domain/trip_draft.dart';

import '../../../test_app_harness.dart';

void main() {
  group('TripDraftStore', () {
    late MemoryPreferences preferences;
    late TripDraftStore store;

    setUp(() {
      preferences = MemoryPreferences();
      store = TripDraftStore(preferences);
    });

    test('saves and restores the single local trip draft key', () async {
      final draft = TripDraft(
        origin: ' Bogotá ',
        destination: ' Medellín ',
        date: DateTime(2026, 9, 3),
        activeVehicleId: 'vehicle-a',
        completedChecklist: {
          TripChecklistItem.picoPlaca,
          TripChecklistItem.safety,
        },
      );

      await store.saveDraft(draft);

      expect(preferences.values.keys, [tripDraftPreferenceKey]);
      final decoded = jsonDecode(
        (await preferences.getString(tripDraftPreferenceKey))!,
      ) as Map<String, Object?>;
      expect(decoded['origin'], 'Bogotá');
      expect(decoded['destination'], 'Medellín');
      expect(decoded['date'], '2026-09-03');
      expect(decoded['activeVehicleId'], 'vehicle-a');
      expect(decoded['completedChecklist'], ['pico_placa', 'safety']);

      final restored = await store.loadDraft();

      expect(restored?.origin, 'Bogotá');
      expect(restored?.destination, 'Medellín');
      expect(restored?.date, DateTime(2026, 9, 3));
      expect(restored?.activeVehicleId, 'vehicle-a');
      expect(restored?.completedChecklist, {
        TripChecklistItem.picoPlaca,
        TripChecklistItem.safety,
      });
    });

    test('deletes the local draft', () async {
      await store.saveDraft(
        TripDraft(
          origin: 'Bogotá',
          destination: 'Cali',
          date: DateTime(2026, 9, 4),
        ),
      );

      await store.deleteDraft();

      expect(await store.loadDraft(), isNull);
      expect(preferences.values, isEmpty);
    });

    test('removes malformed draft instead of restoring stale data', () async {
      await preferences.setString(tripDraftPreferenceKey, '{broken');

      expect(await store.loadDraft(), isNull);
      expect(preferences.values, isEmpty);
    });
  });

  group('Trip external navigation URLs', () {
    test('builds Google Maps directions URL with optional origin', () {
      expect(
        googleMapsTripUrl(origin: 'Bogotá', destination: 'Medellín'),
        'https://www.google.com/maps/dir/?api=1&origin=Bogot%C3%A1&destination=Medell%C3%ADn&travelmode=driving',
      );
      expect(
        googleMapsTripUrl(destination: 'Medellín'),
        'https://www.google.com/maps/dir/?api=1&destination=Medell%C3%ADn&travelmode=driving',
      );
    });

    test('builds Waze and uses the verified INVÍAS SIV destination', () {
      expect(
        wazeTripUrl(destination: 'Medellín'),
        'https://waze.com/ul?q=Medell%C3%ADn&navigate=yes',
      );
      expect(inviasRoadStatusUrl, 'https://hermes2.invias.gov.co/SIV/');
    });
  });
}
