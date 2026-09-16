import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/dataset_sync_service.dart';
import 'tax_catalog.dart';

class TaxCatalogStore {
  TaxCatalogStore({
    required this.database,
    required this.snapshotFile,
    required this.bundledLoader,
  });

  final AppDatabase database;
  final File snapshotFile;
  final Future<String> Function() bundledLoader;
  final _snapshotMutex = _AsyncMutex();
  final Map<String, int> _preparedHashes = {};
  String? lastMaintenanceError;
  String? lastLoadWarning;

  TransactionalDatasetImporter get transactionalImporter =>
      TransactionalDatasetImporter(
        prepare: _prepareImport,
        isInstalledVersionUsable: _isInstalledVersionUsable,
      );

  Future<TaxCatalog> load() => _snapshotMutex.synchronized(() async {
    final installed = await _installedVersion();
    if (installed?.status != 'installed') {
      final catalog = TaxCatalog.fromJsonString(await bundledLoader());
      lastLoadWarning = null;
      return catalog;
    }
    try {
      final catalog = await _loadInstalledSnapshot(installed!);
      lastLoadWarning = null;
      return catalog;
    } on DatasetSyncException {
      return _loadBundledFallback();
    } on FileSystemException {
      return _loadBundledFallback();
    }
  });

  Future<TaxCatalog> _loadBundledFallback() async {
    final catalog = TaxCatalog.fromJsonString(await bundledLoader());
    lastLoadWarning =
        'El catalogo descargado no esta disponible o no supera la '
        'verificacion de integridad. Mostramos el respaldo incluido en la app; '
        'puede no contener las ultimas actualizaciones.';
    return catalog;
  }

  Future<TaxCatalog> _loadInstalledSnapshot(DatasetVersion installed) async {
    final expectedHash = installed.sha256?.trim() ?? '';
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(expectedHash)) {
      throw const DatasetSyncException(
        'Installed tax catalog SHA-256 is invalid.',
      );
    }
    final selectedSnapshot = await _selectedSnapshot(expectedHash);
    final bytes = await selectedSnapshot.readAsBytes();
    final actualHash = await _sha256Bytes(bytes);
    if (actualHash != expectedHash) {
      throw const DatasetSyncException(
        'Tax catalog snapshot does not match dataset_versions.',
      );
    }
    final TaxCatalog dataset;
    try {
      dataset = TaxCatalog.fromJsonString(utf8.decode(bytes));
    } on FormatException {
      throw const DatasetSyncException('Invalid tax catalog snapshot UTF-8.');
    }
    if (dataset.version != installed.version) {
      throw const DatasetSyncException(
        'Tax catalog snapshot version does not match dataset_versions.',
      );
    }
    return dataset;
  }

  Future<bool> _isInstalledVersionUsable(
    AppDatabase targetDatabase,
    DatasetVersion installed,
  ) async {
    if (!identical(targetDatabase, database) ||
        installed.datasetKey != taxCalendarsDatasetKey ||
        installed.status != 'installed') {
      return false;
    }
    return _snapshotMutex.synchronized(() async {
      try {
        await _loadInstalledSnapshot(installed);
        return true;
      } on DatasetSyncException {
        return false;
      } on FileSystemException {
        return false;
      }
    });
  }

  Future<PreparedDatasetImport> _prepareImport(
    AppDatabase targetDatabase,
    Map<String, dynamic> json,
    List<int> verifiedBytes,
    String sha256,
  ) async {
    if (!identical(targetDatabase, database)) {
      throw const DatasetSyncException(
        'Tax catalog store received an unexpected database.',
      );
    }
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256) ||
        await _sha256Bytes(verifiedBytes) != sha256) {
      throw const DatasetSyncException(
        'Tax catalog bytes do not match the verified SHA-256.',
      );
    }
    TaxCatalog.fromJson(json);
    try {
      final source = utf8.decode(verifiedBytes);
      TaxCatalog.fromJsonString(source);
      if (!_sameJson(json, jsonDecode(source))) {
        throw const DatasetSyncException(
          'Tax catalog JSON differs from verified bytes.',
        );
      }
    } on FormatException catch (error) {
      throw DatasetSyncException('Invalid tax catalog UTF-8: $error');
    }

    return _snapshotMutex.synchronized(() async {
      await snapshotFile.parent.create(recursive: true);
      final immutableSnapshot = _snapshotForHash(sha256);
      var created = false;
      try {
        if (!await immutableSnapshot.exists() ||
            await _sha256File(immutableSnapshot) != sha256) {
          final candidate = File(
            '${immutableSnapshot.path}.candidate.'
            '${DateTime.now().microsecondsSinceEpoch}',
          );
          try {
            await candidate.writeAsBytes(verifiedBytes, flush: true);
            // Replace only with verified bytes; never delete the selected file
            // before the complete candidate is ready for the rename.
            await candidate.rename(immutableSnapshot.path);
            created = true;
          } on FileSystemException {
            if (!await immutableSnapshot.exists() ||
                await _sha256File(immutableSnapshot) != sha256) {
              rethrow;
            }
          } finally {
            await _deleteBestEffort(candidate);
          }
        }
      } catch (error) {
        throw DatasetSyncException(
          'Tax catalog snapshot preparation failed: $error',
        );
      }
      _preparedHashes.update(sha256, (count) => count + 1, ifAbsent: () => 1);
      return _PreparedTaxSnapshot(
        store: this,
        immutableSnapshot: immutableSnapshot,
        sha256: sha256,
        created: created,
      );
    });
  }

  File _snapshotForHash(String sha256) => File('${snapshotFile.path}.$sha256');

  Future<File> _selectedSnapshot(String sha256) async {
    final selected = _snapshotForHash(sha256);
    if (await selected.exists()) {
      return selected;
    }

    throw const DatasetSyncException(
      'Installed tax catalog snapshot is missing.',
    );
  }

  Future<bool> _isHashSelected(String sha256) async {
    final installed = await _installedVersion();
    return installed?.status == 'installed' && installed?.sha256 == sha256;
  }

  Future<void> _cleanupUnselectedSnapshots(String selectedSha256) async {
    try {
      final snapshotName = snapshotFile.uri.pathSegments.last;
      final prefix = '$snapshotName.';
      await for (final entity in snapshotFile.parent.list()) {
        if (entity is! File) {
          continue;
        }
        final entityName = entity.uri.pathSegments.last;
        if (!entityName.startsWith(prefix)) {
          continue;
        }
        final suffix = entityName.substring(prefix.length);
        if (suffix != selectedSha256 &&
            !_preparedHashes.containsKey(suffix) &&
            RegExp(r'^[a-f0-9]{64}$').hasMatch(suffix)) {
          await _deleteBestEffort(entity);
        }
      }
    } on FileSystemException {
      lastMaintenanceError = 'Unselected snapshot cleanup deferred.';
      return;
    }
  }

  Future<void> _commitPrepared(_PreparedTaxSnapshot prepared) {
    return _snapshotMutex.synchronized(() async {
      if (prepared._finished) {
        return;
      }
      prepared._finished = true;
      _releasePreparedHash(prepared.sha256);
      final DatasetVersion? installed;
      try {
        installed = await _installedVersion();
      } on Exception {
        lastMaintenanceError =
            'Snapshot cleanup deferred: database unavailable.';
        return;
      }
      final selectedSha256 = installed?.status == 'installed'
          ? installed?.sha256?.trim()
          : null;
      if (selectedSha256 != null &&
          RegExp(r'^[a-f0-9]{64}$').hasMatch(selectedSha256)) {
        await _cleanupUnselectedSnapshots(selectedSha256);
      }
    });
  }

  Future<void> _rollbackPrepared(_PreparedTaxSnapshot prepared) {
    return _snapshotMutex.synchronized(() async {
      if (prepared._finished) {
        return;
      }
      prepared._finished = true;
      _releasePreparedHash(prepared.sha256);
      if (prepared.created &&
          !_preparedHashes.containsKey(prepared.sha256) &&
          !await _isHashSelected(prepared.sha256)) {
        await _deleteBestEffort(prepared.immutableSnapshot);
      }
    });
  }

  void _releasePreparedHash(String sha256) {
    final count = _preparedHashes[sha256];
    if (count == null || count <= 1) {
      _preparedHashes.remove(sha256);
    } else {
      _preparedHashes[sha256] = count - 1;
    }
  }

  Future<void> _deleteBestEffort(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // The selected snapshot remains usable; expose deferred maintenance.
      lastMaintenanceError = 'Unselected snapshot deletion deferred.';
    }
  }

  Future<DatasetVersion?> _installedVersion() async {
    final rows = await (database.select(
      database.datasetVersions,
    )..where((row) => row.datasetKey.equals(taxCalendarsDatasetKey))).get();
    if (rows.length > 1) {
      throw const DatasetSyncException(
        'Multiple tax catalog dataset versions are installed.',
      );
    }
    return rows.isEmpty ? null : rows.single;
  }
}

class _PreparedTaxSnapshot implements PreparedDatasetImport {
  _PreparedTaxSnapshot({
    required this.store,
    required this.immutableSnapshot,
    required this.sha256,
    required this.created,
  });

  final TaxCatalogStore store;
  final File immutableSnapshot;
  final String sha256;
  final bool created;
  bool _finished = false;

  @override
  Future<void> activate() async {}

  @override
  Future<void> commit() => store._commitPrepared(this);

  @override
  Future<void> rollback() => store._rollbackPrepared(this);
}

class _AsyncMutex {
  Future<void> _tail = Future.value();

  Future<T> synchronized<T>(Future<T> Function() action) async {
    final previous = _tail;
    final release = Completer<void>();
    _tail = release.future;
    await previous;
    try {
      return await action();
    } finally {
      release.complete();
    }
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

bool _sameJson(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((key) => b.containsKey(key) && _sameJson(a[key], b[key]));
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (!_sameJson(a[index], b[index])) return false;
    }
    return true;
  }
  return a == b;
}
