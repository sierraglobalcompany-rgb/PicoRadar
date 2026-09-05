import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/trip/data/trip_municipality_catalog.dart';

void main() {
  late Map<String, Object?> json;
  late TripMunicipalityCatalog catalog;

  setUpAll(() {
    json = jsonDecode(
      File('assets/catalogs/colombia_trip_municipalities_v1.json')
          .readAsStringSync(),
    ) as Map<String, Object?>;
    catalog = TripMunicipalityCatalog.fromJson(json);
  });

  test('declares provenance and published B02 fixture coverage', () {
    final source = json['source']! as Map<String, Object?>;
    final coverage = json['coverage']! as Map<String, Object?>;

    expect(json['schemaVersion'], 1);
    expect(json['version'], 'mgn_2025-b02');
    expect(source['authority'], 'DANE');
    expect(source['version'], '2025');
    expect(source['sourceDate'], '2026-08-31');
    expect(
      source['sourceFixtureSha256'],
      '8E54157CD2C0E8F3FEA80D7FC383EC26A801C0116AAA741064DEEE1E481CFCAC',
    );
    expect(source.containsKey('assetSha256'), isFalse);
    expect(coverage['departments'], 33);
    expect(coverage['municipalities'], 1104);
    expect(coverage['jurisdictionMappingSourceDate'], '2026-08-31');
    expect(
      coverage['jurisdictionMappingSourceSha256'],
      '742D6948C48A80609DD2C8B0E05A0D70FD7F85D994EB60AB6C128E7868248DC7',
    );
    expect(catalog.records, hasLength(1104));
    expect(catalog.records.map((entry) => entry.code).toSet(), hasLength(1104));
  });

  test('search starts at three normalized characters', () {
    expect(catalog.search('bo'), isEmpty);
    expect(catalog.search('d.c'), isEmpty);
    expect(catalog.search('BOG').map((entry) => entry.code), contains('11001'));
  });

  test('search ignores accents and keeps homonyms distinguishable', () {
    final unions = catalog
        .search('union')
        .where((entry) => entry.municipality == 'La Unión')
        .toList();

    expect(
      unions.map((entry) => entry.department),
      containsAll(['Antioquia', 'Nariño']),
    );
  });

  test('carries existing B02 municipality to jurisdiction coverage', () {
    final byCode = {for (final entry in catalog.records) entry.code: entry};

    expect(byCode['11001']?.jurisdictionId, 'co-dc-bogota');
    expect(byCode['05001']?.jurisdictionId, 'co-ant-medellin');
    expect(byCode['05088']?.jurisdictionId, 'co-ant-medellin');
    expect(byCode['05631']?.jurisdictionId, 'co-ant-medellin');
    expect(byCode['05002']?.jurisdictionId, isNull);
  });

  test('bare homonym is not resolved by catalog order', () {
    expect(catalog.findExact('Barbosa'), isNull);
    expect(catalog.findExact('Barbosa · Antioquia')?.code, '05079');
    expect(catalog.findExact('Barbosa · Santander')?.code, '68077');
  });
}
