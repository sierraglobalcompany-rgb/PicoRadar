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
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';
import 'package:picoradar/features/pico_placa/domain/colombia_holiday_calendar.dart';
import 'package:picoradar/features/pico_placa/data/restriction_dataset.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_engine.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_rule.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  test('imports the exact Laravel G1 lab bytes and retains last-good data', () async {
    final evidenceDirectory = Platform.environment['PICORADAR_G1_EVIDENCE_DIR'];
    if (evidenceDirectory == null || evidenceDirectory.isEmpty) {
      throw StateError(
        'PICORADAR_G1_EVIDENCE_DIR is required; this E2E must not be skipped.',
      );
    }
    final r2EvidenceDirectory =
        Platform.environment['PICORADAR_R2_EVIDENCE_DIR'];
    if (r2EvidenceDirectory == null || r2EvidenceDirectory.isEmpty) {
      throw StateError(
        'PICORADAR_R2_EVIDENCE_DIR is required to compare the lab engine output with R2.',
      );
    }
    final releaseBytes = await File(
      '$evidenceDirectory${Platform.pathSeparator}LARAVEL_REAL_LAB_RELEASE.json',
    ).readAsBytes();
    final originalManifestBytes = await File(
      '$evidenceDirectory${Platform.pathSeparator}LARAVEL_REAL_LAB_MANIFEST.json',
    ).readAsBytes();
    final phpResult = jsonDecode(
      await File(
        '$evidenceDirectory${Platform.pathSeparator}PHP_G1_LAB_RESULT.json',
      ).readAsString(),
    ) as Map<String, dynamic>;
    final baselineBytes = await File(
      '$r2EvidenceDirectory${Platform.pathSeparator}ACTUAL_R2_LARAVEL_RELEASE.json',
    ).readAsBytes();
    final sourceBogota = jsonDecode(
      await File(
        '$evidenceDirectory${Platform.pathSeparator}SOURCE_BOGOTA_EDITORIAL.json',
      ).readAsString(),
    ) as Map<String, dynamic>;
    final bogotaVariant = jsonDecode(
      await File(
        '$evidenceDirectory${Platform.pathSeparator}BOGOTA_SYNTHETIC_VARIANT_ONLY.json',
      ).readAsString(),
    ) as Map<String, dynamic>;
    final popayanVariant = jsonDecode(
      await File(
        '$evidenceDirectory${Platform.pathSeparator}SECOND_CITY_SYNTHETIC_ONLY.json',
      ).readAsString(),
    ) as Map<String, dynamic>;
    final manifest =
        jsonDecode(utf8.decode(originalManifestBytes)) as Map<String, dynamic>;
    final entry =
        (manifest['datasets'] as Map<String, dynamic>)['restrictions']
            as Map<String, dynamic>;
    final phpSha = await _sha256(releaseBytes);
    final manifestSha = entry['sha256'] as String;
    expect(phpSha, manifestSha);
    expect(await _sha256(baselineBytes), phpResult['baselineR2Sha256']);
    expect(phpResult['releaseSha256'], phpSha);
    expect(phpResult['manifestReleaseSha256'], manifestSha);

    final release =
        jsonDecode(utf8.decode(releaseBytes)) as Map<String, dynamic>;
    expect(release['version'], entry['version']);
    expect(release['datasetKey'], 'restrictions');

    final database = AppDatabase(NativeDatabase.memory());
    AppDatabase? baselineDatabase;
    final tempDirectory = await Directory.systemTemp.createTemp(
      'picoradar_g1_same_bytes_',
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    List<int> servedRelease = releaseBytes;
    List<int> manifestBytes = originalManifestBytes;
    final servedReleaseHashes = <String>[];
    final releasePath = Uri.parse(entry['url'] as String).path;
    server.listen((request) async {
      try {
        if (request.uri.path == '/v1/manifest.json') {
          request.response.headers.contentType = ContentType.json;
          request.response.add(manifestBytes);
        } else if (request.uri.path == releasePath) {
          servedReleaseHashes.add(await _sha256(servedRelease));
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
        database: database,
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
        now: () => DateTime.parse(manifest['generatedAt'] as String).toUtc(),
      );

      final imported = await service.sync();
      expect(imported.imported, ['restrictions']);
      expect(servedReleaseHashes.single, phpSha);
      final coverages = await database
          .select(database.restrictionCoverages)
          .get();
      expect(coverages, hasLength(12));
      final installed =
          (await database.select(database.datasetVersions).get()).single;
      expect(installed.version, entry['version']);
      expect(installed.sha256, manifestSha);
      expect(await _sha256(releaseBytes), manifestSha);

      final originalCoverageIds = coverages.map((row) => row.id).toSet();
      final baselinePayload =
          jsonDecode(utf8.decode(baselineBytes)) as Map<String, dynamic>;
      baselineDatabase = AppDatabase(NativeDatabase.memory());
      await importRestrictionsDataset(baselineDatabase, baselinePayload);
      final engineOutcomes = await _evaluateDataVariants(
        baselineDatabase: baselineDatabase,
        labDatabase: database,
        baselinePayload: baselinePayload,
        sourceBogota: sourceBogota,
        bogotaVariant: bogotaVariant,
        popayanVariant: popayanVariant,
      );

      manifestBytes = _manifestVariant(
        manifest,
        version: 'r3-bad-sha',
        publicationRevision: 3,
        sha256: '0' * 64,
      );
      servedRelease = releaseBytes;
      await expectLater(service.sync(), throwsA(isA<DatasetSyncException>()));
      await _expectLastGood(
        database,
        installed.version,
        installed.sha256!,
        originalCoverageIds,
      );

      final corruptJson = utf8.encode(
        '{"schemaVersion":1,"datasetKey":"restrictions","jurisdictions":[',
      );
      manifestBytes = _manifestVariant(
        manifest,
        version: 'r3-corrupt-json',
        publicationRevision: 3,
        sha256: await _sha256(corruptJson),
      );
      servedRelease = corruptJson;
      await expectLater(service.sync(), throwsA(isA<DatasetSyncException>()));
      await _expectLastGood(
        database,
        installed.version,
        installed.sha256!,
        originalCoverageIds,
      );

      manifestBytes = originalManifestBytes;
      servedRelease = releaseBytes;
      final repeated = await service.sync();
      expect(repeated.skippedCurrent, ['restrictions']);
      expect(
        await database.select(database.restrictionCoverages).get(),
        hasLength(12),
      );

      final dartInputSha = await _sha256(servedRelease);
      final report = File(
        '$evidenceDirectory${Platform.pathSeparator}FLUTTER_SAME_BYTES.md',
      );
      await report.writeAsString(
        '''# Flutter consumes the Laravel G1 lab release

- Classification: `LAB_SYNTHETIC_NOT_FOR_RELEASE`.
- R2 baseline SHA-256: `${phpResult['baselineR2Sha256']}`.
- Laravel release SHA-256: `$phpSha`.
- Manifest entry SHA-256: `$manifestSha`.
- SHA-256 of bytes served over loopback and checked by DatasetSyncService: `$dartInputSha`.
- Imported Drift coverages: ${coverages.length}.
- Release version: `${entry['version']}`; publication revision: ${entry['publicationRevision']}.
- Bad SHA retained the installed version, hash, and all 12 coverage rows: PASS.
- Malformed JSON with matching SHA retained the installed version, hash, and all 12 coverage rows: PASS.
- Restored manifest repeated idempotently: PASS.
- Bogotá engine output changed by the synthetic digit data only: baseline old/new digits `${engineOutcomes['bogotaBaselineOldDigit']}/${engineOutcomes['bogotaBaselineNewDigit']}` -> `${engineOutcomes['bogotaLabOldDigit']}/${engineOutcomes['bogotaLabNewDigit']}`.
- Popayán fixed-time test used fresh synthetic metadata; baseline status `${engineOutcomes['popayanBaselineStatus']}`, synthetic old/new digits `${engineOutcomes['popayanLabOldDigit']}/${engineOutcomes['popayanLabNewDigit']}`.
- Fixed test clock: `${engineOutcomes['testNowUtc']}`; dates were selected from the input rule conditions.
- Network scope: HTTP loopback only; manifest and dataset bytes served from local evidence files.
- Flutter unit-test result: PASS; zero skipped tests in this file.
''',
      );
      expect(await report.exists(), isTrue);
    } finally {
      await server.close(force: true);
      await database.close();
      await baselineDatabase?.close();
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    }
  });
}

Future<Map<String, String>> _evaluateDataVariants({
  required AppDatabase baselineDatabase,
  required AppDatabase labDatabase,
  required Map<String, dynamic> baselinePayload,
  required Map<String, dynamic> sourceBogota,
  required Map<String, dynamic> bogotaVariant,
  required Map<String, dynamic> popayanVariant,
}) async {
  final fixedNowUtc = DateTime.utc(2026, 11, 10, 13);
  final bogotaBefore = _coverage(
    _city(sourceBogota, 'co-dc-bogota'),
    'car',
    'private',
  );
  final bogotaAfter = _coverage(
    _city(bogotaVariant, 'co-dc-bogota'),
    'car',
    'private',
  );
  final bogotaRulePair = _changedDigitRule(bogotaBefore, bogotaAfter);
  final bogotaRuleDate = _firstApplicableDate(
    bogotaRulePair['before']!,
    DateTime(2026, 11, 1),
    DateTime(2026, 11, 10),
  );
  final bogotaOldDigit =
      (bogotaRulePair['before']!['digits'] as List<dynamic>).first as int;
  final bogotaNewDigit =
      (bogotaRulePair['after']!['digits'] as List<dynamic>).first as int;
  final bogotaBaselineOld = await _evaluatePlate(
    baselineDatabase,
    'co-dc-bogota',
    'ABC12$bogotaOldDigit',
    bogotaRuleDate,
    fixedNowUtc,
  );
  final bogotaLabOld = await _evaluatePlate(
    labDatabase,
    'co-dc-bogota',
    'ABC12$bogotaOldDigit',
    bogotaRuleDate,
    fixedNowUtc,
  );
  final bogotaBaselineNew = await _evaluatePlate(
    baselineDatabase,
    'co-dc-bogota',
    'ABC12$bogotaNewDigit',
    bogotaRuleDate,
    fixedNowUtc,
  );
  final bogotaLabNew = await _evaluatePlate(
    labDatabase,
    'co-dc-bogota',
    'ABC12$bogotaNewDigit',
    bogotaRuleDate,
    fixedNowUtc,
  );
  expect(bogotaBaselineOld, RestrictionStatus.restricted);
  expect(bogotaLabOld, RestrictionStatus.allowed);
  expect(bogotaBaselineNew, RestrictionStatus.allowed);
  expect(bogotaLabNew, RestrictionStatus.restricted);

  final baselinePopayan = _city(baselinePayload, 'co-cau-popayan');
  final popayanBefore = _coverage(baselinePopayan, 'car', 'private');
  final popayanAfter = _coverage(
    _city(popayanVariant, 'co-cau-popayan'),
    'car',
    'private',
  );
  final popayanRulePair = _changedDigitRule(popayanBefore, popayanAfter);
  final popayanRuleDate = _firstApplicableDate(
    popayanRulePair['before']!,
    DateTime(2026, 11, 1),
    DateTime(2026, 11, 10),
  );
  final popayanOldDigit =
      (popayanRulePair['before']!['digits'] as List<dynamic>).first as int;
  final popayanNewDigit =
      (popayanRulePair['after']!['digits'] as List<dynamic>).first as int;
  final baselinePopayanCoverage = await RestrictionStore(baselineDatabase)
      .loadCoverage(
        'co-cau-popayan',
        VehicleKind.car,
        VehicleServiceType.private,
        fixedNowUtc,
      );
  final labPopayanCoverage = await RestrictionStore(labDatabase).loadCoverage(
    'co-cau-popayan',
    VehicleKind.car,
    VehicleServiceType.private,
    fixedNowUtc,
  );
  expect(baselinePopayanCoverage.dataIsStale, isTrue);
  expect(labPopayanCoverage.dataIsStale, isFalse);
  final popayanBaseline = _evaluateLoadedCoverage(
    baselinePopayanCoverage,
    'co-cau-popayan',
    'ABC12$popayanOldDigit',
    popayanRuleDate,
  );
  final popayanLabOld = _evaluateLoadedCoverage(
    labPopayanCoverage,
    'co-cau-popayan',
    'ABC12$popayanOldDigit',
    popayanRuleDate,
  );
  final popayanLabNew = _evaluateLoadedCoverage(
    labPopayanCoverage,
    'co-cau-popayan',
    'ABC12$popayanNewDigit',
    popayanRuleDate,
  );
  expect(popayanBaseline, RestrictionStatus.stale);
  expect(popayanLabOld, RestrictionStatus.allowed);
  expect(popayanLabNew, RestrictionStatus.restricted);

  return {
    'bogotaBaselineOldDigit': bogotaBaselineOld.name,
    'bogotaBaselineNewDigit': bogotaBaselineNew.name,
    'bogotaLabOldDigit': bogotaLabOld.name,
    'bogotaLabNewDigit': bogotaLabNew.name,
    'popayanBaselineStatus': popayanBaseline.name,
    'popayanLabOldDigit': popayanLabOld.name,
    'popayanLabNewDigit': popayanLabNew.name,
    'testNowUtc': fixedNowUtc.toIso8601String(),
  };
}

Map<String, dynamic> _city(Map<String, dynamic> payload, String id) =>
    (payload['jurisdictions'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .firstWhere((city) => city['id'] == id);

Map<String, dynamic> _coverage(
  Map<String, dynamic> city,
  String vehicleKind,
  String serviceType,
) => (city['coverages'] as List<dynamic>)
    .cast<Map<String, dynamic>>()
    .firstWhere(
      (coverage) =>
          coverage['vehicleKind'] == vehicleKind &&
          coverage['serviceType'] == serviceType,
    );

Map<String, Map<String, dynamic>> _changedDigitRule(
  Map<String, dynamic> before,
  Map<String, dynamic> after,
) {
  final oldRules = <String, Map<String, dynamic>>{};
  for (final rule
      in (before['rules'] as List<dynamic>).cast<Map<String, dynamic>>()) {
    oldRules[rule['id'] as String] = rule;
  }
  final newRules = <String, Map<String, dynamic>>{};
  for (final rule
      in (after['rules'] as List<dynamic>).cast<Map<String, dynamic>>()) {
    newRules[rule['id'] as String] = rule;
  }
  for (final entry in oldRules.entries) {
    final next = newRules[entry.key];
    if (next != null &&
        jsonEncode(entry.value['digits']) != jsonEncode(next['digits'])) {
      return {'before': entry.value, 'after': next};
    }
  }
  throw StateError('The synthetic variant did not change a rule digit list.');
}

DateTime _firstApplicableDate(
  Map<String, dynamic> rule,
  DateTime earliest,
  DateTime latest,
) {
  final from = (rule['validFrom'] as String).substring(0, 10);
  final until = (rule['validUntil'] as String).substring(0, 10);
  final weekdays = (rule['weekdays'] as List<dynamic>?)?.cast<int>();
  final parity = rule['dateParity'] as String?;
  final windows = (rule['timeWindows'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final startMinute = windows.isEmpty
      ? 480
      : windows.first['startMinute'] as int;

  for (
    var date = DateTime(earliest.year, earliest.month, earliest.day);
    !date.isAfter(latest);
    date = date.add(const Duration(days: 1))
  ) {
    final isoDate =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    if (isoDate.compareTo(from) < 0 || isoDate.compareTo(until) > 0) {
      continue;
    }
    if (weekdays != null && !weekdays.contains(date.weekday)) {
      continue;
    }
    if (parity == 'odd' && date.day.isEven ||
        parity == 'even' && date.day.isOdd) {
      continue;
    }
    if (rule['appliesOnHolidays'] == false &&
        const ColombiaHolidayCalendar().isHoliday(date)) {
      continue;
    }
    final minute = (startMinute + 1).clamp(0, 1439);
    return DateTime(date.year, date.month, date.day, minute ~/ 60, minute % 60);
  }
  throw StateError('No eligible date found inside the fixed G1 test interval.');
}

Future<RestrictionStatus> _evaluatePlate(
  AppDatabase database,
  String jurisdictionId,
  String plate,
  DateTime localDateTime,
  DateTime nowUtc,
) async {
  final coverage = await RestrictionStore(database).loadCoverage(
    jurisdictionId,
    VehicleKind.car,
    VehicleServiceType.private,
    nowUtc,
  );
  return _evaluateLoadedCoverage(
    coverage,
    jurisdictionId,
    plate,
    localDateTime,
  );
}

RestrictionStatus _evaluateLoadedCoverage(
  RestrictionRuleSet coverage,
  String jurisdictionId,
  String plate,
  DateTime localDateTime,
) => const RestrictionEngine()
    .evaluate(
      RestrictionContext(
        jurisdictionId: jurisdictionId,
        plate: plate,
        vehicleKind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
        registrationOrigin: RegistrationOrigin.unknown,
        localDateTime: localDateTime,
        isHoliday: const ColombiaHolidayCalendar().isHoliday(localDateTime),
        coverageKnown: coverage.coverageKnown,
        dataIsStale: coverage.dataIsStale,
      ),
      coverage.rules,
    )
    .status;

Future<void> _expectLastGood(
  AppDatabase database,
  String version,
  String sha256,
  Set<String> coverageIds,
) async {
  final installed =
      (await database.select(database.datasetVersions).get()).single;
  expect(installed.version, version);
  expect(installed.sha256, sha256);
  expect(
    (await database.select(database.restrictionCoverages).get())
        .map((row) => row.id)
        .toSet(),
    coverageIds,
  );
}

List<int> _manifestVariant(
  Map<String, dynamic> original, {
  required String version,
  required int publicationRevision,
  required String sha256,
}) {
  final manifest = jsonDecode(jsonEncode(original)) as Map<String, dynamic>;
  final datasets = manifest['datasets'] as Map<String, dynamic>;
  final entry = datasets['restrictions'] as Map<String, dynamic>;
  entry['version'] = version;
  entry['publicationRevision'] = publicationRevision;
  entry['sha256'] = sha256;
  return utf8.encode(jsonEncode(manifest));
}

Future<String> _sha256(List<int> bytes) async {
  final digest = await Sha256().hash(bytes);
  return digest.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}

class _MemoryPreferences implements AppPreferences {
  final _values = <String, Object?>{};

  @override
  Future<bool?> getBool(String key) async => _values[key] as bool?;

  @override
  Future<int?> getInt(String key) async => _values[key] as int?;

  @override
  Future<String?> getString(String key) async => _values[key] as String?;

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> setBool(String key, bool value) async {
    _values[key] = value;
  }

  @override
  Future<void> setInt(String key, int value) async {
    _values[key] = value;
  }

  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }
}
