import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/config/app_config.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/core/storage/app_preferences.dart';
import 'package:picoradar/core/sync/dataset_sync_service.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/data/restriction_dataset.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';
import 'package:picoradar/features/pico_placa/domain/colombia_holiday_calendar.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_engine.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_rule.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  test(
    'imports the exact Laravel release and evaluates Bogota November cases',
    () async {
      final r2EvidenceDirectory =
          Platform.environment['PICORADAR_R2_EVIDENCE_DIR'];
      final evidenceDirectory =
          r2EvidenceDirectory ??
          Platform.environment['PICORADAR_R1_EVIDENCE_DIR'];
      if (evidenceDirectory == null || evidenceDirectory.isEmpty) {
        markTestSkipped(
          'Requires exact release and manifest exported by Laravel R1 test.',
        );
        return;
      }
      final releaseName = r2EvidenceDirectory == null
          ? 'ACTUAL_LARAVEL_RELEASE.json'
          : 'ACTUAL_R2_LARAVEL_RELEASE.json';
      final manifestName = r2EvidenceDirectory == null
          ? 'ACTUAL_MANIFEST.json'
          : 'ACTUAL_R2_MANIFEST.json';
      final releaseFile = File(
        '$evidenceDirectory${Platform.pathSeparator}$releaseName',
      );
      final manifestFile = File(
        '$evidenceDirectory${Platform.pathSeparator}$manifestName',
      );
      final releaseBytes = await releaseFile.readAsBytes();
      var manifestBytes = await manifestFile.readAsBytes();
      final manifest =
          jsonDecode(utf8.decode(manifestBytes)) as Map<String, dynamic>;
      final runtimeNow = DateTime.parse(manifest['generatedAt'] as String)
          .toUtc();
      final entry =
          (manifest['datasets'] as Map<String, dynamic>)['restrictions']
              as Map<String, dynamic>;
      final phpSha = await _sha256(releaseBytes);
      final manifestSha = entry['sha256'] as String;
      expect(phpSha, manifestSha);

      final db = AppDatabase(NativeDatabase.memory());
      final tempDirectory = await Directory.systemTemp.createTemp(
        'picoradar_r1_e2e_',
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var servedRelease = releaseBytes;
      server.listen((request) async {
        try {
          if (request.uri.path == '/v1/manifest.json') {
            request.response.headers.contentType = ContentType.json;
            request.response.add(manifestBytes);
          } else if (request.uri.path ==
              Uri.parse(entry['url'] as String).path) {
            request.response.headers.contentType = ContentType.json;
            request.response.add(servedRelease);
          } else {
            request.response.statusCode = HttpStatus.notFound;
          }
          await request.response.close();
        } catch (_) {
          await request.response.close();
        }
      });

      try {
        final origin = 'http://127.0.0.1:${server.port}/';
        final service = DatasetSyncService(
          database: db,
          preferences: _MemoryPreferences(),
          config: AppConfig(cdnBaseUrl: origin),
          importers: {'restrictions': importRestrictionsDataset},
          http: Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 3),
              receiveTimeout: const Duration(seconds: 3),
            ),
          ),
          tempDirectory: tempDirectory,
          now: () => runtimeNow,
        );

        final imported = await service.sync();
        expect(imported.imported, ['restrictions']);
        final rows = await db.select(db.restrictionCoverages).get();
        expect(rows, hasLength(12));
        final installed = (await db.select(db.datasetVersions).get()).single;
        final dartInputSha = await _sha256(releaseBytes);
        expect(installed.sha256, manifestSha);
        expect(dartInputSha, manifestSha);

        final store = RestrictionStore(db);
        final results = <String, RestrictionStatus>{};
        Future<RestrictionStatus> at(
          String id,
          DateTime date,
          String plate,
        ) async {
          final coverage = await store.loadCoverage(
            'co-dc-bogota',
            VehicleKind.car,
            VehicleServiceType.private,
            DateTime(
                  date.year,
                  date.month,
                  date.day,
                ).isAfter(DateTime(2026, 11, 30))
                ? DateTime.utc(2026, 12, 1, 14)
                : runtimeNow,
          );
          final evaluation = const RestrictionEngine().evaluate(
            RestrictionContext(
              jurisdictionId: 'co-dc-bogota',
              plate: plate,
              vehicleKind: VehicleKind.car,
              serviceType: VehicleServiceType.private,
              registrationOrigin: RegistrationOrigin.unknown,
              localDateTime: date,
              isHoliday: const ColombiaHolidayCalendar().isHoliday(date),
              coverageKnown: coverage.coverageKnown,
              dataIsStale: coverage.dataIsStale,
            ),
            coverage.rules,
          );
          results[id] = evaluation.status;
          return evaluation.status;
        }

        expect(
          await at('U01', DateTime(2026, 11, 9, 8), 'ABC126'),
          RestrictionStatus.restricted,
        );
        expect(
          await at('U02', DateTime(2026, 11, 9, 8), 'ABC123'),
          RestrictionStatus.allowed,
        );
        expect(
          await at('U03', DateTime(2026, 11, 10, 8), 'ABC123'),
          RestrictionStatus.restricted,
        );
        expect(
          await at('U04', DateTime(2026, 11, 10, 8), 'ABC126'),
          RestrictionStatus.allowed,
        );
        expect(
          await at('U05', DateTime(2026, 11, 10, 5, 59), 'ABC123'),
          RestrictionStatus.allowed,
        );
        expect(
          await at('U06', DateTime(2026, 11, 10, 21), 'ABC123'),
          RestrictionStatus.allowed,
        );
        expect(
          await at('U07', DateTime(2026, 11, 8, 8), 'ABC126'),
          RestrictionStatus.allowed,
        );
        expect(
          await at('U08', DateTime(2026, 11, 16, 14), 'ABC126'),
          RestrictionStatus.allowed,
        );
        expect(
          await at('U09', DateTime(2026, 11, 2, 17), 'ABC123'),
          RestrictionStatus.allowed,
        );
        expect(
          await at('U10', DateTime(2026, 11, 30, 9), 'ABC121'),
          RestrictionStatus.restricted,
        );
        expect(
          await at('U11', DateTime(2026, 12, 1, 9), 'ABC121'),
          RestrictionStatus.stale,
        );

        final taxi = await store.loadCoverage(
          'co-dc-bogota',
          VehicleKind.car,
          VehicleServiceType.taxi,
          runtimeNow,
        );
        const expectedTaxiDigitsByDate = <String, Set<int>>{
          '2026-11-03': {1, 2},
          '2026-11-04': {3, 4},
          '2026-11-05': {5, 6},
          '2026-11-06': {7, 8},
          '2026-11-07': {9, 0},
          '2026-11-09': {1, 2},
          '2026-11-10': {3, 4},
          '2026-11-11': {5, 6},
          '2026-11-12': {7, 8},
          '2026-11-13': {9, 0},
          '2026-11-14': {1, 2},
          '2026-11-17': {5, 6},
          '2026-11-18': {7, 8},
          '2026-11-19': {9, 0},
          '2026-11-20': {1, 2},
          '2026-11-21': {3, 4},
          '2026-11-23': {5, 6},
          '2026-11-24': {7, 8},
          '2026-11-25': {9, 0},
          '2026-11-26': {1, 2},
          '2026-11-27': {3, 4},
          '2026-11-28': {5, 6},
          '2026-11-30': {7, 8},
        };
        expect(taxi.coverageKnown, isTrue);
        expect(taxi.dataIsStale, isFalse);
        expect(taxi.rules, hasLength(23));
        final actualTaxiDigitsByDate = <String, Set<int>>{};
        for (final rule in taxi.rules) {
          final date = rule.validFrom.toUtc();
          final dateKey =
              '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          actualTaxiDigitsByDate[dateKey] = rule.digits!;
          expect(date, DateTime.utc(date.year, date.month, date.day, 5));
          expect(
            rule.validUntil!.toUtc(),
            DateTime.utc(
              date.year,
              date.month,
              date.day + 1,
              5,
            ).subtract(const Duration(seconds: 1)),
          );
          expect(rule.weekdays, {
            DateTime(date.year, date.month, date.day).weekday,
          });
          expect(rule.dateParity, isNull);
          expect(rule.digitPosition, RestrictionDigitPosition.lastNumeric);
          expect(rule.timeWindows.single.startMinute, 330);
          expect(rule.timeWindows.single.endMinute, 1260);
          expect(rule.appliesOnHolidays, isFalse);
        }
        expect(actualTaxiDigitsByDate, expectedTaxiDigitsByDate);

        final taxiOutcomes = <String, RestrictionStatus>{};
        Future<RestrictionStatus> taxiAt(
          String id,
          DateTime date,
          String plate,
        ) async {
          final localDay = DateTime(date.year, date.month, date.day);
          final now = localDay.isAfter(DateTime(2026, 11, 30))
              ? DateTime.utc(2026, 12, 1, 14)
              : runtimeNow;
          final current = await store.loadCoverage(
            'co-dc-bogota',
            VehicleKind.car,
            VehicleServiceType.taxi,
            now,
          );
          final evaluation = const RestrictionEngine().evaluate(
            RestrictionContext(
              jurisdictionId: 'co-dc-bogota',
              plate: plate,
              vehicleKind: VehicleKind.car,
              serviceType: VehicleServiceType.taxi,
              registrationOrigin: RegistrationOrigin.unknown,
              localDateTime: date,
              isHoliday: const ColombiaHolidayCalendar().isHoliday(date),
              coverageKnown: current.coverageKnown,
              dataIsStale: current.dataIsStale,
            ),
            current.rules,
          );
          taxiOutcomes[id] = evaluation.status;
          return evaluation.status;
        }

        expect(
          await taxiAt(
            'T01_BEFORE_0530',
            DateTime(2026, 11, 3, 5, 29),
            'TAX121',
          ),
          RestrictionStatus.allowed,
        );
        expect(
          await taxiAt('T02_AT_0530', DateTime(2026, 11, 3, 5, 30), 'TAX121'),
          RestrictionStatus.restricted,
        );
        expect(
          await taxiAt(
            'T03_BEFORE_2100',
            DateTime(2026, 11, 3, 20, 59),
            'TAX121',
          ),
          RestrictionStatus.restricted,
        );
        expect(
          await taxiAt('T04_AT_2100', DateTime(2026, 11, 3, 21), 'TAX121'),
          RestrictionStatus.allowed,
        );
        expect(
          await taxiAt('T05_HOLIDAY_02', DateTime(2026, 11, 2, 12), 'TAX121'),
          RestrictionStatus.allowed,
        );
        expect(
          await taxiAt('T06_HOLIDAY_16', DateTime(2026, 11, 16, 12), 'TAX125'),
          RestrictionStatus.allowed,
        );
        expect(
          await taxiAt('T07_SUNDAY', DateTime(2026, 11, 8, 8), 'TAX121'),
          RestrictionStatus.allowed,
        );
        expect(
          await taxiAt(
            'T08_SATURDAY_RESTRICTED',
            DateTime(2026, 11, 7, 5, 30),
            'TAX129',
          ),
          RestrictionStatus.restricted,
        );
        expect(
          await taxiAt(
            'T09_SATURDAY_ALLOWED',
            DateTime(2026, 11, 7, 5, 30),
            'TAX121',
          ),
          RestrictionStatus.allowed,
        );
        expect(
          await taxiAt(
            'T10_NOVEMBER_END',
            DateTime(2026, 11, 30, 20, 59),
            'TAX127',
          ),
          RestrictionStatus.restricted,
        );
        expect(
          await taxiAt(
            'T11_AFTER_VALIDITY',
            DateTime(2026, 12, 1, 5, 30),
            'TAX127',
          ),
          RestrictionStatus.stale,
        );
        final taxiU12 = await taxiAt(
          'U12',
          DateTime(2026, 11, 9, 5, 30),
          'TAX121',
        );
        expect(taxiU12, RestrictionStatus.restricted);

        final allDayRule = _rule(digits: null);
        expect(
          _evaluateRule(allDayRule, plate: 'NO-PLATE').status,
          RestrictionStatus.restricted,
        );
        final filteredRule = _rule(digits: {1});
        expect(
          _evaluateRule(filteredRule, plate: 'INVALID').status,
          RestrictionStatus.unknown,
        );
        expect(
          const RestrictionEngine()
              .evaluate(
                _context(
                  plate: 'SYN001',
                  coverageCompleteness: CoverageCompleteness.complete,
                ),
                const <RestrictionRule>[],
              )
              .status,
          RestrictionStatus.allowed,
        );
        expect(
          const RestrictionEngine()
              .evaluate(
                RestrictionContext(
                  jurisdictionId: 'co-dc-bogota',
                  plate: 'SYN001',
                  vehicleKind: VehicleKind.car,
                  serviceType: VehicleServiceType.private,
                  registrationOrigin: RegistrationOrigin.unknown,
                  localDateTime: DateTime(2026, 11, 9, 8),
                  isHoliday: false,
                  coverageKnown: false,
                  dataIsStale: false,
                ),
                const <RestrictionRule>[],
              )
              .status,
          RestrictionStatus.unknown,
        );

        final originalCoverageIds =
            (await db.select(db.restrictionCoverages).get())
                .map((row) => row.id)
                .toSet();
        final originalVersion = installed.version;
        manifestBytes = utf8.encode(
          _negativeManifest(
            version: 'r3-bad-sha',
            revision: 3,
            url: entry['url'] as String,
            sha256: '0' * 64,
          ),
        );
        servedRelease = releaseBytes;
        await expectLater(service.sync(), throwsA(isA<DatasetSyncException>()));
        expect(
          (await db.select(db.datasetVersions).get()).single.version,
          originalVersion,
        );
        expect(
          (await db.select(db.restrictionCoverages).get())
              .map((row) => row.id)
              .toSet(),
          originalCoverageIds,
        );

        final corruptJson = utf8.encode(
          '{"schemaVersion":1,"datasetKey":"restrictions","version":"r3-corrupt-json","jurisdictions":[',
        );
        manifestBytes = utf8.encode(
          _negativeManifest(
            version: 'r3-corrupt-json',
            revision: 3,
            url: entry['url'] as String,
            sha256: await _sha256(corruptJson),
          ),
        );
        servedRelease = corruptJson;
        await expectLater(service.sync(), throwsA(isA<DatasetSyncException>()));
        expect(
          (await db.select(db.datasetVersions).get()).single.version,
          originalVersion,
        );
        expect(
          (await db.select(db.restrictionCoverages).get())
              .map((row) => row.id)
              .toSet(),
          originalCoverageIds,
        );

        // Restore Laravel's exact manifest and prove same-version sync is idempotent.
        manifestBytes = await manifestFile.readAsBytes();
        servedRelease = releaseBytes;
        final repeated = await service.sync();
        expect(repeated.skippedCurrent, ['restrictions']);
        expect((await db.select(db.restrictionCoverages).get()), hasLength(12));

        final resultFile = File(
          '$evidenceDirectory${Platform.pathSeparator}FLUTTER_IMPORT_RESULT.md',
        );
        await resultFile.writeAsString('''# Flutter consume same bytes

- Laravel release file SHA-256: `$phpSha`
- Dart input SHA-256: `$dartInputSha`
- Laravel manifest entry SHA-256: `$manifestSha`
- Exact release version: `${entry['version']}`
- HTTP harness: loopback only; exact manifest and release bytes served unchanged.
- DatasetSyncService import: PASS; Drift coverages: 12.
- Idempotent repeat: PASS; corrupt SHA and corrupt JSON retain last-good version and all 12 rows.
- R1 car/private regression and taxi coverage: PASS; 23/23 explicit taxi dates verified from the imported release.
- R2 taxi boundary/holiday/weekend checks and P1 known-empty cases: PASS.

| Case | Result |
|---|---|
${results.entries.map((item) => '| ${item.key} | ${item.value.name} |').join('\n')}
${taxiOutcomes.entries.map((item) => '| ${item.key} | ${item.value.name} |').join('\n')}
| P1 digits=null | ${_evaluateRule(allDayRule, plate: 'NO-PLATE').status.name} |
| P1 invalid plate with digits | ${_evaluateRule(filteredRule, plate: 'INVALID').status.name} |
| P1 fresh known-empty | allowed |
| P1 no coverage | unknown |
''');
      } finally {
        await server.close(force: true);
        await db.close();
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      }
    },
    skip:
        Platform.environment['PICORADAR_R2_EVIDENCE_DIR'] == null &&
            Platform.environment['PICORADAR_R1_EVIDENCE_DIR'] == null
        ? 'Run after Laravel publisher has exported the release bytes.'
        : null,
  );
}

RestrictionContext _context({
  required String plate,
  CoverageCompleteness coverageCompleteness = CoverageCompleteness.legacy,
}) => RestrictionContext(
  jurisdictionId: 'co-dc-bogota',
  plate: plate,
  vehicleKind: VehicleKind.car,
  serviceType: VehicleServiceType.private,
  registrationOrigin: RegistrationOrigin.unknown,
  localDateTime: DateTime(2026, 11, 9, 8),
  isHoliday: false,
  coverageKnown: true,
  dataIsStale: false,
  coverageCompleteness: coverageCompleteness,
);

RestrictionEvaluation _evaluateRule(
  RestrictionRule rule, {
  required String plate,
}) => const RestrictionEngine().evaluate(_context(plate: plate), [rule]);

RestrictionRule _rule({required Set<int>? digits}) => RestrictionRule(
  id: 'synthetic-negative-rule',
  jurisdictionId: 'co-dc-bogota',
  priority: 1000,
  effect: RestrictionEffect.restrict,
  validFrom: DateTime(2026, 11, 1),
  validUntil: DateTime(2026, 11, 30, 23, 59),
  vehicleKinds: {VehicleKind.car},
  serviceTypes: {VehicleServiceType.private},
  weekdays: {DateTime.monday},
  dateParity: RestrictionDateParity.odd,
  digitPosition: RestrictionDigitPosition.lastNumeric,
  digits: digits,
  timeWindows: const [RestrictionTimeWindow(startMinute: 360, endMinute: 1260)],
  appliesOnHolidays: false,
);

String _negativeManifest({
  required String version,
  required int revision,
  required String url,
  required String sha256,
}) => jsonEncode({
  'schemaVersion': 1,
  'generatedAt': '2026-11-09T22:14:52Z',
  'minAppVersion': '1.0.0',
  'datasets': {
    'restrictions': {
      'version': version,
      'url': url,
      'sha256': sha256,
      'publicationRevision': revision,
    },
  },
  'features': <String, bool>{},
});

Future<String> _sha256(List<int> bytes) async {
  final digest = await Sha256().hash(bytes);
  return digest.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}

class _MemoryPreferences implements AppPreferences {
  final values = <String, Object?>{};
  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;
  @override
  Future<int?> getInt(String key) async => values[key] as int?;
  @override
  Future<String?> getString(String key) async => values[key] as String?;
  @override
  Future<void> remove(String key) async => values.remove(key);
  @override
  Future<void> setBool(String key, bool value) async {
    values[key] = value;
  }

  @override
  Future<void> setInt(String key, int value) async {
    values[key] = value;
  }

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}
