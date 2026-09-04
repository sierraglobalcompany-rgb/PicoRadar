import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/core/storage/app_preferences.dart';
import 'package:picoradar/features/apps_launcher/presentation/module_placeholder_screen.dart';
import 'package:picoradar/features/documents/presentation/documents_screen.dart';
import 'package:picoradar/features/defense/data/defense_case_store.dart';
import 'package:picoradar/features/garage/application/vehicle_associated_data_cleaner.dart';
import 'package:picoradar/features/garage/data/garage_favorites.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/garage/data/vehicle_repository.dart';
import 'package:picoradar/features/maintenance/presentation/maintenance_screen.dart';
import 'package:picoradar/features/peritajes/data/peritajes_draft_store.dart';
import 'package:picoradar/features/pico_placa/data/pico_preferences.dart';
import 'package:picoradar/features/pico_placa/presentation/pico_detail_screen.dart';
import 'package:picoradar/features/visual_assets/presentation/visual_asset_widgets.dart';
import 'package:picoradar/features/vehicle_status/data/private_vehicle_document_store.dart';
import 'package:picoradar/features/vehicle_status/data/vehicle_obligation_store.dart';
import 'package:picoradar/features/vehicle_status/domain/vehicle_obligation.dart';

import '../../../test_app_harness.dart';

void main() {
  late TestAppHarness harness;

  setUp(() {
    harness = TestAppHarness();
  });

  tearDown(() async {
    await harness.dispose();
  });

  testWidgets('garage v2 shows owner structure and real vehicle data', (
    tester,
  ) async {
    await _seedThreeVehicles(harness);

    await _openGarage(tester, harness);

    expect(
      find.byKey(const ValueKey('garage-compact-top-bar')),
      findsOneWidget,
    );
    expect(find.text('PicoRadar'), findsOneWidget);
    expect(find.byKey(const ValueKey('garage-filter-segment')), findsOneWidget);
    expect(find.text('Todos'), findsOneWidget);
    expect(find.text('Favoritos'), findsOneWidget);
    expect(find.text('Activos'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('garage-vehicle-carousel')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('garage-info-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('garage-add-vehicle')), findsOneWidget);
    expect(find.byKey(const ValueKey('garage-quick-actions')), findsOneWidget);
    expect(
      find.text('Tus vehículos y su estado en un solo lugar.'),
      findsNothing,
    );

    expect(find.text('Mazda CX-5'), findsWidgets);
    expect(find.text('ABC123'), findsWidgets);
    expect(find.text('Carro particular'), findsOneWidget);
    expect(find.text('Bogotá D. C.'), findsOneWidget);
    expect(find.text('Particular'), findsOneWidget);
    expect(find.text('2022'), findsWidgets);
    expect(find.text('24.560 km'), findsNothing);
    expect(find.text('Sin comparendos'), findsNothing);
    expect(find.text('0 comparendos'), findsNothing);
  });

  testWidgets(
    'one vehicle keeps count simple and uses vehicle visual resolver',
    (tester) async {
      final vehicle = await _createVehicle(
        harness,
        plate: 'AAA111',
        brand: 'Mazda',
        model: 'CX-5',
        year: 2022,
      );
      await harness.repository.setActiveVehicle(vehicle.id);

      await _openGarage(tester, harness);

      expect(find.text('1 de 1'), findsOneWidget);
      expect(find.byKey(ValueKey('garage-carousel-dot-0')), findsNothing);
      expect(find.byType(VehicleVisualImage), findsOneWidget);
    },
  );

  testWidgets('initial focus is active and swipe does not mutate active', (
    tester,
  ) async {
    final seeded = await _seedThreeVehicles(harness);

    await _openGarage(tester, harness);

    expect(find.text('2 de 3'), findsOneWidget);
    expect(find.text(seeded.active.plate), findsWidgets);
    expect((await harness.repository.getActiveVehicle())?.id, seeded.active.id);

    await tester.drag(
      find.byKey(const ValueKey('garage-vehicle-carousel')),
      const Offset(-320, 0),
    );
    await tester.pumpAndSettle();

    expect((await harness.repository.getActiveVehicle())?.id, seeded.active.id);
    expect(find.text('No activo'), findsOneWidget);
  });

  testWidgets(
    'P02 focused info panel and detail target follow B and C atomically',
    (tester) async {
      final seeded = await _seedThreeVehicles(harness);

      await _openGarage(tester, harness);

      _expectGarageInfoPanel(tester, seeded.active);
      await _openDetailAndReturn(tester, seeded.active);

      await _focusNewestVehicle(tester);
      _expectGarageInfoPanel(tester, seeded.newest);
      await _openDetailAndReturn(tester, seeded.newest);

      await _focusOldestVehicle(tester);
      _expectGarageInfoPanel(tester, seeded.oldest);
      await _openDetailAndReturn(tester, seeded.oldest);

      expect(
        (await harness.repository.getActiveVehicle())?.id,
        seeded.active.id,
      );
    },
  );

  testWidgets('explicit make active changes the active vehicle', (
    tester,
  ) async {
    final seeded = await _seedThreeVehicles(harness);

    await _openGarage(tester, harness);
    await tester.drag(
      find.byKey(const ValueKey('garage-vehicle-carousel')),
      const Offset(-320, 0),
    );
    await tester.pumpAndSettle();
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('garage-action-make-active')),
    );

    final active = await harness.repository.getActiveVehicle();
    expect(active?.id, isNot(seeded.active.id));
    expect(find.text('Activo'), findsOneWidget);
  });

  testWidgets('P02-FIX1 non-active state keeps actions visible and scoped', (
    tester,
  ) async {
    final seeded = await _seedThreeVehicles(harness);

    await _openGarage(tester, harness);
    await _focusNewestVehicle(tester);

    _expectGarageInfoPanel(tester, seeded.newest);
    expect(find.text('No activo'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('garage-action-make-active')),
      findsOneWidget,
    );
    expect((await harness.repository.getActiveVehicle())?.id, seeded.active.id);
    _expectGarageCoreAboveNav(tester, reason: 'non-active focused');

    await tester.tap(find.byKey(const ValueKey('garage-action-detail')));
    await tester.pumpAndSettle();

    expect(find.text('Detalle del vehículo'), findsOneWidget);
    expect(find.text(seeded.newest.plate), findsOneWidget);

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    await _focusNewestVehicle(tester);
    await tester.tap(find.byKey(const ValueKey('garage-action-make-active')));
    await tester.pumpAndSettle();

    expect((await harness.repository.getActiveVehicle())?.id, seeded.newest.id);
    expect(find.text('Activo'), findsOneWidget);
    _expectGarageCoreAboveNav(tester, reason: 'after make active');
  });

  testWidgets('favorites filter toggles and persists in AppPreferences', (
    tester,
  ) async {
    final seeded = await _seedThreeVehicles(harness);

    await _openGarage(tester, harness);
    await tester.tap(
      find.byKey(ValueKey('garage-favorite-${seeded.active.id}')),
    );
    await tester.pumpAndSettle();

    expect(
      await loadGarageFavoriteVehicleIds(harness.preferences),
      contains(seeded.active.id),
    );

    await tester.tap(find.text('Favoritos'));
    await tester.pumpAndSettle();

    expect(find.text('1 de 1'), findsOneWidget);
    expect(find.text(seeded.active.plate), findsWidgets);

    await _openGarage(tester, harness);
    await tester.tap(find.text('Favoritos'));
    await tester.pumpAndSettle();

    expect(find.text('1 de 1'), findsOneWidget);
    expect(find.text(seeded.active.plate), findsWidgets);
  });

  testWidgets(
    'favorites and active filters show controlled empty/current states',
    (tester) async {
      final seeded = await _seedThreeVehicles(harness);

      await _openGarage(tester, harness, size: const Size(480, 900));
      await tester.tap(find.text('Favoritos'));
      await tester.pumpAndSettle();

      expect(find.text('No tienes vehículos favoritos.'), findsOneWidget);

      await tester.tap(find.text('Ver todos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Activos'));
      await tester.pumpAndSettle();

      expect(find.text('1 de 1'), findsOneWidget);
      expect(find.text(seeded.active.plate), findsWidgets);
    },
  );

  testWidgets(
    'root actions navigate with focused vehicle and avoid dead CTAs',
    (tester) async {
      final seeded = await _seedThreeVehicles(harness);

      await _openGarage(tester, harness);
      await tester.drag(
        find.byKey(const ValueKey('garage-vehicle-carousel')),
        const Offset(-320, 0),
      );
      await tester.pumpAndSettle();
      final focused = seeded.newest;

      await _tapVisible(
        tester,
        find.byKey(const ValueKey('garage-action-documents')),
        settle: false,
      );
      final documents = tester.widget<DocumentsScreen>(
        find.byType(DocumentsScreen),
      );
      expect(documents.vehicleId, focused.id);
      expect(find.byKey(const ValueKey('documents-go-garage')), findsNothing);
      expect(find.byType(ModulePlaceholderScreen), findsNothing);
      expect(
        (await harness.repository.getActiveVehicle())?.id,
        seeded.active.id,
      );

      await tester.tap(find.byKey(const ValueKey('tab-garage')));
      await tester.pumpAndSettle();
      await _focusNewestVehicle(tester);
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('garage-action-maintenance')),
        settle: false,
      );
      final maintenance = tester.widget<MaintenanceScreen>(
        find.byType(MaintenanceScreen),
      );
      expect(maintenance.vehicleId, focused.id);
      expect(find.byKey(const ValueKey('maintenance-empty')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('maintenance-missing-vehicle')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('garage-maintenance-soon-sheet')),
        findsNothing,
      );
      expect(
        find.textContaining(RegExp('próximamente|proximamente')),
        findsNothing,
      );
      expect(find.byType(ModulePlaceholderScreen), findsNothing);
      expect(
        (await harness.repository.getActiveVehicle())?.id,
        seeded.active.id,
      );

      await tester.tap(find.byKey(const ValueKey('tab-garage')));
      await tester.pumpAndSettle();
      await _focusNewestVehicle(tester);
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('garage-action-detail')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Detalle del vehículo'), findsOneWidget);
      expect(find.text(focused.plate), findsOneWidget);
    },
  );

  testWidgets('module routes from Garage fail closed for invalid vehicleId', (
    tester,
  ) async {
    final seeded = await _seedThreeVehicles(harness);

    await _openGarage(tester, harness);
    await _goTo(tester, '/apps/module/documentos?vehicleId=missing');

    expect(find.byType(DocumentsScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('documents-go-garage')), findsOneWidget);
    expect(find.byType(ModulePlaceholderScreen), findsNothing);
    expect((await harness.repository.getActiveVehicle())?.id, seeded.active.id);

    await _goTo(tester, '/apps/module/talleres?vehicleId=missing');

    expect(find.byType(MaintenanceScreen), findsOneWidget);
    expect(
      find.byKey(const ValueKey('maintenance-missing-vehicle')),
      findsOneWidget,
    );
    expect(find.byType(ModulePlaceholderScreen), findsNothing);
    expect(
      find.textContaining(RegExp('próximamente|proximamente')),
      findsNothing,
    );
    expect((await harness.repository.getActiveVehicle())?.id, seeded.active.id);
  });

  testWidgets(
    'delete dialog cancel shows full local-data copy and performs no mutations',
    (tester) async {
      final seeded = await _seedThreeVehicles(harness);
      final cleaner = _RecordingVehicleDataCleaner();

      await _openGarage(tester, harness, vehicleAssociatedDataCleaner: cleaner);
      await _focusNewestVehicle(tester);
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('garage-action-delete')),
      );

      expect(find.text('¿Eliminar este vehículo?'), findsOneWidget);
      expect(find.text(seeded.newest.plate), findsWidgets);
      expect(
        find.text(
          'Se eliminarán el vehículo y sus datos locales asociados:\n'
          'mantenimientos, obligaciones, documentos cifrados,\n'
          'expedientes de Defensa, borrador de Peritajes y nota de Comparendos.\n'
          'Esta acción no se puede deshacer.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(cleaner.deletedVehicleIds, isEmpty);
      expect(await harness.repository.getVehicle(seeded.newest.id), isNotNull);
      expect(await harness.repository.getVehicle(seeded.active.id), isNotNull);
    },
  );

  testWidgets(
    'delete action removes focused only and active fallback stays deterministic',
    (tester) async {
      final seeded = await _seedThreeVehicles(harness);

      await _openGarage(tester, harness);
      await _focusNewestVehicle(tester);
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('garage-action-delete')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('garage-confirm-delete-vehicle')),
      );
      await tester.pumpAndSettle();

      expect(await harness.repository.getVehicle(seeded.newest.id), isNull);
      expect(
        (await harness.repository.getActiveVehicle())?.id,
        seeded.active.id,
      );

      await _tapVisible(
        tester,
        find.byKey(const ValueKey('garage-action-delete')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('garage-confirm-delete-vehicle')),
      );
      await tester.pumpAndSettle();

      expect(await harness.repository.getVehicle(seeded.active.id), isNull);
      expect(
        (await harness.repository.getActiveVehicle())?.id,
        seeded.oldest.id,
      );
    },
  );

  testWidgets(
    'delete action ignores a second confirmation while deletion is running',
    (tester) async {
      final seeded = await _seedThreeVehicles(harness);
      final cleaner = _RecordingVehicleDataCleaner()
        ..gate = Completer<void>();
      final repository = _RecordingVehicleRepository(harness);

      await _openGarage(
        tester,
        harness,
        vehicleAssociatedDataCleaner: cleaner,
        vehicleRepository: repository,
      );
      await _focusNewestVehicle(tester);
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('garage-action-delete')),
      );
      await tester.tap(
        find.byKey(const ValueKey('garage-confirm-delete-vehicle')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('garage-action-delete')));
      await tester.pump();

      expect(cleaner.deletedVehicleIds, [seeded.newest.id]);
      expect(
        find.byKey(const ValueKey('garage-confirm-delete-vehicle')),
        findsNothing,
      );

      cleaner.gate!.complete();
      await tester.pumpAndSettle();

      expect(repository.deletedVehicleIds, [seeded.newest.id]);
      expect(await harness.repository.getVehicle(seeded.newest.id), isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'delete action cleans associated private data before vehicle row',
    (tester) async {
      final seeded = await _seedThreeVehicles(harness);
      final cleaner = _RecordingVehicleDataCleaner();

      await _openGarage(tester, harness, vehicleAssociatedDataCleaner: cleaner);
      await _focusNewestVehicle(tester);
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('garage-action-delete')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('garage-confirm-delete-vehicle')),
      );
      await tester.pumpAndSettle();

      expect(cleaner.deletedVehicleIds, [seeded.newest.id]);
      expect(await harness.repository.getVehicle(seeded.newest.id), isNull);
      expect(
        (await harness.repository.getActiveVehicle())?.id,
        seeded.active.id,
      );
    },
  );

  testWidgets('delete action keeps vehicle when associated cleanup fails', (
    tester,
  ) async {
    final seeded = await _seedThreeVehicles(harness);
    final cleaner = _RecordingVehicleDataCleaner()..fail = true;

    await _openGarage(tester, harness, vehicleAssociatedDataCleaner: cleaner);
    await _focusNewestVehicle(tester);
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('garage-action-delete')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('garage-confirm-delete-vehicle')),
    );
    await tester.pumpAndSettle();

    expect(cleaner.deletedVehicleIds, [seeded.newest.id]);
    expect(
      find.text('No pudimos limpiar los datos asociados. Inténtalo de nuevo.'),
      findsOneWidget,
    );
    expect(await harness.repository.getVehicle(seeded.newest.id), isNotNull);
    expect((await harness.repository.getActiveVehicle())?.id, seeded.active.id);
  });

  testWidgets('delete action is safe if screen disposes during cleanup', (
    tester,
  ) async {
    final seeded = await _seedThreeVehicles(harness);
    final cleaner = _RecordingVehicleDataCleaner()..gate = Completer<void>();
    final repository = _RecordingVehicleRepository(harness);

    await _openGarage(
      tester,
      harness,
      vehicleAssociatedDataCleaner: cleaner,
      vehicleRepository: repository,
    );
    await _focusNewestVehicle(tester);
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('garage-action-delete')),
    );
    await tester.tap(
      find.byKey(const ValueKey('garage-confirm-delete-vehicle')),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    cleaner.gate!.complete();
    await tester.pumpAndSettle();

    expect(cleaner.deletedVehicleIds, [seeded.newest.id]);
    expect(repository.deletedVehicleIds, [seeded.newest.id]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'delete action reports repository failure after private cleanup',
    (tester) async {
      final seeded = await _seedThreeVehicles(harness);
      final cleaner = _RecordingVehicleDataCleaner();
      final repository = _RecordingVehicleRepository(harness)
        ..failDelete = true;

      await _openGarage(
        tester,
        harness,
        vehicleAssociatedDataCleaner: cleaner,
        vehicleRepository: repository,
      );
      await _focusNewestVehicle(tester);
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('garage-action-delete')),
      );
      await tester.tap(
        find.byKey(const ValueKey('garage-confirm-delete-vehicle')),
      );
      await tester.pumpAndSettle();

      expect(cleaner.deletedVehicleIds, [seeded.newest.id]);
      expect(repository.deletedVehicleIds, [seeded.newest.id]);
      expect(
        find.text(
          'Los datos privados se limpiaron, pero no pudimos eliminar el vehículo. Inténtalo de nuevo.',
        ),
        findsOneWidget,
      );
      expect(await harness.repository.getVehicle(seeded.newest.id), isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'delete action keeps active vehicle retryable when fallback fails',
    (tester) async {
      final seeded = await _seedThreeVehicles(harness);
      final cleaner = _RecordingVehicleDataCleaner();
      final repository = _RecordingVehicleRepository(harness)
        ..failSetActive = true;

      await _openGarage(
        tester,
        harness,
        vehicleAssociatedDataCleaner: cleaner,
        vehicleRepository: repository,
      );
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('garage-action-delete')),
      );
      await tester.tap(
        find.byKey(const ValueKey('garage-confirm-delete-vehicle')),
      );
      await tester.pumpAndSettle();

      expect(cleaner.deletedVehicleIds, [seeded.active.id]);
      expect(repository.deletedVehicleIds, isEmpty);
      expect(await harness.repository.getVehicle(seeded.active.id), isNotNull);
      expect(
        (await harness.repository.getActiveVehicle())?.id,
        seeded.active.id,
      );
      expect(
        find.text('No pudimos completar la eliminación. Inténtalo de nuevo.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('add vehicle opens existing onboarding', (tester) async {
    await _openGarage(tester, harness);
    await tester.tap(find.byKey(const ValueKey('garage-add-vehicle')).first);
    await tester.pumpAndSettle();

    expect(find.text('Agregar vehículo'), findsWidgets);
    expect(
      find.byKey(const ValueKey('vehicle-choice-privateCar')),
      findsOneWidget,
    );
  });

  testWidgets('adding another vehicle does not replace active vehicle', (
    tester,
  ) async {
    final active = await _createVehicle(harness, plate: 'AAA111');
    await harness.repository.setActiveVehicle(active.id);

    await _openGarage(tester, harness, size: const Size(480, 900));
    await _tapVisible(tester, find.byKey(const ValueKey('garage-add-vehicle')));
    await tester.pumpAndSettle();
    await _completeOnboarding(
      tester,
      choiceKey: 'vehicle-choice-taxi',
      plate: 'TAX123',
    );

    expect((await harness.repository.getActiveVehicle())?.id, active.id);
    expect(await harness.repository.listVehicles(), hasLength(2));
  });

  testWidgets('detail keeps vehicle status routes scoped to tapped vehicle', (
    tester,
  ) async {
    await _createVehicle(harness, plate: 'AAA111');
    final other = await _createVehicle(harness, plate: 'BBB222');
    await harness.repository.setActiveVehicle(other.id);
    await VehicleObligationStore(harness.database).upsert(
      vehicleId: other.id,
      type: VehicleObligationType.soat,
      dueDate: DateTime(2026, 12, 31),
    );

    await _openGarage(tester, harness);
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('garage-action-detail')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('detail-status-soat')));
    await tester.pumpAndSettle();

    expect(find.text('BBB222'), findsWidgets);
    expect(find.text('SOAT ACTIVO'), findsOneWidget);
    expect(find.text('¡Todo en regla!'), findsOneWidget);
    expect((await harness.repository.getActiveVehicle())?.id, other.id);
  });

  testWidgets(
    'P03 detail Pico entry opens scoped personal Pico inside Garage shell',
    (tester) async {
      await harness.preferences.setString(
        picoJurisdictionPreferenceKey,
        'co-dc-bogota',
      );
      final seeded = await _seedThreeVehicles(harness);

      await _openGarage(tester, harness);
      await _focusNewestVehicle(tester);
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('garage-action-detail')),
      );

      expect(find.text(seeded.newest.plate), findsWidgets);
      expect(
        find.text('Pendiente de activar datos de movilidad'),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('detail-status-pico')), findsOneWidget);
      expect(find.text('Ver estado y calendario'), findsOneWidget);

      final picoEntry = find.byKey(const ValueKey('detail-status-pico'));
      await tester.ensureVisible(picoEntry);
      await tester.pump();
      await tester.tap(picoEntry);
      await _pumpPicoRoute(tester);

      expect(find.byType(PicoDetailScreen), findsOneWidget);
      final pico = tester.widget<PicoDetailScreen>(
        find.byType(PicoDetailScreen),
      );
      expect(pico.vehicleId, seeded.newest.id);
      expect(
        find.byKey(const ValueKey('app-bottom-navigation')),
        findsOneWidget,
      );
      expect(_selectedBottomNavLabels(tester), contains('Garaje'));
      expect(
        (await harness.repository.getActiveVehicle())?.id,
        seeded.active.id,
      );
    },
  );

  testWidgets('Apps overlay opens over Garage and closes back to same focus', (
    tester,
  ) async {
    final seeded = await _seedThreeVehicles(harness);

    await _openGarage(tester, harness);
    await _focusNewestVehicle(tester);
    expect(find.text(seeded.newest.plate), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('tab-apps')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('apps-launcher-overlay')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('garage-compact-top-bar')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('tab-apps')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('apps-launcher-overlay')), findsNothing);
    expect(find.text(seeded.newest.plate), findsWidgets);
  });

  testWidgets('Garage V2 viewports and text scales do not overflow', (
    tester,
  ) async {
    for (final viewport in [
      (name: '360x800', size: const Size(360, 800), scale: 1.0),
      (name: '360x780', size: const Size(360, 780), scale: 1.0),
      (name: '390x844', size: const Size(390, 844), scale: 1.0),
      (name: '412x915', size: const Size(412, 915), scale: 1.0),
      (name: '390x844 textScale 1.5', size: const Size(390, 844), scale: 1.5),
      (name: '390x844 textScale 2.0', size: const Size(390, 844), scale: 2.0),
    ]) {
      await _seedThreeVehicles(harness);
      await _openGarage(
        tester,
        harness,
        size: viewport.size,
        textScaleFactor: viewport.scale,
        boundedSettle: true,
      );

      expect(
        find.byKey(const ValueKey('garage-v2-scroll')),
        findsOneWidget,
        reason: viewport.name,
      );
      expect(tester.takeException(), isNull, reason: viewport.name);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await harness.dispose();
      harness = TestAppHarness();
    }
  });

  testWidgets('Garage V2 standard phones fit owner layout without scrolling', (
    tester,
  ) async {
    for (final viewport in [
      (name: '360x800', size: const Size(360, 800)),
      (name: '360x780', size: const Size(360, 780)),
      (name: '390x844', size: const Size(390, 844)),
      (name: '412x915', size: const Size(412, 915)),
    ]) {
      await _seedThreeVehicles(harness);
      await _openGarage(
        tester,
        harness,
        size: viewport.size,
        boundedSettle: true,
      );

      _expectGarageCoreAboveNav(tester, reason: '${viewport.name} active');
      await _focusNewestVehicle(tester);
      expect(find.text('No activo'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('garage-action-make-active')),
        findsOneWidget,
      );
      _expectGarageCoreAboveNav(tester, reason: '${viewport.name} non-active');
      expect(tester.takeException(), isNull, reason: viewport.name);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await harness.dispose();
      harness = TestAppHarness();
    }
  });
}

class _SeededVehicles {
  const _SeededVehicles({
    required this.oldest,
    required this.active,
    required this.newest,
  });

  final VehicleProfile oldest;
  final VehicleProfile active;
  final VehicleProfile newest;
}

Future<_SeededVehicles> _seedThreeVehicles(TestAppHarness harness) async {
  final oldest = await _createVehicle(
    harness,
    plate: 'MOT123',
    kind: VehicleKind.motorcycle,
    nickname: 'Yamaha MT-07',
    year: 2021,
  );
  final active = await _createVehicle(
    harness,
    plate: 'ABC123',
    brand: 'Mazda',
    model: 'CX-5',
    year: 2022,
    city: 'Bogotá D. C.',
  );
  final newest = await _createVehicle(
    harness,
    plate: 'XYZ789',
    brand: 'Chevrolet',
    model: 'Onix',
    year: 2020,
    city: 'Medellín',
  );
  await harness.repository.setActiveVehicle(active.id);
  return _SeededVehicles(oldest: oldest, active: active, newest: newest);
}

Future<VehicleProfile> _createVehicle(
  TestAppHarness harness, {
  required String plate,
  VehicleKind kind = VehicleKind.car,
  VehicleServiceType serviceType = VehicleServiceType.private,
  String? subtype,
  String? nickname,
  String city = 'Bogota',
  String? brand,
  String? model,
  int? year,
  String? color,
}) {
  return harness.repository.createVehicle(
    plate: plate,
    kind: kind,
    serviceType: serviceType,
    subtype: subtype,
    nickname: nickname,
    registrationCity: city,
    brand: brand,
    model: model,
    year: year,
    color: color,
  );
}

Future<void> _openGarage(
  WidgetTester tester,
  TestAppHarness harness, {
  Size size = const Size(390, 844),
  double textScaleFactor = 1,
  bool boundedSettle = false,
  VehicleAssociatedDataCleaner? vehicleAssociatedDataCleaner,
  VehicleRepository? vehicleRepository,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await harness.pump(
    tester,
    vehicleAssociatedDataCleaner: vehicleAssociatedDataCleaner,
    wrap: vehicleRepository == null
        ? null
        : (app) => ProviderScope(
            overrides: [
              vehicleRepositoryProvider.overrideWithValue(vehicleRepository),
            ],
            child: app,
          ),
  );
  await tester.tap(find.byKey(const ValueKey('tab-garage')));
  if (boundedSettle) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));
  } else {
    await tester.pumpAndSettle();
  }
}

class _RecordingVehicleDataCleaner extends VehicleAssociatedDataCleaner {
  _RecordingVehicleDataCleaner()
    : super(
        documentStore: PrivateVehicleDocumentStore(),
        defenseCaseStore: DefenseCaseStore(),
        peritajesDraftStore: PeritajesDraftStore(_MemoryPreferences()),
        preferences: _MemoryPreferences(),
      );

  final deletedVehicleIds = <String>[];
  Completer<void>? gate;
  var fail = false;

  @override
  Future<void> deleteForVehicle(String vehicleId) async {
    deletedVehicleIds.add(vehicleId);
    if (fail) {
      throw StateError('cleanup failed');
    }
    final activeGate = gate;
    if (activeGate != null) {
      await activeGate.future;
    }
  }
}

class _RecordingVehicleRepository extends VehicleRepository {
  _RecordingVehicleRepository(TestAppHarness harness)
    : super(database: harness.database, preferences: harness.preferences);

  final deletedVehicleIds = <String>[];
  var failDelete = false;
  var failSetActive = false;

  @override
  Future<void> deleteVehicle(String id) async {
    deletedVehicleIds.add(id);
    if (failDelete) {
      throw StateError('delete failed');
    }
    await super.deleteVehicle(id);
  }

  @override
  Future<void> setActiveVehicle(String id) async {
    if (failSetActive) {
      throw StateError('active fallback failed');
    }
    await super.setActiveVehicle(id);
  }
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

Future<void> _goTo(WidgetTester tester, String location) async {
  final context = tester.element(
    find.byKey(const ValueKey('app-bottom-navigation')),
  );
  GoRouter.of(context).go(location);
  await tester.pumpAndSettle();
}

Future<void> _focusNewestVehicle(WidgetTester tester) async {
  await tester.ensureVisible(
    find.byKey(const ValueKey('garage-vehicle-carousel')),
  );
  await tester.pumpAndSettle();
  for (var attempt = 0; attempt < 3; attempt += 1) {
    if (find.text('3 de 3').evaluate().isNotEmpty) {
      break;
    }
    await tester.drag(
      find.byKey(const ValueKey('garage-vehicle-carousel')),
      const Offset(-520, 0),
    );
    await tester.pumpAndSettle();
  }
  expect(find.text('3 de 3'), findsOneWidget);
}

Future<void> _focusOldestVehicle(WidgetTester tester) async {
  await tester.ensureVisible(
    find.byKey(const ValueKey('garage-vehicle-carousel')),
  );
  await tester.pumpAndSettle();
  for (var attempt = 0; attempt < 3; attempt += 1) {
    if (find.text('1 de 3').evaluate().isNotEmpty) {
      break;
    }
    await tester.drag(
      find.byKey(const ValueKey('garage-vehicle-carousel')),
      const Offset(520, 0),
    );
    await tester.pumpAndSettle();
  }
  expect(find.text('1 de 3'), findsOneWidget);
}

void _expectGarageInfoPanel(WidgetTester tester, VehicleProfile vehicle) {
  final panel = find.byKey(const ValueKey('garage-info-panel'));
  expect(
    find.descendant(of: panel, matching: find.text(vehicle.plate)),
    findsOneWidget,
  );
  expect(
    find.descendant(of: panel, matching: find.text(vehicle.registrationCity!)),
    findsOneWidget,
  );
  expect(
    find.descendant(of: panel, matching: find.text('${vehicle.year}')),
    findsOneWidget,
  );
}

void _expectGarageCoreAboveNav(WidgetTester tester, {required String reason}) {
  final infoPanel = tester.getSize(
    find.byKey(const ValueKey('garage-info-panel')),
  );
  final addBottom = tester
      .getBottomLeft(find.byKey(const ValueKey('garage-add-vehicle')))
      .dy;
  final actionsBottom = tester
      .getBottomLeft(find.byKey(const ValueKey('garage-quick-actions')))
      .dy;
  final navTop = tester
      .getTopLeft(find.byKey(const ValueKey('app-bottom-navigation')))
      .dy;

  expect(infoPanel.height, lessThanOrEqualTo(122), reason: reason);
  expect(addBottom, lessThan(navTop), reason: reason);
  expect(actionsBottom, lessThan(navTop), reason: reason);
  expect(find.byKey(const ValueKey('garage-action-detail')), findsOneWidget);
  expect(
    find.byKey(const ValueKey('garage-action-maintenance')),
    findsOneWidget,
  );
  expect(find.byKey(const ValueKey('garage-action-documents')), findsOneWidget);
  expect(find.byKey(const ValueKey('garage-action-delete')), findsOneWidget);
}

List<String> _selectedBottomNavLabels(WidgetTester tester) {
  return tester
      .widgetList<Semantics>(find.byType(Semantics))
      .where((widget) => widget.properties.selected == true)
      .map((widget) => widget.properties.label)
      .whereType<String>()
      .toList();
}

Future<void> _openDetailAndReturn(
  WidgetTester tester,
  VehicleProfile vehicle,
) async {
  await _tapVisible(tester, find.byKey(const ValueKey('garage-action-detail')));
  expect(find.text('Detalle del vehículo'), findsOneWidget);
  expect(find.text(vehicle.plate), findsOneWidget);
  await tester.tap(find.byTooltip('Volver'));
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(
  WidgetTester tester,
  Finder finder, {
  bool settle = true,
}) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }
}

Future<void> _pumpPicoRoute(WidgetTester tester) async {
  for (var i = 0; i < 20; i += 1) {
    await tester.pump(const Duration(milliseconds: 300));
    if (find.byType(PicoDetailScreen).evaluate().isNotEmpty) {
      return;
    }
  }
}

Future<void> _completeOnboarding(
  WidgetTester tester, {
  required String choiceKey,
  String plate = 'abc 123',
  String city = 'Bogota',
}) async {
  await tester.tap(find.byKey(ValueKey(choiceKey)));
  await tester.pumpAndSettle();
  await _enterText(tester, 'vehicle-plate-field', plate);
  await _selectManualCity(tester, city);
  await _tapSave(tester);
}

Future<void> _enterText(WidgetTester tester, String key, String value) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.enterText(finder, value);
  await tester.pump();
}

Future<void> _selectManualCity(WidgetTester tester, String value) async {
  await tester.tap(find.byKey(const ValueKey('vehicle-city-field')));
  await tester.pumpAndSettle();
  await _enterText(tester, 'registration-city-search-field', value);
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(const ValueKey('registration-city-manual-option')),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapSave(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('vehicle-save-button'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}
