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
import 'package:picoradar/features/pico_placa/domain/restriction_day_evaluation.dart';
import 'package:picoradar/features/trip/data/trip_municipality_catalog.dart';

const _qaNow = '2026-11-13T14:00:00Z';
const _v5FixturePath =
    'test/fixtures/restrictions_lab_v5_combined_2026-11-12.json';
const _v6r3FixturePath =
    '../server/database/data/restrictions/lab/national_bulk_v6r3_2026-11-12.json';
const _v6r3HashPath =
    '../server/database/data/restrictions/lab/national_bulk_v6r3_2026-11-12.sha256';
const _v6r4FixturePath =
    '../server/database/data/restrictions/lab/national_bulk_v6r4_2026-11-13.json';
const _v6r4HashPath =
    '../server/database/data/restrictions/lab/national_bulk_v6r4_2026-11-13.sha256';
const _tripCatalogPath = 'assets/catalogs/colombia_trip_municipalities_v1.json';

void main() {
  test('OTA V5 to V6R3 to V6R4 replaces atomically and retains last-good on bad SHA', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'picoradar_v6r4_ota_',
    );
    final databaseFile = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}qa-only.sqlite',
    );
    AppDatabase? database = AppDatabase(NativeDatabase(databaseFile));
    final preferences = _MemoryPreferences();
    final syncTemp = await Directory.systemTemp.createTemp(
      'picoradar_v6r4_sync_',
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final v5Bytes = await File(_v5FixturePath).readAsBytes();
    final v6r3Bytes = await File(_v6r3FixturePath).readAsBytes();
    final v6r4Bytes = await File(_v6r4FixturePath).readAsBytes();
    final v5Sha = await _sha256(v5Bytes);
    final v6r3HashText = (await File(_v6r3HashPath).readAsString()).trim();
    final v6r3Sha = v6r3HashText.split(RegExp(r'\s+')).first.toLowerCase();
    final v6r4HashText = (await File(_v6r4HashPath).readAsString()).trim();
    final v6r4Sha = v6r4HashText.split(RegExp(r'\s+')).first.toLowerCase();
    expect(await _sha256(v6r3Bytes), v6r3Sha);
    expect(await _sha256(v6r4Bytes), v6r4Sha);

    const v5Path = '/v1/datasets/v5-calendar-combined.json';
    const v6r3Path = '/v1/datasets/v6r3-national-bulk.json';
    const v6r4Path = '/v1/datasets/v6r4-national-registry.json';
    var manifestBytes = _manifestBytes(
      version: 'LAB-V5-CALENDAR-COMBINED-20261112-01',
      sha256: v5Sha,
      publicationRevision: 1,
      url: v5Path,
    );
    final servedReleaseHashes = <String, List<String>>{};
    final subscription = server.listen((request) async {
      final bytes = switch (request.uri.path) {
        '/v1/manifest.json' => manifestBytes,
        v5Path => v5Bytes,
        v6r3Path => v6r3Bytes,
        v6r4Path => v6r4Bytes,
        _ => null,
      };
      if (bytes == null) {
        request.response.statusCode = HttpStatus.notFound;
      } else {
        request.response.headers.contentType = ContentType.json;
        request.response.headers.contentLength = bytes.length;
        if (request.uri.path == v5Path ||
            request.uri.path == v6r3Path ||
            request.uri.path == v6r4Path) {
          servedReleaseHashes
              .putIfAbsent(request.uri.path, () => <String>[])
              .add(await _sha256(bytes));
        }
        request.response.add(bytes);
      }
      await request.response.close();
    });

    try {
      await database
          .into(database.vehicles)
          .insert(VehiclesCompanion.insert(id: 'qa-garage', plate: 'QA123'));
      await database
          .into(database.notificationPreferences)
          .insert(
            NotificationPreferencesCompanion.insert(id: 'qa-notifications'),
          );

      final service = DatasetSyncService(
        database: database,
        preferences: preferences,
        config: AppConfig(cdnBaseUrl: 'http://127.0.0.1:${server.port}/'),
        importers: {restrictionsDatasetKey: importRestrictionsDataset},
        http: Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 3),
            receiveTimeout: const Duration(seconds: 5),
          ),
        ),
        tempDirectory: syncTemp,
        currentAppVersion: '1.0.1',
        now: () => DateTime.utc(2026, 11, 13, 14),
      );

      final v5Result = await service.sync();
      expect(v5Result.imported, ['restrictions']);
      expect(servedReleaseHashes[v5Path], [v5Sha]);
      final v5Rows = await database.select(database.restrictionCoverages).get();
      expect(v5Rows, hasLength(3));
      final v5Rules = [
        for (final row in v5Rows) ...(jsonDecode(row.rulesJson) as List),
      ];
      expect(v5Rules, hasLength(15));
      final v5Version = await database
          .select(database.datasetVersions)
          .getSingle();
      expect(v5Version.version, 'LAB-V5-CALENDAR-COMBINED-20261112-01');
      expect(v5Version.sha256, v5Sha);
      expect(v5Version.publicationRevision, 1);

      final v6r3Version =
          jsonDecode(utf8.decode(v6r3Bytes))['version'] as String;
      manifestBytes = _manifestBytes(
        version: v6r3Version,
        sha256: v6r3Sha,
        publicationRevision: 2,
        url: v6r3Path,
      );
      final v6r3Result = await service.sync();
      expect(v6r3Result.imported, ['restrictions']);
      expect(servedReleaseHashes[v6r3Path], [v6r3Sha]);
      final v6r3Rows = await database
          .select(database.restrictionCoverages)
          .get();
      expect(v6r3Rows, hasLength(19));
      final v6r3Rules = [
        for (final row in v6r3Rows) ...(jsonDecode(row.rulesJson) as List),
      ];
      expect(v6r3Rules, hasLength(105));
      final v6r3Jurisdictions = await RestrictionStore(database)
          .listJurisdictions();
      expect(v6r3Jurisdictions, hasLength(13));
      final v6r3VersionRow = await database
          .select(database.datasetVersions)
          .getSingle();
      expect(v6r3VersionRow.version, v6r3Version);
      expect(v6r3VersionRow.sha256, v6r3Sha);
      expect(v6r3VersionRow.publicationRevision, 2);

      final v6r4Version =
          jsonDecode(utf8.decode(v6r4Bytes))['version'] as String;
      manifestBytes = _manifestBytes(
        version: v6r4Version,
        sha256: v6r4Sha,
        publicationRevision: 3,
        url: v6r4Path,
      );
      final v6r4Result = await service.sync();
      expect(v6r4Result.imported, ['restrictions']);
      expect(servedReleaseHashes[v6r4Path], [v6r4Sha]);
      final v6r4Rows = await database
          .select(database.restrictionCoverages)
          .get();
      expect(v6r4Rows, hasLength(21));
      final v6r4Rules = [
        for (final row in v6r4Rows) ...(jsonDecode(row.rulesJson) as List),
      ];
      expect(v6r4Rules, hasLength(115));
      final v6r4Jurisdictions = await RestrictionStore(database)
          .listJurisdictions();
      expect(v6r4Jurisdictions, hasLength(14));
      expect(
        v6r4Jurisdictions
            .map((item) => item.municipalityCodes!)
            .expand((codes) => codes),
        hasLength(33),
      );
      final dosquebradas = v6r4Jurisdictions.singleWhere(
        (item) => item.id == 'co-ris-dosquebradas',
      );
      expect(dosquebradas.municipalityCodes, ['66170']);
      final preservedVehicle = await database
          .select(database.vehicles)
          .getSingle();
      expect(preservedVehicle.plate, 'QA123');
      expect(
        (await database.select(database.notificationPreferences).getSingle())
            .id,
        'qa-notifications',
      );
      final currentVersion = await database
          .select(database.datasetVersions)
          .getSingle();
      expect(currentVersion.version, v6r4Version);
      expect(currentVersion.sha256, v6r4Sha);
      expect(currentVersion.publicationRevision, 3);

      manifestBytes = _manifestBytes(
        version: 'LAB-V6R4-BAD-SHA',
        sha256: '0' * 64,
        publicationRevision: 4,
        url: v6r4Path,
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
      expect(retainedVersion.version, v6r4Version);
      expect(retainedVersion.sha256, v6r4Sha);
      expect(retainedVersion.publicationRevision, 3);
      expect(
        await database.select(database.restrictionCoverages).get(),
        hasLength(21),
      );
      expect(await database.select(database.vehicles).get(), hasLength(1));
      expect(
        (await database.select(database.notificationPreferences).getSingle())
            .id,
        'qa-notifications',
      );

      await database.close();
      database = null;
      database = AppDatabase(NativeDatabase(databaseFile));
      final reopenedVersion = await database
          .select(database.datasetVersions)
          .getSingle();
      expect(reopenedVersion.version, v6r4Version);
      expect(reopenedVersion.sha256, v6r4Sha);
      expect(reopenedVersion.publicationRevision, 3);
      final reopenedRows = await database
          .select(database.restrictionCoverages)
          .get();
      expect(reopenedRows, hasLength(21));
      expect(
        await RestrictionStore(database).listJurisdictions(),
        hasLength(14),
      );
      expect(await database.select(database.vehicles).get(), hasLength(1));
      expect(
        (await database.select(database.notificationPreferences).getSingle())
            .id,
        'qa-notifications',
      );
      stdout.writeln(
        'TEST_EVIDENCE V6R4_OTA '
        'v5_sha=$v5Sha v6r3_sha=$v6r3Sha v6r4_sha=$v6r4Sha '
        'v5=2j/3c/15r v6r3=13j/19c/105r v6r4=14j/33codes/21c/115r '
        'revision=3 '
        'bad_sha_rejected=true reopened=true garage_preserved=true '
        'notification_preferences_preserved=true',
      );
    } finally {
      await subscription.cancel();
      await server.close(force: true);
      await database?.close();
      if (await syncTemp.exists()) await syncTemp.delete(recursive: true);
      for (final path in [
        databaseFile.path,
        '${databaseFile.path}-journal',
        '${databaseFile.path}-wal',
        '${databaseFile.path}-shm',
      ]) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    }
  });

  test(
    'Drift, Trip projection, and coverage freshness use real data',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      try {
        final snapshot = jsonDecode(
          await File(_v6r4FixturePath).readAsString(),
        ) as Map<String, dynamic>;
        await importRestrictionsDataset(
          database,
          snapshot,
          now: () => DateTime.utc(2026, 11, 13, 14),
        );
        final store = RestrictionStore(database);
        final jurisdictions = await store.listJurisdictions();
        expect(jurisdictions, hasLength(14));
        expect(
          jurisdictions.map((item) => item.municipalityCodes!).expand((e) => e),
          hasLength(33),
        );

        final catalogJson = jsonDecode(
          await File(_tripCatalogPath).readAsString(),
        ) as Map<String, Object?>;
        final catalog = TripMunicipalityCatalog.fromJson(catalogJson);
        final tripCatalog = catalog.withRestrictionAvailability([
          for (final jurisdiction in jurisdictions)
            TripRestrictionAvailability(
              jurisdictionId: jurisdiction.id,
              municipalityCodes: jurisdiction.municipalityCodes!,
              consultationEnabled: jurisdiction.consultationEnabled!,
            ),
        ]);
        final expectedCodes = {
          '05360': 'co-ant-itagui',
          '68276': 'co-san-floridablanca',
          '05001': 'co-ant-medellin',
          '66001': 'co-ris-pereira',
          '66170': 'co-ris-dosquebradas',
          '08078': 'co-atl-transito-departamental',
          '08433': 'co-atl-transito-departamental',
        };
        for (final entry in expectedCodes.entries) {
          final municipality = tripCatalog.findByCode(entry.key);
          expect(municipality, isNotNull, reason: entry.key);
          expect(municipality!.jurisdictionId, entry.value, reason: entry.key);
          expect(municipality.jurisdictionMappingAmbiguous, isFalse);
        }
        final atlantico = jurisdictions.singleWhere(
          (item) => item.id == 'co-atl-transito-departamental',
        );
        expect(atlantico.municipalityCodes, hasLength(20));
        for (final code in atlantico.municipalityCodes!) {
          final municipality = tripCatalog.findByCode(code);
          expect(municipality, isNotNull, reason: 'DIVIPOLA $code');
          expect(
            municipality!.jurisdictionId,
            'co-atl-transito-departamental',
            reason: 'DIVIPOLA $code',
          );
        }
        final dosquebradasMunicipality = tripCatalog.findByCode('66170');
        expect(dosquebradasMunicipality, isNotNull);
        expect(dosquebradasMunicipality!.jurisdictionId, 'co-ris-dosquebradas');
        expect(dosquebradasMunicipality.jurisdictionMappingAmbiguous, isFalse);

        final itagui = await store.loadCoverage(
          'co-ant-itagui',
          VehicleKind.car,
          VehicleServiceType.private,
          DateTime.utc(2026, 11, 13, 14),
        );
        expect(itagui.coverageKnown, isTrue);
        expect(itagui.dataIsStale, isFalse);
        final thursday = DateTime(2026, 11, 12);
        final itaguiCalendar = summarizeCityRestrictionDay(
          ruleSet: itagui,
          jurisdictionId: 'co-ant-itagui',
          category: PicoVehicleCategory.cars,
          date: thursday,
        );
        expect(itaguiCalendar.status, RestrictionDayStatus.unknown);
        expect(itaguiCalendar.publishedScheduleInformational, isTrue);
        expect(itaguiCalendar.restrictedDigits, [3, 6]);
        expect(itaguiCalendar.effectiveWindows.single.startMinute, 300);
        expect(itaguiCalendar.effectiveWindows.single.endMinute, 1200);
        final matchingPlate = evaluateRestrictionDay(
          ruleSet: itagui,
          jurisdictionId: 'co-ant-itagui',
          plate: 'ABC13',
          vehicleKind: VehicleKind.car,
          serviceType: VehicleServiceType.private,
          date: thursday,
        );
        expect(matchingPlate.status, RestrictionDayStatus.unknown);

        final dosquebradasCar = await store.loadCoverage(
          'co-ris-dosquebradas',
          VehicleKind.car,
          VehicleServiceType.private,
          DateTime.utc(2026, 11, 13, 14),
        );
        final dosquebradasFriday = summarizeCityRestrictionDay(
          ruleSet: dosquebradasCar,
          jurisdictionId: 'co-ris-dosquebradas',
          category: PicoVehicleCategory.cars,
          date: DateTime(2026, 11, 13),
        );
        expect(dosquebradasFriday.status, RestrictionDayStatus.unknown);
        expect(dosquebradasFriday.publishedScheduleInformational, isTrue);
        expect(dosquebradasFriday.restrictedDigits, [8, 9]);
        expect(dosquebradasFriday.effectiveWindows.single.startMinute, 360);
        expect(dosquebradasFriday.effectiveWindows.single.endMinute, 1200);
        final dosquebradasCoveredNovember18 = summarizeCityRestrictionDay(
          ruleSet: dosquebradasCar,
          jurisdictionId: 'co-ris-dosquebradas',
          category: PicoVehicleCategory.cars,
          date: DateTime(2026, 11, 18),
        );
        expect(
          dosquebradasCoveredNovember18.status,
          RestrictionDayStatus.unknown,
        );
        expect(
          dosquebradasCoveredNovember18.publishedScheduleInformational,
          isTrue,
        );
        final dosquebradasStaleNovember19 = summarizeCityRestrictionDay(
          ruleSet: dosquebradasCar,
          jurisdictionId: 'co-ris-dosquebradas',
          category: PicoVehicleCategory.cars,
          date: DateTime(2026, 11, 19),
        );
        expect(dosquebradasStaleNovember19.status, RestrictionDayStatus.stale);
        expect(
          dosquebradasStaleNovember19.publishedScheduleInformational,
          isFalse,
        );
        final dosquebradasMatchingCar = evaluateRestrictionDay(
          ruleSet: dosquebradasCar,
          jurisdictionId: 'co-ris-dosquebradas',
          plate: 'ABC18',
          vehicleKind: VehicleKind.car,
          serviceType: VehicleServiceType.private,
          date: DateTime(2026, 11, 13),
        );
        expect(dosquebradasMatchingCar.status, RestrictionDayStatus.unknown);
        final dosquebradasMotorcycle = await store.loadCoverage(
          'co-ris-dosquebradas',
          VehicleKind.motorcycle,
          VehicleServiceType.private,
          DateTime.utc(2026, 11, 13, 14),
        );
        final dosquebradasMatchingMotorcycle = evaluateRestrictionDay(
          ruleSet: dosquebradasMotorcycle,
          jurisdictionId: 'co-ris-dosquebradas',
          plate: '8ABC123',
          vehicleKind: VehicleKind.motorcycle,
          serviceType: VehicleServiceType.private,
          date: DateTime(2026, 11, 13),
        );
        expect(
          dosquebradasMatchingMotorcycle.status,
          RestrictionDayStatus.unknown,
        );

        final manizales = await store.loadCoverage(
          'co-cal-manizales',
          VehicleKind.car,
          VehicleServiceType.private,
          DateTime.utc(2026, 11, 13, 14),
        );
        final expiredManizales = summarizeCityRestrictionDay(
          ruleSet: manizales,
          jurisdictionId: 'co-cal-manizales',
          category: PicoVehicleCategory.cars,
          date: DateTime(2026, 12, 1),
        );
        expect(expiredManizales.status, RestrictionDayStatus.stale);
        expect(expiredManizales.publishedScheduleInformational, isFalse);
        final coveredItaguiNovember30 = summarizeCityRestrictionDay(
          ruleSet: itagui,
          jurisdictionId: 'co-ant-itagui',
          category: PicoVehicleCategory.cars,
          date: DateTime(2026, 11, 30),
        );
        expect(coveredItaguiNovember30.status, RestrictionDayStatus.unknown);
        expect(coveredItaguiNovember30.publishedScheduleInformational, isTrue);
        expect(coveredItaguiNovember30.restrictedDigits, [5, 8]);
        final expiredItaguiDecember1 = summarizeCityRestrictionDay(
          ruleSet: itagui,
          jurisdictionId: 'co-ant-itagui',
          category: PicoVehicleCategory.cars,
          date: DateTime(2026, 12, 1),
        );
        expect(expiredItaguiDecember1.status, RestrictionDayStatus.stale);
        expect(expiredItaguiDecember1.publishedScheduleInformational, isFalse);
      } finally {
        await database.close();
      }
    },
  );
}

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
