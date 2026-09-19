import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/theme/app_theme.dart';
import 'package:picoradar/features/comparendos/presentation/comparendos_screen.dart';
import 'package:picoradar/features/defense/application/defense_case_providers.dart';
import 'package:picoradar/features/defense/data/defense_case.dart';
import 'package:picoradar/features/defense/data/defense_case_store.dart';
import 'package:picoradar/features/documents/application/wallet_providers.dart';
import 'package:picoradar/features/documents/application/wallet_session.dart';
import 'package:picoradar/features/documents/data/wallet_store.dart';
import 'package:picoradar/features/documents/presentation/documents_screen.dart';
import 'package:picoradar/features/garage/application/vehicle_associated_data_cleaner.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/peritajes/data/peritajes_draft_store.dart';
import 'package:picoradar/features/pico_placa/data/pico_preferences.dart';
import 'package:picoradar/features/pico_placa/platform/pico_notifications.dart';
import 'package:picoradar/features/settings/presentation/settings_screen.dart';
import 'package:picoradar/features/trip/application/trip_services.dart';
import 'package:picoradar/features/vehicle_status/data/private_vehicle_document_store.dart';
import 'package:picoradar/features/vehicle_status/platform/external_launcher.dart';

import '../../../test_app_harness.dart';
import '../../home/presentation/v01b_test_font.dart';

void main() {
  setUpAll(loadV01bTestFont);
  late MemoryPreferences preferences;
  late _FakePicoNotificationScheduler scheduler;
  late _FakeExternalLauncher launcher;
  late _FakeDocumentStore documentStore;
  late int avatarCalls;
  late int configureCalls;

  setUp(() {
    preferences = MemoryPreferences();
    scheduler = _FakePicoNotificationScheduler();
    launcher = _FakeExternalLauncher();
    documentStore = _FakeDocumentStore();
    avatarCalls = 0;
    configureCalls = 0;
  });

  testWidgets('renders required sections and avatar callback', (tester) async {
    await _pumpSettings(
      tester,
      preferences: preferences,
      scheduler: scheduler,
      launcher: launcher,
      documentStore: documentStore,
      onChangeAvatar: () => avatarCalls += 1,
      onConfigureNotifications: () => configureCalls += 1,
    );

    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.text('Apariencia'), findsOneWidget);
    expect(find.text('Notificaciones'), findsOneWidget);
    expect(find.text('Privacidad'), findsOneWidget);
    expect(find.text('Fuentes'), findsOneWidget);
    expect(find.text('Soporte'), findsOneWidget);
    expect(find.text('Borrar todo'), findsNothing);
    expect(
      find.text('Borrar archivos y expedientes del vehículo favorito'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('settings-change-avatar')));
    await tester.pump();
    expect(avatarCalls, 1);

    await tester.tap(
      find.byKey(const ValueKey('settings-go-home-notifications')),
    );
    await tester.pump();
    expect(configureCalls, 1);
  });

  testWidgets('system notification false overrides stale local grant', (
    tester,
  ) async {
    preferences.values[picoRestrictionAlertsEnabledKey] = true;
    preferences.values[picoNotificationPermissionRequestedKey] = true;
    preferences.values[picoNotificationPermissionGrantedKey] = true;
    scheduler.areEnabledResult = false;

    await _pumpSettings(
      tester,
      preferences: preferences,
      scheduler: scheduler,
      launcher: launcher,
      documentStore: documentStore,
      onChangeAvatar: () {},
    );

    expect(find.text('Permiso del sistema: desactivado.'), findsOneWidget);
    expect(find.text('Permiso del sistema: activo.'), findsNothing);
    expect(find.text('Alertas locales: activadas.'), findsOneWidget);
    expect(scheduler.areEnabledCalls, 1);
    expect(scheduler.requestPermissionCalls, 0);
  });

  testWidgets('system notification true overrides stale local denial', (
    tester,
  ) async {
    preferences.values[picoNotificationPermissionRequestedKey] = true;
    preferences.values[picoNotificationPermissionGrantedKey] = false;
    scheduler.areEnabledResult = true;

    await _pumpSettings(
      tester,
      preferences: preferences,
      scheduler: scheduler,
      launcher: launcher,
      documentStore: documentStore,
      onChangeAvatar: () {},
    );

    expect(find.text('Permiso del sistema: activo.'), findsOneWidget);
  });

  testWidgets('unknown system notification state shows last local grant only', (
    tester,
  ) async {
    preferences.values[picoNotificationPermissionRequestedKey] = true;
    preferences.values[picoNotificationPermissionGrantedKey] = true;
    scheduler.areEnabledResult = null;

    await _pumpSettings(
      tester,
      preferences: preferences,
      scheduler: scheduler,
      launcher: launcher,
      documentStore: documentStore,
      onChangeAvatar: () {},
    );

    expect(
      find.text(
        'Permiso del sistema: no disponible; último estado local: activo.',
      ),
      findsOneWidget,
    );
    expect(find.text('Permiso del sistema: activo.'), findsNothing);
  });

  testWidgets('refreshes system notification truth after screen remount', (
    tester,
  ) async {
    scheduler.areEnabledResult = true;
    final container = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWithValue(preferences),
        picoNotificationSchedulerProvider.overrideWithValue(scheduler),
        externalLauncherProvider.overrideWithValue(launcher),
        privateVehicleDocumentStoreProvider.overrideWithValue(documentStore),
        vehicleAssociatedDataCleanerProvider.overrideWithValue(
          _FakeVehicleDataCleaner(),
        ),
        cameraDatasetDiagnosticProvider.overrideWithValue(
          const AsyncValue.data(
            CameraDatasetDiagnostic(version: 'test-cameras', count: 2),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await _pumpSettingsWithContainer(tester, container);
    expect(find.text('Permiso del sistema: activo.'), findsOneWidget);
    expect(scheduler.areEnabledCalls, 1);

    await _unmountContainer(tester, container);
    scheduler.areEnabledResult = false;

    await _pumpSettingsWithContainer(tester, container);
    expect(find.text('Permiso del sistema: desactivado.'), findsOneWidget);
    expect(find.text('Permiso del sistema: activo.'), findsNothing);
    expect(scheduler.areEnabledCalls, 2);
  });

  testWidgets(
    'unknown system notification state stays prudent before request',
    (tester) async {
      scheduler.areEnabledResult = null;

      await _pumpSettings(
        tester,
        preferences: preferences,
        scheduler: scheduler,
        launcher: launcher,
        documentStore: documentStore,
        onChangeAvatar: () {},
      );

      expect(
        find.text(
          'Permiso del sistema: no disponible; no se ha solicitado desde Ajustes.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Permiso del sistema: sin solicitar desde Ajustes.'),
        findsNothing,
      );
    },
  );

  testWidgets('states local privacy truths', (tester) async {
    await _pumpSettings(
      tester,
      preferences: preferences,
      scheduler: scheduler,
      launcher: launcher,
      documentStore: documentStore,
      onChangeAvatar: () {},
    );

    expect(
      find.text('Los datos del vehículo viven en este dispositivo.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Los documentos se guardan cifrados en almacenamiento privado.',
      ),
      findsOneWidget,
    );
    expect(find.text('PicoRadar funciona sin cuenta.'), findsOneWidget);
    expect(
      find.text('No hay sincronización en nube en Free 1.0.'),
      findsOneWidget,
    );
    expect(find.text('No guardamos historial GPS.'), findsOneWidget);
    expect(find.text('No subimos GPS al servidor.'), findsOneWidget);
  });

  testWidgets('runs only real local cleanup actions after confirmation', (
    tester,
  ) async {
    final activeVehicle = _vehicle(id: 'vehicle-1', plate: 'ABC123');
    preferences.values['trip.draft.v1'] =
        '{"origin":"A","destination":"B",'
        '"date":"2026-09-03","completedChecklist":[]}';
    preferences.values['comparendos.last_checked.vehicle-1'] = '2026-09-03';

    await _pumpSettings(
      tester,
      preferences: preferences,
      scheduler: scheduler,
      launcher: launcher,
      documentStore: documentStore,
      activeVehicle: activeVehicle,
      onChangeAvatar: () {},
    );

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('settings-purge-document-viewer')),
    );
    await tester.pumpAndSettle();
    expect(documentStore.purgeViewerCacheCalls, 1);
    final wallet = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    ).read(walletStoreProvider) as _SettingsWalletStore;
    expect(wallet.purgeCalls, 1);

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('settings-delete-trip-draft')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Borrar borrador de Viaje'), findsWidgets);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(preferences.values.containsKey('trip.draft.v1'), isTrue);

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('settings-delete-trip-draft')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(preferences.values.containsKey('trip.draft.v1'), isFalse);

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('settings-delete-comparendos-note')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Borrar nota de Comparendos'), findsWidgets);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(
      preferences.values.containsKey('comparendos.last_checked.vehicle-1'),
      isTrue,
    );

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('settings-delete-comparendos-note')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(
      preferences.values.containsKey('comparendos.last_checked.vehicle-1'),
      isFalse,
    );
    expect(find.textContaining('ABC123'), findsNothing);
  });

  testWidgets('shows no active vehicle message for Comparendos cleanup', (
    tester,
  ) async {
    await _pumpSettings(
      tester,
      preferences: preferences,
      scheduler: scheduler,
      launcher: launcher,
      documentStore: documentStore,
      activeVehicleFuture: Future<VehicleProfile?>.value(),
      onChangeAvatar: () {},
    );

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('settings-delete-comparendos-note')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    expect(find.text('No hay vehículo favorito para limpiar.'), findsOneWidget);
  });

  testWidgets('cleans active vehicle private data only after confirmation', (
    tester,
  ) async {
    final activeVehicle = _vehicle(id: 'vehicle-1', plate: 'ABC123');
    final cleaner = _FakeVehicleDataCleaner();

    await _pumpSettings(
      tester,
      preferences: preferences,
      scheduler: scheduler,
      launcher: launcher,
      documentStore: documentStore,
      vehicleAssociatedDataCleaner: cleaner,
      activeVehicle: activeVehicle,
      onChangeAvatar: () {},
    );

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('settings-delete-active-vehicle-private-data')),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Borrar archivos y expedientes del vehículo favorito'),
      findsWidgets,
    );
    expect(find.textContaining('No se borrará el vehículo'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(cleaner.deletedVehicleIds, isEmpty);

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('settings-delete-active-vehicle-private-data')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    expect(cleaner.deletedVehicleIds, ['vehicle-1']);
    expect(
      find.text('Archivos y expedientes del vehículo favorito eliminados.'),
      findsOneWidget,
    );
    expect(find.textContaining('ABC123'), findsNothing);
  });

  for (final result in [
    WalletAuthenticationResult.cancelled,
    WalletAuthenticationResult.failed,
    WalletAuthenticationResult.success,
  ]) {
    testWidgets('protected Settings deletion requires auth: $result', (
      tester,
    ) async {
      final authenticator = _SettingsAuthenticator()..result = result;
      final session = _settingsSession(
        authenticator: authenticator,
        protectionEnabled: true,
      );
      final wallet = _SettingsWalletStore(documentStore);
      final defense = _MemoryDefenseCaseStore();
      documentStore.putDocument(
        vehicleId: 'vehicle-1',
        documentType: PrivateVehicleDocumentType.soat,
        originalName: 'private.pdf',
      );
      await defense.createCase(
        DefenseCaseDraft(
          vehicleId: 'vehicle-1',
          authority: 'Authority',
          incidentDate: DateTime.utc(2026, 9, 3),
          facts: 'Private notes',
        ),
      );
      preferences.values['comparendos.last_checked.vehicle-1'] = '2026-09-03';
      final cleaner = VehicleAssociatedDataCleaner(
        walletStore: wallet,
        defenseCaseStore: defense,
        peritajesDraftStore: PeritajesDraftStore(preferences),
        preferences: preferences,
      );
      await _pumpSettings(
        tester,
        preferences: preferences,
        scheduler: scheduler,
        launcher: launcher,
        documentStore: documentStore,
        walletSession: session,
        vehicleAssociatedDataCleaner: cleaner,
        activeVehicle: _vehicle(id: 'vehicle-1', plate: 'ABC123'),
        onChangeAvatar: () {},
      );
      await _tapVisible(
        tester,
        find.byKey(
          const ValueKey('settings-delete-active-vehicle-private-data'),
        ),
      );
      await tester.pumpAndSettle();
      expect(authenticator.calls, 0);
      expect(wallet.initializations, 0);
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      final allowed = result == WalletAuthenticationResult.success;
      expect(authenticator.calls, 1);
      expect(wallet.initializations, allowed ? 1 : 0);
      expect(wallet.authorizedDeletion, allowed);
      expect(
        await documentStore.listForVehicle('vehicle-1'),
        hasLength(allowed ? 0 : 1),
      );
      expect(
        await defense.listForVehicle('vehicle-1'),
        hasLength(allowed ? 0 : 1),
      );
      expect(
        preferences.values['comparendos.last_checked.vehicle-1'],
        allowed ? isNull : '2026-09-03',
      );
      expect(session.accessAllowed, isFalse);
      expect(find.textContaining('private.pdf'), findsNothing);
      expect(
        find.textContaining('eliminados.'),
        allowed ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Settings does not delete after auth completes in a locked epoch',
    (tester) async {
      final pending = Completer<WalletAuthenticationResult>();
      final authenticator = _SettingsAuthenticator()..pending = pending;
      final session = _settingsSession(
        authenticator: authenticator,
        protectionEnabled: true,
      );
      final cleaner = _FakeVehicleDataCleaner();
      await _pumpSettings(
        tester,
        preferences: preferences,
        scheduler: scheduler,
        launcher: launcher,
        documentStore: documentStore,
        walletSession: session,
        vehicleAssociatedDataCleaner: cleaner,
        activeVehicle: _vehicle(id: 'vehicle-1', plate: 'ABC123'),
        onChangeAvatar: () {},
      );
      await _tapVisible(
        tester,
        find.byKey(
          const ValueKey('settings-delete-active-vehicle-private-data'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      for (var frame = 0; frame < 30 && authenticator.calls == 0; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(authenticator.calls, 1);
      session.lock();
      pending.complete(WalletAuthenticationResult.success);
      await tester.pumpAndSettle();
      expect(cleaner.deletedVehicleIds, isEmpty);
      expect(session.accessAllowed, isFalse);
      expect(find.textContaining('eliminados.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('active vehicle private data cleanup handles missing vehicle', (
    tester,
  ) async {
    final cleaner = _FakeVehicleDataCleaner();

    await _pumpSettings(
      tester,
      preferences: preferences,
      scheduler: scheduler,
      launcher: launcher,
      documentStore: documentStore,
      vehicleAssociatedDataCleaner: cleaner,
      activeVehicleFuture: Future<VehicleProfile?>.value(),
      onChangeAvatar: () {},
    );

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('settings-delete-active-vehicle-private-data')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    expect(cleaner.deletedVehicleIds, isEmpty);
    expect(find.text('No hay vehículo favorito para limpiar.'), findsOneWidget);
  });

  testWidgets('active vehicle private data cleanup failure is visible', (
    tester,
  ) async {
    final cleaner = _FakeVehicleDataCleaner()..fail = true;

    await _pumpSettings(
      tester,
      preferences: preferences,
      scheduler: scheduler,
      launcher: launcher,
      documentStore: documentStore,
      vehicleAssociatedDataCleaner: cleaner,
      activeVehicle: _vehicle(id: 'vehicle-1', plate: 'ABC123'),
      onChangeAvatar: () {},
    );

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('settings-delete-active-vehicle-private-data')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    expect(cleaner.deletedVehicleIds, ['vehicle-1']);
    expect(find.text('No pudimos completar la acción.'), findsOneWidget);
  });

  testWidgets(
    'active vehicle private data cleanup refreshes cached providers',
    (tester) async {
      final activeVehicle = _vehicle(id: 'vehicle-1', plate: 'ABC123');
      final documentStore = _FakeDocumentStore()
        ..putDocument(
          vehicleId: activeVehicle.id,
          documentType: PrivateVehicleDocumentType.soat,
          originalName: 'soat.pdf',
        );
      final defenseStore = _MemoryDefenseCaseStore();
      await defenseStore.createCase(
        DefenseCaseDraft(
          vehicleId: activeVehicle.id,
          reference: 'CMP-001',
          authority: 'Secretaria de Movilidad',
          incidentDate: DateTime.utc(2026, 9, 3),
          facts: 'Hechos del expediente.',
        ),
      );
      final cleaner = _DeletingVehicleDataCleaner(
        documentStore: documentStore,
        defenseCaseStore: defenseStore,
        preferences: preferences,
      );
      preferences.values['comparendos.last_checked.${activeVehicle.id}'] =
          '2026-09-03';
      var walletReads = 0;
      final walletList = walletDocumentsProvider(
        WalletOwner.vehicle(activeVehicle.id),
      );
      final container = ProviderContainer(
        overrides: [
          walletSessionProvider.overrideWithValue(_settingsSession()),
          walletList.overrideWith((ref) async {
            walletReads++;
            return [
              for (final old in await documentStore.listForVehicle(
                activeVehicle.id,
              ))
                WalletDocument(
                  id: old.documentId,
                  owner: WalletOwner.vehicle(activeVehicle.id),
                  type: WalletDocumentType.soat,
                  importedAt: old.importedAt,
                ),
            ];
          }),
          appPreferencesProvider.overrideWithValue(preferences),
          picoNotificationSchedulerProvider.overrideWithValue(scheduler),
          externalLauncherProvider.overrideWithValue(launcher),
          privateVehicleDocumentStoreProvider.overrideWithValue(documentStore),
          defenseCaseStoreProvider.overrideWithValue(defenseStore),
          vehicleAssociatedDataCleanerProvider.overrideWithValue(cleaner),
          activeVehicleProvider.overrideWithValue(
            AsyncValue.data(activeVehicle),
          ),
          cameraDatasetDiagnosticProvider.overrideWithValue(
            const AsyncValue.data(
              CameraDatasetDiagnostic(version: 'test-cameras', count: 2),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(walletList, (_, _) {});
      addTearDown(subscription.close);
      expect(await container.read(walletList.future), hasLength(1));
      expect(walletReads, 1);

      expect(
        await container.read(vehicleDocumentsProvider(activeVehicle.id).future),
        hasLength(1),
      );
      expect(
        await container.read(
          privateVehicleDocumentProvider((
            activeVehicle.id,
            PrivateVehicleDocumentType.soat,
          )).future,
        ),
        isNotNull,
      );
      expect(
        await container.read(defenseCasesProvider(activeVehicle.id).future),
        hasLength(1),
      );
      expect(
        await container.read(
          comparendosLastCheckedProvider(activeVehicle.id).future,
        ),
        '2026-09-03',
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: SettingsScreen(onChangeAvatar: () {})),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await _tapVisible(
        tester,
        find.byKey(
          const ValueKey('settings-delete-active-vehicle-private-data'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(cleaner.deletedVehicleIds, [activeVehicle.id]);
      expect(await container.read(walletList.future), isEmpty);
      expect(walletReads, 2);
      expect(
        await container.read(vehicleDocumentsProvider(activeVehicle.id).future),
        isEmpty,
      );
      expect(
        await container.read(
          privateVehicleDocumentProvider((
            activeVehicle.id,
            PrivateVehicleDocumentType.soat,
          )).future,
        ),
        isNull,
      );
      expect(
        await container.read(defenseCasesProvider(activeVehicle.id).future),
        isEmpty,
      );
      expect(
        await container.read(
          comparendosLastCheckedProvider(activeVehicle.id).future,
        ),
        isNull,
      );
    },
  );

  testWidgets(
    'active vehicle private data cleanup refreshes cached providers after dispose',
    (tester) async {
      final activeVehicle = _vehicle(id: 'vehicle-1', plate: 'ABC123');
      final documentStore = _FakeDocumentStore()
        ..putDocument(
          vehicleId: activeVehicle.id,
          documentType: PrivateVehicleDocumentType.soat,
          originalName: 'soat.pdf',
        );
      final defenseStore = _MemoryDefenseCaseStore();
      await defenseStore.createCase(
        DefenseCaseDraft(
          vehicleId: activeVehicle.id,
          reference: 'CMP-001',
          authority: 'Secretaria de Movilidad',
          incidentDate: DateTime.utc(2026, 9, 3),
          facts: 'Hechos del expediente.',
        ),
      );
      final cleanupMayFinish = Completer<void>();
      final cleaner = _DelayedDeletingVehicleDataCleaner(
        documentStore: documentStore,
        defenseCaseStore: defenseStore,
        preferences: preferences,
        delay: cleanupMayFinish.future,
      );
      final container = ProviderContainer(
        overrides: [
          walletSessionProvider.overrideWithValue(_settingsSession()),
          appPreferencesProvider.overrideWithValue(preferences),
          picoNotificationSchedulerProvider.overrideWithValue(scheduler),
          externalLauncherProvider.overrideWithValue(launcher),
          privateVehicleDocumentStoreProvider.overrideWithValue(documentStore),
          defenseCaseStoreProvider.overrideWithValue(defenseStore),
          vehicleAssociatedDataCleanerProvider.overrideWithValue(cleaner),
          activeVehicleProvider.overrideWithValue(
            AsyncValue.data(activeVehicle),
          ),
          cameraDatasetDiagnosticProvider.overrideWithValue(
            const AsyncValue.data(
              CameraDatasetDiagnostic(version: 'test-cameras', count: 2),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(vehicleDocumentsProvider(activeVehicle.id).future),
        hasLength(1),
      );
      expect(
        await container.read(
          privateVehicleDocumentProvider((
            activeVehicle.id,
            PrivateVehicleDocumentType.soat,
          )).future,
        ),
        isNotNull,
      );
      expect(
        await container.read(defenseCasesProvider(activeVehicle.id).future),
        hasLength(1),
      );

      await _pumpSettingsWithContainer(tester, container);
      await _tapVisible(
        tester,
        find.byKey(
          const ValueKey('settings-delete-active-vehicle-private-data'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pump();

      await _unmountContainer(tester, container);
      cleanupMayFinish.complete();
      await tester.pump();
      await tester.idle();
      await tester.pump();

      expect(cleaner.deletedVehicleIds, [activeVehicle.id]);
      expect(tester.takeException(), isNull);
      expect(
        await container.read(vehicleDocumentsProvider(activeVehicle.id).future),
        isEmpty,
      );
      expect(
        await container.read(
          privateVehicleDocumentProvider((
            activeVehicle.id,
            PrivateVehicleDocumentType.soat,
          )).future,
        ),
        isNull,
      );
      expect(
        await container.read(defenseCasesProvider(activeVehicle.id).future),
        isEmpty,
      );
    },
  );

  testWidgets('does not use context after active vehicle wait is disposed', (
    tester,
  ) async {
    final activeVehicle = _vehicle(id: 'vehicle-1', plate: 'ABC123');
    final completer = Completer<VehicleProfile?>();
    preferences.values['comparendos.last_checked.vehicle-1'] = '2026-09-03';

    await _pumpSettings(
      tester,
      preferences: preferences,
      scheduler: scheduler,
      launcher: launcher,
      documentStore: documentStore,
      activeVehicleFuture: completer.future,
      onChangeAvatar: () {},
    );

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('settings-delete-comparendos-note')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    completer.complete(activeVehicle);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      preferences.values.containsKey('comparendos.last_checked.vehicle-1'),
      isFalse,
    );
  });

  test('uses exact official source metadata', () {
    expect(ansvFotodeteccionUrl, endsWith('/ubicaciones-aprobadas.html'));
    expect(simitSourceUrl, 'https://www.simit.org.co/');
    expect(
      sicPersonalDataGuideUrl,
      'https://sedeelectronica.sic.gov.co/noticias/sic-expide-guia-para-el-correcto-tratamiento-de-las-fotografias-como-datos-personales',
    );

    final sicSource = settingsSourceLinks.singleWhere(
      (source) => source.label == 'Guía SIC de datos personales',
    );
    expect(sicSource.url, sicPersonalDataGuideUrl);
    expect(sicSource.description, contains('fotografías'));
    expect(
      settingsSourceLinks.where((source) => source.label.contains('SIC')),
      hasLength(1),
    );

    final inviasSource = settingsSourceLinks.singleWhere(
      (source) => source.label == 'INVÍAS',
    );
    expect(inviasSource.url, inviasRoadStatusUrl);
  });

  testWidgets('opens official source URLs', (tester) async {
    await _pumpSettings(
      tester,
      preferences: preferences,
      scheduler: scheduler,
      launcher: launcher,
      documentStore: documentStore,
      onChangeAvatar: () {},
    );

    for (final source in settingsSourceLinks) {
      await tester.ensureVisible(find.text(source.label));
      await tester.tap(find.text(source.label));
      await tester.pump();
    }

    expect(launcher.opened, [
      ansvFotodeteccionUrl,
      simitSourceUrl,
      inviasRoadStatusUrl,
      sicPersonalDataGuideUrl,
    ]);
  });

  testWidgets('shows visible message when source launcher returns false', (
    tester,
  ) async {
    launcher.openResult = false;

    await _pumpSettings(
      tester,
      preferences: preferences,
      scheduler: scheduler,
      launcher: launcher,
      documentStore: documentStore,
      onChangeAvatar: () {},
    );

    await tester.ensureVisible(find.text('SIMIT'));
    await tester.tap(find.text('SIMIT'));
    await tester.pumpAndSettle();

    expect(find.text('No pudimos abrir SIMIT.'), findsOneWidget);
  });

  testWidgets('shows visible message when source launcher throws', (
    tester,
  ) async {
    launcher.openException = Exception('launcher failed');

    await _pumpSettings(
      tester,
      preferences: preferences,
      scheduler: scheduler,
      launcher: launcher,
      documentStore: documentStore,
      onChangeAvatar: () {},
    );

    await tester.ensureVisible(find.text('SIMIT'));
    await tester.tap(find.text('SIMIT'));
    await tester.pumpAndSettle();

    expect(find.text('No pudimos abrir SIMIT.'), findsOneWidget);
  });

  testWidgets('copies non-sensitive diagnostic only', (tester) async {
    var clipboardText = '';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await _pumpSettings(
      tester,
      preferences: preferences,
      scheduler: scheduler,
      launcher: launcher,
      documentStore: documentStore,
      activeVehicle: _vehicle(id: 'vehicle-secret', plate: 'ABC123'),
      cameraDatasetDiagnostic: const CameraDatasetDiagnostic(
        version: '2026.08.31-ansv',
        count: 360,
      ),
      onChangeAvatar: () {},
    );

    await tester.ensureVisible(find.text('Copiar diagnóstico'));
    await tester.tap(find.byKey(const ValueKey('settings-copy-diagnostic')));
    await tester.pumpAndSettle();

    expect(clipboardText, contains('schemaVersion=9'));
    expect(clipboardText, contains('cameraDatasetVersion=2026.08.31-ansv'));
    expect(clipboardText, contains('cameraDatasetCount=360'));
    expect(clipboardText, isNot(contains('ABC123')));
    expect(clipboardText, isNot(contains('vehicle-secret')));
    expect(clipboardText, isNot(contains('vehicleId')));
    expect(clipboardText, isNot(contains('coordinates')));
    expect(clipboardText, isNot(contains('device')));
  });

  testWidgets('shows visible message when diagnostic copy throws', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            throw PlatformException(code: 'copy_failed');
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await _pumpSettings(
      tester,
      preferences: preferences,
      scheduler: scheduler,
      launcher: launcher,
      documentStore: documentStore,
      cameraDatasetDiagnostic: const CameraDatasetDiagnostic(
        version: '2026.08.31-ansv',
        count: 360,
      ),
      onChangeAvatar: () {},
    );

    await tester.ensureVisible(find.text('Copiar diagnóstico'));
    await tester.tap(find.byKey(const ValueKey('settings-copy-diagnostic')));
    await tester.pumpAndSettle();

    expect(find.text('No pudimos copiar el diagnóstico.'), findsOneWidget);
  });

  testWidgets('phone viewports do not overflow', (tester) async {
    const cases = [
      (Size(360, 800), 1.0),
      (Size(390, 844), 1.5),
      (Size(412, 915), 2.0),
    ];

    for (final testCase in cases) {
      await _pumpSettings(
        tester,
        preferences: preferences,
        scheduler: scheduler,
        launcher: launcher,
        documentStore: documentStore,
        onChangeAvatar: () {},
        size: testCase.$1,
        textScale: testCase.$2,
      );

      expect(
        find.byKey(const ValueKey('settings-screen-scroll')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  for (final size in const [Size(360, 800), Size(390, 844), Size(412, 915)]) {
    for (final scale in const [1.0, 1.5, 2.0]) {
      testWidgets('V01B Settings title readable ${size.width} scale $scale', (
        tester,
      ) async {
        await _pumpSettings(
          tester,
          preferences: preferences,
          scheduler: scheduler,
          launcher: launcher,
          documentStore: documentStore,
          onChangeAvatar: () {},
          size: size,
          textScale: scale,
          theme: buildPicoRadarTheme(),
        );
        final title = find.text('Notificaciones');
        await tester.ensureVisible(title);
        final paragraph = tester.renderObject<RenderParagraph>(title);
        final text = paragraph.text.toPlainText();
        final lines = <double, String>{};
        for (var offset = 0; offset < text.length; offset++) {
          final boxes = paragraph.getBoxesForSelection(
            TextSelection(baseOffset: offset, extentOffset: offset + 1),
          );
          for (final box in boxes) {
            lines.update(
              box.top,
              (line) => '$line${text[offset]}',
              ifAbsent: () => text[offset],
            );
          }
        }
        expect(
          lines.values.every((line) => line.length > 1),
          isTrue,
          reason: 'Notification title leaves an isolated letter: $lines',
        );
        expect(paragraph.didExceedMaxLines, isFalse);
        final configure = find.byKey(
          const ValueKey('settings-go-home-notifications'),
        );
        await tester.ensureVisible(configure);
        expect(configure.hitTestable(), findsOneWidget);
        for (final key in [
          'settings-purge-document-viewer',
          'settings-delete-trip-draft',
          'settings-delete-comparendos-note',
          'settings-delete-active-vehicle-private-data',
        ]) {
          final action = find.byKey(ValueKey(key));
          await tester.ensureVisible(action);
          await tester.pump();
          expect(action.hitTestable(), findsOneWidget);
          expect(tester.getSize(action).height, greaterThanOrEqualTo(44));
          for (final element
              in find
                  .descendant(of: action, matching: find.byType(RichText))
                  .evaluate()) {
            final rendered = element.renderObject! as RenderParagraph;
            expect(rendered.didExceedMaxLines, isFalse);
          }
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('V01B Settings deletion differs from cache maintenance', (
    tester,
  ) async {
    await _pumpSettings(
      tester,
      preferences: preferences,
      scheduler: scheduler,
      launcher: launcher,
      documentStore: documentStore,
      onChangeAvatar: () {},
      theme: buildPicoRadarTheme(),
    );
    final cache = find.byKey(const ValueKey('settings-purge-document-viewer'));
    final deletion = find.byKey(const ValueKey('settings-delete-trip-draft'));
    final cacheButton = tester.widget<OutlinedButton>(cache);
    final deleteButton = tester.widget<OutlinedButton>(deletion);
    expect(
      deleteButton.style?.foregroundColor?.resolve({}),
      isNot(cacheButton.style?.foregroundColor?.resolve({})),
      reason: 'Destructive actions have the same appearance as cache upkeep',
    );
    await _tapVisible(tester, deletion);
    await tester.pumpAndSettle();
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Eliminar'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  required MemoryPreferences preferences,
  required _FakePicoNotificationScheduler scheduler,
  required _FakeExternalLauncher launcher,
  required _FakeDocumentStore documentStore,
  required VoidCallback onChangeAvatar,
  VoidCallback? onConfigureNotifications,
  VehicleAssociatedDataCleaner? vehicleAssociatedDataCleaner,
  WalletSession? walletSession,
  VehicleProfile? activeVehicle,
  Future<VehicleProfile?>? activeVehicleFuture,
  CameraDatasetDiagnostic cameraDatasetDiagnostic =
      const CameraDatasetDiagnostic(version: 'test-cameras', count: 2),
  Size size = const Size(390, 844),
  double textScale = 1.0,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        walletSessionProvider.overrideWithValue(
          walletSession ?? _settingsSession(),
        ),
        appPreferencesProvider.overrideWithValue(preferences),
        picoNotificationSchedulerProvider.overrideWithValue(scheduler),
        externalLauncherProvider.overrideWithValue(launcher),
        privateVehicleDocumentStoreProvider.overrideWithValue(documentStore),
        walletStoreProvider.overrideWithValue(
          _SettingsWalletStore(documentStore),
        ),
        vehicleAssociatedDataCleanerProvider.overrideWithValue(
          vehicleAssociatedDataCleaner ?? _FakeVehicleDataCleaner(),
        ),
        if (activeVehicleFuture != null)
          activeVehicleProvider.overrideWith((ref) => activeVehicleFuture),
        if (activeVehicle != null)
          activeVehicleProvider.overrideWithValue(
            AsyncValue.data(activeVehicle),
          ),
        cameraDatasetDiagnosticProvider.overrideWithValue(
          AsyncValue.data(cameraDatasetDiagnostic),
        ),
      ],
      child: MaterialApp(
        theme: theme,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: SettingsScreen(
            onChangeAvatar: onChangeAvatar,
            onConfigureNotifications: onConfigureNotifications,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

Future<void> _pumpSettingsWithContainer(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: SettingsScreen(onChangeAvatar: () {})),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _unmountContainer(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const SizedBox.shrink(),
    ),
  );
  await tester.pump();
  await tester.pump();
}

VehicleProfile _vehicle({required String id, required String plate}) {
  return VehicleProfile(
    id: id,
    plate: plate,
    kind: VehicleKind.car,
    serviceType: VehicleServiceType.private,
    createdAt: DateTime.utc(2026, 9, 3),
    updatedAt: DateTime.utc(2026, 9, 3),
  );
}

class _FakeVehicleDataCleaner extends VehicleAssociatedDataCleaner {
  _FakeVehicleDataCleaner()
    : super(
        documentStore: PrivateVehicleDocumentStore(),
        defenseCaseStore: DefenseCaseStore(),
        peritajesDraftStore: PeritajesDraftStore(MemoryPreferences()),
        preferences: MemoryPreferences(),
      );

  final deletedVehicleIds = <String>[];
  var fail = false;

  @override
  Future<void> deletePrivateDataForVehicle(
    String vehicleId, {
    required bool Function() isAuthorized,
  }) async {
    if (!isAuthorized()) throw StateError('Not authorized');
    await deleteForVehicle(vehicleId);
  }

  @override
  Future<void> deleteForVehicle(String vehicleId) async {
    deletedVehicleIds.add(vehicleId);
    if (fail) {
      throw StateError('cleanup failed');
    }
  }
}

class _FakePicoNotificationScheduler extends PicoNotificationScheduler {
  bool? areEnabledResult = true;
  var areEnabledCalls = 0;
  var requestPermissionCalls = 0;

  @override
  Future<bool?> areNotificationsEnabled() async {
    areEnabledCalls += 1;
    return areEnabledResult;
  }

  @override
  Future<bool> requestPermission() async {
    requestPermissionCalls += 1;
    return true;
  }
}

class _FakeExternalLauncher implements ExternalLauncher {
  final opened = <String>[];
  bool openResult = true;
  Object? openException;

  @override
  Future<bool> callPhone(String phone) async => true;

  @override
  Future<bool> openExternal(String uri) async {
    final exception = openException;
    if (exception != null) {
      throw exception;
    }
    opened.add(uri);
    return openResult;
  }
}

class _FakeDocumentStore extends PrivateVehicleDocumentStore {
  var purgeViewerCacheCalls = 0;
  var documentIds = 0;
  final _documents =
      <(String, PrivateVehicleDocumentType), PrivateVehicleDocumentMetadata>{};

  PrivateVehicleDocumentMetadata putDocument({
    required String vehicleId,
    required PrivateVehicleDocumentType documentType,
    required String originalName,
  }) {
    documentIds += 1;
    final metadata = PrivateVehicleDocumentMetadata(
      documentId: 'settings-doc-$documentIds',
      vehicleId: vehicleId,
      documentType: documentType,
      originalName: originalName,
      mimeType: 'application/pdf',
      importedAt: DateTime.utc(2026, 9, 3),
      encryptedRelativePath: 'docs/${documentType.value}/$vehicleId/doc.prcf',
    );
    _documents[(vehicleId, documentType)] = metadata;
    return metadata;
  }

  @override
  Future<PrivateVehicleDocumentMetadata?> get({
    required String vehicleId,
    required PrivateVehicleDocumentType documentType,
  }) async {
    return _documents[(vehicleId, documentType)];
  }

  @override
  Future<List<PrivateVehicleDocumentMetadata>> listForVehicle(
    String vehicleId,
  ) async {
    return [
      for (final entry in _documents.entries)
        if (entry.key.$1 == vehicleId) entry.value,
    ];
  }

  @override
  Future<void> deleteForVehicle(String vehicleId) async {
    _documents.removeWhere((key, value) => key.$1 == vehicleId.trim());
  }

  @override
  Future<void> purgeViewerCache({
    PrivateVehicleDocumentMetadata? metadata,
  }) async {
    purgeViewerCacheCalls += 1;
  }
}

class _SettingsWalletStore implements WalletStore {
  _SettingsWalletStore(this.legacy);
  final _FakeDocumentStore legacy;
  int purgeCalls = 0;
  int initializations = 0;
  bool authorizedDeletion = false;

  @override
  Future<WalletMigrationReport> initialize() async {
    initializations++;
    return const WalletMigrationReport();
  }

  @override
  Future<void> deleteForVehicle(
    String id, {
    bool Function()? isAuthorized,
  }) async {
    if (isAuthorized?.call() != true) throw StateError('Not authorized');
    authorizedDeletion = true;
    await legacy.deleteForVehicle(id);
  }

  @override
  Future<void> purgeViewerCache() async {
    purgeCalls++;
    await legacy.purgeViewerCache();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DeletingVehicleDataCleaner extends VehicleAssociatedDataCleaner {
  _DeletingVehicleDataCleaner({
    required _FakeDocumentStore documentStore,
    required _MemoryDefenseCaseStore defenseCaseStore,
    required MemoryPreferences preferences,
  }) : super(
         documentStore: documentStore,
         defenseCaseStore: defenseCaseStore,
         peritajesDraftStore: PeritajesDraftStore(preferences),
         preferences: preferences,
       );

  final deletedVehicleIds = <String>[];

  @override
  Future<void> deletePrivateDataForVehicle(
    String vehicleId, {
    required bool Function() isAuthorized,
  }) async {
    deletedVehicleIds.add(vehicleId);
    await super.deletePrivateDataForVehicle(
      vehicleId,
      isAuthorized: isAuthorized,
    );
  }

  @override
  Future<void> deleteForVehicle(String vehicleId) async {
    deletedVehicleIds.add(vehicleId);
    await super.deleteForVehicle(vehicleId);
  }
}

class _DelayedDeletingVehicleDataCleaner extends _DeletingVehicleDataCleaner {
  _DelayedDeletingVehicleDataCleaner({
    required super.documentStore,
    required super.defenseCaseStore,
    required super.preferences,
    required this.delay,
  });

  final Future<void> delay;

  @override
  Future<void> deletePrivateDataForVehicle(
    String vehicleId, {
    required bool Function() isAuthorized,
  }) async {
    await delay;
    await super.deletePrivateDataForVehicle(
      vehicleId,
      isAuthorized: isAuthorized,
    );
  }

  @override
  Future<void> deleteForVehicle(String vehicleId) async {
    await delay;
    await super.deleteForVehicle(vehicleId);
  }
}

class _MemoryDefenseCaseStore extends DefenseCaseStore {
  final _items = <DefenseCase>[];
  var ids = 0;

  @override
  Future<List<DefenseCase>> listForVehicle(String vehicleId) async {
    return [
      for (final item in _items)
        if (item.vehicleId == vehicleId) item,
    ];
  }

  @override
  Future<DefenseCase> createCase(DefenseCaseDraft draft) async {
    ids += 1;
    final item = DefenseCase(
      id: 'settings-case-$ids',
      vehicleId: draft.vehicleId.trim(),
      reference: draft.reference?.trim(),
      authority: draft.authority.trim(),
      incidentDate: draft.incidentDate,
      notificationDate: draft.notificationDate,
      facts: draft.facts.trim(),
      createdAt: DateTime.utc(2026, 9, 3),
      updatedAt: DateTime.utc(2026, 9, 3),
    );
    _items.add(item);
    return item;
  }

  @override
  Future<void> deleteForVehicle(String vehicleId) async {
    _items.removeWhere((item) => item.vehicleId == vehicleId.trim());
  }
}

WalletSession _settingsSession({
  _SettingsAuthenticator? authenticator,
  bool protectionEnabled = false,
}) {
  final session = WalletSession(
    authenticator: authenticator ?? _SettingsAuthenticator(),
    preferences: _SettingsSecurityPreferences(protectionEnabled),
  );
  addTearDown(session.dispose);
  return session;
}

class _SettingsSecurityPreferences implements WalletSecurityPreferencesStore {
  _SettingsSecurityPreferences(this.enabled);
  final bool enabled;

  @override
  Future<WalletSecurityPreferences> read() async =>
      WalletSecurityPreferences(protectionEnabled: enabled, offerSeen: true);

  @override
  Future<void> write(WalletSecurityPreferences preferences) async {}
}

class _SettingsAuthenticator implements WalletDeviceAuthenticator {
  int calls = 0;
  WalletAuthenticationResult result = WalletAuthenticationResult.success;
  Completer<WalletAuthenticationResult>? pending;

  @override
  Future<bool> canAuthenticate() async => true;

  @override
  Future<WalletAuthenticationResult> authenticate() async {
    calls++;
    return pending == null ? result : await pending!.future;
  }
}
