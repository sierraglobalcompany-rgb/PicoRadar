import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/core/storage/app_preferences.dart';
import 'package:picoradar/features/buy_sell/data/buy_sell_draft.dart';
import 'package:picoradar/features/defense/data/defense_case.dart';
import 'package:picoradar/features/defense/data/defense_case_store.dart';
import 'package:picoradar/features/documents/data/wallet_store.dart';
import 'package:picoradar/features/garage/application/vehicle_associated_data_cleaner.dart';
import 'package:picoradar/features/peritajes/data/peritajes_draft_store.dart';
import 'package:picoradar/features/trip/data/trip_draft_store.dart';
import 'package:picoradar/features/vehicle_status/data/private_vehicle_document_store.dart';

void main() {
  late Directory root;
  late _MemoryPreferences preferences;
  late PrivateVehicleDocumentStore documentStore;
  late DefenseCaseStore defenseCaseStore;
  late PeritajesDraftStore peritajesDraftStore;
  late VehicleAssociatedDataCleaner cleaner;
  late AppDatabase database;
  var documentIds = 0;
  var caseIds = 0;

  setUp(() {
    root = Directory.systemTemp.createTempSync('picoradar-cleaner-test-');
    preferences = _MemoryPreferences();
    database = AppDatabase(NativeDatabase.memory());
    documentIds = 0;
    caseIds = 0;
    documentStore = PrivateVehicleDocumentStore(
      rootDirectory: () async => root,
      cacheDirectory: () async => root,
      masterKey: () async => SecretKey(List<int>.filled(32, 7)),
      idGenerator: () => 'doc-${(++documentIds).toString().padLeft(4, '0')}',
      now: () => DateTime.utc(2026, 9, 4, 9),
    );
    defenseCaseStore = DefenseCaseStore(
      rootDirectory: () async => root,
      masterKey: () async => SecretKey(List<int>.filled(32, 8)),
      idGenerator: () => 'case-${(++caseIds).toString().padLeft(4, '0')}',
      now: () => DateTime.utc(2026, 9, 4, 9),
    );
    peritajesDraftStore = PeritajesDraftStore(preferences);
    cleaner = VehicleAssociatedDataCleaner(
      documentStore: documentStore,
      defenseCaseStore: defenseCaseStore,
      peritajesDraftStore: peritajesDraftStore,
      preferences: preferences,
    );
  });

  tearDown(() async {
    await database.close();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  WalletStore wallet() => WalletStore(
    db: database,
    legacyStore: documentStore,
    rootDirectory: () async => root,
    cacheDirectory: () async => root,
    masterKey: () async => SecretKey(List<int>.filled(32, 7)),
  );

  VehicleAssociatedDataCleaner walletCleaner(WalletStore store) =>
      VehicleAssociatedDataCleaner(
        walletStore: store,
        defenseCaseStore: defenseCaseStore,
        peritajesDraftStore: peritajesDraftStore,
        preferences: preferences,
      );

  test(
    'cold cleanup migrates before deletion and cannot resurrect legacy copy',
    () async {
      await database
          .into(database.vehicles)
          .insert(VehiclesCompanion.insert(id: 'vehicle-1', plate: 'AAA123'));
      final source = File('${root.path}/migration.pdf');
      await source.writeAsBytes([37, 80, 68, 70, 45, 49]);
      final old = await documentStore.importDocument(
        vehicleId: 'vehicle-1',
        documentType: PrivateVehicleDocumentType.soat,
        source: source,
        originalName: 'migration.pdf',
        mimeType: 'application/pdf',
      );
      await walletCleaner(wallet()).deleteForVehicle('vehicle-1');
      expect(await wallet().listDocuments(), isEmpty);
      expect(
        await File(
          '${root.path}/vehicle_documents/${old.encryptedRelativePath}',
        ).exists(),
        isFalse,
      );
      expect(
        await database.select(database.walletMigrations).get(),
        hasLength(1),
      );
      expect(await database.select(database.vehicles).get(), hasLength(1));
    },
  );

  test(
    'unified cleanup never deletes driver documents with matching owner id',
    () async {
      for (final id in ['principal', 'other-vehicle']) {
        await database
            .into(database.vehicles)
            .insert(
              VehiclesCompanion.insert(
                id: id,
                plate: id == 'principal' ? 'AAA123' : 'BBB123',
              ),
            );
      }
      final store = wallet();
      final source = File('${root.path}/document.pdf');
      final bytes = [37, 80, 68, 70, 45, 49];
      await source.writeAsBytes(bytes);
      final input = WalletDocumentInput(
        source: source,
        originalName: 'document.pdf',
        mimeType: 'application/pdf',
      );
      final driver = await store.saveDocument(
        owner: const WalletOwner.driver('principal'),
        type: WalletDocumentType.identityCard,
        pdf: input,
      );
      await store.saveDocument(
        owner: const WalletOwner.vehicle('principal'),
        type: WalletDocumentType.soat,
        pdf: input,
      );
      final other = await store.saveDocument(
        owner: const WalletOwner.vehicle('other-vehicle'),
        type: WalletDocumentType.rtm,
        pdf: input,
      );
      await walletCleaner(wallet()).deleteForVehicle(' principal ');
      final remaining = await store.listDocuments();
      expect(
        remaining.map((doc) => doc.id),
        unorderedEquals([driver.id, other.id]),
      );
      expect(
        await store.readDocumentBytes(driver, WalletDocumentSide.pdf),
        bytes,
      );
      expect(await store.listDrivers(), hasLength(1));
    },
  );

  test(
    'failed wallet initialization preserves all associated data and can retry',
    () async {
      await preferences.setString(
        'comparendos.last_checked.vehicle-1',
        '2026-09-04',
      );
      final store = _OrderedWalletStore()..failInitialization = true;
      final deleting = walletCleaner(store);
      await expectLater(
        deleting.deleteForVehicle('vehicle-1'),
        throwsStateError,
      );
      expect(store.calls, ['initialize']);
      expect(
        await preferences.getString('comparendos.last_checked.vehicle-1'),
        '2026-09-04',
      );
      store.failInitialization = false;
      await deleting.deleteForVehicle('vehicle-1');
      expect(store.calls, ['initialize', 'initialize', 'delete:vehicle-1']);
      expect(
        await preferences.getString('comparendos.last_checked.vehicle-1'),
        isNull,
      );
    },
  );

  test('empty vehicle id never initializes or deletes wallet', () async {
    final store = _OrderedWalletStore();
    await walletCleaner(store).deleteForVehicle('  ');
    expect(store.calls, isEmpty);
  });

  test(
    'guarded cleanup preserves encrypted copy and note until authorized',
    () async {
      await database
          .into(database.vehicles)
          .insert(VehiclesCompanion.insert(id: 'vehicle-1', plate: 'AAA123'));
      final source = File('${root.path}/guarded.pdf');
      await source.writeAsBytes([37, 80, 68, 70, 45, 49]);
      final old = await documentStore.importDocument(
        vehicleId: 'vehicle-1',
        documentType: PrivateVehicleDocumentType.soat,
        source: source,
        originalName: 'guarded.pdf',
        mimeType: 'application/pdf',
      );
      final encrypted = File(
        '${root.path}/vehicle_documents/${old.encryptedRelativePath}',
      );
      await preferences.setString('comparendos.last_checked.vehicle-1', 'kept');
      final deleting = walletCleaner(wallet());
      await expectLater(
        deleting.deletePrivateDataForVehicle(
          'vehicle-1',
          isAuthorized: () => false,
        ),
        throwsStateError,
      );
      expect(await encrypted.exists(), isTrue);
      expect(await documentStore.listForVehicle('vehicle-1'), hasLength(1));
      expect(await database.select(database.walletMigrations).get(), isEmpty);
      expect(
        await preferences.getString('comparendos.last_checked.vehicle-1'),
        'kept',
      );

      await deleting.deletePrivateDataForVehicle(
        'vehicle-1',
        isAuthorized: () => true,
      );
      expect(await encrypted.exists(), isFalse);
      expect(await wallet().listDocuments(), isEmpty);
      expect(
        await preferences.getString('comparendos.last_checked.vehicle-1'),
        isNull,
      );
    },
  );

  test(
    'authorization revoked during initialization preserves notes and copies',
    () async {
      var authorized = true;
      final store = _OrderedWalletStore()
        ..onInitialize = () => authorized = false;
      await preferences.setString('comparendos.last_checked.vehicle-1', 'kept');
      await expectLater(
        walletCleaner(store).deletePrivateDataForVehicle(
          'vehicle-1',
          isAuthorized: () => authorized,
        ),
        throwsStateError,
      );
      expect(store.calls, ['initialize']);
      expect(
        await preferences.getString('comparendos.last_checked.vehicle-1'),
        'kept',
      );
    },
  );

  test(
    'guard is forwarded to wallet transaction instead of checked only once',
    () async {
      var authorized = true;
      final store = _OrderedWalletStore()
        ..beforeDelete = () => authorized = false;
      await preferences.setString('comparendos.last_checked.vehicle-1', 'kept');
      await expectLater(
        walletCleaner(store).deletePrivateDataForVehicle(
          'vehicle-1',
          isAuthorized: () => authorized,
        ),
        throwsStateError,
      );
      expect(store.calls, ['initialize']);
      expect(store.deletionAuthorization, isNotNull);
      expect(
        await preferences.getString('comparendos.last_checked.vehicle-1'),
        'kept',
      );
    },
  );

  test('deleteForVehicle cleans vehicle data without deleting other drafts', () async {
    final targetSource = File('${root.path}/target.pdf');
    final otherSource = File('${root.path}/other.pdf');
    await targetSource.writeAsBytes([1, 2, 3]);
    await otherSource.writeAsBytes([4, 5, 6]);
    final targetDocument = await documentStore.importDocument(
      vehicleId: 'vehicle-1',
      documentType: PrivateVehicleDocumentType.soat,
      source: targetSource,
      originalName: 'target.pdf',
      mimeType: 'application/pdf',
    );
    final otherDocument = await documentStore.importDocument(
      vehicleId: 'vehicle-2',
      documentType: PrivateVehicleDocumentType.soat,
      source: otherSource,
      originalName: 'other.pdf',
      mimeType: 'application/pdf',
    );
    final targetViewer = File(
      '${root.path}/vehicle_document_viewer/${targetDocument.documentId}/target.pdf',
    );
    await targetViewer.parent.create(recursive: true);
    await targetViewer.writeAsBytes([1, 2, 3]);

    await defenseCaseStore.createCase(_caseDraft('vehicle-1', 'Objetivo'));
    final otherCase = await defenseCaseStore.createCase(
      _caseDraft('vehicle-2', 'Otro'),
    );
    final draft = PeritajesDraft(
      checkedItems: const {'frenos'},
      notes: 'Revisar pedal.',
      updatedAt: DateTime.utc(2026, 9, 4),
    );
    await peritajesDraftStore.saveDraft('vehicle-1', draft);
    await peritajesDraftStore.saveDraft('vehicle-2', draft);
    await preferences.setString(
      'comparendos.last_checked.vehicle-1',
      '2026-09-04',
    );
    await preferences.setString(
      'comparendos.last_checked.vehicle-2',
      '2026-09-03',
    );
    await preferences.setString(buySellDraftPreferenceKey, 'keep-buy-sell');
    await preferences.setString(tripDraftPreferenceKey, 'keep-trip');

    await cleaner.deleteForVehicle('vehicle-1');
    await cleaner.deleteForVehicle('vehicle-1');

    expect(await documentStore.listForVehicle('vehicle-1'), isEmpty);
    expect(
      (await documentStore.listForVehicle('vehicle-2')).single.documentId,
      otherDocument.documentId,
    );
    expect(
      await File(
        '${root.path}/vehicle_documents/${targetDocument.encryptedRelativePath}',
      ).exists(),
      isFalse,
    );
    expect(
      await File(
        '${root.path}/vehicle_documents/${otherDocument.encryptedRelativePath}',
      ).exists(),
      isTrue,
    );
    expect(await targetViewer.exists(), isFalse);
    expect(await defenseCaseStore.listForVehicle('vehicle-1'), isEmpty);
    expect(
      (await defenseCaseStore.listForVehicle('vehicle-2')).single.id,
      otherCase.id,
    );
    expect(await peritajesDraftStore.loadDraft('vehicle-1'), isNull);
    expect(await peritajesDraftStore.loadDraft('vehicle-2'), isNotNull);
    expect(
      await preferences.getString('comparendos.last_checked.vehicle-1'),
      isNull,
    );
    expect(
      await preferences.getString('comparendos.last_checked.vehicle-2'),
      '2026-09-03',
    );
    expect(
      await preferences.getString(buySellDraftPreferenceKey),
      'keep-buy-sell',
    );
    expect(await preferences.getString(tripDraftPreferenceKey), 'keep-trip');
  });

  test(
    'document cleanup failure preserves associated data until retry succeeds',
    () async {
      final source = File('${root.path}/target.pdf');
      await source.writeAsBytes([1, 2, 3]);
      final document = await documentStore.importDocument(
        vehicleId: 'vehicle-1',
        documentType: PrivateVehicleDocumentType.soat,
        source: source,
        originalName: 'target.pdf',
        mimeType: 'application/pdf',
      );
      final caseSummary = await defenseCaseStore.createCase(
        _caseDraft('vehicle-1', 'Objetivo'),
      );
      final draft = PeritajesDraft(
        checkedItems: const {'luces'},
        notes: 'Pendiente.',
        updatedAt: DateTime.utc(2026, 9, 4),
      );
      await peritajesDraftStore.saveDraft('vehicle-1', draft);
      await preferences.setString(
        'comparendos.last_checked.vehicle-1',
        '2026-09-04',
      );
      final retryCleaner = VehicleAssociatedDataCleaner(
        documentStore: _FailOnceDeleteDocumentStore(documentStore),
        defenseCaseStore: defenseCaseStore,
        peritajesDraftStore: peritajesDraftStore,
        preferences: preferences,
      );

      await expectLater(
        retryCleaner.deleteForVehicle('vehicle-1'),
        throwsStateError,
      );

      expect(
        (await documentStore.listForVehicle('vehicle-1')).single.documentId,
        document.documentId,
      );
      expect(
        (await defenseCaseStore.listForVehicle('vehicle-1')).single.id,
        caseSummary.id,
      );
      expect(await peritajesDraftStore.loadDraft('vehicle-1'), isNotNull);
      expect(
        await preferences.getString('comparendos.last_checked.vehicle-1'),
        '2026-09-04',
      );

      await retryCleaner.deleteForVehicle('vehicle-1');

      expect(await documentStore.listForVehicle('vehicle-1'), isEmpty);
      expect(await defenseCaseStore.listForVehicle('vehicle-1'), isEmpty);
      expect(await peritajesDraftStore.loadDraft('vehicle-1'), isNull);
      expect(
        await preferences.getString('comparendos.last_checked.vehicle-1'),
        isNull,
      );
    },
  );
}

DefenseCaseDraft _caseDraft(String vehicleId, String facts) {
  return DefenseCaseDraft(
    vehicleId: vehicleId,
    reference: 'CMP-123',
    authority: 'Secretaria de Movilidad',
    incidentDate: DateTime.utc(2026, 9, 1),
    notificationDate: DateTime.utc(2026, 9, 2),
    facts: facts,
  );
}

class _MemoryPreferences implements AppPreferences {
  final values = <String, Object?>{};

  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;

  @override
  Future<int?> getInt(String key) async => values[key] as int?;

  @override
  Future<String?> getString(String key) async => values[key] as String?;

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<void> setBool(String key, bool value) async {
    values[key] = value;
  }

  @override
  Future<void> setInt(String key, int value) async {
    values[key] = value;
  }

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

class _FailOnceDeleteDocumentStore extends PrivateVehicleDocumentStore {
  _FailOnceDeleteDocumentStore(this.delegate);

  final PrivateVehicleDocumentStore delegate;
  var calls = 0;

  @override
  Future<void> deleteForVehicle(String vehicleId) {
    calls += 1;
    if (calls == 1) {
      throw StateError('document cleanup failed');
    }
    return delegate.deleteForVehicle(vehicleId);
  }
}

class _OrderedWalletStore implements WalletStore {
  final calls = <String>[];
  bool failInitialization = false;
  void Function()? onInitialize;
  void Function()? beforeDelete;
  bool Function()? deletionAuthorization;

  @override
  Future<WalletMigrationReport> initialize() async {
    calls.add('initialize');
    if (failInitialization) throw StateError('migration failed');
    onInitialize?.call();
    return const WalletMigrationReport();
  }

  @override
  Future<void> deleteForVehicle(
    String id, {
    bool Function()? isAuthorized,
  }) async {
    deletionAuthorization = isAuthorized;
    beforeDelete?.call();
    if (isAuthorized != null && !isAuthorized()) throw StateError('Locked');
    calls.add('delete:$id');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
