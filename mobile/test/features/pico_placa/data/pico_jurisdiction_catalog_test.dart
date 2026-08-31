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
        'co-vac-cali',
        'co-bol-cartagena',
        'co-san-bucaramanga',
        'co-tol-ibague',
        'co-met-villavicencio',
        'co-cau-popayan',
      ]),
    );
    expect(
      catalog.records
          .singleWhere((entry) => entry.id == 'co-qui-armenia')
          .classification,
      'PENDING_EXACT_RULES',
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
