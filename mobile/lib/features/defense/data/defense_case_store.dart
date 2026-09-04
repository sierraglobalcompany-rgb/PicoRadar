import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/storage/app_secure_storage.dart';
import '../../../core/storage/file_crypto.dart';
import 'defense_case.dart';

typedef DefenseDirectoryResolver = Future<Directory> Function();
typedef DefenseSecretKeyResolver = Future<SecretKey> Function();
typedef DefenseCaseIdGenerator = String Function();

class DefenseCaseStoreException implements Exception {
  const DefenseCaseStoreException(this.code);

  final String code;

  @override
  String toString() => 'DefenseCaseStoreException: $code';
}

class DefenseCaseStore {
  DefenseCaseStore({
    DefenseDirectoryResolver? rootDirectory,
    DefenseSecretKeyResolver? masterKey,
    FileCrypto? fileCrypto,
    DateTime Function()? now,
    DefenseCaseIdGenerator? idGenerator,
  }) : _rootDirectory = rootDirectory ?? _defaultRootDirectory,
       _masterKey = masterKey ?? AppSecureStorage().getOrCreateFileMasterKey,
       _fileCrypto = fileCrypto ?? FileCrypto(),
       _now = now ?? DateTime.now,
       _idGenerator = idGenerator ?? _secureId;

  static const storageFolder = 'defense_cases';
  static const indexFileName = 'index_v1.prcf';
  static const corruptIndexCode = 'DEFENSE_INDEX_CORRUPT';
  static const missingCaseCode = 'DEFENSE_CASE_NOT_FOUND';

  final DefenseDirectoryResolver _rootDirectory;
  final DefenseSecretKeyResolver _masterKey;
  final FileCrypto _fileCrypto;
  final DateTime Function() _now;
  final DefenseCaseIdGenerator _idGenerator;
  Future<void> _mutationTail = Future<void>.value();

  Future<List<DefenseCase>> listForVehicle(String vehicleId) async {
    final requestedVehicleId = vehicleId.trim();
    if (requestedVehicleId.isEmpty) {
      return const [];
    }
    final cases = await _readIndex();
    final filtered = [
      for (final item in cases)
        if (item.vehicleId == requestedVehicleId) item,
    ];
    filtered.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return filtered;
  }

  Future<DefenseCase> createCase(DefenseCaseDraft draft) {
    final normalized = _normalizeDraft(draft);
    return _runMutation(() async {
      final cases = await _readIndex();
      final now = _now().toUtc();
      final item = DefenseCase(
        id: _idGenerator(),
        vehicleId: normalized.vehicleId,
        reference: normalized.reference,
        authority: normalized.authority,
        incidentDate: normalized.incidentDate,
        notificationDate: normalized.notificationDate,
        facts: normalized.facts,
        createdAt: now,
        updatedAt: now,
      );
      await _writeIndex([...cases, item]);
      return item;
    });
  }

  Future<DefenseCase> updateCase({
    required String caseId,
    required DefenseCaseDraft draft,
  }) {
    final normalized = _normalizeDraft(draft);
    return _runMutation(() async {
      final cases = await _readIndex();
      DefenseCase? updated;
      final next = [
        for (final item in cases)
          if (item.id == caseId)
            updated = DefenseCase(
              id: item.id,
              vehicleId: item.vehicleId,
              reference: normalized.reference,
              authority: normalized.authority,
              incidentDate: normalized.incidentDate,
              notificationDate: normalized.notificationDate,
              facts: normalized.facts,
              createdAt: item.createdAt,
              updatedAt: _now().toUtc(),
            )
          else
            item,
      ];
      if (updated == null || updated.vehicleId != normalized.vehicleId) {
        throw const DefenseCaseStoreException(missingCaseCode);
      }
      await _writeIndex(next);
      return updated;
    });
  }

  Future<void> deleteCase(String caseId) {
    return _runMutation(() async {
      final cases = await _readIndex();
      final next = [
        for (final item in cases)
          if (item.id != caseId) item,
      ];
      if (next.length == cases.length) {
        throw const DefenseCaseStoreException(missingCaseCode);
      }
      await _writeIndex(next);
    });
  }

  Future<List<DefenseCase>> _readIndex() async {
    final indexFile = await _indexFile();
    if (!await indexFile.exists()) {
      return const [];
    }

    try {
      final key = await _masterKey();
      final raw = await _fileCrypto.decryptBytes(
        await indexFile.readAsBytes(),
        key,
      );
      final decoded = jsonDecode(utf8.decode(raw));
      if (decoded is! List) {
        throw const FormatException('Invalid defense case index.');
      }
      return [
        for (final item in decoded)
          if (item is Map)
            DefenseCase.fromJson(Map<String, Object?>.from(item))
          else
            throw const FormatException('Invalid defense case item.'),
      ];
    } on DefenseCaseStoreException {
      rethrow;
    } catch (_) {
      throw const DefenseCaseStoreException(corruptIndexCode);
    }
  }

  Future<void> _writeIndex(List<DefenseCase> cases) async {
    final indexFile = await _indexFile();
    final payload = utf8.encode(
      jsonEncode([for (final item in cases) item.toJson()]),
    );
    final key = await _masterKey();
    final encrypted = await _fileCrypto.encryptBytes(payload, key);
    await indexFile.parent.create(recursive: true);
    final stamp = _now().microsecondsSinceEpoch;
    final temp = File('${indexFile.path}.tmp.$stamp');
    final backup = File('${indexFile.path}.bak.$stamp');
    var backupCreated = false;
    try {
      await temp.writeAsBytes(encrypted, flush: true);
      if (await indexFile.exists()) {
        await indexFile.rename(backup.path);
        backupCreated = true;
      }
      await temp.rename(indexFile.path);
      if (backupCreated && await backup.exists()) {
        await _tryDeleteFile(backup);
      }
    } catch (_) {
      if (await temp.exists()) {
        await temp.delete();
      }
      if (backupCreated && await backup.exists() && !await indexFile.exists()) {
        await backup.rename(indexFile.path);
      }
      rethrow;
    }
  }

  Future<T> _runMutation<T>(Future<T> Function() action) {
    final previous = _mutationTail;
    final gate = Completer<void>();
    _mutationTail = gate.future;
    return (() async {
      await previous;
      try {
        return await action();
      } finally {
        gate.complete();
      }
    })();
  }

  Future<File> _indexFile() async {
    return File('${(await _storeRoot()).path}/$indexFileName');
  }

  Future<Directory> _storeRoot() async {
    final base = await _rootDirectory();
    final root = Directory('${base.path}/$storageFolder');
    await root.create(recursive: true);
    return root;
  }

  DefenseCaseDraft _normalizeDraft(DefenseCaseDraft draft) {
    final vehicleId = draft.vehicleId.trim();
    final authority = draft.authority.trim();
    final facts = draft.facts.trim();
    if (vehicleId.isEmpty || authority.isEmpty || facts.isEmpty) {
      throw ArgumentError(
        'Defense case requires vehicle, authority and facts.',
      );
    }
    final reference = draft.reference?.trim();
    return DefenseCaseDraft(
      vehicleId: vehicleId,
      reference: reference == null || reference.isEmpty ? null : reference,
      authority: authority,
      incidentDate: _dateOnly(draft.incidentDate),
      notificationDate: draft.notificationDate == null
          ? null
          : _dateOnly(draft.notificationDate!),
      facts: facts,
    );
  }

  static Future<Directory> _defaultRootDirectory() async {
    return getApplicationSupportDirectory();
  }

  static DateTime _dateOnly(DateTime date) {
    final normalized = date.toUtc();
    return DateTime.utc(normalized.year, normalized.month, normalized.day);
  }

  static Future<void> _tryDeleteFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      return;
    }
  }

  static String _secureId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}
