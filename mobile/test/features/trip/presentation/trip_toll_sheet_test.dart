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
    double width = 390,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 844);
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
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TripRouteTolls(
                    pricing: pricing,
                    onSource: onSource ?? (_) {},
                  ),
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
    expect(find.text('1. Guarne'), findsOneWidget);
    expect(find.text('2. Papiros'), findsOneWidget);
    expect(find.text('3. Guarne'), findsOneWidget);
    expect(guarne.name, 'GUARNE');
    expect(papiros.name, 'PAPIROS');
    final search = find.byKey(const ValueKey('trip-route-toll-search'));
    await tester.enterText(search, '  gUaRnE  ');
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsNWidgets(2));
    expect(find.text('2. Papiros'), findsNothing);
    expect(find.text('3. Guarne'), findsOneWidget);
    expect(find.text('COP 37.000'), findsOneWidget);

    await tester.enterText(search, 'amaga');
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsNothing);
    expect(find.text('No hay coincidencias en esta ruta.'), findsOneWidget);
    expect(find.textContaining('Amagá'), findsNothing);
    expect(find.text('COP 37.000'), findsOneWidget);

    await tester.enterText(search, '');
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsNWidgets(3));
    expect(find.text('2. Papiros'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final stationCase in [
    ('norte', 'Buses de dos ejes del operador Norte', 32500),
    ('sur', 'Camiones de dos ejes del operador Sur', 41700),
  ]) {
    testWidgets(
      'all ${stationCase.$1} general rates appear together without changing estimate',
      (tester) async {
        final station = _station(
          stationCase.$1,
          stationCase.$2,
          stationCase.$3,
        );
        final pricing = _pricing([_charge(station, 1850000)]);
        final sources = <String>[];
        await pump(tester, pricing, onSource: sources.add);
        await _openStation(tester, station.id);
        final details = find.byType(TripTollChargeDetails);
        expect(
          find.text('Automoviles del operador ${stationCase.$1}'),
          findsOneWidget,
        );
        expect(find.text(stationCase.$2), findsOneWidget);
        expect(
          find.descendant(of: details, matching: find.text('Categoría I')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: details, matching: find.text('Categoría II')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: details, matching: find.text(r'$ 18.500')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: details,
            matching: find.text(
              stationCase.$1 == 'norte' ? r'$ 32.500' : r'$ 41.700',
            ),
          ),
          findsOneWidget,
        );
        expect(find.byType(DropdownButtonFormField<String>), findsNothing);
        expect(find.textContaining('Cobro pendiente'), findsNothing);
        expect(find.text('COP 18.500'), findsOneWidget);
        expect(find.text(r'$ 18.500'), findsNWidgets(2));
        expect(pricing.totalMinor, 1850000);
        expect(pricing.charges.single.categoryCode, 'I');
        expect(sources, isEmpty);
        expect(find.textContaining('Fuente · categoría'), findsNothing);
        await _tapText(tester, 'Condiciones y fuentes');
        await _tapText(tester, 'Fuente · categoría I');
        await _tapText(tester, 'Fuente · categoría II');
        expect(sources, [
          'https://example.test/${station.id}/I',
          'https://example.test/${station.id}/II',
        ]);
        expect(pricing.totalMinor, 1850000);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'missing charge category does not hide available rates or rewrite its budget',
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
      await _openStation(tester, station.id);
      expect(find.text('Categoría III'), findsOneWidget);
      expect(find.text('Categoría I'), findsOneWidget);
      expect(find.text('Categoría II'), findsOneWidget);
      expect(find.text('Automoviles del operador fallback'), findsOneWidget);
      expect(find.text('Buses de dos ejes'), findsOneWidget);
      expect(find.text(r'$ 18.500'), findsOneWidget);
      expect(find.text(r'$ 32.500'), findsOneWidget);
      expect(find.text(r'$ 41.700'), findsOneWidget);
      expect(find.text('COP 41.700'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(pricing.totalMinor, 4170000);
      expect(pricing.charges.single.categoryCode, 'III');
      expect(sources, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('maps callback uses the exact real Seminario coordinates', (
    tester,
  ) async {
    final station = catalog.byId('SUP-SEMINARIO-5823DA6561')!;
    final sources = <String>[];
    await pump(
      tester,
      _pricing([_charge(station, 2630000)]),
      onSource: sources.add,
    );
    expect(find.text('Ver ubicación en Google Maps'), findsNothing);
    await _openStation(tester, station.id);
    await _tapText(tester, 'Ver ubicación en Google Maps');
    expect(sources, [
      'https://www.google.com/maps/search/?api=1&query=6.223354274777737%2C-75.53483941832708',
    ]);
    final uri = Uri.parse(sources.single);
    expect(uri.queryParameters, {
      'api': '1',
      'query': '6.223354274777737,-75.53483941832708',
    });
    expect(tester.takeException(), isNull);
  });

  for (final reference in ['nominal', 'station']) {
    testWidgets(
      'excluded $reference tariff is visible but never added to budget',
      (tester) async {
        final known = _station('known', 'Buses', 32500);
        final excluded = _station('excluded', 'Buses', 32500);
        final pricing = _pricing([
          _charge(known, 1200000, nominalMinor: 9900000),
          _charge(
            excluded,
            null,
            nominalMinor: reference == 'nominal' ? 2630000 : null,
          ),
        ]);
        await pump(tester, pricing);
        final knownRow = _row('known', 0);
        final excludedRow = _row('excluded', 1);
        expect(
          find.descendant(of: knownRow, matching: find.text(r'$ 12.000')),
          findsOneWidget,
        );
        final amount = find.descendant(
          of: excludedRow,
          matching: find.text(
            reference == 'nominal' ? r'$ 26.300' : r'$ 18.500',
          ),
        );
        expect(amount, findsOneWidget);
        expect(
          tester.getTopRight(find.text('2. Peaje excluded')).dx,
          lessThanOrEqualTo(tester.getTopLeft(amount).dx),
        );
        expect(
          find.text('Categoría I · Tarifa de referencia, no sumada'),
          findsOneWidget,
        );
        expect(find.text('COP 12.000'), findsOneWidget);
        expect(find.text(r'$ 12.000'), findsOneWidget);
        expect(find.textContaining('COP 99.000'), findsNothing);
        expect(find.textContaining(r'$ 99.000'), findsNothing);
        expect(find.textContaining('Cobro pendiente'), findsNothing);
        expect(pricing.subtotalMinor, 1200000);
        expect(pricing.totalMinor, isNull);
        expect(pricing.missingRates, 1);
        await _openStation(tester, excluded.id, index: 1);
        expect(find.text('COP 12.000'), findsOneWidget);
        expect(pricing.charges.last.amountMinor, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('missing station coordinates never invent a maps location', (
    tester,
  ) async {
    final sources = <String>[];
    await pump(tester, _pricing([_unknownCharge]), onSource: sources.add);
    await _openStation(tester, 'unknown');
    expect(find.text('Ver ubicación en Google Maps'), findsNothing);
    expect(find.byIcon(Icons.location_on_outlined), findsNothing);
    expect(sources, isEmpty);
    expect(find.textContaining('0,0'), findsNothing);
    expect(find.textContaining('Tarifa no disponible'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  for (final width in [360.0, 390.0, 412.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'long names preserve raw casing and fit width $width scale $scale',
        (tester) async {
          const rawName = 'TÚNEL DEL ORIENTE ESTACIÓN ALTO DE LAS PALMAS';
          const displayName = 'Túnel Del Oriente Estación Alto De Las Palmas';
          const mixedName = 'Peaje de La Pintada - Ruta del Café';
          final uppercase = _station(
            'long-uppercase',
            'Buses',
            32500,
            name: rawName,
          );
          final mixed = _station('long-mixed', 'Buses', 32500, name: mixedName);
          final pricing = _pricing([
            _charge(uppercase, 1850000),
            _charge(mixed, 3250000),
          ]);
          await pump(tester, pricing, width: width, scale: scale);
          for (final (title, amount, index, id) in [
            ('1. $displayName', r'$ 18.500', 0, uppercase.id),
            ('2. $mixedName', r'$ 32.500', 1, mixed.id),
          ]) {
            final nameRect = tester.getRect(find.text(title));
            final amountRect = tester.getRect(
              find.descendant(of: _row(id, index), matching: find.text(amount)),
            );
            expect(nameRect.left, greaterThanOrEqualTo(16));
            expect(nameRect.right, lessThanOrEqualTo(width - 16));
            expect(amountRect.right, lessThanOrEqualTo(width - 16));
            expect(nameRect.overlaps(amountRect), isFalse);
          }
          expect(find.text('COP 51.000'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await _openStation(tester, uppercase.id);
          expect(find.text('1. $displayName'), findsOneWidget);
          expect(find.text('2. $mixedName'), findsOneWidget);
          expect(find.text('COP 51.000'), findsOneWidget);
          expect(pricing.totalMinor, 5100000);
          expect(pricing.charges.map((charge) => charge.name), [
            rawName,
            mixedName,
          ]);
          expect(uppercase.name, rawName);
          expect(mixed.name, mixedName);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'Seminario expanded fits width $width scale $scale with conditions toggled',
        (tester) async {
          final station = catalog.byId('SUP-SEMINARIO-5823DA6561')!;
          final sources = <String>[];
          await pump(
            tester,
            _pricing([_charge(station, null, nominalMinor: 2630000)]),
            width: width,
            scale: scale,
            onSource: sources.add,
          );
          await _openStation(tester, station.id);
          expect(find.text('1. Seminario'), findsOneWidget);
          expect(station.name, 'SEMINARIO');
          expect(find.byType(DropdownButtonFormField<String>), findsNothing);
          for (final rate in station.generalRates) {
            expect(
              find.descendant(
                of: find.byType(TripTollChargeDetails),
                matching: find.text('Categoría ${rate.categoryCode}'),
              ),
              findsOneWidget,
            );
            expect(find.text(rate.vehicleDescription!), findsNothing);
            if (rate.amountMinor != null) {
              const displayedRates = {
                'I': r'$ 26.300',
                'II': r'$ 32.900',
                'III': r'$ 58.600',
                'IV': r'$ 65.300',
                'V': r'$ 72.500',
                'VI': r'$ 87.100',
              };
              expect(
                find.text(displayedRates[rate.categoryCode]!),
                findsWidgets,
              );
            }
          }
          final condition = find.textContaining('Cobro por sentido: no sumar');
          expect(condition, findsNothing);
          expect(
            find.textContaining('Descripción no disponible'),
            findsNothing,
          );
          expect(find.textContaining('Fuente · categoría'), findsNothing);
          expect(find.text('Condiciones y fuentes'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await _tapText(tester, 'Condiciones y fuentes');
          expect(condition, findsWidgets);
          expect(
            find.textContaining('Descripción no disponible'),
            findsWidgets,
          );
          expect(find.textContaining('Fuente · categoría'), findsWidgets);
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(condition.first);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await _tapText(tester, 'Condiciones y fuentes');
          expect(condition, findsNothing);
          expect(
            find.textContaining('Descripción no disponible'),
            findsNothing,
          );
          expect(sources, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

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
          'unknown' => _pricing([_unknownCharge]),
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
            'unknown' => 'Total por confirmar',
            'unsupported' => 'Categoría por confirmar',
            _ => 'Sin pasos identificados',
          }),
          findsOneWidget,
        );
        expect(find.textContaining('COP 0'), findsNothing);
        expect(find.textContaining(r'$ 0'), findsNothing);
        expect(find.textContaining('0 peajes'), findsNothing);
        if (state == 'unknown') {
          expect(find.text('Categoría I'), findsOneWidget);
          expect(find.textContaining('Tarifa no disponible'), findsWidgets);
          expect(find.textContaining('Tarifa de referencia'), findsNothing);
          expect(find.textContaining('Cobro pendiente'), findsNothing);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}

TollTariffStation _station(
  String id,
  String? descriptionII,
  int? amountII, {
  String? name,
}) => TollTariffStation.fromJson({
  'id': id,
  'name': name ?? 'Peaje $id',
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

LocalTollPricingCharge _charge(
  TollTariffStation station,
  int? amount, {
  int? nominalMinor,
}) => LocalTollPricingCharge(
  stationId: station.id,
  name: station.name,
  categoryCode: 'I',
  amountMinor: amount,
  nominalMinor: nominalMinor,
  publicationControl: station.publicationControl,
  sourceType: 'Oficial',
  sourceDate: '2026-09-01',
  sourceUrl: station.categoryI?.amountSourceUrl,
  station: station,
);

const _unknownCharge = LocalTollPricingCharge(
  stationId: 'unknown',
  name: 'Peaje sin datos',
  categoryCode: 'I',
  amountMinor: null,
  publicationControl: null,
  sourceType: null,
  sourceDate: null,
  sourceUrl: null,
);

Finder _row(String id, int index) =>
    find.byKey(ValueKey('trip-route-toll-$id-$index'));

Future<void> _openStation(
  WidgetTester tester,
  String id, {
  int index = 0,
}) async {
  final finder = find
      .descendant(of: _row(id, index), matching: find.byType(Text))
      .first;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

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
