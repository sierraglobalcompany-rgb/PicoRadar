import 'dart:convert';

import 'package:flutter/services.dart';

import 'cda_catalog.dart';

const cdaGeographyAssetPath = 'assets/catalogs/cda_geography_v1.json';

Future<CdaGeography> loadCdaGeography(AssetBundle bundle) async =>
    CdaGeography.fromJson(
      jsonDecode(await bundle.loadString(cdaGeographyAssetPath))
          as Map<String, Object?>,
    );

/// Editorial evidence is independent of inclusion in the RUNT inventory.
class CdaEvidence {
  const CdaEvidence({required this.url, required this.reviewedAt});
  final String url;
  final DateTime reviewedAt;

  bool validAt(DateTime now) => !reviewedAt.isAfter(
    DateTime.utc(now.year, now.month, now.day, 23, 59, 59),
  );

  factory CdaEvidence.fromJson(Map<String, Object?> json) {
    final url = json['url'];
    final date = json['reviewedAt'];
    if (url is! String ||
        !isCdaHttpsUrl(url) ||
        date is! String ||
        DateTime.tryParse(date) == null) {
      throw const FormatException('Invalid CDA evidence.');
    }
    return CdaEvidence(url: url, reviewedAt: DateTime.parse(date));
  }
}

bool isCdaHttpsUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host.contains('.') &&
      uri.userInfo.isEmpty &&
      !uri.hasFragment;
}

class CdaSite {
  CdaSite({
    required this.cdaId,
    required this.catalogName,
    required this.municipality,
    required this.departmentCode,
    required this.status,
    this.latitude,
    this.longitude,
    this.address,
    this.locationMethod,
    this.locationScore,
    List<CdaEvidence> locationSources = const [],
    Set<String> vehicleTypes = const {},
    List<CdaEvidence> compatibilitySources = const [],
    this.phone,
    this.web,
    List<CdaEvidence> contactSources = const [],
  }) : locationSources = List.unmodifiable(locationSources),
       vehicleTypes = Set.unmodifiable(vehicleTypes),
       compatibilitySources = List.unmodifiable(compatibilitySources),
       contactSources = List.unmodifiable(contactSources);

  final String cdaId, catalogName, municipality, departmentCode, status;
  final double? latitude, longitude;
  final double? locationScore;
  final String? address, phone, web;
  final String? locationMethod;
  final List<CdaEvidence> locationSources, compatibilitySources, contactSources;
  final Set<String> vehicleTypes;

  bool matches(CdaCatalogEntry entry) =>
      entry.id == cdaId &&
      _identity(entry.name) == _identity(catalogName) &&
      _identity(entry.municipality) == _identity(municipality) &&
      entry.departmentCode == departmentCode;

  bool verifiedAt(DateTime now) =>
      status == 'verified' &&
      latitude != null &&
      longitude != null &&
      addressVerifiedAt(now);

  bool mapEligibleAt(DateTime now) =>
      (status == 'geocoded' || status == 'verified') &&
      latitude != null &&
      longitude != null &&
      addressVerifiedAt(now);

  bool get isGeocoded => status == 'geocoded';

  bool addressVerifiedAt(DateTime now) =>
      (status == 'address_verified' ||
          status == 'geocoded' ||
          status == 'verified') &&
      (address?.trim().isNotEmpty ?? false) &&
      _evidenceValid(locationSources, now);

  Set<String> verifiedVehicleTypes(DateTime now) =>
      _evidenceValid(compatibilitySources, now) ? vehicleTypes : const {};
  bool contactsVerifiedAt(DateTime now) => _evidenceValid(contactSources, now);

  factory CdaSite.fromJson(Map<String, Object?> json) {
    String requiredString(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Invalid CDA $key.');
      }
      return value;
    }

    List<CdaEvidence> evidence(String key) => [
      for (final row in (json[key] as List<Object?>? ?? const []))
        CdaEvidence.fromJson(row as Map<String, Object?>),
    ];
    final lat = (json['latitude'] as num?)?.toDouble();
    final lon = (json['longitude'] as num?)?.toDouble();
    // Bounds are a sanity check, never a substitute for editorial sede verification.
    if ((lat == null) != (lon == null) ||
        (lat != null && (!lat.isFinite || lat < -5 || lat > 14)) ||
        (lon != null && (!lon.isFinite || lon < -82 || lon > -66))) {
      throw const FormatException('Invalid Colombian CDA coordinate.');
    }
    final status = requiredString('status');
    if (!{
      'pending',
      'address_verified',
      'geocoded',
      'verified',
      'rejected',
    }.contains(status)) {
      throw const FormatException('Invalid CDA status.');
    }
    final web = json['web'] as String?;
    if (web != null && !isCdaHttpsUrl(web)) {
      throw const FormatException('Invalid CDA website.');
    }
    final types = (json['vehicleTypes'] as List<Object?>? ?? const [])
        .cast<String>()
        .toSet();
    if (!types.every({'car', 'motorcycle'}.contains)) {
      throw const FormatException('Invalid CDA vehicle type.');
    }
    final phone = json['phone'] as String?;
    if (phone != null && !RegExp(r'^\+?[0-9 ()-]{7,24}$').hasMatch(phone)) {
      throw const FormatException('Invalid CDA phone.');
    }
    return CdaSite(
      cdaId: requiredString('cdaId'),
      catalogName: requiredString('catalogName'),
      municipality: requiredString('municipality'),
      departmentCode: requiredString('departmentCode'),
      status: status,
      latitude: lat,
      longitude: lon,
      address: json['address'] as String?,
      locationMethod: json['locationMethod'] as String?,
      locationScore: (json['locationScore'] as num?)?.toDouble(),
      locationSources: evidence('locationSources'),
      vehicleTypes: types,
      compatibilitySources: evidence('compatibilitySources'),
      phone: phone,
      web: web,
      contactSources: evidence('contactSources'),
    );
  }
}

class CdaGeography {
  CdaGeography({
    required this.version,
    required this.catalogPeriod,
    required this.approved,
    required List<CdaSite> sites,
  }) : sites = List.unmodifiable(sites),
       byId = Map.unmodifiable({for (final site in sites) site.cdaId: site}) {
    if (byId.length != sites.length) {
      throw const FormatException('Duplicate CDA geography ID.');
    }
  }
  final String version, catalogPeriod;
  final bool approved;
  final List<CdaSite> sites;
  final Map<String, CdaSite> byId;

  factory CdaGeography.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != 1 ||
        json['version'] is! String ||
        json['catalogPeriod'] is! String ||
        json['approved'] is! bool ||
        json['entries'] is! List) {
      throw const FormatException('Unsupported CDA geography schema.');
    }
    return CdaGeography(
      version: json['version'] as String,
      catalogPeriod: json['catalogPeriod'] as String,
      approved: json['approved'] as bool,
      sites: [
        for (final row in json['entries'] as List<Object?>)
          CdaSite.fromJson(row as Map<String, Object?>),
      ],
    );
  }

  CdaCoverage coverage(CdaCatalog catalog, {required DateTime now}) {
    final pending = <String>[];
    var addressVerifiedCount = 0;
    var mapEligibleCount = 0;
    var operationalTotal = 0;
    final ids = catalog.entries.map((entry) => entry.id).toSet();
    final matchedOperationalIds = <String>{};
    for (final entry in catalog.entries) {
      final site = byId[entry.id];
      if (site != null && site.matches(entry) && site.addressVerifiedAt(now)) {
        addressVerifiedCount++;
        operationalTotal++;
        matchedOperationalIds.add(entry.id);
      }
      if (site != null && site.matches(entry) && site.mapEligibleAt(now)) {
        mapEligibleCount++;
      } else {
        pending.add(entry.id);
      }
    }
    final periodMatches =
        catalogPeriod ==
        '${catalog.source.latestSourceYear}-${catalog.source.latestSourceMonth.toString().padLeft(2, '0')}';
    return CdaCoverage(
      total: catalog.entries.length,
      operationalTotal: operationalTotal,
      missingInventoryCount: catalog.entries.length - operationalTotal,
      pendingIds: List.unmodifiable(pending),
      addressVerifiedCount: addressVerifiedCount,
      mapEligibleCount: mapEligibleCount,
      mapEnabled:
          approved &&
          periodMatches &&
          operationalTotal > 0 &&
          mapEligibleCount == operationalTotal &&
          byId.keys.every(ids.contains) &&
          byId.keys.toSet().difference(matchedOperationalIds).isEmpty,
    );
  }
}

class CdaCoverage {
  const CdaCoverage({
    required this.total,
    required this.operationalTotal,
    required this.missingInventoryCount,
    required this.pendingIds,
    required this.addressVerifiedCount,
    required this.mapEligibleCount,
    required this.mapEnabled,
  });
  final int total;
  final int operationalTotal;
  final int missingInventoryCount;
  final List<String> pendingIds;
  final int addressVerifiedCount;
  final int mapEligibleCount;
  final bool mapEnabled;
  int get verifiedCount => mapEligibleCount;
}

bool _evidenceValid(List<CdaEvidence> sources, DateTime now) =>
    sources.isNotEmpty && sources.every((source) => source.validAt(now));
String _identity(String value) =>
    value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
