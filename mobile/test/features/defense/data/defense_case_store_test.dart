import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/storage/file_crypto.dart';
import 'package:picoradar/features/defense/data/defense_case.dart';
import 'package:picoradar/features/defense/data/defense_case_store.dart';

void main() {
  late Directory root;
  late DefenseCaseStore store;
  var ids = 0;

  setUp(() {
    root = Directory.systemTemp.createTempSync('picoradar-defense-test-');
    ids = 0;
    store = DefenseCaseStore(
      rootDirectory: () async => root,
      masterKey: () async => SecretKey(List<int>.filled(32, 11)),
      idGenerator: () => 'case-${(++ids).toString().padLeft(4, '0')}',
      now: () => DateTime.utc(2026, 9, 3, 8),
    );
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('creates vehicle-scoped cases in one encrypted index v1', () async {
    final item = await store.createCase(_draft(facts: 'Hechos sensibles'));

    expect(item.id, 'case-0001');
    expect(item.vehicleId, 'vehicle-1');
    expect(item.createdAt, DateTime.utc(2026, 9, 3, 8));
    expect((await store.listForVehicle('vehicle-1')).single.id, item.id);
    expect(await store.listForVehicle('vehicle-2'), isEmpty);

    final index = _indexFile(root);
    expect(await index.exists(), isTrue);
    final encrypted = await index.readAsBytes();
    expect(encrypted.take(4), [0x50, 0x52, 0x43, 0x46]);
    expect(
      String.fromCharCodes(encrypted),
      isNot(contains('Hechos sensibles')),
    );
    expect(String.fromCharCodes(encrypted), isNot(contains('Secretaria')));
  });

  test('reads existing encrypted index v1', () async {
    final key = SecretKey(List<int>.filled(32, 11));
    final index = _indexFile(root);
    await index.parent.create(recursive: true);
    await index.writeAsBytes(
      await FileCrypto().encryptBytes(
        utf8.encode(
          jsonEncode([
            _caseJson(
              id: 'legacy-case',
              vehicleId: 'vehicle-1',
              facts: 'Texto guardado',
            ),
          ]),
        ),
        key,
      ),
    );

    final cases = await store.listForVehicle('vehicle-1');

    expect(cases.single.id, 'legacy-case');
    expect(cases.single.facts, 'Texto guardado');
  });

  test(
    'updates and deletes cases without moving them across vehicles',
    () async {
      final original = await store.createCase(_draft());

      final updated = await store.updateCase(
        caseId: original.id,
        draft: _draft(
          reference: null,
          authority: 'Transito local',
          incidentDate: DateTime.utc(2026, 9, 2),
          notificationDate: null,
          facts: 'Hechos corregidos',
        ),
      );

      expect(updated.reference, isNull);
      expect(updated.authority, 'Transito local');
      expect(updated.facts, 'Hechos corregidos');
      expect(updated.createdAt, original.createdAt);
      expect(updated.updatedAt, DateTime.utc(2026, 9, 3, 8));

      await store.deleteCase(original.id);
      expect(await store.listForVehicle('vehicle-1'), isEmpty);
    },
  );

  test('rolls back a failed index write atomically', () async {
    final original = await store.createCase(_draft(facts: 'Version original'));
    final failingStore = DefenseCaseStore(
      rootDirectory: () async => root,
      masterKey: () async => SecretKey(List<int>.filled(32, 11)),
      fileCrypto: _FailingIndexCrypto(),
      now: () => DateTime.utc(2026, 9, 3, 9),
    );

    await expectLater(
      failingStore.updateCase(
        caseId: original.id,
        draft: _draft(facts: 'Version fallida'),
      ),
      throwsStateError,
    );

    final cases = await store.listForVehicle('vehicle-1');
    expect(cases.single.facts, 'Version original');
  });

  test('serializes concurrent mutations', () async {
    final crypto = _BlockingIndexCrypto();
    final serializedStore = DefenseCaseStore(
      rootDirectory: () async => root,
      masterKey: () async => SecretKey(List<int>.filled(32, 11)),
      fileCrypto: crypto,
      idGenerator: () => 'queued-${(++ids).toString().padLeft(4, '0')}',
      now: () => DateTime.utc(2026, 9, 3, 8),
    );

    final first = serializedStore.createCase(_draft(facts: 'Primero'));
    await crypto.firstIndexWrite.future;
    final second = serializedStore.createCase(_draft(facts: 'Segundo'));

    await expectLater(
      crypto.secondIndexWrite.future.timeout(const Duration(milliseconds: 40)),
      throwsA(isA<TimeoutException>()),
    );

    crypto.releaseFirstIndexWrite();
    await crypto.secondIndexWrite.future;
    crypto.releaseSecondIndexWrite();

    await first;
    await second;
    final cases = await serializedStore.listForVehicle('vehicle-1');
    expect(cases.map((item) => item.facts).toSet(), {'Primero', 'Segundo'});
  });

  test('surfaces corrupt index with a sanitized error', () async {
    final index = _indexFile(root);
    await index.parent.create(recursive: true);
    await index.writeAsBytes([1, 2, 3, 4]);

    await expectLater(
      store.listForVehicle('vehicle-1'),
      throwsA(
        isA<DefenseCaseStoreException>().having(
          (error) => error.code,
          'code',
          DefenseCaseStore.corruptIndexCode,
        ),
      ),
    );
  });

  test('failed technical errors do not include user facts', () async {
    final original = await store.createCase(
      _draft(facts: 'Dato privado unico'),
    );
    final failingStore = DefenseCaseStore(
      rootDirectory: () async => root,
      masterKey: () async => SecretKey(List<int>.filled(32, 11)),
      fileCrypto: _FailingIndexCrypto(),
    );

    Object? thrown;
    try {
      await failingStore.updateCase(
        caseId: original.id,
        draft: _draft(facts: 'Dato privado unico actualizado'),
      );
    } catch (error) {
      thrown = error;
    }

    expect(thrown, isNotNull);
    expect(thrown.toString(), isNot(contains('Dato privado unico')));
    expect(thrown.toString(), isNot(contains('actualizado')));
  });
}

DefenseCaseDraft _draft({
  String vehicleId = 'vehicle-1',
  String? reference = 'CMP-123',
  String authority = 'Secretaria de Movilidad',
  DateTime? incidentDate,
  DateTime? notificationDate,
  String facts = 'Hechos escritos por el usuario',
}) {
  return DefenseCaseDraft(
    vehicleId: vehicleId,
    reference: reference,
    authority: authority,
    incidentDate: incidentDate ?? DateTime.utc(2026, 9, 1),
    notificationDate: notificationDate ?? DateTime.utc(2026, 9, 4),
    facts: facts,
  );
}

Map<String, Object?> _caseJson({
  required String id,
  required String vehicleId,
  required String facts,
}) {
  return {
    'id': id,
    'vehicleId': vehicleId,
    'reference': 'CMP-123',
    'authority': 'Secretaria de Movilidad',
    'incidentDate': '2026-09-01',
    'notificationDate': '2026-09-04',
    'facts': facts,
    'createdAt': '2026-09-03T08:00:00.000Z',
    'updatedAt': '2026-09-03T08:00:00.000Z',
  };
}

File _indexFile(Directory root) {
  return File(
    '${root.path}/${DefenseCaseStore.storageFolder}/${DefenseCaseStore.indexFileName}',
  );
}

class _FailingIndexCrypto extends FileCrypto {
  @override
  Future<Uint8List> encryptBytes(List<int> plaintext, SecretKey key) {
    throw StateError('index write failed');
  }
}

class _BlockingIndexCrypto extends FileCrypto {
  final firstIndexWrite = Completer<void>();
  final secondIndexWrite = Completer<void>();
  final _releaseFirst = Completer<void>();
  final _releaseSecond = Completer<void>();
  var indexWrites = 0;

  @override
  Future<Uint8List> encryptBytes(List<int> plaintext, SecretKey key) async {
    indexWrites += 1;
    if (indexWrites == 1) {
      firstIndexWrite.complete();
      await _releaseFirst.future;
    } else if (indexWrites == 2) {
      secondIndexWrite.complete();
      await _releaseSecond.future;
    }
    return super.encryptBytes(plaintext, key);
  }

  void releaseFirstIndexWrite() {
    if (!_releaseFirst.isCompleted) {
      _releaseFirst.complete();
    }
  }

  void releaseSecondIndexWrite() {
    if (!_releaseSecond.isCompleted) {
      _releaseSecond.complete();
    }
  }
}
