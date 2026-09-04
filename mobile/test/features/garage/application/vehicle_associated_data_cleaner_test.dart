import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/storage/app_preferences.dart';
import 'package:picoradar/features/buy_sell/data/buy_sell_draft.dart';
import 'package:picoradar/features/defense/data/defense_case.dart';
import 'package:picoradar/features/defense/data/defense_case_store.dart';
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
  var documentIds = 0;
  var caseIds = 0;

  setUp(() {
    root = Directory.systemTemp.createTempSync('picoradar-cleaner-test-');
    preferences = _MemoryPreferences();
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
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

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
