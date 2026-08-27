import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
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

  testWidgets('garage shows several vehicles', (tester) async {
    final car = await _createVehicle(harness, plate: 'AAA111');
    final taxi = await _createVehicle(
      harness,
      plate: 'TAX123',
      serviceType: VehicleServiceType.taxi,
      subtype: 'taxi',
    );

    await _openGarage(tester, harness);

    expect(find.text(car.plate), findsOneWidget);
    expect(find.text(taxi.plate), findsOneWidget);
    expect(
      find.text('Tus vehículos y su estado en un solo lugar.'),
      findsOneWidget,
    );
  });

  testWidgets('private car is labeled for users', (tester) async {
    await _createVehicle(harness, plate: 'AAA111');

    await _openGarage(tester, harness);

    expect(find.text('Carro particular'), findsOneWidget);
    expect(find.text('private'), findsNothing);
  });

  testWidgets('motorcycle is labeled for users', (tester) async {
    await _createVehicle(
      harness,
      plate: 'MOT123',
      kind: VehicleKind.motorcycle,
    );

    await _openGarage(tester, harness);

    expect(find.text('Moto'), findsOneWidget);
    expect(find.text('motorcycle'), findsNothing);
  });

  testWidgets('taxi is labeled for users', (tester) async {
    await _createVehicle(
      harness,
      plate: 'TAX123',
      serviceType: VehicleServiceType.taxi,
      subtype: 'taxi',
    );

    await _openGarage(tester, harness);

    expect(find.text('Taxi'), findsOneWidget);
    expect(find.text('Carro particular'), findsNothing);
  });

  testWidgets('active badge marks the active vehicle', (tester) async {
    final active = await _createVehicle(harness, plate: 'AAA111');
    await _createVehicle(harness, plate: 'BBB222');
    await harness.repository.setActiveVehicle(active.id);

    await _openGarage(tester, harness);

    expect(find.byKey(ValueKey('vehicle-active-${active.id}')), findsOneWidget);
  });

  testWidgets('switching active vehicle works', (tester) async {
    final first = await _createVehicle(harness, plate: 'AAA111');
    final second = await _createVehicle(harness, plate: 'BBB222');
    await harness.repository.setActiveVehicle(first.id);

    await _openGarage(tester, harness);
    await tester.tap(find.byKey(ValueKey('vehicle-use-${second.id}')));
    await tester.pumpAndSettle();

    expect((await harness.repository.getActiveVehicle())?.id, second.id);
    expect(find.byKey(ValueKey('vehicle-active-${second.id}')), findsOneWidget);
  });

  testWidgets('tapping a vehicle card opens detail', (tester) async {
    final vehicle = await _createVehicle(harness, plate: 'AAA111');

    await _openGarage(tester, harness);
    await tester.tap(find.byKey(ValueKey('vehicle-card-${vehicle.id}')));
    await tester.pumpAndSettle();

    expect(find.text('Detalle del vehículo'), findsOneWidget);
    expect(find.text('Pico y Placa'), findsOneWidget);
  });

  testWidgets('detail shows vehicle fields', (tester) async {
    final vehicle = await _createVehicle(
      harness,
      plate: 'AAA111',
      nickname: 'Casa',
      city: 'Bogota',
      brand: 'Mazda',
      model: '2',
      year: 2021,
      color: 'Rojo',
    );
    await harness.repository.setActiveVehicle(vehicle.id);

    await _openDetail(tester, harness, vehicle.id);

    expect(find.text('AAA111'), findsOneWidget);
    expect(find.text('Carro particular'), findsOneWidget);
    expect(find.text('Bogota'), findsOneWidget);
    expect(find.text('Casa'), findsOneWidget);
    expect(find.text('Mazda 2'), findsOneWidget);
    expect(find.text('2021'), findsOneWidget);
    expect(find.text('Rojo'), findsOneWidget);
    expect(find.text('Activo'), findsOneWidget);
    expect(find.text('SOAT'), findsOneWidget);
    expect(find.text('Tecnomecánica'), findsOneWidget);
    expect(find.text('Seguro'), findsOneWidget);
    expect(find.text('Impuestos'), findsOneWidget);
  });

  testWidgets('garage status cards open modules for the tapped vehicle', (
    tester,
  ) async {
    final active = await _createVehicle(harness, plate: 'AAA111');
    final other = await _createVehicle(harness, plate: 'BBB222');
    await harness.repository.setActiveVehicle(active.id);
    await VehicleObligationStore(harness.database).upsert(
      vehicleId: other.id,
      type: VehicleObligationType.soat,
      dueDate: DateTime(2026, 12, 31),
    );

    await _openDetail(tester, harness, other.id);
    await tester.tap(find.byKey(const ValueKey('detail-status-soat')));
    await tester.pumpAndSettle();

    expect(find.text('BBB222'), findsOneWidget);
    expect(find.text('AAA111'), findsNothing);
    expect((await harness.repository.getActiveVehicle())?.id, active.id);
    expect(find.text('Vigente según la fecha guardada'), findsOneWidget);
  });

  testWidgets('edit reuses the form and updates the vehicle', (tester) async {
    final vehicle = await _createVehicle(harness, plate: 'AAA111');

    await _openDetail(tester, harness, vehicle.id);
    await tester.tap(find.byKey(const ValueKey('detail-edit-vehicle')));
    await tester.pumpAndSettle();
    expect(find.text('Editar vehículo'), findsOneWidget);

    await _enterText(tester, 'vehicle-plate-field', 'bbb 222');
    await _enterText(tester, 'vehicle-city-field', 'Medellin');
    await _tapSave(tester);

    final updated = await harness.repository.getVehicle(vehicle.id);
    expect(updated?.plate, 'BBB222');
    expect(updated?.registrationCity, 'Medellin');
    expect(find.text('BBB222'), findsOneWidget);
  });

  testWidgets('deleting inactive vehicle preserves active vehicle', (
    tester,
  ) async {
    final active = await _createVehicle(harness, plate: 'AAA111');
    final inactive = await _createVehicle(harness, plate: 'BBB222');
    await harness.repository.setActiveVehicle(active.id);

    await _openDetail(tester, harness, inactive.id);
    await _deleteCurrentVehicle(tester);

    expect(await harness.repository.getVehicle(inactive.id), isNull);
    expect((await harness.repository.getActiveVehicle())?.id, active.id);
  });

  testWidgets('deleting active vehicle selects deterministic fallback', (
    tester,
  ) async {
    final active = await _createVehicle(harness, plate: 'AAA111');
    await tester.pump(const Duration(milliseconds: 2));
    final fallback = await _createVehicle(harness, plate: 'BBB222');
    await harness.repository.setActiveVehicle(active.id);

    await _openDetail(tester, harness, active.id);
    await _deleteCurrentVehicle(tester);

    expect(await harness.repository.getVehicle(active.id), isNull);
    expect((await harness.repository.getActiveVehicle())?.id, fallback.id);
  });

  testWidgets('deleting last vehicle clears active vehicle', (tester) async {
    final vehicle = await _createVehicle(harness, plate: 'AAA111');
    await harness.repository.setActiveVehicle(vehicle.id);

    await _openDetail(tester, harness, vehicle.id);
    await _deleteCurrentVehicle(tester);

    expect(await harness.repository.listVehicles(), isEmpty);
    expect(await harness.repository.getActiveVehicle(), isNull);
    expect(find.text('No tienes vehículos todavía'), findsOneWidget);
  });

  testWidgets('adding a second vehicle does not replace active vehicle', (
    tester,
  ) async {
    final active = await _createVehicle(harness, plate: 'AAA111');
    await harness.repository.setActiveVehicle(active.id);

    await _openGarage(tester, harness);
    await tester.tap(find.byKey(const ValueKey('garage-add-vehicle')).first);
    await tester.pumpAndSettle();
    await _completeOnboarding(
      tester,
      choiceKey: 'vehicle-choice-taxi',
      plate: 'TAX123',
    );

    expect((await harness.repository.getActiveVehicle())?.id, active.id);
    expect(await harness.repository.listVehicles(), hasLength(2));
  });

  testWidgets('adding the first vehicle makes it active', (tester) async {
    await _openGarage(tester, harness);
    await tester.tap(find.byKey(const ValueKey('garage-add-vehicle')).first);
    await tester.pumpAndSettle();
    await _completeOnboarding(tester, choiceKey: 'vehicle-choice-privateCar');

    final vehicle = (await harness.repository.listVehicles()).single;
    expect((await harness.repository.getActiveVehicle())?.id, vehicle.id);
  });

  testWidgets('home no longer shows immersive scaffold action', (tester) async {
    await harness.pump(tester);

    expect(find.text('Probar ruta inmersiva'), findsNothing);
  });
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

Future<void> _openGarage(WidgetTester tester, TestAppHarness harness) async {
  await harness.pump(tester);
  await tester.tap(find.byKey(const ValueKey('tab-garage')));
  await tester.pumpAndSettle();
}

Future<void> _openDetail(
  WidgetTester tester,
  TestAppHarness harness,
  String vehicleId,
) async {
  await _openGarage(tester, harness);
  await tester.tap(find.byKey(ValueKey('vehicle-card-$vehicleId')));
  await tester.pumpAndSettle();
}

Future<void> _deleteCurrentVehicle(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('detail-delete-vehicle')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('confirm-delete-vehicle')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
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
