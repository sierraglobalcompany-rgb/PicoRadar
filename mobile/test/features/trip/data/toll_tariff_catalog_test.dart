import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/trip/data/toll_inventory.dart';
import 'package:picoradar/features/trip/data/toll_tariff_catalog.dart';

late TollTariffCatalog catalog;
late TollInventoryDataset inventory;

void main() {
  setUpAll(() {
    catalog = TollTariffCatalog.fromJsonString(
      File('assets/catalogs/tolls_tariffs_v1.json').readAsStringSync(),
    );
    inventory = TollInventoryDataset.fromJsonString(
      File('assets/catalogs/tolls_inventory_v1.json').readAsStringSync(),
    );
  });

  test(
    'parses audited owner tariff catalog without modifying inventory v1',
    () {
      expect(catalog.version, '2026.09.08-upload-a');
      expect(catalog.currency, 'COP');
      expect(catalog.amountUnit, 'whole_pesos');
      expect(catalog.counts.stations, 184);
      expect(catalog.counts.generalRates, 1300);
      expect(catalog.counts.numericGeneralRates, 1007);
      expect(catalog.counts.officialGeneralRates, 793);
      expect(catalog.counts.secondaryGeneralRates, 214);
      expect(catalog.counts.specialRates, 437);
      expect(catalog.counts.candidatesOutsideBase, 9);
      expect(inventory.records, hasLength(184));
      expect(inventory.knownTariffCount, 0);
    },
  );

  test('keeps audited category I examples in whole pesos and minor units', () {
    expect(_amount('INV-GUARNE-3A941FAFD9', 'I'), 18500);
    expect(_minor('INV-GUARNE-3A941FAFD9', 'I'), 1850000);
    expect(_amount('INV-LAS-PALMAS-E8C2EE2BB5', 'I'), 13500);
    expect(_amount('INV-COCORNA-6A6F1282D1', 'I'), 18800);
    expect(
      catalog
          .byId('INV-COCORNA-6A6F1282D1')!
          .generalRateByCategory('I')!
          .hasSecondarySource,
      isTrue,
    );
    expect(_amount('INV-AMAGA-ABD7881C50', 'I'), 25900);
  });

  test('preserves nominal, base and multiplier separately', () {
    final losSantos = catalog.byId('INV-LOS-SANTOS-85453C31BB')!;
    final auto = losSantos.generalRateByCategory('AUTOMOVIL')!;

    expect(auto.amountCop, 9000);
    expect(auto.boothBaseChargeCop, 18000);
    expect(auto.collectionMultiplier, 2);
    expect(auto.amountMinor, 900000);
    expect(auto.boothBaseChargeMinor, 1800000);
    expect(auto.hasSecondarySource, isTrue);
  });

  test('preserves null as not informed and documented zero as zero', () {
    final papiros = catalog.byId('INV-PAPIROS-2F4F657C0E')!;
    final papirosI = papiros.generalRateByCategory('I')!;
    final turbaco = catalog.byId('INV-TURBACO-E6A3364829')!;
    final turbacoI = turbaco.generalRateByCategory('I')!;

    expect(papiros.publicationControl, 'APLICAR_SUSPENSION_PARCIAL');
    expect(papirosI.amountCop, isNull);
    expect(papirosI.boothBaseChargeCop, 0);
    expect(turbaco.publicationControl, 'APLICAR_SUSPENSION_PARCIAL');
    expect(turbacoI.amountCop, 5800);
    expect(turbacoI.boothBaseChargeCop, 0);
  });

  test('search exposes tariffs without route provider', () {
    final results = catalog.search('guarne');

    expect(results.first.id, 'INV-GUARNE-3A941FAFD9');
    expect(results.first.categoryI!.amountCop, 18500);
  });

  test('prices only explicit passages and reports partial coverage', () {
    final known = inventory.records.firstWhere(
      (record) => record.id == 'INV-GUARNE-3A941FAFD9',
    );
    final missing = inventory.records.firstWhere(
      (record) => record.id == 'INV-PAPIROS-2F4F657C0E',
    );

    final complete = priceExplicitTollPassages(
      catalog: catalog,
      passages: [known],
      operatorCategoryCode: 'I',
    );
    expect(complete.coverage, LocalTollPricingCoverage.complete);
    expect(complete.totalMinor, 1850000);

    final partial = priceExplicitTollPassages(
      catalog: catalog,
      passages: [known, missing],
      operatorCategoryCode: 'I',
    );
    expect(partial.coverage, LocalTollPricingCoverage.partial);
    expect(partial.subtotalMinor, 1850000);
    expect(partial.totalMinor, isNull);
    expect(partial.missingRates, 1);
  });
}

int? _amount(String stationId, String category) =>
    catalog.byId(stationId)!.generalRateByCategory(category)!.amountCop;

int? _minor(String stationId, String category) =>
    catalog.byId(stationId)!.generalRateByCategory(category)!.amountMinor;
