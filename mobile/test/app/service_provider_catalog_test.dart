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
import 'package:picoradar/features/services/data/service_provider_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('catalog parses, filters territory/category, and rejects duplicates', () {
    final catalog = ServiceProviderCatalog.fromJson(_payload());

    expect(catalog.providers, hasLength(2));
    expect(
      catalog.search('Medellín', category: ServiceProviderCategory.cda),
      hasLength(1),
    );
    expect(catalog.search('Antioquia'), hasLength(2));
    expect(
      () => ServiceProviderRecord.fromJson(
        Map<String, dynamic>.from(_record())
          ..['municipalityCode'] = '11001',
      ),
      throwsFormatException,
    );

    final duplicated = _payload();
    (duplicated['providers'] as List<dynamic>)[1] = _record();
    expect(
      () => ServiceProviderCatalog.fromJson(duplicated),
      throwsFormatException,
    );
  });

  test('verified OTA snapshot is usable offline and invalid payload keeps last good', () async {
    final directory = await Directory.systemTemp.createTemp(
      'picoradar_service_providers_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        appPreferencesProvider.overrideWithValue(_MemoryPreferences()),
        datasetSnapshotsDirectoryProvider.overrideWith(
          (ref) async => directory,
        ),
        datasetSyncConfigProvider.overrideWithValue(
          AppConfig(cdnBaseUrl: 'https://datasets.example.org'),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      (await container.read(serviceProvidersCatalogProvider.future)).providers,
      isEmpty,
    );
    final payload = _payload();
    final payloadBytes = utf8.encode(jsonEncode(payload));
    final transport = _MemoryHttp({});
    final service = (await container.read(datasetSyncServiceProvider.future))!;
    service.http.httpClientAdapter = transport;
    addTearDown(() => service.http.close(force: true));

    transport.responses.addAll(
      await _responses(payloadBytes, 'directory-v1', 1),
    );
    final imported = await service.sync();
    expect(imported.imported, contains(serviceProvidersDatasetKey));
    container.invalidate(serviceProvidersCatalogProvider);
    final installed = await container.read(serviceProvidersCatalogProvider.future);
    expect(installed.version, 'directory-v1');
    expect(installed.search('Centro CDA sintético'), hasLength(1));

    final invalidPayload = _payload(version: 'directory-v2');
    (invalidPayload['providers'] as List<dynamic>).add(_record());
    transport.responses
      ..clear()
      ..addAll(
        await _responses(
          utf8.encode(jsonEncode(invalidPayload)),
          'directory-v2',
          2,
        ),
      );
    await expectLater(service.sync(), throwsA(isA<DatasetSyncException>()));
    final persistedVersion = await (database.select(
      database.datasetVersions,
    )..where((row) => row.datasetKey.equals(serviceProvidersDatasetKey))).getSingle();
    expect(persistedVersion.version, 'directory-v1');

    transport.responses.clear();
    container.invalidate(serviceProvidersCatalogProvider);
    final offline = await container.read(serviceProvidersCatalogProvider.future);
    expect(offline.version, 'directory-v1');
    expect(offline.search('Centro CDA sintético'), hasLength(1));
  });
}

Map<String, dynamic> _payload({String version = 'directory-v1'}) => {
  'schemaVersion': 1,
  'datasetKey': serviceProvidersDatasetKey,
  'version': version,
  'generatedAt': '2026-11-21T08:00:00Z',
  'providers': [
    _record(),
    {
      ..._record(),
      'id': 'sp-2',
      'category': 'workshop',
      'municipalityCode': '05088',
      'municipality': 'Bello',
      'name': 'Taller sintético',
    },
  ],
};

Map<String, dynamic> _record() => {
  'id': 'sp-1',
  'category': 'cda',
  'departmentCode': '05',
  'municipalityCode': '05001',
  'department': 'Antioquia',
  'municipality': 'Medellín',
  'name': 'Centro CDA sintético',
  'address': 'Dirección de prueba',
  'latitude': 6.25,
  'longitude': -75.56,
  'contactUrl': 'https://example.test/contacto',
  'sourceUrl': 'https://example.test/fuente',
  'verifiedAt': '2026-11-20T08:00:00Z',
  'validUntil': '2026-12-31',
};

Future<Map<String, List<int>>> _responses(
  List<int> bytes,
  String version,
  int revision,
) async {
  final digest = (await Sha256().hash(bytes)).bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return {
    '/v1/manifest.json': utf8.encode(
      jsonEncode({
        'schemaVersion': 1,
        'generatedAt': '2026-11-21T08:00:00Z',
        'minAppVersion': '1.0.0',
        'datasets': {
          serviceProvidersDatasetKey: {
            'version': version,
            'url': '/datasets/$version.json',
            'sha256': digest,
            'expiresAt': '2026-12-31T23:59:59Z',
            'publicationRevision': revision,
          },
        },
        'features': {'ads': false, 'cloud': false},
      }),
    ),
    '/datasets/$version.json': bytes,
  };
}

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

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = responses[options.uri.path];
    if (bytes == null) throw StateError('Unexpected synthetic HTTP request.');
    return ResponseBody.fromBytes(
      bytes,
      HttpStatus.ok,
      headers: {HttpHeaders.contentTypeHeader: ['application/json']},
    );
  }

  @override
  void close({bool force = false}) {}
}
