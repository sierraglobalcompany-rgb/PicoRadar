import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/core/sync/dataset_sync_service.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/data/restriction_dataset.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test(
    'imports strict schema2, typed conditions, and partial completeness',
    () async {
      await importRestrictionsDataset(db, _schema2());
      final rows = await db.select(db.restrictionCoverages).get();

      expect(rows, hasLength(1));
      expect(rows.single.vehicleKind, 'truck');
      expect(rows.single.serviceType, 'public_cargo');
      expect(rows.single.coverageCompleteness, 'partial');
      expect(rows.single.rulesJson, contains('inside_scope_ref'));
      expect(
        restrictionRulesFromJson(
          rows.single.rulesJson,
          jurisdictionId: rows.single.jurisdictionId,
          vehicleKind: VehicleKind.truck,
          serviceType: VehicleServiceType.publicCargo,
          schemaVersion: 2,
        ).single.conditions,
        hasLength(2),
      );
    },
  );

  test(
    'schema2 parses only explicit full-day windows and preserves legacy',
    () {
      final rule =
          _schema2()['jurisdictions'][0]['coverages'][0]['rules'][0]
              as Map<String, dynamic>;
      final parsedLegacy = restrictionRulesFromJson(
        jsonEncode([rule]),
        jurisdictionId: 'co-g2-synthetic',
        vehicleKind: VehicleKind.truck,
        serviceType: VehicleServiceType.publicCargo,
        schemaVersion: 2,
      ).single;
      expect(parsedLegacy.timeWindows.single.fullDay, isFalse);

      rule['timeWindows'] = [
        {'startMinute': 360, 'endMinute': 360, 'fullDay': true},
      ];
      final parsedFullDay = restrictionRulesFromJson(
        jsonEncode([rule]),
        jurisdictionId: 'co-g2-synthetic',
        vehicleKind: VehicleKind.truck,
        serviceType: VehicleServiceType.publicCargo,
        schemaVersion: 2,
      ).single;
      expect(parsedFullDay.timeWindows.single.fullDay, isTrue);
      expect(parsedFullDay.timeWindows.single.startMinute, 360);
      expect(parsedFullDay.timeWindows.single.endMinute, 360);
    },
  );

  test('schema1 and malformed schema2 full-day windows are rejected', () {
    final baseRule =
        _schema2()['jurisdictions'][0]['coverages'][0]['rules'][0]
            as Map<String, dynamic>;
    baseRule.remove('conditions');
    baseRule['timeWindows'] = [
      {'startMinute': 360, 'endMinute': 360, 'fullDay': true},
    ];
    expect(
      () => restrictionRulesFromJson(
        jsonEncode([baseRule]),
        jurisdictionId: 'co-g2-synthetic',
        vehicleKind: VehicleKind.truck,
        serviceType: VehicleServiceType.publicCargo,
        schemaVersion: 1,
      ),
      throwsA(isA<DatasetSyncException>()),
    );

    for (final window in const [
      {'startMinute': 360, 'endMinute': 360},
      {'startMinute': 360, 'endMinute': 360, 'fullDay': false},
      {'startMinute': 360, 'endMinute': 360, 'fullDay': null},
      {'startMinute': 360, 'endMinute': 360, 'fullDay': 'true'},
      {'startMinute': 360, 'endMinute': 360, 'fullDay': 1},
      {'startMinute': 360, 'endMinute': 420, 'fullDay': true},
      {'startMinute': 1440, 'endMinute': 1440, 'fullDay': true},
    ]) {
      final invalidRule = Map<String, dynamic>.from(baseRule)
        ..['timeWindows'] = [window];
      expect(
        () => restrictionRulesFromJson(
          jsonEncode([invalidRule]),
          jurisdictionId: 'co-g2-synthetic',
          vehicleKind: VehicleKind.truck,
          serviceType: VehicleServiceType.publicCargo,
          schemaVersion: 2,
        ),
        throwsA(isA<DatasetSyncException>()),
        reason: '$window',
      );
    }
  });

  test(
    'imports one combined Cali and Pereira LAB envelope through schema2',
    () async {
      final caliBytes = await File(
        '../server/database/data/restrictions/lab/2026-11-cali-official-calendar-partial.json',
      ).readAsBytes();
      final pereiraBytes = await File(
        '../server/database/data/restrictions/lab/2026-11-pereira-official-calendar-partial.json',
      ).readAsBytes();
      final cali = jsonDecode(utf8.decode(caliBytes)) as Map<String, dynamic>;
      final pereira =
          jsonDecode(utf8.decode(pereiraBytes)) as Map<String, dynamic>;
      final combinedFromSources = <String, dynamic>{
        'schemaVersion': 2,
        'datasetKey': 'restrictions',
        'version': 'LAB-V5-CALENDAR-COMBINED-20261112-01',
        'generatedAt': '2026-11-12T15:00:00Z',
        'jurisdictions': [
          ...(cali['jurisdictions'] as List),
          ...(pereira['jurisdictions'] as List),
        ],
      };
      final releaseBytes = await File(
        'test/fixtures/restrictions_lab_v5_combined_2026-11-12.json',
      ).readAsBytes();
      final release =
          jsonDecode(utf8.decode(releaseBytes)) as Map<String, dynamic>;
      expect(release, combinedFromSources);
      expect(DateTime.parse(release['generatedAt'] as String).isUtc, isTrue);
      expect(
        await _sha256(caliBytes),
        '84d5ae34ba45bb1258b259f504fe580d69b0ac2ada6a26eb53a31f7726893b99',
      );
      expect(
        await _sha256(pereiraBytes),
        '4719aedccf73c758647addd59380d040111172c841a5be2ec85848812312ba12',
      );
      final caliSha = await _sha256(caliBytes);
      final pereiraSha = await _sha256(pereiraBytes);
      final releaseSha = await _sha256(releaseBytes);
      expect(releaseSha, isNot(caliSha));
      expect(releaseSha, isNot(pereiraSha));

      await importRestrictionsDataset(
        db,
        release,
        now: () => DateTime.utc(2026, 11, 12, 16),
      );

      final coverages = await db.select(db.restrictionCoverages).get();
      expect(coverages, hasLength(3));
      expect(
        coverages
            .map(
              (row) =>
                  '${row.jurisdictionId}:${row.vehicleKind}:${row.serviceType}',
            )
            .toSet(),
        {
          'co-vac-cali:car:private',
          'co-ris-pereira:car:private',
          'co-ris-pereira:motorcycle:private',
        },
      );
      expect(
        coverages.map((row) => row.coverageCompleteness),
        everyElement('partial'),
      );
      final rules = [
        for (final coverage in coverages)
          ...(jsonDecode(coverage.rulesJson) as List)
              .cast<Map<String, dynamic>>(),
      ];
      expect(rules, hasLength(15));
      expect(rules.map((rule) => rule['id']).toSet(), hasLength(15));
      final availability = await db
          .select(db.restrictionJurisdictionAvailability)
          .get();
      expect(availability, hasLength(2));
      expect(availability.map((row) => row.jurisdictionId).toSet(), {
        'co-vac-cali',
        'co-ris-pereira',
      });
      expect(
        availability.map((row) => row.consultationEnabled),
        everyElement(true),
      );
      final codesByJurisdiction = {
        for (final row in availability)
          row.jurisdictionId:
              jsonDecode(row.municipalityCodesJson) as List<dynamic>,
      };
      expect(codesByJurisdiction['co-vac-cali'], ['76001']);
      expect(codesByJurisdiction['co-ris-pereira'], ['66001']);
      stdout.writeln(
        'TEST_EVIDENCE V5_COMBINED_IMPORT '
        'cali_sha=$caliSha pereira_sha=$pereiraSha '
        'release_sha=$releaseSha jurisdictions=2 coverages=3 rules=15',
      );
    },
  );

  test('schema2 mixed envelope preserves seven R2 legacy cities beside one V2 city', () async {
    final releasePath = Platform.environment['PICORADAR_G2_R2_RELEASE'];
    expect(releasePath, isNotNull);
    final r2 = jsonDecode(
      await File(releasePath!).readAsString(),
    ) as Map<String, dynamic>;
    final legacyCities = List<dynamic>.from(r2['jurisdictions'] as List);
    expect(legacyCities, hasLength(7));
    final syntheticCities = _schema2()['jurisdictions'] as List;

    final mixed = Map<String, dynamic>.from(r2)
      ..['schemaVersion'] = 2
      ..['version'] = 'G2_V3_SYNTHETIC_MIXED_TEST'
      ..['jurisdictions'] = [...legacyCities, syntheticCities.single];

    await importRestrictionsDataset(db, mixed);
    final rows = await db.select(db.restrictionCoverages).get();

    expect(rows, hasLength(13));
    expect(rows.map((row) => row.jurisdictionId).toSet(), hasLength(8));
    expect(
      rows.where((row) => row.coverageCompleteness == 'legacy'),
      hasLength(12),
    );
    expect(
      rows.where((row) => row.coverageCompleteness == 'partial'),
      hasLength(1),
    );
    for (final cityValue in legacyCities) {
      final city = cityValue as Map<String, dynamic>;
      for (final coverageValue in city['coverages'] as List) {
        final coverage = coverageValue as Map<String, dynamic>;
        final row = rows.singleWhere(
          (candidate) =>
              candidate.jurisdictionId == city['id'] &&
              candidate.vehicleKind == coverage['vehicleKind'] &&
              candidate.serviceType == coverage['serviceType'],
        );
        expect(jsonDecode(row.rulesJson), coverage['rules']);
        expect(
          row.staleAfter.toUtc(),
          DateTime.parse(coverage['staleAfter'] as String).toUtc(),
        );
        expect(
          row.verifiedAt.toUtc(),
          DateTime.parse(coverage['verifiedAt'] as String).toUtc(),
        );
        expect(jsonDecode(row.sourceUrlsJson), coverage['sourceUrls']);
      }
    }
  });

  test('schema1 rejects V2-only condition and coverage fields', () async {
    final conditionInV1 = _schema2()..['schemaVersion'] = 1;
    (conditionInV1['jurisdictions'] as List).single['schemaVersion'] = 1;
    await expectLater(
      importRestrictionsDataset(db, conditionInV1),
      throwsA(isA<DatasetSyncException>()),
    );

    final completenessInV1 = _schema1()
      ..['jurisdictions'] = [
        {
          'id': 'co-g2-synthetic',
          'name': 'SYNTHETIC',
          'coverages': [
            {
              'vehicleKind': 'car',
              'serviceType': 'private',
              'coverageCompleteness': 'complete',
              'verifiedAt': '2026-11-10T00:00:00Z',
              'staleAfter': '2026-11-20T00:00:00Z',
              'sourceUrls': ['https://example.test/synthetic'],
              'rules': [],
            },
          ],
        },
      ];
    await expectLater(
      importRestrictionsDataset(db, completenessInV1),
      throwsA(isA<DatasetSyncException>()),
    );
    expect(await db.select(db.restrictionCoverages).get(), isEmpty);
  });

  test('schema2 rejects an explicit null city schema version', () async {
    final payload = _schema2();
    final jurisdictions = payload['jurisdictions'] as List<dynamic>;
    final city = Map<String, dynamic>.from(jurisdictions.single as Map)
      ..['schemaVersion'] = null;
    payload['jurisdictions'] = [city];

    await expectLater(
      importRestrictionsDataset(db, payload),
      throwsA(isA<DatasetSyncException>()),
    );
  });

  test(
    'schema2 rejects unknown condition, duplicate type, and impossible pair',
    () async {
      final unknown = _schema2();
      _conditions(unknown).add({'type': 'future_operator', 'value': 1});
      await expectLater(
        importRestrictionsDataset(db, unknown),
        throwsA(isA<DatasetSyncException>()),
      );

      final duplicate = _schema2();
      _conditions(duplicate).add({'type': 'gross_weight_kg_gt', 'value': 9000});
      await expectLater(
        importRestrictionsDataset(db, duplicate),
        throwsA(isA<DatasetSyncException>()),
      );

      final impossible = _schema2(
        conditions: [
          {'type': 'occupants_at_least', 'value': 3},
          {'type': 'occupants_below', 'value': 3},
        ],
      );
      await expectLater(
        importRestrictionsDataset(db, impossible),
        throwsA(isA<DatasetSyncException>()),
      );
    },
  );

  test(
    'schema2 validates all condition types, ranges, and scope references',
    () async {
      final validBoundaries = _schema2(
        conditions: [
          {'type': 'pillion_present', 'value': false},
          {'type': 'occupants_at_least', 'value': 1},
          {'type': 'occupants_below', 'value': 99},
          {'type': 'gross_weight_kg_gt', 'value': 0},
          {'type': 'axles_at_least', 'value': 20},
          {'type': 'inside_scope_ref', 'value': 'zone-1@v2'},
        ],
      );
      await importRestrictionsDataset(db, validBoundaries);

      for (final invalid in const [
        {'type': 'pillion_present', 'value': 1},
        {'type': 'occupants_at_least', 'value': 0},
        {'type': 'occupants_below', 'value': 100},
        {'type': 'gross_weight_kg_gt', 'value': 100001},
        {'type': 'axles_at_least', 'value': 21},
        {'type': 'inside_scope_ref', 'value': '@v2'},
        {'type': 'inside_scope_ref', 'value': 'zone@v2@extra'},
        {'type': 'inside_scope_ref', 'value': ' zone@v2 '},
      ]) {
        await expectLater(
          importRestrictionsDataset(
            db,
            _schema2(conditions: [Map<String, Object?>.from(invalid)]),
          ),
          throwsA(isA<DatasetSyncException>()),
        );
      }
    },
  );

  test('schema2 rejects explicit null conditions', () async {
    final payload = jsonDecode(jsonEncode(_schema2())) as Map<String, dynamic>;
    final jurisdictions = payload['jurisdictions'] as List<dynamic>;
    final city = jurisdictions.single as Map<String, dynamic>;
    final coverages = city['coverages'] as List<dynamic>;
    final coverage = coverages.single as Map<String, dynamic>;
    final rules = coverage['rules'] as List<dynamic>;
    final rule = rules.single as Map<String, dynamic>;
    rule['conditions'] = null;

    await expectLater(
      importRestrictionsDataset(db, payload),
      throwsA(isA<DatasetSyncException>()),
    );
  });

  test(
    'schema2 rejects mixed city/envelope version and illegal pairs',
    () async {
      final mixed = _schema2();
      (mixed['jurisdictions'] as List).single['schemaVersion'] = 1;
      await expectLater(
        importRestrictionsDataset(db, mixed),
        throwsA(isA<DatasetSyncException>()),
      );

      final illegal = _schema2(
        vehicleKind: 'motorcycle',
        serviceType: 'public_cargo',
      );
      await expectLater(
        importRestrictionsDataset(db, illegal),
        throwsA(isA<DatasetSyncException>()),
      );
    },
  );

  test('schema2 accepts only the documented vehicle/service pairs', () async {
    for (final pair in const [
      ('car', 'private'),
      ('car', 'taxi'),
      ('motorcycle', 'private'),
      ('truck', 'private'),
      ('truck', 'public_cargo'),
      ('bus', 'public_passenger'),
      ('bus', 'special'),
      ('car', 'special'),
      ('motocarro', 'private'),
    ]) {
      await importRestrictionsDataset(
        db,
        _schema2(vehicleKind: pair.$1, serviceType: pair.$2),
      );
      final row = await db.select(db.restrictionCoverages).getSingle();
      expect((row.vehicleKind, row.serviceType), pair);
    }

    for (final pair in const [
      ('truck', 'taxi'),
      ('bus', 'taxi'),
      ('motorcycle', 'public_cargo'),
    ]) {
      await expectLater(
        importRestrictionsDataset(
          db,
          _schema2(vehicleKind: pair.$1, serviceType: pair.$2),
        ),
        throwsA(isA<DatasetSyncException>()),
      );
    }
  });
}

List<Map<String, Object?>> _conditions(Map<String, dynamic> dataset) =>
    (((dataset['jurisdictions'] as List).single['coverages'] as List)
                    .single['rules']
                as List)
            .single['conditions']
        as List<Map<String, Object?>>;

Map<String, dynamic> _schema1() => {
  'schemaVersion': 1,
  'datasetKey': 'restrictions',
  'version': 'SYNTHETIC_G2_V1',
  'generatedAt': '2026-11-10T00:00:00Z',
  'jurisdictions': const [],
};

Future<String> _sha256(List<int> bytes) async {
  final digest = await Sha256().hash(bytes);
  return digest.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}

Map<String, dynamic> _schema2({
  String vehicleKind = 'truck',
  String serviceType = 'public_cargo',
  List<Map<String, Object?>>? conditions,
}) => {
  'schemaVersion': 2,
  'datasetKey': 'restrictions',
  'version': 'SYNTHETIC_G2_V2',
  'generatedAt': '2026-11-10T00:00:00Z',
  'jurisdictions': [
    {
      'schemaVersion': 2,
      'id': 'co-g2-synthetic',
      'name': 'SYNTHETIC_G2_ONLY',
      'coverages': [
        {
          'vehicleKind': vehicleKind,
          'serviceType': serviceType,
          'coverageCompleteness': 'partial',
          'verifiedAt': '2026-11-10T00:00:00Z',
          'staleAfter': '2026-11-20T00:00:00Z',
          'sourceUrls': ['https://example.test/synthetic'],
          'rules': [
            {
              'id': 'synthetic-rule',
              'priority': 100,
              'effect': 'restrict',
              'validFrom': '2026-11-10T00:00:00Z',
              'validUntil': '2026-11-19T23:59:59Z',
              'weekdays': [1, 2, 3, 4, 5],
              'timeWindows': [
                {'startMinute': 360, 'endMinute': 480},
              ],
              'appliesOnHolidays': false,
              'sourceUrl': 'https://example.test/synthetic',
              'verifiedAt': '2026-11-10T00:00:00Z',
              'conditions':
                  conditions ??
                  [
                    {'type': 'gross_weight_kg_gt', 'value': 8500},
                    {'type': 'inside_scope_ref', 'value': 'zone-1@v2'},
                  ],
            },
          ],
        },
      ],
    },
  ],
};
