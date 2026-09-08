import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/shell/app_shell.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/core/design_system/navigation.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/garage/data/vehicle_repository.dart';
import 'package:picoradar/features/driving/domain/traffic_camera.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_rule.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_day_evaluation.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_engine.dart';
import 'package:picoradar/features/trip/data/trip_draft_store.dart';
import 'package:picoradar/features/trip/application/trip_route_association_resolver.dart';
import 'package:picoradar/features/trip/application/trip_route_associations.dart';
import 'package:picoradar/features/trip/application/trip_services.dart';
import 'package:picoradar/features/trip/data/trip_plan_client.dart';
import 'package:picoradar/features/trip/data/toll_inventory.dart';
import 'package:picoradar/features/trip/data/toll_tariff_catalog.dart';
import 'package:picoradar/features/trip/data/trip_route_preview_data.dart';
import 'package:picoradar/features/trip/domain/trip_plan.dart';
import 'package:picoradar/features/trip/data/trip_municipality_catalog.dart';
import 'package:picoradar/features/trip/domain/trip_draft.dart';
import 'package:picoradar/features/trip/presentation/trip_screen.dart';
import 'package:picoradar/features/trip/presentation/trip_route_preview_map.dart';
import 'package:picoradar/features/vehicle_status/platform/external_launcher.dart';

import '../../../test_app_harness.dart';

late TripMunicipalityCatalog _tripCatalog;
late TollTariffCatalog _tollTariffCatalog;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemoryPreferences preferences;
  late _FakeExternalLauncher launcher;

  setUpAll(() async {
    final raw = await rootBundle.loadString(tripMunicipalityCatalogAssetPath);
    _tripCatalog = TripMunicipalityCatalog.fromJson(
      jsonDecode(raw) as Map<String, Object?>,
    );
    _tollTariffCatalog = TollTariffCatalog.fromJsonString(
      File('assets/catalogs/tolls_tariffs_v1.json').readAsStringSync(),
    );
  });

  tearDownAll(_FakeTripRestrictionStore.closeDatabase);

  testWidgets('VIAJE-R1 exposes an explicit plan CTA', (tester) async {
    await _pumpScreen(tester, preferences: preferences);
    expect(find.text('Ver plan de viaje'), findsOneWidget);
  });

  testWidgets('toll tariffs are searchable before route provider is used', (
    tester,
  ) async {
    await _pumpScreen(tester, preferences: preferences);
    final search = find.byKey(const ValueKey('trip-toll-tariff-query'));
    await tester.ensureVisible(search);
    await tester.pumpAndSettle();

    await tester.enterText(search, 'guarne');
    await tester.pumpAndSettle();

    expect(find.text('Tarifas propias de peajes'), findsOneWidget);
    expect(find.text('GUARNE'), findsOneWidget);
    expect(find.textContaining(r'Cat I: $18.500'), findsOneWidget);
    expect(find.textContaining('No requiere TollGuru'), findsOneWidget);
  });

  testWidgets(
    'VIAJE-R2C keeps preparation grouped and the CTA before secondary content',
    (tester) async {
      await TripDraftStore(preferences).saveDraft(
        TripDraft(
          origin: 'Bogota',
          destination: 'Medellin',
          date: DateTime(2026, 9, 7),
          departureMinute: 600,
        ),
      );
      await _pumpScreen(
        tester,
        preferences: preferences,
        activeVehicle: _vehicle(),
        size: const Size(360, 800),
      );

      final locationGroup = find.byKey(const ValueKey('trip-location-group'));
      final departureGroup = find.byKey(const ValueKey('trip-departure-group'));
      final preview = find.byKey(const ValueKey('trip-preview'));
      final secondaryContent = find.text('Pico y placa del viaje');

      expect(locationGroup, findsOneWidget);
      expect(
        find.descendant(
          of: locationGroup,
          matching: find.byKey(const ValueKey('trip-swap-locations')),
        ),
        findsOneWidget,
      );
      expect(departureGroup, findsOneWidget);
      for (final key in const [
        'trip-date-button',
        'trip-time-button',
        'trip-select-vehicle',
      ]) {
        expect(
          find.descendant(
            of: departureGroup,
            matching: find.byKey(ValueKey(key)),
          ),
          findsOneWidget,
        );
      }
      expect(
        tester.getTopLeft(preview).dy,
        greaterThan(tester.getTopLeft(departureGroup).dy),
      );
      expect(
        tester.getTopLeft(preview).dy,
        lessThan(tester.getTopLeft(secondaryContent).dy),
      );
      await tester.ensureVisible(preview);
      await tester.pumpAndSettle();
      expect(preview.hitTestable(), findsOneWidget);
      await tester.tap(preview);
      await tester.pumpAndSettle();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        isNot('trip-vehicle-focus'),
      );
    },
  );

  testWidgets(
    'VIAJE-R2C keeps initial CTA above floating shell nav at 360x800',
    (tester) async {
      await TripDraftStore(preferences).saveDraft(
        TripDraft(
          origin: 'Bogotá',
          destination: 'Medellín',
          date: DateTime(2026, 9, 7),
          departureMinute: 600,
        ),
      );
      await _pumpScreen(
        tester,
        preferences: preferences,
        activeVehicle: _vehicle(),
        size: const Size(360, 800),
        shellOverlay: Align(
          alignment: Alignment.bottomCenter,
          child: _testBottomNav(),
        ),
      );

      final preview = find.byKey(const ValueKey('trip-preview'));
      final bottomNav = find.byKey(const ValueKey('app-bottom-navigation'));

      expect(preview.hitTestable(), findsOneWidget);
      expect(
        tester.getRect(preview).bottom,
        lessThanOrEqualTo(tester.getRect(bottomNav).top),
      );

      await tester.tap(preview);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final mode in ['false', 'throw', 'unsafe']) {
    testWidgets('Viaje source handoff handles $mode safely', (tester) async {
      final sourceLauncher = _FakeExternalLauncher()
        ..openResult = false
        ..throwOnOpen = mode == 'throw';
      await TripDraftStore(preferences).saveDraft(
        TripDraft(
          origin: 'Bogotá',
          destination: 'Medellín',
          date: DateTime(2026, 9, 7),
          departureMinute: 600,
        ),
      );
      await _pumpScreen(
        tester,
        preferences: preferences,
        activeVehicle: _vehicle(),
        launcher: sourceLauncher,
        instantRestriction: (_) => TripEndpointRestriction(
          status: RestrictionDayStatus.unknown,
          sourceUrl: mode == 'unsafe'
              ? 'http://example.test'
              : 'https://example.test/rules',
        ),
      );
      final source = find.text('Consultar fuente').first;
      await tester.ensureVisible(source);
      await tester.pumpAndSettle();
      expect(source.hitTestable(), findsOneWidget);
      await tester.tap(source);
      await tester.pumpAndSettle();
      expect(
        find.text(
          mode == 'unsafe'
              ? 'Fuente no disponible.'
              : 'No pudimos abrir la fuente.',
        ),
        findsOneWidget,
      );
      if (mode == 'unsafe' || mode == 'throw') {
        expect(sourceLauncher.opened, isEmpty);
      } else {
        expect(sourceLauncher.opened, ['https://example.test/rules']);
      }
    });
  }

  testWidgets('both real local sections expire without a paid consultation', (
    tester,
  ) async {
    var clock = DateTime.utc(2026, 10, 1, 4, 59, 58);
    final client = _PendingPlanClient();
    await TripDraftStore(preferences).saveDraft(
      TripDraft(
        origin: 'Bogotá',
        destination: 'Medellín',
        date: DateTime(2026, 9, 7),
        departureMinute: 600,
      ),
    );
    await _pumpScreen(
      tester,
      preferences: preferences,
      activeVehicle: _vehicle(),
      planClient: client,
      restrictionClock: () => clock,
    );
    expect(find.text('Sin restricción a la hora evaluada'), findsOneWidget);
    expect(find.textContaining('Sin restricción para ese día'), findsOneWidget);
    clock = DateTime.utc(2026, 10, 1, 5);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Sin restricción a la hora evaluada'), findsNothing);
    expect(find.textContaining('Sin restricción para ese día'), findsNothing);
    expect(client.requests, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.textContaining('Sin restricción para ese día'), findsNothing);
    expect(find.text('Sin restricción a la hora evaluada'), findsNothing);
    expect(client.requests, isEmpty);
  });

  setUp(() {
    preferences = MemoryPreferences();
    launcher = _FakeExternalLauncher();
  });

  testWidgets('VIAJE DEMO is gated by dart-define and keeps visible labels', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      preferences: preferences,
      activeVehicle: _vehicle(),
      launcher: launcher,
      size: const Size(390, 1000),
    );

    if (!tripDemoEnabled) {
      expect(
        find.byKey(const ValueKey('trip-demo-medellinBogota')),
        findsNothing,
      );
      expect(find.text(tripDemoWarningLabel), findsNothing);
      return;
    }

    expect(
      find.byKey(const ValueKey('trip-demo-medellinBogota')),
      findsOneWidget,
    );
    expect(find.text(tripDemoWarningLabel), findsWidgets);

    await _tapByKey(tester, 'trip-demo-medellinBogota');
    _pressButtonByKey(tester, 'trip-preview');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('trip-plan-result')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('trip-demo-result-banner')),
      findsOneWidget,
    );
    expect(find.text('Ruta DEMO Magdalena Medio'), findsOneWidget);
    expect(find.text('Ruta DEMO La Pintada'), findsOneWidget);
    expect(find.byType(TripRoutePreviewMap), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-demo-map-banner')), findsOneWidget);

    await _tapByKey(tester, 'trip-open-google-maps');
    expect(find.text('DEMO: navegación externa desactivada.'), findsOneWidget);
    await _tapByKey(tester, 'trip-open-waze');
    expect(launcher.opened, isEmpty);

    await _tapByKey(tester, 'trip-demo-unknownCoverage');
    _pressButtonByKey(tester, 'trip-preview');
    await tester.pumpAndSettle();

    expect(find.text('Ruta DEMO con cobertura incierta'), findsOneWidget);
    expect(find.text('Alternativa DEMO sin tarifa verificada'), findsOneWidget);
    expect(find.textContaining('Por confirmar'), findsWidgets);
    expect(
      find.byKey(const ValueKey('trip-demo-result-banner')),
      findsOneWidget,
    );
  });

  testWidgets(
    'VIAJE-R1 review6 resume refreshes both local endpoints without paid call',
    (tester) async {
      final client = _PendingPlanClient();
      var expired = false;
      await TripDraftStore(preferences).saveDraft(
        TripDraft(
          origin: 'Bogotá',
          destination: 'Medellín',
          date: DateTime(2026, 9, 5),
          departureMinute: 600,
        ),
      );
      await _pumpScreen(
        tester,
        preferences: preferences,
        activeVehicle: _vehicle(),
        planClient: client,
        instantRestriction: (_) => TripEndpointRestriction(
          status: expired
              ? RestrictionDayStatus.stale
              : RestrictionDayStatus.allowed,
          instantStatus: expired
              ? RestrictionStatus.stale
              : RestrictionStatus.allowed,
          reason: expired ? 'stale_data' : null,
        ),
      );
      await _tapByKey(tester, 'trip-standard-vehicle');
      _pressButtonByKey(tester, 'trip-preview');
      await tester.pump();
      client.completions.single.complete(_testPlan(client.requests.single));
      await tester.pumpAndSettle();
      expect(find.text('Sin restricción a la hora evaluada'), findsNWidgets(2));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expired = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(client.requests, hasLength(1));
      expect(find.text('Sin restricción a la hora evaluada'), findsNothing);
      expect(find.text('Información desactualizada'), findsNWidgets(2));
      expect(find.byKey(const ValueKey('trip-plan-result')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(client.requests, hasLength(1));
    },
  );

  testWidgets(
    'VIAJE-R1 review6 explicit reconsult refreshes local status only on CTA',
    (tester) async {
      final client = _PendingPlanClient();
      var expired = false;
      await TripDraftStore(preferences).saveDraft(
        TripDraft(
          origin: 'Bogotá',
          destination: 'Medellín',
          date: DateTime(2026, 9, 5),
          departureMinute: 600,
        ),
      );
      await _pumpScreen(
        tester,
        preferences: preferences,
        activeVehicle: _vehicle(),
        planClient: client,
        instantRestriction: (_) => TripEndpointRestriction(
          status: expired
              ? RestrictionDayStatus.stale
              : RestrictionDayStatus.allowed,
          instantStatus: expired
              ? RestrictionStatus.stale
              : RestrictionStatus.allowed,
          reason: expired ? 'stale_data' : null,
        ),
      );
      await _tapByKey(tester, 'trip-standard-vehicle');
      _pressButtonByKey(tester, 'trip-preview');
      await tester.pump();
      client.completions.single.completeError(const TripPlanFailure('network'));
      await tester.pumpAndSettle();
      expect(find.text('Sin restricción a la hora evaluada'), findsOneWidget);
      expired = true;
      await tester.pump();
      expect(client.requests, hasLength(1));
      _pressButtonByKey(tester, 'trip-preview');
      await tester.pump();
      expect(client.requests, hasLength(2));
      client.completions.last.completeError(const TripPlanFailure('network'));
      await tester.pumpAndSettle();
      expect(find.text('Sin restricción a la hora evaluada'), findsNothing);
      expect(find.text('Información desactualizada'), findsOneWidget);
    },
  );

  testWidgets(
    'VIAJE-R1 review10 departure window error preserves selected date and time',
    (tester) async {
      final client = _PendingPlanClient();
      await TripDraftStore(preferences).saveDraft(
        TripDraft(
          origin: 'Bogotá',
          destination: 'Medellín',
          date: DateTime(2026, 9, 5),
          departureMinute: 600,
        ),
      );
      await _pumpScreen(
        tester,
        preferences: preferences,
        activeVehicle: _vehicle(),
        planClient: client,
      );
      await _tapByKey(tester, 'trip-standard-vehicle');
      _pressButtonByKey(tester, 'trip-preview');
      await tester.pump();
      client.completions.single.completeError(
        const TripPlanFailure('departure_window', maxFutureDays: 7),
      );
      await tester.pumpAndSettle();
      final error = find.text(
        'Elige una salida futura dentro de los próximos 7 días.',
      );
      expect(error, findsOneWidget);
      expect(
        find.ancestor(of: error, matching: find.byType(Form)),
        findsOneWidget,
      );
      expect(find.text('Fecha · 2026-09-05'), findsOneWidget);
      expect(find.text('Hora de salida · 10:00'), findsOneWidget);
      expect(client.requests.single.departureUtc, DateTime.utc(2026, 9, 5, 15));
      expect(find.byKey(const ValueKey('trip-origin-instant')), findsOneWidget);
      expect(
        find.text('No pudimos conectar. Puedes volver a consultar.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'VIAJE-R1 immutable request single flight cancel and stale response',
    (tester) async {
      final client = _PendingPlanClient();
      await TripDraftStore(preferences).saveDraft(
        TripDraft(
          origin: 'Bogotá',
          destination: 'Medellín',
          date: DateTime(2026, 9, 5),
          departureMinute: 1410,
        ),
      );
      await _pumpScreen(
        tester,
        preferences: preferences,
        activeVehicle: _vehicle(),
        planClient: client,
      );
      expect(client.requests, isEmpty);
      await _tapByKey(tester, 'trip-standard-vehicle');
      _pressButtonByKey(tester, 'trip-preview');
      _pressButtonByKey(tester, 'trip-preview');
      await tester.pump();
      expect(client.requests, hasLength(1));
      expect(
        client.requests.single.departureUtc,
        DateTime.utc(2026, 9, 6, 4, 30),
      );
      expect(client.requests.single.origin.code, '11001');
      await tester.enterText(
        find.byKey(const ValueKey('trip-destination-field')),
        'Cali',
      );
      await tester.pump();
      expect(client.tokens.single!.isCancelled, isTrue);
      expect(client.requests.single.destination.municipality, 'Medellín');
      client.completions.single.complete(_testPlan(client.requests.single));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('trip-plan-result')), findsNothing);
      _pressButtonByKey(tester, 'trip-preview');
      await tester.pump();
      expect(client.requests, hasLength(1));
      expect(
        find.text('Elige municipio y departamento de las sugerencias.'),
        findsOneWidget,
      );
      final cali = find.descendant(
        of: find.byKey(const ValueKey('trip-destination-suggestions')),
        matching: find.text('Santiago de Cali · Valle del Cauca'),
      );
      await tester.ensureVisible(cali);
      await tester.tap(cali);
      await tester.pumpAndSettle();
      _pressButtonByKey(tester, 'trip-preview');
      await tester.pump();
      expect(client.requests, hasLength(2));
      _pressButtonByKey(tester, 'trip-cancel-preview');
      await tester.pump();
      expect(client.tokens.last!.isCancelled, isTrue);
      client.completions.last.complete(_testPlan(client.requests.last));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('trip-plan-result')), findsNothing);
    },
  );

  testWidgets(
    'VIAJE-R1 network error keeps local origin and no arrival verdict',
    (tester) async {
      final client = _PendingPlanClient();
      await TripDraftStore(preferences).saveDraft(
        TripDraft(
          origin: 'Bogotá',
          destination: 'Medellín',
          date: DateTime(2026, 9, 5),
          departureMinute: 600,
        ),
      );
      await _pumpScreen(
        tester,
        preferences: preferences,
        activeVehicle: _vehicle(),
        planClient: client,
      );
      await _tapByKey(tester, 'trip-standard-vehicle');
      _pressButtonByKey(tester, 'trip-preview');
      await tester.pump();
      client.completions.single.completeError(const TripPlanFailure('network'));
      await tester.pumpAndSettle();
      expect(
        find.text('No pudimos conectar. Puedes volver a consultar.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('trip-origin-instant')), findsOneWidget);
      expect(
        find.text('Destino / llegada: no disponible hasta obtener una ruta.'),
        findsOneWidget,
      );
      expect(client.requests, hasLength(1));
    },
  );

  testWidgets('VIAJE-R1 dispose cancels pending preview', (tester) async {
    final client = _PendingPlanClient();
    await TripDraftStore(preferences).saveDraft(
      TripDraft(
        origin: 'Bogotá',
        destination: 'Medellín',
        date: DateTime(2026, 9, 5),
        departureMinute: 600,
      ),
    );
    await _pumpScreen(
      tester,
      preferences: preferences,
      activeVehicle: _vehicle(),
      planClient: client,
    );
    await _tapByKey(tester, 'trip-standard-vehicle');
    _pressButtonByKey(tester, 'trip-preview');
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(client.tokens.single!.isCancelled, isTrue);
    client.completions.single.complete(_testPlan(client.requests.single));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('today without a time captures now once on preview', (
    tester,
  ) async {
    final client = _PendingPlanClient();
    final today = DateTime.now();
    await TripDraftStore(preferences).saveDraft(
      TripDraft(
        origin: 'Bogotá',
        destination: 'Medellín',
        date: DateTime(today.year, today.month, today.day),
      ),
    );
    await _pumpScreen(
      tester,
      preferences: preferences,
      activeVehicle: _vehicle(),
      planClient: client,
    );
    final before = DateTime.now().toUtc();
    _pressButtonByKey(tester, 'trip-preview');
    await tester.pump();
    final after = DateTime.now().toUtc();

    expect(client.requests, hasLength(1));
    final json = client.requests.single.toJson();
    expect(json['departureMode'], 'now');
    expect(json['departureUtc'], isNotNull);
    final captured = DateTime.parse(json['departureUtc']! as String);
    expect(captured.isBefore(before), isFalse);
    expect(captured.isAfter(after), isFalse);
    expect(find.text('Salida: ahora'), findsOneWidget);
  });

  testWidgets('future date without time is allowed and has no exact arrival', (
    tester,
  ) async {
    final client = _PendingPlanClient();
    final future = DateTime.now().add(const Duration(days: 2));
    await TripDraftStore(preferences).saveDraft(
      TripDraft(
        origin: 'Bogotá',
        destination: 'Medellín',
        date: DateTime(future.year, future.month, future.day),
      ),
    );
    await _pumpScreen(
      tester,
      preferences: preferences,
      activeVehicle: _vehicle(),
      planClient: client,
    );
    _pressButtonByKey(tester, 'trip-preview');
    await tester.pump();

    expect(client.requests, hasLength(1));
    expect(client.requests.single.toJson()['departureMode'], 'date_only');
    expect(client.requests.single.toJson()['departureUtc'], isNull);
    expect(find.text('Hora opcional · Sin definir'), findsWidgets);
    expect(find.textContaining('Llegada:'), findsNothing);
  });

  testWidgets('chosen time can be cleared without blocking preview', (
    tester,
  ) async {
    final client = _PendingPlanClient();
    final future = DateTime.now().add(const Duration(days: 2));
    await TripDraftStore(preferences).saveDraft(
      TripDraft(
        origin: 'Bogotá',
        destination: 'Medellín',
        date: DateTime(future.year, future.month, future.day),
        departureMinute: 600,
      ),
    );
    await _pumpScreen(
      tester,
      preferences: preferences,
      activeVehicle: _vehicle(),
      planClient: client,
    );

    await _tapByKey(tester, 'trip-clear-time');
    expect(find.text('Hora opcional · Sin definir'), findsOneWidget);
    _pressButtonByKey(tester, 'trip-preview');
    await tester.pump();
    expect(client.requests.single.toJson()['departureMode'], 'date_only');
  });

  testWidgets('particular defaults to 2 axes without physical confirmation', (
    tester,
  ) async {
    final client = _PendingPlanClient();
    final future = DateTime.now().add(const Duration(days: 2));
    await TripDraftStore(preferences).saveDraft(
      TripDraft(
        origin: 'Bogotá',
        destination: 'Medellín',
        date: DateTime(future.year, future.month, future.day),
      ),
    );
    await _pumpScreen(
      tester,
      preferences: preferences,
      activeVehicle: _vehicle(),
      planClient: client,
    );

    expect(find.text('Particular · 2 ejes'), findsOneWidget);
    expect(find.text('Opciones del vehículo'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNWidgets(4));
    _pressButtonByKey(tester, 'trip-preview');
    await tester.pump();
    expect(client.requests, hasLength(1));
    expect(client.requests.single.vehicleCategory, 'car');
  });

  testWidgets('unsupported configuration keeps local consultation available', (
    tester,
  ) async {
    final client = _PendingPlanClient();
    final future = DateTime.now().add(const Duration(days: 2));
    await TripDraftStore(preferences).saveDraft(
      TripDraft(
        origin: 'Bogotá',
        destination: 'Medellín',
        date: DateTime(future.year, future.month, future.day),
      ),
    );
    await _pumpScreen(
      tester,
      preferences: preferences,
      activeVehicle: _vehicle(),
      planClient: client,
    );

    await _tapByKey(tester, 'trip-vehicle-options');
    await tester.tap(find.text('Remolque o configuración distinta'));
    await tester.pumpAndSettle();
    _pressButtonByKey(tester, 'trip-preview');
    await tester.pumpAndSettle();

    expect(client.requests, isEmpty);
    expect(find.text('Lo que ya podemos consultar'), findsOneWidget);
    expect(find.text('Rutas y precios todavía no disponibles'), findsOneWidget);
    expect(find.textContaining('Tarifas no soportadas'), findsOneWidget);
  });

  testWidgets(
    'advanced vehicle configuration restored from draft is not reset on first build',
    (tester) async {
      final vehicle = _vehicle(id: 'vehicle-a', plate: 'ABC123');
      await TripDraftStore(preferences).saveDraft(
        TripDraft(
          origin: 'Bogotá',
          destination: 'Medellín',
          date: DateTime(2026, 9, 7),
          activeVehicleId: vehicle.id,
          vehicleConfiguration: TripVehicleConfiguration.unsupported,
          vehicleCategorySource: TripVehicleCategorySource.userSelected,
        ),
      );

      await _pumpScreen(
        tester,
        preferences: preferences,
        activeVehicle: vehicle,
        vehicles: [vehicle],
        size: const Size(390, 1000),
      );

      expect(find.text('Configuración no soportada'), findsOneWidget);
      _pressButtonByKey(tester, 'trip-preview');
      await tester.pumpAndSettle();

      final restored = await TripDraftStore(preferences).loadDraft();
      expect(
        restored?.vehicleConfiguration,
        TripVehicleConfiguration.unsupported,
      );
      expect(
        restored?.vehicleCategorySource,
        TripVehicleCategorySource.userSelected,
      );
      expect(
        find.text('Rutas y precios todavía no disponibles'),
        findsOneWidget,
      );
    },
  );

  testWidgets('not configured keeps useful local result visible', (
    tester,
  ) async {
    final client = _PendingPlanClient();
    final future = DateTime.now().add(const Duration(days: 2));
    await TripDraftStore(preferences).saveDraft(
      TripDraft(
        origin: 'Bogotá',
        destination: 'Medellín',
        date: DateTime(future.year, future.month, future.day),
      ),
    );
    await _pumpScreen(
      tester,
      preferences: preferences,
      activeVehicle: _vehicle(),
      planClient: client,
    );
    _pressButtonByKey(tester, 'trip-preview');
    await tester.pump();
    client.completions.single.completeError(
      const TripPlanFailure('not_configured'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lo que ya podemos consultar'), findsOneWidget);
    expect(find.text('Rutas y precios todavía no disponibles'), findsOneWidget);
    expect(find.textContaining('Origen'), findsWidgets);
    expect(find.textContaining('Destino'), findsWidgets);
  });

  testWidgets('VIAJE-R2 route selection updates locally without auto-scroll', (
    tester,
  ) async {
    final client = _PendingPlanClient();
    await TripDraftStore(preferences).saveDraft(
      TripDraft(
        origin: 'Bogotá',
        destination: 'Medellín',
        date: DateTime(2026, 9, 5),
        departureMinute: 1410,
      ),
    );
    await _pumpScreen(
      tester,
      preferences: preferences,
      activeVehicle: _vehicle(),
      planClient: client,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TripScreen)),
    );
    await _tapByKey(tester, 'trip-standard-vehicle');
    _pressButtonByKey(tester, 'trip-preview');
    await tester.pump();
    final request = client.requests.single;
    final first = _testPlan(request);
    client.completions.single.complete(
      TripPlan(
        requestId: first.requestId,
        generatedAtUtc: first.generatedAtUtc,
        provider: first.provider,
        attribution: first.attribution,
        origin: first.origin,
        destination: first.destination,
        routes: [
          first.routes.single,
          TripRouteOption(
            id: 'slow',
            summary: 'Ruta lenta',
            distanceMeters: 600000,
            durationSeconds: 43200,
            timeBasis: 'static',
            tolls: TripTolls(
              coverage: TripTollCoverage.unknown,
              vehicleCategory: 'car',
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('trip-destination-instant-test-route')),
      findsOneWidget,
    );
    final routeButton = find.byKey(const ValueKey('trip-select-route-slow'));
    await tester.ensureVisible(routeButton);
    await tester.pumpAndSettle();
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    final offsetBeforeSelection = scrollable.position.pixels;
    _pressButtonByKey(tester, 'trip-select-route-slow');
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, offsetBeforeSelection);
    expect(
      find.byKey(const ValueKey('trip-destination-instant-test-route')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('trip-destination-instant-slow')),
      findsOneWidget,
    );
    final evaluation = await container.read(
      tripInstantRestrictionProvider((
        municipality: request.destination,
        vehicle: request.vehicle,
        instantUtc: DateTime.utc(2026, 9, 6, 16, 30),
      )).future,
    );
    expect(evaluation.evaluatedAtUtc, DateTime.utc(2026, 9, 6, 16, 30));
    expect(client.requests, hasLength(1));
    expect(
      find.byKey(const ValueKey('trip-toll-details-slow')),
      findsOneWidget,
    );
  });

  testWidgets('VIAJE-R1 mismatched request ID cannot become current plan', (
    tester,
  ) async {
    final client = _PendingPlanClient();
    await TripDraftStore(preferences).saveDraft(
      TripDraft(
        origin: 'Bogotá',
        destination: 'Medellín',
        date: DateTime(2026, 9, 5),
        departureMinute: 600,
      ),
    );
    await _pumpScreen(
      tester,
      preferences: preferences,
      activeVehicle: _vehicle(),
      planClient: client,
    );
    await _tapByKey(tester, 'trip-standard-vehicle');
    _pressButtonByKey(tester, 'trip-preview');
    await tester.pump();
    final request = client.requests.single;
    client.completions.single.complete(
      _testPlan(
        TripPlanRequest(
          requestId: 'different',
          origin: request.origin,
          destination: request.destination,
          vehicle: request.vehicle,
          departureUtc: request.departureUtc,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('trip-plan-result')), findsNothing);
    expect(
      find.textContaining('no devolvió un plan verificable'),
      findsOneWidget,
    );
  });

  testWidgets('VIAJE-R1 validates exact municipalities and same city inline', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      preferences: preferences,
      activeVehicle: _vehicle(),
    );
    await tester.enterText(
      find.byKey(const ValueKey('trip-origin-field')),
      'Barbosa',
    );
    await tester.enterText(
      find.byKey(const ValueKey('trip-destination-field')),
      'xyz',
    );
    await _tapByKey(tester, 'trip-preview');
    expect(
      find.text('Elige municipio y departamento de las sugerencias.'),
      findsNWidgets(2),
    );
    await tester.enterText(
      find.byKey(const ValueKey('trip-origin-field')),
      'Bogotá',
    );
    await tester.enterText(
      find.byKey(const ValueKey('trip-destination-field')),
      'bogota',
    );
    await _tapByKey(tester, 'trip-preview');
    expect(
      find.text('Elige otro municipio: no se ha definido un trayecto urbano.'),
      findsOneWidget,
    );
  });

  for (final size in [
    const Size(360, 780),
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915),
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('VIAJE-R1 CTA with keyboard $size scale $scale', (
        tester,
      ) async {
        await _pumpScreen(
          tester,
          preferences: preferences,
          size: size,
          textScale: scale,
        );
        await tester.showKeyboard(
          find.byKey(const ValueKey('trip-destination-field')),
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await tester.pump();
        expect(
          MediaQuery.viewInsetsOf(tester.element(find.byType(TripScreen)))
              .bottom,
          300,
        );
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
    expect(
      find.text('Selecciona un vehículo para consultar el plan.'),
      findsOneWidget,
    );
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
      store.loadedJurisdictions.toSet(),
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

  testWidgets('initial target responsive viewports avoid overflow', (
    tester,
  ) async {
    for (final size in const [
      Size(360, 780),
      Size(360, 800),
      Size(390, 844),
      Size(412, 915),
    ]) {
      for (final scale in const [1.0, 1.5, 2.0]) {
        await _pumpScreen(
          tester,
          preferences: preferences,
          size: size,
          textScale: scale,
        );

        expect(find.byKey(const ValueKey('trip-screen')), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('VIAJE-R2 integrated success covers the 4 x 3 matrix', (
    tester,
  ) async {
    for (final size in const [
      Size(360, 780),
      Size(360, 800),
      Size(390, 844),
      Size(412, 915),
    ]) {
      for (final scale in const [1.0, 1.5, 2.0]) {
        final casePreferences = MemoryPreferences();
        final client = _PendingPlanClient();
        await TripDraftStore(casePreferences).saveDraft(
          TripDraft(
            origin: 'Bogotá',
            destination: 'Medellín',
            date: DateTime(2026, 9, 7),
            departureMinute: 600,
          ),
        );
        final keyboardCase = size == const Size(360, 780) && scale == 2.0;
        tester.view.padding = keyboardCase
            ? const FakeViewPadding(top: 24, bottom: 16)
            : FakeViewPadding.zero;
        await _pumpScreen(
          tester,
          preferences: casePreferences,
          activeVehicle: _vehicle(),
          planClient: client,
          size: size,
          textScale: scale,
        );
        await _tapByKey(tester, 'trip-standard-vehicle');
        _pressButtonByKey(tester, 'trip-preview');
        await tester.pump();
        client.completions.single.complete(
          _testPlanWithTwoRoutes(client.requests.single),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('trip-screen')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('trip-preparation-summary')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('trip-plan-result')), findsOneWidget);
        const metricKeys = [
          'distance',
          'duration',
          'arrival',
          'tolls',
          'cost',
          'cameras',
        ];
        for (final metric in metricKeys) {
          expect(find.byKey(ValueKey('trip-summary-$metric')), findsOneWidget);
        }
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('trip-summary-cameras')),
            matching: find.text('Por confirmar'),
          ),
          findsOneWidget,
        );
        final metricRects = [
          for (final metric in metricKeys)
            tester.getRect(find.byKey(ValueKey('trip-summary-$metric'))),
        ];
        if (scale == 2) {
          expect(metricRects.map((rect) => rect.left).toSet(), hasLength(1));
          for (var index = 1; index < metricRects.length; index += 1) {
            expect(
              metricRects[index].top,
              greaterThan(metricRects[index - 1].bottom),
            );
          }
        } else {
          expect(metricRects[0].left, closeTo(metricRects[2].left, 0.01));
          expect(metricRects[0].left, closeTo(metricRects[4].left, 0.01));
          expect(metricRects[1].left, closeTo(metricRects[3].left, 0.01));
          expect(metricRects[1].left, closeTo(metricRects[5].left, 0.01));
          expect(metricRects[0].top, closeTo(metricRects[1].top, 0.01));
          expect(metricRects[2].top, closeTo(metricRects[3].top, 0.01));
          expect(metricRects[4].top, closeTo(metricRects[5].top, 0.01));
        }

        final firstRoute = find.byKey(const ValueKey('trip-route-test-route'));
        final secondRoute = find.byKey(const ValueKey('trip-route-scenic'));
        final firstRect = tester.getRect(firstRoute);
        final secondRect = tester.getRect(secondRoute);
        expect(firstRect.left, closeTo(secondRect.left, 0.01));
        expect(firstRect.width, closeTo(secondRect.width, 0.01));
        expect(
          firstRect.width,
          closeTo(
            tester
                .getSize(find.byKey(const ValueKey('trip-plan-result')))
                .width,
            0.01,
          ),
        );
        expect(firstRect.bottom, lessThan(secondRect.top));
        final mapRect = tester.getRect(
          find.byKey(const ValueKey('trip-map-preview-slot')),
        );
        final tollRect = tester.getRect(
          find.byKey(const ValueKey('trip-toll-details-test-route')),
        );
        expect(secondRect.bottom, lessThan(mapRect.top));
        expect(mapRect.bottom, lessThanOrEqualTo(tollRect.top));

        await tester.ensureVisible(
          find.byKey(const ValueKey('trip-view-map-test-route')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('trip-view-map-test-route')).hitTestable(),
          findsOneWidget,
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('trip-preparation-compact')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('trip-preparation-compact')).hitTestable(),
          findsOneWidget,
        );

        if (keyboardCase) {
          await _tapByKey(tester, 'trip-preparation-compact');
          await tester.showKeyboard(
            find.byKey(const ValueKey('trip-destination-field')),
          );
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.byKey(const ValueKey('trip-destination-field')),
          );
          await tester.pumpAndSettle();
          expect(
            FocusManager.instance.primaryFocus?.debugLabel,
            'trip-destination-focus',
          );
          expect(
            find.byKey(const ValueKey('trip-destination-field')).hitTestable(),
            findsOneWidget,
          );
          expect(
            tester.getTopLeft(find.byKey(const ValueKey('trip-screen'))).dy,
            greaterThanOrEqualTo(24),
          );
          tester.view.resetViewInsets();
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        tester.view.resetPadding();
      }
    }
  });

  for (final invalidField in const [
    (name: 'origin', focus: 'trip-origin-focus', key: 'trip-origin-field'),
    (
      name: 'destination',
      focus: 'trip-destination-focus',
      key: 'trip-destination-field',
    ),
    (name: 'vehicle', focus: 'trip-vehicle-focus', key: 'trip-select-vehicle'),
  ]) {
    testWidgets(
      'VIAJE-R2 focuses and reveals first invalid ${invalidField.name}',
      (tester) async {
        final casePreferences = MemoryPreferences();
        if (invalidField.name != 'origin') {
          await TripDraftStore(casePreferences).saveDraft(
            TripDraft(
              origin: 'Bogotá',
              destination: 'Medellín',
              date: DateTime(2026, 9, 7),
              departureMinute: invalidField.name == 'time' ? null : 600,
            ),
          );
        }
        final vehicle = _vehicle();
        await _pumpScreen(
          tester,
          preferences: casePreferences,
          activeVehicle: invalidField.name == 'vehicle' ? null : vehicle,
          vehicles: [vehicle],
          size: const Size(360, 780),
          textScale: 2,
        );
        if (invalidField.name == 'destination') {
          await tester.enterText(
            find.byKey(const ValueKey('trip-destination-field')),
            '',
          );
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        }

        await _tapByKey(tester, 'trip-preview');

        expect(
          FocusManager.instance.primaryFocus?.debugLabel,
          invalidField.focus,
        );
        expect(
          find.byKey(ValueKey(invalidField.key)).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
      },
    );
  }

  testWidgets(
    'VIAJE-R2 focuses the first invalid field and swaps endpoints accessibly',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpScreen(tester, preferences: preferences);

      await _tapByKey(tester, 'trip-preview');
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'trip-origin-focus',
      );

      await tester.enterText(
        find.byKey(const ValueKey('trip-origin-field')),
        'Bogotá · Bogotá',
      );
      await tester.enterText(
        find.byKey(const ValueKey('trip-destination-field')),
        'Medellín · Antioquia',
      );
      await _tapByKey(tester, 'trip-swap-locations');
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('trip-origin-field')),
            )
            .controller!
            .text,
        'Medellín · Antioquia',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('trip-destination-field')),
            )
            .controller!
            .text,
        'Bogotá · Bogotá',
      );
      expect(
        find.bySemanticsLabel('Intercambiar origen y destino'),
        findsOneWidget,
      );
      semantics.dispose();
    },
  );

  testWidgets(
    'VIAJE-R2 successful request compacts preparation and reveals results once',
    (tester) async {
      final client = _PendingPlanClient();
      await TripDraftStore(preferences).saveDraft(
        TripDraft(
          origin: 'Bogotá',
          destination: 'Medellín',
          date: DateTime(2026, 9, 7),
          departureMinute: 600,
        ),
      );
      await _pumpScreen(
        tester,
        preferences: preferences,
        activeVehicle: _vehicle(),
        planClient: client,
      );
      await _tapByKey(tester, 'trip-standard-vehicle');
      _pressButtonByKey(tester, 'trip-preview');
      await tester.pump();
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      final offsetBeforeSuccess = scrollable.position.pixels;
      client.completions.single.complete(_testPlan(client.requests.single));
      await tester.pumpAndSettle();

      expect(scrollable.position.pixels, isNot(offsetBeforeSuccess));
      expect(find.text('Tu plan de viaje').hitTestable(), findsOneWidget);
      expect(
        find.byKey(const ValueKey('trip-preparation-summary')),
        findsOneWidget,
      );
      expect(find.text('Bogotá → Medellín'), findsOneWidget);
      expect(find.textContaining('ABC123'), findsWidgets);
      expect(find.byKey(const ValueKey('trip-origin-field')), findsNothing);
      expect(find.byKey(const ValueKey('trip-plan-result')), findsOneWidget);

      await _tapByKey(tester, 'trip-preparation-compact');
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('trip-origin-field')),
            )
            .controller!
            .text,
        'Bogotá',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('trip-destination-field')),
            )
            .controller!
            .text,
        'Medellín',
      );
      await _tapByKey(tester, 'trip-preparation-compact');

      final revealedOffset = scrollable.position.pixels;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(scrollable.position.pixels, revealedOffset);

      _pressButtonByKey(tester, 'trip-view-map-test-route');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('trip-map-preview-slot')),
        findsOneWidget,
      );
    },
  );

  testWidgets('VIAJE-R2 mounts the reviewed map in the selected-route seam', (
    tester,
  ) async {
    final client = _PendingPlanClient();
    await TripDraftStore(preferences).saveDraft(
      TripDraft(
        origin: 'Bogotá',
        destination: 'Medellín',
        date: DateTime(2026, 9, 7),
        departureMinute: 600,
      ),
    );
    await _pumpScreen(
      tester,
      preferences: preferences,
      activeVehicle: _vehicle(),
      planClient: client,
    );
    await _tapByKey(tester, 'trip-standard-vehicle');
    _pressButtonByKey(tester, 'trip-preview');
    await tester.pump();
    client.completions.single.complete(
      _testPlan(client.requests.single, withGeometry: true),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TripRoutePreviewMap), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-route-map')), findsOneWidget);
    expect(find.textContaining('DEMOSTRACIÓN'), findsNothing);
    expect(find.textContaining('Test only'), findsWidgets);
  });

  testWidgets('VIAJE-R2 uses the available local camera location count', (
    tester,
  ) async {
    final client = _PendingPlanClient();
    await TripDraftStore(preferences).saveDraft(
      TripDraft(
        origin: 'Bogotá',
        destination: 'Medellín',
        date: DateTime(2026, 9, 7),
        departureMinute: 600,
      ),
    );
    await _pumpScreen(
      tester,
      preferences: preferences,
      activeVehicle: _vehicle(),
      planClient: client,
      cameraSnapshot: TripCameraPackSnapshot(
        version: 'test-cameras-v2',
        pack: CameraPack(
          source: const CameraPackSource(
            name: 'Test only',
            pageUrl: 'https://example.test/cameras',
            dataUrl: 'https://example.test/cameras.json',
            fetchedAtUtc: '2026-09-01T00:00:00Z',
          ),
          cameras: [_cameraForRoute('local-camera')],
        ),
      ),
    );
    await _tapByKey(tester, 'trip-standard-vehicle');
    _pressButtonByKey(tester, 'trip-preview');
    await tester.pump();
    client.completions.single.complete(
      _testPlan(client.requests.single, withGeometry: true),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('trip-summary-cameras')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('trip-map-camera-local-camera-0')),
      findsOneWidget,
    );
  });

  testWidgets('prices route candidate tolls from local catalog only for current records', (
    tester,
  ) async {
    final client = _PendingPlanClient();
    await TripDraftStore(preferences).saveDraft(
      TripDraft(
        origin: 'Bogotá',
        destination: 'Medellín',
        date: DateTime(2026, 9, 7),
        departureMinute: 600,
      ),
    );
    await _pumpScreen(
      tester,
      preferences: preferences,
      activeVehicle: _vehicle(),
      planClient: client,
      tollInventory: TollInventoryDataset(
        version: 'test-tolls-v1',
        sourceTimestamp: DateTime.utc(2026, 8, 31),
        records: [
          _tollRecordForRoute(
            id: 'INV-GUARNE-3A941FAFD9',
            name: 'GUARNE',
          ),
          _tollRecordForRoute(
            id: 'INV-AMAGA-ABD7881C50',
            name: 'AMAGÁ',
            classification: TollOperationClassification.nonOperationalHistorical,
          ),
        ],
      ),
    );
    await _tapByKey(tester, 'trip-standard-vehicle');
    _pressButtonByKey(tester, 'trip-preview');
    await tester.pump();
    client.completions.single.complete(
      _testPlan(client.requests.single, withGeometry: true),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Cat I disponible para 1 de 1'), findsOneWidget);

    final localPricing = find.byKey(
      const ValueKey('trip-local-toll-pricing-test-route'),
    );
    await tester.ensureVisible(localPricing);
    await tester.pumpAndSettle();
    await tester.tap(localPricing);
    await tester.pumpAndSettle();

    expect(find.text('Tarifas propias sobre peajes candidatos'), findsOneWidget);
    expect(find.textContaining('Cobertura local completa'), findsOneWidget);
    expect(find.text('Subtotal con datos: COP 18.500'), findsOneWidget);
    expect(find.text('Total local: COP 18.500'), findsOneWidget);
    expect(find.textContaining('AMAGÁ'), findsNothing);
  });

  testWidgets(
    'VIAJE-R2 defers local associations and discards a stale route result',
    (tester) async {
      final client = _PendingPlanClient();
      final associations = _PendingAssociationResolver();
      await TripDraftStore(preferences).saveDraft(
        TripDraft(
          origin: 'Bogotá',
          destination: 'Medellín',
          date: DateTime(2026, 9, 7),
          departureMinute: 600,
        ),
      );
      await _pumpScreen(
        tester,
        preferences: preferences,
        activeVehicle: _vehicle(),
        planClient: client,
        associationResolver: associations,
      );
      await _tapByKey(tester, 'trip-standard-vehicle');
      _pressButtonByKey(tester, 'trip-preview');
      await tester.pump();
      client.completions.single.complete(
        _testPlanWithTwoRoutes(client.requests.single, withGeometry: true),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('trip-plan-result')), findsOneWidget);
      expect(associations.requests, hasLength(1));
      expect(associations.schedulerPhases, [SchedulerPhase.postFrameCallbacks]);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('trip-summary-cameras')),
          matching: find.text('Por confirmar'),
        ),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('trip-select-route-scenic')),
      );
      await tester.pump();
      _pressButtonByKey(tester, 'trip-select-route-scenic');
      await tester.pump();
      expect(associations.requests, hasLength(2));

      associations.completions.first.complete(
        _associationResult(
          associations.requests.first,
          cameras: [_cameraForRoute('old-camera')],
        ),
      );
      await tester.pump();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('trip-summary-cameras')),
          matching: find.text('Por confirmar'),
        ),
        findsOneWidget,
      );

      associations.completions.last.complete(
        _associationResult(associations.requests.last, cameras: const []),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('trip-summary-cameras')),
          matching: find.text('0'),
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('no significa que la ruta esté libre de cámaras'),
        findsWidgets,
      );

      await tester.tap(find.byKey(const ValueKey('trip-map-fullscreen')));
      await tester.pumpAndSettle();
      expect(associations.requests, hasLength(2));
    },
  );

  testWidgets('VIAJE-R2 keeps the plan and retries local map data', (
    tester,
  ) async {
    final client = _PendingPlanClient();
    var failTolls = true;
    await TripDraftStore(preferences).saveDraft(
      TripDraft(
        origin: 'Bogotá',
        destination: 'Medellín',
        date: DateTime(2026, 9, 7),
        departureMinute: 600,
      ),
    );
    await _pumpScreen(
      tester,
      preferences: preferences,
      activeVehicle: _vehicle(),
      planClient: client,
      tollInventoryLoader: () async {
        if (failTolls) throw StateError('local snapshot unavailable');
        return _emptyTollInventory();
      },
    );
    await _tapByKey(tester, 'trip-standard-vehicle');
    _pressButtonByKey(tester, 'trip-preview');
    await tester.pump();
    client.completions.single.complete(
      _testPlan(client.requests.single, withGeometry: true),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('trip-plan-result')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-map-data-retry')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('trip-summary-cameras')),
        matching: find.text('Por confirmar'),
      ),
      findsOneWidget,
    );
    failTolls = false;
    await _tapByKey(tester, 'trip-map-data-retry');

    expect(find.byType(TripRoutePreviewMap), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-route-map')), findsOneWidget);
  });

  testWidgets('VIAJE-R2 offstage success never changes scroll position', (
    tester,
  ) async {
    final client = _PendingPlanClient();
    await TripDraftStore(preferences).saveDraft(
      TripDraft(
        origin: 'Bogotá',
        destination: 'Medellín',
        date: DateTime(2026, 9, 7),
        departureMinute: 600,
      ),
    );
    await _pumpScreen(
      tester,
      preferences: preferences,
      activeVehicle: _vehicle(),
      planClient: client,
      tickerEnabled: false,
    );
    await _tapByKey(tester, 'trip-standard-vehicle');
    _pressButtonByKey(tester, 'trip-preview');
    await tester.pump();
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    final offsetBeforeSuccess = scrollable.position.pixels;
    client.completions.single.complete(_testPlan(client.requests.single));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('trip-plan-result')), findsOneWidget);
    expect(scrollable.position.pixels, offsetBeforeSuccess);
  });

  testWidgets('VIAJE-R2 reduced motion reveals results without animation', (
    tester,
  ) async {
    final client = _PendingPlanClient();
    await TripDraftStore(preferences).saveDraft(
      TripDraft(
        origin: 'Bogotá',
        destination: 'Medellín',
        date: DateTime(2026, 9, 7),
        departureMinute: 600,
      ),
    );
    await _pumpScreen(
      tester,
      preferences: preferences,
      activeVehicle: _vehicle(),
      planClient: client,
      disableAnimations: true,
    );
    await _tapByKey(tester, 'trip-standard-vehicle');
    _pressButtonByKey(tester, 'trip-preview');
    await tester.pump();
    client.completions.single.complete(_testPlan(client.requests.single));
    await tester.pump();
    await tester.pump();

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(scrollable.position.pixels, greaterThan(0));
    expect(scrollable.position.isScrollingNotifier.value, isFalse);
  });

  testWidgets('VIAJE-R2 manual scroll while loading suppresses auto-scroll', (
    tester,
  ) async {
    final client = _PendingPlanClient();
    await TripDraftStore(preferences).saveDraft(
      TripDraft(
        origin: 'Bogotá',
        destination: 'Medellín',
        date: DateTime(2026, 9, 7),
        departureMinute: 600,
      ),
    );
    await _pumpScreen(
      tester,
      preferences: preferences,
      activeVehicle: _vehicle(),
      planClient: client,
    );
    await _tapByKey(tester, 'trip-standard-vehicle');
    _pressButtonByKey(tester, 'trip-preview');
    await tester.pump();
    await tester.drag(
      find.byKey(const ValueKey('trip-screen')),
      const Offset(0, -180),
    );
    await tester.pump(const Duration(milliseconds: 500));
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    final manualOffset = scrollable.position.pixels;

    client.completions.single.complete(_testPlan(client.requests.single));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('trip-plan-result')), findsOneWidget);
    expect(scrollable.position.pixels, manualOffset);
  });

  testWidgets(
    'VIAJE-R2 interaction during reveal keeps user scroll and focus authority',
    (tester) async {
      final client = _PendingPlanClient();
      await TripDraftStore(preferences).saveDraft(
        TripDraft(
          origin: 'Bogotá',
          destination: 'Medellín',
          date: DateTime(2026, 9, 7),
          departureMinute: 600,
        ),
      );
      await _pumpScreen(
        tester,
        preferences: preferences,
        activeVehicle: _vehicle(),
        planClient: client,
      );
      await _tapByKey(tester, 'trip-standard-vehicle');
      _pressButtonByKey(tester, 'trip-preview');
      await tester.pump();
      client.completions.single.complete(_testPlan(client.requests.single));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      expect(scrollable.position.isScrollingNotifier.value, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final userFocus = FocusManager.instance.primaryFocus;
      expect(userFocus, isNotNull);
      expect(userFocus?.debugLabel, isNot('trip-results-focus'));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('trip-screen'))),
      );
      await gesture.moveBy(const Offset(0, -80));
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await tester.pump();
      final userOffset = scrollable.position.pixels;
      await tester.pump(const Duration(milliseconds: 100));

      expect(scrollable.position.pixels, closeTo(userOffset, 0.01));
      expect(FocusManager.instance.primaryFocus, same(userFocus));
    },
  );

  testWidgets('VIAJE-R2 keyboard next moves focus to destination', (
    tester,
  ) async {
    await _pumpScreen(tester, preferences: preferences);
    await tester.showKeyboard(find.byKey(const ValueKey('trip-origin-field')));
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();

    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'trip-destination-focus',
    );
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
  DateTime Function()? restrictionClock,
  TripEndpointRestriction Function(TripInstantRestrictionQuery)?
  instantRestriction,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool tickerEnabled = true,
  bool disableAnimations = false,
  bool settle = true,
  TollInventoryDataset? tollInventory,
  Future<TollInventoryDataset> Function()? tollInventoryLoader,
  TripCameraPackSnapshot? cameraSnapshot,
  TripRouteMapConfig? mapConfig,
  TripRouteAssociationResolver? associationResolver,
  Widget? shellOverlay,
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
        if (restrictionClock != null)
          tripRestrictionClockProvider.overrideWithValue(restrictionClock),
        if (instantRestriction != null)
          tripInstantRestrictionProvider.overrideWith(
            (ref, query) async => instantRestriction(query),
          ),
        if (planClient != null)
          tripPlanClientProvider.overrideWithValue(planClient),
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
        tripTollInventoryProvider.overrideWith(
          (ref) =>
              tollInventoryLoader?.call() ??
              Future.value(tollInventory ?? _emptyTollInventory()),
        ),
        tripTollTariffCatalogProvider.overrideWith(
          (ref) async => _tollTariffCatalog,
        ),
        tripCameraPackSnapshotProvider.overrideWith(
          (ref) async => cameraSnapshot ?? _emptyCameraSnapshot(),
        ),
        tripRouteMapConfigProvider.overrideWithValue(
          mapConfig ?? _neutralTripMapConfig(),
        ),
        tripRouteAssociationResolverProvider.overrideWithValue(
          associationResolver ??
              CachedTripRouteAssociationResolver(
                compute: (request) async =>
                    const TripRouteAssociator().associate(
                      routeId: request.routeId,
                      geometry: request.geometry,
                      tolls: request.tolls,
                      cameras: request.cameras,
                    ),
              ),
        ),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: child!,
        ),
        home: TickerMode(
          enabled: tickerEnabled,
          child: shellOverlay == null
              ? const TripScreen()
              : Stack(children: [const TripScreen(), shellOverlay]),
        ),
      ),
    ),
  );
  await tester.pump();
  if (settle) {
    await tester.pumpAndSettle();
  }
}

Widget _testBottomNav() {
  return AppBottomNav(
    destinations: [
      for (final tab in AppTab.values)
        AppBottomNavDestination(
          label: tab.label,
          icon: tab.icon,
          selectedIcon: tab.selectedIcon,
          color: tab.color,
          keyName: tab.name,
        ),
    ],
    currentIndex: AppTab.trip.index,
    onSelect: (_) {},
  );
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
  Future<TripPlan> preview(
    TripPlanRequest request, {
    CancelToken? cancelToken,
  }) {
    requests.add(request);
    tokens.add(cancelToken);
    final pending = Completer<TripPlan>();
    completions.add(pending);
    return pending.future;
  }
}

TripPlan _testPlan(TripPlanRequest request, {bool withGeometry = false}) =>
    TripPlan(
      requestId: request.requestId,
      generatedAtUtc: DateTime.utc(2026, 9, 5, 12),
      provider: 'Test only',
      attribution: 'Test only',
      origin: const TripResolvedPoint(
        label: 'Referencia origen',
        latitude: 4.7,
        longitude: -74.1,
      ),
      destination: const TripResolvedPoint(
        label: 'Referencia destino',
        latitude: 6.2,
        longitude: -75.5,
      ),
      routes: [
        TripRouteOption(
          id: 'test-route',
          summary: 'Ruta de prueba',
          distanceMeters: 420000,
          durationSeconds: 36000,
          timeBasis: 'static',
          geometry: withGeometry
              ? const [
                  TripCoordinate(latitude: 4.7, longitude: -74.1),
                  TripCoordinate(latitude: 5.4, longitude: -74.8),
                  TripCoordinate(latitude: 6.2, longitude: -75.5),
                ]
              : const [],
          tolls: TripTolls(
            coverage: TripTollCoverage.unknown,
            vehicleCategory: 'car',
          ),
        ),
      ],
    );

TollInventoryDataset _emptyTollInventory() => TollInventoryDataset(
  version: 'test-tolls-v1',
  sourceTimestamp: DateTime.utc(2026, 8, 31),
  records: const [],
);

TollInventoryRecord _tollRecordForRoute({
  required String id,
  required String name,
  TollOperationClassification classification =
      TollOperationClassification.inventoriedOperationNotConfirmed,
}) => TollInventoryRecord(
  id: id,
  name: name,
  exactSourceName: name,
  department: 'Antioquia',
  recordKind: TollRecordKind.physicalStation,
  operationStatusRaw: 'Inventariado',
  operationClassification: classification,
  latitude: 5.4,
  longitude: -74.8,
  chargeEventVerified: false,
  tariffsBySourceCategoryCop: const {
    'category_1': null,
    'category_2': null,
    'category_3': null,
    'category_4': null,
    'category_5': null,
    'category_6': null,
    'category_7': null,
  },
  inventorySource: 'https://example.test/tolls',
  gpsSource: 'https://example.test/tolls-gps',
);

TripCameraPackSnapshot _emptyCameraSnapshot() => const TripCameraPackSnapshot(
  version: 'test-cameras-v1',
  pack: CameraPack(
    source: CameraPackSource(
      name: 'Test only',
      pageUrl: 'https://example.test/cameras',
      dataUrl: 'https://example.test/cameras.json',
      fetchedAtUtc: '2026-08-31T00:00:00Z',
    ),
    cameras: [],
  ),
);

TripRouteMapConfig _neutralTripMapConfig() => const TripRouteMapConfig(
  tileUrlTemplate: 'https://tiles.test/{z}/{x}/{y}.png',
  attributionLabel: 'Test only',
  userAgentPackageName: 'co.picoradar.app.dev',
  forceNeutralFallback: true,
);

TripPlan _testPlanWithTwoRoutes(
  TripPlanRequest request, {
  bool withGeometry = false,
}) {
  final plan = _testPlan(request, withGeometry: withGeometry);
  return TripPlan(
    requestId: plan.requestId,
    generatedAtUtc: plan.generatedAtUtc,
    provider: plan.provider,
    attribution: plan.attribution,
    origin: plan.origin,
    destination: plan.destination,
    routes: [
      plan.routes.single,
      TripRouteOption(
        id: 'scenic',
        summary: 'Ruta alterna extensa para validar lectura integrada',
        distanceMeters: 460000,
        durationSeconds: 39600,
        timeBasis: 'static',
        geometry: withGeometry
            ? const [
                TripCoordinate(latitude: 4.7, longitude: -74.1),
                TripCoordinate(latitude: 5.5, longitude: -74.7),
                TripCoordinate(latitude: 6.2, longitude: -75.5),
              ]
            : const [],
        tolls: TripTolls(
          coverage: TripTollCoverage.partial,
          vehicleCategory: 'car',
          stationCount: 4,
          subtotalMinor: 4200000,
        ),
      ),
    ],
  );
}

class _PendingAssociationResolver implements TripRouteAssociationResolver {
  final requests = <TripRouteAssociationRequest>[];
  final completions = <Completer<TripRouteAssociations>>[];
  final schedulerPhases = <SchedulerPhase>[];

  @override
  Future<TripRouteAssociations> resolve(TripRouteAssociationRequest request) {
    requests.add(request);
    schedulerPhases.add(SchedulerBinding.instance.schedulerPhase);
    final completion = Completer<TripRouteAssociations>();
    completions.add(completion);
    return completion.future;
  }
}

TripRouteAssociations _associationResult(
  TripRouteAssociationRequest request, {
  required List<TrafficCamera> cameras,
}) => const TripRouteAssociator(corridorMeters: 100000).associate(
  routeId: request.routeId,
  geometry: request.geometry,
  tolls: request.tolls,
  cameras: cameras,
);

TrafficCamera _cameraForRoute(String id) => TrafficCamera(
  id: id,
  department: 'Cundinamarca',
  municipality: 'Bogotá',
  jurisdiction: 'Bogotá',
  address: 'Corredor de prueba',
  latitude: 5.4,
  longitude: -74.8,
  status: 'Aprobada',
  technology: null,
  kind: CameraKind.mixed,
  speedLimitKmh: null,
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
