import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:picoradar/app/app.dart';
import 'package:picoradar/app/shell/app_shell.dart';

Future<void> pumpPicoRadarApp(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: PicoRadarApp()));
  await tester.pumpAndSettle();
}

void main() {
  test('tabs are fixed in the approved C01 order', () {
    expect(AppTab.values.map((tab) => tab.label), [
      'Inicio',
      'Garaje',
      'Apps',
      'Viaje',
      'Conducir',
    ]);
    expect(AppTab.values, hasLength(5));
    expect(AppTab.values.indexOf(AppTab.apps), 2);
    expect(AppTab.values[1].label, 'Garaje');
  });

  testWidgets('renders the five-tab shell at the home root', (tester) async {
    await pumpPicoRadarApp(tester);

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byKey(const ValueKey('app-bottom-navigation')), findsOneWidget);
    expect(find.text('Inicio'), findsAtLeastNWidgets(1));
    expect(find.text('Garaje'), findsAtLeastNWidgets(1));
    expect(find.text('Apps'), findsAtLeastNWidgets(1));
    expect(find.text('Viaje'), findsAtLeastNWidgets(1));
    expect(find.text('Conducir'), findsAtLeastNWidgets(1));
    expect(find.text('Raiz diaria de PicoRadar.'), findsOneWidget);
  });

  testWidgets('bottom navigation opens each root tab', (tester) async {
    await pumpPicoRadarApp(tester);

    await tester.tap(find.byKey(const ValueKey('tab-garage')));
    await tester.pumpAndSettle();
    expect(find.text('Vehiculos, documentos y obligaciones.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tab-apps')));
    await tester.pumpAndSettle();
    expect(
      find.text('Launcher central de modulos secundarios.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('tab-trip')));
    await tester.pumpAndSettle();
    expect(find.text('Planeacion de ruta sin mapa propio.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tab-drive')));
    await tester.pumpAndSettle();
    expect(
      find.text('Modo de conduccion de alta concentracion.'),
      findsOneWidget,
    );
  });

  testWidgets('indexed stack preserves branch state', (tester) async {
    await pumpPicoRadarApp(tester);

    await tester.tap(find.byKey(const ValueKey('state-button-home')));
    await tester.pumpAndSettle();
    expect(find.text('Estado local 1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tab-garage')));
    await tester.pumpAndSettle();
    expect(find.text('Estado local 0'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tab-home')));
    await tester.pumpAndSettle();
    expect(find.text('Estado local 1'), findsOneWidget);
  });

  testWidgets('immersive route is outside the shell and returns with back', (
    tester,
  ) async {
    await pumpPicoRadarApp(tester);

    await tester.tap(find.byKey(const ValueKey('open-immersive-route')));
    await tester.pumpAndSettle();

    expect(find.text('Ruta inmersiva'), findsOneWidget);
    expect(find.text('Fuera del shell'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('app-bottom-navigation')).hitTestable(),
      findsNothing,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-bottom-navigation')), findsOneWidget);
    expect(find.text('Raiz diaria de PicoRadar.'), findsOneWidget);
  });
}
