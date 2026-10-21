import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/comparendos/data/territorial_catalog.dart';

void main() {
  late Map<String, Object?> json;
  const procedureFields = [
    'supportsRegistrationProcedures',
    'transferUrl',
    'appointmentUrl',
    'formsUrl',
    'phone',
    'address',
    'procedureEvidenceUrl',
    'procedureReviewedAt',
  ];

  setUp(() {
    json = jsonDecode(
      File(territorialCatalogAssetPath).readAsStringSync(),
    ) as Map<String, Object?>;
  });

  Map<String, Object?> row(String id) => (json['authorities'] as List)
      .cast<Map<String, Object?>>()
      .singleWhere((entry) => entry['id'] == id);

  TerritorialCatalog parse() => TerritorialCatalog.fromJson(json);

  test('v1 legacy rows and constructors default to not confirmed', () {
    for (final entry in (json['authorities'] as List).cast<Map>()) {
      for (final field in procedureFields) {
        entry.remove(field);
      }
    }
    final catalog = parse();
    expect(catalog.authorities, hasLength(769));
    expect(
      catalog.authorities.every((a) => !a.supportsRegistrationProcedures),
      isTrue,
    );
    const legacy = TerritorialAuthority(
      id: 'legacy',
      name: 'Legacy fixture',
      platformName: 'Pending',
      municipalityCodes: [],
    );
    expect(legacy.supportsRegistrationProcedures, isFalse);
    expect(legacy.transferUrl, isNull);
    expect(legacy.procedureReviewedAt, isNull);
  });

  test('only two reviewed transfers; unknown inventory remains searchable', () {
    final catalog = parse();
    expect(catalog.search(''), hasLength(769));
    final confirmed = catalog.authorities
        .where((a) => a.supportsRegistrationProcedures)
        .toList();
    expect(confirmed.map((a) => a.id).toSet(), {'co-bogota', 'co-medellin'});
    expect(
      catalog.authorities.where((a) => !a.supportsRegistrationProcedures),
      hasLength(767),
    );
    final unknown = catalog.authorities.firstWhere(
      (a) => a.verificationStatus == 'pending',
    );
    expect(catalog.search(unknown.name), contains(unknown));
    expect(unknown.procedureEvidenceUrl, isNull);
    expect(unknown.phone, isNull);
    expect(unknown.address, isNull);
    expect(json['registrationFallbackUrl'], runtActorsDirectoryUrl);
    expect(
      runtActorsDirectoryUrl,
      'https://www.runt.gov.co/directorio-de-actores',
    );
  });

  test('reviewed contact and procedure links remain distinct from fines', () {
    final catalog = parse();
    final bogota = catalog.authorities.singleWhere((a) => a.id == 'co-bogota');
    final medellin = catalog.authorities.singleWhere(
      (a) => a.id == 'co-medellin',
    );
    expect(bogota.consultationUrl, isNull);
    expect(bogota.phone, '6012916999');
    expect(bogota.address, isNull);
    expect(bogota.appointmentUrl, 'https://vus.circulemosdigital.com.co/');
    expect(
      bogota.formsUrl,
      'https://www.ventanillamovilidad.com.co/formularios',
    );
    expect(medellin.phone, '6044457777');
    expect(medellin.address, contains('Sede Caribe'));
    expect(medellin.appointmentUrl, isNull);
    expect(medellin.formsUrl, isNull);
    for (final a in [bogota, medellin]) {
      expect(a.transferUrl, a.procedureEvidenceUrl);
      expect(a.procedureReviewedAt, '2026-09-15');
      expect(a.verifiedAt, '2026-09-13');
      expect(a.transferUrl, isNot(a.consultationUrl));
    }
  });

  for (final field in procedureFields.skip(1)) {
    test('unconfirmed row cannot supply $field without procedure proof', () {
      final pending = (json['authorities'] as List)
          .cast<Map<String, Object?>>()
          .firstWhere((a) => a['verificationStatus'] == 'pending');
      pending[field] = 'https://www.medellin.gov.co/';
      expect(parse, throwsFormatException);
    });
  }

  test('source inventory alone cannot confer registration capability', () {
    final pending = (json['authorities'] as List)
        .cast<Map<String, Object?>>()
        .firstWhere((a) => a['verificationStatus'] == 'pending');
    for (final field in procedureFields) {
      pending[field] = row('co-bogota')[field];
    }
    expect(parse, throwsFormatException);
  });

  for (final field in [
    'transferUrl',
    'procedureEvidenceUrl',
    'procedureReviewedAt',
  ]) {
    test('confirmed capability requires $field', () {
      row('co-bogota').remove(field);
      expect(parse, throwsFormatException);
    });
  }

  for (final field in procedureFields.skip(1)) {
    test('reviewed tuple rejects altered $field', () {
      row('co-bogota')[field] = switch (field) {
        'phone' => '6010000000',
        'address' => 'Unverified office',
        'procedureReviewedAt' => '2099-01-01',
        _ => 'https://www.ventanillamovilidad.com.co/unreviewed',
      };
      expect(parse, throwsFormatException);
    });
  }

  test('optional reviewed contacts may be omitted', () {
    row('co-bogota')
      ..remove('phone')
      ..remove('appointmentUrl')
      ..remove('formsUrl');
    expect(parse().authorities, hasLength(769));
  });

  for (final value in ['true', 1, [], {}]) {
    test('capability rejects non boolean $value', () {
      row('co-bogota')['supportsRegistrationProcedures'] = value;
      expect(parse, throwsFormatException);
    });
  }
}
