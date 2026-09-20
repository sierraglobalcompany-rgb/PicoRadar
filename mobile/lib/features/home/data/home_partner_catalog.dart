import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';

const campaignCatalogPlacement = 'home_c11';

class HomePartnerCampaign {
  const HomePartnerCampaign({
    required this.id,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.ctaText,
    required this.priority,
    this.sponsorId,
    this.explanation = '',
    this.assetPath,
    this.imageUrl,
    this.targetUrl,
  });

  final String id;
  final String? sponsorId;
  final String eyebrow;
  final String title;
  final String subtitle;
  final String ctaText;
  final String explanation;
  final String? assetPath;
  final Uri? imageUrl;
  final Uri? targetUrl;
  final int priority;

  bool get isLocalFallback => assetPath != null;
}

const fallbackHomePartnerCampaigns = <HomePartnerCampaign>[
  HomePartnerCampaign(
    id: 'automotor',
    eyebrow: 'DEMO LOCAL',
    title: 'Automotor de demostración',
    subtitle: 'Conoce cómo podría funcionar una experiencia de compra y venta.',
    ctaText: 'Ver explicación',
    explanation: 'Esta vista explica una futura experiencia con aliados automotores. No ofrece inventario, valoración ni contacto comercial real.',
    assetPath: 'assets/home/partners/campaign_automotor.png',
    priority: 0,
  ),
  HomePartnerCampaign(
    id: 'insurance',
    eyebrow: 'DEMO LOCAL',
    title: 'Seguro de demostración',
    subtitle: 'Una vista informativa sin cotización ni envío de datos.',
    ctaText: 'Ver explicación',
    explanation: 'Esta demostración describe un posible acceso a seguros. No cotiza, no compara pólizas y no transmite información personal.',
    assetPath: 'assets/home/partners/campaign_insurance.png',
    priority: 1,
  ),
  HomePartnerCampaign(
    id: 'appraisal',
    eyebrow: 'DEMO LOCAL',
    title: 'Peritaje de demostración',
    subtitle: 'Explora el concepto antes de integrar centros reales.',
    ctaText: 'Ver explicación',
    explanation: 'Esta explicación muestra el alcance previsto para peritajes. No agenda citas, no emite diagnósticos y no comparte datos.',
    assetPath: 'assets/home/partners/campaign_appraisal.png',
    priority: 2,
  ),
  HomePartnerCampaign(
    id: 'recruitment',
    eyebrow: 'PROGRAMA DE ALIADOS',
    title: 'Haz crecer tu negocio con PicoRadar',
    subtitle: 'Cuéntanos qué servicio prestas y revisaremos tu solicitud.',
    ctaText: 'Quiero ser aliado',
    assetPath: 'assets/home/partners/campaign_partners.png',
    priority: 3,
  ),
];

class CampaignTerritoryContext {
  const CampaignTerritoryContext({
    this.departmentCode,
    this.departmentKey,
    this.municipalityCode,
    this.municipalityKey,
  });

  final String? departmentCode;
  final String? departmentKey;
  final String? municipalityCode;
  final String? municipalityKey;

  @override
  bool operator ==(Object other) =>
      other is CampaignTerritoryContext &&
      other.departmentCode == departmentCode &&
      other.departmentKey == departmentKey &&
      other.municipalityCode == municipalityCode &&
      other.municipalityKey == municipalityKey;

  @override
  int get hashCode => Object.hash(
    departmentCode,
    departmentKey,
    municipalityCode,
    municipalityKey,
  );
}

class CampaignCatalogCacheEntry {
  const CampaignCatalogCacheEntry({
    required this.version,
    required this.bytes,
    required this.sha256,
  });

  final int version;
  final List<int> bytes;
  final String sha256;
}

abstract interface class CampaignCatalogCache {
  Future<CampaignCatalogCacheEntry?> read();

  Future<void> write(CampaignCatalogCacheEntry entry);
}

class FileCampaignCatalogCache implements CampaignCatalogCache {
  FileCampaignCatalogCache(this.file);

  final File file;

  @override
  Future<CampaignCatalogCacheEntry?> read() async {
    try {
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      final json = Map<String, Object?>.from(decoded);
      final version = json['version'];
      final sha256 = json['sha256'];
      final payload = json['payload'];
      if (version is! int || sha256 is! String || payload is! String) {
        return null;
      }
      return CampaignCatalogCacheEntry(
        version: version,
        bytes: base64Decode(payload),
        sha256: sha256,
      );
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(CampaignCatalogCacheEntry entry) async {
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({
        'schemaVersion': 1,
        'version': entry.version,
        'sha256': entry.sha256,
        'payload': base64Encode(entry.bytes),
      }),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }
}

class HomePartnerCatalogRepository {
  HomePartnerCatalogRepository({
    required this.manifestUri,
    required this.http,
    required this.cache,
    DateTime Function()? now,
    this.maxManifestBytes = 64 * 1024,
    this.maxCatalogBytes = 512 * 1024,
  }) : now = now ?? DateTime.now;

  final Uri manifestUri;
  final Dio http;
  final CampaignCatalogCache cache;
  final DateTime Function() now;
  final int maxManifestBytes;
  final int maxCatalogBytes;

  Future<List<HomePartnerCampaign>> load(
    CampaignTerritoryContext territory,
  ) async {
    try {
      final remote = await _loadRemote(territory);
      if (remote.isNotEmpty) return remote;
    } catch (_) {
      // Commercial content is optional; a verified cache or local C11 follows.
    }
    try {
      final cached = await _loadCache(territory);
      if (cached.isNotEmpty) return cached;
    } catch (_) {
      // Corrupt and expired cache entries are deliberately ignored.
    }
    return fallbackHomePartnerCampaigns;
  }

  Future<List<HomePartnerCampaign>> _loadRemote(
    CampaignTerritoryContext territory,
  ) async {
    _requireSecureUri(manifestUri, 'Campaign manifest');
    final manifestBytes = await _download(manifestUri, maxManifestBytes);
    final manifest = _CampaignManifest.parse(manifestBytes);
    if (!now().toUtc().isBefore(manifest.expiresAt)) {
      throw const FormatException('Campaign manifest expired.');
    }
    if (!_sameOrigin(manifestUri, manifest.url)) {
      throw const FormatException('Campaign release changed origin.');
    }
    final existing = await cache.read();
    if (existing != null && existing.version > manifest.version) {
      throw const FormatException('Campaign catalog version rolled back.');
    }

    final catalogBytes = await _download(manifest.url, maxCatalogBytes);
    final actualSha = await _sha256(catalogBytes);
    if (actualSha != manifest.sha256) {
      throw const FormatException('Campaign catalog hash mismatch.');
    }
    final parsed = _parseCatalog(catalogBytes, manifestUri);
    if (parsed.version != manifest.version ||
        parsed.expiresAt.toUtc() != manifest.expiresAt) {
      throw const FormatException('Campaign catalog metadata is inconsistent.');
    }
    await cache.write(
      CampaignCatalogCacheEntry(
        version: manifest.version,
        bytes: catalogBytes,
        sha256: actualSha,
      ),
    );

    return _eligible(parsed.campaigns, territory);
  }

  Future<List<HomePartnerCampaign>> _loadCache(
    CampaignTerritoryContext territory,
  ) async {
    final entry = await cache.read();
    if (entry == null || !RegExp(r'^[a-f0-9]{64}$').hasMatch(entry.sha256)) {
      return const [];
    }
    final actualSha = await _sha256(entry.bytes);
    if (actualSha != entry.sha256) {
      return const [];
    }
    final parsed = _parseCatalog(entry.bytes, manifestUri);
    if (parsed.version != entry.version ||
        !now().toUtc().isBefore(parsed.expiresAt.toUtc())) {
      return const [];
    }
    return _eligible(parsed.campaigns, territory);
  }

  Future<List<int>> _download(Uri uri, int maxBytes) async {
    final response = await http.getUri<List<int>>(
      uri,
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: false,
        validateStatus: (status) => status != null,
      ),
    );
    if (response.statusCode != HttpStatus.ok || response.data == null) {
      throw FormatException(
        'Campaign request failed with HTTP ${response.statusCode}.',
      );
    }
    final declaredLength = int.tryParse(
      response.headers.value(HttpHeaders.contentLengthHeader) ?? '',
    );
    if (declaredLength != null && declaredLength > maxBytes) {
      throw const FormatException('Campaign response is too large.');
    }
    final bytes = response.data!;
    if (bytes.length > maxBytes) {
      throw const FormatException('Campaign response is too large.');
    }
    return bytes;
  }

  _ParsedCatalog _parseCatalog(List<int> bytes, Uri trustedOrigin) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw const FormatException('Campaign catalog must be an object.');
    }
    final json = Map<String, Object?>.from(decoded);
    if (json['schemaVersion'] != 1 || json['version'] is! int) {
      throw const FormatException('Campaign catalog schema is unsupported.');
    }
    final expiresAt = DateTime.tryParse(json['expiresAt']?.toString() ?? '');
    final rows = json['campaigns'];
    if (expiresAt == null || rows is! List || rows.length > 100) {
      throw const FormatException('Campaign catalog metadata is invalid.');
    }
    final campaigns = <_RemoteCampaign>[];
    for (final row in rows) {
      if (row is! Map) continue;
      try {
        campaigns.add(
          _RemoteCampaign.parse(Map<String, Object?>.from(row), trustedOrigin),
        );
      } on FormatException {
        continue;
      }
    }
    return _ParsedCatalog(
      version: json['version']! as int,
      expiresAt: expiresAt.toUtc(),
      campaigns: campaigns,
    );
  }

  List<HomePartnerCampaign> _eligible(
    List<_RemoteCampaign> campaigns,
    CampaignTerritoryContext territory,
  ) {
    final instant = now().toUtc();
    final eligible =
        campaigns
            .where(
              (campaign) =>
                  campaign.status == 'active' &&
                  campaign.placement == campaignCatalogPlacement &&
                  !instant.isBefore(campaign.startsAt) &&
                  instant.isBefore(campaign.endsAt) &&
                  campaign.matches(territory),
            )
            .toList()
          ..sort((a, b) {
            final priority = a.priority.compareTo(b.priority);
            return priority != 0 ? priority : a.id.compareTo(b.id);
          });
    return List.unmodifiable(eligible.map((campaign) => campaign.publicValue));
  }
}

class _CampaignManifest {
  const _CampaignManifest({
    required this.version,
    required this.expiresAt,
    required this.url,
    required this.sha256,
  });

  final int version;
  final DateTime expiresAt;
  final Uri url;
  final String sha256;

  static _CampaignManifest parse(List<int> bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw const FormatException('Campaign manifest must be an object.');
    }
    final json = Map<String, Object?>.from(decoded);
    final version = json['version'];
    final expiresAt = DateTime.tryParse(json['expiresAt']?.toString() ?? '');
    final url = Uri.tryParse(json['url']?.toString() ?? '');
    final sha256 = json['sha256']?.toString().toLowerCase() ?? '';
    if (json['schemaVersion'] != 1 ||
        version is! int ||
        version < 1 ||
        expiresAt == null ||
        url == null ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256)) {
      throw const FormatException('Campaign manifest metadata is invalid.');
    }
    _requireSecureUri(url, 'Campaign release');
    return _CampaignManifest(
      version: version,
      expiresAt: expiresAt.toUtc(),
      url: url,
      sha256: sha256,
    );
  }
}

class _ParsedCatalog {
  const _ParsedCatalog({
    required this.version,
    required this.expiresAt,
    required this.campaigns,
  });

  final int version;
  final DateTime expiresAt;
  final List<_RemoteCampaign> campaigns;
}

class _RemoteCampaign {
  const _RemoteCampaign({
    required this.publicValue,
    required this.status,
    required this.placement,
    required this.priority,
    required this.scope,
    required this.territoryCode,
    required this.territoryKey,
    required this.startsAt,
    required this.endsAt,
  });

  final HomePartnerCampaign publicValue;
  final String status;
  final String placement;
  final int priority;
  final String scope;
  final String? territoryCode;
  final String? territoryKey;
  final DateTime startsAt;
  final DateTime endsAt;

  String get id => publicValue.id;

  static _RemoteCampaign parse(Map<String, Object?> json, Uri trustedOrigin) {
    String requiredText(String key, {int max = 255}) {
      final value = json[key]?.toString().trim() ?? '';
      if (value.isEmpty || value.length > max) {
        throw FormatException('Campaign $key is invalid.');
      }
      return value;
    }

    final territoryValue = json['territory'];
    if (territoryValue is! Map) {
      throw const FormatException('Campaign territory is invalid.');
    }
    final territory = Map<String, Object?>.from(territoryValue);
    final scope = territory['scope']?.toString() ?? '';
    if (!const {'national', 'department', 'municipality'}.contains(scope)) {
      throw const FormatException('Campaign scope is invalid.');
    }
    final startsAt = DateTime.tryParse(json['startsAt']?.toString() ?? '');
    final endsAt = DateTime.tryParse(json['endsAt']?.toString() ?? '');
    final priority = json['priority'];
    final imageUrl = Uri.tryParse(requiredText('imageUrl', max: 2048));
    final targetUrl = Uri.tryParse(requiredText('targetUrl', max: 2048));
    if (startsAt == null ||
        endsAt == null ||
        !endsAt.isAfter(startsAt) ||
        priority is! int ||
        priority < 0 ||
        priority > 1000 ||
        imageUrl == null ||
        targetUrl == null ||
        !_sameOrigin(trustedOrigin, imageUrl)) {
      throw const FormatException('Campaign payload is unsafe.');
    }
    _requireSecureUri(imageUrl, 'Campaign image');
    _requireSecureUri(targetUrl, 'Campaign target');

    final status = json['status']?.toString() ?? 'active';
    final campaign = HomePartnerCampaign(
      id: requiredText('id', max: 64),
      sponsorId: requiredText('sponsorId', max: 64),
      eyebrow: requiredText('label', max: 80),
      title: requiredText('title', max: 120),
      subtitle: requiredText('subtitle', max: 240),
      ctaText: requiredText('ctaText', max: 64),
      imageUrl: imageUrl,
      targetUrl: targetUrl,
      priority: priority,
    );
    return _RemoteCampaign(
      publicValue: campaign,
      status: status,
      placement: requiredText('placement', max: 32),
      priority: priority,
      scope: scope,
      territoryCode: _optionalText(territory['code']),
      territoryKey: _optionalText(territory['key']),
      startsAt: startsAt.toUtc(),
      endsAt: endsAt.toUtc(),
    );
  }

  bool matches(CampaignTerritoryContext context) => switch (scope) {
    'national' => true,
    'department' =>
      _matches(territoryCode, context.departmentCode) ||
          _matches(territoryKey, context.departmentKey),
    'municipality' =>
      _matches(territoryCode, context.municipalityCode) ||
          _matches(territoryKey, context.municipalityKey),
    _ => false,
  };
}

String? _optionalText(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

bool _matches(String? expected, String? actual) =>
    expected != null && actual != null && expected == actual;

void _requireSecureUri(Uri uri, String label) {
  if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
    throw FormatException('$label must use credential-free HTTPS.');
  }
}

bool _sameOrigin(Uri left, Uri right) =>
    left.scheme == right.scheme &&
    left.host == right.host &&
    _effectivePort(left) == _effectivePort(right);

int _effectivePort(Uri uri) => uri.hasPort ? uri.port : 443;

Future<String> _sha256(List<int> bytes) async {
  final hash = await Sha256().hash(bytes);
  return hash.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}
