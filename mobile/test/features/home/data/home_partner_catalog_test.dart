import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/home/data/home_partner_catalog.dart';

void main() {
  test('local fallback preserves the exact four finite C11 campaigns', () {
    expect(fallbackHomePartnerCampaigns, hasLength(4));
    expect(fallbackHomePartnerCampaigns.map((campaign) => campaign.id), [
      'automotor',
      'insurance',
      'appraisal',
      'recruitment',
    ]);
    expect(fallbackHomePartnerCampaigns.map((campaign) => campaign.assetPath), [
      'assets/home/partners/campaign_automotor.png',
      'assets/home/partners/campaign_insurance.png',
      'assets/home/partners/campaign_appraisal.png',
      'assets/home/partners/campaign_partners.png',
    ]);
    expect(
      fallbackHomePartnerCampaigns.first.title,
      'Automotor de demostración',
    );
    expect(fallbackHomePartnerCampaigns.last.eyebrow, 'PROGRAMA DE ALIADOS');
    expect(
      fallbackHomePartnerCampaigns.last.title,
      'Haz crecer tu negocio con PicoRadar',
    );
  });

  test(
    'remote catalog verifies hash then filters and orders eligible territory',
    () async {
      final now = DateTime.utc(2026, 9, 20, 15);
      final release = _catalogBytes(now, [
        _campaign('national', priority: 20),
        _campaign(
          'department-first',
          priority: 5,
          territory: {
            'scope': 'department',
            'code': '05',
            'key': 'co-antioquia',
          },
        ),
        _campaign('paused', priority: 1, status: 'paused'),
        _campaign(
          'expired',
          priority: 1,
          endsAt: now.subtract(const Duration(seconds: 1)),
        ),
        _campaign(
          'scheduled',
          priority: 1,
          startsAt: now.add(const Duration(minutes: 1)),
        ),
        _campaign(
          'other-department',
          priority: 1,
          territory: {'scope': 'department', 'code': '11', 'key': 'co-bogota'},
        ),
      ]);
      final sha = await _sha256(release);
      final adapter = _CatalogAdapter({
        '/storage/campaigns/v1/catalog.json': _manifestBytes(now, sha),
        '/storage/campaigns/v1/releases/catalog-7.json': release,
      });
      final cache = _MemoryCatalogCache();

      final campaigns = await _repository(adapter, cache, () => now).load(
        const CampaignTerritoryContext(
          departmentCode: '05',
          departmentKey: 'co-antioquia',
        ),
      );

      expect(campaigns.map((campaign) => campaign.id), [
        'department-first',
        'national',
      ]);
      expect(campaigns.first.imageUrl?.scheme, 'https');
      expect(cache.entry, isNotNull);
      expect(adapter.paths, [
        '/storage/campaigns/v1/catalog.json',
        '/storage/campaigns/v1/releases/catalog-7.json',
      ]);
    },
  );

  test('commercial failures use fresh cache then exact local fallback after expiry', () async {
    var now = DateTime.utc(2026, 9, 20, 15);
    final release = _catalogBytes(now, [_campaign('cached', priority: 10)]);
    final sha = await _sha256(release);
    final cache = _MemoryCatalogCache();
    final online = _CatalogAdapter({
      '/storage/campaigns/v1/catalog.json': _manifestBytes(now, sha),
      '/storage/campaigns/v1/releases/catalog-7.json': release,
    });
    await _repository(
      online,
      cache,
      () => now,
    ).load(const CampaignTerritoryContext());

    final offline = _CatalogAdapter({});
    expect(
      (await _repository(
        offline,
        cache,
        () => now,
      ).load(const CampaignTerritoryContext())).single.id,
      'cached',
    );

    now = now.add(const Duration(hours: 2));
    final fallback = await _repository(
      offline,
      cache,
      () => now,
    ).load(const CampaignTerritoryContext());
    expect(fallback.map((campaign) => campaign.id), [
      'automotor',
      'insurance',
      'appraisal',
      'recruitment',
    ]);
  });

  test(
    'hash mismatch and unsafe image URL never escape or render remotely',
    () async {
      final now = DateTime.utc(2026, 9, 20, 15);
      final release = _catalogBytes(now, [
        _campaign(
          'unsafe-image',
          priority: 1,
          imageUrl: 'https://other.example.test/image.png',
        ),
      ]);
      final adapter = _CatalogAdapter({
        '/storage/campaigns/v1/catalog.json': _manifestBytes(now, 'f' * 64),
        '/storage/campaigns/v1/releases/catalog-7.json': release,
      });

      final campaigns = await _repository(
        adapter,
        _MemoryCatalogCache(),
        () => now,
      ).load(const CampaignTerritoryContext());

      expect(campaigns, same(fallbackHomePartnerCampaigns));
    },
  );
}

HomePartnerCatalogRepository _repository(
  _CatalogAdapter adapter,
  CampaignCatalogCache cache,
  DateTime Function() now,
) {
  final dio = Dio()..httpClientAdapter = adapter;
  return HomePartnerCatalogRepository(
    manifestUri: Uri.parse(
      'https://cdn.picoradar.test/storage/campaigns/v1/catalog.json',
    ),
    http: dio,
    cache: cache,
    now: now,
  );
}

List<int> _manifestBytes(DateTime now, String sha) => utf8.encode(
  jsonEncode({
    'schemaVersion': 1,
    'version': 7,
    'generatedAt': now.subtract(const Duration(minutes: 1)).toIso8601String(),
    'expiresAt': now.add(const Duration(hours: 1)).toIso8601String(),
    'url': 'https://cdn.picoradar.test/storage/campaigns/v1/releases/catalog-7.json',
    'sha256': sha,
  }),
);

List<int> _catalogBytes(DateTime now, List<Map<String, Object?>> campaigns) =>
    utf8.encode(
      jsonEncode({
        'schemaVersion': 1,
        'version': 7,
        'generatedAt': now
            .subtract(const Duration(minutes: 1))
            .toIso8601String(),
        'expiresAt': now.add(const Duration(hours: 1)).toIso8601String(),
        'campaigns': campaigns,
      }),
    );

Map<String, Object?> _campaign(
  String id, {
  required int priority,
  String status = 'active',
  DateTime? startsAt,
  DateTime? endsAt,
  String imageUrl =
      'https://cdn.picoradar.test/storage/campaigns/assets/image.png',
  Map<String, Object?> territory = const {'scope': 'national'},
}) => {
  'id': id,
  'sponsorId': 'sp_synthetic',
  'kind': 'sponsored',
  'status': status,
  'label': 'PATROCINADO',
  'title': 'Campaña $id',
  'subtitle': 'Contenido sintético.',
  'ctaText': 'Conocer más',
  'targetUrl': 'https://example.test/$id',
  'imageUrl': imageUrl,
  'priority': priority,
  'placement': 'home_c11',
  'territory': territory,
  'startsAt': (startsAt ?? DateTime.utc(2026, 9, 20, 14)).toIso8601String(),
  'endsAt': (endsAt ?? DateTime.utc(2026, 9, 20, 16)).toIso8601String(),
};

Future<String> _sha256(List<int> bytes) async {
  final hash = await Sha256().hash(bytes);
  return hash.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}

class _MemoryCatalogCache implements CampaignCatalogCache {
  CampaignCatalogCacheEntry? entry;

  @override
  Future<CampaignCatalogCacheEntry?> read() async => entry;

  @override
  Future<void> write(CampaignCatalogCacheEntry entry) async {
    this.entry = entry;
  }
}

class _CatalogAdapter implements HttpClientAdapter {
  _CatalogAdapter(this.responses);

  final Map<String, List<int>> responses;
  final paths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.uri.path);
    final bytes = responses[options.uri.path];
    if (bytes == null) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    return ResponseBody.fromBytes(
      bytes,
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        Headers.contentLengthHeader: ['${bytes.length}'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
