import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/pico_placa/data/pico_jurisdiction_catalog.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';
import 'package:picoradar/features/trip/data/trip_municipality_catalog.dart';

void main() {
  test('catalog represents all 73 source municipalities exactly once', () {
    final catalog = _loadCatalog();

    expect(catalog.version, '2026.09.19-operational-v1');
    expect(catalog.sourceCutoff, '2026-09-10');
    expect(catalog.asOfDate, '2026-09-19');
    expect(catalog.records, hasLength(73));
    expect(catalog.records.map((entry) => entry.id).toSet(), hasLength(73));
    expect(
      catalog.records.map((entry) => entry.municipalityCode).toSet(),
      hasLength(73),
    );
  });

  test('operational status counts match the documentary reconciliation', () {
    final catalog = _loadCatalog();
    final counts = {
      for (final status in PicoOperationalStatus.values)
        status: catalog.records.where((entry) => entry.status == status).length,
    };

    expect(counts, {
      PicoOperationalStatus.verified: 6,
      PicoOperationalStatus.conditional: 36,
      PicoOperationalStatus.expired: 2,
      PicoOperationalStatus.pending: 29,
    });
  });

  test('only five verified municipalities are enabled in the engine', () {
    final catalog = _loadCatalog();
    final enabled = catalog.records.where((entry) => entry.engineEnabled);

    expect(enabled.map((entry) => entry.id).toSet(), {
      'co-dc-bogota',
      'co-ant-medellin',
      'co-san-bucaramanga',
      'co-cau-popayan',
      'co-met-villavicencio',
    });
    expect(
      enabled.every((entry) => entry.status == PicoOperationalStatus.verified),
      isTrue,
    );
  });

  test('representative statuses do not invent current rules', () {
    final catalog = _loadCatalog();

    expect(_city(catalog, 'Itagüí').status, PicoOperationalStatus.verified);
    expect(_city(catalog, 'Itagüí').engineEnabled, isFalse);
    expect(_city(catalog, 'Medellín').engineEnabled, isTrue);
    expect(
      _city(catalog, 'Barranquilla').status,
      PicoOperationalStatus.expired,
    );
    expect(_city(catalog, 'Manizales').status, PicoOperationalStatus.expired);
    expect(_city(catalog, 'Cali').status, PicoOperationalStatus.conditional);
    expect(_city(catalog, 'Armenia').status, PicoOperationalStatus.pending);
  });

  test('every record retains worksheet evidence and a truthful summary', () {
    final catalog = _loadCatalog();
    for (final entry in catalog.records) {
      expect(entry.evidenceSummary.trim(), isNotEmpty, reason: entry.name);
      expect(entry.evidenceRecordIds, isNotEmpty, reason: entry.name);
      expect(
        entry.sourceUrls.every((url) => url.startsWith('https://')),
        isTrue,
        reason: entry.name,
      );
      if (entry.sourceUrls.isEmpty) {
        expect(entry.status, PicoOperationalStatus.pending);
      }
    }
  });

  test('parser rejects summary or engine drift', () {
    final raw = jsonDecode(
      File(picoJurisdictionCatalogAssetPath).readAsStringSync(),
    ) as Map<String, Object?>;
    final summary = raw['summary'] as Map<String, Object?>;
    summary['verified'] = 7;
    expect(() => PicoJurisdictionCatalog.fromJson(raw), throwsFormatException);
  });

  test('search matches city and department without accents', () {
    final catalog = _loadCatalog();
    expect(catalog.search('cali').map((entry) => entry.name), contains('Cali'));
    expect(
      catalog.search('quindio').map((entry) => entry.name),
      contains('Armenia'),
    );
    expect(
      catalog.search('medellin').map((entry) => entry.name),
      contains('Medellín'),
    );
  });

  test(
    'national options merge 1,104 DIVIPOLA municipalities without rules',
    () {
      final pico = _loadCatalog();
      final trip = _loadTripCatalog();
      final combined = mergePicoMunicipalityOptions(
        pico,
        trip.records.map(
          (item) => (
            code: item.code,
            municipality: item.municipality,
            department: item.department,
          ),
        ),
      );

      expect(combined.records, hasLength(1104));
      expect(
        combined.records.map((entry) => entry.municipalityCode).toSet(),
        hasLength(1104),
      );
      expect(
        combined.records.map((entry) => entry.id).toSet(),
        hasLength(1104),
      );

      final originalCodes = pico.records
          .map((entry) => entry.municipalityCode)
          .toSet();
      final added = combined.records.where(
        (entry) => !originalCodes.contains(entry.municipalityCode),
      );
      expect(added, hasLength(1031));
      for (final entry in added) {
        expect(entry.id, 'co-mun-${entry.municipalityCode}');
        expect(entry.status, PicoOperationalStatus.pending);
        expect(entry.classification, 'GEOGRAPHIC_ONLY');
        expect(entry.engineEnabled, isFalse);
        expect(entry.engineJurisdictionId, isNull);
        expect(entry.evidenceRecordIds, isEmpty);
        expect(entry.sourceIds, isEmpty);
        expect(entry.sourceUrls, isEmpty);
      }
      for (final original in pico.records) {
        expect(
          identical(
            combined.records.singleWhere(
              (entry) => entry.municipalityCode == original.municipalityCode,
            ),
            original,
          ),
          isTrue,
          reason: original.municipalityCode,
        );
      }
    },
  );

  test('national search separates La Union homonyms and resolves DIVIPOLA', () {
    final pico = _loadCatalog();
    final trip = _loadTripCatalog();
    final combined = mergePicoMunicipalityOptions(
      pico,
      trip.records.map(
        (item) => (
          code: item.code,
          municipality: item.municipality,
          department: item.department,
        ),
      ),
    );

    final laUnion = combined.search('La Unión');
    expect(laUnion, hasLength(4));
    expect(laUnion.map((entry) => entry.municipalityCode).toSet(), {
      '05400',
      '52399',
      '70400',
      '76400',
    });
    expect(combined.search('05400').single.department, 'Antioquia');
    expect(
      combined
          .search('medellin')
          .any((entry) => entry.municipalityCode == '05001'),
      isTrue,
    );
    expect(
      combined.search('cali').any((entry) => entry.municipalityCode == '76001'),
      isTrue,
    );
    expect(
      combined
          .search('bogota')
          .any((entry) => entry.municipalityCode == '11001'),
      isTrue,
    );
  });
  test('runtime availability overrides seed without inventing new entries', () {
    final catalog = _loadCatalog();
    final disabledSeed = _city(catalog, 'Itagüí');
    final runtime = catalog.withRuntimeAvailability([
      RestrictionJurisdiction(
        id: disabledSeed.id,
        name: disabledSeed.name,
        municipalityCodes: [disabledSeed.municipalityCode],
        consultationEnabled: true,
      ),
      const RestrictionJurisdiction(
        id: 'co-new-supported',
        name: 'Municipio nuevo',
        municipalityCodes: ['99001'],
        consultationEnabled: true,
      ),
      const RestrictionJurisdiction(
        id: 'co-dc-bogota',
        name: 'Bogotá',
        municipalityCodes: ['11001'],
        consultationEnabled: false,
      ),
      const RestrictionJurisdiction(
        id: 'co-new-disabled',
        name: 'No habilitado',
        municipalityCodes: ['99002'],
        consultationEnabled: false,
      ),
    ]);

    expect(
      runtime.singleWhere((entry) => entry.id == disabledSeed.id).engineEnabled,
      isTrue,
    );
    expect(
      runtime.singleWhere((entry) => entry.id == 'co-dc-bogota').engineEnabled,
      isFalse,
    );
    expect(runtime.any((entry) => entry.id == 'co-new-supported'), isTrue);
    final limited = catalog.withRuntimeAvailability(const [
      RestrictionJurisdiction(
        id: 'co-new-supported',
        name: 'Municipio nuevo',
        municipalityCodes: ['99001'],
        consultationEnabled: true,
      ),
    ], includeUnlisted: false);
    expect(limited.any((entry) => entry.id == 'co-new-supported'), isFalse);
    expect(runtime.any((entry) => entry.id == 'co-new-disabled'), isFalse);
    expect(runtime.any((entry) => entry.id == 'co-unmapped-new-city'), isFalse);
    expect(_city(catalog, 'Itagüí').engineEnabled, isFalse);
    expect(_city(catalog, 'Bogotá').engineEnabled, isTrue);
  });
}

PicoJurisdictionCatalogEntry _city(
  PicoJurisdictionCatalog catalog,
  String name,
) => catalog.records.singleWhere((entry) => entry.name == name);

TripMunicipalityCatalog _loadTripCatalog() {
  final raw = File(tripMunicipalityCatalogAssetPath).readAsStringSync();
  return TripMunicipalityCatalog.fromJson(
    jsonDecode(raw) as Map<String, Object?>,
  );
}

PicoJurisdictionCatalog _loadCatalog() {
  final raw = File(picoJurisdictionCatalogAssetPath).readAsStringSync();
  return PicoJurisdictionCatalog.fromJson(
    jsonDecode(raw) as Map<String, Object?>,
  );
}
