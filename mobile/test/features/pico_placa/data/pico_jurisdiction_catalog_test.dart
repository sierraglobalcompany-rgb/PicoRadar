import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/pico_placa/data/pico_jurisdiction_catalog.dart';

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
}

PicoJurisdictionCatalogEntry _city(
  PicoJurisdictionCatalog catalog,
  String name,
) => catalog.records.singleWhere((entry) => entry.name == name);

PicoJurisdictionCatalog _loadCatalog() {
  final raw = File(picoJurisdictionCatalogAssetPath).readAsStringSync();
  return PicoJurisdictionCatalog.fromJson(
    jsonDecode(raw) as Map<String, Object?>,
  );
}
