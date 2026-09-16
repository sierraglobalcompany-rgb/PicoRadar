import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/shell/app_shell.dart' show AppTab;
import 'package:picoradar/app/theme/app_theme.dart';
import 'package:picoradar/core/design_system/navigation.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/onboarding/data/registration_city_catalog.dart';
import 'package:picoradar/features/vehicle_status/data/insurance_directory.dart';
import 'package:picoradar/features/vehicle_status/domain/vehicle_obligation.dart';
import 'package:picoradar/features/vehicle_status/presentation/insurance_owner_content.dart';
import 'package:picoradar/features/visual_assets/data/visual_asset_catalogs.dart';

import '../../../plate_test_fonts.dart';

final _date = DateTime(2026, 9, 13);
final _car = VehicleProfile(
  id: 'car',
  plate: 'BOG127',
  kind: VehicleKind.car,
  serviceType: VehicleServiceType.private,
  registrationCity: 'Bogotá',
  brand: 'Chevrolet',
  createdAt: _date,
  updatedAt: _date,
);
final _moto = VehicleProfile(
  id: 'moto',
  plate: 'ZVV73D',
  kind: VehicleKind.motorcycle,
  serviceType: VehicleServiceType.private,
  nickname: 'Mi moto para viajar',
  createdAt: _date,
  updatedAt: _date,
);
final _catalog = VehicleVisualCatalog.fromJson(
  jsonDecode(File(vehicleCatalogAssetPath).readAsStringSync())
      as Map<String, Object?>,
);
final _registration = RegistrationCityCatalog.fromJson(
  jsonDecode(File(registrationCityCatalogAssetPath).readAsStringSync())
      as Map<String, Object?>,
);
VehicleObligation _policy(String id) => VehicleObligation(
  id: '$id:insurance',
  vehicleId: id,
  type: VehicleObligationType.insurance,
  reminderEnabled: false,
  createdAt: _date,
  updatedAt: _date,
  details: const {'providerName': 'SURA', 'policyNumber': 'QA-POLICY'},
  dueDate: DateTime(2027, 9, 13),
);

void main() {
  setUpAll(loadPlateTestFonts);
  testWidgets(
    'small plate gives the vehicle more room without changing banner',
    (tester) async {
      final legacyMoto = VehicleProfile(
        id: 'legacy-moto',
        plate: 'GHGGH3453',
        kind: VehicleKind.motorcycle,
        serviceType: VehicleServiceType.private,
        createdAt: _date,
        updatedAt: _date,
      );
      await _pump(
        tester,
        size: const Size(360, 780),
        insets: const EdgeInsets.only(top: 35, bottom: 48),
        vehicles: [_car, legacyMoto],
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('insurance-banner'))).height,
        closeTo(279, .5),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('insurance-plate'))).width,
        80,
      );
      final number = tester.renderObject<RenderParagraph>(
        find.byKey(const ValueKey('colombian-plate-first-group')),
      );
      final numberHeight =
          (number.localToGlobal(Offset(0, number.size.height)) -
                  number.localToGlobal(Offset.zero))
              .distance;
      expect(
        numberHeight,
        greaterThanOrEqualTo(17),
        reason: 'The small plate must not shrink its number to 11 dp',
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('insurance-vehicle-carousel')))
            .height,
        greaterThanOrEqualTo(143),
        reason: 'Another approximately 30% above the approved 112 dp art slot',
      );
      _geometry(tester);
      await tester.drag(
        find.byKey(const ValueKey('insurance-vehicle-carousel')),
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();
      final plate = tester.getSize(
        find.byKey(const ValueKey('insurance-plate')),
      );
      expect(plate.aspectRatio, closeTo(2.15, .01));
      _geometry(tester);
    },
  );
  testWidgets('Mi A3 safe areas retain banner with long vehicle names', (
    tester,
  ) async {
    final fixture = VehicleProfile(
      id: 'physical-layout',
      plate: 'QAQ014',
      kind: VehicleKind.car,
      serviceType: VehicleServiceType.private,
      nickname: 'QA-SEGURO-PORTADA',
      registrationCity: 'Bogotá - Bogotá D.C.',
      createdAt: _date,
      updatedAt: _date,
    );
    await _pump(
      tester,
      size: const Size(360, 780),
      insets: const EdgeInsets.only(top: 35, bottom: 48),
      vehicles: [_car, _moto, fixture],
    );
    expect(
      find.text('Encuentra opciones\npara asegurar\ntu vehículo'),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('insurance-banner'))).height,
      greaterThanOrEqualTo(275),
      reason: 'Owner requested about 50% above the physical 186 dp banner',
    );
    _geometry(tester);
  });
  testWidgets('registered city catalog labels do not overbudget the plate', (
    tester,
  ) async {
    final city = _registration.records.firstWhere(
      (c) => c.municipality == 'Bogotá',
    );
    final full = VehicleProfile(
      id: 'city-label',
      plate: 'BOG127',
      kind: VehicleKind.car,
      serviceType: VehicleServiceType.private,
      registrationCity: city.displayName,
      brand: 'Chevrolet',
      createdAt: _date,
      updatedAt: _date,
    );
    await _pump(
      tester,
      size: const Size(360, 780),
      vehicles: [full],
      incoming: full.id,
    );
    final height = tester
        .getSize(find.byKey(const ValueKey('insurance-banner')))
        .height;
    final art = tester
        .getSize(find.byKey(const ValueKey('insurance-vehicle-carousel')))
        .height;
    await tester.pumpWidget(const SizedBox.shrink());
    await _pump(
      tester,
      size: const Size(360, 780),
      vehicles: [_car],
      incoming: _car.id,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('insurance-banner'))).height,
      height,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('insurance-vehicle-carousel')))
          .height,
      closeTo(art, .5),
    );
    _geometry(tester);
  });
  for (final size in const [
    Size(360, 780),
    Size(360, 800),
    Size(390, 844),
    Size(412, 915),
    Size(430, 932),
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      for (final configured in [false, true]) {
        testWidgets(
          'single insurance home $size text $scale configured $configured',
          (tester) async {
            final semantics = tester.ensureSemantics();
            try {
              await _pump(
                tester,
                size: size,
                scale: scale,
                configured: configured,
              );
              _geometry(tester);
              if (const bool.fromEnvironment('INSURANCE_SCREENSHOTS') &&
                  size.width == 360 &&
                  (scale == 1 || scale == 2)) {
                await _capture(
                  tester,
                  'home-${size.height.toInt()}-$scale-$configured',
                );
              }
              _expectSingleHome(tester);
              if (scale == 1) {
                expect(
                  find.text(
                    configured
                        ? 'Compara opciones\npara tu próxima\npóliza'
                        : 'Encuentra opciones\npara asegurar\ntu vehículo',
                  ),
                  findsOneWidget,
                  reason: 'Compact actions must not remove the promotional headline',
                );
                expect(
                  find.text(
                    configured
                        ? 'Consulta coberturas y formas de pago con un aliado.'
                        : 'Solicita una cotización con un aliado de seguros.',
                  ),
                  findsOneWidget,
                  reason: 'Restore the approved mockup supporting copy',
                );
              }
              expect(
                find.bySemanticsLabel(
                  RegExp(
                    configured ? 'Comparar mi póliza' : 'Cotizar mi póliza',
                  ),
                ),
                findsWidgets,
                reason: 'Compact quote labels keep their full accessible name',
              );
              if (scale > 1) {
                final readable = find.byKey(
                  const ValueKey('insurance-readable-plate'),
                );
                expect(readable, findsOneWidget);
                expect(tester.widget<Text>(readable).data, _car.plate);
              }
              final plate = tester.getRect(
                find.byKey(const ValueKey('insurance-plate')),
              );
              expect(plate.width, 80);
              expect(plate.width, greaterThan(plate.height));
              expect(
                find
                    .byKey(const ValueKey('insurance-assistance'))
                    .hitTestable(),
                findsOneWidget,
              );
            } finally {
              semantics.dispose();
            }
          },
        );
      }
    }
  }
  testWidgets('public UI cannot show commercial demo', (tester) async {
    await _pump(tester, preview: false);
    expect(find.byKey(const ValueKey('insurance-quote')), findsNothing);
    expect(find.text('Patrocinado'), findsNothing);
    _expectSingleHome(tester, preview: false);
    _geometry(tester);
  });
  testWidgets('policy failure remains actionable with enlarged text', (
    tester,
  ) async {
    await _pump(tester, scale: 2, policyFailure: true);
    expect(
      find.byTooltip('No se pudo leer la póliza. Reintentar'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('insurance-register')), findsNothing);
    _geometry(tester);
  });
  testWidgets('policy retry recovers the selected vehicle on the same home', (
    tester,
  ) async {
    var failed = true;
    await _pump(
      tester,
      scale: 2,
      incoming: _moto.id,
      loadPolicy: (id) async {
        if (failed) throw StateError('Fixture failed');
        return _policy(id);
      },
    );
    final carousel = find.byKey(const ValueKey('insurance-vehicle-carousel'));
    final controller = tester.widget<PageView>(carousel).controller!;
    expect(find.byKey(const ValueKey('insurance-register')), findsNothing);
    failed = false;
    await tester.tap(find.byTooltip('No se pudo leer la póliza. Reintentar'));
    await tester.pumpAndSettle();
    expect(
      find.byTooltip('No se pudo leer la póliza. Reintentar'),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('insurance-edit')), findsOneWidget);
    expect(tester.widget<PageView>(carousel).controller, same(controller));
    expect(controller.page, closeTo(1, .001));
    _geometry(tester);
  });
  for (final favoriteFailure in [false, true]) {
    testWidgets('vehicle loading failure retries favorite $favoriteFailure', (
      tester,
    ) async {
      var failed = true;
      await _pump(
        tester,
        loadVehicles: () async {
          if (failed && !favoriteFailure) {
            throw StateError('Garage fixture failed');
          }
          return [_car, _moto];
        },
        loadActive: () async {
          if (failed && favoriteFailure) {
            throw StateError('Favorite fixture failed');
          }
          return _car;
        },
      );
      expect(
        find.text(
          favoriteFailure
              ? 'No se pudo leer el vehículo favorito.'
              : 'No se pudieron leer los vehículos.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('insurance-plate')), findsNothing);
      failed = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      _expectSingleHome(tester);
      _geometry(tester);
    });
  }
  testWidgets('explicit vehicle does not depend on favorite availability', (
    tester,
  ) async {
    await _pump(
      tester,
      incoming: _moto.id,
      loadActive: () async {
        throw StateError('Favorite fixture failed');
      },
    );
    expect(find.text(_moto.nickname!), findsOneWidget);
    expect(find.text('No se pudo leer el vehículo favorito.'), findsNothing);
    _expectSingleHome(tester);
    _geometry(tester);
  });
  for (final scale in [1.0, 1.5, 2.0]) {
    for (final taxi in [false, true]) {
      testWidgets('long vehicle name taxi $taxi scale $scale', (tester) async {
        final vehicle = VehicleProfile(
          id: 'long',
          plate: taxi ? 'KZA123' : 'ZVV73D',
          kind: taxi ? VehicleKind.car : VehicleKind.motorcycle,
          serviceType: taxi
              ? VehicleServiceType.taxi
              : VehicleServiceType.private,
          nickname: 'Mi vehículo para viajes familiares',
          createdAt: _date,
          updatedAt: _date,
        );
        await _pump(
          tester,
          size: const Size(360, 780),
          scale: scale,
          vehicles: [vehicle],
          incoming: vehicle.id,
        );
        _geometry(tester);
        _expectSingleHome(tester);
        final semantics = tester.ensureSemantics();
        try {
          expect(
            find.bySemanticsLabel(RegExp(RegExp.escape(vehicle.nickname!))),
            findsWidgets,
          );
        } finally {
          semantics.dispose();
        }
        expect(
          tester.getSize(find.byKey(const ValueKey('insurance-plate'))).width,
          80,
        );
        expect(
          tester
              .getSize(find.byKey(const ValueKey('insurance-vehicle-carousel')))
              .height,
          greaterThanOrEqualTo(48),
        );
      });
    }
  }
  testWidgets('extra height grows vehicle instead of controls', (tester) async {
    await _pump(tester, size: const Size(390, 844), preview: false);
    final carousel = find.byKey(const ValueKey('insurance-vehicle-carousel'));
    final initial = tester.getSize(carousel).height;
    final footer = tester.getSize(
      find.byKey(const ValueKey('insurance-assistance')),
    );
    tester.view.physicalSize = const Size(390, 944);
    await tester.pumpAndSettle();
    expect(tester.getSize(carousel).height - initial, closeTo(100, 1));
    expect(
      tester.getSize(find.byKey(const ValueKey('insurance-assistance'))),
      footer,
    );
    _geometry(tester);
  });
  testWidgets('explicit missing ID is not substituted with favorite', (
    tester,
  ) async {
    await _pump(tester, incoming: 'removed');
    expect(find.text('Este vehículo ya no está disponible.'), findsOneWidget);
    expect(find.byKey(const ValueKey('insurance-plate')), findsNothing);
    expect(
      find.byKey(const ValueKey('insurance-assistance')).hitTestable(),
      findsOneWidget,
    );
  });
  testWidgets('empty garage retains directory and assistance', (tester) async {
    await _pump(tester, vehicles: const []);
    expect(find.text('Agregar vehículo'), findsOneWidget);
    expect(find.text('Directorio'), findsOneWidget);
    expect(find.text('Asistencia'), findsOneWidget);
  });
  testWidgets(
    'switch preserves controller and updates policy without favorite writes',
    (tester) async {
      await _pump(tester, size: const Size(430, 932), configured: true);
      final carousel = find.byKey(const ValueKey('insurance-vehicle-carousel'));
      final controller = tester.widget<PageView>(carousel).controller;
      final container = ProviderScope.containerOf(
        tester.element(find.byType(InsuranceOwnerScreen)),
      );
      await tester.tap(
        find.byKey(const ValueKey('insurance-vehicle-selector')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mi moto para viajar').last);
      await tester.pumpAndSettle();
      expect(tester.widget<PageView>(carousel).controller, same(controller));
      expect(controller!.page, closeTo(1, .001));
      expect(find.byKey(const ValueKey('insurance-register')), findsOneWidget);
      expect(find.byKey(const ValueKey('insurance-quote')), findsOneWidget);
      expect((await container.read(activeVehicleProvider.future))?.id, 'car');
      expect(tester.takeException(), isNull);
    },
  );
}

void _expectSingleHome(WidgetTester tester, {bool preview = true}) {
  expect(find.byType(AppBar), findsNothing);
  expect(find.text('Seguro y asistencia'), findsNothing);
  expect(find.byType(TabBar), findsNothing);
  expect(find.byType(TabBarView), findsNothing);
  expect(find.text('Resumen'), findsNothing);
  expect(find.byType(PageView), findsOneWidget);
  final banner = find.byKey(const ValueKey('insurance-banner'));
  final back = find.byKey(const ValueKey('insurance-back'));
  final surface = find.byKey(const ValueKey('insurance-back-surface'));
  expect(back.hitTestable(), findsOneWidget);
  expect(tester.getSize(back), const Size(48, 48));
  expect(tester.getSize(surface), const Size(36, 36));
  expect(tester.getRect(back).contains(tester.getRect(surface).center), isTrue);
  if (preview) {
    expect(find.descendant(of: banner, matching: back), findsOneWidget);
    expect(
      find.byKey(const ValueKey('insurance-quote')).hitTestable(),
      findsOneWidget,
    );
  }
  for (final key in [
    'insurance-vehicle-carousel',
    'insurance-vehicle-name',
    'insurance-policy-panel',
    'insurance-footer',
  ]) {
    expect(find.byKey(ValueKey(key)), findsOneWidget);
  }
  final ordered = [
    if (preview) 'insurance-banner',
    'insurance-vehicle-name',
    'insurance-vehicle-carousel',
    'insurance-plate',
    'insurance-policy-panel',
    'insurance-footer',
  ];
  for (var i = 1; i < ordered.length; i++) {
    expect(
      tester.getRect(find.byKey(ValueKey(ordered[i - 1]))).bottom,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(ValueKey(ordered[i]))).top + .5,
      ),
      reason: '${ordered[i - 1]} must not overlap ${ordered[i]}',
    );
  }
}

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double scale = 1,
  EdgeInsets insets = const EdgeInsets.only(top: 24, bottom: 24),
  bool configured = false,
  bool preview = true,
  bool policyFailure = false,
  String? incoming,
  List<VehicleProfile>? vehicles,
  Future<List<VehicleProfile>> Function()? loadVehicles,
  Future<VehicleProfile?> Function()? loadActive,
  Future<VehicleObligation?> Function(String id)? loadPolicy,
}) async {
  final items = vehicles ?? [_car, _moto];
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        insurancePreviewProvider.overrideWithValue(preview),
        insuranceDirectoryProvider.overrideWith(
          (ref) => Future<InsuranceDirectory>.error(
            StateError('Fixture unavailable'),
          ),
        ),
        vehicleListProvider.overrideWith(
          (ref) async => loadVehicles == null ? items : await loadVehicles(),
        ),
        activeVehicleProvider.overrideWith(
          (ref) async => loadActive != null
              ? await loadActive()
              : items.isEmpty
              ? null
              : _car,
        ),
        vehicleObligationProvider.overrideWith((ref, key) async {
          if (loadPolicy != null) return loadPolicy(key.$1);
          if (policyFailure) throw StateError('Fixture failed');
          return configured && key.$1 == 'car' ? _policy(key.$1) : null;
        }),
        vehicleVisualCatalogProvider.overrideWithValue(
          AsyncValue.data(_catalog),
        ),
        registrationCityCatalogProvider.overrideWith(
          (ref) async => _registration,
        ),
        vehicleVisualOverrideProvider.overrideWith((ref, id) async => null),
      ],
      child: MaterialApp(
        theme: buildPicoRadarTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            padding: insets,
            viewPadding: insets,
          ),
          child: child!,
        ),
        home: RepaintBoundary(
          key: const ValueKey('insurance-preview'),
          child: Scaffold(
            body: InsuranceOwnerScreen(vehicleId: incoming),
            bottomNavigationBar: AppBottomNav(
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
              currentIndex: AppTab.apps.index,
              onSelect: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _geometry(WidgetTester tester) {
  expect(tester.takeException(), isNull);
  for (final e in find.byType(Scrollable).evaluate()) {
    final s = (e as StatefulElement).state as ScrollableState;
    expect(
      s.position.axis,
      Axis.horizontal,
      reason: 'No vertical portada scroll',
    );
  }
  final content = tester.getRect(
    find.byKey(const ValueKey('insurance-owner-content')),
  );
  for (final key in [
    'insurance-back',
    'insurance-assistance',
    'insurance-directory-or-docs',
    'insurance-vehicle-selector',
  ]) {
    final f = find.byKey(ValueKey(key));
    final r = tester.getRect(f);
    expect(r.height, greaterThanOrEqualTo(48));
    expect(r.bottom, lessThanOrEqualTo(content.bottom + .1));
    expect(r.top, greaterThanOrEqualTo(content.top - .1));
    expect(r.left, greaterThanOrEqualTo(content.left - .1));
    expect(r.right, lessThanOrEqualTo(content.right + .1));
    expect(f.hitTestable(), findsOneWidget);
  }
  for (final element
      in find
          .descendant(
            of: find.byKey(const ValueKey('insurance-owner-content')),
            matching: find.byType(RichText),
          )
          .evaluate()) {
    // The approved fixed plate has its own fidelity suite and font metrics.
    var inPlate = false;
    var semanticText = false;
    var fittedText = false;
    element.visitAncestorElements((ancestor) {
      if (ancestor.widget is Text) semanticText = true;
      if (ancestor.widget is FittedBox) fittedText = true;
      if (ancestor.widget.runtimeType.toString() == 'VehiclePlateBadge') {
        inPlate = true;
      }
      return !inPlate;
    });
    if (inPlate) continue;
    final p = element.renderObject! as RenderParagraph;
    if (semanticText) {
      expect(fittedText, isFalse, reason: 'Do not shrink semantic text to fit');
      expect(
        p.textScaler.scale(14),
        closeTo(
          MediaQuery.textScalerOf(
            tester.element(find.byType(InsuranceOwnerScreen)),
          ).scale(14),
          .01,
        ),
        reason:
            'Semantic text must honor the requested scale: ${p.text.toPlainText()}',
      );
    }
    expect(p.didExceedMaxLines, isFalse, reason: p.text.toPlainText());
    // A wrapped trailing space can have selection bounds outside the line.
    // Measure every visible word, without treating that invisible advance as ink.
    final boxes = [
      for (final word in RegExp(r'\S+').allMatches(p.text.toPlainText()))
        ...p.getBoxesForSelection(
          TextSelection(baseOffset: word.start, extentOffset: word.end),
        ),
    ];
    for (final b in boxes) {
      expect(b.left, greaterThanOrEqualTo(-.5), reason: p.text.toPlainText());
      expect(
        b.right,
        lessThanOrEqualTo(p.size.width + .5),
        reason: p.text.toPlainText(),
      );
      expect(
        b.bottom,
        lessThanOrEqualTo(p.size.height + .5),
        reason: p.text.toPlainText(),
      );
    }
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('insurance-preview')),
  );
  await tester.runAsync(() async {
    final pic = await boundary.toImage(pixelRatio: 2);
    final data = await pic.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('../temp-insurance-preview');
    await dir.create(recursive: true);
    await File('${dir.path}/$name.png')
        .writeAsBytes(data!.buffer.asUint8List());
    pic.dispose();
  });
}
