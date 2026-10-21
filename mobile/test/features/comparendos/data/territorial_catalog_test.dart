import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/comparendos/data/territorial_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, Object?> json;
  late TerritorialCatalog catalog;

  setUp(() {
    json = jsonDecode(
      File(territorialCatalogAssetPath).readAsStringSync(),
    ) as Map<String, Object?>;
    catalog = TerritorialCatalog.fromJson(json);
  });

  Map<String, Object?> authority(String id) => (json['authorities'] as List)
      .cast<Map<String, Object?>>()
      .singleWhere((row) => row['id'] == id);

  test('all historical source rows are reconciled exactly once', () {
    expect(catalog.authorities, hasLength(769));
    final sourceRecords = (json['sourceRecords'] as List)
        .cast<Map<String, Object?>>();
    expect(sourceRecords, hasLength(1003));
    final sources = (json['sources'] as List).cast<Map<String, Object?>>();
    expect(
      {for (final row in sources) row['id']: row['observedRowCount']},
      {'fcm_organismos': 398, 'fcm_autoridades': 308, 'runt': 297},
    );
    final ids = catalog.authorities.expand((a) => a.sourceRecordIds).toList();
    expect(ids, hasLength(1003));
    expect(ids.toSet(), hasLength(1003));
    expect(ids.toSet(), sourceRecords.map((r) => r['id']).toSet());
    expect(
      sourceRecords.where((r) => r['sourceId'] == 'runt').map((r) => r['row']),
      orderedEquals(List.generate(297, (i) => i + 1)),
    );
    expect(
      catalog.authorities.map((a) => a.id).toSet(),
      hasLength(catalog.authorities.length),
    );
  });

  test('reports verification separately from national inventory intake', () {
    final summary = json['summary'] as Map;
    expect(summary['individuallyReviewedEntries'], 7);
    expect(summary['notIndividuallyReviewedEntries'], 762);
    expect(summary['supplementaryMunicipalityLeads'], 3);
    expect(summary['directConsultationEntries'], 2);
    expect(summary['institutionOnlyEntries'], 5);
    final verified = catalog.authorities.where(
      (a) => a.verificationStatus == 'verified',
    );
    expect(verified, hasLength(7));
    expect(
      catalog.authorities.where((a) => a.consultationUrl == null),
      hasLength(767),
    );
    for (final entry in catalog.authorities) {
      if (entry.verificationStatus == 'pending') {
        expect(entry.institutionalUrl, isNull);
        expect(entry.evidenceUrl, isNull);
        expect(entry.verifiedAt, isNull);
        expect(entry.municipalityCodes, isEmpty);
      } else {
        expect(entry.verifiedAt, '2026-09-13');
        if (entry.consultationUrl != null) {
          expect(isSafeOfficialPortalUrl(entry.consultationUrl!), isTrue);
        }
        expect(isSafeOfficialPortalUrl(entry.institutionalUrl!), isTrue);
        expect(isSafeOfficialPortalUrl(entry.evidenceUrl!), isTrue);
      }
    }
  });

  test('institution-only entries never masquerade as direct consultations', () {
    for (final id in [
      'co-bogota',
      'co-barranquilla',
      'co-bucaramanga',
      'co-itagui',
      'co-pereira',
    ]) {
      final entry = catalog.authorities.singleWhere((a) => a.id == id);
      expect(entry.consultationUrl, isNull);
      expect(entry.institutionalUrl, isNotNull);
      expect(entry.platformName, startsWith('Portal institucional'));
    }
  });

  test('institution-only landing cannot be promoted by asset flag alone', () {
    final entry = authority('co-bogota');
    entry['consultationUrl'] = entry['institutionalUrl'];
    expect(() => TerritorialCatalog.fromJson(json), throwsFormatException);
  });

  test(
    'references the existing 1104 municipalities without duplicating them',
    () {
      final national = jsonDecode(
        File('assets/catalogs/colombia_trip_municipalities_v1.json')
            .readAsStringSync(),
      ) as Map<String, Object?>;
      final codes = (national['records'] as List)
          .cast<Map<String, Object?>>()
          .map((r) => r['code'])
          .toSet();
      expect(codes, hasLength(1104));
      for (final entry in catalog.authorities) {
        expect(codes.containsAll(entry.municipalityCodes), isTrue);
        if (entry.officeMunicipalityCode != null) {
          expect(codes, contains(entry.officeMunicipalityCode));
        }
      }
    },
  );

  test(
    'Medellin uses exact referred portal and separate institutional evidence',
    () {
      final medellin = catalog.forMunicipality('05001');
      expect(medellin.map((a) => a.id), ['co-medellin']);
      expect(medellin.single.platformName, 'Movilidad en Línea');
      expect(
        medellin.single.consultationUrl,
        'https://www.medellin.gov.co/portal-movilidad/#/public',
      );
      expect(
        medellin.single.institutionalUrl,
        'https://www.medellin.gov.co/es/pag-movilidad/',
      );
      expect(medellin.single.evidenceUrl, medellin.single.institutionalUrl);
      expect(
        medellin.single.consultationUrl,
        isNot(medellin.single.institutionalUrl),
      );
      expect(catalog.forMunicipality('05360').single.id, 'co-itagui');
      for (final code in [
        '05088',
        '05266',
        '05631',
        '05002',
        '99999',
        '5001',
        '',
      ]) {
        expect(catalog.forMunicipality(code), isEmpty, reason: code);
      }
    },
  );

  test(
    'departmental office in Medellin or Bogota does not create coverage',
    () {
      final departmentOffice = catalog.authorities.singleWhere(
        (a) => a.sourceRecordIds.contains('fcm_organismos-p1-r2'),
      );
      expect(departmentOffice.officeMunicipalityCode, '05001');
      expect(departmentOffice.municipalityCodes, isEmpty);
      final cundinamarca = catalog.authorities.singleWhere(
        (a) => a.sourceRecordIds.contains('fcm_organismos-p2-r128'),
      );
      expect(cundinamarca.municipalityCodes, isEmpty);
      expect(catalog.forMunicipality('11001').map((a) => a.id), ['co-bogota']);
    },
  );

  test(
    'district duplicate rows reconcile without absorbing metro operator',
    () {
      final barranquilla = catalog.forMunicipality('08001').single;
      expect(
        barranquilla.sourceRecordIds,
        containsAll(['fcm_organismos-p3-r109', 'fcm_organismos-p3-r110']),
      );
      final operator = catalog.authorities.singleWhere(
        (a) => a.sourceRecordIds.contains('runt-029'),
      );
      expect(operator.id, isNot(barranquilla.id));
      expect(operator.entryKind, 'operator_or_company');
      expect(operator.municipalityCodes, isEmpty);
    },
  );

  test('SIMIT stays a separate national entry with FCM evidence', () {
    expect(simitConsultationUrl, 'https://www.fcm.org.co/simit/');
    expect(isSafeOfficialPortalUrl(simitConsultationUrl), isTrue);
    expect((json['simit'] as Map)['url'], simitConsultationUrl);
    expect(
      (json['simit'] as Map)['evidenceUrl'],
      'https://www.fcm.org.co/preguntas-frecuentes-simit/',
    );
    expect(catalog.authorities.any((a) => a.id == 'simit'), isFalse);
  });

  test(
    'official referral permits the exact Manizales non-government domain',
    () {
      final entry = catalog.forMunicipality('17001').single;
      expect(
        entry.consultationUrl,
        'https://www.movilidadmanizales.com.co/portal-servicios/#/public',
      );
      expect(
        Uri.parse(entry.evidenceUrl!).host,
        'centrodeinformacion.manizales.gov.co',
      );
    },
  );

  test('normalization handles Spanish accents and combining marks', () {
    expect(
      normalizeTerritorialText('  MEDELLÍN · Antioquia  '),
      'medellin antioquia',
    );
    expect(normalizeTerritorialText('Itagu\u0308i\u0301'), 'itagui');
    expect(
      normalizeTerritorialText('NARIÑO / Bogotá D.C.'),
      'narino bogota d c',
    );
  });

  test('search exposes pending authorities without inventing coverage', () {
    final candidates = catalog.search('AGENCIA SEGURIDAD VIAL ANTIOQUIA');
    final office = candidates.singleWhere(
      (a) => a.sourceRecordIds.contains('fcm_organismos-p1-r2'),
    );
    expect(office.officeMunicipalityCode, '05001');
    expect(office.municipalityCodes, isEmpty);
    expect(office.consultationUrl, isNull);
    expect(office.verificationStatus, 'pending');
    expect(catalog.forMunicipality('05001'), isNot(contains(office)));
  });

  test('search finds source aliases and accents independently of coverage', () {
    expect(
      catalog.search('transporte tránsito Medellín').map((a) => a.id),
      contains('co-medellin'),
    );
    expect(catalog.search('Envigado'), isNotEmpty);
    expect(
      catalog.search('Envigado').every((a) => a.municipalityCodes.isEmpty),
      isTrue,
    );
    expect(catalog.search('impossible directory query'), isEmpty);
  });

  test('search supports full directory browsing and explicit limits', () {
    expect(catalog.search(''), hasLength(769));
    expect(catalog.search('  '), hasLength(769));
    expect(catalog.search('', limit: 5), hasLength(5));
    expect(catalog.search('', limit: 0), isEmpty);
    expect(() => catalog.search('', limit: -1), throwsRangeError);
    expect(() => catalog.search('').clear(), throwsUnsupportedError);
  });

  for (final url in [
    'http://www.fcm.org.co/simit/',
    'javascript:alert(1)',
    '//www.fcm.org.co',
    'https://',
    'https://user:pass@www.fcm.org.co',
    'https://@www.fcm.org.co',
    'https://localhost/',
    'https://127.0.0.1/',
    'https://10.0.0.1/',
    'https://[::1]/',
    'https://192.168.1.1/',
    'https://portal.local/',
    'https://portal.internal/',
    'https://portal/',
    ' https://www.fcm.org.co/',
    'https://www.fcm.org.co/\n',
    'https://foo..gov.co/',
    'https://-foo.gov.co/',
    'https://www.fcm.org.co\\@evil.com/',
    'https://%6cocalhost/',
  ]) {
    test('rejects unsafe portal syntax $url', () {
      expect(isSafeOfficialPortalUrl(url), isFalse);
    });
  }

  test('syntax check alone never establishes official provenance', () {
    expect(isSafeOfficialPortalUrl('https://example.com/'), isTrue);
    expect(isSafeOfficialPortalUrl('https://fcm.org.co.evil.com/'), isTrue);
    authority('co-medellin')['consultationUrl'] =
        'https://fcm.org.co.evil.com/';
    expect(() => TerritorialCatalog.fromJson(json), throwsFormatException);
  });

  test(
    'Medellin generic institutional page cannot replace direct consultation',
    () {
      authority('co-medellin')['consultationUrl'] =
          'https://www.medellin.gov.co/es/pag-movilidad/';
      expect(() => TerritorialCatalog.fromJson(json), throwsFormatException);
    },
  );

  for (final change in <String, Object?>{
    'consultationUrl': 'https://www.medellin.gov.co/unreviewed',
    'institutionalUrl': 'https://www.bogota.gov.co/',
    'evidenceUrl': 'https://www.fcm.org.co/simit/',
    'verifiedAt': '2026-09-31',
    'municipalityCodes': ['05001', '05088'],
    'name': 'Autoridad departamental ubicada en Medellín',
    'verificationStatus': 'self_declared',
    'coverageStatus': 'office_location',
  }.entries) {
    test('rejects mismatched reviewed ${change.key}', () {
      authority('co-medellin')[change.key] = change.value;
      expect(() => TerritorialCatalog.fromJson(json), throwsFormatException);
    });
  }

  test(
    'pending authority cannot smuggle an official-looking clickable URL',
    () {
      final pending = (json['authorities'] as List)
          .cast<Map<String, Object?>>()
          .firstWhere((a) => a['verificationStatus'] == 'pending');
      pending['institutionalUrl'] = 'https://www.medellin.gov.co/';
      expect(() => TerritorialCatalog.fromJson(json), throwsFormatException);
    },
  );

  test('pending office cannot assert municipality coverage', () {
    final pending = (json['authorities'] as List)
        .cast<Map<String, Object?>>()
        .firstWhere((a) => a['verificationStatus'] == 'pending');
    pending['municipalityCodes'] = ['05001'];
    expect(() => TerritorialCatalog.fromJson(json), throwsFormatException);
  });

  for (final field in ['sources', 'sourceRecords', 'authorities']) {
    test('rejects missing $field', () {
      json.remove(field);
      expect(() => TerritorialCatalog.fromJson(json), throwsFormatException);
    });
  }

  test('rejects unsupported schema and duplicate authority', () {
    json['schemaVersion'] = 2;
    expect(() => TerritorialCatalog.fromJson(json), throwsFormatException);
    json['schemaVersion'] = 1;
    (json['authorities'] as List).add(authority('co-medellin'));
    expect(() => TerritorialCatalog.fromJson(json), throwsFormatException);
  });

  test('rejects unknown directory source even when URL is HTTPS', () {
    ((json['sources'] as List).first as Map)['url'] = 'https://example.com/';
    expect(() => TerritorialCatalog.fromJson(json), throwsFormatException);
  });

  test('rejects orphaned source rows', () {
    (json['authorities'] as List).removeAt(0);
    expect(() => TerritorialCatalog.fromJson(json), throwsFormatException);
  });

  test('rejects duplicate, missing and reassigned source references', () {
    final entry = authority('co-medellin');
    entry['sourceRecordIds'] = ['not-a-source-row'];
    expect(() => TerritorialCatalog.fromJson(json), throwsFormatException);
    entry['sourceRecordIds'] = ['runt-036'];
    expect(() => TerritorialCatalog.fromJson(json), throwsFormatException);
    entry['sourceRecordIds'] = ['runt-157', 'runt-157'];
    expect(() => TerritorialCatalog.fromJson(json), throwsFormatException);
  });

  test('rejects incomplete numbered directory intake', () {
    (json['sourceRecords'] as List).removeLast();
    expect(() => TerritorialCatalog.fromJson(json), throwsFormatException);
  });

  test('parsed authority lists cannot be mutated after validation', () {
    expect(() => catalog.authorities.clear(), throwsUnsupportedError);
    expect(
      () => catalog.forMunicipality('05001').clear(),
      throwsUnsupportedError,
    );
    expect(
      () => catalog
          .forMunicipality('05001')
          .single
          .municipalityCodes
          .add('05088'),
      throwsUnsupportedError,
    );
  });

  test(
    'provider loads bundled catalog without any runtime web request',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final loaded = await container.read(territorialCatalogProvider.future);
      expect(loaded.authorities, hasLength(769));
      expect(loaded.forMunicipality('05001').single.id, 'co-medellin');
    },
  );
}
