// Opt-in only; this file is outside mobile/test auto-discovery.
// Requires the immutable PHP B1 export in PICORADAR_C29_B1_EXPORT_DIR.
// Run from mobile/: flutter test --no-pub qa/c29/national_ota_from_php_c29_test.dart
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
import 'package:picoradar/features/pico_placa/domain/restriction_day_evaluation.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_rule.dart';

void main() {
  test('imports immutable PHP B1 bytes and rejects a higher memory-only OTA before parsing', () async {
    final exportDirectory = Platform.environment['PICORADAR_C29_B1_EXPORT_DIR'];
    if (exportDirectory == null || exportDirectory.trim().isEmpty) {
      throw StateError(
        'PICORADAR_C29_B1_EXPORT_DIR is required; this opt-in test must not '
        'skip or synthesize the PHP export.',
      );
    }

    final separator = Platform.pathSeparator;
    final manifestFile = File('$exportDirectory${separator}manifest.json');
    final payloadFile = File('$exportDirectory${separator}restrictions.json');
    if (!await manifestFile.exists() || !await payloadFile.exists()) {
      throw StateError(
        'The immutable PHP B1 manifest.json and restrictions.json are required.',
      );
    }

    final manifestBytes = await manifestFile.readAsBytes();
    final payloadBytes = await payloadFile.readAsBytes();
    final manifest = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(manifestBytes)) as Map,
    );
    final datasets = Map<String, dynamic>.from(manifest['datasets'] as Map);
    expect(datasets.keys, {restrictionsDatasetKey});
    final positiveEntry = Map<String, dynamic>.from(
      datasets[restrictionsDatasetKey] as Map,
    );
    final expectedSha256 = (positiveEntry['sha256'] as String).toLowerCase();
    expect(await _sha256Hex(payloadBytes), expectedSha256);

    final attackManifest = Map<String, dynamic>.from(manifest);
    final attackDatasets = Map<String, dynamic>.from(
      attackManifest['datasets'] as Map,
    );
    final attackEntry = Map<String, dynamic>.from(
      attackDatasets[restrictionsDatasetKey] as Map,
    );
    final positiveVersion = positiveEntry['version'] as String;
    final attackVersion = _nextHigherVersion(positiveVersion);
    final positiveRevision =
        (positiveEntry['publicationRevision'] as int?) ?? 0;
    final attackRevision = positiveRevision + 1;
    attackEntry['version'] = attackVersion;
    attackEntry['publicationRevision'] = attackRevision;
    // Keep the published SHA unchanged. Only the in-memory response bytes
    // below are changed, so the service must reject them before JSON parsing.
    attackDatasets[restrictionsDatasetKey] = attackEntry;
    attackManifest['datasets'] = attackDatasets;
    final attackManifestBytes = utf8.encode(jsonEncode(attackManifest));
    final attackPayloadBytes = List<int>.of(payloadBytes);
    if (attackPayloadBytes.isEmpty) {
      throw StateError('The immutable PHP B1 payload is empty.');
    }
    attackPayloadBytes[0] = 0xff;
    expect(attackVersion.compareTo(positiveVersion), greaterThan(0));
    expect(attackRevision, greaterThan(positiveRevision));
    expect(await _sha256Hex(attackPayloadBytes), isNot(expectedSha256));

    AppDatabase? database;
    Dio? dio;
    HttpServer? server;
    Directory? temporaryDirectory;
    try {
      final db = AppDatabase(NativeDatabase.memory());
      database = db;
      final client = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
      dio = client;
      final loopback = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server = loopback;

      final cdnBaseUri = Uri(
        scheme: 'http',
        host: InternetAddress.loopbackIPv4.address,
        port: loopback.port,
      );
      final manifestUri = cdnBaseUri.resolve('/v1/manifest.json');
      final config = AppConfig(
        cdnBaseUrl: cdnBaseUri.toString(),
        manifestUrl: manifestUri.toString(),
      );
      final declaredUrl = positiveEntry['url'] as String;
      final declaredDatasetUri = Uri.parse(declaredUrl);
      expect(declaredUrl.startsWith('/storage/'), isTrue);
      expect(declaredDatasetUri.hasScheme, isFalse);
      expect(declaredDatasetUri.hasAuthority, isFalse);
      expect(declaredDatasetUri.hasQuery, isFalse);
      expect(declaredDatasetUri.hasFragment, isFalse);
      expect(declaredDatasetUri.pathSegments, isNot(contains('..')));
      final datasetUri = config.cdnBaseUri.resolveUri(declaredDatasetUri);
      expect(
        _sameOrigin(datasetUri, config.cdnBaseUri),
        isTrue,
        reason:
            'The immutable PHP URL must be served on the configured loopback '
            'origin; the test does not rewrite origins or relax validation.',
      );

      final fixedNow = DateTime.utc(2026, 11, 23, 12);
      expect(
        DateTime.parse(manifest['generatedAt'] as String).toUtc(),
        fixedNow,
      );
      final fixedClock = _FixedClock(fixedNow);
      final temporary = await Directory.systemTemp.createTemp(
        'picoradar_c29_national_ota_',
      );
      temporaryDirectory = temporary;

      var attackActive = false;
      var manifestHits = 0;
      var payloadHits = 0;
      final requestPaths = <String>[];
      final requestMethods = <String>[];
      final requestUris = <Uri>[];
      final manifestStatuses = <int>[];
      final payloadStatuses = <int>[];
      loopback.listen((request) async {
        requestPaths.add(request.uri.path);
        requestMethods.add(request.method);
        requestUris.add(request.uri);
        final List<int>? responseBytes;
        final int statusCode;
        if (request.uri.path == manifestUri.path) {
          manifestHits++;
          statusCode = HttpStatus.ok;
          manifestStatuses.add(statusCode);
          responseBytes = attackActive ? attackManifestBytes : manifestBytes;
        } else if (request.uri.path == datasetUri.path) {
          payloadHits++;
          statusCode = HttpStatus.ok;
          payloadStatuses.add(statusCode);
          responseBytes = attackActive ? attackPayloadBytes : payloadBytes;
        } else {
          statusCode = HttpStatus.notFound;
          responseBytes = null;
        }

        request.response.statusCode = statusCode;
        if (responseBytes != null) {
          request.response.headers.contentType = ContentType.json;
          request.response.headers.contentLength = responseBytes.length;
          request.response.add(responseBytes);
        }
        await request.response.close();
      });

      final preferences = _MemoryPreferences();
      final service = DatasetSyncService(
        database: db,
        preferences: preferences,
        config: config,
        importers: {
          restrictionsDatasetKey: (database, payload) =>
              importRestrictionsDataset(
                database,
                payload,
                now: fixedClock.read,
              ),
        },
        http: client,
        tempDirectory: temporary,
        now: fixedClock.read,
      );

      final positiveResult = await service.sync();
      expect(positiveResult.imported, contains(restrictionsDatasetKey));

      final coverage = await RestrictionStore(db).loadCoverage(
        'co-c28-synthetic-99999',
        VehicleKind.car,
        VehicleServiceType.private,
        DateTime.utc(2026, 11, 23, 12),
      );
      expect(coverage.coverageKnown, isTrue);
      expect(coverage.coverageCompleteness, CoverageCompleteness.partial);
      expect(coverage.consultationEnabled, isFalse);
      expect(coverage.jurisdictionConsultationEnabled, isFalse);
      expect(coverage.rules, isNotEmpty);
      final evaluation = evaluateRestrictionDay(
        ruleSet: coverage,
        jurisdictionId: 'co-c28-synthetic-99999',
        plate: 'ABC123',
        vehicleKind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
        date: DateTime.utc(2026, 11, 23),
      );
      expect(evaluation.status, RestrictionDayStatus.unknown);
      expect(evaluation.status, isNot(RestrictionDayStatus.allowed));

      final jurisdictionAvailability =
          (await db.select(db.restrictionJurisdictionAvailability).get())
              .singleWhere(
                (row) => row.jurisdictionId == 'co-c28-synthetic-99999',
              );
      final municipalityCodes = List<String>.from(
        jsonDecode(jurisdictionAvailability.municipalityCodesJson) as List,
      );
      expect(municipalityCodes, contains('99999'));
      expect(jurisdictionAvailability.consultationEnabled, isFalse);

      final beforeAttack = await _persistedSnapshot(db);
      expect(beforeAttack['datasetVersions'], hasLength(1));
      expect(beforeAttack['coverage'], isNotEmpty);
      expect(beforeAttack['availability'], isNotEmpty);
      final installedVersions =
          beforeAttack['datasetVersions'] as List<Map<String, Object?>>;
      expect(installedVersions.single['version'], positiveVersion);
      expect(installedVersions.single['sha256'], expectedSha256);
      expect(installedVersions.single['publicationRevision'], positiveRevision);
      expect(manifestHits, 1);
      expect(payloadHits, 1);
      expect(requestMethods, ['GET', 'GET']);
      expect(requestPaths, [manifestUri.path, datasetUri.path]);
      expect(manifestStatuses, [HttpStatus.ok]);
      expect(payloadStatuses, [HttpStatus.ok]);
      expect(
        requestUris.every((uri) => !uri.hasQuery && !uri.hasFragment),
        isTrue,
      );

      attackActive = true;
      await expectLater(
        service.sync(),
        throwsA(
          isA<DatasetSyncException>().having(
            (error) => error.message,
            'message',
            contains('SHA-256 mismatch'),
          ),
        ),
      );

      expect(manifestHits, 2);
      expect(payloadHits, 2);
      expect(requestPaths, [
        manifestUri.path,
        datasetUri.path,
        manifestUri.path,
        datasetUri.path,
      ]);
      expect(requestMethods, ['GET', 'GET', 'GET', 'GET']);
      expect(manifestStatuses, [HttpStatus.ok, HttpStatus.ok]);
      expect(payloadStatuses, [HttpStatus.ok, HttpStatus.ok]);
      expect(
        requestUris.every((uri) => !uri.hasQuery && !uri.hasFragment),
        isTrue,
      );
      expect(await _persistedSnapshot(db), beforeAttack);
      expect(await manifestFile.readAsBytes(), manifestBytes);
      expect(await payloadFile.readAsBytes(), payloadBytes);
    } finally {
      await server?.close(force: true);
      dio?.close(force: true);
      await database?.close();
      if (temporaryDirectory != null && await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    }
  }, timeout: const Timeout(Duration(seconds: 90)));
}

Future<Map<String, Object?>> _persistedSnapshot(AppDatabase database) async {
  final versions = (await database.select(database.datasetVersions).get())
    ..sort((left, right) => left.datasetKey.compareTo(right.datasetKey));
  final coverages = (await database.select(database.restrictionCoverages).get())
    ..sort((left, right) => left.id.compareTo(right.id));
  final availability =
      (await database
            .select(database.restrictionJurisdictionAvailability)
            .get())
        ..sort(
          (left, right) => left.jurisdictionId.compareTo(right.jurisdictionId),
        );

  return {
    'datasetVersions': [
      for (final row in versions)
        {
          'id': row.id,
          'datasetKey': row.datasetKey,
          'version': row.version,
          'sha256': row.sha256,
          'status': row.status,
          'publicationRevision': row.publicationRevision,
          'appliedAt': row.appliedAt.toUtc().toIso8601String(),
        },
    ],
    'coverage': [
      for (final row in coverages)
        {
          'id': row.id,
          'jurisdictionId': row.jurisdictionId,
          'jurisdictionName': row.jurisdictionName,
          'vehicleKind': row.vehicleKind,
          'serviceType': row.serviceType,
          'rulesJson': row.rulesJson,
          'verifiedAt': row.verifiedAt.toUtc().toIso8601String(),
          'staleAfter': row.staleAfter.toUtc().toIso8601String(),
          'sourceUrlsJson': row.sourceUrlsJson,
          'coverageCompleteness': row.coverageCompleteness,
          'updatedAt': row.updatedAt.toUtc().toIso8601String(),
        },
    ],
    'availability': [
      for (final row in availability)
        {
          'jurisdictionId': row.jurisdictionId,
          'municipalityCodesJson': row.municipalityCodesJson,
          'consultationEnabled': row.consultationEnabled,
        },
    ],
  };
}

Future<String> _sha256Hex(List<int> bytes) async {
  final digest = await Sha256().hash(bytes);
  return digest.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}

String _nextHigherVersion(String version) {
  final parts = version.split('.');
  if (parts.every((part) => RegExp(r'^\d+$').hasMatch(part))) {
    final last = int.parse(parts.removeLast()) + 1;
    return [...parts, '$last'].join('.');
  }
  return '$version~';
}

bool _sameOrigin(Uri left, Uri right) =>
    left.scheme == right.scheme &&
    left.host == right.host &&
    _effectivePort(left) == _effectivePort(right);

int _effectivePort(Uri uri) =>
    uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);

class _FixedClock {
  const _FixedClock(this.instant);

  final DateTime instant;

  DateTime read() => instant;
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
  Future<void> remove(String key) async => _values.remove(key);

  @override
  Future<void> setBool(String key, bool value) async => _values[key] = value;

  @override
  Future<void> setInt(String key, int value) async => _values[key] = value;

  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }
}
