import 'dart:convert';

import 'package:flutter/services.dart';

const tollDatasetManifestAssetPath = 'assets/catalogs/tolls_manifest_v1.json';
const tollInventoryAssetPath = 'assets/catalogs/tolls_inventory_v1.json';
const tollTariffAssetPath = 'assets/catalogs/tolls_tariffs_v1.json';

Future<TollDatasetManifest> loadTollDatasetManifest(AssetBundle bundle) async {
  return TollDatasetManifest.fromJsonString(
    await bundle.loadString(tollDatasetManifestAssetPath),
  );
}

class TollDatasetManifest {
  const TollDatasetManifest({
    required this.version,
    required this.inventory,
    required this.tariffs,
  });

  final String version;
  final TollInventoryManifest inventory;
  final TollTariffManifest tariffs;

  factory TollDatasetManifest.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?> ||
        decoded['schemaVersion'] != 1 ||
        decoded['datasetKey'] != 'tolls_national_coverage') {
      throw const FormatException('Invalid toll manifest');
    }
    return TollDatasetManifest(
      version: _string(decoded, 'version'),
      inventory: TollInventoryManifest.fromJson(_map(decoded, 'inventory')),
      tariffs: TollTariffManifest.fromJson(_map(decoded, 'tariffs')),
    );
  }
}

class TollInventoryManifest {
  const TollInventoryManifest({
    required this.version,
    required this.sourceSnapshotDate,
    required this.sourceUrl,
    required this.assetBytes,
    required this.assetSha256,
    required this.stationCount,
    required this.verifiedChargeEventCount,
    required this.unknownTariffStationCount,
    required this.currentOperationConfirmed,
    required this.operationCounts,
  });

  final String version;
  final String sourceSnapshotDate;
  final String sourceUrl;
  final int assetBytes;
  final String assetSha256;
  final int stationCount;
  final int verifiedChargeEventCount;
  final int unknownTariffStationCount;
  final bool currentOperationConfirmed;
  final Map<String, int> operationCounts;

  factory TollInventoryManifest.fromJson(Map<String, Object?> json) {
    final asset = _asset(json, 'tolls_inventory_v1.json');
    final operationCounts = _map(
      json,
      'operationCounts',
    ).map((key, value) => MapEntry(key, _intValue(value, key)));
    final stationCount = _int(json, 'stationCount');
    if (operationCounts.values.fold<int>(0, (sum, value) => sum + value) !=
            stationCount ||
        _int(json, 'verifiedChargeEventCount') != 0 ||
        _int(json, 'unknownTariffStationCount') != stationCount ||
        _bool(json, 'currentOperationConfirmed')) {
      throw const FormatException('Unsafe toll inventory semantics');
    }
    return TollInventoryManifest(
      version: _string(json, 'version'),
      sourceSnapshotDate: _string(json, 'sourceSnapshotDate'),
      sourceUrl: _https(json, 'sourceUrl'),
      assetBytes: asset.$1,
      assetSha256: asset.$2,
      stationCount: stationCount,
      verifiedChargeEventCount: 0,
      unknownTariffStationCount: stationCount,
      currentOperationConfirmed: false,
      operationCounts: Map.unmodifiable(operationCounts),
    );
  }
}

class TollTariffManifest {
  const TollTariffManifest({
    required this.version,
    required this.consultationCutoffAsStated,
    required this.independentExternalReverification,
    required this.assetBytes,
    required this.assetSha256,
    required this.stationCount,
    required this.generalRateCount,
    required this.numericGeneralRateCount,
    required this.officialGeneralRateCount,
    required this.secondaryGeneralRateCount,
    required this.specialRateCount,
    required this.candidatesOutsideBase,
  });

  final String version;
  final String consultationCutoffAsStated;
  final bool independentExternalReverification;
  final int assetBytes;
  final String assetSha256;
  final int stationCount;
  final int generalRateCount;
  final int numericGeneralRateCount;
  final int officialGeneralRateCount;
  final int secondaryGeneralRateCount;
  final int specialRateCount;
  final int candidatesOutsideBase;

  factory TollTariffManifest.fromJson(Map<String, Object?> json) {
    final asset = _asset(json, 'tolls_tariffs_v1.json');
    if (_bool(json, 'independentExternalReverification')) {
      throw const FormatException('Unexpected toll external reverification');
    }
    return TollTariffManifest(
      version: _string(json, 'version'),
      consultationCutoffAsStated: _string(json, 'consultationCutoffAsStated'),
      independentExternalReverification: false,
      assetBytes: asset.$1,
      assetSha256: asset.$2,
      stationCount: _int(json, 'stationCount'),
      generalRateCount: _int(json, 'generalRateCount'),
      numericGeneralRateCount: _int(json, 'numericGeneralRateCount'),
      officialGeneralRateCount: _int(json, 'officialGeneralRateCount'),
      secondaryGeneralRateCount: _int(json, 'secondaryGeneralRateCount'),
      specialRateCount: _int(json, 'specialRateCount'),
      candidatesOutsideBase: _int(json, 'candidatesOutsideBase'),
    );
  }
}

(int, String) _asset(Map<String, Object?> json, String expectedPath) {
  final asset = _map(json, 'asset');
  if (_string(asset, 'path') != expectedPath) {
    throw const FormatException('Unexpected toll asset path');
  }
  final sha = _string(asset, 'sha256');
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(sha)) {
    throw const FormatException('Invalid toll asset hash');
  }
  return (_int(asset, 'bytes'), sha);
}

Map<String, Object?> _map(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! Map<String, Object?>) throw FormatException('Invalid $key');
  return value;
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid $key');
  }
  return value;
}

String _https(Map<String, Object?> json, String key) {
  final value = _string(json, key);
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    throw FormatException('Invalid $key');
  }
  return value;
}

int _int(Map<String, Object?> json, String key) => _intValue(json[key], key);

int _intValue(Object? value, String key) {
  if (value is! int || value < 0) throw FormatException('Invalid $key');
  return value;
}

bool _bool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('Invalid $key');
  return value;
}
