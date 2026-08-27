import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../config/app_config.dart';
import '../database/app_database.dart';
import '../storage/app_preferences.dart';
import 'dataset_manifest.dart';

typedef DatasetImporter = Future<void> Function(
  AppDatabase db,
  Map<String, dynamic> json,
);

class DatasetSyncService {
  DatasetSyncService({
    required this.database,
    required this.preferences,
    required this.config,
    required this.importers,
    Dio? http,
    Directory? tempDirectory,
  }) : http =
           http ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 30),
             ),
           ),
       tempDirectory = tempDirectory ?? Directory.systemTemp;

  static const manifestEtagPreferenceKey = 'manifest_etag_v1';

  final AppDatabase database;
  final AppPreferences preferences;
  final AppConfig config;
  final Map<String, DatasetImporter> importers;
  final Dio http;
  final Directory tempDirectory;

  Future<DatasetSyncResult> sync() async {
    final headers = <String, String>{};
    final etag = await preferences.getString(manifestEtagPreferenceKey);
    if (etag != null && etag.isNotEmpty) {
      headers[HttpHeaders.ifNoneMatchHeader] = etag;
    }

    final manifestResponse = await http.getUri<Object?>(
      config.manifestUri,
      options: Options(
        headers: headers,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    if (manifestResponse.statusCode == HttpStatus.notModified) {
      return const DatasetSyncResult(notModified: true);
    }
    if (manifestResponse.statusCode != HttpStatus.ok) {
      throw DatasetSyncException(
        'Manifest request failed with HTTP ${manifestResponse.statusCode}.',
      );
    }

    final manifest = DatasetManifest.fromJson(
      _manifestMap(manifestResponse.data),
    );
    final result = DatasetSyncResultBuilder();

    for (final entry in manifest.datasets.entries) {
      await _syncDataset(entry.key, entry.value, result);
    }

    final newEtag = manifestResponse.headers.value(HttpHeaders.etagHeader);
    if (newEtag != null && newEtag.isNotEmpty) {
      await preferences.setString(manifestEtagPreferenceKey, newEtag);
    }

    return result.build();
  }

  Future<void> _syncDataset(
    String datasetKey,
    DatasetManifestEntry entry,
    DatasetSyncResultBuilder result,
  ) async {
    final importer = importers[datasetKey];
    if (importer == null) {
      result.skippedMissingImporter.add(datasetKey);
      return;
    }

    final localVersion = await _localDatasetVersion(datasetKey);
    if (localVersion?.version == entry.version &&
        localVersion?.status == 'installed') {
      result.skippedCurrent.add(datasetKey);
      return;
    }

    final uri = _resolveDatasetUri(entry.url);
    await tempDirectory.create(recursive: true);
    final tempFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}'
      '${_safeFileName(datasetKey)}-${DateTime.now().microsecondsSinceEpoch}',
    );

    try {
      final bytes = await _downloadToTemp(uri, tempFile);
      final actualSha256 = await _sha256Hex(bytes);
      if (actualSha256 != entry.sha256) {
        throw DatasetSyncException(
          'SHA-256 mismatch for $datasetKey: expected ${entry.sha256}, '
          'got $actualSha256.',
        );
      }

      final payload = _decodeDatasetPayload(datasetKey, entry, bytes);
      await database.transaction(() async {
        await importer(database, payload);
        await _writeDatasetVersion(datasetKey, entry);
      });
      result.imported.add(datasetKey);
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  Future<List<int>> _downloadToTemp(Uri uri, File tempFile) async {
    final response = await http.getUri<Object?>(
      uri,
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: false,
        validateStatus: (status) =>
            status != null &&
            status >= HttpStatus.ok &&
            status < HttpStatus.multipleChoices,
      ),
    );
    final data = response.data;
    if (data is! List<int>) {
      throw DatasetSyncException('Dataset response was not bytes: $uri.');
    }

    final bytes = List<int>.from(data);
    await tempFile.writeAsBytes(bytes, flush: true);
    return bytes;
  }

  Map<String, dynamic> _decodeDatasetPayload(
    String datasetKey,
    DatasetManifestEntry entry,
    List<int> bytes,
  ) {
    final decodedBytes = switch (entry.contentEncoding) {
      null => bytes,
      'gzip' => gzip.decode(bytes),
      final encoding => throw DatasetSyncException(
        'Unsupported contentEncoding for $datasetKey: $encoding.',
      ),
    };

    final decodedJson = jsonDecode(utf8.decode(decodedBytes));
    if (decodedJson is Map) {
      return Map<String, dynamic>.from(decodedJson);
    }
    throw DatasetSyncException('Dataset payload must be a JSON object.');
  }

  Uri _resolveDatasetUri(String url) {
    final parsed = Uri.parse(url);
    final resolved = parsed.hasScheme ? parsed : config.cdnBaseUri.resolve(url);
    if (!_sameOrigin(resolved, config.cdnBaseUri)) {
      throw DatasetSyncException(
        'Dataset URL origin is not allowed: $resolved.',
      );
    }
    return resolved;
  }

  bool _sameOrigin(Uri left, Uri right) {
    return left.scheme == right.scheme &&
        left.host == right.host &&
        _effectivePort(left) == _effectivePort(right);
  }

  int _effectivePort(Uri uri) {
    if (uri.hasPort) {
      return uri.port;
    }
    return uri.scheme == 'https' ? 443 : 80;
  }

  Future<DatasetVersion?> _localDatasetVersion(String datasetKey) async {
    final rows = await (database.select(
      database.datasetVersions,
    )..where((row) => row.datasetKey.equals(datasetKey))).get();
    if (rows.isEmpty) {
      return null;
    }
    return rows.single;
  }

  Future<void> _writeDatasetVersion(
    String datasetKey,
    DatasetManifestEntry entry,
  ) async {
    final now = DateTime.now().toUtc();
    final existing = await _localDatasetVersion(datasetKey);
    if (existing == null) {
      await database
          .into(database.datasetVersions)
          .insert(
            DatasetVersionsCompanion.insert(
              id: datasetKey,
              datasetKey: datasetKey,
              version: entry.version,
              sha256: Value(entry.sha256),
              status: 'installed',
              appliedAt: Value(now),
            ),
          );
      return;
    }

    await (database.update(
      database.datasetVersions,
    )..where((row) => row.datasetKey.equals(datasetKey))).write(
      DatasetVersionsCompanion(
        version: Value(entry.version),
        sha256: Value(entry.sha256),
        status: const Value('installed'),
        appliedAt: Value(now),
      ),
    );
  }

  String _safeFileName(String datasetKey) {
    return datasetKey.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
  }

  Map<String, dynamic> _manifestMap(Object? data) {
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    }
    if (data is List<int>) {
      final decoded = jsonDecode(utf8.decode(data));
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    }
    throw const DatasetSyncException('Manifest payload must be a JSON object.');
  }

  Future<String> _sha256Hex(List<int> bytes) async {
    final hash = await Sha256().hash(bytes);
    return hash.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}

class DatasetSyncResult {
  const DatasetSyncResult({
    this.notModified = false,
    this.imported = const [],
    this.skippedCurrent = const [],
    this.skippedMissingImporter = const [],
  });

  final bool notModified;
  final List<String> imported;
  final List<String> skippedCurrent;
  final List<String> skippedMissingImporter;
}

class DatasetSyncResultBuilder {
  final imported = <String>[];
  final skippedCurrent = <String>[];
  final skippedMissingImporter = <String>[];

  DatasetSyncResult build() {
    return DatasetSyncResult(
      imported: List.unmodifiable(imported),
      skippedCurrent: List.unmodifiable(skippedCurrent),
      skippedMissingImporter: List.unmodifiable(skippedMissingImporter),
    );
  }
}

class DatasetSyncException implements Exception {
  const DatasetSyncException(this.message);

  final String message;

  @override
  String toString() => 'DatasetSyncException: $message';
}
