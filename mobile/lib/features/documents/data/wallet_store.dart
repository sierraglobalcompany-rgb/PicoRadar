import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/database/app_database.dart';
import '../../../core/storage/app_secure_storage.dart';
import '../../../core/storage/file_crypto.dart';
import '../../vehicle_status/data/private_vehicle_document_store.dart';
import '../platform/wallet_platform.dart';
import 'wallet_models.dart';

export 'wallet_models.dart';

class WalletStore {
  WalletStore({
    required AppDatabase db,
    required PrivateVehicleDocumentStore legacyStore,
    DirectoryResolver? rootDirectory,
    DirectoryResolver? cacheDirectory,
    SecretKeyResolver? masterKey,
    FileCrypto? fileCrypto,
    DateTime Function()? now,
  }) : _db = db, // ignore: prefer_initializing_formals
       _legacy = legacyStore,
       _rootDirectory = rootDirectory ?? _defaultRootDirectory,
       _cacheDirectory = cacheDirectory ?? getTemporaryDirectory,
       _masterKey = masterKey ?? AppSecureStorage().getOrCreateFileMasterKey,
       _crypto = fileCrypto ?? FileCrypto(),
       _now = now ?? DateTime.now;

  static const principalId = 'principal';
  static const viewerFolder = 'wallet_document_viewer';
  static const maxImportBytes = PrivateVehicleDocumentStore.maxImportBytes;
  static const _migrationId = 'legacy_vehicle_index_v1';
  static const _cleanupPrefix = 'cleanup:';
  static final _tails = Expando<Future<void>>();
  final AppDatabase _db;
  final PrivateVehicleDocumentStore _legacy;
  final DirectoryResolver _rootDirectory;
  final DirectoryResolver _cacheDirectory;
  final SecretKeyResolver _masterKey;
  final FileCrypto _crypto;
  final DateTime Function() _now;
  bool _initialized = false;
  WalletMigrationReport _migrationReport = const WalletMigrationReport();

  WalletMigrationReport get migrationReport => _migrationReport;

  Future<WalletMigrationReport> initialize() => _serialized(_initialize);

  Future<WalletMigrationReport> _initialize() async {
    try {
      return await _initializeStorage();
    } catch (_) {
      _migrationReport = WalletMigrationReport(
        importedCount: _migrationReport.importedCount,
        orphanedCount: _migrationReport.orphanedCount,
        pendingCleanupCount: _migrationReport.pendingCleanupCount,
        migrationFailed: true,
      );
      rethrow;
    }
  }

  Future<WalletMigrationReport> _initializeStorage() async {
    if (!_initialized) await _purgeViewerCache();
    final report = await _db.transaction(() async {
      final principal = await (_db.select(
        _db.driverProfiles,
      )..where((r) => r.id.equals(principalId))).getSingleOrNull();
      if (principal == null) {
        await _db
            .into(_db.driverProfiles)
            .insert(
              DriverProfilesCompanion.insert(
                id: principalId,
                slot: 0,
                encryptedMetadata: await _encrypt({
                  'id': principalId,
                  'displayName': 'Principal',
                }),
              ),
            );
      }
      final marker = await (_db.select(
        _db.walletMigrations,
      )..where((r) => r.id.equals(_migrationId))).getSingleOrNull();
      if (marker != null) {
        final data = await _decrypt(marker.encryptedMetadata);
        if (data['id'] != _migrationId) {
          throw const FormatException('Invalid wallet migration record.');
        }
        return WalletMigrationReport(
          importedCount: data['importedCount']! as int,
          orphanedCount: (data['unresolved']! as List).length,
        );
      }

      final legacy = await _legacy.listAllForMigration();
      final vehicleIds = (await _db.select(_db.vehicles).get())
          .map((v) => v.id)
          .toSet();
      final unresolved = <Map<String, Object?>>[];
      var imported = 0;
      for (final old in legacy) {
        _checkedPath(old.encryptedRelativePath);
        final owner = WalletOwner.vehicle(old.vehicleId);
        final type = WalletDocumentType.fromValue(old.documentType.value);
        if (!vehicleIds.contains(old.vehicleId) ||
            old.documentId.isEmpty ||
            await _find(owner, type) != null ||
            await (_db.select(_db.privateDocuments)
                      ..where((r) => r.id.equals(old.documentId)))
                    .getSingleOrNull() !=
                null) {
          // Retain every unassignable reference encrypted, without inventing an owner.
          unresolved.add(old.toJson());
          continue;
        }
        final ref = WalletFileRef(
          encryptedRelativePath: old.encryptedRelativePath,
          originalName: old.originalName,
          mimeType: old.mimeType,
          legacyMetadata: old,
        );
        final isPdf =
            old.mimeType == 'application/pdf' ||
            old.originalName.toLowerCase().endsWith('.pdf');
        final document = WalletDocument(
          id: old.documentId,
          owner: owner,
          type: type,
          importedAt: old.importedAt,
          front: isPdf ? null : ref,
          pdf: isPdf ? ref : null,
        );
        await _insert(document);
        imported++;
      }
      // Subsequent reads use Drift; legacy mutations only retire explicitly deleted copies.
      await _db
          .into(_db.walletMigrations)
          .insert(
            WalletMigrationsCompanion.insert(
              id: _migrationId,
              encryptedMetadata: await _encrypt({
                'id': _migrationId,
                'importedCount': imported,
                'unresolved': unresolved,
              }),
            ),
          );
      return WalletMigrationReport(
        importedCount: imported,
        orphanedCount: unresolved.length,
      );
    });
    _migrationReport = report;
    await _drainPendingCleanup();
    if (!_initialized) await _purgeUnreferencedEncryptedFiles();
    _initialized = true;
    return _migrationReport;
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) await _initialize();
  }

  Future<List<WalletDriver>> listDrivers() => _serialized(() async {
    await _ensureInitialized();
    final rows = await (_db.select(
      _db.driverProfiles,
    )..orderBy([(r) => OrderingTerm.asc(r.slot)])).get();
    return [for (final row in rows) await _driver(row)];
  });

  Future<WalletOwner> ensurePreparation(
    String id, {
    bool Function()? isAuthorized,
  }) => _serialized(() async {
    _requireAuthorized(isAuthorized);
    _validatePreparationId(id);
    await _ensureInitialized();
    return _db.transaction(() async {
      final existing = await _preparation(id);
      if (existing == null) {
        final encrypted = await _encrypt({'id': id});
        _requireAuthorized(isAuthorized);
        await _db
            .into(_db.walletPreparations)
            .insert(
              WalletPreparationsCompanion.insert(
                id: id,
                encryptedMetadata: encrypted,
              ),
            );
      }
      _requireAuthorized(isAuthorized);
      return WalletOwner.preparation(id);
    });
  });

  Future<bool> preparationExists(String id) => _serialized(() async {
    _validatePreparationId(id);
    await _ensureInitialized();
    return await _preparation(id) != null;
  });

  Future<List<WalletOwner>> listPreparations() => _serialized(() async {
    await _ensureInitialized();
    final rows = await (_db.select(
      _db.walletPreparations,
    )..orderBy([(r) => OrderingTerm.asc(r.id)])).get();
    return [for (final row in rows) await _preparationOwner(row)];
  });

  Future<void> deletePreparation(String id, {bool Function()? isAuthorized}) =>
      _serialized(() async {
        _requireAuthorized(isAuthorized);
        _validatePreparationId(id);
        await _ensureInitialized();
        await _preparation(id);
        final documents = await _documents(WalletOwner.preparation(id));
        await _purgeViewerCache();
        await _db.transaction(() async {
          _requireAuthorized(isAuthorized);
          for (final document in documents) {
            await _queueCleanup(document);
          }
          await (_db.delete(
            _db.privateDocuments,
          )..where((r) => r.preparationId.equals(id))).go();
          await (_db.delete(
            _db.walletPreparations,
          )..where((r) => r.id.equals(id))).go();
          _requireAuthorized(isAuthorized);
        });
        await _drainPendingCleanup();
      });

  static void _validatePreparationId(String id) {
    if (id.trim().isEmpty || id != id.trim() || id.contains('\u0000')) {
      throw ArgumentError('Invalid preparation identity.');
    }
  }

  Future<WalletOwner?> _preparation(String id) async {
    final row = await (_db.select(
      _db.walletPreparations,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    return row == null ? null : _preparationOwner(row);
  }

  Future<WalletOwner> _preparationOwner(WalletPreparation row) async {
    final data = await _decrypt(row.encryptedMetadata);
    if (data['id'] != row.id) {
      throw const FormatException('Preparation metadata identity mismatch.');
    }
    return WalletOwner.preparation(row.id);
  }

  Future<WalletDriver> saveDriver({
    String? id,
    required String displayName,
    bool Function()? isAuthorized,
  }) => _serialized(() async {
    _requireAuthorized(isAuthorized);
    await _ensureInitialized();
    final name = displayName.trim();
    if (name.isEmpty || name.length > 100) {
      throw ArgumentError('Driver name must contain 1 to 100 characters.');
    }
    return _db.transaction(() async {
      final rows = await _db.select(_db.driverProfiles).get();
      if (id == null && rows.length >= 2) {
        throw StateError('Only two driver profiles are supported.');
      }
      if (id != null && !rows.any((r) => r.id == id)) {
        throw ArgumentError('Unknown driver profile.');
      }
      final driverId = id ?? _id();
      final driver = WalletDriver(
        id: driverId,
        displayName: name,
        isPrincipal: driverId == principalId,
      );
      final encrypted = await _encrypt({'id': driverId, 'displayName': name});
      _requireAuthorized(isAuthorized);
      await _db
          .into(_db.driverProfiles)
          .insertOnConflictUpdate(
            DriverProfilesCompanion.insert(
              id: driverId,
              slot: driver.isPrincipal ? 0 : 1,
              encryptedMetadata: encrypted,
            ),
          );
      _requireAuthorized(isAuthorized);
      return driver;
    });
  });

  Future<void> deleteDriver(String id, {bool Function()? isAuthorized}) =>
      _serialized(() async {
        _requireAuthorized(isAuthorized);
        await _ensureInitialized();
        final documents = await _documents(WalletOwner.driver(id));
        await _purgeViewerCache();
        await _db.transaction(() async {
          for (final document in documents) {
            await _queueCleanup(document);
          }
          await (_db.delete(
            _db.privateDocuments,
          )..where((r) => r.driverId.equals(id))).go();
          if (id == principalId) {
            await (_db.update(
              _db.driverProfiles,
            )..where((r) => r.id.equals(id))).write(
              DriverProfilesCompanion(
                encryptedMetadata: Value(
                  await _encrypt({
                    'id': principalId,
                    'displayName': 'Principal',
                  }),
                ),
              ),
            );
          } else {
            await (_db.delete(
              _db.driverProfiles,
            )..where((r) => r.id.equals(id))).go();
          }
          _requireAuthorized(isAuthorized);
        });
        await _drainPendingCleanup();
      });

  Future<List<WalletDocument>> listDocuments({WalletOwner? owner}) =>
      _serialized(() async {
        await _ensureInitialized();
        return _documents(owner);
      });

  Future<WalletDocument> saveDocument({
    required WalletOwner owner,
    required WalletDocumentType type,
    WalletDocumentInput? front,
    WalletDocumentInput? back,
    WalletDocumentInput? pdf,
    Map<String, String> metadata = const {},
    bool Function()? isAuthorized,
  }) => _serialized(() async {
    _requireAuthorized(isAuthorized);
    await _ensureInitialized();
    if ((pdf == null && front == null) ||
        (pdf != null && (front != null || back != null))) {
      throw ArgumentError(
        'Provide a front image with optional back, or one PDF.',
      );
    }
    if (owner.isDriver != type.isDriverDocument &&
        type != WalletDocumentType.other) {
      throw ArgumentError('Document type does not match its owner.');
    }
    if (owner.isPreparation && type == WalletDocumentType.voluntaryInsurance) {
      throw ArgumentError('Document type does not match its owner.');
    }
    if (metadata.length > 32 ||
        utf8.encode(jsonEncode(metadata)).length > 16384) {
      throw ArgumentError('Document metadata is too large.');
    }
    final inputs = <WalletDocumentSide, WalletDocumentInput>{
      WalletDocumentSide.front: ?front,
      WalletDocumentSide.back: ?back,
      WalletDocumentSide.pdf: ?pdf,
    };
    for (final entry in inputs.entries) {
      await _validateInput(entry.value, entry.key);
    }
    await _purgeViewerCache();
    final created = <File>[];
    WalletDocument? previous;
    late WalletDocument saved;
    var committed = false;
    try {
      await _db.transaction(() async {
        await _validateOwner(owner);
        final row = await _find(owner, type);
        if (row != null) previous = await _document(row);
        final id = _id();
        final refs = <WalletDocumentSide, WalletFileRef>{};
        for (final entry in inputs.entries) {
          final relativePath = 'docs/$id/${entry.key.name}.prcf';
          final destination = await _ownedFile(relativePath);
          created.add(destination);
          // Read once with a hard bound; file growth cannot bypass the import limit.
          final bytes = await _readLimited(entry.value.source);
          try {
            final encrypted = await _crypto.encryptBytes(
              bytes,
              await _masterKey(),
            );
            await destination.parent.create(recursive: true);
            await destination.writeAsBytes(encrypted, flush: true);
          } finally {
            bytes.fillRange(0, bytes.length, 0);
          }
          refs[entry.key] = WalletFileRef(
            encryptedRelativePath: relativePath,
            originalName: _safeName(entry.value.originalName),
            mimeType: entry.value.mimeType,
          );
        }
        saved = WalletDocument(
          id: id,
          owner: owner,
          type: type,
          importedAt: _now().toUtc(),
          front: refs[WalletDocumentSide.front],
          back: refs[WalletDocumentSide.back],
          pdf: refs[WalletDocumentSide.pdf],
          metadata: metadata,
        );
        await _validateOwner(owner);
        _requireAuthorized(isAuthorized);
        if (row != null) {
          await _queueCleanup(previous!);
          await (_db.delete(
            _db.privateDocuments,
          )..where((r) => r.id.equals(row.id))).go();
        }
        await _insert(saved, isAuthorized: isAuthorized);
        await _validateOwner(owner);
        _requireAuthorized(isAuthorized);
      });
      committed = true;
    } finally {
      if (!committed) {
        for (final file in created) {
          if (await file.exists()) await file.delete();
        }
      }
    }
    await _drainPendingCleanup();
    return saved;
  });

  Future<void> deleteDocument(String id, {bool Function()? isAuthorized}) =>
      _serialized(() async {
        _requireAuthorized(isAuthorized);
        await _ensureInitialized();
        final row = await (_db.select(
          _db.privateDocuments,
        )..where((r) => r.id.equals(id))).getSingleOrNull();
        if (row == null) {
          await _drainPendingCleanup();
          return;
        }
        final document = await _document(row);
        await _purgeViewerCache();
        await _db.transaction(() async {
          _requireAuthorized(isAuthorized);
          await _queueCleanup(document);
          await (_db.delete(
            _db.privateDocuments,
          )..where((r) => r.id.equals(id))).go();
          _requireAuthorized(isAuthorized);
        });
        await _drainPendingCleanup();
      });

  Future<void> deleteForVehicle(String id, {bool Function()? isAuthorized}) =>
      _serialized(() async {
        _requireAuthorized(isAuthorized);
        await _ensureInitialized();
        final documents = await _documents(WalletOwner.vehicle(id));
        await _purgeViewerCache();
        await _db.transaction(() async {
          _requireAuthorized(isAuthorized);
          for (final document in documents) {
            await _queueCleanup(document);
          }
          await (_db.delete(
            _db.privateDocuments,
          )..where((r) => r.vehicleId.equals(id))).go();
          _requireAuthorized(isAuthorized);
        });
        await _drainPendingCleanup();
      });

  Future<Uint8List> readDocumentBytes(
    WalletDocument document,
    WalletDocumentSide side,
  ) => _serialized(() async {
    await _ensureInitialized();
    return _readDocumentBytes(await _current(document), side);
  });

  Future<File> decryptForView(
    WalletDocument document,
    WalletDocumentSide side,
  ) => _serialized(() async {
    await _ensureInitialized();
    final current = await _current(document);
    if (side != WalletDocumentSide.pdf) {
      throw ArgumentError('Images must be read directly into memory.');
    }
    await _purgeViewerCache();
    final bytes = await _readDocumentBytes(current, side);
    final directory = await _viewerRoot();
    final destination = File('${directory.path}/${_id()}.pdf');
    try {
      await destination.writeAsBytes(bytes, flush: true);
      return destination;
    } catch (_) {
      if (await destination.exists()) await destination.delete();
      rethrow;
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  });

  Future<void> purgeViewerCache() => _serialized(_purgeViewerCache);

  Future<void> _purgeViewerCache() async {
    await _legacy.purgeViewerCache();
    await purgeTemporaryViewerFiles(cacheDirectory: _cacheDirectory);
  }

  static Future<void> purgeTemporaryViewerFiles({
    DirectoryResolver? cacheDirectory,
  }) async {
    final base = await (cacheDirectory ?? getTemporaryDirectory)();
    final root = Directory('${base.path}/$viewerFolder');
    if (!await root.exists()) return;
    await for (final entity in root.list(followLinks: false)) {
      await entity.delete(recursive: entity is Directory);
    }
  }

  Future<Uint8List> _readDocumentBytes(
    WalletDocument document,
    WalletDocumentSide side,
  ) async {
    final ref = document.fileFor(side);
    if (ref == null) throw ArgumentError('Document side is not available.');
    if (ref.legacyMetadata != null) {
      _checkedPath(ref.encryptedRelativePath);
      // The original store remains the authority for its injected paths and key.
      try {
        final file = await _legacy.decryptForView(ref.legacyMetadata!);
        return await _readLimited(file);
      } finally {
        await _legacy.purgeViewerCache();
      }
    }
    final file = await _ownedFile(ref.encryptedRelativePath);
    if (await file.length() > maxImportBytes + 128) {
      throw const FormatException('Encrypted wallet file is too large.');
    }
    return _crypto.decryptBytes(await file.readAsBytes(), await _masterKey());
  }

  Future<WalletDocument> _current(WalletDocument document) async {
    final row = await (_db.select(
      _db.privateDocuments,
    )..where((r) => r.id.equals(document.id))).getSingleOrNull();
    if (row == null) throw StateError('Document is no longer available.');
    return _document(row);
  }

  Future<void> _validateOwner(WalletOwner owner) async {
    if (owner.id.isEmpty) throw ArgumentError('Missing document owner.');
    if (owner.isPreparation) {
      _validatePreparationId(owner.id);
      if (await _preparation(owner.id) == null) {
        throw ArgumentError('Unknown document owner.');
      }
      return;
    }
    final exists = owner.isDriver
        ? await (_db.select(
                _db.driverProfiles,
              )..where((r) => r.id.equals(owner.id))).getSingleOrNull() !=
              null
        : await (_db.select(
                _db.vehicles,
              )..where((r) => r.id.equals(owner.id))).getSingleOrNull() !=
              null;
    if (!exists) throw ArgumentError('Unknown document owner.');
  }

  Future<PrivateDocument?> _find(WalletOwner owner, WalletDocumentType type) =>
      (_db.select(_db.privateDocuments)
            ..where((r) => _ownerFilter(r, owner) & r.type.equals(type.value)))
          .getSingleOrNull();

  Future<List<WalletDocument>> _documents(WalletOwner? owner) async {
    final query = _db.select(_db.privateDocuments);
    if (owner != null) {
      query.where((r) => _ownerFilter(r, owner));
    }
    query.orderBy([(r) => OrderingTerm.asc(r.type)]);
    return [for (final row in await query.get()) await _document(row)];
  }

  Expression<bool> _ownerFilter(PrivateDocuments row, WalletOwner owner) {
    if (owner.isDriver) return row.driverId.equals(owner.id);
    if (owner.isPreparation) return row.preparationId.equals(owner.id);
    return row.vehicleId.equals(owner.id);
  }

  Future<void> _insert(
    WalletDocument document, {
    bool Function()? isAuthorized,
  }) async {
    final encrypted = await _encrypt({
      'id': document.id,
      'driverId': document.owner.driverId,
      'vehicleId': document.owner.vehicleId,
      'preparationId': document.owner.preparationId,
      'type': document.type.value,
      'front': document.front?.toJson(),
      'back': document.back?.toJson(),
      'pdf': document.pdf?.toJson(),
      'metadata': document.metadata,
    });
    _requireAuthorized(isAuthorized);
    await _db
        .into(_db.privateDocuments)
        .insert(
          PrivateDocumentsCompanion.insert(
            id: document.id,
            driverId: Value(document.owner.driverId),
            vehicleId: Value(document.owner.vehicleId),
            preparationId: Value(document.owner.preparationId),
            type: document.type.value,
            importedAt: Value(document.importedAt),
            encryptedMetadata: encrypted,
          ),
        );
  }

  Future<WalletDriver> _driver(DriverProfile row) async {
    final data = await _decrypt(row.encryptedMetadata);
    if (data['id'] != row.id) {
      throw const FormatException('Driver metadata identity mismatch.');
    }
    return WalletDriver(
      id: row.id,
      displayName: data['displayName']! as String,
      isPrincipal: row.slot == 0,
    );
  }

  Future<WalletDocument> _document(PrivateDocument row) async {
    final data = await _decrypt(row.encryptedMetadata);
    if (data['id'] != row.id ||
        data['driverId'] != row.driverId ||
        data['vehicleId'] != row.vehicleId ||
        data['preparationId'] != row.preparationId ||
        data['type'] != row.type) {
      throw const FormatException('Document metadata identity mismatch.');
    }
    WalletFileRef? ref(String key) => data[key] == null
        ? null
        : WalletFileRef.fromJson(Map<String, Object?>.from(data[key]! as Map));
    return WalletDocument(
      id: row.id,
      owner: row.preparationId != null
          ? WalletOwner.preparation(row.preparationId!)
          : row.driverId == null
          ? WalletOwner.vehicle(row.vehicleId!)
          : WalletOwner.driver(row.driverId!),
      type: WalletDocumentType.fromValue(row.type),
      importedAt: row.importedAt,
      front: ref('front'),
      back: ref('back'),
      pdf: ref('pdf'),
      metadata: Map<String, String>.from(data['metadata']! as Map),
    );
  }

  Future<Uint8List> _encrypt(Map<String, Object?> data) async =>
      _crypto.encryptBytes(utf8.encode(jsonEncode(data)), await _masterKey());

  Future<Map<String, Object?>> _decrypt(Uint8List data) async {
    final bytes = await _crypto.decryptBytes(data, await _masterKey());
    try {
      return Map<String, Object?>.from(jsonDecode(utf8.decode(bytes)) as Map);
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  Future<void> _queueCleanup(WalletDocument document) async {
    final id = '$_cleanupPrefix${document.id}';
    await _db
        .into(_db.walletMigrations)
        .insertOnConflictUpdate(
          WalletMigrationsCompanion.insert(
            id: id,
            encryptedMetadata: await _encrypt({
              'id': id,
              'files': [
                for (final side in document.sides)
                  document.fileFor(side)!.toJson(),
              ],
            }),
          ),
        );
  }

  Future<WalletMigrationReport> retryPendingCleanup() => _serialized(() async {
    await _ensureInitialized();
    await _drainPendingCleanup();
    return _migrationReport;
  });

  Future<void> _drainPendingCleanup() async {
    final rows = await (_db.select(
      _db.walletMigrations,
    )..where((r) => r.id.like('$_cleanupPrefix%'))).get();
    var pending = 0;
    for (final row in rows) {
      try {
        final data = await _decrypt(row.encryptedMetadata);
        if (data['id'] != row.id) {
          throw const FormatException('Invalid wallet cleanup record.');
        }
        for (final item in data['files']! as List) {
          final ref = WalletFileRef.fromJson(
            Map<String, Object?>.from(item as Map),
          );
          if (ref.legacyMetadata != null) {
            await _legacy.removeMigratedReference(ref.legacyMetadata!);
          } else {
            final file = await _ownedFile(ref.encryptedRelativePath);
            if (await file.exists()) await file.delete();
          }
        }
        await (_db.delete(
          _db.walletMigrations,
        )..where((r) => r.id.equals(row.id))).go();
      } catch (_) {
        // Persist the exact retry request and expose the failure without leaking paths.
        pending++;
      }
    }
    _migrationReport = WalletMigrationReport(
      importedCount: _migrationReport.importedCount,
      orphanedCount: _migrationReport.orphanedCount,
      migrationFailed: _migrationReport.migrationFailed,
      pendingCleanupCount: pending,
    );
  }

  Future<void> _purgeUnreferencedEncryptedFiles() async {
    final root = Directory('${(await _rootDirectory()).path}/wallet_documents');
    if (!await root.exists()) return;
    final referenced = <String>{};
    for (final document in await _documents(null)) {
      for (final side in document.sides) {
        final ref = document.fileFor(side)!;
        if (ref.legacyMetadata == null) {
          referenced.add(_checkedPath(ref.encryptedRelativePath));
        }
      }
    }
    for (final row in await (_db.select(
      _db.walletMigrations,
    )..where((r) => r.id.like('$_cleanupPrefix%'))).get()) {
      final data = await _decrypt(row.encryptedMetadata);
      for (final item in data['files']! as List) {
        final ref = WalletFileRef.fromJson(
          Map<String, Object?>.from(item as Map),
        );
        if (ref.legacyMetadata == null) {
          referenced.add(_checkedPath(ref.encryptedRelativePath));
        }
      }
    }
    // A crash can leave ciphertext written before a transaction commits, or an
    // obsolete file after commit. Only collect files in this store's namespace.
    final prefix = '${root.absolute.path.replaceAll('\\', '/')}/';
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final path = entity.absolute.path.replaceAll('\\', '/');
      if (!path.startsWith(prefix)) continue;
      final relative = path.substring(prefix.length);
      if (RegExp(r'^docs/[a-f0-9]{32}/(front|back|pdf)\.prcf$')
              .hasMatch(relative) &&
          !referenced.contains(relative)) {
        await entity.delete();
      }
    }
  }

  Future<void> _validateInput(
    WalletDocumentInput input,
    WalletDocumentSide side,
  ) async {
    final extension = _safeName(input.originalName)
        .split('.')
        .last
        .toLowerCase();
    final mime = switch (extension) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      _ => null,
    };
    if (mime == null ||
        input.mimeType != mime ||
        (side == WalletDocumentSide.pdf) != (mime == 'application/pdf')) {
      throw ArgumentError('Unsupported document file type.');
    }
    if (!await input.source.exists()) {
      throw ArgumentError('Document file is missing.');
    }
    final length = await input.source.length();
    if (length == 0 || length > maxImportBytes) {
      throw ArgumentError('Document must contain between 1 byte and 25 MB.');
    }
  }

  Future<Uint8List> _readLimited(File file) async {
    final handle = await file.open();
    try {
      final bytes = await handle.read(maxImportBytes + 1);
      if (bytes.isEmpty || bytes.length > maxImportBytes) {
        bytes.fillRange(0, bytes.length, 0);
        throw ArgumentError('Document must contain between 1 byte and 25 MB.');
      }
      return bytes;
    } finally {
      await handle.close();
    }
  }

  Future<File> _ownedFile(String relativePath) async {
    final checked = _checkedPath(relativePath);
    if (!RegExp(r'^docs/[a-f0-9]{32}/(front|back|pdf)\.prcf$')
        .hasMatch(checked)) {
      throw const FormatException('Invalid wallet file reference.');
    }
    return File('${(await _rootDirectory()).path}/wallet_documents/$checked');
  }

  Future<Directory> _viewerRoot() async {
    final root = Directory('${(await _cacheDirectory()).path}/$viewerFolder');
    await root.create(recursive: true);
    return root;
  }

  static Future<Directory> _defaultRootDirectory() async =>
      Directory(await const WalletPlatform().noBackupDirectory());

  static String _checkedPath(String path) {
    final segments = path.replaceAll('\\', '/').split('/');
    if (path.contains(':') ||
        segments.any((s) => s.isEmpty || s == '.' || s == '..')) {
      throw const FormatException('Invalid encrypted document path.');
    }
    return segments.join('/');
  }

  static String _safeName(String name) {
    final result = name.replaceAll('\\', '/').split('/').last.trim();
    if (result.isEmpty || result.length > 255 || result.contains('\u0000')) {
      throw ArgumentError('Invalid document filename.');
    }
    return result;
  }

  static String _id() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  static void _requireAuthorized(bool Function()? isAuthorized) {
    if (isAuthorized != null && !isAuthorized()) {
      throw const WalletAuthorizationException();
    }
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final previous = _tails[_db] ?? Future<void>.value();
    final done = Completer<void>();
    _tails[_db] = done.future;
    return (() async {
      await previous;
      try {
        return await action();
      } finally {
        done.complete();
      }
    })();
  }
}
