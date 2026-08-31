import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/cda/data/cda_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('catalog parser loads the generated official RUNT asset', () async {
    final catalog = await loadCdaCatalog(rootBundle);

    expect(catalog.source.datasetId, 'epfm-5fhb');
    expect(catalog.metrics.sourceRows, greaterThan(0));
    expect(catalog.metrics.cdaSourceRows, greaterThan(0));
    expect(catalog.metrics.latestSourcePeriod, '2026-07');
    expect(catalog.metrics.currentUniqueCdaCount, catalog.entries.length);
    expect(catalog.metrics.staleHistoricalCdaExcludedCount, 1);
    expect(catalog.entries, isNotEmpty);
    expect(catalog.metrics.uniqueCdaCount, catalog.entries.length);
    expect(catalog.metrics.sponsoredCdaCount, 0);
    expect(catalog.entries.every((entry) => entry.certified), isTrue);
    expect(catalog.entries.every((entry) => entry.novelty == 'NO'), isTrue);
  });

  test('CDA-only filter rejects non-CDA actors', () {
    final entries = currentOfficialCdaEntries([
      _row(id: '1', name: 'CDA Uno', actorType: 'CDA'),
      _row(id: '2', name: 'Concesionario Uno', actorType: 'CONCESIONARIO'),
    ], timestamp: DateTime.utc(2026, 8, 31));

    expect(entries.map((entry) => entry.name), ['CDA Uno']);
  });

  test('old safe historical CDA absent from latest period is excluded', () {
    final entries = currentOfficialCdaEntries([
      _row(id: '1', name: 'CDA Viejo', year: 2026, month: 6),
      _row(id: '2', name: 'CDA Actual', year: 2026, month: 7),
    ], timestamp: DateTime.utc(2026, 8, 31));

    expect(entries, hasLength(1));
    expect(entries.single.name, 'CDA Actual');
    expect(entries.single.sourceYear, 2026);
    expect(entries.single.sourceMonth, 7);
  });

  test('latest safe CDA is included', () {
    final entries = currentOfficialCdaEntries([
      _row(id: '1', name: 'CDA Vigente', year: 2026, month: 7),
    ], timestamp: DateTime.utc(2026, 8, 31));

    expect(entries.map((entry) => entry.name), ['CDA Vigente']);
  });

  test('latest non-certified CDA is excluded fail-closed', () {
    final entries = currentOfficialCdaEntries([
      _row(id: '1', name: 'CDA Vigente', year: 2026, month: 7),
      _row(
        id: '2',
        name: 'CDA No Certifica',
        year: 2026,
        month: 7,
        certified: 'NO',
      ),
    ], timestamp: DateTime.utc(2026, 8, 31));

    expect(entries.map((entry) => entry.name), ['CDA Vigente']);
  });

  test('latest unsafe novelty is excluded fail-closed', () {
    final entries = currentOfficialCdaEntries([
      _row(id: '1', name: 'CDA Vigente', year: 2026, month: 7),
      _row(
        id: '2',
        name: 'CDA Cancelado',
        year: 2026,
        month: 7,
        novelty: 'CANCELADO',
      ),
    ], timestamp: DateTime.utc(2026, 8, 31));

    expect(entries.map((entry) => entry.name), ['CDA Vigente']);
  });

  test('ambiguous latest-period rows are excluded', () {
    final entries = currentOfficialCdaEntries([
      _row(id: '1', name: 'CDA Vigente', year: 2026, month: 7),
      _row(id: '2', name: 'CDA Ambiguo A', year: 2026, month: 7),
      _row(id: '2', name: 'CDA Ambiguo B', year: 2026, month: 7),
    ], timestamp: DateTime.utc(2026, 8, 31));

    expect(entries.map((entry) => entry.name), ['CDA Vigente']);
  });

  test('source period rolls over to the latest non-future month', () {
    final rows = [
      _row(id: '1', name: 'CDA Junio', year: 2026, month: 6),
      _row(id: '2', name: 'CDA Julio', year: 2026, month: 7),
      _row(id: '3', name: 'CDA Futuro', year: 2026, month: 12),
    ];

    expect(
      latestNonFutureSourcePeriod(rows, DateTime.utc(2026, 8, 31)),
      const SourcePeriod(2026, 7),
    );
    expect(
      currentOfficialCdaEntries(
        rows,
        timestamp: DateTime.utc(2026, 8, 31),
      ).map((entry) => entry.name),
      ['CDA Julio'],
    );
  });

  test('catalog staleness warns after two months', () {
    final catalog = CdaCatalog(
      source: CdaCatalogSource(
        provider: 'Ministerio de Transporte / RUNT 2.0',
        datasetId: 'epfm-5fhb',
        datasetName: 'ACTORES RUNT POR MUNICIPIO Y DEPARTAMENTO RUNT2.0',
        sourceUrl: cdaCatalogSourceUrl,
        sourceVerifiedAt: DateTime.utc(2026, 8, 31),
        latestSourceYear: 2026,
        latestSourceMonth: 7,
        latestSourceMonthName: 'JULIO',
      ),
      metrics: _metrics(),
      entries: const [],
    );

    expect(isCdaCatalogStale(catalog, DateTime(2026, 9, 1)), isFalse);
    expect(isCdaCatalogStale(catalog, DateTime(2026, 10, 15)), isTrue);
  });

  test('search results do not expose fake distance rating or price fields', () {
    final entry = _entry(name: 'CDA Medellín Norte', municipality: 'MEDELLIN');
    final encoded = jsonEncode({
      'id': entry.id,
      'name': entry.name,
      'municipality': entry.municipality,
      'department': entry.department,
    });

    expect(encoded, isNot(contains('km')));
    expect(encoded, isNot(contains('rating')));
    expect(encoded, isNot(contains('price')));
  });

  test('search matches CDA name, municipality and department', () {
    final entries = [
      _entry(name: 'CDA Medellín Norte', municipality: 'MEDELLIN'),
      _entry(name: 'Revision Andina', municipality: 'CHIA'),
      _entry(name: 'Centro Caribe', department: 'BOLIVAR'),
    ];

    expect(searchCdaCatalog(entries, 'medellin norte'), hasLength(1));
    expect(searchCdaCatalog(entries, 'chia'), hasLength(1));
    expect(searchCdaCatalog(entries, 'bolivar'), hasLength(1));
  });
}

CdaSourceRow _row({
  required String id,
  required String name,
  String actorType = 'CDA',
  int year = 2026,
  int month = 7,
  String certified = 'SI',
  String novelty = 'NO',
}) {
  return CdaSourceRow(
    id: id,
    name: name,
    nit: '900$id',
    municipality: 'MEDELLIN',
    department: 'ANTIOQUIA',
    departmentCode: '05',
    actorType: actorType,
    sourceYear: year,
    sourceMonth: month,
    sourceMonthName: 'JULIO',
    certified: certified,
    novelty: novelty,
  );
}

CdaCatalogMetrics _metrics() {
  return const CdaCatalogMetrics(
    sourceRows: 10,
    cdaSourceRows: 10,
    latestSourcePeriod: '2026-07',
    globalLatestSourcePeriod: '2026-12',
    futureSourcePeriodsIgnored: true,
    latestPeriodCdaRows: 5,
    currentUniqueCdaCount: 1,
    staleHistoricalCdaExcludedCount: 1,
    certificoNotSiCount: 1,
    unsafeNoveltyCount: 1,
    ambiguousCurrentDuplicateCount: 1,
    uniqueCdaCount: 1,
    excludedCurrentStatusCount: 4,
    municipalityCount: 1,
    departmentCount: 1,
    sponsoredCdaCount: 0,
  );
}

CdaCatalogEntry _entry({
  String name = 'CDA Uno',
  String municipality = 'MEDELLIN',
  String department = 'ANTIOQUIA',
}) {
  return CdaCatalogEntry(
    id: name,
    name: name,
    nit: null,
    municipality: municipality,
    department: department,
    departmentCode: '05',
    sourceYear: 2025,
    sourceMonth: 7,
    sourceMonthName: 'JULIO',
    certified: true,
    novelty: 'NO',
    sourceVerifiedAt: DateTime.utc(2026),
    generatedAt: DateTime.utc(2026),
  );
}
