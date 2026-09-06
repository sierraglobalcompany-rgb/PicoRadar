import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../config/app_config.dart';
import '../database/app_database.dart';
import '../storage/app_preferences.dart';
import 'bounded_stream.dart';
import 'dataset_manifest.dart';

typedef DatasetImporter = Future<void> Function(
  AppDatabase db,
  Map<String, dynamic> json,
);

typedef PrepareTransactionalDatasetImport =
    Future<PreparedDatasetImport> Function(
      AppDatabase db,
      Map<String, dynamic> json,
      List<int> verifiedBytes,
      String sha256,
    );

typedef ValidateInstalledDataset = Future<bool> Function(
  AppDatabase db,
  DatasetVersion installedVersion,
);

class TransactionalDatasetImporter {
  const TransactionalDatasetImporter({
    required this.prepare,
    required this.isInstalledVersionUsable,
  });

  final PrepareTransactionalDatasetImport prepare;
  final ValidateInstalledDataset isInstalledVersionUsable;

  Future<PreparedDatasetImport> call(
    AppDatabase db,
    Map<String, dynamic> json,
    List<int> verifiedBytes,
    String sha256,
  ) => prepare(db, json, verifiedBytes, sha256);
}

abstract interface class PreparedDatasetImport {
  Future<void> activate();

  Future<void> commit();

  Future<void> rollback();
}

class DatasetSyncService {
  DatasetSyncService({
    required this.database,
    required this.preferences,
    required this.config,
    required this.importers,
    this.transactionalImporters = const {},
    Dio? http,
    Directory? tempDirectory,
    this.currentAppVersion = '1.0.0',
    DateTime Function()? now,
    this.maxManifestBytes = 64 * 1024,
    this.maxDownloadBytes = 4 * 1024 * 1024,
    this.maxDecodedBytes = 16 * 1024 * 1024,
  }) : http =
           http ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 30),
             ),
           ),
       tempDirectory = tempDirectory ?? Directory.systemTemp,
       now = now ?? DateTime.now {
    if (maxManifestBytes <= 0 ||
        maxDownloadBytes <= 0 ||
        maxDecodedBytes <= 0) {
      throw ArgumentError('Dataset byte limits must be positive.');
    }
    final duplicateKeys = importers.keys.toSet().intersection(
      transactionalImporters.keys.toSet(),
    );
    if (duplicateKeys.isNotEmpty) {
      throw ArgumentError(
        'Dataset importers must use one protocol: ${duplicateKeys.join(', ')}.',
      );
    }
  }

  static const manifestEtagPreferenceKey = 'manifest_etag_v1';

  final AppDatabase database;
  final AppPreferences preferences;
  final AppConfig config;
  final Map<String, DatasetImporter> importers;
  final Map<String, TransactionalDatasetImporter> transactionalImporters;
  final Dio http;
  final Directory tempDirectory;
  final String currentAppVersion;
  final DateTime Function() now;
  final int maxManifestBytes;
  final int maxDownloadBytes;
  final int maxDecodedBytes;

  Future<DatasetSyncResult> sync({CancelToken? cancelToken}) async {
    final headers = <String, String>{};
    final etag = await preferences.getString(manifestEtagPreferenceKey);
    if (etag != null && etag.isNotEmpty) {
      headers[HttpHeaders.ifNoneMatchHeader] = etag;
    }

    var manifestResponse = await _requestManifest(headers, cancelToken);

    if (manifestResponse.statusCode == HttpStatus.notModified) {
      if (await _installedDatasetsAreUsable()) {
        return const DatasetSyncResult(notModified: true);
      }
      manifestResponse = await _requestManifest(const {}, cancelToken);
      if (manifestResponse.statusCode == HttpStatus.notModified) {
        throw const DatasetSyncException(
          'Manifest returned 304 during unconditional recovery request.',
        );
      }
    }
    if (manifestResponse.statusCode != HttpStatus.ok) {
      throw DatasetSyncException(
        'Manifest request failed with HTTP ${manifestResponse.statusCode}.',
      );
    }

    _validateDeclaredLength(
      manifestResponse.headers,
      maxManifestBytes,
      'Manifest response',
    );
    final manifestBytes = await _collectResponseBytes(
      manifestResponse.data,
      maxManifestBytes,
      'Manifest response',
    );
    final manifest = DatasetManifest.fromJson(_manifestMap(manifestBytes));
    _validateManifest(manifest);
    final result = DatasetSyncResultBuilder();

    for (final entry in manifest.datasets.entries) {
      await _syncDataset(entry.key, entry.value, result, cancelToken);
    }

    final newEtag = manifestResponse.headers.value(HttpHeaders.etagHeader);
    if (newEtag != null && newEtag.isNotEmpty) {
      await preferences.setString(manifestEtagPreferenceKey, newEtag);
    }

    return result.build();
  }

  Future<Response<ResponseBody>> _requestManifest(
    Map<String, String> headers,
    CancelToken? cancelToken,
  ) {
    return http.getUri<ResponseBody>(
      config.manifestUri,
      cancelToken: cancelToken,
      options: Options(
        headers: headers,
        responseType: ResponseType.stream,
        followRedirects: false,
        validateStatus: (status) => status != null,
      ),
    );
  }

  Future<bool> _installedDatasetsAreUsable() async {
    final datasetKeys = {...importers.keys, ...transactionalImporters.keys};
    for (final datasetKey in datasetKeys) {
      final installed = await _localDatasetVersion(datasetKey);
      if (installed == null || installed.status != 'installed') {
        return false;
      }
      final transactionalImporter = transactionalImporters[datasetKey];
      if (transactionalImporter != null &&
          !await transactionalImporter.isInstalledVersionUsable(
            database,
            installed,
          )) {
        return false;
      }
    }
    return true;
  }

  Future<void> _syncDataset(
    String datasetKey,
    DatasetManifestEntry entry,
    DatasetSyncResultBuilder result,
    CancelToken? cancelToken,
  ) async {
    final importer = importers[datasetKey];
    final transactionalImporter = transactionalImporters[datasetKey];
    if (importer == null && transactionalImporter == null) {
      result.skippedMissingImporter.add(datasetKey);
      return;
    }

    final currentTime = now().toUtc();
    if (entry.expiresAt != null &&
        !currentTime.isBefore(entry.expiresAt!.toUtc())) {
      throw DatasetSyncException('Dataset $datasetKey manifest entry expired.');
    }

    final localVersion = await _localDatasetVersion(datasetKey);
    if (localVersion?.status == 'installed') {
      _validatePublicationOrder(datasetKey, entry, localVersion!);
    }
    if (localVersion?.version == entry.version &&
        localVersion?.status == 'installed') {
      final installedHash = localVersion?.sha256?.trim();
      if (installedHash != null &&
          installedHash.isNotEmpty &&
          installedHash != entry.sha256) {
        throw DatasetSyncException(
          'Dataset $datasetKey reuses version ${entry.version} with a '
          'different SHA-256.',
        );
      }
      final installedStateUsable =
          transactionalImporter == null ||
          await transactionalImporter.isInstalledVersionUsable(
            database,
            localVersion!,
          );
      if (installedStateUsable) {
        if (entry.publicationRevision != null &&
            entry.publicationRevision! > localVersion!.publicationRevision) {
          await database.transaction(
            () => _writeDatasetVersion(datasetKey, entry),
          );
        }
        result.skippedCurrent.add(datasetKey);
        return;
      }
    }

    final uri = _resolveDatasetUri(entry.url);
    await tempDirectory.create(recursive: true);
    final tempFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}'
      '${_safeFileName(datasetKey)}-${DateTime.now().microsecondsSinceEpoch}',
    );
    final decodedFile = File('${tempFile.path}.decoded');

    try {
      await _downloadToTemp(uri, tempFile, cancelToken);
      final actualSha256 = await _sha256File(tempFile);
      if (actualSha256 != entry.sha256) {
        throw DatasetSyncException(
          'SHA-256 mismatch for $datasetKey: expected ${entry.sha256}, '
          'got $actualSha256.',
        );
      }

      final decoded = await _decodeDatasetPayload(
        datasetKey,
        entry,
        tempFile,
        decodedFile,
      );
      _validatePayloadMetadata(datasetKey, entry, decoded.json);
      PreparedDatasetImport? prepared;
      if (transactionalImporter != null) {
        if (entry.contentEncoding != null) {
          throw DatasetSyncException(
            'Transactional importer $datasetKey requires unencoded bytes.',
          );
        }
        prepared = await transactionalImporter(
          database,
          decoded.json,
          decoded.bytes,
          entry.sha256,
        );
      }
      try {
        await database.transaction(() async {
          if (prepared != null) {
            await prepared.activate();
          } else {
            await importer!(database, decoded.json);
          }
          await _writeDatasetVersion(datasetKey, entry);
        });
      } catch (error, stackTrace) {
        if (prepared != null) {
          try {
            await prepared.rollback();
          } catch (rollbackError) {
            throw DatasetSyncException(
              'Dataset $datasetKey failed and snapshot rollback also failed: '
              '$error; rollback: $rollbackError',
            );
          }
        }
        Error.throwWithStackTrace(error, stackTrace);
      }
      await prepared?.commit();
      result.imported.add(datasetKey);
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      if (await decodedFile.exists()) {
        await decodedFile.delete();
      }
    }
  }

  Future<void> _downloadToTemp(
    Uri uri,
    File tempFile,
    CancelToken? cancelToken,
  ) async {
    final response = await http.getUri<ResponseBody>(
      uri,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: false,
        validateStatus: (status) => status != null,
      ),
    );
    if (response.statusCode != HttpStatus.ok) {
      throw DatasetSyncException(
        'Dataset request failed with HTTP ${response.statusCode}: $uri.',
      );
    }
    _validateDeclaredLength(
      response.headers,
      maxDownloadBytes,
      'Dataset response for $uri',
    );
    final body = response.data;
    if (body == null) {
      throw DatasetSyncException('Dataset response had no body: $uri.');
    }
    try {
      await writeBoundedStream(
        body.stream,
        tempFile,
        maxBytes: maxDownloadBytes,
        label: 'Dataset response for $uri',
      );
    } on BoundedStreamException catch (error) {
      throw DatasetSyncException(error.message);
    }
  }

  Future<_DecodedDatasetPayload> _decodeDatasetPayload(
    String datasetKey,
    DatasetManifestEntry entry,
    File downloadedFile,
    File decodedFile,
  ) async {
    try {
      final File payloadFile;
      if (entry.contentEncoding == null) {
        if (await downloadedFile.length() > maxDecodedBytes) {
          throw DatasetSyncException(
            'Dataset $datasetKey exceeds decoded byte limit.',
          );
        }
        payloadFile = downloadedFile;
      } else if (entry.contentEncoding == 'gzip') {
        try {
          await writeBoundedStream(
            downloadedFile.openRead().transform(gzip.decoder),
            decodedFile,
            maxBytes: maxDecodedBytes,
            label: 'Decoded dataset $datasetKey',
          );
        } on BoundedStreamException catch (error) {
          throw DatasetSyncException(error.message);
        }
        payloadFile = decodedFile;
      } else {
        throw DatasetSyncException(
          'Unsupported contentEncoding for $datasetKey: '
          '${entry.contentEncoding}.',
        );
      }

      final decodedBytes = await payloadFile.readAsBytes();
      final decodedJson = jsonDecode(utf8.decode(decodedBytes));
      if (decodedJson is Map) {
        return _DecodedDatasetPayload(
          Map<String, dynamic>.from(decodedJson),
          decodedBytes,
        );
      }
      throw const DatasetSyncException(
        'Dataset payload must be a JSON object.',
      );
    } on DatasetSyncException {
      rethrow;
    } on FormatException catch (error) {
      throw DatasetSyncException(
        'Dataset $datasetKey is not valid UTF-8 JSON: $error',
      );
    } on FileSystemException catch (error) {
      throw DatasetSyncException(
        'Dataset $datasetKey stream decoding failed: $error',
      );
    }
  }

  void _validateManifest(DatasetManifest manifest) {
    final currentTime = now().toUtc();
    if (manifest.generatedAt.toUtc().isAfter(
      currentTime.add(const Duration(minutes: 5)),
    )) {
      throw const DatasetSyncException(
        'Manifest generatedAt is in the future.',
      );
    }
    final requiredVersion = _orderedVersion(manifest.minAppVersion);
    final installedVersion = _orderedVersion(currentAppVersion);
    if (requiredVersion == null || installedVersion == null) {
      throw const DatasetSyncException(
        'Manifest and app versions must be numeric dotted versions.',
      );
    }
    if (_compareOrderedVersions(installedVersion, requiredVersion) < 0) {
      throw DatasetSyncException(
        'Manifest requires app ${manifest.minAppVersion}; installed '
        '$currentAppVersion.',
      );
    }
  }

  void _validatePayloadMetadata(
    String datasetKey,
    DatasetManifestEntry entry,
    Map<String, dynamic> payload,
  ) {
    final payloadKey = payload['datasetKey'];
    if (payloadKey != null && payloadKey != datasetKey) {
      throw DatasetSyncException(
        'Dataset payload key does not match manifest key $datasetKey.',
      );
    }
    final payloadVersion = payload['version'];
    if (payloadVersion != null && payloadVersion.toString() != entry.version) {
      throw DatasetSyncException(
        'Dataset $datasetKey payload version does not match manifest.',
      );
    }
    final expectedSourceTimestamp = entry.sourceTimestamp;
    if (expectedSourceTimestamp == null) {
      return;
    }
    final rawTimestamp =
        payload['sourceTimestamp'] ??
        payload['sourceSnapshotDate'] ??
        payload['generatedAt'];
    if (rawTimestamp is! String || rawTimestamp.trim().isEmpty) {
      throw DatasetSyncException(
        'Dataset $datasetKey source timestamp is required by manifest.',
      );
    }
    final normalized = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(rawTimestamp)
        ? '${rawTimestamp}T00:00:00Z'
        : rawTimestamp;
    final actualSourceTimestamp = DateTime.tryParse(normalized);
    if (actualSourceTimestamp == null ||
        actualSourceTimestamp.toUtc() != expectedSourceTimestamp.toUtc()) {
      throw DatasetSyncException(
        'Dataset $datasetKey source timestamp does not match manifest.',
      );
    }
  }

  void _validatePublicationOrder(
    String datasetKey,
    DatasetManifestEntry entry,
    DatasetVersion installed,
  ) {
    final installedHash = installed.sha256?.trim();
    if (entry.version == installed.version &&
        installedHash != null &&
        installedHash.isNotEmpty &&
        installedHash != entry.sha256) {
      throw DatasetSyncException(
        'Dataset $datasetKey reuses version ${entry.version} with a '
        'different SHA-256.',
      );
    }

    final candidateRevision = entry.publicationRevision;
    if (candidateRevision != null) {
      if (candidateRevision < installed.publicationRevision) {
        throw DatasetSyncException(
          'Dataset $datasetKey publication revision $candidateRevision is '
          'older than installed revision ${installed.publicationRevision}.',
        );
      }
      if (candidateRevision == installed.publicationRevision &&
          (entry.version != installed.version ||
              installedHash != entry.sha256)) {
        throw DatasetSyncException(
          'Dataset $datasetKey reuses publication revision '
          '$candidateRevision with different content.',
        );
      }
      return;
    }

    if (installed.publicationRevision > 0) {
      throw DatasetSyncException(
        'Dataset $datasetKey requires a publication revision.',
      );
    }
    if (entry.version == installed.version) {
      return;
    }
    final candidateParts = _orderedVersion(entry.version);
    final installedParts = _orderedVersion(installed.version);
    if (candidateParts == null || installedParts == null) {
      throw DatasetSyncException(
        'Dataset $datasetKey opaque version changes require a publication '
        'revision.',
      );
    }
    if (_compareOrderedVersions(candidateParts, installedParts) < 0) {
      throw DatasetSyncException(
        'Dataset $datasetKey downgrade from ${installed.version} to '
        '${entry.version} is not allowed.',
      );
    }
  }

  List<int>? _orderedVersion(String value) {
    if (!RegExp(r'^\d+(?:\.\d+)*$').hasMatch(value)) {
      return null;
    }
    return value.split('.').map(int.parse).toList(growable: false);
  }

  int _compareOrderedVersions(List<int> left, List<int> right) {
    final length = left.length > right.length ? left.length : right.length;
    for (var index = 0; index < length; index++) {
      final leftPart = index < left.length ? left[index] : 0;
      final rightPart = index < right.length ? right[index] : 0;
      if (leftPart != rightPart) {
        return leftPart.compareTo(rightPart);
      }
    }
    return 0;
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
    final appliedAt = now().toUtc();
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
              publicationRevision: Value(entry.publicationRevision ?? 0),
              appliedAt: Value(appliedAt),
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
        publicationRevision: Value(entry.publicationRevision ?? 0),
        appliedAt: Value(appliedAt),
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

  Future<List<int>> _collectResponseBytes(
    ResponseBody? body,
    int maxBytes,
    String label,
  ) async {
    if (body == null) {
      throw DatasetSyncException('$label had no body.');
    }
    try {
      return await collectBoundedBytes(
        body.stream,
        maxBytes: maxBytes,
        label: label,
      );
    } on BoundedStreamException catch (error) {
      throw DatasetSyncException(error.message);
    }
  }

  void _validateDeclaredLength(Headers headers, int maxBytes, String label) {
    final declaredLength = int.tryParse(
      headers.value(HttpHeaders.contentLengthHeader) ?? '',
    );
    if (declaredLength != null && declaredLength > maxBytes) {
      throw DatasetSyncException('$label exceeds its $maxBytes byte limit.');
    }
  }

  Future<String> _sha256File(File file) async {
    final sink = Sha256().toSync().newHashSink();
    await for (final chunk in file.openRead()) {
      sink.add(chunk);
    }
    sink.close();
    final hash = await sink.hash();
    return hash.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}

class _DecodedDatasetPayload {
  const _DecodedDatasetPayload(this.json, this.bytes);

  final Map<String, dynamic> json;
  final List<int> bytes;
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
