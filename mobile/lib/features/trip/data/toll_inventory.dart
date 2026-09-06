import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/dataset_sync_service.dart';

const tollInventoryDatasetKey = 'tolls_inventory';
const bundledTollInventoryAsset = 'assets/catalogs/tolls_inventory_v1.json';

enum TollRecordKind { physicalStation }

enum TollOperationClassification {
  inventoriedOperationNotConfirmed,
  sourceReportsOperating,
  nonOperationalHistorical,
  damagedReviewRequired,
}

class TollInventoryDataset {
  const TollInventoryDataset({
    required this.version,
    required this.sourceTimestamp,
    required this.records,
  });

  factory TollInventoryDataset.fromJsonString(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map) {
        throw const DatasetSyncException(
          'Toll inventory payload must be a JSON object.',
        );
      }
      return TollInventoryDataset.fromJson(Map<String, dynamic>.from(decoded));
    } on FormatException catch (error) {
      throw DatasetSyncException('Invalid toll inventory JSON: $error');
    }
  }

  factory TollInventoryDataset.fromJson(Map<String, dynamic> json) {
    final schemaVersion = _requiredInt(json, 'schemaVersion');
    if (schemaVersion != 1) {
      throw DatasetSyncException(
        'Unsupported toll inventory schemaVersion: $schemaVersion.',
      );
    }
    if (_requiredString(json, 'datasetKey') != tollInventoryDatasetKey) {
      throw const DatasetSyncException('Toll inventory datasetKey is invalid.');
    }
    if (_requiredString(json, 'inventoryScope') !=
        'physical_station_inventory_only') {
      throw const DatasetSyncException(
        'Toll inventory cannot represent active charge events.',
      );
    }
    if (_requiredString(json, 'currency') != 'COP') {
      throw const DatasetSyncException('Toll inventory currency must be COP.');
    }
    if (_requiredBool(json, 'mapInventoryAvailable') != true ||
        _requiredBool(json, 'liveTariffsAvailable') != false) {
      throw const DatasetSyncException(
        'Toll inventory availability metadata is invalid.',
      );
    }

    final sourceDate = _requiredString(json, 'sourceSnapshotDate');
    final sourceTimestamp = DateTime.tryParse('${sourceDate}T00:00:00Z');
    if (sourceTimestamp == null) {
      throw const DatasetSyncException(
        'Toll inventory sourceSnapshotDate is invalid.',
      );
    }
    DateTime.parse(_requiredString(json, 'generatedAt'));

    final ids = <String>{};
    final records = <TollInventoryRecord>[];
    for (final value in _requiredList(json, 'records')) {
      if (value is! Map) {
        throw const DatasetSyncException(
          'Toll inventory records must be objects.',
        );
      }
      final record = TollInventoryRecord.fromJson(
        Map<String, dynamic>.from(value),
      );
      if (!ids.add(record.id)) {
        throw DatasetSyncException(
          'Duplicate toll inventory id: ${record.id}.',
        );
      }
      records.add(record);
    }
    if (records.isEmpty) {
      throw const DatasetSyncException('Toll inventory records are required.');
    }

    return TollInventoryDataset(
      version: _requiredString(json, 'version'),
      sourceTimestamp: sourceTimestamp,
      records: List.unmodifiable(records),
    );
  }

  final String version;
  final DateTime sourceTimestamp;
  final List<TollInventoryRecord> records;

  int get tariffCellCount => records.fold(
    0,
    (count, record) => count + record.tariffsBySourceCategoryCop.length,
  );

  int get knownTariffCount => records.fold(
    0,
    (count, record) =>
        count +
        record.tariffsBySourceCategoryCop.values
            .where((value) => value != null)
            .length,
  );

  int get verifiedChargeEventCount =>
      records.where((record) => record.chargeEventVerified).length;
}

class TollInventoryRecord {
  const TollInventoryRecord({
    required this.id,
    required this.name,
    required this.exactSourceName,
    required this.department,
    required this.recordKind,
    required this.operationStatusRaw,
    required this.operationClassification,
    required this.latitude,
    required this.longitude,
    required this.chargeEventVerified,
    required this.tariffsBySourceCategoryCop,
    required this.inventorySource,
    required this.gpsSource,
    this.chargeGroupRaw,
    this.routeCountingRuleRaw,
  });

  factory TollInventoryRecord.fromJson(Map<String, dynamic> json) {
    if (_requiredString(json, 'recordKind') != 'physical_station') {
      throw const DatasetSyncException(
        'Toll inventory recordKind must be physical_station.',
      );
    }
    if (_requiredString(json, 'chargeEventStatus') != 'unverified' ||
        _requiredBool(json, 'chargeEventVerified') != false ||
        _requiredBool(json, 'eligibleForUnqualifiedOperationalCount') !=
            false) {
      throw const DatasetSyncException(
        'Physical toll inventory must not imply a verified charge event.',
      );
    }
    final location = _requiredMap(json, 'location');
    final latitude = _requiredNumber(location, 'latitude').toDouble();
    final longitude = _requiredNumber(location, 'longitude').toDouble();
    if (latitude < -5 || latitude > 14 || longitude < -82 || longitude > -66) {
      throw DatasetSyncException(
        'Toll inventory coordinate is outside the audited Colombia bounds.',
      );
    }

    final tariffs = _requiredMap(json, 'tariffsBySourceCategoryCOP');
    final expectedCategories = {
      for (var index = 1; index <= 7; index++) 'category_$index',
    };
    if (tariffs.keys.toSet().difference(expectedCategories).isNotEmpty ||
        expectedCategories.difference(tariffs.keys.toSet()).isNotEmpty ||
        tariffs.values.any((value) => value != null)) {
      throw const DatasetSyncException(
        'All seven toll tariff cells must remain null.',
      );
    }

    return TollInventoryRecord(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      exactSourceName: _requiredString(json, 'exactSourceName'),
      department: _requiredString(json, 'department'),
      recordKind: TollRecordKind.physicalStation,
      operationStatusRaw: _requiredString(json, 'operationStatusRaw'),
      operationClassification: _operationClassification(
        _requiredString(json, 'operationClassification'),
      ),
      latitude: latitude,
      longitude: longitude,
      chargeEventVerified: false,
      tariffsBySourceCategoryCop: {
        for (final entry in tariffs.entries) entry.key: entry.value as int?,
      },
      inventorySource: _httpsUrl(json, 'inventorySource'),
      gpsSource: _httpsUrl(json, 'gpsSource'),
      chargeGroupRaw: _optionalString(json['chargeGroupRaw']),
      routeCountingRuleRaw: _optionalString(json['routeCountingRuleRaw']),
    );
  }

  final String id;
  final String name;
  final String exactSourceName;
  final String department;
  final TollRecordKind recordKind;
  final String operationStatusRaw;
  final TollOperationClassification operationClassification;
  final double latitude;
  final double longitude;
  final bool chargeEventVerified;
  final Map<String, int?> tariffsBySourceCategoryCop;
  final String inventorySource;
  final String gpsSource;
  final String? chargeGroupRaw;
  final String? routeCountingRuleRaw;
}

class TollInventoryStore {
  const TollInventoryStore({
    required this.database,
    required this.snapshotFile,
    required this.bundledLoader,
  });

  final AppDatabase database;
  final File snapshotFile;
  final Future<String> Function() bundledLoader;

  TransactionalDatasetImporter get transactionalImporter =>
      TransactionalDatasetImporter(
        prepare: _prepareImport,
        isInstalledVersionUsable: _isInstalledVersionUsable,
      );

  Future<TollInventoryDataset> load() async {
    final installed = await _installedVersion();
    if (installed?.status != 'installed') {
      return TollInventoryDataset.fromJsonString(await bundledLoader());
    }
    return _loadInstalledSnapshot(installed!);
  }

  Future<TollInventoryDataset> _loadInstalledSnapshot(
    DatasetVersion installed,
  ) async {
    final expectedHash = installed.sha256?.trim() ?? '';
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(expectedHash)) {
      throw const DatasetSyncException(
        'Installed toll inventory SHA-256 is invalid.',
      );
    }
    final selectedSnapshot = await _selectedSnapshot(expectedHash);
    final actualHash = await _sha256File(selectedSnapshot);
    if (actualHash != expectedHash) {
      throw const DatasetSyncException(
        'Toll inventory snapshot does not match dataset_versions.',
      );
    }
    final dataset = TollInventoryDataset.fromJsonString(
      await selectedSnapshot.readAsString(),
    );
    if (dataset.version != installed.version) {
      throw const DatasetSyncException(
        'Toll inventory snapshot version does not match dataset_versions.',
      );
    }
    return dataset;
  }

  Future<bool> _isInstalledVersionUsable(
    AppDatabase targetDatabase,
    DatasetVersion installed,
  ) async {
    if (!identical(targetDatabase, database) ||
        installed.datasetKey != tollInventoryDatasetKey ||
        installed.status != 'installed') {
      return false;
    }
    try {
      await _loadInstalledSnapshot(installed);
      return true;
    } on DatasetSyncException {
      return false;
    } on FileSystemException {
      return false;
    }
  }

  Future<PreparedDatasetImport> _prepareImport(
    AppDatabase targetDatabase,
    Map<String, dynamic> json,
    List<int> verifiedBytes,
    String sha256,
  ) async {
    if (!identical(targetDatabase, database)) {
      throw const DatasetSyncException(
        'Toll inventory store received an unexpected database.',
      );
    }
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256) ||
        await _sha256Bytes(verifiedBytes) != sha256) {
      throw const DatasetSyncException(
        'Toll inventory bytes do not match the verified SHA-256.',
      );
    }
    TollInventoryDataset.fromJson(json);
    try {
      TollInventoryDataset.fromJsonString(utf8.decode(verifiedBytes));
    } on FormatException catch (error) {
      throw DatasetSyncException('Invalid toll inventory UTF-8: $error');
    }

    await snapshotFile.parent.create(recursive: true);
    final immutableSnapshot = _snapshotForHash(sha256);
    var created = false;
    try {
      if (await immutableSnapshot.exists()) {
        if (await _sha256File(immutableSnapshot) != sha256) {
          throw const DatasetSyncException(
            'Existing immutable toll snapshot is corrupt.',
          );
        }
      } else {
        final candidate = File(
          '${immutableSnapshot.path}.candidate.'
          '${DateTime.now().microsecondsSinceEpoch}',
        );
        await candidate.writeAsBytes(verifiedBytes, flush: true);
        try {
          await candidate.rename(immutableSnapshot.path);
          created = true;
        } on FileSystemException {
          await _deleteBestEffort(candidate);
          if (!await immutableSnapshot.exists() ||
              await _sha256File(immutableSnapshot) != sha256) {
            rethrow;
          }
        }
      }
    } catch (error) {
      throw DatasetSyncException(
        'Toll inventory snapshot preparation failed: $error',
      );
    }
    return _PreparedTollSnapshot(
      store: this,
      immutableSnapshot: immutableSnapshot,
      sha256: sha256,
      created: created,
    );
  }

  File _snapshotForHash(String sha256) => File('${snapshotFile.path}.$sha256');

  Future<File> _selectedSnapshot(String sha256) async {
    final selected = _snapshotForHash(sha256);
    if (await selected.exists()) {
      return selected;
    }

    final legacyHash = File('${snapshotFile.path}.sha256');
    if (await snapshotFile.exists() && await legacyHash.exists()) {
      final sidecar = (await legacyHash.readAsString()).trim();
      if (sidecar == sha256 && await _sha256File(snapshotFile) == sha256) {
        try {
          await snapshotFile.rename(selected.path);
        } on FileSystemException {
          if (!await selected.exists()) {
            rethrow;
          }
        }
        await _deleteBestEffort(legacyHash);
        return selected;
      }
    }
    throw const DatasetSyncException(
      'Installed toll inventory snapshot is missing.',
    );
  }

  Future<bool> _isHashSelected(String sha256) async {
    final installed = await _installedVersion();
    return installed?.status == 'installed' && installed?.sha256 == sha256;
  }

  Future<void> _cleanupUnselectedSnapshots(String selectedSha256) async {
    try {
      await for (final entity in snapshotFile.parent.list()) {
        if (entity is! File ||
            !entity.path.startsWith('${snapshotFile.path}.')) {
          continue;
        }
        final suffix = entity.path.substring(snapshotFile.path.length + 1);
        if (suffix != selectedSha256 &&
            RegExp(r'^[a-f0-9]{64}$').hasMatch(suffix)) {
          await _deleteBestEffort(entity);
        }
      }
    } on FileSystemException {
      return;
    }
  }

  Future<DatasetVersion?> _installedVersion() async {
    final rows = await (database.select(
      database.datasetVersions,
    )..where((row) => row.datasetKey.equals(tollInventoryDatasetKey))).get();
    if (rows.length > 1) {
      throw const DatasetSyncException(
        'Multiple toll inventory dataset versions are installed.',
      );
    }
    return rows.isEmpty ? null : rows.single;
  }
}

class _PreparedTollSnapshot implements PreparedDatasetImport {
  _PreparedTollSnapshot({
    required this.store,
    required this.immutableSnapshot,
    required this.sha256,
    required this.created,
  });

  final TollInventoryStore store;
  final File immutableSnapshot;
  final String sha256;
  final bool created;

  @override
  Future<void> activate() async {}

  @override
  Future<void> commit() async {
    await store._cleanupUnselectedSnapshots(sha256);
  }

  @override
  Future<void> rollback() async {
    if (created && !await store._isHashSelected(sha256)) {
      await _deleteBestEffort(immutableSnapshot);
    }
  }
}

Future<void> _deleteBestEffort(File file) async {
  try {
    if (await file.exists()) {
      await file.delete();
    }
  } on FileSystemException {
    return;
  }
}

Future<String> _sha256Bytes(List<int> bytes) async {
  final hash = await Sha256().hash(bytes);
  return _hex(hash.bytes);
}

Future<String> _sha256File(File file) async {
  final sink = Sha256().toSync().newHashSink();
  await for (final chunk in file.openRead()) {
    sink.add(chunk);
  }
  sink.close();
  return _hex((await sink.hash()).bytes);
}

String _hex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

TollOperationClassification _operationClassification(String value) {
  return switch (value) {
    'inventoried_operation_not_confirmed' =>
      TollOperationClassification.inventoriedOperationNotConfirmed,
    'source_reports_operating' =>
      TollOperationClassification.sourceReportsOperating,
    'non_operational_historical' =>
      TollOperationClassification.nonOperationalHistorical,
    'damaged_review_required' =>
      TollOperationClassification.damagedReviewRequired,
    _ => throw DatasetSyncException(
      'Invalid toll operationClassification: $value.',
    ),
  };
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  throw DatasetSyncException('$key must be a non-empty string.');
}

String? _optionalString(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  throw const DatasetSyncException('Optional toll metadata must be a string.');
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  throw DatasetSyncException('$key must be an integer.');
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) {
    return value;
  }
  throw DatasetSyncException('$key must be a boolean.');
}

num _requiredNumber(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) {
    return value;
  }
  throw DatasetSyncException('$key must be numeric.');
}

List<Object?> _requiredList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is List) {
    return List<Object?>.from(value);
  }
  throw DatasetSyncException('$key must be a list.');
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  throw DatasetSyncException('$key must be an object.');
}

String _httpsUrl(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  final uri = Uri.parse(value);
  if (uri.scheme != 'https' || uri.host.isEmpty) {
    throw DatasetSyncException('$key must be an HTTPS URL.');
  }
  return value;
}
