import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/garage/data/vehicle_repository.dart';
import 'package:picoradar/features/onboarding/presentation/onboarding_vehicle_screen.dart';

import '../../../test_app_harness.dart';

void main() {
  late TestAppHarness harness;

  setUp(() {
    harness = TestAppHarness();
  });

  tearDown(() async {
    await harness.dispose();
  });

  testWidgets('without vehicles home shows welcome', (tester) async {
    await harness.pump(tester);

    expect(find.text('PicoRadar'), findsOneWidget);
    expect(
      find.text('Tu vehículo, tus alertas y tu ruta en un solo lugar.'),
      findsOneWidget,
    );
  });

  testWidgets('home CTA opens vehicle onboarding', (tester) async {
    await harness.pump(tester);

    await tester.tap(find.byKey(const ValueKey('home-add-vehicle')));
    await tester.pumpAndSettle();

    expect(find.text('¿Qué conduces?'), findsOneWidget);
  });

  testWidgets('vehicle choices show private car, motorcycle and taxi', (
    tester,
  ) async {
    await _openOnboarding(tester, harness);

    expect(find.text('Carro particular'), findsOneWidget);
    expect(find.text('Moto'), findsOneWidget);
    expect(find.text('Taxi'), findsOneWidget);
  });

  testWidgets('selecting private car creates car private vehicle', (
    tester,
  ) async {
    await _openOnboarding(tester, harness);

    await _completeOnboarding(tester, choiceKey: 'vehicle-choice-privateCar');

    final vehicle = (await harness.repository.listVehicles()).single;
    expect(vehicle.kind, VehicleKind.car);
    expect(vehicle.serviceType, VehicleServiceType.private);
  });

  testWidgets('selecting motorcycle creates motorcycle private vehicle', (
    tester,
  ) async {
    await _openOnboarding(tester, harness);

    await _completeOnboarding(
      tester,
      choiceKey: 'vehicle-choice-motorcycle',
      plate: 'mot-01',
    );

    final vehicle = (await harness.repository.listVehicles()).single;
    expect(vehicle.kind, VehicleKind.motorcycle);
    expect(vehicle.serviceType, VehicleServiceType.private);
  });

  testWidgets('selecting taxi creates car taxi vehicle', (tester) async {
    await _openOnboarding(tester, harness);

    await _completeOnboarding(
      tester,
      choiceKey: 'vehicle-choice-taxi',
      plate: 'tax 123',
    );

    final vehicle = (await harness.repository.listVehicles()).single;
    expect(vehicle.kind, VehicleKind.car);
    expect(vehicle.serviceType, VehicleServiceType.taxi);
    expect(vehicle.subtype, 'taxi');
  });

  testWidgets('plate is required', (tester) async {
    await _openOnboarding(tester, harness);
    await tester.tap(find.byKey(const ValueKey('vehicle-choice-privateCar')));
    await tester.pumpAndSettle();

    await _enterText(tester, 'vehicle-city-field', 'Bogota');
    await _tapSave(tester);

    expect(find.text('La placa es obligatoria.'), findsOneWidget);
    expect(await harness.repository.listVehicles(), isEmpty);
  });

  testWidgets('registration city is required', (tester) async {
    await _openOnboarding(tester, harness);
    await tester.tap(find.byKey(const ValueKey('vehicle-choice-privateCar')));
    await tester.pumpAndSettle();

    await _enterText(tester, 'vehicle-plate-field', 'abc 123');
    await _tapSave(tester);

    expect(find.text('La ciudad de matrícula es obligatoria.'), findsOneWidget);
    expect(await harness.repository.listVehicles(), isEmpty);
  });

  testWidgets('plate uses repository normalization', (tester) async {
    await _openOnboarding(tester, harness);

    await _completeOnboarding(
      tester,
      choiceKey: 'vehicle-choice-privateCar',
      plate: 'abc-123',
    );

    final vehicle = (await harness.repository.listVehicles()).single;
    expect(vehicle.plate, 'ABC123');
  });

  testWidgets('draft is restored', (tester) async {
    await harness.preferences.setString(
      onboardingVehicleDraftKey,
      jsonEncode({
        'choice': 'privateCar',
        'plate': 'abc 123',
        'registrationCity': 'Bogota',
        'nickname': 'Mi carro',
        'alertsEnabled': false,
      }),
    );

    await _openOnboarding(tester, harness);

    final plate = tester.widget<EditableText>(find.byType(EditableText).first);
    expect(plate.controller.text, 'abc 123');
    expect(find.text('Mi carro'), findsOneWidget);
  });

  testWidgets('saving clears draft', (tester) async {
    await _openOnboarding(tester, harness);

    await _completeOnboarding(tester, choiceKey: 'vehicle-choice-privateCar');

    expect(
      await harness.preferences.getString(onboardingVehicleDraftKey),
      isNull,
    );
  });

  testWidgets('first vehicle becomes active', (tester) async {
    await _openOnboarding(tester, harness);

    await _completeOnboarding(tester, choiceKey: 'vehicle-choice-privateCar');

    final vehicle = (await harness.repository.listVehicles()).single;
    expect(
      await harness.preferences.getString(
        VehicleRepository.activeVehiclePreferenceKey,
      ),
      vehicle.id,
    );
  });

  testWidgets('after saving reaches Home', (tester) async {
    await _openOnboarding(tester, harness);

    await _completeOnboarding(tester, choiceKey: 'vehicle-choice-privateCar');

    expect(find.text('Inicio'), findsAtLeastNWidgets(1));
    expect(find.text('Tienes 1 vehículo guardado.'), findsOneWidget);
  });

  testWidgets('empty garage opens onboarding', (tester) async {
    await harness.pump(tester);

    await tester.tap(find.byKey(const ValueKey('tab-garage')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('garage-add-vehicle')));
    await tester.pumpAndSettle();

    expect(find.text('¿Qué conduces?'), findsOneWidget);
  });

  testWidgets('onboarding does not request OS permission', (tester) async {
    await _openOnboarding(tester, harness);

    await _completeOnboarding(tester, choiceKey: 'vehicle-choice-privateCar');

    expect(await harness.repository.listVehicles(), hasLength(1));
    expect(
      await harness.preferences.getBool(picoRestrictionAlertsPreferenceKey),
      isTrue,
    );
  });
}

Future<void> _openOnboarding(
  WidgetTester tester,
  TestAppHarness harness,
) async {
  await harness.pump(tester);
  await tester.tap(find.byKey(const ValueKey('home-add-vehicle')));
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
