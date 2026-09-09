import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_day_evaluation.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_engine.dart';
import 'package:picoradar/features/trip/application/trip_services.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/trip/data/toll_tariff_catalog.dart';
import 'package:picoradar/features/trip/data/trip_municipality_catalog.dart';
import 'package:picoradar/features/trip/domain/trip_plan.dart';
import 'package:picoradar/features/trip/presentation/trip_plan_result.dart';

void main() {
  for (final testCase in [
    (
      RestrictionReasonCode.conflictingRules,
      'Hay reglas en conflicto para este vehículo y horario.',
    ),
    (
      RestrictionReasonCode.unknownRegistrationOrigin,
      'No se pudo determinar el origen de matrícula necesario para esta regla.',
    ),
    (
      RestrictionReasonCode.unknownRequiredPlateDigit,
      'No se pudo determinar el dígito de placa necesario para esta regla.',
    ),
  ]) {
    testWidgets(
      'VIAJE-R1 review8 explains ${testCase.$1} while keeping unknown',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TripInstantEndpoint(
                label: 'Origen / salida',
                instantUtc: DateTime.utc(2026, 9, 5, 12),
                onSource: (_) {},
                evaluation: AsyncData(
                  TripEndpointRestriction(
                    status: RestrictionDayStatus.unknown,
                    instantStatus: RestrictionStatus.unknown,
                    reason: 'no_coverage',
                    engineReason: testCase.$1,
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('Estado a esta hora no disponible'), findsOneWidget);
        expect(find.text(testCase.$2), findsOneWidget);
        expect(
          find.text('Sin cobertura de reglas para este municipio y vehículo.'),
          findsNothing,
        );
        expect(find.text('Sin restricción a la hora evaluada'), findsNothing);
      },
    );
  }

  final request = TripPlanRequest(
    requestId: 'test-request',
    origin: const TripMunicipality(
      code: '05001',
      municipality: 'Medellín',
      department: 'Antioquia',
    ),
    destination: const TripMunicipality(
      code: '11001',
      municipality: 'Bogotá',
      department: 'Bogotá',
    ),
    vehicle: VehicleProfile(
      id: 'local-only',
      plate: 'ABC123',
      kind: VehicleKind.car,
      serviceType: VehicleServiceType.private,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    departureUtc: DateTime.utc(2026, 9, 6, 4, 30),
    standardVehicleConfirmed: true,
  );
  TripRouteOption route(
    String id,
    TripTolls tolls, {
    int seconds = 7200,
    String? summary,
  }) => TripRouteOption(
    id: id,
    summary: summary ?? 'Corredor $id',
    distanceMeters: 125500,
    durationSeconds: seconds,
    timeBasis: 'static',
    tolls: tolls,
  );
  TripPlan plan(List<TripRouteOption> routes) => TripPlan(
    requestId: request.requestId,
    generatedAtUtc: DateTime.utc(2026, 9, 5, 12),
    provider: 'Proveedor de prueba',
    attribution: 'Atribución de prueba',
    origin: const TripResolvedPoint(
      label: 'Referencia Medellín',
      latitude: 6.2,
      longitude: -75.5,
    ),
    destination: const TripResolvedPoint(
      label: 'Referencia Bogotá',
      latitude: 4.7,
      longitude: -74.1,
    ),
    routes: routes,
  );
  Future<void> pump(
    WidgetTester tester,
    List<TripRouteOption> routes, {
    double scale = 1,
    Size size = const Size(360, 800),
    LocalTollPricingBreakdown? localTollPricing,
    Map<String, LocalTollPricingBreakdown> localPricingByRoute = const {},
    ValueNotifier<Map<String, LocalTollPricingBreakdown>>? pricingChanges,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selected = routes.first.id;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: StatefulBuilder(
              builder: (context, setState) => SingleChildScrollView(
                child: TripPlanResult(
                  request: request,
                  plan: plan(routes),
                  selectedRouteId: selected,
                  onRouteSelected: (id) => setState(() => selected = id),
                  onSource: (_) {},
                  localTollPricing:
                      localPricingByRoute[selected] ?? localTollPricing,
                  localPricingByRoute: localPricingByRoute,
                  pricingChanges: pricingChanges,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openRoutes(WidgetTester tester) async {
    final button = find.byKey(const ValueKey('trip-open-routes-detail'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> openTolls(WidgetTester tester, String routeId) async {
    final button = find.byKey(ValueKey('trip-toll-details-$routeId'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> closeSheet(WidgetTester tester) async {
    await tester.tapAt(const Offset(12, 12));
    await tester.pumpAndSettle();
  }

  testWidgets('summary is followed by a useful map before route alternatives', (
    tester,
  ) async {
    final routes = [
      route(
        'fast',
        TripTolls(
          coverage: TripTollCoverage.complete,
          vehicleCategory: 'car',
          stationCount: 2,
          payableCount: 2,
          totalMinor: 2400000,
        ),
      ),
      route(
        'slow',
        TripTolls(coverage: TripTollCoverage.unknown, vehicleCategory: 'car'),
        seconds: 10800,
      ),
    ];

    await pump(tester, routes);

    expect(find.text('Tu plan de viaje'), findsOneWidget);
    final metrics = [
      find.byKey(const ValueKey('trip-summary-distance')),
      find.byKey(const ValueKey('trip-summary-duration')),
      find.byKey(const ValueKey('trip-summary-cost')),
    ];
    for (final metric in metrics) {
      expect(metric, findsOneWidget);
    }
    expect(find.byKey(const ValueKey('trip-summary-arrival')), findsNothing);
    expect(find.byKey(const ValueKey('trip-summary-tolls')), findsNothing);
    expect(find.byKey(const ValueKey('trip-summary-cameras')), findsNothing);

    final firstRoute = find.byKey(const ValueKey('trip-route-fast'));
    final secondRoute = find.byKey(const ValueKey('trip-route-slow'));
    final mapSlot = find.byKey(const ValueKey('trip-map-preview-slot'));
    final tollDetails = find.byKey(const ValueKey('trip-toll-details-fast'));
    final routeHeading = find.text('Otras rutas · 2');
    expect(firstRoute, findsNothing);
    expect(secondRoute, findsNothing);
    expect(
      tester.getTopLeft(mapSlot).dy,
      greaterThan(tester.getBottomLeft(metrics.last).dy),
    );
    expect(tester.getSize(mapSlot).height, greaterThanOrEqualTo(300));
    expect(
      tester.getTopLeft(routeHeading).dy,
      greaterThan(tester.getBottomLeft(mapSlot).dy),
    );
    expect(
      tester.getTopLeft(tollDetails).dy,
      greaterThanOrEqualTo(tester.getTopLeft(routeHeading).dy),
    );
    expect(find.text('Opciones de ruta · 2'), findsNothing);

    await openRoutes(tester);
    expect(find.byKey(const ValueKey('trip-route-fast')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-route-slow')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('trip-select-route-slow')),
      findsOneWidget,
    );
  });

  testWidgets('shows local owner toll pricing as candidate breakdown', (
    tester,
  ) async {
    await pump(
      tester,
      [
        route(
          'priced',
          TripTolls(coverage: TripTollCoverage.unknown, vehicleCategory: 'car'),
        ),
      ],
      localTollPricing: const LocalTollPricingBreakdown(
        coverage: LocalTollPricingCoverage.partial,
        subtotalMinor: 1850000,
        totalMinor: null,
        missingRates: 1,
        charges: [
          LocalTollPricingCharge(
            stationId: 'INV-GUARNE-3A941FAFD9',
            name: 'GUARNE',
            categoryCode: 'I',
            amountMinor: 1850000,
            publicationControl: 'VALIDAR_RUTA_Y_CATEGORIA',
            sourceType: 'Oficial',
            sourceDate: '2026-01-10',
            sourceUrl: 'https://example.test/source',
          ),
          LocalTollPricingCharge(
            stationId: 'INV-PAPIROS-2F4F657C0E',
            name: 'PAPIROS',
            categoryCode: 'I',
            amountMinor: null,
            publicationControl: 'APLICAR_SUSPENSION_PARCIAL',
            sourceType: null,
            sourceDate: null,
            sourceUrl: null,
          ),
        ],
      ),
    );

    final summary = find.byKey(const ValueKey('trip-summary-cost'));
    expect(
      find.descendant(of: summary, matching: find.text('COP 18.500')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: summary, matching: find.text('Estimación parcial')),
      findsOneWidget,
    );
    await openTolls(tester, 'priced');
    final sheet = find.byKey(const ValueKey('trip-toll-sheet-priced'));
    expect(
      find.descendant(of: sheet, matching: find.text('COP 18.500')),
      findsOneWidget,
    );
    expect(
      find.text('1 cobros pendientes, excluidos de la estimación.'),
      findsOneWidget,
    );
    expect(find.text('1. GUARNE'), findsOneWidget);
    expect(find.text('2. PAPIROS'), findsOneWidget);
    expect(find.text('Cat. I · Cobro pendiente'), findsOneWidget);
    expect(find.textContaining('COP 0'), findsNothing);
  });

  testWidgets(
    'open toll sheet updates when local prices arrive without reopening',
    (tester) async {
      final prices = ValueNotifier<Map<String, LocalTollPricingBreakdown>>({});
      addTearDown(prices.dispose);
      await pump(tester, [
        route(
          'a',
          TripTolls(coverage: TripTollCoverage.unknown, vehicleCategory: 'car'),
        ),
        route(
          'b',
          TripTolls(coverage: TripTollCoverage.unknown, vehicleCategory: 'car'),
        ),
      ], pricingChanges: prices);
      await openTolls(tester, 'a');
      final sheet = find.byKey(const ValueKey('trip-toll-sheet-a'));
      final sheetElement = tester.element(sheet);
      expect(
        find.descendant(of: sheet, matching: find.text('Peajes por confirmar')),
        findsOneWidget,
      );

      prices.value = {
        'b': _localPricing([('Solo otra ruta', 900000)]),
      };
      await tester.pumpAndSettle();
      expect(find.textContaining('Solo otra ruta'), findsNothing);
      expect(tester.element(sheet), same(sheetElement));
      expect(
        find.descendant(of: sheet, matching: find.text('Peajes por confirmar')),
        findsOneWidget,
      );
      prices.value = {
        ...prices.value,
        'a': _localPricing([('Peaje de esta ruta', 1850000)]),
      };
      await tester.pumpAndSettle();
      expect(tester.element(sheet), same(sheetElement));
      expect(
        find.descendant(of: sheet, matching: find.text('COP 18.500')),
        findsOneWidget,
      );
      expect(find.text('1. Peaje de esta ruta'), findsOneWidget);
      expect(find.textContaining('Solo otra ruta'), findsNothing);
      expect(
        find.descendant(of: sheet, matching: find.text('Peajes por confirmar')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'open alternatives update local amounts and cheapest after data arrives',
    (tester) async {
      final prices = ValueNotifier<Map<String, LocalTollPricingBreakdown>>({});
      addTearDown(prices.dispose);
      await pump(tester, [
        route(
          'a',
          TripTolls(
            coverage: TripTollCoverage.complete,
            vehicleCategory: 'car',
            totalMinor: 99999999,
          ),
        ),
        route(
          'b',
          TripTolls(
            coverage: TripTollCoverage.complete,
            vehicleCategory: 'car',
            totalMinor: 0,
          ),
        ),
      ], pricingChanges: prices);
      await openRoutes(tester);
      final routeA = find.byKey(const ValueKey('trip-route-a'));
      final routeB = find.byKey(const ValueKey('trip-route-b'));
      final elementA = tester.element(routeA);
      final elementB = tester.element(routeB);
      expect(
        find.descendant(
          of: routeA,
          matching: find.text('Peajes por confirmar'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Menor estimación'), findsNothing);
      expect(
        find.descendant(
          of: routeB,
          matching: find.text('Peajes por confirmar'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('COP 0'), findsNothing);
      prices.value = {
        'a': _localPricing([('Peaje A', 1200000)]),
        'b': _localPricing([('Peaje B', 2400000)]),
      };
      await tester.pumpAndSettle();
      expect(tester.element(routeA), same(elementA));
      expect(
        find.descendant(of: routeA, matching: find.text('COP 12.000')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: routeB, matching: find.text('COP 24.000')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: routeA,
          matching: find.textContaining('Menor estimación'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: routeB,
          matching: find.textContaining('Menor estimación'),
        ),
        findsNothing,
      );
      expect(find.textContaining('COP 0'), findsNothing);
      prices.value = {
        ...prices.value,
        'b': _localPricing([('Peaje B', 900000)]),
      };
      await tester.pumpAndSettle();
      expect(tester.element(routeA), same(elementA));
      expect(tester.element(routeB), same(elementB));
      expect(
        find.descendant(of: routeB, matching: find.text('COP 9.000')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: routeB, matching: find.text('COP 24.000')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: routeA,
          matching: find.textContaining('Menor estimación'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: routeB,
          matching: find.textContaining('Menor estimación'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('local no-passages pricing never reads as complete COP zero', (
    tester,
  ) async {
    await pump(
      tester,
      [
        route(
          'no-passages',
          TripTolls(coverage: TripTollCoverage.unknown, vehicleCategory: 'car'),
        ),
      ],
      localTollPricing: const LocalTollPricingBreakdown(
        coverage: LocalTollPricingCoverage.noPassages,
        subtotalMinor: 0,
        totalMinor: null,
        missingRates: 0,
        charges: [],
      ),
    );

    await openTolls(tester, 'no-passages');

    expect(find.text('Sin pasos identificados'), findsWidgets);
    expect(
      find.text(
        'No hay pasos identificados para esta ruta. No significa que sea gratuita.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('COP 0'), findsNothing);
    expect(find.text('Subtotal con datos: COP 0'), findsNothing);
    expect(find.text('Total local: COP 0'), findsNothing);
    expect(find.textContaining('faltan 0 tarifa'), findsNothing);
  });

  for (final size in [
    const Size(360, 780),
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915),
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('VIAJE-R2 dense result fits $size at text scale $scale', (
        tester,
      ) async {
        await pump(
          tester,
          [
            route(
              'one',
              TripTolls(
                coverage: TripTollCoverage.partial,
                vehicleCategory: 'car',
                stationCount: 12,
                payableCount: 5,
                subtotalMinor: 9876500,
                missingRates: 7,
              ),
              summary: 'Corredor nacional con nombre extenso y datos parciales por confirmar',
            ),
            route(
              'two',
              TripTolls(
                coverage: TripTollCoverage.unknown,
                vehicleCategory: 'car',
              ),
              seconds: 14400,
            ),
            route(
              'three',
              TripTolls(
                coverage: TripTollCoverage.unsupportedVehicle,
                vehicleCategory: 'car',
              ),
              seconds: 18000,
            ),
          ],
          size: size,
          scale: scale,
        );
        await tester.pumpAndSettle();

        expect(find.byType(Scrollable), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'route selection binds toll details and next-day Bogota arrival',
    (tester) async {
      final routes = [
        route(
          'a',
          TripTolls(
            coverage: TripTollCoverage.complete,
            vehicleCategory: 'car',
            totalMinor: 2400000,
            charges: const [
              TripTollCharge(name: 'Estación A', amountMinor: 1200000),
              TripTollCharge(name: 'Estación A', amountMinor: 1200000),
            ],
          ),
        ),
        route(
          'b',
          TripTolls(
            coverage: TripTollCoverage.partial,
            vehicleCategory: 'car',
            subtotalMinor: 500000,
            missingRates: 1,
            charges: const [
              TripTollCharge(name: 'Estación B', amountMinor: 500000),
              TripTollCharge(name: 'Sin tarifa'),
            ],
          ),
          seconds: 10800,
        ),
      ];
      await pump(
        tester,
        routes,
        localPricingByRoute: {
          'a': _localPricing([
            ('Estación A', 1200000),
            ('Estación A', 1200000),
          ]),
          'b': _localPricing([('Estación B', 500000), ('Sin tarifa', null)]),
        },
      );
      await openRoutes(tester);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('trip-route-a')),
          matching: find.textContaining('2026-09-06 01:30'),
        ),
        findsOneWidget,
      );
      await closeSheet(tester);
      await openTolls(tester, 'a');
      expect(find.textContaining('Estación A'), findsNWidgets(2));
      await closeSheet(tester);
      await openRoutes(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('trip-select-route-b')),
      );
      await tester.tap(find.byKey(const ValueKey('trip-select-route-b')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('trip-toll-details-a')), findsNothing);
      await openTolls(tester, 'b');
      expect(find.textContaining('Estación B'), findsOneWidget);
      expect(find.textContaining('Estación A'), findsNothing);
      expect(
        find.text('Estimación parcial · cobros pendientes'),
        findsOneWidget,
      );
      expect(find.text('Cat. I · Cobro pendiente'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('trip-toll-sheet-b')),
          matching: find.text('COP 5.000'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('unknown cannot win cheapest and empty unknown is not zero', (
    tester,
  ) async {
    await pump(
      tester,
      [
        route(
          'unknown',
          TripTolls(coverage: TripTollCoverage.unknown, vehicleCategory: 'car'),
        ),
        route(
          'paid',
          TripTolls(
            coverage: TripTollCoverage.complete,
            vehicleCategory: 'car',
            totalMinor: 1200000,
            charges: const [
              TripTollCharge(name: 'Peaje', amountMinor: 1200000),
            ],
          ),
        ),
      ],
      localPricingByRoute: {
        'unknown': _localPricing([('Sin tarifa', null)]),
        'paid': _localPricing([('Peaje', 1200000)]),
      },
    );
    await openRoutes(tester);
    final unknown = find.byKey(const ValueKey('trip-route-unknown'));
    expect(
      find.descendant(
        of: unknown,
        matching: find.textContaining('Menor estimación'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: unknown, matching: find.textContaining('COP 0')),
      findsNothing,
    );
    expect(
      find.descendant(of: unknown, matching: find.textContaining('0 peajes')),
      findsNothing,
    );
    expect(find.textContaining('Menor estimación'), findsNothing);
  });

  testWidgets(
    'route details use local passages without promoting server station counts',
    (tester) async {
      await pump(
        tester,
        [
          route(
            'count',
            TripTolls(
              coverage: TripTollCoverage.partial,
              vehicleCategory: 'car',
              stationCount: 7,
              payableCount: 4,
              subtotalMinor: 1200000,
              missingRates: 3,
              charges: const [
                TripTollCharge(
                  name: 'Una tarifa conocida',
                  amountMinor: 1200000,
                ),
              ],
            ),
          ),
        ],
        localPricingByRoute: {
          'count': _localPricing([
            ('Paso local', 1850000),
            ('Pendiente', null),
          ]),
        },
      );
      await openRoutes(tester);
      expect(find.text('COP 18.500'), findsWidgets);
      expect(find.textContaining('7 estaciones de peaje'), findsNothing);
      expect(find.textContaining('4 cobros aplicables'), findsNothing);
      expect(find.textContaining('1 estaciones'), findsNothing);
      await closeSheet(tester);
      expect(find.text('Peajes de esta ruta · 2'), findsOneWidget);
      await openTolls(tester, 'count');
      expect(find.text('1. Paso local'), findsOneWidget);
      expect(find.text('2. Pendiente'), findsOneWidget);
    },
  );

  testWidgets(
    'cheapest compares complete totals and preserves repeated station visits',
    (tester) async {
      await pump(
        tester,
        [
          route(
            'expensive',
            TripTolls(
              coverage: TripTollCoverage.complete,
              vehicleCategory: 'car',
              totalMinor: 2400000,
              charges: const [
                TripTollCharge(name: 'Paso', amountMinor: 1200000),
                TripTollCharge(name: 'Paso', amountMinor: 1200000),
              ],
            ),
          ),
          route(
            'cheap',
            TripTolls(
              coverage: TripTollCoverage.complete,
              vehicleCategory: 'car',
              totalMinor: 1200000,
              charges: const [
                TripTollCharge(name: 'Otro', amountMinor: 1200000),
              ],
            ),
          ),
          route(
            'partial',
            TripTolls(
              coverage: TripTollCoverage.partial,
              vehicleCategory: 'car',
              subtotalMinor: 100000,
              missingRates: 2,
            ),
          ),
        ],
        localPricingByRoute: {
          'expensive': _localPricing([('Paso', 1200000), ('Paso', 1200000)]),
          'cheap': _localPricing([('Otro', 1200000)]),
          'partial': _localPricing([('Con dato', 100000), ('Sin dato', null)]),
        },
      );
      await openRoutes(tester);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('trip-route-cheap')),
          matching: find.text(
            'Menor estimación entre opciones con datos completos',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('trip-route-partial')),
          matching: find.textContaining('Menor estimación'),
        ),
        findsNothing,
      );
      await closeSheet(tester);
      expect(find.text('COP 24.000'), findsOneWidget);
      await openTolls(tester, 'expensive');
      expect(find.text('1. Paso'), findsOneWidget);
      expect(find.text('2. Paso'), findsOneWidget);
    },
  );

  testWidgets(
    'outside restriction window shows one instant status and day schedule',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TripInstantEndpoint(
                label: 'Origen / salida',
                instantUtc: DateTime.utc(2026, 9, 5, 23),
                onSource: (_) {},
                onCity: () {},
                evaluation: AsyncData(
                  TripEndpointRestriction(
                    status: RestrictionDayStatus.restricted,
                    instantStatus: RestrictionStatus.allowed,
                    windows: const [
                      RestrictionDayWindow(startMinute: 360, endMinute: 540),
                    ],
                    sourceUrl: 'https://example.com/regla',
                    verifiedAt: DateTime.utc(2026, 9, 1, 12),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Sin restricción a la hora evaluada'), findsOneWidget);
      expect(
        find.text('Este día tiene restricción para el vehículo.'),
        findsNothing,
      );
      expect(find.text('Horario restringido: 06:00–09:00'), findsOneWidget);
      expect(find.text('Consultar fuente'), findsNothing);
      expect(
        find.textContaining('Fuente verificada: 2026-09-01 07:00'),
        findsNothing,
      );
      expect(find.widgetWithText(ListTile, 'Origen / salida'), findsOneWidget);
    },
  );

  for (final coverage in TripTollCoverage.values) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'toll coverage $coverage at scale $scale stays truthful and fits',
        (tester) async {
          await pump(tester, [
            route(
              'one',
              TripTolls(
                coverage: coverage,
                vehicleCategory: 'motorcycle',
                totalMinor: coverage == TripTollCoverage.complete
                    ? 1200000
                    : coverage == TripTollCoverage.noChargeConfirmed
                    ? 0
                    : null,
                subtotalMinor: coverage == TripTollCoverage.partial
                    ? 1200000
                    : null,
                missingRates: coverage == TripTollCoverage.partial ? 1 : 0,
                charges:
                    coverage == TripTollCoverage.complete ||
                        coverage == TripTollCoverage.partial
                    ? const [
                        TripTollCharge(
                          name: 'Estación con nombre largo para comprobar ajuste de texto',
                          amountMinor: 1200000,
                        ),
                      ]
                    : const [],
              ),
            ),
          ], scale: scale);
          await tester.ensureVisible(
            find.byKey(const ValueKey('trip-toll-details-one')),
          );
          await tester.tap(find.byKey(const ValueKey('trip-toll-details-one')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Peajes por confirmar'), findsWidgets);
          expect(find.textContaining('COP 0'), findsNothing);
          expect(find.textContaining('COP 12.000'), findsNothing);
        },
      );
    }
  }
}

LocalTollPricingBreakdown _localPricing(List<(String, int?)> passages) {
  final missing = passages.where((passage) => passage.$2 == null).length;
  final subtotal = passages.fold<int>(
    0,
    (sum, passage) => sum + (passage.$2 ?? 0),
  );
  return LocalTollPricingBreakdown(
    coverage: missing == 0
        ? LocalTollPricingCoverage.complete
        : LocalTollPricingCoverage.partial,
    subtotalMinor: subtotal,
    totalMinor: missing == 0 ? subtotal : null,
    missingRates: missing,
    charges: [
      for (final (index, passage) in passages.indexed)
        LocalTollPricingCharge(
          stationId: 'station-$index',
          name: passage.$1,
          categoryCode: 'I',
          amountMinor: passage.$2,
          publicationControl: null,
          sourceType: 'Oficial',
          sourceDate: '2026-09-01',
          sourceUrl: 'https://example.test/toll',
        ),
    ],
  );
}
