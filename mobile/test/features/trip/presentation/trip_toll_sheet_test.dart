import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/features/trip/data/toll_tariff_catalog.dart';
import 'package:picoradar/features/trip/presentation/trip_toll_sheet.dart';

void main() {
  late TollTariffCatalog catalog;

  setUpAll(() {
    catalog = TollTariffCatalog.fromJsonString(
      File('assets/catalogs/tolls_tariffs_v1.json').readAsStringSync(),
    );
  });

  Future<void> pump(
    WidgetTester tester,
    LocalTollPricingBreakdown? pricing, {
    ValueChanged<String>? onSource,
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripTollTariffCatalogProvider.overrideWith((ref) async => catalog),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: SingleChildScrollView(
                child: TripRouteTolls(
                  pricing: pricing,
                  onSource: onSource ?? (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('search filters route passages without adding national entries', (
    tester,
  ) async {
    final guarne = catalog.byId('INV-GUARNE-3A941FAFD9')!;
    final papiros = catalog.byId('INV-PAPIROS-2F4F657C0E')!;
    expect(catalog.search('amaga'), isNotEmpty);
    await pump(
      tester,
      _pricing([
        _charge(guarne, 1850000),
        _charge(papiros, null),
        _charge(guarne, 1850000),
      ]),
    );

    expect(find.byType(ExpansionTile), findsNWidgets(3));
    expect(find.text('1. GUARNE'), findsOneWidget);
    expect(find.text('2. PAPIROS'), findsOneWidget);
    expect(find.text('3. GUARNE'), findsOneWidget);
    final search = find.byKey(const ValueKey('trip-route-toll-search'));
    await tester.enterText(search, '  gUaRnE  ');
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsNWidgets(2));
    expect(find.text('2. PAPIROS'), findsNothing);
    expect(find.text('3. GUARNE'), findsOneWidget);
    expect(find.text('COP 37.000'), findsOneWidget);

    await tester.enterText(search, 'amaga');
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsNothing);
    expect(find.text('No hay coincidencias en esta ruta.'), findsOneWidget);
    expect(find.textContaining('AMAGÁ'), findsNothing);
    expect(find.text('COP 37.000'), findsOneWidget);

    await tester.enterText(search, '');
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsNWidgets(3));
    expect(find.text('2. PAPIROS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final stationCase in [
    ('norte', 'Buses de dos ejes del operador Norte', 32500),
    ('sur', 'Camiones de dos ejes del operador Sur', 41700),
  ]) {
    testWidgets(
      'category consultation uses ${stationCase.$1} source and preserves estimate',
      (tester) async {
        final station = _station(
          stationCase.$1,
          stationCase.$2,
          stationCase.$3,
        );
        final pricing = _pricing([_charge(station, 1850000)]);
        final sources = <String>[];
        await pump(tester, pricing, onSource: sources.add);
        await tester.tap(find.byType(ExpansionTile));
        await tester.pumpAndSettle();
        expect(
          find.text('Automoviles del operador ${stationCase.$1}'),
          findsOneWidget,
        );
        expect(find.text('Tarifa publicada: COP 18.500'), findsOneWidget);
        await tester.ensureVisible(find.text('Consultar fuente'));
        await tester.tap(find.text('Consultar fuente'));
        expect(sources, ['https://example.test/${station.id}/I']);

        final category = find.byKey(
          ValueKey('trip-toll-category-${station.id}'),
        );
        await tester.ensureVisible(category);
        await tester.tap(category);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Categoría II').last);
        await tester.pumpAndSettle();
        expect(find.text(stationCase.$2), findsOneWidget);
        expect(
          find.text('Automoviles del operador ${stationCase.$1}'),
          findsNothing,
        );
        expect(
          find.text(
            stationCase.$1 == 'norte'
                ? 'Tarifa publicada: COP 32.500'
                : 'Tarifa publicada: COP 41.700',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            'Consulta de tarifa; no modifica el vehículo ni valida la ruta para esta categoría.',
          ),
          findsOneWidget,
        );
        expect(find.text('COP 18.500'), findsOneWidget);
        expect(find.text('Cat. I · COP 18.500'), findsOneWidget);
        expect(pricing.totalMinor, 1850000);
        expect(pricing.charges.single.categoryCode, 'I');
        await tester.ensureVisible(find.text('Consultar fuente'));
        await tester.tap(find.text('Consultar fuente'));
        expect(sources.last, 'https://example.test/${station.id}/II');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'missing initial category consults the first available rate consistently',
    (tester) async {
      final station = _station('fallback', 'Buses de dos ejes', 32500);
      final charge = LocalTollPricingCharge(
        stationId: station.id,
        name: station.name,
        categoryCode: 'III',
        amountMinor: 4170000,
        publicationControl: null,
        sourceType: 'Oficial',
        sourceDate: '2026-09-01',
        sourceUrl: 'https://example.test/fallback/III',
        station: station,
      );
      final pricing = _pricing([charge]);
      final sources = <String>[];
      expect(station.generalRateByCategory('III'), isNull);
      expect(station.generalRates.first.categoryCode, 'I');
      await pump(tester, pricing, onSource: sources.add);
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      final category = find.byKey(
        const ValueKey('trip-toll-category-fallback'),
      );
      expect(tester.state<FormFieldState<String>>(category).value, 'I');
      expect(find.text('Automoviles del operador fallback'), findsOneWidget);
      expect(find.text('Tarifa publicada: COP 18.500'), findsOneWidget);
      expect(find.text('Descripción no disponible'), findsNothing);
      expect(find.text('Tarifa publicada: Sin dato'), findsNothing);
      expect(
        find.text(
          'Consulta de tarifa; no modifica el vehículo ni valida la ruta para esta categoría.',
        ),
        findsOneWidget,
      );
      expect(find.text('COP 41.700'), findsOneWidget);
      expect(find.text('Cat. III · COP 41.700'), findsOneWidget);
      expect(pricing.totalMinor, 4170000);
      expect(pricing.charges.single.categoryCode, 'III');
      await tester.ensureVisible(find.text('Consultar fuente'));
      await tester.tap(find.text('Consultar fuente'));
      expect(sources, ['https://example.test/fallback/I']);
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 1.5, 2.0]) {
    for (final state in [
      'unavailable',
      'no-passages',
      'unknown',
      'unsupported',
    ]) {
      testWidgets('$state tolls never imply zero at scale $scale', (
        tester,
      ) async {
        final pricing = switch (state) {
          'unavailable' => null,
          'unknown' => _pricing([
            _charge(_station('unknown', null, null), null),
          ]),
          _ => LocalTollPricingBreakdown(
            coverage: state == 'unsupported'
                ? LocalTollPricingCoverage.unsupportedCategory
                : LocalTollPricingCoverage.noPassages,
            subtotalMinor: 0,
            totalMinor: null,
            missingRates: 0,
            charges: const [],
          ),
        };
        await pump(tester, pricing, scale: scale);
        expect(
          find.text(switch (state) {
            'unavailable' => 'Peajes por confirmar',
            'unknown' => 'Cobros por confirmar',
            'unsupported' => 'Categoría por confirmar',
            _ => 'Sin pasos identificados',
          }),
          findsOneWidget,
        );
        expect(find.textContaining('COP 0'), findsNothing);
        expect(find.textContaining('0 peajes'), findsNothing);
        if (state == 'unknown') {
          expect(find.text('Cat. I · Cobro pendiente'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}

TollTariffStation _station(String id, String? descriptionII, int? amountII) =>
    TollTariffStation.fromJson({
      'id': id,
      'name': 'Peaje $id',
      'latitude': 5.4,
      'longitude': -74.8,
      'generalRates': [
        {
          'categoryCode': 'I',
          'vehicleDescription': 'Automoviles del operador $id',
          'amountCop': 18500,
          'sourceType': 'Oficial',
          'amountSourceUrl': 'https://example.test/$id/I',
        },
        {
          'categoryCode': 'II',
          'vehicleDescription': descriptionII,
          'amountCop': amountII,
          'sourceType': 'Oficial',
          'amountSourceUrl': 'https://example.test/$id/II',
        },
      ],
      'specialRates': <Object>[],
    });

LocalTollPricingCharge _charge(TollTariffStation station, int? amount) =>
    LocalTollPricingCharge(
      stationId: station.id,
      name: station.name,
      categoryCode: 'I',
      amountMinor: amount,
      publicationControl: station.publicationControl,
      sourceType: 'Oficial',
      sourceDate: '2026-09-01',
      sourceUrl: station.categoryI?.amountSourceUrl,
      station: station,
    );

LocalTollPricingBreakdown _pricing(List<LocalTollPricingCharge> charges) {
  final missing = charges.where((charge) => charge.amountMinor == null).length;
  final subtotal = charges.fold<int>(
    0,
    (sum, charge) => sum + (charge.amountMinor ?? 0),
  );
  return LocalTollPricingBreakdown(
    coverage: missing > 0
        ? LocalTollPricingCoverage.partial
        : LocalTollPricingCoverage.complete,
    subtotalMinor: subtotal,
    totalMinor: missing > 0 ? null : subtotal,
    missingRates: missing,
    charges: charges,
  );
}
