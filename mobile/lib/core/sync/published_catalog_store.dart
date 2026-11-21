import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

import '../database/app_database.dart';
import 'dataset_sync_service.dart';

/// A small, typed snapshot adapter for existing catalog DTOs. DatasetSyncService
/// remains the ONLY network client, manifest validator and Drift version writer.
/// Files are immutable and named by the SHA-256 recorded in dataset_versions.
class PublishedCatalogStore<T> {
  PublishedCatalogStore({
    required this.database,
    required this.datasetKey,
    required this.snapshotFile,
    required this.bundledLoader,
    required this.parse,
  });

  final AppDatabase database;
  final String datasetKey;
  final File snapshotFile;
  final Future<String> Function() bundledLoader;
  final T Function(String source) parse;
  final _CatalogMutex _mutex = _CatalogMutex();
  final Map<String, int> _pending = {};
  String? lastLoadWarning;
  String? lastMaintenanceWarning;

  TransactionalDatasetImporter get transactionalImporter =>
      TransactionalDatasetImporter(
        prepare: _prepare,
        isInstalledVersionUsable: _isInstalledVersionUsable,
      );

  Future<T> load() => _mutex.run(() async {
    final installed = await _installed();
    if (installed == null || installed.status != 'installed') {
      lastLoadWarning = null;
      return parse(await bundledLoader());
    }
    try {
      final value = await _readInstalled(installed);
      lastLoadWarning = null;
      return value;
    } on DatasetSyncException {
      return _bundledFallback();
    } on FileSystemException {
      return _bundledFallback();
    }
  });

  Future<T> _bundledFallback() async {
    lastLoadWarning =
        'El catálogo descargado no pasó la comprobación de integridad. '
        'Se muestra la copia incluida en la aplicación.';
    return parse(await bundledLoader());
  }

  Future<DatasetVersion?> _installed() async {
    final found = await (database.select(
      database.datasetVersions,
    )..where((row) => row.datasetKey.equals(datasetKey))).get();
    if (found.length > 1) {
      throw DatasetSyncException('Duplicate installed dataset: $datasetKey.');
    }
    return found.isEmpty ? null : found.single;
  }

  File _snapshot(String sha) => File('${snapshotFile.path}.$sha');

  Future<T> _readInstalled(DatasetVersion installed) async {
    final sha = installed.sha256?.trim() ?? '';
    if (!_sha256Pattern.hasMatch(sha)) {
      throw DatasetSyncException('Invalid installed hash for $datasetKey.');
    }
    final bytes = await _snapshot(sha).readAsBytes();
    if (await _digest(bytes) != sha) {
      throw DatasetSyncException('Installed bytes changed for $datasetKey.');
    }
    try {
      final source = utf8.decode(bytes);
      final json = jsonDecode(source);
      if (json is! Map ||
          json['datasetKey'] != datasetKey ||
          json['version'] != installed.version ||
          json['schemaVersion'] != 1) {
        throw const FormatException('Installed envelope mismatch.');
      }
      return parse(source);
    } catch (error) {
      throw DatasetSyncException('Installed $datasetKey is invalid: $error');
    }
  }

  Future<bool> _isInstalledVersionUsable(
    AppDatabase target,
    DatasetVersion installed,
  ) async {
    if (!identical(target, database) ||
        installed.datasetKey != datasetKey ||
        installed.status != 'installed') {
      return false;
    }
    return _mutex.run(() async {
      try {
        await _readInstalled(installed);
        return true;
      } on Exception {
        return false;
      }
    });
  }

  Future<PreparedDatasetImport> _prepare(
    AppDatabase target,
    Map<String, dynamic> payload,
    List<int> verifiedBytes,
    String sha,
  ) async {
    if (!identical(target, database) ||
        !_sha256Pattern.hasMatch(sha) ||
        await _digest(verifiedBytes) != sha) {
      throw DatasetSyncException('Invalid verified bytes for $datasetKey.');
    }
    try {
      final source = utf8.decode(verifiedBytes);
      final decoded = jsonDecode(source);
      if (decoded is! Map ||
          !_sameJson(decoded, payload) ||
          decoded['datasetKey'] != datasetKey ||
          decoded['schemaVersion'] != 1 ||
          decoded['version'] is! String ||
          (decoded['version'] as String).trim().isEmpty ||
          DateTime.tryParse(decoded['generatedAt']?.toString() ?? '') == null) {
        throw const FormatException('Catalog envelope does not match bytes.');
      }
      // The same parser used by the UI must accept the candidate BEFORE Drift
      // records its version. No committed but unreadable catalog is allowed.
      parse(source);
    } catch (error) {
      throw DatasetSyncException('Invalid published $datasetKey: $error');
    }

    return _mutex.run(() async {
      await snapshotFile.parent.create(recursive: true);
      final destination = _snapshot(sha);
      var created = false;
      final present = await destination.exists();
      final intact =
          present && await _digest(await destination.readAsBytes()) == sha;
      if (!intact) {
        final nonce = DateTime.now().microsecondsSinceEpoch;
        final candidate = File('${destination.path}.candidate.$nonce');
        final quarantine = File('${destination.path}.corrupt.$nonce');
        var quarantined = false;
        try {
          await candidate.writeAsBytes(verifiedBytes, flush: true);
          // Never write partial bytes to a selected snapshot. A damaged file
          // is moved out of the way only after the replacement is complete.
          if (present) {
            await destination.rename(quarantine.path);
            quarantined = true;
          }
          await candidate.rename(destination.path);
          created = true;
        } on FileSystemException {
          if (quarantined && !await destination.exists()) {
            await quarantine.rename(destination.path);
          }
          if (!await destination.exists() ||
              await _digest(await destination.readAsBytes()) != sha) {
            rethrow;
          }
        } finally {
          if (await candidate.exists()) await candidate.delete();
          if (await quarantine.exists()) await quarantine.delete();
        }
      }
      _pending.update(sha, (count) => count + 1, ifAbsent: () => 1);
      return _PreparedCatalog<T>(this, sha, created);
    });
  }

  Future<void> _finish(String sha, bool created, {required bool committed}) =>
      _mutex.run(() async {
        final count = _pending[sha] ?? 0;
        if (count <= 1) {
          _pending.remove(sha);
        } else {
          _pending[sha] = count - 1;
        }
        if (committed) {
          // Cleanup is best-effort, never invalidate a successful DB commit.
          try {
            final selected = await _installed();
            if (selected?.sha256 == sha) {
              final prefix = '${snapshotFile.uri.pathSegments.last}.';
              await for (final entity in snapshotFile.parent.list()) {
                if (entity is! File) continue;
                final name = entity.uri.pathSegments.last;
                if (!name.startsWith(prefix)) continue;
                final suffix = name.substring(prefix.length);
                if (suffix != sha &&
                    !_pending.containsKey(suffix) &&
                    _sha256Pattern.hasMatch(suffix)) {
                  await entity.delete();
                }
              }
            }
          } on Exception {
            lastMaintenanceWarning = 'Old snapshot cleanup deferred.';
          }
        } else if (created && !_pending.containsKey(sha)) {
          try {
            final selected = await _installed();
            if (selected?.sha256 != sha) {
              final snapshot = _snapshot(sha);
              if (await snapshot.exists()) await snapshot.delete();
            }
          } on Exception {
            lastMaintenanceWarning = 'Unselected snapshot cleanup deferred.';
          }
        }
      });
}

class _PreparedCatalog<T> implements PreparedDatasetImport {
  _PreparedCatalog(this.store, this.sha, this.created);
  final PublishedCatalogStore<T> store;
  final String sha;
  final bool created;
  bool _finished = false;

  @override
  Future<void> activate() async {}

  @override
  Future<void> commit() async {
    if (_finished) return;
    _finished = true;
    await store._finish(sha, created, committed: true);
  }

  @override
  Future<void> rollback() async {
    if (_finished) return;
    _finished = true;
    await store._finish(sha, created, committed: false);
  }
}

class _CatalogMutex {
  Future<void> _last = Future.value();

  Future<T> run<T>(Future<T> Function() action) async {
    final previous = _last;
    final completer = Completer<void>();
    _last = completer.future;
    await previous;
    try {
      return await action();
    } finally {
      completer.complete();
    }
  }
}

final _sha256Pattern = RegExp(r'^[a-f0-9]{64}$');

Future<String> _digest(List<int> bytes) async {
  final hash = await Sha256().hash(bytes);
  return hash.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}

bool _sameJson(Object? left, Object? right) {
  if (left is Map && right is Map) {
    return left.length == right.length &&
        left.keys.every(
          (key) => right.containsKey(key) && _sameJson(left[key], right[key]),
        );
  }
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (!_sameJson(left[i], right[i])) return false;
    }
    return true;
  }
  return left == right;
}
