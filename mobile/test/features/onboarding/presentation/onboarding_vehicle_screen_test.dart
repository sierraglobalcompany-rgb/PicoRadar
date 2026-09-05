import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/features/apps_launcher/presentation/apps_screen.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/garage/data/vehicle_repository.dart';
import 'package:picoradar/features/onboarding/data/registration_city_catalog.dart';
import 'package:picoradar/features/onboarding/presentation/onboarding_vehicle_screen.dart';
import 'package:picoradar/features/pico_placa/data/pico_preferences.dart';
import 'package:picoradar/features/location/data/location_preferences.dart';

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
    expect(find.byKey(const ValueKey('home-empty-state')), findsOneWidget);
    expect(find.text('No tienes vehículos todavía'), findsOneWidget);
  });

  testWidgets('onboarding route opens vehicle onboarding', (tester) async {
    await _openOnboarding(tester, harness);

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

  testWidgets('UI back from step 2 returns to the vehicle selector', (
    tester,
  ) async {
    await _openOnboarding(tester, harness);
    await tester.tap(find.byKey(const ValueKey('vehicle-choice-privateCar')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('onboarding-back')));
    await tester.pumpAndSettle();

    expect(find.text('Paso 1 de 2'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('vehicle-choice-motorcycle')),
      findsOneWidget,
    );
  });

  testWidgets('system back from step 2 allows choosing another family', (
    tester,
  ) async {
    await _openOnboarding(tester, harness);
    await tester.tap(find.byKey(const ValueKey('vehicle-choice-privateCar')));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vehicle-choice-motorcycle')));
    await tester.pumpAndSettle();

    expect(find.text('Paso 2 de 2'), findsOneWidget);
    expect(find.text('Moto'), findsOneWidget);
    expect(find.byKey(const ValueKey('vehicle-subtype-field')), findsOneWidget);
  });

  testWidgets('new car subtype labels use the owner-approved catalog', (
    tester,
  ) async {
    await _openOnboarding(tester, harness);
    await tester.tap(find.byKey(const ValueKey('vehicle-choice-privateCar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vehicle-subtype-field')));
    await tester.pumpAndSettle();

    expect(find.text('Camioneta / SUV'), findsOneWidget);
    expect(find.text('Coupé / Hatchback'), findsOneWidget);
    expect(find.text('Coupé'), findsNothing);
  });

  testWidgets('back and reselecting car preserves a compatible subtype', (
    tester,
  ) async {
    await _openOnboarding(tester, harness);
    await tester.tap(find.byKey(const ValueKey('vehicle-choice-privateCar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vehicle-subtype-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Camioneta / SUV').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('onboarding-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vehicle-choice-privateCar')));
    await tester.pumpAndSettle();

    expect(find.text('Camioneta / SUV'), findsOneWidget);
  });

  testWidgets('switching from car to motorcycle clears incompatible subtype', (
    tester,
  ) async {
    await _openOnboarding(tester, harness);
    await tester.tap(find.byKey(const ValueKey('vehicle-choice-privateCar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vehicle-subtype-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Camioneta / SUV').last);
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vehicle-choice-motorcycle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vehicle-subtype-field')));
    await tester.pumpAndSettle();

    expect(find.text('Camioneta / SUV'), findsNothing);
    expect(find.text('Scooter'), findsOneWidget);
  });

  testWidgets('legacy car_coupe edits without changing its subtype', (
    tester,
  ) async {
    final vehicle = await harness.repository.createVehicle(
      plate: 'LEG123',
      kind: VehicleKind.car,
      serviceType: VehicleServiceType.private,
      subtype: 'car_coupe',
      registrationCity: 'Bogota',
    );

    await _openVehicleEdit(tester, harness, vehicle.id);
    expect(find.text('Coupé (anterior)'), findsOneWidget);
    await _tapSave(tester);

    expect(
      (await harness.repository.getVehicle(vehicle.id))?.subtype,
      'car_coupe',
    );
    expect(tester.takeException(), isNull);
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

    await _selectManualCity(tester, 'Bogota');
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

  testWidgets('registration city picker selects an official catalog city', (
    tester,
  ) async {
    await _openOnboarding(tester, harness);
    await tester.tap(find.byKey(const ValueKey('vehicle-choice-privateCar')));
    await tester.pumpAndSettle();

    await _selectCatalogCity(tester, 'medellin', 'Medellín - Antioquia');
    await _enterText(tester, 'vehicle-plate-field', 'abc 123');
    await _tapSave(tester);

    final vehicle = (await harness.repository.listVehicles()).single;
    expect(vehicle.registrationCity, 'Medellín - Antioquia');
  });

  testWidgets(
    'manual registration fallback persists without mutating Pico city',
    (tester) async {
      await harness.preferences.setString(
        picoJurisdictionPreferenceKey,
        'co-ant-medellin',
      );
      await harness.preferences.setString(locationModePreferenceKey, 'manual');
      await _openOnboarding(tester, harness);
      await tester.tap(find.byKey(const ValueKey('vehicle-choice-privateCar')));
      await tester.pumpAndSettle();

      await _selectManualCity(tester, 'Ciudad QA Nueva');
      await _enterText(tester, 'vehicle-plate-field', 'abc 123');
      await _tapSave(tester);

      final vehicle = (await harness.repository.listVehicles()).single;
      expect(vehicle.registrationCity, 'Ciudad QA Nueva');
      expect(
        await harness.preferences.getString(picoJurisdictionPreferenceKey),
        'co-ant-medellin',
      );
      expect(
        await harness.preferences.getString(locationModePreferenceKey),
        'manual',
      );
    },
  );

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
    expect(await harness.repository.listVehicles(), hasLength(1));
  });

  testWidgets('after saving can return to Apps without post-route setState', (
    tester,
  ) async {
    await _openOnboardingWithReturnPath(tester, harness, '/apps');

    await _completeOnboarding(tester, choiceKey: 'vehicle-choice-privateCar');

    expect(find.text('Apps'), findsOneWidget);
    expect(await harness.repository.listVehicles(), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('returning to Apps preserves active vehicle after later save', (
    tester,
  ) async {
    final active = await harness.repository.createVehicle(
      plate: 'ACT001',
      kind: VehicleKind.car,
      serviceType: VehicleServiceType.private,
      registrationCity: 'Bogota',
    );
    await harness.repository.setActiveVehicle(active.id);
    await _openOnboardingWithReturnPath(tester, harness, '/apps');

    await _completeOnboarding(
      tester,
      choiceKey: 'vehicle-choice-privateCar',
      plate: 'NEW002',
    );

    final vehicles = await harness.repository.listVehicles();
    expect(
      vehicles.map((vehicle) => vehicle.plate),
      containsAll(['ACT001', 'NEW002']),
    );
    expect(
      await harness.preferences.getString(
        VehicleRepository.activeVehiclePreferenceKey,
      ),
      active.id,
    );
    expect(find.text('Apps'), findsOneWidget);
    expect(find.textContaining('ACT001'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('returning to Apps remains stable across 25 later saves', (
    tester,
  ) async {
    final active = await harness.repository.createVehicle(
      plate: 'ACT001',
      kind: VehicleKind.car,
      serviceType: VehicleServiceType.private,
      registrationCity: 'Bogota',
    );
    await harness.repository.setActiveVehicle(active.id);

    for (var i = 0; i < 25; i += 1) {
      final plate = 'QA${(600 + i).toString()}';
      await _openOnboardingWithReturnPath(tester, harness, '/apps');
      await _completeOnboarding(
        tester,
        choiceKey: 'vehicle-choice-privateCar',
        plate: plate,
      );

      final vehicles = await harness.repository.listVehicles();
      expect(vehicles.map((vehicle) => vehicle.plate), contains(plate));
      expect(
        await harness.preferences.getString(
          VehicleRepository.activeVehiclePreferenceKey,
        ),
        active.id,
      );
      expect(find.textContaining('ACT001'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    expect(await harness.repository.listVehicles(), hasLength(26));
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
  final router = GoRouter(
    initialLocation: '/vehicle-onboarding',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Inicio'))),
      ),
      GoRoute(
        path: '/vehicle-onboarding',
        builder: (context, state) =>
            const OnboardingVehicleScreen(returnPath: '/'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(harness.database),
        appPreferencesProvider.overrideWithValue(harness.preferences),
        registrationCityCatalogProvider.overrideWith(
          (_) async => _testRegistrationCatalog,
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openVehicleEdit(
  WidgetTester tester,
  TestAppHarness harness,
  String vehicleId,
) async {
  final router = GoRouter(
    initialLocation: '/vehicle-edit/$vehicleId',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Inicio'))),
      ),
      GoRoute(
        path: '/vehicle-edit/:vehicleId',
        builder: (context, state) => OnboardingVehicleScreen(
          vehicleId: state.pathParameters['vehicleId'],
          returnPath: '/',
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(harness.database),
        appPreferencesProvider.overrideWithValue(harness.preferences),
        registrationCityCatalogProvider.overrideWith(
          (_) async => _testRegistrationCatalog,
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openOnboardingWithReturnPath(
  WidgetTester tester,
  TestAppHarness harness,
  String returnPath,
) async {
  final router = GoRouter(
    initialLocation: '/vehicle-onboarding',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Inicio'))),
      ),
      GoRoute(
        path: '/apps',
        builder: (context, state) => const Scaffold(body: AppsScreen()),
      ),
      GoRoute(
        path: '/vehicle-onboarding',
        builder: (context, state) =>
            OnboardingVehicleScreen(returnPath: returnPath),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(harness.database),
        appPreferencesProvider.overrideWithValue(harness.preferences),
        registrationCityCatalogProvider.overrideWith(
          (_) async => _testRegistrationCatalog,
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

const _testRegistrationCatalog = RegistrationCityCatalog(
  records: [
    RegistrationCity(
      municipality: 'Bogotá',
      department: 'Bogotá D.C.',
      displayName: 'Bogotá - Bogotá D.C.',
      source: 'RUNT2.0 OT',
    ),
    RegistrationCity(
      municipality: 'Medellín',
      department: 'Antioquia',
      displayName: 'Medellín - Antioquia',
      source: 'RUNT2.0 OT',
    ),
    RegistrationCity(
      municipality: 'Bucaramanga',
      department: 'Santander',
      displayName: 'Bucaramanga - Santander',
      source: 'RUNT2.0 OT',
    ),
  ],
);

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

Future<void> _selectCatalogCity(
  WidgetTester tester,
  String query,
  String displayName,
) async {
  await _openRegistrationCityPicker(tester);
  await _enterText(tester, 'registration-city-search-field', query);
  await tester.pumpAndSettle();
  await tester.tap(find.text(displayName));
  await tester.pumpAndSettle();
}

Future<void> _selectManualCity(WidgetTester tester, String value) async {
  await _openRegistrationCityPicker(tester);
  await _enterText(tester, 'registration-city-search-field', value);
  await tester.pumpAndSettle();
  await tester.ensureVisible(
    find.byKey(const ValueKey('registration-city-manual-option')),
  );
  await tester.tap(
    find.byKey(const ValueKey('registration-city-manual-option')),
  );
  await tester.pumpAndSettle();
}

Future<void> _openRegistrationCityPicker(WidgetTester tester) async {
  final cityField = find.byKey(const ValueKey('vehicle-city-field'));
  await tester.ensureVisible(cityField);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();

  final searchField = find.byKey(
    const ValueKey('registration-city-search-field'),
  );
  for (var attempt = 0; attempt < 3; attempt += 1) {
    await tester.tap(cityField);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    if (searchField.evaluate().isNotEmpty) {
      return;
    }
  }
  expect(searchField, findsOneWidget);
}

Future<void> _tapSave(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('vehicle-save-button'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}
