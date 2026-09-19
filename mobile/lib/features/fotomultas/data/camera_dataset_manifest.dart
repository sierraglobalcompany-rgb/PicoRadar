import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const cameraDatasetManifestAssetPath =
    'assets/datasets/cameras/cameras_manifest_v1.json';
const cameraDatasetAssetPath = 'assets/datasets/cameras/cameras_v1.json';

final cameraDatasetManifestProvider = FutureProvider<CameraDatasetManifest>((
  ref,
) async {
  final source = await rootBundle.loadString(cameraDatasetManifestAssetPath);
  return CameraDatasetManifest.fromJsonString(source);
});

class CameraDatasetManifest {
  const CameraDatasetManifest({
    required this.version,
    required this.recordCount,
    required this.speedKnownCount,
    required this.speedUnknownCount,
    required this.departmentCount,
    required this.snapshotOnly,
    required this.currentOperationConfirmed,
    required this.sourceAsOf,
    required this.sourceUrl,
    required this.assetBytes,
    required this.assetSha256,
  });

  final String version;
  final int recordCount;
  final int speedKnownCount;
  final int speedUnknownCount;
  final int departmentCount;
  final bool snapshotOnly;
  final bool currentOperationConfirmed;
  final String sourceAsOf;
  final String sourceUrl;
  final int assetBytes;
  final String assetSha256;

  factory CameraDatasetManifest.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?> ||
        decoded['schemaVersion'] != 1 ||
        decoded['datasetKey'] != 'traffic_cameras') {
      throw const FormatException('Invalid camera manifest');
    }
    final asset = _map(decoded, 'asset');
    final semantics = _map(decoded, 'semantics');
    final freshness = _map(decoded, 'freshness');
    final sourceMetadata = _map(decoded, 'source');
    final recordCount = _int(decoded, 'recordCount');
    final known = _int(decoded, 'speedKnownCount');
    final unknown = _int(decoded, 'speedUnknownCount');
    final snapshotOnly = _bool(semantics, 'snapshotOnly');
    final currentOperationConfirmed = _bool(
      semantics,
      'currentOperationConfirmed',
    );
    if (recordCount != known + unknown ||
        !snapshotOnly ||
        currentOperationConfirmed ||
        _string(semantics, 'inventoryKind') != 'authorized_location_snapshot' ||
        _string(asset, 'path') != 'cameras_v1.json') {
      throw const FormatException('Unsafe camera manifest semantics');
    }
    final sha = _string(asset, 'sha256');
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(sha)) {
      throw const FormatException('Invalid camera asset hash');
    }
    return CameraDatasetManifest(
      version: _string(decoded, 'version'),
      recordCount: recordCount,
      speedKnownCount: known,
      speedUnknownCount: unknown,
      departmentCount: _int(decoded, 'departmentCount'),
      snapshotOnly: snapshotOnly,
      currentOperationConfirmed: currentOperationConfirmed,
      sourceAsOf: _string(freshness, 'asOf'),
      sourceUrl: _https(sourceMetadata, 'url'),
      assetBytes: _int(asset, 'bytes'),
      assetSha256: sha,
    );
  }
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
    throw FormatException('Invalid URL: $key');
  }
  return value;
}

int _int(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int || value < 0) throw FormatException('Invalid $key');
  return value;
}

bool _bool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('Invalid $key');
  return value;
}
