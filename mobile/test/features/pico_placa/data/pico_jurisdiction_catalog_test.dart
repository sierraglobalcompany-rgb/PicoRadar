import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/pico_placa/data/pico_jurisdiction_catalog.dart';

void main() {
  test('catalog parses audited Pico jurisdiction records uniquely', () {
    final catalog = _loadCatalog();
    final ids = <String>{};

    for (final entry in catalog.records) {
      expect(ids.add(entry.id), isTrue, reason: entry.id);
      expect(entry.name.trim(), isNotEmpty);
      expect(entry.department.trim(), isNotEmpty);
      expect(entry.classification.trim(), isNotEmpty);
    }

    expect(catalog.records.length, 16);
    expect(
      catalog.records
          .where((entry) => entry.classification == 'SUPPORTED_CURRENT')
          .map((entry) => entry.id),
      containsAll([
        'co-dc-bogota',
        'co-ant-medellin',
        'co-san-bucaramanga',
        'co-met-villavicencio',
        'co-cal-manizales',
        'co-atl-barranquilla',
        'co-cau-popayan',
      ]),
    );
    expect(
      catalog.records
          .singleWhere((entry) => entry.id == 'co-vac-cali')
          .classification,
      'CONDITIONED_SOURCE',
    );
    expect(
      catalog.records
          .singleWhere((entry) => entry.id == 'co-bol-cartagena')
          .classification,
      'CONDITIONED_SOURCE',
    );
    expect(
      catalog.records
          .singleWhere((entry) => entry.id == 'co-qui-armenia')
          .classification,
      'PENDING_EXACT_RULES',
    );
    expect(
      catalog.records
          .singleWhere((entry) => entry.id == 'co-tol-ibague')
          .classification,
      'PENDING_EXACT_RULES',
    );
    expect(
      catalog.records
          .singleWhere((entry) => entry.id == 'co-met-villavicencio')
          .classification,
      'SUPPORTED_CURRENT',
    );
  });

  test('pending catalog records explain conditional-rule blockers', () {
    final raw = jsonDecode(
      File(picoJurisdictionCatalogAssetPath).readAsStringSync(),
    ) as Map<String, Object?>;
    final records = (raw['records'] as List).cast<Map<String, Object?>>();

    expect(
      records.singleWhere(
        (entry) => entry['id'] == 'co-tol-ibague',
      )['pendingReason'],
      'CONDITIONAL_REGISTRATION_CITY_WINDOW_UNSUPPORTED',
    );
    expect(
      records.singleWhere(
        (entry) => entry['id'] == 'co-vac-cali',
      )['pendingReason'],
      'R4_CONDITIONED_SOURCE_NOT_AUTOMATIC',
    );
  });

  test('search matches city and department without accents', () {
    final catalog = _loadCatalog();

    expect(
      catalog.search('cali').map((entry) => entry.id),
      contains('co-vac-cali'),
    );
    expect(
      catalog.search('quindio').map((entry) => entry.id),
      contains('co-qui-armenia'),
    );
    expect(
      catalog.search('cauca').map((entry) => entry.id),
      contains('co-cau-popayan'),
    );
    expect(
      catalog.search('medellin').map((entry) => entry.id),
      contains('co-ant-medellin'),
    );
  });
}

PicoJurisdictionCatalog _loadCatalog() {
  final raw = File(picoJurisdictionCatalogAssetPath).readAsStringSync();
  return PicoJurisdictionCatalog.fromJson(
    jsonDecode(raw) as Map<String, Object?>,
  );
}
