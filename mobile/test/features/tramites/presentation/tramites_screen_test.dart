import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/comparendos/data/territorial_catalog.dart';
import 'package:picoradar/features/tramites/data/tramites_catalog.dart';
import 'package:picoradar/features/tramites/presentation/tramites_screen.dart';
import 'package:picoradar/features/vehicle_status/platform/external_launcher.dart';

void main() {
  late TramitesCatalog catalog;

  setUpAll(() {
    final json = jsonDecode(
      File(territorialCatalogAssetPath).readAsStringSync(),
    ) as Map<String, Object?>;
    catalog = TramitesCatalog.fromTerritorial(
      TerritorialCatalog.fromJson(json),
    );
  });

  testWidgets('shows national coverage and source counts', (tester) async {
    await _pumpScreen(tester, catalog);

    expect(find.text('Cobertura nacional'), findsOneWidget);
    expect(find.text('769 autoridades'), findsOneWidget);
    expect(find.text('1.003 filas fuente'), findsOneWidget);
    expect(find.text('2 con enlaces revisados'), findsOneWidget);
    expect(find.text('767 por confirmar'), findsOneWidget);
    expect(find.byKey(const ValueKey('tramites-search')), findsOneWidget);
  });

  testWidgets('searches by authority municipality and department', (
    tester,
  ) async {
    await _pumpScreen(tester, catalog);
    await _search(tester, 'medellin antioquia');

    expect(
      find.byKey(const ValueKey('tramites-authority-co-medellin')),
      findsOneWidget,
    );
    expect(find.text('Secretaría de Movilidad de Medellín'), findsOneWidget);
  });

  testWidgets('Medellin keeps the four reviewed procedures and exact URL', (
    tester,
  ) async {
    final launcher = _FakeExternalLauncher();
    await _pumpScreen(tester, catalog, launcher: launcher);
    await _openAuthority(tester, 'Medellín', 'co-medellin');

    expect(find.text('Enlaces revisados'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('tramites-card-co-medellin-traspaso')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tramites-card-co-medellin-duplicado')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tramites-card-co-medellin-matricula')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tramites-card-co-medellin-certificado')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('tramites-card-co-medellin-traspaso')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lista de preparación'), findsOneWidget);
    expect(find.text('Revisado 2026-09-15'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tramites-open-official')));
    await tester.pumpAndSettle();
    expect(
      launcher.opened.single,
      'https://www.medellin.gov.co/es/tramites-y-servicios/traspaso-de-propiedad-de-un-vehiculo-automotor/',
    );
  });

  testWidgets('reviewed institution remains Por confirmar for procedures', (
    tester,
  ) async {
    final launcher = _FakeExternalLauncher();
    await _pumpScreen(tester, catalog, launcher: launcher);
    await _openAuthority(tester, 'Itagüí', 'co-itagui');

    expect(find.text('Por confirmar'), findsWidgets);
    expect(
      find.text(
        'No hay enlaces directos de trámites revisados para esta autoridad.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tramites-open-fallback')),
      findsOneWidget,
    );
    expect(find.text('Abrir sitio institucional'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tramites-open-fallback')));
    await tester.pumpAndSettle();
    expect(launcher.opened.single, 'https://www.transitoitagui.gov.co/');
  });

  testWidgets(
    'unreviewed inventory entry falls back to official RUNT directory',
    (tester) async {
      final launcher = _FakeExternalLauncher();
      await _pumpScreen(tester, catalog, launcher: launcher);
      await _openAuthority(
        tester,
        'SECRETARÍA DE MOVILIDAD MUNICIPIO DE ENVIGADO',
        'inventory-fcm_organismos-p2-r121',
      );

      expect(find.text('Por confirmar'), findsWidgets);
      expect(find.text('Consultar directorio RUNT'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tramites-open-fallback')));
      await tester.pumpAndSettle();
      expect(launcher.opened.single, runtActorsDirectoryUrl);
    },
  );

  testWidgets('launch failure keeps the approved error message', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      catalog,
      launcher: _FakeExternalLauncher(openResult: false),
    );
    await _openAuthority(tester, 'Bogotá', 'co-bogota');
    await tester.tap(
      find.byKey(const ValueKey('tramites-card-co-bogota-certificado')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tramites-open-official')));
    await tester.pump();

    expect(find.text('No pudimos abrir el portal oficial.'), findsOneWidget);
  });

  testWidgets('national catalog stays readable on target phones', (
    tester,
  ) async {
    for (final size in const [Size(360, 800), Size(412, 915)]) {
      await _pumpScreen(tester, catalog, size: size, scale: 1.5);
      await _openAuthority(
        tester,
        'Secretaría Distrital de Movilidad de Bogotá',
        'co-bogota',
      );
      expect(
        find.byKey(const ValueKey('tramites-authority-detail')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });
}

Future<void> _pumpScreen(
  WidgetTester tester,
  TramitesCatalog catalog, {
  _FakeExternalLauncher? launcher,
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tramitesCatalogProvider.overrideWith((ref) async => catalog),
        externalLauncherProvider.overrideWithValue(
          launcher ?? _FakeExternalLauncher(),
        ),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: const TramitesScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _search(WidgetTester tester, String query) async {
  await tester.enterText(find.byKey(const ValueKey('tramites-search')), query);
  await tester.pumpAndSettle();
}

Future<void> _openAuthority(
  WidgetTester tester,
  String query,
  String authorityId,
) async {
  await _search(tester, query);
  final card = find.byKey(ValueKey('tramites-authority-$authorityId'));
  await tester.ensureVisible(card);
  await tester.tap(card);
  await tester.pumpAndSettle();
}

class _FakeExternalLauncher implements ExternalLauncher {
  _FakeExternalLauncher({this.openResult = true});

  final bool openResult;
  final List<String> opened = [];

  @override
  Future<bool> callPhone(String phone) async => false;

  @override
  Future<bool> openExternal(String url) async {
    opened.add(url);
    return openResult;
  }
}
