import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/sync/dataset_sync_service.dart';
import 'package:picoradar/features/vehicle_status/data/tax_catalog.dart';

Map<String, dynamic> taxFixture() => {
  'schemaVersion': 1,
  'datasetKey': 'tax_calendars',
  'version': 'test-v1',
  'generatedAt': '2026-09-13T16:00:00Z',
  'authorities': [
    {
      'id': 'bogota',
      'territoryCode': '11',
      'territoryName': 'Bogota D.C.',
      'name': 'Secretaria Distrital de Hacienda',
      'institutionalUrl': 'https://www.haciendabogota.gov.co/',
      'portalUrl': null,
      'sourceUrls': ['https://www.haciendabogota.gov.co/'],
      'reviewedAt': null,
    },
  ],
  'calendars': [
    {
      'id': 'bogota-2026-vehicle-tax',
      'authorityId': 'bogota',
      'year': 2026,
      'obligationKind': 'vehicle_tax',
      'status': 'partial',
      'reviewedAt': '2026-09-13T16:00:00Z',
      'reviewAfter': null,
      'sourceUrls': ['https://www.haciendabogota.gov.co/calendario'],
      'events': [
        {
          'id': 'ordinary',
          'date': '2026-07-24',
          'label': 'Plazo ordinario',
          'kind': 'ordinary',
          'condition': null,
          'status': 'active',
          'supersededBy': null,
          'sourceUrls': ['https://www.haciendabogota.gov.co/calendario'],
        },
      ],
    },
  ],
};

void main() {
  late Map<String, dynamic> json;
  Map<String, dynamic> calendar() => (json['calendars'] as List).first;
  Map<String, dynamic> event() => (calendar()['events'] as List).first;
  Map<String, dynamic> authority() => (json['authorities'] as List).first;
  void rejects() => expect(
    () => TaxCatalog.fromJson(json),
    throwsA(isA<DatasetSyncException>()),
  );

  setUp(() => json = taxFixture());

  test('lookup is exact by authority, tax year and obligation', () {
    final catalog = TaxCatalog.fromJson(json);
    expect(catalog.authorityById('bogota')!.territoryCode, '11');
    expect(catalog.authorityById(null), isNull);
    expect(catalog.authorityById('unknown'), isNull);
    expect(catalog.calendarFor('bogota', 2027), isNull);
    expect(
      catalog.calendarFor('bogota', 2026)!.events.single.date,
      DateTime.utc(2026, 7, 24),
    );
    expect(() => catalog.authorities.clear(), throwsUnsupportedError);
    expect(
      () => catalog.calendars.single.events.clear(),
      throwsUnsupportedError,
    );
  });

  for (final date in [
    '2026-02-29',
    '2026-04-31',
    '2026-13-01',
    '2026-00-01',
    '2026-01-00',
    '2026-1-01',
    '2026-01-01T00:00:00Z',
    '0000-01-01',
    '2026-01-01 ',
  ]) {
    test('rejects invalid civil date $date', () {
      event()['date'] = date;
      rejects();
    });
  }

  test(
    'compatible future years and leap days need no schema or APK change',
    () {
      calendar()['year'] = 2028;
      event()['date'] = '2028-02-29';
      json['additiveMetadata'] = {'editor': 'review'};
      expect(TaxCatalog.fromJson(json).calendarFor('bogota', 2028), isNotNull);
    },
  );

  test('following civil year requires condition; other years rejected', () {
    event()['date'] = '2027-01-15';
    rejects();
    event()['condition'] = 'Cuota de la vigencia 2026 con plazo en enero 2027';
    expect(TaxCatalog.fromJson(json).calendars.single.events, hasLength(1));
    event()['date'] = '2028-01-15';
    rejects();
    event()['date'] = '2025-01-15';
    rejects();
  });

  for (final field in [
    'schemaVersion',
    'datasetKey',
    'version',
    'authorities',
    'calendars',
  ]) {
    test('requires envelope $field', () {
      json.remove(field);
      rejects();
    });
  }

  test('rejects unknown schema, enums and non-integer years', () {
    json['schemaVersion'] = 2;
    rejects();
    json = taxFixture();
    calendar()['year'] = 2026.0;
    rejects();
    json = taxFixture();
    calendar()['obligationKind'] = 'debt_relief';
    rejects();
    json = taxFixture();
    calendar()['status'] = 'assumed';
    rejects();
    json = taxFixture();
    event()['kind'] = 'ordinaryDeadline';
    rejects();
    json = taxFixture();
    event()['status'] = 'confirmed';
    rejects();
  });

  test(
    'rejects duplicate authority IDs, DANE, calendar IDs/keys and events',
    () {
      (json['authorities'] as List).add({...authority()});
      rejects();
      (json['authorities'] as List).last['id'] = 'other';
      rejects();
      json = taxFixture();
      (json['calendars'] as List).add({...calendar()});
      rejects();
      (json['calendars'] as List).last['id'] = 'other-calendar';
      rejects();
      json = taxFixture();
      (calendar()['events'] as List).add({...event()});
      rejects();
    },
  );

  test('validates authority reference and two-digit territory code', () {
    calendar()['authorityId'] = 'missing';
    rejects();
    json = taxFixture();
    authority()['territoryCode'] = '1';
    rejects();
  });

  for (final kind in ['installment', 'installmentEnrollment']) {
    test('$kind requires explicit text condition', () {
      event()['kind'] = kind;
      rejects();
      event()['condition'] = {'unsupported': 'formula'};
      rejects();
      event()['condition'] = 'Si se acogio al SPAC';
      expect(
        TaxCatalog.fromJson(json).calendars.single.activeEvents,
        hasLength(1),
      );
    });
  }

  test('review and sources required for calendars with dates', () {
    calendar()['reviewedAt'] = null;
    rejects();
    json = taxFixture();
    calendar()['sourceUrls'] = [];
    rejects();
    json = taxFixture();
    event()['sourceUrls'] = [];
    rejects();
    json = taxFixture();
    authority()['sourceUrls'] = [];
    rejects();
  });

  test('pending and withdrawn calendars cannot expose active dates', () {
    for (final status in ['pending', 'withdrawn']) {
      calendar()['status'] = status;
      rejects();
    }
    event()['status'] = 'withdrawn';
    expect(TaxCatalog.fromJson(json).calendars.single.activeEvents, isEmpty);
  });

  test('supersession preserves history and hides the replaced event', () {
    final replacement = {...event(), 'id': 'extended', 'date': '2026-07-31'};
    event()['status'] = 'superseded';
    event()['supersededBy'] = 'extended';
    (calendar()['events'] as List).add(replacement);
    final parsed = TaxCatalog.fromJson(json).calendars.single;
    expect(parsed.events, hasLength(2));
    expect(parsed.activeEvents.single.id, 'extended');
    replacement['status'] = 'superseded';
    replacement['supersededBy'] = 'ordinary';
    rejects();
  });

  test('rejects missing, self and non-superseded supersession references', () {
    event()['supersededBy'] = 'missing';
    rejects();
    event()['status'] = 'superseded';
    rejects();
    event()['supersededBy'] = 'ordinary';
    rejects();
    event()['supersededBy'] = null;
    rejects();
  });

  for (final instant in [
    '2026-02-30T12:00:00Z',
    '2026-09-13',
    '2026-09-13T12:00:00',
    '2026-09-13T24:00:00Z',
    '2026-09-13T12:00:00+25:00',
  ]) {
    test('rejects invalid or timezone-free instant $instant', () {
      json['generatedAt'] = instant;
      rejects();
    });
  }

  test(
    'parses actual offset instants and rejects malformed nullable values',
    () {
      json['generatedAt'] = '2026-09-13T11:00:00-05:00';
      expect(
        TaxCatalog.fromJson(json).generatedAt,
        DateTime.utc(2026, 9, 13, 16),
      );
      authority()['reviewedAt'] = 0;
      rejects();
      json = taxFixture();
      calendar()['reviewAfter'] = 'bad';
      rejects();
    },
  );

  for (final url in [
    'http://example.gov.co/',
    'https://localhost/',
    'https://private.local/',
    'https://127.0.0.1/',
    'https://[::1]/',
    'https://2130706433/',
    'https://127.1/',
    'https://user:pass@example.gov.co/',
    'https://example.gov.co/?placa=ABC123',
    'https://example.gov.co/?cedula=123',
    'https://example.gov.co/?email=x%40mail.com',
    'https://example.gov.co/?token=secret',
    'https://example.gov.co/?redirect=https%3A%2F%2Flocalhost',
    'https://example.gov.co/#placa=ABC123',
  ]) {
    test('rejects unsafe URLs on every surface: $url', () {
      for (final target in [
        'authoritySource',
        'portal',
        'institution',
        'calendar',
        'event',
      ]) {
        json = taxFixture();
        switch (target) {
          case 'authoritySource':
            authority()['sourceUrls'] = [url];
          case 'portal':
            authority()['portalUrl'] = url;
          case 'institution':
            authority()['institutionalUrl'] = url;
          case 'calendar':
            calendar()['sourceUrls'] = [url];
          case 'event':
            event()['sourceUrls'] = [url];
        }
        rejects();
      }
    });
  }

  test('permits editorial document query parameters and additive fields', () {
    event()['sourceUrls'] = [
      'https://www.cundinamarca.gov.co/wcm/connect/act.pdf?CACHEID=ROOTWORKSPACE-a&CONVERT_TO=url&MOD=AJPERES',
    ];
    event()['editorialNote'] = 'Resolucion, articulo primero';
    expect(TaxCatalog.fromJson(json).calendars, hasLength(1));
    event()['sourceUrls'] = [
      'https://example.gov.co/calendario?year=2028&page=2&lang=es',
    ];
    expect(TaxCatalog.fromJson(json).calendars, hasLength(1));
  });

  test('rejects malformed JSON and non-object records', () {
    expect(
      () => TaxCatalog.fromJsonString('{'),
      throwsA(isA<DatasetSyncException>()),
    );
    expect(
      () => TaxCatalog.fromJsonString('[]'),
      throwsA(isA<DatasetSyncException>()),
    );
    json['authorities'] = [42];
    rejects();
  });

  test(
    'bundled inventory has 33 units with truthful coverage and prorroga',
    () {
      final catalog = TaxCatalog.fromJsonString(
        File(bundledTaxCatalogAsset).readAsStringSync(),
      );
      expect(catalog.authorities, hasLength(33));
      expect(
        catalog.authorities.map((a) => a.territoryCode).toSet(),
        hasLength(33),
      );
      expect(catalog.calendarFor('bogota', 2026)!.activeEvents, hasLength(5));
      expect(
        catalog.calendarFor('antioquia', 2026)!.activeEvents,
        hasLength(2),
      );
      final cund = catalog.calendarFor('cundinamarca', 2026)!;
      expect(
        cund.activeEvents.any((e) => e.date == DateTime.utc(2026, 6, 19)),
        isTrue,
      );
      expect(
        cund.activeEvents.any((e) => e.date == DateTime.utc(2026, 5, 31)),
        isFalse,
      );
      expect(cund.events.any((e) => e.status == 'superseded'), isTrue);
      for (final id in ['meta', 'quindio', 'magdalena', 'la-guajira']) {
        expect(catalog.calendarFor(id, 2026)!.status, 'pending');
        expect(catalog.calendarFor(id, 2026)!.activeEvents, isEmpty);
      }
      expect(catalog.authorityById('narino')!.portalUrl, isNull);
      expect(catalog.authorityById('amazonas')!.reviewedAt, isNull);
      expect(catalog.calendarFor('bogota', 2027), isNull);
      expect(
        jsonDecode(
          File(bundledTaxCatalogAsset).readAsStringSync(),
        )['schemaVersion'],
        1,
      );
    },
  );

  test('audited seed expands primary-source dates with partial coverage', () {
    final catalog = TaxCatalog.fromJsonString(
      File(bundledTaxCatalogAsset).readAsStringSync(),
    );
    const expected = {
      'bogota': [
        '2026-05-15',
        '2026-06-12',
        '2026-07-03',
        '2026-07-24',
        '2026-09-04',
      ],
      'antioquia': ['2026-04-30', '2026-07-31'],
      'cundinamarca': ['2026-06-19', '2026-07-31', '2026-07-31'],
      'boyaca': ['2026-02-28', '2026-02-28', '2026-03-31'],
      'caldas': ['2026-07-06'],
      'casanare': ['2026-03-15', '2026-05-31', '2026-07-31', '2026-11-30'],
      'cauca': ['2026-06-30'],
      'cesar': ['2026-04-30', '2026-06-30'],
      'cordoba': ['2026-03-31', '2026-05-29', '2026-06-30'],
      'huila': ['2026-05-31', '2026-05-31', '2026-07-31'],
      'narino': ['2026-04-30', '2026-12-30'],
      'putumayo': ['2026-06-30'],
      'santander': ['2026-06-30'],
      'tolima': ['2026-06-30'],
    };
    expect(
      catalog.calendars.where((c) => c.status == 'partial'),
      hasLength(14),
    );
    expect(
      catalog.calendars.where((c) => c.status == 'pending'),
      hasLength(19),
    );
    expect(catalog.calendars.where((c) => c.status == 'verified'), isEmpty);
    for (final entry in expected.entries) {
      final calendar = catalog.calendarFor(entry.key, 2026)!;
      expect(calendar.status, 'partial', reason: entry.key);
      expect(calendar.reviewedAt, isNotNull);
      expect(calendar.sourceUrls, isNotEmpty);
      expect(
        calendar.activeEvents.map(
          (e) => e.date.toIso8601String().substring(0, 10),
        ),
        entry.value,
        reason: entry.key,
      );
      for (final event in calendar.events) {
        expect(event.sourceUrls, isNotEmpty);
        expect(event.sourceUrls.every(calendar.sourceUrls.contains), isTrue);
      }
    }
    final boyaca = catalog.calendarFor('boyaca', 2026)!;
    expect(
      boyaca.events.where((e) => e.status == 'superseded').single.date,
      DateTime.utc(2026, 1, 31),
    );
    expect(boyaca.activeEvents.every((e) => e.condition != null), isTrue);
    final putumayo = catalog.calendarFor('putumayo', 2026)!;
    expect(putumayo.activeEvents.single.kind, 'discount');
    expect(
      putumayo.activeEvents.single.condition,
      contains('antes del 30 de junio'),
    );
    expect(putumayo.activeEvents.where((e) => e.kind == 'ordinary'), isEmpty);
    expect(
      catalog
          .calendarFor('cordoba', 2026)!
          .activeEvents
          .every((e) => e.kind == 'discount'),
      isTrue,
    );
    final loyalty = catalog
        .calendarFor('huila', 2026)!
        .activeEvents
        .firstWhere((e) => e.id == 'discount-loyalty');
    expect(loyalty.condition, contains('vigencia anterior'));
  });

  test('seed portals retain independent referral and explicit exclusions', () {
    final catalog = TaxCatalog.fromJsonString(
      File(bundledTaxCatalogAsset).readAsStringSync(),
    );
    const portalIds = {
      'bogota',
      'antioquia',
      'cundinamarca',
      'arauca',
      'caldas',
      'cauca',
      'boyaca',
      'quindio',
    };
    expect(
      catalog.authorities
          .where((a) => a.portalUrl != null)
          .map((a) => a.id)
          .toSet(),
      portalIds,
    );
    for (final id in portalIds) {
      final authority = catalog.authorityById(id)!;
      expect(authority.reviewedAt, isNotNull);
      expect(
        authority.sourceUrls.any(
          (url) => url != authority.portalUrl && Uri.parse(url).path.length > 1,
        ),
        isTrue,
        reason: id,
      );
    }
    for (final id in [
      'bolivar',
      'narino',
      'casanare',
      'cesar',
      'putumayo',
      'tolima',
    ]) {
      expect(catalog.authorityById(id)!.portalUrl, isNull, reason: id);
    }
    expect(catalog.calendarFor('arauca', 2026)!.status, 'pending');
    expect(
      catalog.authorityById('cauca')!.sourceUrls,
      contains(
        'https://www.cauca.gov.co/rentas/SaladePrensa/Paginas/Liquidaci%C3%B3n-y-pago-del-impuesto-vehicular-en-linea.aspx',
      ),
    );
  });
}
