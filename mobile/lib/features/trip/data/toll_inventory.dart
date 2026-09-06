import 'dart:convert';
import 'dart:io';

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
    required this.snapshotFile,
    required this.bundledLoader,
  });

  final File snapshotFile;
  final Future<String> Function() bundledLoader;

  DatasetImporter get datasetImporter =>
      (_, json) => importJson(json);

  Future<TollInventoryDataset> load() async {
    final source = await snapshotFile.exists()
        ? await snapshotFile.readAsString()
        : await bundledLoader();
    return TollInventoryDataset.fromJsonString(source);
  }

  Future<void> importJson(Map<String, dynamic> json) async {
    TollInventoryDataset.fromJson(json);
    final bytes = utf8.encode(jsonEncode(json));
    await _replaceSnapshot(bytes);
  }

  Future<void> _replaceSnapshot(List<int> bytes) async {
    await snapshotFile.parent.create(recursive: true);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final temporary = File('${snapshotFile.path}.tmp.$stamp');
    final backup = File('${snapshotFile.path}.bak.$stamp');
    var movedPrevious = false;
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      if (await snapshotFile.exists()) {
        await snapshotFile.rename(backup.path);
        movedPrevious = true;
      }
      await temporary.rename(snapshotFile.path);
      if (movedPrevious && await backup.exists()) {
        await backup.delete();
      }
    } catch (error) {
      if (movedPrevious && await backup.exists()) {
        if (await snapshotFile.exists()) {
          await snapshotFile.delete();
        }
        await backup.rename(snapshotFile.path);
      }
      if (await temporary.exists()) {
        await temporary.delete();
      }
      if (error is DatasetSyncException) {
        rethrow;
      }
      throw DatasetSyncException(
        'Toll inventory snapshot import failed: $error',
      );
    }
  }
}

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
