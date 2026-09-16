import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/theme/app_theme.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/vehicle_status/data/vehicle_obligation_store.dart';
import 'package:picoradar/features/vehicle_status/data/tax_catalog.dart';
import 'package:picoradar/features/vehicle_status/domain/vehicle_obligation.dart';
import 'package:picoradar/features/vehicle_status/presentation/vehicle_status_screen.dart';
import 'package:picoradar/features/vehicle_status/presentation/tax_owner_content.dart';

import '../../../test_app_harness.dart';
import '../../../plate_test_fonts.dart';
import 'v01b_obligations_test_font.dart';

late TaxCatalog _catalog;
late String _catalogSource;

void main() {
  setUpAll(() async {
    await loadPlateTestFonts();
    await loadV01bObligationsTestFont();
    _catalogSource = await rootBundle.loadString(bundledTaxCatalogAsset);
    _catalog = TaxCatalog.fromJsonString(_catalogSource);
  });

  testWidgets('tax authority selection previews until explicitly saved', (
    tester,
  ) async {
    final harness = TestAppHarness();
    addTearDown(harness.dispose);
    final vehicle = await _open(tester, harness);
    await tester.tap(find.byKey(const ValueKey('tax-authority-field')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('tax-authority-search')),
      'Antioquia',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tax-authority-antioquia')));
    await tester.pumpAndSettle();
    final store = VehicleObligationStore(harness.database);
    expect(await store.get(vehicle.id, VehicleObligationType.tax), isNull);
    expect(find.text('Consulta temporal'), findsOneWidget);
    final save = find.byKey(const ValueKey('tax-save-authority'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(
      (await store.get(
        vehicle.id,
        VehicleObligationType.tax,
      ))?.details['authorityId'],
      'antioquia',
    );
    expect(find.text('Consulta temporal'), findsNothing);
  });

  testWidgets('tax history is grouped instead of repeating past labels', (
    tester,
  ) async {
    final harness = TestAppHarness();
    addTearDown(harness.dispose);
    await _open(tester, harness);
    expect(find.byKey(const ValueKey('tax-owner-hero')), findsOneWidget);
    expect(find.textContaining('Ya pasó'), findsNothing);
    final history = find.byKey(const ValueKey('tax-past-dates'));
    await tester.ensureVisible(history);
    await tester.tap(history);
    await tester.pumpAndSettle();
    expect(find.textContaining('Pronto pago'), findsWidgets);
  });

  testWidgets('civil deadline remains today and new year is not extrapolated', (
    tester,
  ) async {
    final harness = TestAppHarness();
    addTearDown(harness.dispose);
    await _open(tester, harness, now: DateTime(2026, 9, 4, 23, 59));
    expect(find.text('Hoy'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TaxOwnerContent)),
    );
    container.updateOverrides([
      taxCatalogProvider.overrideWith((ref) async => _catalog),
      bogotaNowProvider.overrideWithValue(DateTime(2027, 1, 1)),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Calendario 2027'), findsOneWidget);
    expect(find.textContaining('Calendario 2027 pendiente'), findsOneWidget);
    expect(find.text('Hoy'), findsNothing);
    expect(find.byKey(const ValueKey('tax-open-portal')), findsOneWidget);
  });

  for (final kind in [VehicleKind.motorcycle, VehicleKind.car]) {
    testWidgets('tax vehicle applicability remains informative for $kind', (
      tester,
    ) async {
      final harness = TestAppHarness();
      addTearDown(harness.dispose);
      await _open(tester, harness, kind: kind, taxi: kind == VehicleKind.car);
      expect(
        find.textContaining(
          kind == VehicleKind.motorcycle ? 'cilindrada' : 'servicio público',
        ),
        findsOneWidget,
      );
      expect(find.text('No aplica'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('expired review instant warns during the same civil day', (
    tester,
  ) async {
    final harness = TestAppHarness()..now = DateTime.utc(2026, 9, 13, 18);
    addTearDown(harness.dispose);
    final json = jsonDecode(_catalogSource) as Map<String, dynamic>;
    final calendar = (json['calendars'] as List).firstWhere(
      (c) => c['authorityId'] == 'bogota',
    );
    calendar['reviewAfter'] = '2026-09-13T12:00:00Z';
    await _open(tester, harness, catalog: TaxCatalog.fromJson(json));
    expect(find.textContaining('requiere una nueva revisión'), findsOneWidget);
  });

  testWidgets('published additional concepts and sources remain accessible', (
    tester,
  ) async {
    final harness = TestAppHarness();
    addTearDown(harness.dispose);
    final json = jsonDecode(_catalogSource) as Map<String, dynamic>;
    final calendars = json['calendars'] as List;
    final extra = jsonDecode(
      jsonEncode(calendars.firstWhere((c) => c['authorityId'] == 'bogota')),
    ) as Map<String, dynamic>;
    extra['id'] = 'fixture-semaforizacion';
    extra['obligationKind'] = 'semaforizacion';
    extra['events'] = [
      {
        ...(extra['events'] as List).first as Map<String, dynamic>,
        'id': 'fixture-event',
        'label': 'Fecha de otro concepto verificada en fixture',
      },
    ];
    calendars.add(extra);
    await _open(tester, harness, catalog: TaxCatalog.fromJson(json));
    final concept = find.text('Semaforización');
    await tester.ensureVisible(concept);
    await tester.tap(concept);
    await tester.pumpAndSettle();
    expect(
      find.text('Fecha de otro concepto verificada en fixture'),
      findsOneWidget,
    );
  });

  testWidgets('registered island municipality resolves by territorial alias', (
    tester,
  ) async {
    final harness = TestAppHarness();
    addTearDown(harness.dispose);
    await _open(
      tester,
      harness,
      registration: 'San Andrés - Archipielago De San Andres, Providencia',
    );
    expect(
      find.text('San Andrés, Providencia y Santa Catalina'),
      findsOneWidget,
    );
  });

  for (final size in [
    const Size(360, 780),
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915),
    const Size(430, 932),
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('tax layout ${size.width}x${size.height} text $scale', (
        tester,
      ) async {
        final harness = TestAppHarness();
        addTearDown(harness.dispose);
        await _open(tester, harness, size: size, scale: scale);
        expect(tester.takeException(), isNull);
        await _capture(tester, 'tax-${size.width.toInt()}-$scale');
        final hero = tester.getRect(
          find.byKey(const ValueKey('tax-owner-hero')),
        );
        final name = tester.getRect(
          find.byKey(const ValueKey('tax-authority-name')),
        );
        final plate = tester.getRect(
          find.byKey(const ValueKey('tax-vehicle-plate')),
        );
        expect(hero.contains(name.topLeft), isTrue);
        expect(name.overlaps(plate), isFalse);
        expect(plate.width / plate.height, greaterThan(1.7));
        await tester.ensureVisible(
          find.byKey(const ValueKey('tax-authority-field')),
        );
        expect(
          tester
              .getSize(find.byKey(const ValueKey('tax-authority-field')))
              .height,
          greaterThanOrEqualTo(48),
        );
        await tester.tap(find.byKey(const ValueKey('tax-authority-field')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('tax-authority-search')),
          'Santander',
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final option = find.text('Norte de Santander');
        await tester.ensureVisible(option);
        await tester.tap(option);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final element in find.byType(RichText).evaluate()) {
          final render = element.renderObject;
          if (render is RenderParagraph) {
            expect(render.didExceedMaxLines, isFalse);
          }
        }
        await tester.ensureVisible(find.byKey(const ValueKey('tax-source')));
        await tester.tap(find.byKey(const ValueKey('tax-source')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}

Future<VehicleProfile> _open(
  WidgetTester tester,
  TestAppHarness harness, {
  Size size = const Size(390, 844),
  double scale = 1,
  DateTime? now,
  VehicleKind kind = VehicleKind.car,
  bool taxi = false,
  TaxCatalog? catalog,
  String registration = 'Bogotá D.C.',
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final vehicle = await harness.repository.createVehicle(
    plate: kind == VehicleKind.motorcycle ? 'ZVV73D' : 'BOG127',
    kind: kind,
    serviceType: taxi ? VehicleServiceType.taxi : VehicleServiceType.private,
    registrationCity: registration,
  );
  await harness.pump(
    tester,
    vehicleListOverride: [vehicle],
    activeVehicleOverride: vehicle,
    childOverride: ProviderScope(
      overrides: [
        taxCatalogProvider.overrideWith((ref) async => catalog ?? _catalog),
        bogotaNowProvider.overrideWithValue(now ?? DateTime(2026, 9, 13, 12)),
      ],
      child: MaterialApp(
        theme: buildPicoRadarTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: RepaintBoundary(
          key: const ValueKey('tax-test-capture'),
          child: VehicleStatusScreen(
            moduleId: 'impuestos',
            vehicleId: vehicle.id,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return vehicle;
}

Future<void> _capture(WidgetTester tester, String name) async {
  final directory = Platform.environment['TAX_CAPTURE_DIR'];
  if (directory == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('tax-test-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(directory).create(recursive: true);
      await File('$directory/$name.png')
          .writeAsBytes(data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
