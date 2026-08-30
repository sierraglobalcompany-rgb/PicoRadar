import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/garage/data/garage_favorites.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/visual_assets/presentation/visual_asset_widgets.dart';
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
    'root actions use focused vehicle and keep truthful placeholders',
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
        find.byKey(const ValueKey('garage-action-maintenance')),
      );
      expect(
        find.byKey(const ValueKey('garage-maintenance-soon-sheet')),
        findsOneWidget,
      );
      expect(find.textContaining('próximamente'), findsWidgets);
      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();

      await _tapVisible(
        tester,
        find.byKey(const ValueKey('garage-action-documents')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Documentos'), findsWidgets);
      expect(find.text('Próximamente'), findsOneWidget);
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

    expect(find.text('BBB222'), findsOneWidget);
    expect(find.text('Vigente según la fecha guardada'), findsOneWidget);
    expect((await harness.repository.getActiveVehicle())?.id, other.id);
  });

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
      (name: '390x844', size: const Size(390, 844)),
      (name: '412x915', size: const Size(412, 915)),
    ]) {
      await _seedThreeVehicles(harness);
      await _openGarage(tester, harness, size: viewport.size);

      final infoPanel = tester.getSize(
        find.byKey(const ValueKey('garage-info-panel')),
      );
      final actionsBottom = tester
          .getBottomLeft(find.byKey(const ValueKey('garage-quick-actions')))
          .dy;
      final navTop = tester
          .getTopLeft(find.byKey(const ValueKey('app-bottom-navigation')))
          .dy;

      expect(infoPanel.height, lessThanOrEqualTo(122), reason: viewport.name);
      expect(actionsBottom, lessThan(navTop), reason: viewport.name);
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
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await harness.pump(tester);
  await tester.tap(find.byKey(const ValueKey('tab-garage')));
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

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
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
  await _enterText(tester, 'vehicle-city-field', city);
  await _tapSave(tester);
}

Future<void> _enterText(WidgetTester tester, String key, String value) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.enterText(finder, value);
  await tester.pump();
}

Future<void> _tapSave(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('vehicle-save-button'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}
