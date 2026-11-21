import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/config/app_config.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/core/storage/app_preferences.dart';
import 'package:picoradar/core/sync/dataset_sync_service.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/data/restriction_dataset.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';
import 'package:picoradar/features/pico_placa/domain/city_restriction_summary.dart';
import 'package:picoradar/features/pico_placa/domain/colombia_holiday_calendar.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_day_evaluation.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_rule.dart';

const _releasePath =
    'test/fixtures/restrictions_lab_v5_combined_2026-11-12.json';
const _releaseVersion = 'LAB-V5-CALENDAR-COMBINED-20261112-01';
const _qaNow = '2026-11-12T15:00:00Z';

void main() {
  test(
    'combined partial calendar persists in a real Drift file and stays UNKNOWN',
    () async {
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'picoradar_v5_drift_',
      );
      final databaseFile = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}qa-only.sqlite',
      );
      AppDatabase? database = AppDatabase(NativeDatabase(databaseFile));
      try {
        final releaseBytes = await File(_releasePath).readAsBytes();
        final release = Map<String, dynamic>.from(
          jsonDecode(utf8.decode(releaseBytes)) as Map,
        );
        await importRestrictionsDataset(
          database,
          release,
          now: () => DateTime.utc(2026, 11, 12, 16),
        );

        final initialRows = await database
            .select(database.restrictionCoverages)
            .get();
        expect(initialRows, hasLength(3));
        final initialSnapshot = initialRows.map(_coverageSnapshot).toList()
          ..sort();
        final initialRules = [
          for (final row in initialRows)
            ...(jsonDecode(row.rulesJson) as List).cast<Map<String, dynamic>>(),
        ];
        expect(initialRules, hasLength(15));
        expect(initialRules.map((rule) => rule['id']).toSet(), hasLength(15));
        expect(
          initialRows.map((row) => row.coverageCompleteness),
          everyElement('partial'),
        );

        final store = RestrictionStore(database);
        final jurisdictions = await store.listJurisdictions();
        expect(jurisdictions.map((item) => item.id).toSet(), {
          'co-vac-cali',
          'co-ris-pereira',
        });
        expect(
          {for (final item in jurisdictions) item.id: item.municipalityCodes},
          {
            'co-vac-cali': ['76001'],
            'co-ris-pereira': ['66001'],
          },
        );
        expect(
          jurisdictions.map((item) => item.consultationEnabled),
          everyElement(true),
        );

        final thursday = DateTime(2026, 11, 12);
        final cali = await store.loadCoverage(
          'co-vac-cali',
          VehicleKind.car,
          VehicleServiceType.private,
          DateTime.utc(2026, 11, 12, 15),
        );
        final caliDay = summarizeCityRestrictionDay(
          ruleSet: cali,
          jurisdictionId: 'co-vac-cali',
          category: PicoVehicleCategory.cars,
          date: thursday,
        );
        expect(cali.coverageCompleteness, CoverageCompleteness.partial);
        expect(caliDay.status, RestrictionDayStatus.unknown);
        expect(caliDay.publishedScheduleInformational, isTrue);
        expect(caliDay.restrictedDigits, [5, 6]);
        expect(caliDay.digitBasis, CityRestrictionDigitBasis.lastNumeric);
        expect(caliDay.effectiveWindows.single.startMinute, 360);
        expect(caliDay.effectiveWindows.single.endMinute, 1140);
        expect(caliDay.sourceUrl, startsWith('https://'));
        final personalCali = evaluateRestrictionDay(
          ruleSet: cali,
          jurisdictionId: 'co-vac-cali',
          plate: 'ABC56',
          vehicleKind: VehicleKind.car,
          serviceType: VehicleServiceType.private,
          date: thursday,
        );
        expect(personalCali.status, RestrictionDayStatus.unknown);

        final pereiraCar = await store.loadCoverage(
          'co-ris-pereira',
          VehicleKind.car,
          VehicleServiceType.private,
          DateTime.utc(2026, 11, 12, 15),
        );
        final pereiraDay = summarizeCityRestrictionDay(
          ruleSet: pereiraCar,
          jurisdictionId: 'co-ris-pereira',
          category: PicoVehicleCategory.cars,
          date: thursday,
        );
        expect(pereiraDay.status, RestrictionDayStatus.unknown);
        expect(pereiraDay.publishedScheduleInformational, isTrue);
        expect(pereiraDay.restrictedDigits, [6, 7]);
        expect(pereiraDay.effectiveWindows.single.startMinute, 360);
        expect(pereiraDay.effectiveWindows.single.endMinute, 1200);
        expect(pereiraDay.sourceUrl, startsWith('https://'));

        final pereiraMotorcycle = await store.loadCoverage(
          'co-ris-pereira',
          VehicleKind.motorcycle,
          VehicleServiceType.private,
          DateTime.utc(2026, 11, 12, 15),
        );
        final motorcycleDay = summarizeCityRestrictionDay(
          ruleSet: pereiraMotorcycle,
          jurisdictionId: 'co-ris-pereira',
          category: PicoVehicleCategory.motorcycles,
          date: thursday,
        );
        expect(motorcycleDay.status, RestrictionDayStatus.unknown);
        expect(motorcycleDay.publishedScheduleInformational, isTrue);
        expect(
          motorcycleDay.digitBasis,
          CityRestrictionDigitBasis.firstNumeric,
        );
        expect(motorcycleDay.restrictedDigits, [6, 7]);

        final uncoveredDay = summarizeCityRestrictionDay(
          ruleSet: cali,
          jurisdictionId: 'co-vac-cali',
          category: PicoVehicleCategory.cars,
          date: DateTime(2026, 11, 15),
        );
        expect(uncoveredDay.status, RestrictionDayStatus.unknown);
        expect(uncoveredDay.publishedScheduleInformational, isFalse);
        expect(uncoveredDay.restrictedDigits, isEmpty);

        const holidays = ColombiaHolidayCalendar();
        final holidayDate = DateTime(2026, 11, 2);
        expect(holidays.isHoliday(holidayDate), isTrue);
        final holidayDay = summarizeCityRestrictionDay(
          holidays: holidays,
          ruleSet: cali,
          jurisdictionId: 'co-vac-cali',
          category: PicoVehicleCategory.cars,
          date: holidayDate,
        );
        expect(holidayDay.status, RestrictionDayStatus.unknown);
        expect(holidayDay.publishedScheduleInformational, isFalse);

        final dosquebradas = await store.loadCoverage(
          'co-ris-dosquebradas',
          VehicleKind.car,
          VehicleServiceType.private,
          DateTime.utc(2026, 11, 12, 15),
        );
        expect(dosquebradas.coverageKnown, isFalse);
        final unsupported = summarizeCityRestrictionDay(
          ruleSet: dosquebradas,
          jurisdictionId: 'co-ris-dosquebradas',
          category: PicoVehicleCategory.cars,
          date: thursday,
        );
        expect(unsupported.status, RestrictionDayStatus.unknown);
        expect(unsupported.publishedScheduleInformational, isFalse);

        await database.close();
        database = null;
        database = AppDatabase(NativeDatabase(databaseFile));
        final reopenedRows = await database
            .select(database.restrictionCoverages)
            .get();
        final reopenedSnapshot = reopenedRows.map(_coverageSnapshot).toList()
          ..sort();
        expect(reopenedSnapshot, initialSnapshot);
        expect(reopenedRows, hasLength(3));
        final reopenedJurisdictions = await RestrictionStore(database)
            .listJurisdictions();
        expect(reopenedJurisdictions, hasLength(2));
        final reopenedPereira = await RestrictionStore(database).loadCoverage(
          'co-ris-pereira',
          VehicleKind.motorcycle,
          VehicleServiceType.private,
          DateTime.utc(2026, 11, 12, 15),
        );
        expect(reopenedPereira.rules, hasLength(5));
        expect(
          reopenedPereira.coverageCompleteness,
          CoverageCompleteness.partial,
        );

        stdout.writeln(
          'TEST_EVIDENCE V5_DRIFT_REOPEN '
          'release_sha=${await _sha256(releaseBytes)} '
          'jurisdictions=2 coverages=${reopenedRows.length} '
          'rules=${initialRules.length} cali=UNKNOWN pereira=UNKNOWN '
          'motorcycle_digit_basis=${motorcycleDay.digitBasis.name} '
          'holiday=UNKNOWN dosquebradas=UNKNOWN reopened=true',
        );
      } finally {
        await database?.close();
        for (final path in [
          databaseFile.path,
          '${databaseFile.path}-journal',
          '${databaseFile.path}-wal',
          '${databaseFile.path}-shm',
        ]) {
          final file = File(path);
          if (await file.exists()) await file.delete();
        }
        await temporaryDirectory.delete();
      }
    },
  );

  test(
    'loopback OTA imports exact combined bytes and preserves last-good data',
    () async {
      final releaseBytes = await File(_releasePath).readAsBytes();
      final release = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(releaseBytes)) as Map,
      );
      final releaseSha = await _sha256(releaseBytes);
      final database = AppDatabase(NativeDatabase.memory());
      final preferences = _MemoryPreferences();
      final syncTemp = await Directory.systemTemp.createTemp(
        'picoradar_v5_ota_',
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final datasetPath = '/v1/datasets/v5-calendar-combined.json';
      var manifestBytes = _manifestBytes(
        version: _releaseVersion,
        sha256: releaseSha,
        publicationRevision: 1,
        url: datasetPath,
      );
      final servedReleaseHashes = <String>[];
      final subscription = server.listen((request) async {
        final bytes = switch (request.uri.path) {
          '/v1/manifest.json' => manifestBytes,
          '/v1/datasets/v5-calendar-combined.json' => releaseBytes,
          _ => null,
        };
        if (bytes == null) {
          request.response.statusCode = HttpStatus.notFound;
        } else {
          request.response.headers.contentType = ContentType.json;
          request.response.headers.contentLength = bytes.length;
          if (request.uri.path == datasetPath) {
            servedReleaseHashes.add(await _sha256(bytes));
          }
          request.response.add(bytes);
        }
        await request.response.close();
      });

      try {
        await database
            .into(database.vehicles)
            .insert(
              VehiclesCompanion.insert(id: 'v5-qa-garage', plate: 'QA123'),
            );
        await database
            .into(database.notificationPreferences)
            .insert(
              NotificationPreferencesCompanion.insert(id: 'v5-qa-preferences'),
            );
        final baseUrl = 'http://127.0.0.1:${server.port}/';
        final service = DatasetSyncService(
          database: database,
          preferences: preferences,
          config: AppConfig(cdnBaseUrl: baseUrl),
          importers: {restrictionsDatasetKey: importRestrictionsDataset},
          http: Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 3),
              receiveTimeout: const Duration(seconds: 5),
            ),
          ),
          tempDirectory: syncTemp,
          currentAppVersion: '1.0.1',
          now: () => DateTime.utc(2026, 11, 12, 16),
        );

        final firstResult = await service.sync();
        expect(firstResult.imported, ['restrictions']);
        expect(servedReleaseHashes.single, releaseSha);
        expect(await _sha256(releaseBytes), releaseSha);
        final firstVersion = await database
            .select(database.datasetVersions)
            .getSingle();
        expect(firstVersion.datasetKey, 'restrictions');
        expect(firstVersion.version, release['version']);
        expect(firstVersion.sha256, releaseSha);
        expect(firstVersion.publicationRevision, 1);
        expect(
          await database.select(database.restrictionCoverages).get(),
          hasLength(3),
        );
        expect(await database.select(database.vehicles).get(), hasLength(1));
        expect(
          (await database.select(database.vehicles).getSingle()).plate,
          'QA123',
        );
        expect(
          (await database.select(database.notificationPreferences).getSingle())
              .id,
          'v5-qa-preferences',
        );

        manifestBytes = _manifestBytes(
          version: 'LAB-V5-CALENDAR-COMBINED-BAD-SHA',
          sha256: '0' * 64,
          publicationRevision: 2,
          url: datasetPath,
        );
        await expectLater(
          service.sync(),
          throwsA(
            isA<DatasetSyncException>().having(
              (error) => error.message,
              'message',
              contains('SHA-256 mismatch for restrictions'),
            ),
          ),
        );
        final retainedVersion = await database
            .select(database.datasetVersions)
            .getSingle();
        expect(retainedVersion.version, _releaseVersion);
        expect(retainedVersion.sha256, releaseSha);
        expect(retainedVersion.publicationRevision, 1);
        expect(
          await database.select(database.restrictionCoverages).get(),
          hasLength(3),
        );
        expect(
          (await database.select(database.vehicles).getSingle()).plate,
          'QA123',
        );
        expect(
          (await database.select(database.notificationPreferences).getSingle())
              .id,
          'v5-qa-preferences',
        );
        final loaded = await RestrictionStore(database).loadCoverage(
          'co-vac-cali',
          VehicleKind.car,
          VehicleServiceType.private,
          DateTime.utc(2026, 11, 12, 16),
        );
        expect(loaded.coverageCompleteness, CoverageCompleteness.partial);
        expect(
          summarizeCityRestrictionDay(
            ruleSet: loaded,
            jurisdictionId: 'co-vac-cali',
            category: PicoVehicleCategory.cars,
            date: DateTime(2026, 11, 12),
          ).status,
          RestrictionDayStatus.unknown,
        );
        stdout.writeln(
          'TEST_EVIDENCE V5_OTA_HTTP '
          'manifest_sha=$releaseSha response_sha=${servedReleaseHashes.first} '
          'db_sha=${retainedVersion.sha256} revision=1 '
          'first_import=1 invalid_sha_rejected=true garage_preserved=true '
          'preferences_preserved=true coverages=3 calendar=UNKNOWN',
        );
      } finally {
        await subscription.cancel();
        await server.close(force: true);
        await database.close();
        if (await syncTemp.exists()) await syncTemp.delete();
      }
    },
  );
}

String _coverageSnapshot(RestrictionCoverage row) =>
    '${row.id}|${row.jurisdictionName}|${row.rulesJson}|'
    '${row.verifiedAt.toUtc().toIso8601String()}|'
    '${row.staleAfter.toUtc().toIso8601String()}|${row.sourceUrlsJson}|'
    '${row.coverageCompleteness}';

List<int> _manifestBytes({
  required String version,
  required String sha256,
  required int publicationRevision,
  required String url,
}) => utf8.encode(
  '${jsonEncode({
    'schemaVersion': 1,
    'generatedAt': _qaNow,
    'minAppVersion': '1.0.0',
    'datasets': {
      'restrictions': {'version': version, 'url': url, 'sha256': sha256, 'publicationRevision': publicationRevision},
    },
    'features': <String, bool>{},
  })}\n',
);

Future<String> _sha256(List<int> bytes) async {
  final digest = await Sha256().hash(bytes);
  return digest.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}

class _MemoryPreferences implements AppPreferences {
  final Map<String, Object?> _values = {};

  @override
  Future<bool?> getBool(String key) async => _values[key] as bool?;

  @override
  Future<int?> getInt(String key) async => _values[key] as int?;

  @override
  Future<String?> getString(String key) async => _values[key] as String?;

  @override
  Future<void> setBool(String key, bool value) async => _values[key] = value;

  @override
  Future<void> setInt(String key, int value) async => _values[key] = value;

  @override
  Future<void> setString(String key, String value) async =>
      _values[key] = value;

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }
}
