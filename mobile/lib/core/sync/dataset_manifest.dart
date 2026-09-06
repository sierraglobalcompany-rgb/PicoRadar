class DatasetManifest {
  const DatasetManifest({
    required this.schemaVersion,
    required this.generatedAt,
    required this.minAppVersion,
    required this.datasets,
    required this.features,
  });

  factory DatasetManifest.fromJson(Map<String, dynamic> json) {
    final schemaVersion = _int(json, 'schemaVersion');
    if (schemaVersion != 1) {
      throw ManifestFormatException(
        'Unsupported manifest schemaVersion: $schemaVersion.',
      );
    }

    final datasetsJson = _map(json, 'datasets');
    return DatasetManifest(
      schemaVersion: schemaVersion,
      generatedAt: DateTime.parse(_string(json, 'generatedAt')),
      minAppVersion: _string(json, 'minAppVersion'),
      datasets: datasetsJson.map(
        (key, value) => MapEntry(
          key,
          DatasetManifestEntry.fromJson(_mapValue(value, 'datasets.$key')),
        ),
      ),
      features: _optionalBoolMap(json['features']),
    );
  }

  final int schemaVersion;
  final DateTime generatedAt;
  final String minAppVersion;
  final Map<String, DatasetManifestEntry> datasets;
  final Map<String, bool> features;
}

class DatasetManifestEntry {
  const DatasetManifestEntry({
    required this.version,
    required this.url,
    required this.sha256,
    this.contentEncoding,
    this.expiresAt,
    this.sourceTimestamp,
  });

  factory DatasetManifestEntry.fromJson(Map<String, dynamic> json) {
    final version = json['version']?.toString().trim();
    if (version == null || version.isEmpty) {
      throw const ManifestFormatException('Dataset version is required.');
    }

    final contentEncoding = json['contentEncoding']?.toString().trim();
    final expiresAt = json['expiresAt']?.toString().trim();
    final sourceTimestamp = json['sourceTimestamp']?.toString().trim();
    final sha256 = _string(json, 'sha256').toLowerCase();
    if (!_sha256Pattern.hasMatch(sha256)) {
      throw ManifestFormatException('Invalid sha256 for dataset $version.');
    }

    return DatasetManifestEntry(
      version: version,
      url: _string(json, 'url'),
      sha256: sha256,
      contentEncoding: contentEncoding == null || contentEncoding.isEmpty
          ? null
          : contentEncoding,
      expiresAt: expiresAt == null || expiresAt.isEmpty
          ? null
          : DateTime.parse(expiresAt),
      sourceTimestamp: sourceTimestamp == null || sourceTimestamp.isEmpty
          ? null
          : DateTime.parse(sourceTimestamp),
    );
  }

  final String version;
  final String url;
  final String sha256;
  final String? contentEncoding;
  final DateTime? expiresAt;
  final DateTime? sourceTimestamp;
}

class ManifestFormatException implements Exception {
  const ManifestFormatException(this.message);

  final String message;

  @override
  String toString() => 'ManifestFormatException: $message';
}

final _sha256Pattern = RegExp(r'^[a-f0-9]{64}$');

int _int(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  throw ManifestFormatException('$key must be an integer.');
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  throw ManifestFormatException('$key must be a non-empty string.');
}

Map<String, dynamic> _map(Map<String, dynamic> json, String key) {
  return _mapValue(json[key], key);
}

Map<String, dynamic> _mapValue(Object? value, String key) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  throw ManifestFormatException('$key must be an object.');
}

Map<String, bool> _optionalBoolMap(Object? value) {
  if (value == null) {
    return const {};
  }
  if (value is! Map) {
    throw const ManifestFormatException('features must be an object.');
  }

  final result = <String, bool>{};
  for (final entry in value.entries) {
    if (entry.value is! bool) {
      throw ManifestFormatException('features.${entry.key} must be a boolean.');
    }
    result[entry.key.toString()] = entry.value as bool;
  }
  return result;
}
