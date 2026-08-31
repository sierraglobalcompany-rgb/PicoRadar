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
    ], timestamp: DateTime.utc(2026));

    expect(entries.map((entry) => entry.name), ['CDA Uno']);
  });

  test('historical rows collapse to the current actor record', () {
    final entries = currentOfficialCdaEntries([
      _row(id: '1', name: 'CDA Viejo', year: 2024, month: 12),
      _row(id: '1', name: 'CDA Actual', year: 2025, month: 7),
    ], timestamp: DateTime.utc(2026));

    expect(entries, hasLength(1));
    expect(entries.single.name, 'CDA Actual');
    expect(entries.single.sourceYear, 2025);
    expect(entries.single.sourceMonth, 7);
  });

  test('cancelled or suspended novelty is excluded fail-closed', () {
    final entries = currentOfficialCdaEntries([
      _row(id: '1', name: 'CDA Vigente'),
      _row(id: '2', name: 'CDA Cancelado', novelty: 'CANCELADO'),
      _row(id: '3', name: 'CDA Suspendido', novelty: 'SUSPENDIDO'),
      _row(id: '4', name: 'CDA No Certifica', certified: 'NO'),
    ], timestamp: DateTime.utc(2026));

    expect(entries.map((entry) => entry.name), ['CDA Vigente']);
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
  int year = 2025,
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
