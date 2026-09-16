import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/vehicle_status/data/tax_catalog.dart';

void main() {
  late Map<String, dynamic> json;
  late TaxCatalog catalog;

  setUp(() {
    json = jsonDecode(
      File(bundledTaxCatalogAsset).readAsStringSync(),
    ) as Map<String, dynamic>;
    catalog = TaxCatalog.fromJson(json);
  });

  test('all 33 fichas record successful or unresolved dated link audit', () {
    expect(json['schemaVersion'], 1);
    expect(catalog.authorities, hasLength(33));
    final rows = (json['authorities'] as List).cast<Map<String, dynamic>>();
    final read = <String>[];
    final unresolved = <String>[];
    for (final row in rows) {
      final audit = row['directoryAudit'] as Map<String, dynamic>;
      final attemptedAt = DateTime.parse(audit['attemptedAt'] as String);
      expect(attemptedAt.isAfter(catalog.generatedAt), isFalse);
      expect(audit['note'], isNotEmpty);
      final checked = (audit['checkedUrls'] as List).cast<String>();
      expect(checked, containsAll(row['sourceUrls'] as List));
      expect(checked.every((url) => Uri.parse(url).scheme == 'https'), isTrue);
      switch (audit['institutionalStatus']) {
        case 'source_read':
          read.add(row['id'] as String);
        case 'unresolved':
          unresolved.add(row['id'] as String);
        default:
          fail('Unknown audit status');
      }
    }
    expect(read, hasLength(18));
    expect(unresolved, hasLength(15));
    expect(unresolved, containsAll(['amazonas', 'la-guajira', 'huila']));
    // A failed attempt must not manufacture a successful editorial review.
    expect(catalog.authorityById('amazonas')!.reviewedAt, isNull);
    expect(catalog.authorityById('la-guajira')!.reviewedAt, isNull);
  });

  test('new referral retains publisher provenance without payment claims', () {
    final quindio = catalog.authorityById('quindio')!;
    expect(quindio.portalUrl, 'https://isva.quindio.gov.co/portal-quindio/');
    expect(quindio.sourceUrls, contains('https://www.quindio.gov.co/'));
    expect(quindio.reviewedAt, isNotNull);
    expect(catalog.authorities.where((a) => a.portalUrl != null), hasLength(8));
    expect(
      catalog.authorityById('atlantico')!.institutionalUrl,
      'https://www.atlantico.gov.co/index.php/impuestos-departamentales',
    );
    // Official referral exists, but the target currently reports errors.
    expect(catalog.authorityById('atlantico')!.portalUrl, isNull);
    expect(catalog.authorityById('la-guajira')!.institutionalUrl, isNull);
    expect(catalog.authorityById('la-guajira')!.sourceUrls, isNotEmpty);
  });

  test('link audit does not turn partial calendars into national coverage', () {
    expect(
      catalog.calendars.where((c) => c.status == 'partial'),
      hasLength(14),
    );
    expect(
      catalog.calendars.where((c) => c.status == 'pending'),
      hasLength(19),
    );
    expect(catalog.calendars.where((c) => c.status == 'verified'), isEmpty);
    for (final calendar in catalog.calendars.where(
      (c) => c.status == 'pending',
    )) {
      expect(calendar.events, isEmpty);
    }
    expect(catalog.calendarFor('quindio', 2026)!.status, 'pending');
    expect(catalog.calendarFor('atlantico', 2026)!.status, 'pending');
  });
}
