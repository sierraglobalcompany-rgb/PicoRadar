import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/config/app_config.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/core/storage/app_preferences.dart';
import 'package:picoradar/core/sync/dataset_sync_service.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/home/data/home_partner_catalog.dart';
import 'package:picoradar/features/pico_placa/data/restriction_dataset.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_engine.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_rule.dart';

void main() {
  final baseUrl = Platform.environment['PICORADAR_B07_BASE_URL'] ?? '';
  final basicUser = Platform.environment['PICORADAR_TEST_BASIC_USER'] ?? '';
  final basicPassword =
      Platform.environment['PICORADAR_TEST_BASIC_PASSWORD'] ?? '';

  test(
    'server publications reach the real mobile restriction and campaign consumers',
    () async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final dio = _localHttpsDio(baseUrl, basicUser, basicPassword);
      final database = AppDatabase(NativeDatabase.memory());
      final temporary = await Directory.systemTemp.createTemp(
        'picoradar_b07_bridge_',
      );
      try {
        final sync = DatasetSyncService(
          database: database,
          preferences: _MemoryPreferences(),
          config: AppConfig(
            cdnBaseUrl: baseUrl,
            manifestUrl: '$baseUrl/v1/manifest.json',
          ),
          importers: const {restrictionsDatasetKey: importRestrictionsDataset},
          http: dio,
          tempDirectory: temporary,
          now: () => DateTime.utc(2026, 9, 21, 13),
        );

        final result = await sync.sync();
        expect(result.imported, contains(restrictionsDatasetKey));

        final coverage =
            await (database.select(
                  database.restrictionCoverages,
                )..where((row) => row.id.equals('co-ant-medellin:car:private')))
                .getSingle();
        final rules = restrictionRulesFromJson(
          coverage.rulesJson,
          jurisdictionId: coverage.jurisdictionId,
          vehicleKind: VehicleKind.car,
          serviceType: VehicleServiceType.private,
        );
        final evaluation = const RestrictionEngine().evaluate(
          RestrictionContext(
            jurisdictionId: 'co-ant-medellin',
            plate: 'ABC121',
            vehicleKind: VehicleKind.car,
            serviceType: VehicleServiceType.private,
            registrationOrigin: RegistrationOrigin.local,
            localDateTime: DateTime(2026, 9, 21, 8),
            isHoliday: false,
            coverageKnown: true,
            dataIsStale: false,
          ),
          rules,
        );
        expect(evaluation.status, RestrictionStatus.restricted);
        expect(evaluation.matchedRuleId, 'b07-browser-medellin-monday');

        final campaigns = await HomePartnerCatalogRepository(
          manifestUri: Uri.parse('$baseUrl/storage/campaigns/v1/catalog.json'),
          http: dio,
          cache: _MemoryCampaignCache(),
          now: () => DateTime.utc(2026, 9, 21, 13),
        ).load(const CampaignTerritoryContext());
        expect(
          campaigns.map((campaign) => campaign.title),
          contains('Aliado B07 sintético'),
        );
        expect(
          campaigns
              .singleWhere(
                (campaign) => campaign.title == 'Aliado B07 sintético',
              )
              .isLocalFallback,
          isFalse,
        );
      } finally {
        await database.close();
        await temporary.delete(recursive: true);
      }
    },
    skip: baseUrl.isEmpty
        ? 'Requires a published B07 clean-room server.'
        : false,
  );
}

Dio _localHttpsDio(String baseUrl, String user, String password) {
  final authorization = base64Encode(utf8.encode('$user:$password'));
  final dio = Dio(
    BaseOptions(
      headers: {HttpHeaders.authorizationHeader: 'Basic $authorization'},
    ),
  );
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () =>
        HttpClient()
          ..badCertificateCallback = (certificate, host, port) {
            return Uri.parse(baseUrl).host == host;
          },
  );
  return dio;
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

class _MemoryCampaignCache implements CampaignCatalogCache {
  CampaignCatalogCacheEntry? entry;

  @override
  Future<CampaignCatalogCacheEntry?> read() async => entry;

  @override
  Future<void> write(CampaignCatalogCacheEntry value) async {
    entry = value;
  }
}
