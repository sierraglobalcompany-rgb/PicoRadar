import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/theme/app_theme.dart';
import 'package:picoradar/features/cda/data/cda_catalog.dart';
import 'package:picoradar/features/cda/data/cda_geography.dart';
import 'package:picoradar/features/cda/presentation/cda_finder_screen.dart';

import '../../vehicle_status/presentation/v01b_obligations_test_font.dart';

void main() {
  setUpAll(loadV01bObligationsTestFont);
  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final catalog = (await tester.runAsync(() => loadCdaCatalog(rootBundle)))!;
    final geography = (await tester.runAsync(
      () => loadCdaGeography(rootBundle),
    ))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cdaCatalogProvider.overrideWith((ref) async => catalog),
          cdaGeographyProvider.overrideWith((ref) async => geography),
          bogotaNowProvider.overrideWithValue(DateTime(2026, 9, 14)),
        ],
        child: MaterialApp(
          theme: buildPicoRadarTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const Scaffold(
            body: CdaFinderScreen(),
            bottomNavigationBar: SizedBox(height: 80),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('home offers paths instead of first forty CDA', (tester) async {
    await pump(tester);
    expect(find.text('Directorio RUNT'), findsOneWidget);
    expect(find.text('Cerca de mí'), findsOneWidget);
    expect(find.text('Explorar mapa'), findsOneWidget);
    expect(find.text('C.D.A CERTIGASES AMAZONAS'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('cda-directory-open')));
    await tester.pumpAndSettle();
    expect(find.text('C.D.A CERTIGASES AMAZONAS'), findsNothing);
  });
  testWidgets('approved operational geography opens the map', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('cda-map-open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cda-geography-gate')), findsNothing);
    expect(find.byKey(const ValueKey('cda-map-toolbar')), findsOneWidget);
  });
  for (final size in const [
    Size(360, 780),
    Size(360, 800),
    Size(390, 844),
    Size(412, 915),
    Size(430, 932),
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('home fits shell $size $scale', (tester) async {
        await pump(tester, size: size, scale: scale);
        expect(tester.takeException(), isNull);
        final source = find.byKey(const ValueKey('cda-source-open'));
        await tester.ensureVisible(source);
        await tester.pumpAndSettle();
        expect(source.hitTestable(), findsOneWidget);
        expect(tester.getSize(source).height, greaterThanOrEqualTo(48));
        if (scale == 1) {
          final scroll = tester.state<ScrollableState>(
            find.byType(Scrollable).first,
          );
          expect(scroll.position.maxScrollExtent, 0);
        }
      });
    }
  }
}
