import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:picoradar/app/app_clock.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/garage/presentation/vehicle_detail_screen.dart';
import 'package:picoradar/features/vehicle_status/data/tax_catalog.dart';
import 'package:picoradar/features/vehicle_status/domain/vehicle_obligation.dart';
import 'package:picoradar/features/vehicle_status/presentation/tax_owner_content.dart';
import 'package:picoradar/features/vehicle_status/presentation/vehicle_status_screen.dart';

import '../../../test_app_harness.dart';

void main() {
  for (final territory in [
    (
      city: 'Zipaquirá - Cundinamarca',
      id: 'cundinamarca',
      code: '25',
      name: 'Cundinamarca',
    ),
    (
      city: 'Bucaramanga - Santander',
      id: 'santander',
      code: '68',
      name: 'Santander',
    ),
  ]) {
    testWidgets(
      'tax detail resolves registration ${territory.city} without saved authority',
      (tester) async {
        final harness = TestAppHarness();
        addTearDown(harness.dispose);
        final vehicle = await harness.repository.createVehicle(
          plate: 'AAA111',
          kind: VehicleKind.car,
          registrationCity: territory.city,
        );
        await harness.pump(
          tester,
          childOverride: ProviderScope(
            overrides: [
              appClockProvider.overrideWith(AppClock.new),
              appClockNowProvider.overrideWithValue(
                () => DateTime.utc(2026, 8, 27, 15),
              ),
              taxCatalogProvider.overrideWithValue(
                AsyncValue.data(
                  _catalog(
                    status: 'verified',
                    year: 2026,
                    authorityId: territory.id,
                    territoryCode: territory.code,
                    territoryName: territory.name,
                  ),
                ),
              ),
              vehicleObligationsProvider(vehicle.id)
                  .overrideWithValue(const AsyncValue.data([])),
            ],
            child: MaterialApp(
              home: VehicleDetailScreen(vehicleId: vehicle.id),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final more = find.byKey(const ValueKey('detail-more-actions'));
        if (more.evaluate().isNotEmpty) {
          await tester.tap(more);
          await tester.pumpAndSettle();
        }
        expect(find.text('Calendario oficial'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'tax detail review expires at UTC instant within same civil day',
    (tester) async {
      final harness = TestAppHarness();
      addTearDown(harness.dispose);
      var instant = DateTime.utc(2026, 8, 27, 14, 59, 59);
      final vehicle = await harness.repository.createVehicle(
        plate: 'AAA111',
        kind: VehicleKind.car,
        registrationCity: 'Zipaquirá - Cundinamarca',
      );
      await harness.pump(
        tester,
        childOverride: ProviderScope(
          overrides: [
            appClockProvider.overrideWith(AppClock.new),
            appClockNowProvider.overrideWithValue(() => instant),
            taxCatalogProvider.overrideWithValue(
              AsyncValue.data(
                _catalog(
                  status: 'verified',
                  year: 2026,
                  reviewAfter: '2026-08-27T10:00:00-05:00',
                ),
              ),
            ),
            vehicleObligationsProvider(vehicle.id)
                .overrideWithValue(const AsyncValue.data([])),
          ],
          child: MaterialApp(home: VehicleDetailScreen(vehicleId: vehicle.id)),
        ),
      );
      await tester.pumpAndSettle();
      final more = find.byKey(const ValueKey('detail-more-actions'));
      if (more.evaluate().isNotEmpty) {
        await tester.tap(more);
        await tester.pumpAndSettle();
      }
      expect(find.text('Calendario oficial'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(VehicleDetailScreen)),
      );
      instant = DateTime.utc(2026, 8, 27, 15);
      container.read(appClockProvider.notifier).setForeground(true);
      await tester.pumpAndSettle();
      expect(find.text('Revisión pendiente'), findsOneWidget);
      expect(find.text('Calendario oficial'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tax missing explicit vehicle does not open favorite and offers garage',
    (tester) async {
      final harness = TestAppHarness();
      addTearDown(harness.dispose);
      final favorite = await harness.repository.createVehicle(
        plate: 'AAA111',
        kind: VehicleKind.car,
      );
      await harness.repository.setActiveVehicle(favorite.id);
      final router = GoRouter(
        initialLocation: '/tax',
        routes: [
          GoRoute(
            path: '/tax',
            builder: (_, _) => const VehicleStatusScreen(
              moduleId: 'impuestos',
              vehicleId: 'deleted',
            ),
          ),
          GoRoute(
            path: '/garage',
            builder: (_, _) => const Scaffold(body: Text('Garaje destino')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await harness.pump(
        tester,
        childOverride: MaterialApp.router(routerConfig: router),
      );
      await tester.pumpAndSettle();
      expect(find.text('Este vehículo ya no está disponible.'), findsOneWidget);
      expect(find.byType(TaxOwnerContent), findsNothing);
      expect(tester.widget<Text>(find.text('Impuestos')).style?.fontSize, 20);
      await tester.tap(
        find.byKey(const ValueKey('tax-missing-vehicle-garage')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Garaje destino'), findsOneWidget);
      expect((await harness.repository.getActiveVehicle())?.id, favorite.id);
    },
  );

  for (final explicit in [false, true]) {
    testWidgets(
      'tax resolves ${explicit ? 'explicit vehicle before' : 'no ID to'} favorite',
      (tester) async {
        final harness = TestAppHarness();
        addTearDown(harness.dispose);
        final first = await harness.repository.createVehicle(
          plate: 'AAA111',
          kind: VehicleKind.car,
        );
        final favorite = await harness.repository.createVehicle(
          plate: 'BBB222',
          kind: VehicleKind.car,
        );
        await harness.repository.setActiveVehicle(favorite.id);
        final expected = explicit ? first : favorite;
        await harness.pump(
          tester,
          childOverride: ProviderScope(
            overrides: [
              taxCatalogProvider.overrideWithValue(
                AsyncValue.data(_catalog(status: 'pending', year: 2026)),
              ),
              taxCatalogRefreshProvider.overrideWithValue((_) async => false),
              vehicleObligationProvider((
                expected.id,
                VehicleObligationType.tax,
              )).overrideWithValue(const AsyncValue.data(null)),
            ],
            child: MaterialApp(
              home: VehicleStatusScreen(
                moduleId: 'impuestos',
                vehicleId: explicit ? first.id : null,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TaxOwnerContent>(find.byType(TaxOwnerContent))
              .vehicle
              .id,
          expected.id,
        );
        expect((await harness.repository.getActiveVehicle())?.id, favorite.id);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final scenario in [
    (status: 'verified', year: 2026, stale: false, text: 'Calendario oficial'),
    (status: 'partial', year: 2026, stale: false, text: 'Calendario parcial'),
    (status: 'pending', year: 2026, stale: false, text: 'Calendario pendiente'),
    (
      status: 'withdrawn',
      year: 2026,
      stale: false,
      text: 'Calendario pendiente',
    ),
    (
      status: 'verified',
      year: 2025,
      stale: false,
      text: 'Calendario pendiente',
    ),
    (status: 'verified', year: 2026, stale: true, text: 'Revisión pendiente'),
  ]) {
    testWidgets('tax detail reads catalog $scenario', (tester) async {
      final harness = TestAppHarness();
      addTearDown(harness.dispose);
      final vehicle = await harness.repository.createVehicle(
        plate: 'AAA111',
        kind: VehicleKind.car,
      );
      final obligation = VehicleObligation(
        id: 'tax',
        vehicleId: vehicle.id,
        type: VehicleObligationType.tax,
        reminderEnabled: false,
        createdAt: harness.now,
        updatedAt: harness.now,
        details: const {'authorityId': 'cundinamarca'},
      );
      await harness.pump(
        tester,
        childOverride: ProviderScope(
          overrides: [
            appClockProvider.overrideWith(AppClock.new),
            appClockNowProvider.overrideWithValue(
              () => DateTime.utc(2026, 8, 27, 15),
            ),
            taxCatalogProvider.overrideWithValue(
              AsyncValue.data(
                _catalog(
                  status: scenario.status,
                  year: scenario.year,
                  stale: scenario.stale,
                ),
              ),
            ),
            vehicleObligationsProvider(vehicle.id)
                .overrideWithValue(AsyncValue.data([obligation])),
          ],
          child: MaterialApp(home: VehicleDetailScreen(vehicleId: vehicle.id)),
        ),
      );
      await tester.pumpAndSettle();
      final more = find.byKey(const ValueKey('detail-more-actions'));
      if (more.evaluate().isNotEmpty) {
        await tester.tap(more);
        await tester.pumpAndSettle();
      }
      expect(find.byKey(const ValueKey('detail-status-tax')), findsOneWidget);
      expect(find.text(scenario.text), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

TaxCatalog _catalog({
  required String status,
  required int year,
  bool stale = false,
  String? reviewAfter,
  String authorityId = 'cundinamarca',
  String territoryCode = '25',
  String territoryName = 'Cundinamarca',
}) {
  const source = 'https://www.cundinamarca.gov.co/';
  return TaxCatalog.fromJson({
    'schemaVersion': 1,
    'datasetKey': 'tax_calendars',
    'version': 'test',
    'generatedAt': '2026-08-27T00:00:00Z',
    'authorities': [
      {
        'id': authorityId,
        'territoryCode': territoryCode,
        'territoryName': territoryName,
        'name': 'Gobernacion de $territoryName',
        'sourceUrls': [source],
      },
    ],
    'calendars': [
      {
        'id': '$authorityId-$year',
        'authorityId': authorityId,
        'year': year,
        'obligationKind': 'vehicle_tax',
        'status': status,
        'reviewedAt': '$year-01-01T00:00:00Z',
        'reviewAfter':
            reviewAfter ??
            (stale ? '2026-08-01T00:00:00Z' : '2027-01-01T00:00:00Z'),
        'sourceUrls': [source],
        'events': [
          if (status == 'verified' || status == 'partial')
            {
              'id': 'ordinary',
              'date': '$year-07-31',
              'label': 'Fecha ordinaria',
              'kind': 'ordinary',
              'status': 'active',
              'sourceUrls': [source],
            },
        ],
      },
    ],
  });
}
