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

  test('rejects incompatible restrictions schema', () async {
    await expectLater(
      importRestrictionsDataset(db, _dataset(schemaVersion: 2)),
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
      expect(result.matchedRuleId, 'medellin-car-private-2026h2-mon');
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
      expect(result.matchedRuleId, 'medellin-moto-private-2026h2-mon');
    },
  );

  test('Bogota private car asset evaluates odd/even rules', () async {
    await importRestrictionsDataset(db, await _assetDataset());
    final loaded = await RestrictionStore(db).loadCoverage(
      'co-dc-bogota',
      VehicleKind.car,
      VehicleServiceType.private,
      DateTime.utc(2026, 8, 27),
    );

    final evenDay = const RestrictionEngine().evaluate(
      _context(
        loaded,
        jurisdictionId: 'co-dc-bogota',
        plate: 'ABC123',
        localDateTime: DateTime(2026, 8, 26, 8),
      ),
      loaded.rules,
    );
    final oddDay = const RestrictionEngine().evaluate(
      _context(
        loaded,
        jurisdictionId: 'co-dc-bogota',
        plate: 'ABC126',
        localDateTime: DateTime(2026, 8, 27, 8),
      ),
      loaded.rules,
    );

    expect(evenDay.status, RestrictionStatus.restricted);
    expect(oddDay.status, RestrictionStatus.restricted);
  });

  test('Bogota taxi asset keeps 24 to 31 August coverage', () async {
    await importRestrictionsDataset(db, await _assetDataset());
    final loaded = await RestrictionStore(db).loadCoverage(
      'co-dc-bogota',
      VehicleKind.car,
      VehicleServiceType.taxi,
      DateTime.utc(2026, 8, 27),
    );

    expect(
      _taxiStatus(loaded, day: 24, plate: 'TXI090'),
      RestrictionStatus.restricted,
    );
    expect(
      _taxiStatus(loaded, day: 25, plate: 'TXI001'),
      RestrictionStatus.restricted,
    );
    expect(
      _taxiStatus(loaded, day: 26, plate: 'TXI034'),
      RestrictionStatus.restricted,
    );
    expect(
      _taxiStatus(loaded, day: 27, plate: 'TXI056'),
      RestrictionStatus.restricted,
    );
    expect(
      _taxiStatus(loaded, day: 28, plate: 'TXI078'),
      RestrictionStatus.restricted,
    );
    expect(
      _taxiStatus(loaded, day: 29, plate: 'TXI090'),
      RestrictionStatus.restricted,
    );
    expect(
      _taxiStatus(loaded, day: 30, plate: 'TXI090'),
      RestrictionStatus.allowed,
    );
    expect(
      _taxiStatus(loaded, day: 31, plate: 'TXI001'),
      RestrictionStatus.restricted,
    );
  });

  test('bundled asset parses correctly', () async {
    await importRestrictionsDataset(db, await _assetDataset());

    final rows = await db.select(db.restrictionCoverages).get();
    expect(rows, hasLength(4));
  });

  test('bundled staleAfter values represent Colombia midnight', () async {
    await importRestrictionsDataset(db, await _assetDataset());

    final rows = await db.select(db.restrictionCoverages).get();
    final staleAfterById = {
      for (final row in rows) row.id: row.staleAfter.toUtc(),
    };

    expect(
      staleAfterById['co-ant-medellin:car:private'],
      DateTime.utc(2027, 1, 1, 5),
    );
    expect(
      staleAfterById['co-ant-medellin:motorcycle:private'],
      DateTime.utc(2027, 1, 1, 5),
    );
    expect(
      staleAfterById['co-dc-bogota:car:private'],
      DateTime.utc(2026, 9, 1, 5),
    );
    expect(
      staleAfterById['co-dc-bogota:car:taxi'],
      DateTime.utc(2026, 9, 1, 5),
    );
  });
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
          localDateTime: DateTime(2026, 8, day, 6),
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
      },
    ],
  };
}
