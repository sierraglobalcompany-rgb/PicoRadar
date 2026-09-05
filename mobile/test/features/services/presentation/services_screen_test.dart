import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/theme/app_theme.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/services/presentation/services_screen.dart';
import 'package:picoradar/features/vehicle_status/platform/external_launcher.dart';

import 'v01b_tools_test_font.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadV01bToolsTestFont);
  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915),
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'V01B S02 repeated heading uses compact readable geometry $size/$scale',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await _pumpServices(
            tester,
            activeVehicle: _vehicle(registrationCity: 'Cali'),
          );
          final heading = tester.renderObject<RenderParagraph>(
            find.text('Servicios para tu vehículo'),
          );
          final metrics = TextPainter(
            text: heading.text,
            textDirection: heading.textDirection,
            textScaler: heading.textScaler,
          )..layout(maxWidth: heading.size.width);
          if (scale == 1) {
            expect(
              metrics.computeLineMetrics(),
              hasLength(1),
              reason: 'Repeated heading should not push city/actions down with a second line at normal scale',
            );
          }
          expect(heading.didExceedMaxLines, isFalse);
          expect(metrics.height, lessThanOrEqualTo(heading.size.height + 0.1));
          metrics.dispose();
          final city = find.byKey(const ValueKey('services-city-field'));
          await tester.ensureVisible(city);
          await tester.pumpAndSettle();
          expect(city.hitTestable(), findsOneWidget);
          await tester.enterText(city, 'Pereira');
          expect(find.text('Pereira'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'V01B S02 actions expose working semantic taps $size/$scale',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final semantics = tester.ensureSemantics();
          try {
            final launcher = _FakeExternalLauncher();
            var cdaOpens = 0;
            await _pumpServices(
              tester,
              activeVehicle: _vehicle(registrationCity: 'Cali'),
              externalLauncher: launcher,
              onOpenCda: () => cdaOpens++,
            );
            for (final entry in [
              ('services-open-cda', 'Abrir CDA dentro de PicoRadar'),
              ('services-search-tow', 'Buscar grúa 24 horas'),
              ('services-search-battery', 'Buscar batería'),
              ('services-search-tires', 'Buscar llantas'),
              ('services-search-mechanic', 'Buscar taller mecánico'),
            ]) {
              final action = find.byKey(ValueKey(entry.$1));
              await tester.ensureVisible(action);
              await tester.pumpAndSettle();
              expect(action.hitTestable(), findsOneWidget);
              expect(tester.getSize(action).height, greaterThanOrEqualTo(44));
              final node = tester.getSemantics(find.bySemanticsLabel(entry.$2));
              expect(
                node.getSemanticsData().hasAction(SemanticsAction.tap),
                isTrue,
                reason:
                    '${entry.$1} must be activatable by assistive technology',
              );
              node.owner!.performAction(node.id, SemanticsAction.tap);
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }
            expect(cdaOpens, 1);
            expect(
              launcher.openedUris.map(
                (uri) => Uri.parse(uri).queryParameters['query'],
              ),
              [
                'grúa 24 horas Cali',
                'batería Cali',
                'llantas Cali',
                'taller mecánico Cali',
              ],
            );
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }

  testWidgets('prefills city from active vehicle and keeps required copy', (
    tester,
  ) async {
    await _pumpServices(
      tester,
      activeVehicle: _vehicle(registrationCity: 'Medellín'),
    );

    expect(find.text('Servicios para tu vehículo'), findsOneWidget);
    expect(find.text('Medellín'), findsOneWidget);
    expect(find.text('Abrir CDA dentro de PicoRadar'), findsOneWidget);
    expect(find.text('Buscar grúa 24 horas'), findsOneWidget);
    expect(find.text('Buscar batería'), findsOneWidget);
    expect(find.text('Buscar llantas'), findsOneWidget);
    expect(find.text('Buscar taller mecánico'), findsOneWidget);
    expect(
      find.text(
        'PicoRadar no presta estos servicios ni verifica proveedores en esta versión.\n'
        'Revisa identidad, precio y condiciones antes de contratar.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('editable city is used only for the current external search', (
    tester,
  ) async {
    final launcher = _FakeExternalLauncher();
    final vehicle = _vehicle(registrationCity: 'Bogotá D. C.');

    await _pumpServices(
      tester,
      activeVehicle: vehicle,
      externalLauncher: launcher,
    );

    await tester.enterText(
      find.byKey(const ValueKey('services-city-field')),
      'Chía',
    );
    await tester.tap(find.byKey(const ValueKey('services-search-tow')));
    await tester.pump();

    expect(vehicle.registrationCity, 'Bogotá D. C.');
    final opened = Uri.parse(launcher.openedUris.single);
    expect(opened.scheme, 'https');
    expect(opened.host, 'www.google.com');
    expect(opened.path, '/maps/search/');
    expect(opened.queryParameters, {'api': '1', 'query': 'grúa 24 horas Chía'});
  });

  testWidgets('edited city is not overwritten by later vehicle updates', (
    tester,
  ) async {
    await _pumpServices(
      tester,
      activeVehicle: _vehicle(registrationCity: 'Medellín'),
    );

    await tester.enterText(
      find.byKey(const ValueKey('services-city-field')),
      'Chía',
    );
    await _pumpServices(
      tester,
      activeVehicle: _vehicle(registrationCity: 'Bogotá'),
    );

    expect(find.text('Chía'), findsOneWidget);
    expect(find.text('Bogotá'), findsNothing);
  });

  testWidgets('service searches use only Google Maps official search URLs', (
    tester,
  ) async {
    final launcher = _FakeExternalLauncher();
    await _pumpServices(
      tester,
      activeVehicle: _vehicle(registrationCity: 'Cali'),
      externalLauncher: launcher,
    );

    for (final key in [
      'services-search-tow',
      'services-search-battery',
      'services-search-tires',
      'services-search-mechanic',
    ]) {
      final action = find.byKey(ValueKey(key));
      await tester.ensureVisible(action);
      await tester.pump();
      await tester.tap(action);
      await tester.pump();
    }

    expect(
      launcher.openedUris,
      everyElement(
        startsWith('https://www.google.com/maps/search/?api=1&query='),
      ),
    );
    expect(
      launcher.openedUris.map((uri) {
        return Uri.parse(uri).queryParameters['query'];
      }),
      [
        'grúa 24 horas Cali',
        'batería Cali',
        'llantas Cali',
        'taller mecánico Cali',
      ],
    );
  });

  testWidgets('CDA action stays inside PicoRadar and does not launch search', (
    tester,
  ) async {
    var cdaOpened = false;
    final launcher = _FakeExternalLauncher();
    await _pumpServices(
      tester,
      activeVehicle: _vehicle(registrationCity: 'Bogotá'),
      onOpenCda: () => cdaOpened = true,
      externalLauncher: launcher,
    );

    await tester.tap(find.byKey(const ValueKey('services-open-cda')));
    await tester.pump();

    expect(cdaOpened, isTrue);
    expect(launcher.openedUris, isEmpty);
  });

  testWidgets('empty city blocks external search without GPS fallback', (
    tester,
  ) async {
    final launcher = _FakeExternalLauncher();
    await _pumpServices(
      tester,
      activeVehicle: _vehicle(registrationCity: null),
      externalLauncher: launcher,
    );

    await tester.tap(find.byKey(const ValueKey('services-search-battery')));
    await tester.pump();

    expect(launcher.openedUris, isEmpty);
    expect(find.text('Ingresa una ciudad para buscar.'), findsOneWidget);
  });

  testWidgets('launcher failure shows a controlled message', (tester) async {
    final launcher = _FakeExternalLauncher(openResult: false);
    await _pumpServices(
      tester,
      activeVehicle: _vehicle(registrationCity: 'Cali'),
      externalLauncher: launcher,
    );

    await tester.tap(find.byKey(const ValueKey('services-search-battery')));
    await tester.pump();

    expect(launcher.openedUris, hasLength(1));
    expect(find.text('No pudimos abrir Google Maps.'), findsOneWidget);
  });

  testWidgets('dispose during launch does not touch UI or ref', (tester) async {
    final pendingOpen = Completer<bool>();
    final launcher = _FakeExternalLauncher(pendingOpen: pendingOpen);
    await _pumpServices(
      tester,
      activeVehicle: _vehicle(registrationCity: 'Cali'),
      externalLauncher: launcher,
    );

    await tester.tap(find.byKey(const ValueKey('services-search-battery')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    pendingOpen.complete(false);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('No pudimos abrir Google Maps.'), findsNothing);
  });

  testWidgets('services screen tolerates phone viewports and text scale', (
    tester,
  ) async {
    for (final viewport in [
      (name: '360x800', size: const Size(360, 800), scale: 1.0),
      (name: '390x844 textScale 1.5', size: const Size(390, 844), scale: 1.5),
      (name: '412x915 textScale 2.0', size: const Size(412, 915), scale: 2.0),
    ]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = viewport.size;
      tester.platformDispatcher.textScaleFactorTestValue = viewport.scale;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await _pumpServices(
        tester,
        activeVehicle: _vehicle(registrationCity: 'Medellín'),
      );

      expect(
        find.byKey(const ValueKey('services-screen')),
        findsOneWidget,
        reason: viewport.name,
      );
      expect(tester.takeException(), isNull, reason: viewport.name);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}

Future<void> _pumpServices(
  WidgetTester tester, {
  required VehicleProfile? activeVehicle,
  VoidCallback? onOpenCda,
  ExternalLauncher? externalLauncher,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeVehicleProvider.overrideWithValue(AsyncValue.data(activeVehicle)),
        externalLauncherProvider.overrideWithValue(
          externalLauncher ?? _FakeExternalLauncher(),
        ),
      ],
      child: MaterialApp(
        theme: buildPicoRadarTheme(),
        home: ServicesScreen(onOpenCda: onOpenCda),
      ),
    ),
  );
  await tester.pump();
}

VehicleProfile _vehicle({required String? registrationCity}) {
  return VehicleProfile(
    id: 'vehicle-1',
    plate: 'ABC123',
    kind: VehicleKind.car,
    serviceType: VehicleServiceType.private,
    registrationCity: registrationCity,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

class _FakeExternalLauncher implements ExternalLauncher {
  _FakeExternalLauncher({this.openResult = true, this.pendingOpen});

  final bool openResult;
  final Completer<bool>? pendingOpen;
  final openedUris = <String>[];
  final calledPhones = <String>[];

  @override
  Future<bool> callPhone(String phone) async {
    calledPhones.add(phone);
    return true;
  }

  @override
  Future<bool> openExternal(String uri) {
    openedUris.add(uri);
    final completer = pendingOpen;
    if (completer != null) return completer.future;
    return Future.value(openResult);
  }
}
