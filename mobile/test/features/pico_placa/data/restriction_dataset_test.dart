import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/core/sync/dataset_sync_service.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/data/restriction_dataset.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_day_evaluation.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_engine.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_rule.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('imports a valid restrictions schema', () async {
    await importRestrictionsDataset(db, _dataset());

    final rows = await db.select(db.restrictionCoverages).get();
    expect(rows, hasLength(1));
    expect(rows.single.id, 'synthetic_test_jurisdiction:car:private');
    expect(rows.single.sourceUrlsJson, contains('example.test'));
  });

  test(
    'imports root schema2 availability metadata for legacy and schema2 cities',
    () async {
      final legacy = _dataset(
        schemaVersion: 2,
        jurisdictionPatch: {
          'municipalityCodes': ['05001', '05002'],
          'consultationEnabled': false,
        },
      );
      await importRestrictionsDataset(db, legacy);

      var metadata = await db
          .customSelect(
            'SELECT jurisdiction_id, municipality_codes_json, consultation_enabled '
            'FROM restriction_jurisdiction_availability',
          )
          .get();
      expect(metadata, hasLength(1));
      expect(
        metadata.single.read<String>('jurisdiction_id'),
        'synthetic_test_jurisdiction',
      );
      expect(
        metadata.single.read<String>('municipality_codes_json'),
        '["05001","05002"]',
      );
      expect(metadata.single.read<bool>('consultation_enabled'), isFalse);
      final listed = await RestrictionStore(db).listJurisdictions();
      expect(listed.single.municipalityCodes, ['05001', '05002']);
      expect(listed.single.consultationEnabled, isFalse);

      final schema2 = _dataset(
        schemaVersion: 2,
        coveragePatch: {'coverageCompleteness': 'partial'},
        rulePatch: {'conditions': []},
        jurisdictionPatch: {
          'schemaVersion': 2,
          'municipalityCodes': ['06001'],
          'consultationEnabled': true,
        },
      );
      await importRestrictionsDataset(db, schema2);

      metadata = await db
          .customSelect(
            'SELECT jurisdiction_id, municipality_codes_json, consultation_enabled '
            'FROM restriction_jurisdiction_availability',
          )
          .get();
      expect(metadata, hasLength(1));
      expect(
        metadata.single.read<String>('municipality_codes_json'),
        '["06001"]',
      );
      expect(metadata.single.read<bool>('consultation_enabled'), isTrue);
    },
  );

  test(
    'root schema1 and malformed availability metadata reject the whole import',
    () async {
      await importRestrictionsDataset(
        db,
        _dataset(
          schemaVersion: 2,
          jurisdictionPatch: {
            'municipalityCodes': ['05001'],
            'consultationEnabled': true,
          },
        ),
      );

      final invalid = [
        _dataset(
          jurisdictionPatch: {
            'municipalityCodes': ['05001'],
            'consultationEnabled': true,
          },
        ),
        _dataset(
          schemaVersion: 2,
          jurisdictionPatch: {
            'municipalityCodes': ['05001', '05001'],
            'consultationEnabled': true,
          },
        ),
        _dataset(
          schemaVersion: 2,
          jurisdictionPatch: {
            'municipalityCodes': ['05002', '05001'],
            'consultationEnabled': true,
          },
        ),
        _dataset(
          schemaVersion: 2,
          jurisdictionPatch: {
            'municipalityCodes': ['5001'],
            'consultationEnabled': true,
          },
        ),
        _dataset(
          schemaVersion: 2,
          jurisdictionPatch: {
            'municipalityCodes': ['05001'],
            'consultationEnabled': 'true',
          },
        ),
        _dataset(
          schemaVersion: 2,
          jurisdictionPatch: {
            'municipalityCodes': ['05001'],
          },
        ),
      ];
      for (final dataset in invalid) {
        await expectLater(
          importRestrictionsDataset(db, dataset),
          throwsA(isA<DatasetSyncException>()),
        );
      }

      final metadata = await db
          .customSelect(
            'SELECT municipality_codes_json, consultation_enabled '
            'FROM restriction_jurisdiction_availability',
          )
          .get();
      expect(metadata, hasLength(1));
      expect(
        metadata.single.read<String>('municipality_codes_json'),
        '["05001"]',
      );
      expect(metadata.single.read<bool>('consultation_enabled'), isTrue);
      expect(await db.select(db.restrictionCoverages).get(), hasLength(1));
    },
  );

  test('schema2 modality and jurisdiction toggles produce only safe evaluation states', () async {
    Map<String, dynamic> fixture({required bool jurisdictionEnabled}) {
      final dataset = _dataset(
        schemaVersion: 2,
        coveragePatch: {
          'coverageCompleteness': 'partial',
          'consultationEnabled': true,
        },
        rulePatch: {'conditions': []},
        jurisdictionPatch: {
          'schemaVersion': 2,
          'municipalityCodes': ['05001'],
          'consultationEnabled': jurisdictionEnabled,
        },
      );
      final jurisdiction = Map<String, dynamic>.from(
        (dataset['jurisdictions'] as List).single as Map,
      );
      final car = Map<String, dynamic>.from(
        (jurisdiction['coverages'] as List).single as Map,
      );
      final motorcycle = Map<String, dynamic>.from(car)
        ..['vehicleKind'] = 'motorcycle'
        ..['consultationEnabled'] = false;
      final motorcycleRule = Map<String, dynamic>.from(
        (car['rules'] as List).single as Map,
      )..['id'] = 'NON_PRODUCTION_FIXTURE-motorcycle-rule';
      motorcycle['rules'] = [motorcycleRule];
      jurisdiction['coverages'] = [car, motorcycle];
      dataset['jurisdictions'] = [jurisdiction];
      return dataset;
    }

    await importRestrictionsDataset(db, fixture(jurisdictionEnabled: true));
    final store = RestrictionStore(db);
    final day = DateTime(2026, 8, 27);
    final car = await store.loadCoverage(
      'synthetic_test_jurisdiction',
      VehicleKind.car,
      VehicleServiceType.private,
      DateTime(2026, 8, 27, 8),
    );
    final motorcycle = await store.loadCoverage(
      'synthetic_test_jurisdiction',
      VehicleKind.motorcycle,
      VehicleServiceType.private,
      DateTime(2026, 8, 27, 8),
    );
    expect(car.consultationEnabled, isTrue);
    expect(motorcycle.consultationEnabled, isFalse);
    expect(
      motorcycle.rules,
      isNotEmpty,
      reason: 'OFF retains rules for later reactivation.',
    );
    expect(
      evaluateRestrictionDay(
        ruleSet: car,
        jurisdictionId: 'synthetic_test_jurisdiction',
        plate: 'ABC123',
        vehicleKind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
        date: day,
      ).status,
      RestrictionDayStatus.unknown,
    );
    expect(
      evaluateRestrictionDay(
        ruleSet: motorcycle,
        jurisdictionId: 'synthetic_test_jurisdiction',
        plate: 'ABC123',
        vehicleKind: VehicleKind.motorcycle,
        serviceType: VehicleServiceType.private,
        date: day,
      ).status,
      RestrictionDayStatus.unknown,
    );

    await importRestrictionsDataset(db, fixture(jurisdictionEnabled: false));
    for (final (kind, coverage) in [
      (
        VehicleKind.car,
        await store.loadCoverage(
          'synthetic_test_jurisdiction',
          VehicleKind.car,
          VehicleServiceType.private,
          DateTime(2026, 8, 27, 8),
        ),
      ),
      (
        VehicleKind.motorcycle,
        await store.loadCoverage(
          'synthetic_test_jurisdiction',
          VehicleKind.motorcycle,
          VehicleServiceType.private,
          DateTime(2026, 8, 27, 8),
        ),
      ),
    ]) {
      expect(coverage.jurisdictionConsultationEnabled, isFalse);
      expect(
        evaluateRestrictionDay(
          ruleSet: coverage,
          jurisdictionId: 'synthetic_test_jurisdiction',
          plate: 'ABC123',
          vehicleKind: kind,
          serviceType: VehicleServiceType.private,
          date: day,
        ).status,
        RestrictionDayStatus.unknown,
      );
    }
  });

  test(
    'schema2 historical coverage without a toggle remains enabled',
    () async {
      await importRestrictionsDataset(
        db,
        _dataset(
          schemaVersion: 2,
          coveragePatch: {'coverageCompleteness': 'partial'},
          rulePatch: {'conditions': []},
          jurisdictionPatch: {'schemaVersion': 2},
        ),
      );

      final coverage = await RestrictionStore(db).loadCoverage(
        'synthetic_test_jurisdiction',
        VehicleKind.car,
        VehicleServiceType.private,
        DateTime(2026, 8, 27, 8),
      );
      expect(coverage.consultationEnabled, isTrue);
      expect(coverage.rules, isNotEmpty);
    },
  );

  test('rejects non-boolean schema2 coverage toggles', () async {
    await expectLater(
      importRestrictionsDataset(
        db,
        _dataset(
          schemaVersion: 2,
          coveragePatch: {
            'coverageCompleteness': 'partial',
            'consultationEnabled': 'false',
          },
          rulePatch: {'conditions': []},
          jurisdictionPatch: {'schemaVersion': 2},
        ),
      ),
      throwsA(isA<DatasetSyncException>()),
    );
  });

  test('rejects unsupported future restrictions schema', () async {
    await expectLater(
      importRestrictionsDataset(db, _dataset(schemaVersion: 3)),
      throwsA(isA<DatasetSyncException>()),
    );
  });

  test('rejects invalid enum values', () async {
    await expectLater(
      importRestrictionsDataset(
        db,
        _dataset(coveragePatch: {'vehicleKind': 'bus'}),
      ),
      throwsA(isA<DatasetSyncException>()),
    );
  });

  test('rejects invalid digits', () async {
    await expectLater(
      importRestrictionsDataset(
        db,
        _dataset(
          rulePatch: {
            'digits': [10],
          },
        ),
      ),
      throwsA(isA<DatasetSyncException>()),
    );
  });

  test('rejects invalid time windows', () async {
    await expectLater(
      importRestrictionsDataset(
        db,
        _dataset(
          rulePatch: {
            'timeWindows': [
              {'startMinute': 60, 'endMinute': 60},
            ],
          },
        ),
      ),
      throwsA(isA<DatasetSyncException>()),
    );
  });

  test('rejects duplicate rule ids', () async {
    final dataset = _dataset();
    final coverages =
        (dataset['jurisdictions'] as List).single['coverages'] as List;
    final rules = coverages.single['rules'] as List;
    rules.add(Map<String, Object?>.from(rules.single as Map));

    await expectLater(
      importRestrictionsDataset(db, dataset),
      throwsA(isA<DatasetSyncException>()),
    );
  });

  test('invalid import preserves previous coverage', () async {
    await importRestrictionsDataset(db, _dataset());

    await expectLater(
      importRestrictionsDataset(
        db,
        _dataset(
          rulePatch: {
            'digits': [-1],
          },
        ),
      ),
      throwsA(isA<DatasetSyncException>()),
    );

    final rows = await db.select(db.restrictionCoverages).get();
    expect(rows, hasLength(1));
    expect(rows.single.id, 'synthetic_test_jurisdiction:car:private');
  });

  test(
    'restriction envelope expiry is strict and preserves the last good data',
    () async {
      final now = DateTime.utc(2026, 8, 27);
      await importRestrictionsDataset(db, _dataset(), now: () => now);

      await importRestrictionsDataset(
        db,
        _dataset()..['expiresAt'] = '2026-08-28T00:00:00Z',
        now: () => now,
      );
      final accepted = await db.select(db.restrictionCoverages).get();
      expect(accepted, hasLength(1));

      await importRestrictionsDataset(
        db,
        _dataset()..['expiresAt'] = '2026-08-28T05:00:00-05:00',
        now: () => now,
      );
      await importRestrictionsDataset(
        db,
        _dataset()..['expiresAt'] = '2026-08-28T05:00:00+05:00',
        now: () => now,
      );

      for (final invalidExpiry in <Object?>[
        null,
        42,
        'tomorrow',
        '2026-08-28T00:00:00',
        '2026-08-28T00:00:00Z trailing',
        '2026-02-30T00:00:00Z',
        '2026-08-28T00:00:00+25:00',
        '2026-08-28T00:00:00+01:60',
        '2026-08-28T00:00:00-25:00',
      ]) {
        await expectLater(
          importRestrictionsDataset(
            db,
            _dataset()..['expiresAt'] = invalidExpiry,
            now: () => now,
          ),
          throwsA(isA<DatasetSyncException>()),
          reason: 'expiresAt must reject $invalidExpiry',
        );
      }

      for (final expiredAt in [
        '2026-08-27T00:00:00Z',
        '2026-08-26T23:59:59Z',
      ]) {
        await expectLater(
          importRestrictionsDataset(
            db,
            _dataset()..['expiresAt'] = expiredAt,
            now: () => now,
          ),
          throwsA(isA<DatasetSyncException>()),
        );
      }

      final lastGood = await db.select(db.restrictionCoverages).get();
      expect(lastGood, hasLength(1));
      expect(lastGood.single.id, 'synthetic_test_jurisdiction:car:private');
    },
  );

  test('import participates in the caller transaction rollback', () async {
    await expectLater(
      db.transaction(() async {
        await importRestrictionsDataset(db, _dataset());
        throw const DatasetSyncException('rollback probe');
      }),
      throwsA(isA<DatasetSyncException>()),
    );

    expect(await db.select(db.restrictionCoverages).get(), isEmpty);
  });

  test('missing coverage loads fail-closed unknown coverage data', () async {
    final loaded = await RestrictionStore(db).loadCoverage(
      'missing',
      VehicleKind.car,
      VehicleServiceType.private,
      DateTime.utc(2026, 8, 27),
    );

    expect(loaded.coverageKnown, isFalse);
    final result = const RestrictionEngine().evaluate(
      _context(loaded, jurisdictionId: 'missing', plate: 'ABC123'),
      loaded.rules,
    );
    expect(result.status, RestrictionStatus.unknown);
    expect(result.reasonCode, RestrictionReasonCode.unknownCoverage);
  });

  test('staleAfter is surfaced by the store', () async {
    await importRestrictionsDataset(
      db,
      _dataset(coveragePatch: {'staleAfter': '2026-08-01T00:00:00Z'}),
    );

    final loaded = await RestrictionStore(db).loadCoverage(
      'synthetic_test_jurisdiction',
      VehicleKind.car,
      VehicleServiceType.private,
      DateTime.utc(2026, 8, 27),
    );

    expect(loaded.coverageKnown, isTrue);
    expect(loaded.dataIsStale, isTrue);
    expect(loaded.staleAfter?.toUtc(), DateTime.utc(2026, 8, 1));
  });

  test('staleAfter boundary is inclusive', () async {
    await importRestrictionsDataset(db, _dataset());

    final fresh = await RestrictionStore(db).loadCoverage(
      'synthetic_test_jurisdiction',
      VehicleKind.car,
      VehicleServiceType.private,
      DateTime.utc(2026, 8, 31, 23, 59),
    );
    final stale = await RestrictionStore(db).loadCoverage(
      'synthetic_test_jurisdiction',
      VehicleKind.car,
      VehicleServiceType.private,
      DateTime.utc(2026, 9),
    );

    expect(fresh.dataIsStale, isFalse);
    expect(stale.dataIsStale, isTrue);
  });

  test(
    'staleAfter compares real instants independent of device wall clock',
    () async {
      await importRestrictionsDataset(
        db,
        _dataset(coveragePatch: {'staleAfter': '2026-09-01T05:00:00Z'}),
      );

      final loaded = await RestrictionStore(db).loadCoverage(
        'synthetic_test_jurisdiction',
        VehicleKind.car,
        VehicleServiceType.private,
        DateTime.parse('2026-08-31T20:30:00-10:00'),
      );

      expect(loaded.dataIsStale, isTrue);
    },
  );

  test('source metadata reaches engine evaluation', () async {
    await importRestrictionsDataset(db, _dataset());
    final loaded = await RestrictionStore(db).loadCoverage(
      'synthetic_test_jurisdiction',
      VehicleKind.car,
      VehicleServiceType.private,
      DateTime.utc(2026, 8, 27),
    );

    final result = const RestrictionEngine().evaluate(
      _context(loaded, plate: 'ABC123'),
      loaded.rules,
    );

    expect(result.sourceUrl, 'https://example.test/NON_PRODUCTION_FIXTURE');
    expect(result.verifiedAt, DateTime.utc(2026, 8, 27));
    expect(loaded.sourceUrls, ['https://example.test/NON_PRODUCTION_FIXTURE']);
  });

  test(
    'Medellin private car asset evaluates with last numeric digit',
    () async {
      await importRestrictionsDataset(db, await _assetDataset());
      final loaded = await RestrictionStore(db).loadCoverage(
        'co-ant-medellin',
        VehicleKind.car,
        VehicleServiceType.private,
        DateTime.utc(2026, 8, 27),
      );

      final result = const RestrictionEngine().evaluate(
        _context(
          loaded,
          jurisdictionId: 'co-ant-medellin',
          plate: 'ABC158',
          localDateTime: DateTime(2026, 8, 3, 8),
        ),
        loaded.rules,
      );

      expect(result.status, RestrictionStatus.restricted);
      expect(result.matchedRuleId, 'medellin-car-private-2026-r4-lun');
    },
  );

  test(
    'Medellin motorcycle asset evaluates with first numeric digit',
    () async {
      await importRestrictionsDataset(db, await _assetDataset());
      final loaded = await RestrictionStore(db).loadCoverage(
        'co-ant-medellin',
        VehicleKind.motorcycle,
        VehicleServiceType.private,
        DateTime.utc(2026, 8, 27),
      );

      final result = const RestrictionEngine().evaluate(
        _context(
          loaded,
          jurisdictionId: 'co-ant-medellin',
          vehicleKind: VehicleKind.motorcycle,
          plate: '8AB12',
          localDateTime: DateTime(2026, 8, 3, 8),
        ),
        loaded.rules,
      );

      expect(result.status, RestrictionStatus.restricted);
      expect(result.matchedRuleId, 'medellin-moto-private-2026-r4-lun');
    },
  );

  test(
    'Bogota private car asset evaluates September R4 parity rules',
    () async {
      await importRestrictionsDataset(db, await _assetDataset());
      final loaded = await RestrictionStore(db).loadCoverage(
        'co-dc-bogota',
        VehicleKind.car,
        VehicleServiceType.private,
        DateTime.utc(2026, 9, 10),
      );

      final evenDay = const RestrictionEngine().evaluate(
        _context(
          loaded,
          jurisdictionId: 'co-dc-bogota',
          plate: 'ABC123',
          localDateTime: DateTime(2026, 9, 10, 8),
        ),
        loaded.rules,
      );
      final oddDay = const RestrictionEngine().evaluate(
        _context(
          loaded,
          jurisdictionId: 'co-dc-bogota',
          plate: 'ABC126',
          localDateTime: DateTime(2026, 9, 11, 8),
        ),
        loaded.rules,
      );
      final outsideWindow = const RestrictionEngine().evaluate(
        _context(
          loaded,
          jurisdictionId: 'co-dc-bogota',
          plate: 'ABC123',
          localDateTime: DateTime(2026, 9, 10, 21),
        ),
        loaded.rules,
      );

      expect(evenDay.status, RestrictionStatus.restricted);
      expect(oddDay.status, RestrictionStatus.restricted);
      expect(outsideWindow.status, RestrictionStatus.allowed);
    },
  );

  test('Bogota taxi asset uses September R4 calendar coverage', () async {
    await importRestrictionsDataset(db, await _assetDataset());
    final loaded = await RestrictionStore(db).loadCoverage(
      'co-dc-bogota',
      VehicleKind.car,
      VehicleServiceType.taxi,
      DateTime.utc(2026, 9, 10),
    );

    expect(
      _taxiStatus(loaded, day: 9, plate: 'TXI078'),
      RestrictionStatus.restricted,
    );
    expect(
      _taxiStatus(loaded, day: 10, plate: 'TXI090'),
      RestrictionStatus.restricted,
    );
    expect(
      _taxiStatus(loaded, day: 10, plate: 'TXI078'),
      RestrictionStatus.allowed,
    );
    expect(
      _taxiStatus(loaded, day: 30, plate: 'TXI034'),
      RestrictionStatus.restricted,
    );
  });

  test('R4 automatic city assets evaluate verified 2026 car rules', () async {
    await importRestrictionsDataset(db, await _assetDataset());

    expect(
      await _assetStatus(
        db,
        jurisdictionId: 'co-ant-medellin',
        plate: 'BOG126',
        localDateTime: DateTime(2026, 9, 10, 8),
      ),
      RestrictionStatus.restricted,
    );
    expect(
      await _assetStatus(
        db,
        jurisdictionId: 'co-san-bucaramanga',
        plate: 'ABC034',
        localDateTime: DateTime(2026, 9, 10, 7),
      ),
      RestrictionStatus.restricted,
    );
    expect(
      await _assetStatus(
        db,
        jurisdictionId: 'co-cau-popayan',
        plate: 'ABC056',
        localDateTime: DateTime(2026, 9, 10, 8),
      ),
      RestrictionStatus.restricted,
    );
    expect(
      await _assetStatus(
        db,
        jurisdictionId: 'co-cal-manizales',
        plate: 'ABC056',
        localDateTime: DateTime(2026, 9, 10, 8),
      ),
      RestrictionStatus.restricted,
    );
    expect(
      await _assetStatus(
        db,
        jurisdictionId: 'co-met-villavicencio',
        plate: 'ABC012',
        localDateTime: DateTime(2026, 9, 10, 8),
      ),
      RestrictionStatus.restricted,
    );
  });

  test(
    'R4 conditioned cities fail closed without automatic runtime rules',
    () async {
      await importRestrictionsDataset(db, await _assetDataset());

      final cali = await _assetEvaluation(
        db,
        jurisdictionId: 'co-vac-cali',
        plate: 'ABC056',
        localDateTime: DateTime(2026, 9, 10, 8),
      );
      final cartagena = await _assetEvaluation(
        db,
        jurisdictionId: 'co-bol-cartagena',
        plate: 'ABC056',
        localDateTime: DateTime(2026, 9, 10, 8),
      );
      final ibague = await _assetEvaluation(
        db,
        jurisdictionId: 'co-tol-ibague',
        plate: 'ABC067',
        localDateTime: DateTime(2026, 7, 6, 8),
      );

      expect(cali.status, RestrictionStatus.unknown);
      expect(cali.reasonCode, RestrictionReasonCode.unknownCoverage);
      expect(cartagena.status, RestrictionStatus.unknown);
      expect(cartagena.reasonCode, RestrictionReasonCode.unknownCoverage);
      expect(ibague.status, RestrictionStatus.unknown);
      expect(ibague.reasonCode, RestrictionReasonCode.unknownCoverage);
    },
  );

  test(
    'empty legacy coverage stays unknown without inventing no restriction',
    () async {
      await importRestrictionsDataset(db, await _assetDataset());

      final bogotaMoto = await RestrictionStore(db).loadCoverage(
        'co-dc-bogota',
        VehicleKind.motorcycle,
        VehicleServiceType.private,
        DateTime.utc(2026, 9, 10),
      );
      final barranquillaTaxi = await RestrictionStore(db).loadCoverage(
        'co-atl-barranquilla',
        VehicleKind.car,
        VehicleServiceType.taxi,
        DateTime.utc(2026, 9, 10),
      );

      expect(bogotaMoto.coverageKnown, isTrue);
      expect(bogotaMoto.rules, isEmpty);
      final evaluation = const RestrictionEngine().evaluate(
        _context(
          bogotaMoto,
          jurisdictionId: 'co-dc-bogota',
          vehicleKind: VehicleKind.motorcycle,
          plate: 'MOT123',
          localDateTime: DateTime(2026, 9, 10, 8),
        ),
        bogotaMoto.rules,
      );
      expect(evaluation.status, RestrictionStatus.unknown);
      expect(evaluation.reasonCode, RestrictionReasonCode.unknownCoverage);
      expect(barranquillaTaxi.coverageKnown, isTrue);
      expect(barranquillaTaxi.rules, isEmpty);
    },
  );

  test(
    'R4 Bucaramanga Saturday and Q4 rotations honor review window',
    () async {
      await importRestrictionsDataset(db, await _assetDataset());

      expect(
        await _assetStatus(
          db,
          jurisdictionId: 'co-san-bucaramanga',
          plate: 'ABC012',
          localDateTime: DateTime(2026, 9, 12, 10),
        ),
        RestrictionStatus.restricted,
      );
      expect(
        await _assetStatus(
          db,
          jurisdictionId: 'co-san-bucaramanga',
          plate: 'ABC012',
          localDateTime: DateTime(2026, 9, 19, 10),
        ),
        RestrictionStatus.allowed,
      );
      expect(
        await _assetStatus(
          db,
          jurisdictionId: 'co-san-bucaramanga',
          plate: 'ABC056',
          localDateTime: DateTime(2026, 10, 5, 8),
        ),
        RestrictionStatus.stale,
      );
    },
  );

  test('bundled asset parses correctly', () async {
    await importRestrictionsDataset(db, await _assetDataset());

    final rows = await db.select(db.restrictionCoverages).get();
    expect(rows, hasLength(12));
  });

  test('bundled staleAfter values represent Colombia midnight', () async {
    await importRestrictionsDataset(db, await _assetDataset());

    final rows = await db.select(db.restrictionCoverages).get();
    final staleAfterById = {
      for (final row in rows) row.id: row.staleAfter.toUtc(),
    };

    expect(
      staleAfterById['co-ant-medellin:car:private'],
      DateTime.utc(2026, 9, 23, 5),
    );
    expect(
      staleAfterById['co-ant-medellin:motorcycle:private'],
      DateTime.utc(2026, 9, 23, 5),
    );
    expect(
      staleAfterById['co-dc-bogota:car:private'],
      DateTime.utc(2026, 9, 23, 5),
    );
    expect(
      staleAfterById['co-dc-bogota:car:taxi'],
      DateTime.utc(2026, 9, 28, 5),
    );
    expect(
      staleAfterById['co-cal-manizales:car:private'],
      DateTime.utc(2026, 9, 14, 5),
    );
    expect(
      staleAfterById['co-san-bucaramanga:car:private'],
      DateTime.utc(2026, 9, 28, 5),
    );
    expect(
      staleAfterById['co-san-bucaramanga:motorcycle:private'],
      DateTime.utc(2026, 9, 28, 5),
    );
    expect(
      staleAfterById['co-cau-popayan:car:private'],
      DateTime.utc(2026, 9, 23, 5),
    );
    expect(
      staleAfterById['co-met-villavicencio:car:private'],
      DateTime.utc(2026, 9, 23, 5),
    );
    expect(
      staleAfterById['co-atl-barranquilla:car:taxi'],
      DateTime.utc(2026, 9, 23, 5),
    );
  });
}

Future<RestrictionStatus> _assetStatus(
  AppDatabase db, {
  required String jurisdictionId,
  required String plate,
  required DateTime localDateTime,
}) async {
  return (await _assetEvaluation(
    db,
    jurisdictionId: jurisdictionId,
    plate: plate,
    localDateTime: localDateTime,
  )).status;
}

Future<RestrictionEvaluation> _assetEvaluation(
  AppDatabase db, {
  required String jurisdictionId,
  required String plate,
  required DateTime localDateTime,
}) async {
  final loaded = await RestrictionStore(db).loadCoverage(
    jurisdictionId,
    VehicleKind.car,
    VehicleServiceType.private,
    localDateTime,
  );
  return const RestrictionEngine().evaluate(
    _context(
      loaded,
      jurisdictionId: jurisdictionId,
      plate: plate,
      localDateTime: localDateTime,
    ),
    loaded.rules,
  );
}

RestrictionStatus _taxiStatus(
  RestrictionRuleSet loaded, {
  required int day,
  required String plate,
}) {
  return const RestrictionEngine()
      .evaluate(
        _context(
          loaded,
          jurisdictionId: 'co-dc-bogota',
          serviceType: VehicleServiceType.taxi,
          plate: plate,
          localDateTime: DateTime(2026, 9, day, 6),
        ),
        loaded.rules,
      )
      .status;
}

RestrictionContext _context(
  RestrictionRuleSet loaded, {
  String jurisdictionId = 'synthetic_test_jurisdiction',
  String plate = 'ABC123',
  VehicleKind vehicleKind = VehicleKind.car,
  VehicleServiceType serviceType = VehicleServiceType.private,
  DateTime? localDateTime,
}) {
  return RestrictionContext(
    jurisdictionId: jurisdictionId,
    plate: plate,
    vehicleKind: vehicleKind,
    serviceType: serviceType,
    registrationOrigin: RegistrationOrigin.local,
    localDateTime: localDateTime ?? DateTime(2026, 8, 27, 8),
    isHoliday: false,
    coverageKnown: loaded.coverageKnown,
    dataIsStale: loaded.dataIsStale,
  );
}

Future<Map<String, dynamic>> _assetDataset() async {
  final file = File('assets/datasets/restrictions/restrictions_v1.json');
  return Map<String, dynamic>.from(
    jsonDecode(await file.readAsString()) as Map,
  );
}

Map<String, dynamic> _dataset({
  int schemaVersion = 1,
  Map<String, Object?> coveragePatch = const {},
  Map<String, Object?> rulePatch = const {},
  Map<String, Object?> jurisdictionPatch = const {},
}) {
  final rule = <String, Object?>{
    'id': 'NON_PRODUCTION_FIXTURE-synthetic-rule',
    'priority': 1000,
    'effect': 'restrict',
    'validFrom': '2026-08-01T00:00:00',
    'validUntil': '2026-08-31T23:59:59',
    'weekdays': [1, 2, 3, 4, 5],
    'digitPosition': 'lastNumeric',
    'digits': [3],
    'timeWindows': [
      {'startMinute': 360, 'endMinute': 1260},
    ],
    'appliesOnHolidays': false,
    'sourceUrl': 'https://example.test/NON_PRODUCTION_FIXTURE',
    'verifiedAt': '2026-08-27T00:00:00Z',
    ...rulePatch,
  };
  final coverage = <String, Object?>{
    'vehicleKind': 'car',
    'serviceType': 'private',
    'verifiedAt': '2026-08-27T00:00:00Z',
    'staleAfter': '2026-09-01T00:00:00Z',
    'sourceUrls': ['https://example.test/NON_PRODUCTION_FIXTURE'],
    'rules': [rule],
    ...coveragePatch,
  };
  return {
    'schemaVersion': schemaVersion,
    'datasetKey': 'restrictions',
    'version': 'NON_PRODUCTION_FIXTURE',
    'generatedAt': '2026-08-27T00:00:00Z',
    'jurisdictions': [
      {
        'id': 'synthetic_test_jurisdiction',
        'name': 'NON_PRODUCTION_FIXTURE',
        'coverages': [coverage],
        ...jurisdictionPatch,
      },
    ],
  };
}
