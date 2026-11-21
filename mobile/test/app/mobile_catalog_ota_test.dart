import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/core/config/app_config.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/core/storage/app_preferences.dart';
import 'package:picoradar/core/sync/dataset_sync_service.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/data/restriction_dataset.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_engine.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_rule.dart';
import 'package:picoradar/features/vehicle_status/data/insurance_directory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'the 3 shipped catalogs remain available without CDN or account',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final directory = await Directory.systemTemp.createTemp(
        'picoradar_catalogs_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          datasetSnapshotsDirectoryProvider.overrideWith(
            (ref) async => directory,
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(await container.read(datasetSyncServiceProvider.future), isNull);
      expect(
        (await container.read(cdaCatalogProvider.future)).entries.length,
        964,
      );
      expect(
        (await container.read(cdaGeographyProvider.future)).sites.length,
        866,
      );
      expect(
        (await container.read(insuranceDirectoryProvider.future))
            .entries
            .length,
        16,
      );
    },
  );

  test('SHA verified HTTP catalog updates become visible and stay offline', () async {
    final directory = await Directory.systemTemp.createTemp(
      'picoradar_catalogs_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final databaseFile = File(
      '${directory.path}${Platform.pathSeparator}app.sqlite',
    );
    final db = AppDatabase(NativeDatabase(databaseFile));
    var databaseClosed = false;
    addTearDown(() async {
      if (!databaseClosed) await db.close();
    });
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        appPreferencesProvider.overrideWithValue(_MemoryPreferences()),
        datasetSnapshotsDirectoryProvider.overrideWith(
          (ref) async => directory,
        ),
        datasetSyncConfigProvider.overrideWithValue(
          AppConfig(cdnBaseUrl: 'https://datasets.example.org'),
        ),
      ],
    );
    var containerDisposed = false;
    addTearDown(() {
      if (!containerDisposed) container.dispose();
    });
    final oldCda = await container.read(cdaCatalogProvider.future);
    final oldSites = await container.read(cdaGeographyProvider.future);
    final oldInsurers = await container.read(insuranceDirectoryProvider.future);

    final sources = <String, String>{
      cdaCatalogDatasetKey: 'assets/catalogs/cda_catalog_v1.json',
      cdaGeographyDatasetKey: 'assets/catalogs/cda_geography_v1.json',
      insuranceDirectoryDatasetKey:
          'assets/catalogs/insurance_directory_v1.json',
      restrictionsDatasetKey: '',
    };
    final payloads = <String, List<int>>{};
    final entries = <String, Object?>{};
    for (final record in sources.entries) {
      final json = record.key == restrictionsDatasetKey
          ? _schema2Restrictions()
          : Map<String, dynamic>.from(
              jsonDecode(File(record.value).readAsStringSync()) as Map,
            );
      json['datasetKey'] = record.key;
      json['version'] = '2026-11-18.1';
      json['generatedAt'] = '2026-11-18T08:00:00Z';
      if (record.key == cdaCatalogDatasetKey) {
        (json['source'] as Map)['provider'] = 'RUNT - updated over OTA';
      } else if (record.key == cdaGeographyDatasetKey) {
        json['approved'] = true;
      } else if (record.key == insuranceDirectoryDatasetKey) {
        final insurers = json['entries'] as List<dynamic>;
        final firstInsurer = Map<String, dynamic>.from(insurers.first as Map);
        firstInsurer['aliases'] = [
          ...(firstInsurer['aliases'] as List<dynamic>).cast<String>(),
          'Aseguradora OTA actualizada',
        ];
        insurers[0] = firstInsurer;
      }
      final bytes = utf8.encode(jsonEncode(json));
      payloads['/datasets/${record.key}.json'] = bytes;
      entries[record.key] = {
        'version': '2026-11-18.1',
        'url': '/datasets/${record.key}.json',
        'sha256': await _hash(bytes),
        'publicationRevision': 11,
      };
    }
    payloads['/v1/manifest.json'] = utf8.encode(
      jsonEncode({
        'schemaVersion': 1,
        'generatedAt': '2026-11-18T08:00:00Z',
        'minAppVersion': '1.0.0',
        'datasets': entries,
        'features': {'ads': false, 'cloud': false, 'paidDocuments': false},
      }),
    );
    final service = (await container.read(datasetSyncServiceProvider.future))!;
    addTearDown(() => service.http.close(force: true));
    final transport = _MemoryHttp(Map<String, List<int>>.from(payloads));
    service.http.httpClientAdapter = transport;

    final result = await service.sync();
    expect(result.imported.toSet(), sources.keys.toSet());
    final installedRestrictionVersion =
        await (db.select(db.datasetVersions)
              ..where((row) => row.datasetKey.equals(restrictionsDatasetKey)))
            .getSingle();
    expect(installedRestrictionVersion.version, '2026-11-18.1');
    expect(installedRestrictionVersion.status, 'installed');
    final newCda = await container.read(cdaCatalogProvider.future);
    final newSites = await container.read(cdaGeographyProvider.future);
    final newInsurers = await container.read(insuranceDirectoryProvider.future);
    expect(newCda.source.provider, 'RUNT - updated over OTA');
    expect(newCda.entries.length, oldCda.entries.length);
    expect(newSites.sites.length, oldSites.sites.length);
    expect(newInsurers.entries.length, oldInsurers.entries.length);

    // A conditional manifest with no changes needs only ONE HTTP response:
    // Tax and tolls are not treated as missing if never published.
    transport.returnNotModified = true;
    final notModified = await service.sync();
    expect(notModified.notModified, isTrue);
    transport.returnNotModified = false;

    // The same verified snapshot must be usable offline after a provider reload.
    transport.responses.clear();
    container.invalidate(cdaCatalogProvider);
    container.invalidate(cdaGeographyProvider);
    container.invalidate(insuranceDirectoryProvider);
    expect(
      (await container.read(cdaCatalogProvider.future)).source.provider,
      'RUNT - updated over OTA',
    );
    expect(
      (await container.read(cdaGeographyProvider.future)).version,
      '2026-11-18.1',
    );
    expect(
      (await container.read(insuranceDirectoryProvider.future))
          .search('Aseguradora OTA actualizada'),
      hasLength(1),
    );

    // A different manifest SHA MUST NOT replace the last good publication.
    transport.responses.addAll(payloads);
    final manifest = jsonDecode(
      utf8.decode(payloads['/v1/manifest.json']!),
    ) as Map<String, dynamic>;
    final manifestEntries = manifest['datasets'] as Map<String, dynamic>;
    (manifestEntries[restrictionsDatasetKey] as Map)['sha256'] = '0' * 64;
    (manifestEntries[restrictionsDatasetKey] as Map)['version'] =
        '2026-11-18.2';
    (manifestEntries[restrictionsDatasetKey] as Map)['publicationRevision'] =
        12;
    transport.responses['/v1/manifest.json'] = utf8.encode(
      jsonEncode(manifest),
    );
    await expectLater(service.sync(), throwsA(isA<DatasetSyncException>()));
    final preservedRestrictionVersion =
        await (db.select(db.datasetVersions)
              ..where((row) => row.datasetKey.equals(restrictionsDatasetKey)))
            .getSingle();
    expect(preservedRestrictionVersion.version, '2026-11-18.1');
    container.invalidate(cdaCatalogProvider);
    expect(
      (await container.read(cdaCatalogProvider.future)).source.provider,
      'RUNT - updated over OTA',
    );

    // If local storage is altered, never render unverified data. Return to
    // the shipped copy, then repair the same published hash atomically.
    final installedSha =
        (entries[cdaCatalogDatasetKey] as Map)['sha256'] as String;
    final selected = File(
      '${directory.path}${Platform.pathSeparator}cda_catalog.json.$installedSha',
    );
    await selected.writeAsString('damaged bytes', flush: true);
    container.invalidate(cdaCatalogProvider);
    expect(
      (await container.read(cdaCatalogProvider.future)).source.provider,
      oldCda.source.provider,
    );
    transport.responses.addAll(payloads);
    final repaired = await service.sync();
    expect(repaired.imported, contains(cdaCatalogDatasetKey));
    container.invalidate(cdaCatalogProvider);
    expect(
      (await container.read(cdaCatalogProvider.future)).source.provider,
      'RUNT - updated over OTA',
    );

    // Reopen the actual SQLite file as a new app process would. Keep the CDN
    // URL configured but make its transport unavailable; no account is used.
    container.dispose();
    containerDisposed = true;
    await db.close();
    databaseClosed = true;

    final reopenedDb = AppDatabase(NativeDatabase(File(databaseFile.path)));
    var reopenedDbClosed = false;
    addTearDown(() async {
      if (!reopenedDbClosed) await reopenedDb.close();
    });
    final offlineContainer = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appDatabaseProvider.overrideWithValue(reopenedDb),
        appPreferencesProvider.overrideWithValue(_MemoryPreferences()),
        datasetSnapshotsDirectoryProvider.overrideWith(
          (ref) async => directory,
        ),
        datasetSyncConfigProvider.overrideWithValue(
          AppConfig(cdnBaseUrl: 'https://datasets.example.org'),
        ),
      ],
    );
    var offlineContainerDisposed = false;
    addTearDown(() {
      if (!offlineContainerDisposed) offlineContainer.dispose();
    });

    final offlineService = await offlineContainer.read(
      datasetSyncServiceProvider.future,
    );
    expect(offlineService, isNotNull);
    offlineService!.http.httpClientAdapter = _MemoryHttp({});
    await expectLater(offlineService.sync(), throwsA(isA<DioException>()));
    final reopenedRestrictionVersion =
        await (reopenedDb.select(reopenedDb.datasetVersions)
              ..where((row) => row.datasetKey.equals(restrictionsDatasetKey)))
            .getSingle();
    expect(reopenedRestrictionVersion.version, '2026-11-18.1');
    expect(reopenedRestrictionVersion.status, 'installed');
    expect(
      (await offlineContainer.read(cdaCatalogProvider.future)).source.provider,
      'RUNT - updated over OTA',
    );
    expect(
      (await offlineContainer.read(cdaGeographyProvider.future)).version,
      '2026-11-18.1',
    );
    expect(
      (await offlineContainer.read(insuranceDirectoryProvider.future))
          .search('Aseguradora OTA actualizada'),
      hasLength(1),
    );
    await offlineContainer.read(bundledRestrictionsProvider.future);
    final restrictionStore = offlineContainer.read(restrictionStoreProvider);
    const jurisdictionId = 'co-c3-synthetic';
    final coveredAt = DateTime(2026, 11, 23, 8);
    final covered = await restrictionStore.loadCoverage(
      jurisdictionId,
      VehicleKind.car,
      VehicleServiceType.private,
      coveredAt,
    );
    expect(covered.coverageKnown, isTrue);
    expect(covered.dataIsStale, isFalse);
    expect(covered.coverageCompleteness, CoverageCompleteness.partial);
    final coveredEvaluation = const RestrictionEngine().evaluate(
      RestrictionContext(
        jurisdictionId: jurisdictionId,
        plate: 'ABC123',
        vehicleKind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
        registrationOrigin: RegistrationOrigin.local,
        localDateTime: coveredAt,
        isHoliday: false,
        coverageKnown: covered.coverageKnown,
        dataIsStale: covered.dataIsStale,
        coverageCompleteness: covered.coverageCompleteness,
      ),
      covered.rules,
    );
    expect(coveredEvaluation.status, RestrictionStatus.restricted);

    final unknown = await restrictionStore.loadCoverage(
      jurisdictionId,
      VehicleKind.car,
      VehicleServiceType.taxi,
      coveredAt,
    );
    expect(unknown.coverageKnown, isFalse);
    final unknownEvaluation = const RestrictionEngine().evaluate(
      RestrictionContext(
        jurisdictionId: jurisdictionId,
        plate: 'ABC123',
        vehicleKind: VehicleKind.car,
        serviceType: VehicleServiceType.taxi,
        registrationOrigin: RegistrationOrigin.local,
        localDateTime: coveredAt,
        isHoliday: false,
        coverageKnown: unknown.coverageKnown,
        dataIsStale: unknown.dataIsStale,
      ),
      unknown.rules,
    );
    expect(unknownEvaluation.status, RestrictionStatus.unknown);

    final staleAt = DateTime(2026, 12, 1, 8);
    final stale = await restrictionStore.loadCoverage(
      jurisdictionId,
      VehicleKind.car,
      VehicleServiceType.private,
      staleAt,
    );
    expect(stale.dataIsStale, isTrue);
    final staleEvaluation = const RestrictionEngine().evaluate(
      RestrictionContext(
        jurisdictionId: jurisdictionId,
        plate: 'ABC123',
        vehicleKind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
        registrationOrigin: RegistrationOrigin.local,
        localDateTime: staleAt,
        isHoliday: false,
        coverageKnown: stale.coverageKnown,
        dataIsStale: stale.dataIsStale,
        coverageCompleteness: stale.coverageCompleteness,
      ),
      stale.rules,
    );
    expect(staleEvaluation.status, RestrictionStatus.stale);
    offlineContainer.dispose();
    offlineContainerDisposed = true;
    await reopenedDb.close();
    reopenedDbClosed = true;
  });
}

Future<String> _hash(List<int> bytes) async {
  final value = await Sha256().hash(bytes);
  return value.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

Map<String, dynamic> _schema2Restrictions() => {
  'schemaVersion': 2,
  'datasetKey': restrictionsDatasetKey,
  'version': '2026-11-18.1',
  'generatedAt': '2026-11-18T08:00:00Z',
  'expiresAt': '2026-12-31T23:59:59Z',
  'jurisdictions': [
    {
      'schemaVersion': 2,
      'id': 'co-c3-synthetic',
      'name': 'Ciudad sintética C3',
      'municipalityCodes': ['05001'],
      'consultationEnabled': true,
      'coverages': [
        {
          'vehicleKind': 'car',
          'serviceType': 'private',
          'coverageCompleteness': 'partial',
          'verifiedAt': '2026-11-18T00:00:00Z',
          'staleAfter': '2026-11-30T00:00:00Z',
          'sourceUrls': ['https://example.test/c3-synthetic'],
          'rules': [
            {
              'id': 'C3_SYNTHETIC_RULE',
              'priority': 100,
              'effect': 'restrict',
              'validFrom': '2026-11-01T00:00:00Z',
              'validUntil': '2026-12-31T23:59:59Z',
              'weekdays': [1],
              'timeWindows': [
                {'startMinute': 420, 'endMinute': 540},
              ],
              'appliesOnHolidays': false,
              'sourceUrl': 'https://example.test/c3-synthetic',
              'verifiedAt': '2026-11-18T00:00:00Z',
              'digits': [3],
              'digitPosition': 'lastNumeric',
              'conditions': [],
            },
          ],
        },
      ],
    },
  ],
};

class _MemoryPreferences extends Fake implements AppPreferences {
  final values = <String, String>{};
  @override
  Future<String?> getString(String key) async => values[key];
  @override
  Future<void> setString(String key, String value) async => values[key] = value;
}

class _MemoryHttp implements HttpClientAdapter {
  _MemoryHttp(this.responses);
  final Map<String, List<int>> responses;
  bool returnNotModified = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (returnNotModified && options.uri.path == '/v1/manifest.json') {
      return ResponseBody.fromBytes(const <int>[], HttpStatus.notModified);
    }
    final bytes = responses[options.uri.path];
    if (bytes == null) throw StateError('Unexpected synthetic HTTP request');
    return ResponseBody.fromBytes(
      bytes,
      200,
      headers: {
        HttpHeaders.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
