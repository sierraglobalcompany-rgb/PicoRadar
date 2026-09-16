import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/cda/data/cda_catalog.dart';
import 'package:picoradar/features/cda/data/cda_geography.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CdaCatalog catalog;
  final now = DateTime.utc(2026, 9, 14);
  setUp(() async => catalog = await loadCdaCatalog(rootBundle));

  Map<String, Object?> site(CdaCatalogEntry entry) => {
    'cdaId': entry.id,
    'catalogName': entry.name,
    'municipality': entry.municipality,
    'departmentCode': entry.departmentCode,
    'status': 'verified',
    'latitude': 4.6,
    'longitude': -74.1,
    'address': 'FICTIONAL TEST ADDRESS',
    'locationSources': [
      {'url': 'https://example.org/fixture', 'reviewedAt': '2026-09-14'},
    ],
    'vehicleTypes': <String>[],
    'compatibilitySources': <Object?>[],
  };
  Map<String, Object?> pack(List<Object?> entries) => {
    'schemaVersion': 1,
    'version': 'fixture-1',
    'catalogPeriod': '2026-07',
    'approved': true,
    'entries': entries,
  };

  test(
    'shipping geography enables the approved operational set only',
    () async {
      final geo = await loadCdaGeography(rootBundle);
      final coverage = geo.coverage(catalog, now: now);
      expect(coverage.total, 964);
      expect(coverage.operationalTotal, 866);
      expect(coverage.missingInventoryCount, 98);
      expect(coverage.addressVerifiedCount, 866);
      expect(coverage.mapEligibleCount, 866);
      expect(coverage.verifiedCount, 866);
      expect(coverage.mapEnabled, isTrue);
      expect(coverage.pendingIds, hasLength(98));
    },
  );
  test(
    'an approved operational fixture can unlock even if catalog has more IDs',
    () {
      final geo = CdaGeography.fromJson(pack([site(catalog.entries.first)]));
      final coverage = geo.coverage(catalog, now: now);
      expect(coverage.addressVerifiedCount, 1);
      expect(coverage.verifiedCount, 1);
      expect(coverage.mapEnabled, isTrue);
      expect(coverage.pendingIds, hasLength(963));
    },
  );
  test('address-only evidence is useful but never unlocks map', () {
    final row = site(catalog.entries.first)
      ..['status'] = 'address_verified'
      ..remove('latitude')
      ..remove('longitude');
    final geo = CdaGeography.fromJson(pack([row]));
    final siteRow = geo.sites.single;
    final coverage = geo.coverage(catalog, now: now);
    expect(siteRow.addressVerifiedAt(now), isTrue);
    expect(siteRow.verifiedAt(now), isFalse);
    expect(siteRow.mapEligibleAt(now), isFalse);
    expect(coverage.addressVerifiedCount, 1);
    expect(coverage.verifiedCount, 0);
    expect(coverage.mapEnabled, isFalse);
  });
  test('only complete approved matching inventory unlocks', () {
    final json = pack(catalog.entries.map(site).toList());
    expect(
      CdaGeography.fromJson(json).coverage(catalog, now: now).mapEnabled,
      isTrue,
    );
    json['approved'] = false;
    expect(
      CdaGeography.fromJson(json).coverage(catalog, now: now).mapEnabled,
      isFalse,
    );
    json['approved'] = true;
    json['catalogPeriod'] = '2026-06';
    expect(
      CdaGeography.fromJson(json).coverage(catalog, now: now).mapEnabled,
      isFalse,
    );
  });
  test(
    'identity mismatch, missing evidence and future reviews fail closed',
    () {
      for (final change in <String, Object?>{
        'municipality': 'DIFFERENT SEDE',
        'departmentCode': '00',
        'catalogName': 'DIFFERENT NAME',
        'address': '',
        'locationSources': <Object?>[],
        'status': 'pending',
      }.entries) {
        final row = site(catalog.entries.first)..[change.key] = change.value;
        expect(
          CdaGeography.fromJson(pack([row]))
              .coverage(catalog, now: now)
              .mapEligibleCount,
          0,
          reason: change.key,
        );
      }
      final row = site(catalog.entries.first)
        ..['locationSources'] = [
          {'url': 'https://example.org/fixture', 'reviewedAt': '2027-01-01'},
        ];
      expect(
        CdaGeography.fromJson(pack([row]))
            .coverage(catalog, now: now)
            .mapEligibleCount,
        0,
      );
    },
  );
  test(
    'invalid coordinates, duplicate and unknown IDs reject or close gate',
    () {
      final row = site(catalog.entries.first)..['latitude'] = 90;
      expect(() => CdaGeography.fromJson(pack([row])), throwsFormatException);
      expect(
        () => CdaGeography.fromJson(
          pack([site(catalog.entries.first), site(catalog.entries.first)]),
        ),
        throwsFormatException,
      );
      final unknown = site(catalog.entries.first)
        ..['cdaId'] = 'not-in-inventory';
      final geo = CdaGeography.fromJson(
        pack([...catalog.entries.map(site), unknown]),
      );
      expect(geo.coverage(catalog, now: now).mapEnabled, isFalse);
    },
  );
  test('compatibility and contacts require their own valid evidence', () {
    final row = site(catalog.entries.first)..['vehicleTypes'] = ['car'];
    expect(
      CdaGeography.fromJson(pack([row])).sites.single.verifiedVehicleTypes(now),
      isEmpty,
    );
    row['compatibilitySources'] = [
      {'url': 'https://example.org/scope', 'reviewedAt': '2026-09-14'},
    ];
    expect(
      CdaGeography.fromJson(pack([row])).sites.single.verifiedVehicleTypes(now),
      {'car'},
    );
    row['web'] = 'javascript:alert(1)';
    expect(() => CdaGeography.fromJson(pack([row])), throwsFormatException);
  });
  test('unknown schema rejected without mutating original catalogue', () {
    expect(
      () => CdaGeography.fromJson(
        jsonDecode('{"schemaVersion":2}') as Map<String, Object?>,
      ),
      throwsFormatException,
    );
    expect(catalog.entries, hasLength(964));
  });
}
