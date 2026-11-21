import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/data/pico_jurisdiction_catalog.dart';
import 'package:picoradar/features/pico_placa/data/restriction_dataset.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';
import 'package:picoradar/features/trip/data/trip_municipality_catalog.dart';

void main() {
  test(
    'published availability drives Pico and a separate Trip projection',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final now = DateTime.utc(2026, 11, 10);
      for (final city in const [
        ('co-seed-disabled', 'Disabled seed'),
        ('co-seed-enabled', 'Enabled seed'),
        ('co-new-no-metadata', 'No metadata'),
        ('co-overlap-one', 'Overlap one'),
        ('co-overlap-two', 'Overlap two'),
        ('co-new-city', 'New city'),
      ]) {
        await database
            .into(database.restrictionCoverages)
            .insert(
              RestrictionCoveragesCompanion.insert(
                id: '${city.$1}:car:private',
                jurisdictionId: city.$1,
                jurisdictionName: city.$2,
                vehicleKind: 'car',
                serviceType: 'private',
                rulesJson: '[]',
                verifiedAt: now,
                staleAfter: DateTime.utc(2026, 12, 10),
                sourceUrlsJson: '[]',
              ),
            );
      }
      await _availability(database, 'co-seed-disabled', ['05001'], true);
      await _availability(database, 'co-seed-enabled', ['05002'], false);
      await _availability(database, 'co-overlap-one', ['05003'], true);
      await _availability(database, 'co-overlap-two', ['05003'], true);
      await _availability(database, 'co-new-city', ['05004'], true);

      final picoCatalog = PicoJurisdictionCatalog(
        records: [
          _seed('co-seed-disabled', enabled: false),
          _seed('co-seed-enabled', enabled: true),
        ],
      );
      const tripCatalog = TripMunicipalityCatalog(
        records: [
          TripMunicipality(
            code: '05001',
            municipality: 'Municipio uno',
            department: 'Antioquia',
          ),
          TripMunicipality(
            code: '05002',
            municipality: 'Municipio dos',
            department: 'Antioquia',
            jurisdictionId: 'co-seed-enabled',
          ),
          TripMunicipality(
            code: '05003',
            municipality: 'Municipio tres',
            department: 'Antioquia',
          ),
          TripMunicipality(
            code: '05004',
            municipality: 'Municipio cuatro',
            department: 'Antioquia',
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          bundledRestrictionsProvider.overrideWith((ref) async {}),
          picoJurisdictionCatalogProvider.overrideWith(
            (ref) async => picoCatalog,
          ),
          tripMunicipalityCatalogProvider.overrideWith(
            (ref) async => tripCatalog,
          ),
        ],
      );

      try {
        final pico = await container.read(
          restrictionJurisdictionsProvider.future,
        );
        expect(pico.map((city) => city.id), contains('co-seed-disabled'));
        expect(pico.map((city) => city.id), isNot(contains('co-seed-enabled')));
        expect(
          pico.map((city) => city.id),
          isNot(contains('co-new-no-metadata')),
        );
        expect(pico.map((city) => city.id), contains('co-new-city'));

        final shared = await container.read(
          tripMunicipalityCatalogProvider.future,
        );
        final mapped = await container.read(
          tripRestrictionMappedMunicipalitiesProvider.future,
        );
        expect(shared.findByCode('05001')?.jurisdictionId, isNull);
        expect(mapped.findByCode('05001')?.jurisdictionId, 'co-seed-disabled');
        expect(mapped.findByCode('05002')?.jurisdictionId, isNull);
        expect(mapped.findByCode('05003')?.jurisdictionId, isNull);
        expect(
          mapped.findByCode('05003')?.jurisdictionMappingAmbiguous,
          isTrue,
        );
        expect(mapped.findByCode('05004')?.jurisdictionId, 'co-new-city');

        await _availability(database, 'co-new-city', ['05002'], true);
        container.read(datasetSyncCommitHandlerProvider)('restrictions');
        final refreshed = await container.read(
          tripRestrictionMappedMunicipalitiesProvider.future,
        );
        expect(refreshed.findByCode('05002')?.jurisdictionId, 'co-new-city');
        expect(
          (await container.read(tripMunicipalityCatalogProvider.future))
              .findByCode('05002')
              ?.jurisdictionId,
          'co-seed-enabled',
        );
      } finally {
        container.dispose();
        await database.close();
      }
    },
  );

  test('schema2 revisions disable and reactivate a seed while retaining a new city', () async {
    final database = AppDatabase(NativeDatabase.memory());
    final now = DateTime.utc(2026, 11, 16, 12);
    final picoCatalog = PicoJurisdictionCatalog.fromJson(
      jsonDecode(File(picoJurisdictionCatalogAssetPath).readAsStringSync())
          as Map<String, Object?>,
    );
    final tripCatalog = TripMunicipalityCatalog.fromJson(
      jsonDecode(File(tripMunicipalityCatalogAssetPath).readAsStringSync())
          as Map<String, Object?>,
    );
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        bundledRestrictionsProvider.overrideWith((ref) async {}),
        picoJurisdictionCatalogProvider.overrideWith(
          (ref) async => picoCatalog,
        ),
        tripMunicipalityCatalogProvider.overrideWith(
          (ref) async => tripCatalog,
        ),
      ],
    );

    try {
      for (final snapshot in [
        ('synthetic-v1', true, 1, [1], 360, 600),
        ('synthetic-v2', false, 2, [2], 720, 900),
        ('synthetic-v3', true, 3, [3], 960, 1200),
      ]) {
        final (version, enabled, digit, weekdays, start, end) = snapshot;
        await importRestrictionsDataset(
          database,
          _schema2Snapshot(
            version: version,
            aEnabled: enabled,
            aDigit: digit,
            aWeekdays: weekdays,
            aStart: start,
            aEnd: end,
          ),
          now: () => now,
        );
        await database
            .into(database.datasetVersions)
            .insertOnConflictUpdate(
              DatasetVersionsCompanion.insert(
                id: restrictionsDatasetKey,
                datasetKey: restrictionsDatasetKey,
                version: version,
                status: 'installed',
              ),
            );
        container.read(datasetSyncCommitHandlerProvider)(
          restrictionsDatasetKey,
        );

        final versionRow =
            await (database.select(database.datasetVersions)..where(
                  (row) => row.datasetKey.equals(restrictionsDatasetKey),
                ))
                .getSingle();
        expect(versionRow.version, version);

        final active = await container.read(
          restrictionJurisdictionsProvider.future,
        );
        final activeIds = active.map((city) => city.id).toSet();
        expect(activeIds.contains('co-ant-medellin'), enabled);
        expect(activeIds, contains('co-new-abejorral'));

        final picoEntries = picoCatalog.withRuntimeAvailability(active);
        final medellin = picoEntries.singleWhere(
          (entry) => entry.id == 'co-ant-medellin',
        );
        final abejorral = picoEntries.singleWhere(
          (entry) => entry.id == 'co-new-abejorral',
        );
        expect(
          medellin.engineEnabled && activeIds.contains(medellin.id),
          enabled,
        );
        expect(abejorral.name, 'Abejorral');
        expect(
          abejorral.engineEnabled && activeIds.contains(abejorral.id),
          isTrue,
        );

        final trip = await container.read(
          tripRestrictionMappedMunicipalitiesProvider.future,
        );
        expect(
          trip.findByCode('05001')?.jurisdictionId,
          enabled ? 'co-ant-medellin' : isNull,
        );
        expect(trip.findByCode('05002')?.displayName, 'Abejorral · Antioquia');
        expect(trip.findByCode('05002')?.jurisdictionId, 'co-new-abejorral');

        final store = RestrictionStore(database);
        for (final category in const [
          (VehicleKind.car, VehicleServiceType.private),
          (VehicleKind.car, VehicleServiceType.taxi),
          (VehicleKind.motorcycle, VehicleServiceType.private),
        ]) {
          final aCoverage = await store.loadCoverage(
            'co-ant-medellin',
            category.$1,
            category.$2,
            now,
          );
          final bCoverage = await store.loadCoverage(
            'co-new-abejorral',
            category.$1,
            category.$2,
            now,
          );
          expect(aCoverage.coverageKnown, isTrue);
          expect(aCoverage.dataIsStale, isFalse);
          expect(bCoverage.coverageKnown, isTrue);
          expect(bCoverage.dataIsStale, isFalse);
          expect(bCoverage.rules.single.digits, {9});
        }

        final aCar = await store.loadCoverage(
          'co-ant-medellin',
          VehicleKind.car,
          VehicleServiceType.private,
          now,
        );
        expect(aCar.rules.single.digits, {digit});
        expect(aCar.rules.single.weekdays, weekdays.toSet());
        expect(aCar.rules.single.timeWindows.single.startMinute, start);
        expect(aCar.rules.single.timeWindows.single.endMinute, end);
      }
    } finally {
      container.dispose();
      await database.close();
    }
  });
}

PicoJurisdictionCatalogEntry _seed(String id, {required bool enabled}) {
  return PicoJurisdictionCatalogEntry(
    id: id,
    name: id,
    department: 'Antioquia',
    classification: 'fixture',
    sourceDate: '2026-11-10',
    municipalityCode: '05001',
    status: PicoOperationalStatus.verified,
    engineEnabled: enabled,
    engineJurisdictionId: enabled ? id : null,
  );
}

Future<void> _availability(
  AppDatabase database,
  String jurisdictionId,
  List<String> codes,
  bool enabled,
) async {
  await database
      .into(database.restrictionJurisdictionAvailability)
      .insertOnConflictUpdate(
        RestrictionJurisdictionAvailabilityCompanion.insert(
          jurisdictionId: jurisdictionId,
          municipalityCodesJson:
              '[${codes.map((code) => '"$code"').join(',')}]',
          consultationEnabled: enabled,
        ),
      );
}

Map<String, dynamic> _schema2Snapshot({
  required String version,
  required bool aEnabled,
  required int aDigit,
  required List<int> aWeekdays,
  required int aStart,
  required int aEnd,
}) => {
  'schemaVersion': 2,
  'datasetKey': restrictionsDatasetKey,
  'version': version,
  'generatedAt': '2026-11-16T12:00:00Z',
  'expiresAt': '2026-12-31T00:00:00Z',
  'jurisdictions': [
    _schema2Jurisdiction(
      id: 'co-ant-medellin',
      name: 'Medellín',
      code: '05001',
      enabled: aEnabled,
      digit: aDigit,
      weekdays: aWeekdays,
      start: aStart,
      end: aEnd,
    ),
    _schema2Jurisdiction(
      id: 'co-new-abejorral',
      name: 'Abejorral',
      code: '05002',
      enabled: true,
      digit: 9,
      weekdays: const [4],
      start: 600,
      end: 780,
    ),
  ],
};

Map<String, Object?> _schema2Jurisdiction({
  required String id,
  required String name,
  required String code,
  required bool enabled,
  required int digit,
  required List<int> weekdays,
  required int start,
  required int end,
}) => {
  'schemaVersion': 2,
  'id': id,
  'name': name,
  'municipalityCodes': [code],
  'consultationEnabled': enabled,
  'coverages': [
    for (final category in const [
      ('car', 'private'),
      ('car', 'taxi'),
      ('motorcycle', 'private'),
    ])
      {
        'vehicleKind': category.$1,
        'serviceType': category.$2,
        'coverageCompleteness': 'partial',
        'verifiedAt': '2026-11-16T00:00:00Z',
        'staleAfter': '2026-12-01T00:00:00Z',
        'sourceUrls': ['https://example.test/$id'],
        'rules': [
          {
            'id': '${category.$1}-${category.$2}-synthetic-rule',
            'priority': 10,
            'effect': 'restrict',
            'validFrom': '2026-11-01T00:00:00Z',
            'validUntil': '2026-12-31T23:59:59Z',
            'weekdays': weekdays,
            'digitPosition': 'lastNumeric',
            'digits': [digit],
            'timeWindows': [
              {'startMinute': start, 'endMinute': end},
            ],
            'appliesOnHolidays': false,
            'sourceUrl': 'https://example.test/$id',
            'verifiedAt': '2026-11-16T00:00:00Z',
            'conditions': <Object?>[],
          },
        ],
      },
  ],
};
