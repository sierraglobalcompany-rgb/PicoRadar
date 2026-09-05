import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/garage/data/vehicle_repository.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_rule.dart';
import 'package:picoradar/features/trip/data/trip_draft_store.dart';
import 'package:picoradar/features/trip/application/trip_services.dart';
import 'package:picoradar/features/trip/data/trip_plan_client.dart';
import 'package:picoradar/features/trip/domain/trip_plan.dart';
import 'package:picoradar/features/trip/data/trip_municipality_catalog.dart';
import 'package:picoradar/features/trip/domain/trip_draft.dart';
import 'package:picoradar/features/trip/presentation/trip_screen.dart';
import 'package:picoradar/features/vehicle_status/platform/external_launcher.dart';

import '../../../test_app_harness.dart';

late TripMunicipalityCatalog _tripCatalog;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemoryPreferences preferences;
  late _FakeExternalLauncher launcher;

  setUpAll(() async {
    final raw = await rootBundle.loadString(tripMunicipalityCatalogAssetPath);
    _tripCatalog = TripMunicipalityCatalog.fromJson(
      jsonDecode(raw) as Map<String, Object?>,
    );
  });

  tearDownAll(_FakeTripRestrictionStore.closeDatabase);

  testWidgets('VIAJE-R1 exposes an explicit plan CTA', (tester) async {
    await _pumpScreen(tester, preferences: preferences);
    expect(find.text('Ver plan de viaje'), findsOneWidget);
  });

  setUp(() {
    preferences = MemoryPreferences();
    launcher = _FakeExternalLauncher();
  });

  testWidgets('VIAJE-R1 immutable request single flight cancel and stale response', (tester) async {
    final client = _PendingPlanClient();
    await TripDraftStore(preferences).saveDraft(TripDraft(
      origin: 'Bogotá', destination: 'Medellín', date: DateTime(2026, 9, 5), departureMinute: 1410,
    ));
    await _pumpScreen(tester, preferences: preferences, activeVehicle: _vehicle(), planClient: client);
    expect(client.requests, isEmpty);
    await _tapByKey(tester, 'trip-standard-vehicle');
    _pressButtonByKey(tester, 'trip-preview');
    _pressButtonByKey(tester, 'trip-preview');
    await tester.pump();
    expect(client.requests, hasLength(1));
    expect(client.requests.single.departureUtc, DateTime.utc(2026, 9, 6, 4, 30));
    expect(client.requests.single.origin.code, '11001');
    await tester.enterText(find.byKey(const ValueKey('trip-destination-field')), 'Cali');
    await tester.pump();
    expect(client.tokens.single!.isCancelled, isTrue);
    expect(client.requests.single.destination.municipality, 'Medellín');
    client.completions.single.complete(_testPlan(client.requests.single));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('trip-plan-result')), findsNothing);
    _pressButtonByKey(tester, 'trip-preview');
    await tester.pump();
    expect(client.requests, hasLength(2));
    _pressButtonByKey(tester, 'trip-cancel-preview');
    await tester.pump();
    expect(client.tokens.last!.isCancelled, isTrue);
    client.completions.last.complete(_testPlan(client.requests.last));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('trip-plan-result')), findsNothing);
  });

  testWidgets('VIAJE-R1 network error keeps local origin and no arrival verdict', (tester) async {
    final client = _PendingPlanClient();
    await TripDraftStore(preferences).saveDraft(TripDraft(
      origin: 'Bogotá', destination: 'Medellín', date: DateTime(2026, 9, 5), departureMinute: 600,
    ));
    await _pumpScreen(tester, preferences: preferences, activeVehicle: _vehicle(), planClient: client);
    await _tapByKey(tester, 'trip-standard-vehicle');
    _pressButtonByKey(tester, 'trip-preview');
    await tester.pump();
    client.completions.single.completeError(const TripPlanFailure('network'));
    await tester.pumpAndSettle();
    expect(find.text('No pudimos conectar. Puedes volver a consultar.'), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-origin-instant')), findsOneWidget);
    expect(find.text('Destino / llegada: no disponible hasta obtener una ruta.'), findsOneWidget);
    expect(client.requests, hasLength(1));
  });

  testWidgets('VIAJE-R1 dispose cancels pending preview', (tester) async {
    final client = _PendingPlanClient();
    await TripDraftStore(preferences).saveDraft(TripDraft(
      origin: 'Bogotá', destination: 'Medellín', date: DateTime(2026, 9, 5), departureMinute: 600,
    ));
    await _pumpScreen(tester, preferences: preferences, activeVehicle: _vehicle(), planClient: client);
    await _tapByKey(tester, 'trip-standard-vehicle');
    _pressButtonByKey(tester, 'trip-preview');
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(client.tokens.single!.isCancelled, isTrue);
    client.completions.single.complete(_testPlan(client.requests.single));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('VIAJE-R1 old draft requires explicit time confirmation', (tester) async {
    await TripDraftStore(preferences).saveDraft(TripDraft(
      origin: 'Bogotá', destination: 'Medellín', date: DateTime(2026, 9, 5),
    ));
    await _pumpScreen(tester, preferences: preferences, activeVehicle: _vehicle());
    await _tapByKey(tester, 'trip-preview');
    expect(find.text('Confirma la hora de salida.'), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-plan-result')), findsNothing);
  });

  testWidgets('VIAJE-R1 physical confirmation required and resets on vehicle change', (tester) async {
    final client = _PendingPlanClient();
    final active = _vehicle();
    final other = _vehicle(id: 'other', plate: 'ZZZ999');
    await TripDraftStore(preferences).saveDraft(TripDraft(
      origin: 'Bogotá', destination: 'Medellín', date: DateTime(2026, 9, 5), departureMinute: 600,
    ));
    await _pumpScreen(tester, preferences: preferences, activeVehicle: active, vehicles: [active, other], planClient: client);
    await _tapByKey(tester, 'trip-preview');
    expect(client.requests, isEmpty);
    expect(find.text('Confirma las características del vehículo.'), findsOneWidget);
    await _tapByKey(tester, 'trip-standard-vehicle');
    await _tapByKey(tester, 'trip-select-vehicle');
    await tester.tap(find.text('Particular · ZZZ999'));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(find.byKey(const ValueKey('trip-standard-vehicle'))).value, isFalse);
    await _tapByKey(tester, 'trip-preview');
    expect(client.requests, isEmpty);
  });

  testWidgets('VIAJE-R1 selecting route updates arrival restriction without remote query', (tester) async {
    final client = _PendingPlanClient();
    await TripDraftStore(preferences).saveDraft(TripDraft(
      origin: 'Bogotá', destination: 'Medellín', date: DateTime(2026, 9, 5), departureMinute: 1410,
    ));
    await _pumpScreen(tester, preferences: preferences, activeVehicle: _vehicle(), planClient: client);
    final container = ProviderScope.containerOf(tester.element(find.byType(TripScreen)));
    await _tapByKey(tester, 'trip-standard-vehicle');
    _pressButtonByKey(tester, 'trip-preview');
    await tester.pump();
    final request = client.requests.single;
    final first = _testPlan(request);
    client.completions.single.complete(TripPlan(requestId: first.requestId, generatedAtUtc: first.generatedAtUtc,
      provider: first.provider, attribution: first.attribution, origin: first.origin, destination: first.destination,
      routes: [first.routes.single, TripRouteOption(id: 'slow', summary: 'Ruta lenta', distanceMeters: 600000,
        durationSeconds: 43200, timeBasis: 'static', tolls: TripTolls(coverage: TripTollCoverage.unknown, vehicleCategory: 'car'))]));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('trip-destination-instant-test-route')), findsOneWidget);
    await _tapByKey(tester, 'trip-select-route-slow');
    expect(find.byKey(const ValueKey('trip-destination-instant-test-route')), findsNothing);
    expect(find.byKey(const ValueKey('trip-destination-instant-slow')), findsOneWidget);
    final evaluation = await container.read(tripInstantRestrictionProvider((municipality: request.destination,
      vehicle: request.vehicle, instantUtc: DateTime.utc(2026, 9, 6, 16, 30))).future);
    expect(evaluation.evaluatedAtUtc, DateTime.utc(2026, 9, 6, 16, 30));
    expect(client.requests, hasLength(1));
    expect(find.byKey(const ValueKey('trip-toll-details-slow')), findsOneWidget);
  });

  testWidgets('VIAJE-R1 mismatched request ID cannot become current plan', (tester) async {
    final client = _PendingPlanClient();
    await TripDraftStore(preferences).saveDraft(TripDraft(origin: 'Bogotá', destination: 'Medellín',
      date: DateTime(2026, 9, 5), departureMinute: 600));
    await _pumpScreen(tester, preferences: preferences, activeVehicle: _vehicle(), planClient: client);
    await _tapByKey(tester, 'trip-standard-vehicle');
    _pressButtonByKey(tester, 'trip-preview');
    await tester.pump();
    final request = client.requests.single;
    client.completions.single.complete(_testPlan(TripPlanRequest(requestId: 'different',
      origin: request.origin, destination: request.destination, vehicle: request.vehicle, departureUtc: request.departureUtc)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('trip-plan-result')), findsNothing);
    expect(find.textContaining('no devolvió un plan verificable'), findsOneWidget);
  });

  testWidgets('VIAJE-R1 validates exact municipalities and same city inline', (tester) async {
    await _pumpScreen(tester, preferences: preferences, activeVehicle: _vehicle());
    await tester.enterText(find.byKey(const ValueKey('trip-origin-field')), 'Barbosa');
    await tester.enterText(find.byKey(const ValueKey('trip-destination-field')), 'xyz');
    await _tapByKey(tester, 'trip-preview');
    expect(find.text('Elige municipio y departamento de las sugerencias.'), findsNWidgets(2));
    await tester.enterText(find.byKey(const ValueKey('trip-origin-field')), 'Bogotá');
    await tester.enterText(find.byKey(const ValueKey('trip-destination-field')), 'bogota');
    await _tapByKey(tester, 'trip-preview');
    expect(find.text('Elige otro municipio: no se ha definido un trayecto urbano.'), findsOneWidget);
  });

  for (final size in [const Size(360, 800), const Size(390, 844), const Size(412, 915)]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('VIAJE-R1 CTA with keyboard $size scale $scale', (tester) async {
        await _pumpScreen(tester, preferences: preferences, size: size, textScale: scale);
        await tester.showKeyboard(find.byKey(const ValueKey('trip-destination-field')));
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await tester.pump();
        expect(MediaQuery.viewInsetsOf(tester.element(find.byType(TripScreen))).bottom, 300);
        await _tapByKey(tester, 'trip-preview');
        expect(find.text('Ingresa el origen.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('shows basic trip planner copy and checklist', (tester) async {
    await _pumpScreen(tester, preferences: preferences);

    expect(find.byKey(const ValueKey('trip-screen')), findsOneWidget);
    expect(find.text('Planea tu viaje'), findsOneWidget);
    expect(find.text('Viaje'), findsNothing);
    expect(
      find.text('PicoRadar no calcula rutas, ETA ni peajes en esta versión.'),
      findsNothing,
    );
    expect(
      find.text(
        'La navegación y el estado vial se consultan en servicios externos.',
      ),
      findsOneWidget,
    );
    expect(find.text('Selecciona un vehículo para consultar el plan.'), findsOneWidget);
    expect(find.text('Revisé Pico y placa'), findsOneWidget);
    expect(find.text('Revisé SOAT'), findsOneWidget);
    expect(find.text('Revisé tecnomecánica'), findsOneWidget);
    expect(
      find.text('Planeé descansos y elementos de seguridad'),
      findsOneWidget,
    );
  });

  testWidgets('shows active vehicle without requiring it', (tester) async {
    await _pumpScreen(
      tester,
      preferences: preferences,
      activeVehicle: _vehicle(plate: 'ABC123'),
    );

    expect(find.text('Particular · ABC123'), findsOneWidget);
  });

  testWidgets('offers local municipality matches only after three letters', (
    tester,
  ) async {
    await _pumpScreen(tester, preferences: preferences);

    await tester.enterText(
      find.byKey(const ValueKey('trip-origin-field')),
      'bo',
    );
    await tester.pump();

    expect(find.text('Bogotá, D.C. · Bogotá, D.C.'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('trip-origin-field')),
      'bog',
    );
    await tester.pump();

    expect(find.text('Bogotá, D.C. · Bogotá, D.C.'), findsOneWidget);
  });

  testWidgets(
    'municipality search ignores accents and disambiguates homonyms',
    (tester) async {
      await _pumpScreen(
        tester,
        preferences: preferences,
        size: const Size(390, 1000),
      );

      await tester.enterText(
        find.byKey(const ValueKey('trip-destination-field')),
        'union',
      );
      await tester.pump();

      expect(find.text('La Unión · Antioquia'), findsOneWidget);
      expect(find.text('La Unión · Nariño'), findsOneWidget);
    },
  );

  testWidgets('deleted draft vehicle requires an explicit new selection', (
    tester,
  ) async {
    await TripDraftStore(preferences).saveDraft(
      TripDraft(
        origin: 'Bogotá',
        destination: 'Medellín',
        date: DateTime(2026, 9, 5),
        activeVehicleId: 'deleted-vehicle',
      ),
    );
    await _pumpScreen(
      tester,
      preferences: preferences,
      activeVehicle: _vehicle(id: 'active-vehicle', plate: 'ACT123'),
      vehicles: [_vehicle(id: 'active-vehicle', plate: 'ACT123')],
    );

    expect(
      find.text('El vehículo del borrador ya no está disponible.'),
      findsOneWidget,
    );
    expect(find.text('Particular · ACT123'), findsNothing);
    expect(find.byKey(const ValueKey('trip-select-vehicle')), findsOneWidget);

    await _tapByKey(tester, 'trip-save-draft');

    expect(
      find.text('Selecciona un vehículo para este viaje.'),
      findsOneWidget,
    );
    expect(
      (await TripDraftStore(preferences).loadDraft())?.activeVehicleId,
      'deleted-vehicle',
    );
  });

  testWidgets(
    'trip vehicle selection leaves the global active vehicle intact',
    (tester) async {
      final active = _vehicle(id: 'vehicle-a', plate: 'AAA123');
      final tripVehicle = _vehicle(
        id: 'vehicle-b',
        plate: 'BBB223',
        serviceType: VehicleServiceType.taxi,
      );
      await preferences.setString(
        VehicleRepository.activeVehiclePreferenceKey,
        active.id,
      );
      await _pumpScreen(
        tester,
        preferences: preferences,
        activeVehicle: active,
        vehicles: [active, tripVehicle],
        size: const Size(390, 1000),
      );

      await _tapByKey(tester, 'trip-select-vehicle');
      await tester.tap(find.text('Taxi · BBB223'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('trip-origin-field')),
        'Bogotá',
      );
      await tester.enterText(
        find.byKey(const ValueKey('trip-destination-field')),
        'Medellín',
      );
      await _tapByKey(tester, 'trip-save-draft');

      expect(
        await preferences.getString(
          VehicleRepository.activeVehiclePreferenceKey,
        ),
        active.id,
      );
      expect(
        (await TripDraftStore(preferences).loadDraft())?.activeVehicleId,
        tripVehicle.id,
      );
      expect(find.text('Taxi · BBB223'), findsOneWidget);
    },
  );

  testWidgets('evaluates origin and destination independently for one date', (
    tester,
  ) async {
    final store = _FakeTripRestrictionStore();
    addTearDown(store.dispose);
    final vehicle = _vehicle(id: 'vehicle-a', plate: 'ABC123');
    await TripDraftStore(preferences).saveDraft(
      TripDraft(
        origin: 'Bogotá',
        destination: 'Medellín',
        date: DateTime(2026, 9, 5),
        activeVehicleId: vehicle.id,
      ),
    );
    await _pumpScreen(
      tester,
      preferences: preferences,
      activeVehicle: vehicle,
      vehicles: [vehicle],
      restrictionStore: store,
      size: const Size(390, 1000),
    );

    await tester.enterText(
      find.byKey(const ValueKey('trip-origin-field')),
      'bog',
    );
    await tester.pump();
    await tester.tap(find.text('Bogotá, D.C. · Bogotá, D.C.'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('trip-destination-field')),
      'med',
    );
    await tester.pump();
    await tester.tap(find.text('Medellín · Antioquia'));
    await tester.pumpAndSettle();

    expect(find.text('Origen · No circula'), findsOneWidget);
    expect(find.text('Destino · Sin información vigente'), findsOneWidget);
    expect(find.text('Consultado para 2026-09-05'), findsNWidgets(2));
    expect(
      store.loadedJurisdictions,
      unorderedEquals(['co-dc-bogota', 'co-ant-medellin']),
    );
  });

  testWidgets('date outside rule coverage is stale rather than unrestricted', (
    tester,
  ) async {
    final store = _FakeTripRestrictionStore();
    addTearDown(store.dispose);
    final vehicle = _vehicle(id: 'vehicle-a', plate: 'ABC123');
    await TripDraftStore(preferences).saveDraft(
      TripDraft(
        origin: 'Bogotá',
        destination: 'Medellín',
        date: DateTime(2027, 1, 2),
        activeVehicleId: vehicle.id,
      ),
    );
    await _pumpScreen(
      tester,
      preferences: preferences,
      activeVehicle: vehicle,
      vehicles: [vehicle],
      restrictionStore: store,
      size: const Size(390, 1000),
    );

    expect(find.text('Origen · Información desactualizada'), findsOneWidget);
    expect(find.text('https://example.test/bogota-source'), findsOneWidget);
    expect(find.text('Origen · Sin restricción para ese día'), findsNothing);
  });

  testWidgets('known stale coverage retains its first source URL', (
    tester,
  ) async {
    final store = _FakeTripRestrictionStore(dataIsStale: true);
    addTearDown(store.dispose);
    final vehicle = _vehicle(id: 'vehicle-a', plate: 'ABC123');
    await TripDraftStore(preferences).saveDraft(
      TripDraft(
        origin: 'Bogotá',
        destination: 'Medellín',
        date: DateTime(2026, 9, 5),
        activeVehicleId: vehicle.id,
      ),
    );
    await _pumpScreen(
      tester,
      preferences: preferences,
      activeVehicle: vehicle,
      vehicles: [vehicle],
      restrictionStore: store,
      size: const Size(390, 1000),
    );

    expect(find.text('Origen · Información desactualizada'), findsOneWidget);
    expect(find.text('https://example.test/bogota-source'), findsOneWidget);
  });

  testWidgets('ambiguous legacy municipality requires department selection', (
    tester,
  ) async {
    final store = _FakeTripRestrictionStore();
    addTearDown(store.dispose);
    final vehicle = _vehicle(id: 'vehicle-a', plate: 'ABC123');
    await TripDraftStore(preferences).saveDraft(
      TripDraft(
        origin: 'Barbosa',
        destination: 'Bogotá',
        date: DateTime(2026, 9, 5),
        activeVehicleId: vehicle.id,
      ),
    );
    await _pumpScreen(
      tester,
      preferences: preferences,
      activeVehicle: vehicle,
      vehicles: [vehicle],
      restrictionStore: store,
      size: const Size(390, 1000),
    );

    expect(find.text('Barbosa · Antioquia'), findsOneWidget);
    expect(find.text('Barbosa · Santander'), findsOneWidget);
    expect(store.loadedJurisdictions, ['co-dc-bogota']);
  });

  testWidgets('selected homonym keeps department through save and restore', (
    tester,
  ) async {
    final vehicle = _vehicle(id: 'vehicle-a', plate: 'ABC123');
    await _pumpScreen(
      tester,
      preferences: preferences,
      activeVehicle: vehicle,
      vehicles: [vehicle],
      size: const Size(390, 1000),
    );
    await tester.enterText(
      find.byKey(const ValueKey('trip-origin-field')),
      'barb',
    );
    await tester.pump();
    await tester.tap(find.text('Barbosa · Santander'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('trip-destination-field')),
      'Bogotá',
    );
    await _tapByKey(tester, 'trip-save-draft');

    expect(
      (await TripDraftStore(preferences).loadDraft())?.origin,
      'Barbosa · Santander',
    );

    await _pumpScreen(
      tester,
      preferences: preferences,
      activeVehicle: vehicle,
      vehicles: [vehicle],
      size: const Size(390, 1000),
    );

    final originField = tester.widget<TextFormField>(
      find.byKey(const ValueKey('trip-origin-field')),
    );
    expect(originField.controller?.text, 'Barbosa · Santander');
    expect(find.text('Barbosa · Antioquia'), findsNothing);
  });

  testWidgets('waits for draft identity before showing the active vehicle', (
    tester,
  ) async {
    final delayedPreferences = _DelayedPreferences()
      ..values[tripDraftPreferenceKey] = '{"origin":"Bogotá","destination":"Medellín","date":"2026-09-05","activeVehicleId":"deleted-vehicle","completedChecklist":[]}'
      ..pauseLoad();
    final active = _vehicle(id: 'active-vehicle', plate: 'ACT123');
    final store = _FakeTripRestrictionStore();
    addTearDown(store.dispose);

    await _pumpScreen(
      tester,
      preferences: delayedPreferences,
      activeVehicle: active,
      vehicles: [active],
      restrictionStore: store,
      settle: false,
    );

    expect(find.text('Particular · ACT123'), findsNothing);
    expect(find.byKey(const ValueKey('trip-loading')), findsOneWidget);
    expect(store.loadedJurisdictions, isEmpty);

    delayedPreferences.completeLoad();
    await tester.pumpAndSettle();

    expect(
      find.text('El vehículo del borrador ya no está disponible.'),
      findsOneWidget,
    );
    expect(find.text('Particular · ACT123'), findsNothing);
  });

  testWidgets('draft read failure offers an explicit retry', (tester) async {
    final failingPreferences = _FailingReadPreferences();

    await _pumpScreen(tester, preferences: failingPreferences);

    expect(find.text('No pudimos cargar el borrador local.'), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-retry-draft-load')), findsOneWidget);

    failingPreferences.throwOnRead = false;
    await tester.tap(find.byKey(const ValueKey('trip-retry-draft-load')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('trip-screen')), findsOneWidget);
  });

  testWidgets('deleted selected trip vehicle must be selected again', (
    tester,
  ) async {
    final active = _vehicle(id: 'vehicle-a', plate: 'AAA123');
    final selected = _vehicle(id: 'vehicle-b', plate: 'BBB223');
    var availableVehicles = [active, selected];
    await _pumpScreen(
      tester,
      preferences: preferences,
      activeVehicle: active,
      vehicleListBuilder: () => availableVehicles,
      size: const Size(390, 1000),
    );

    await _tapByKey(tester, 'trip-select-vehicle');
    await tester.tap(find.text('Particular · BBB223'));
    await tester.pumpAndSettle();

    availableVehicles = [active];
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TripScreen)),
    );
    container.invalidate(vehicleListProvider);
    await tester.pumpAndSettle();

    expect(
      find.text('El vehículo del borrador ya no está disponible.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('trip-origin-field')),
      'Bogotá',
    );
    await tester.enterText(
      find.byKey(const ValueKey('trip-destination-field')),
      'Medellín',
    );
    await _tapByKey(tester, 'trip-save-draft');

    expect(
      find.text('Selecciona un vehículo para este viaje.'),
      findsOneWidget,
    );
    expect(await TripDraftStore(preferences).loadDraft(), isNull);
  });

  testWidgets('validates required origin and destination before navigation', (
    tester,
  ) async {
    await _pumpScreen(tester, preferences: preferences, launcher: launcher);

    await _tapByKey(tester, 'trip-open-google-maps');

    expect(find.text('Ingresa el origen.'), findsOneWidget);
    expect(find.text('Ingresa el destino.'), findsOneWidget);
    expect(launcher.opened, isEmpty);
  });

  testWidgets('opens Google Maps Waze and INVÍAS with exact URLs', (
    tester,
  ) async {
    await _pumpScreen(tester, preferences: preferences, launcher: launcher);
    await tester.enterText(
      find.byKey(const ValueKey('trip-origin-field')),
      'Bogotá',
    );
    await tester.enterText(
      find.byKey(const ValueKey('trip-destination-field')),
      'Medellín',
    );

    await _tapByKey(tester, 'trip-open-google-maps');
    await _tapByKey(tester, 'trip-open-waze');
    await _tapByKey(tester, 'trip-open-invias');

    expect(launcher.opened, [
      'https://www.google.com/maps/dir/?api=1&origin=Bogot%C3%A1&destination=Medell%C3%ADn&travelmode=driving',
      'https://waze.com/ul?q=Medell%C3%ADn&navigate=yes',
      'https://hermes2.invias.gov.co/SIV/',
    ]);
  });

  testWidgets('does not present an unknown toll total as zero', (tester) async {
    await _pumpScreen(tester, preferences: preferences);

    expect(find.text(r'$0'), findsNothing);
    expect(find.textContaining('0 peajes'), findsNothing);
  });

  testWidgets('shows Google Maps Waze and INVÍAS launch failures', (
    tester,
  ) async {
    for (final failureCase in [
      (key: 'trip-open-google-maps', message: 'No pudimos abrir Google Maps.'),
      (key: 'trip-open-waze', message: 'No pudimos abrir Waze.'),
      (key: 'trip-open-invias', message: 'No pudimos abrir INVÍAS.'),
    ]) {
      final failingLauncher = _FakeExternalLauncher()..openResult = false;
      await _pumpScreen(
        tester,
        preferences: preferences,
        launcher: failingLauncher,
        size: const Size(390, 1000),
      );
      await tester.enterText(
        find.byKey(const ValueKey('trip-origin-field')),
        'Bogotá',
      );
      await tester.enterText(
        find.byKey(const ValueKey('trip-destination-field')),
        'Medellín',
      );

      await _tapByKey(tester, failureCase.key);

      expect(find.text(failureCase.message), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('shows Google Maps Waze and INVÍAS launch exceptions', (
    tester,
  ) async {
    for (final failureCase in [
      (key: 'trip-open-google-maps', message: 'No pudimos abrir Google Maps.'),
      (key: 'trip-open-waze', message: 'No pudimos abrir Waze.'),
      (key: 'trip-open-invias', message: 'No pudimos abrir INVÍAS.'),
    ]) {
      final failingLauncher = _FakeExternalLauncher()..throwOnOpen = true;
      await _pumpScreen(
        tester,
        preferences: preferences,
        launcher: failingLauncher,
        size: const Size(390, 1000),
      );
      await tester.enterText(
        find.byKey(const ValueKey('trip-origin-field')),
        'Bogotá',
      );
      await tester.enterText(
        find.byKey(const ValueKey('trip-destination-field')),
        'Medellín',
      );

      await _tapByKey(tester, failureCase.key);

      expect(find.text(failureCase.message), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('saves local draft with active vehicle and checklist only', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      preferences: preferences,
      activeVehicle: _vehicle(id: 'vehicle-a'),
    );
    await tester.enterText(
      find.byKey(const ValueKey('trip-origin-field')),
      'Bogotá',
    );
    await tester.enterText(
      find.byKey(const ValueKey('trip-destination-field')),
      'Cali',
    );
    await _tapByKey(tester, 'trip-checklist-pico_placa');

    await _tapByKey(tester, 'trip-save-draft');

    expect(preferences.values.keys, [tripDraftPreferenceKey]);
    final restored = await TripDraftStore(preferences).loadDraft();
    expect(restored?.origin, 'Bogotá');
    expect(restored?.destination, 'Cali');
    expect(restored?.activeVehicleId, 'vehicle-a');
    expect(restored?.completedChecklist, {TripChecklistItem.picoPlaca});
    expect(find.text('Borrador guardado en este dispositivo.'), findsOneWidget);
  });

  testWidgets(
    'restores and deletes the explicit local draft after confirmation',
    (tester) async {
      await TripDraftStore(preferences).saveDraft(
        TripDraft(
          origin: 'Cali',
          destination: 'Pereira',
          date: DateTime(2026, 9, 5),
          completedChecklist: {TripChecklistItem.soat},
        ),
      );

      await _pumpScreen(tester, preferences: preferences);

      expect(find.text('Cali'), findsOneWidget);
      expect(find.text('Pereira'), findsOneWidget);
      expect(find.text('Fecha · 2026-09-05'), findsOneWidget);
      expect(find.byKey(const ValueKey('trip-draft-restored')), findsOneWidget);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('trip-checklist-soat')),
            )
            .value,
        isTrue,
      );

      await _tapByKey(tester, 'trip-delete-draft');

      expect(find.text('Borrar borrador'), findsOneWidget);
      expect(
        find.text('Se eliminará el borrador guardado en este dispositivo.'),
        findsOneWidget,
      );
      expect(await preferences.getString(tripDraftPreferenceKey), isNotNull);

      await _tapByKey(tester, 'trip-delete-cancel');

      expect(await preferences.getString(tripDraftPreferenceKey), isNotNull);
      expect(find.text('Cali'), findsOneWidget);
      expect(find.text('Pereira'), findsOneWidget);

      await _tapByKey(tester, 'trip-delete-draft');
      await _tapByKey(tester, 'trip-delete-confirm');

      expect(await preferences.getString(tripDraftPreferenceKey), isNull);
      expect(find.text('Borrador eliminado.'), findsOneWidget);
      expect(find.text('Cali'), findsNothing);
      expect(find.text('Pereira'), findsNothing);
    },
  );

  testWidgets('date picker is future-safe for restored drafts', (tester) async {
    final futureDate = DateTime(DateTime.now().year + 12, 9, 5);
    await TripDraftStore(preferences).saveDraft(
      TripDraft(origin: 'Bogotá', destination: 'Cartagena', date: futureDate),
    );
    await _pumpScreen(tester, preferences: preferences);

    expect(find.text('Fecha · ${_formatTestDate(futureDate)}'), findsOneWidget);

    await _tapByKey(tester, 'trip-date-button');

    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('date range includes restored draft and is not pinned to 2026', (
    tester,
  ) async {
    final restoredDate = DateTime(DateTime.now().year - 1, 12, 31);
    await TripDraftStore(preferences).saveDraft(
      TripDraft(origin: 'Bogotá', destination: 'Manizales', date: restoredDate),
    );
    await _pumpScreen(tester, preferences: preferences);

    await _tapByKey(tester, 'trip-date-button');

    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not update UI after dispose during restore', (
    tester,
  ) async {
    final delayedPreferences = _DelayedPreferences()
      ..values[tripDraftPreferenceKey] = '{"origin":"Cali","destination":"Pereira","date":"2026-09-05","completedChecklist":["soat"]}'
      ..pauseLoad();

    await _pumpScreen(tester, preferences: delayedPreferences, settle: false);
    await tester.pumpWidget(const SizedBox.shrink());

    delayedPreferences.completeLoad();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('does not update UI after dispose during save', (tester) async {
    final delayedPreferences = _DelayedPreferences()..pauseSave();
    await _pumpScreen(
      tester,
      preferences: delayedPreferences,
      size: const Size(390, 1000),
    );
    await tester.enterText(
      find.byKey(const ValueKey('trip-origin-field')),
      'Bogotá',
    );
    await tester.enterText(
      find.byKey(const ValueKey('trip-destination-field')),
      'Cali',
    );

    _pressButtonByKey(tester, 'trip-save-draft');
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());

    delayedPreferences.completeSave();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('does not update UI after dispose during delete', (tester) async {
    final delayedPreferences = _DelayedPreferences()..pauseRemove();
    await _pumpScreen(
      tester,
      preferences: delayedPreferences,
      size: const Size(390, 1000),
    );

    _pressButtonByKey(tester, 'trip-delete-draft');
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());

    delayedPreferences.completeRemove();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('target responsive viewports avoid overflow', (tester) async {
    const cases = [
      (Size(360, 800), 1.0),
      (Size(360, 800), 2.0),
      (Size(390, 844), 1.5),
      (Size(412, 915), 2.0),
    ];

    for (final testCase in cases) {
      await _pumpScreen(
        tester,
        preferences: preferences,
        size: testCase.$1,
        textScale: testCase.$2,
      );

      expect(find.byKey(const ValueKey('trip-screen')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}

Future<void> _tapByKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  final hitTest = tester.hitTestOnBinding(tester.getCenter(finder));
  expect(hitTest.path, isNotEmpty, reason: '$key must be hit-testable');
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required MemoryPreferences preferences,
  _FakeExternalLauncher? launcher,
  VehicleProfile? activeVehicle,
  List<VehicleProfile>? vehicles,
  List<VehicleProfile> Function()? vehicleListBuilder,
  RestrictionStore? restrictionStore,
  TripPlanClient? planClient,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool settle = true,
}) async {
  final ownedRestrictionStore = restrictionStore == null
      ? _FakeTripRestrictionStore()
      : null;
  if (ownedRestrictionStore != null) {
    addTearDown(ownedRestrictionStore.dispose);
  }
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (planClient != null) tripPlanClientProvider.overrideWithValue(planClient),
        appPreferencesProvider.overrideWithValue(preferences),
        activeVehicleProvider.overrideWith((ref) async => activeVehicle),
        vehicleListProvider.overrideWith(
          (ref) async =>
              vehicleListBuilder?.call() ??
              vehicles ??
              (activeVehicle == null
                  ? const <VehicleProfile>[]
                  : <VehicleProfile>[activeVehicle]),
        ),
        restrictionStoreProvider.overrideWithValue(
          restrictionStore ?? ownedRestrictionStore!,
        ),
        tripMunicipalityCatalogProvider.overrideWith(
          (ref) async => _tripCatalog,
        ),
        externalLauncherProvider.overrideWithValue(
          launcher ?? _FakeExternalLauncher(),
        ),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const TripScreen(),
      ),
    ),
  );
  await tester.pump();
  if (settle) {
    await tester.pumpAndSettle();
  }
}

String _formatTestDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

void _pressButtonByKey(WidgetTester tester, String key) {
  final widget = tester.widget(find.byKey(ValueKey(key)));
  switch (widget) {
    case ButtonStyleButton(:final onPressed):
      onPressed?.call();
    case IconButton(:final onPressed):
      onPressed?.call();
    default:
      fail('Widget with key $key does not expose an onPressed callback.');
  }
}

VehicleProfile _vehicle({
  String id = 'vehicle-a',
  String plate = 'ABC123',
  VehicleKind kind = VehicleKind.car,
  VehicleServiceType serviceType = VehicleServiceType.private,
}) {
  return VehicleProfile(
    id: id,
    plate: plate,
    kind: kind,
    serviceType: serviceType,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

class _PendingPlanClient implements TripPlanClient {
  final requests = <TripPlanRequest>[];
  final tokens = <CancelToken?>[];
  final completions = <Completer<TripPlan>>[];

  @override
  Future<TripPlan> preview(TripPlanRequest request, {CancelToken? cancelToken}) {
    requests.add(request);
    tokens.add(cancelToken);
    final pending = Completer<TripPlan>();
    completions.add(pending);
    return pending.future;
  }
}

TripPlan _testPlan(TripPlanRequest request) => TripPlan(
  requestId: request.requestId, generatedAtUtc: DateTime.utc(2026, 9, 5, 12),
  provider: 'Test only', attribution: 'Test only',
  origin: const TripResolvedPoint(label: 'Referencia origen', latitude: 4.7, longitude: -74.1),
  destination: const TripResolvedPoint(label: 'Referencia destino', latitude: 6.2, longitude: -75.5),
  routes: [TripRouteOption(id: 'test-route', summary: 'Ruta de prueba', distanceMeters: 420000,
    durationSeconds: 36000, timeBasis: 'static',
    tolls: TripTolls(coverage: TripTollCoverage.unknown, vehicleCategory: 'car'))],
);

class _FakeExternalLauncher implements ExternalLauncher {
  final opened = <String>[];
  var openResult = true;
  var throwOnOpen = false;

  @override
  Future<bool> callPhone(String phone) async => true;

  @override
  Future<bool> openExternal(String uri) async {
    if (throwOnOpen) {
      throw StateError('launcher failed');
    }
    opened.add(uri);
    return openResult;
  }
}

class _FakeTripRestrictionStore extends RestrictionStore {
  factory _FakeTripRestrictionStore({bool dataIsStale = false}) {
    return _FakeTripRestrictionStore._(_database, dataIsStale: dataIsStale);
  }

  static final AppDatabase _database = AppDatabase(NativeDatabase.memory());

  _FakeTripRestrictionStore._(super.database, {required this.dataIsStale});

  final bool dataIsStale;
  final loadedJurisdictions = <String>[];

  @override
  Future<RestrictionRuleSet> loadCoverage(
    String jurisdictionId,
    VehicleKind vehicleKind,
    VehicleServiceType serviceType,
    DateTime now,
  ) async {
    loadedJurisdictions.add(jurisdictionId);
    if (jurisdictionId != 'co-dc-bogota') {
      return const RestrictionRuleSet(
        coverageKnown: false,
        dataIsStale: false,
        rules: [],
      );
    }
    return RestrictionRuleSet(
      coverageKnown: true,
      dataIsStale: dataIsStale,
      rules: [
        RestrictionRule(
          id: 'bogota-test-rule',
          jurisdictionId: jurisdictionId,
          priority: 100,
          effect: RestrictionEffect.restrict,
          validFrom: DateTime(2026),
          vehicleKinds: const {VehicleKind.car},
          serviceTypes: const {VehicleServiceType.private},
          weekdays: const {DateTime.saturday},
          digitPosition: RestrictionDigitPosition.lastNumeric,
          digits: const {3},
          timeWindows: const [
            RestrictionTimeWindow(startMinute: 360, endMinute: 540),
          ],
          appliesOnHolidays: true,
        ),
      ],
      verifiedAt: DateTime(2026, 9, 1),
      staleAfter: DateTime.utc(2026, 10, 1, 5),
      sourceUrls: const ['https://example.test/bogota-source'],
    );
  }

  Future<void> dispose() async {}

  static Future<void> closeDatabase() => _database.close();
}

class _DelayedPreferences extends MemoryPreferences {
  Completer<void>? _loadGate;
  Completer<void>? _saveGate;
  Completer<void>? _removeGate;

  void pauseLoad() {
    _loadGate = Completer<void>();
  }

  void completeLoad() {
    _loadGate?.complete();
  }

  void pauseSave() {
    _saveGate = Completer<void>();
  }

  void completeSave() {
    _saveGate?.complete();
  }

  void pauseRemove() {
    _removeGate = Completer<void>();
  }

  void completeRemove() {
    _removeGate?.complete();
  }

  @override
  Future<String?> getString(String key) async {
    final gate = _loadGate;
    if (gate != null) {
      await gate.future;
    }
    return super.getString(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    final gate = _saveGate;
    if (gate != null) {
      await gate.future;
    }
    return super.setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    final gate = _removeGate;
    if (gate != null) {
      await gate.future;
    }
    return super.remove(key);
  }
}

class _FailingReadPreferences extends MemoryPreferences {
  var throwOnRead = true;

  @override
  Future<String?> getString(String key) async {
    if (throwOnRead && key == tripDraftPreferenceKey) {
      throw StateError('test read failure');
    }
    return super.getString(key);
  }
}
