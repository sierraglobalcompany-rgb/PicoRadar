import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/theme/app_theme.dart';
import 'package:picoradar/features/cda/data/cda_catalog.dart';
import 'package:picoradar/features/cda/presentation/cda_directory_view.dart';

import '../../vehicle_status/presentation/v01b_obligations_test_font.dart';

void main() {
  setUpAll(loadV01bObligationsTestFont);
  testWidgets('requires two normalized characters or a territory', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byKey(const ValueKey('cda-directory-initial')), findsOneWidget);
    expect(_row('car'), findsNothing);
    for (final query in ['a', '  . ! ', 'a - ']) {
      await tester.enterText(_search, query);
      await tester.pump();
      expect(_row('car'), findsNothing);
      expect(
        find.byKey(const ValueKey('cda-directory-initial')),
        findsOneWidget,
      );
    }
    await tester.enterText(_search, 'zz');
    await tester.pump();
    expect(find.byKey(const ValueKey('cda-directory-empty')), findsOneWidget);
    expect(find.byKey(const ValueKey('cda-directory-initial')), findsNothing);
  });

  testWidgets('normalizes accents punctuation and decomposed search text', (
    tester,
  ) async {
    await _pump(tester);
    for (final query in [
      'revision',
      'MEDELLIN!!',
      'Antioquia',
      'revisio\u0301n',
    ]) {
      await tester.enterText(_search, query);
      await tester.pump();
      expect(_row('car'), findsOneWidget);
    }
    await tester.enterText(_search, 'revision - medellin, antioquia');
    await tester.pump();
    expect(_row('car'), findsOneWidget);
    expect(_row('moto'), findsNothing);
  });

  testWidgets('compatibility alone cannot reveal the national directory', (
    tester,
  ) async {
    await _pump(tester);
    await _filters(tester);
    await _tap(tester, find.text('Carros'));
    await _apply(tester);
    expect(_row('car'), findsNothing);
    expect(find.byKey(const ValueKey('cda-directory-initial')), findsOneWidget);
  });

  testWidgets('dotted CDA names match their unpunctuated search', (
    tester,
  ) async {
    await _pump(
      tester,
      entries: [
        _entry('dotted', 'C.D.A. Revisión-Centro', 'Bogotá D.C.', 'Bogotá'),
      ],
    );
    await tester.enterText(_search, 'cda revision centro bogota dc');
    await tester.pump();
    expect(_row('dotted'), findsOneWidget);
  });

  testWidgets('same-name cities retain their department identity', (
    tester,
  ) async {
    await _pump(
      tester,
      entries: [
        _entry('north', 'CDA Norte', 'Antioquia', 'La Unión'),
        _entry('south', 'CDA Sur', 'Nariño', 'La Unión'),
      ],
    );
    await _filters(tester);
    await _tap(tester, find.byKey(const ValueKey('cda-filter-city')));
    await tester.enterText(
      find.byKey(const ValueKey('cda-picker-search')),
      'la union',
    );
    await tester.pump();
    await _tap(tester, find.text('La Unión · Nariño'));
    await _apply(tester);
    expect(_row('south'), findsOneWidget);
    expect(_row('north'), findsNothing);
  });

  for (final item in <(String, List<String>)>[
    ('Todos', ['car', 'moto', 'both', 'unknown']),
    ('Carros', ['car', 'both']),
    ('Motos', ['moto', 'both']),
    ('Ambos', ['both']),
  ]) {
    testWidgets('${item.$1} uses verified compatibility only', (tester) async {
      await _pump(tester, query: 'cda');
      await _filters(tester);
      await _tap(tester, _choiceChip(item.$1));
      await _apply(tester);
      for (final id in ['car', 'moto', 'both', 'unknown']) {
        expect(_row(id), item.$2.contains(id) ? findsOneWidget : findsNothing);
      }
    });
  }

  testWidgets(
    'city selection qualifies its department and scopes city choices',
    (tester) async {
      await _pump(tester);
      await _filters(tester);
      await _tap(tester, find.byKey(const ValueKey('cda-filter-city')));
      await tester.enterText(
        find.byKey(const ValueKey('cda-picker-search')),
        'medellin',
      );
      await tester.pump();
      await _tap(tester, find.text('Medellín · Antioquia'));
      await _apply(tester);
      expect(_row('car'), findsOneWidget);
      expect(_row('both'), findsNothing);
      await _filters(tester);
      await _tap(tester, find.byKey(const ValueKey('cda-filter-department')));
      await tester.enterText(
        find.byKey(const ValueKey('cda-picker-search')),
        'boyaca',
      );
      await tester.pump();
      await _tap(tester, find.text('Boyacá'));
      await _tap(tester, find.byKey(const ValueKey('cda-filter-city')));
      final cityPicker = find.byType(ListView).last;
      expect(
        find.descendant(
          of: cityPicker,
          matching: find.text('Medellín · Antioquia'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: cityPicker, matching: find.text('Tunja · Boyacá')),
        findsOneWidget,
      );
      await _tap(
        tester,
        find
            .ancestor(
              of: find.text('Todas las ciudades'),
              matching: find.byType(ListTile),
            )
            .last,
      );
      await _apply(tester);
      expect(_row('moto'), findsOneWidget);
      expect(_row('car'), findsNothing);
    },
  );

  testWidgets(
    'cancel discards filter drafts and clear removes applied filters',
    (tester) async {
      await _pump(tester, query: 'cda');
      await _filters(tester);
      await _tap(tester, find.text('Ambos'));
      await _tap(tester, find.byTooltip('Cerrar filtros'));
      expect(_row('unknown'), findsOneWidget);
      await _filters(tester);
      await _tap(tester, find.text('Ambos'));
      await _apply(tester);
      expect(_row('unknown'), findsNothing);
      await _filters(tester);
      await _tap(tester, find.text('Restablecer'));
      await _apply(tester);
      expect(_row('unknown'), findsOneWidget);
    },
  );

  testWidgets('name order has stable department city and id ties', (
    tester,
  ) async {
    final entries = [
      _entry('z', 'CDA Alfa', 'Boyacá', 'Tunja'),
      _entry('b', 'CDA Alfa', 'Antioquia', 'Medellín'),
      _entry('a', 'CDA Alfa', 'Antioquia', 'Medellín'),
      _entry('c', 'CDA Alfa', 'Antioquia', 'Bello'),
      _entry('first', 'CDA Abad', 'Boyacá', 'Tunja'),
    ];
    await _pump(tester, query: 'cda', entries: entries);
    expect(_visibleIds(tester), ['first', 'c', 'a', 'b', 'z']);
    await _filters(tester);
    await _tap(tester, find.byKey(const ValueKey('cda-filter-order')));
    expect(find.textContaining('Cercanía'), findsNothing);
    await _tap(tester, find.text('Nombre Z-A'));
    await _apply(tester);
    expect(_visibleIds(tester), ['c', 'a', 'b', 'z', 'first']);
  });

  testWidgets(
    'all results reachable; detail preserves scroll; query resets it',
    (tester) async {
      final entries = List.generate(
        85,
        (i) => _entry(
          'id-$i',
          'CDA ${i.toString().padLeft(3, '0')}',
          'Antioquia',
          'Medellín',
        ),
      );
      await _pump(tester, query: 'cda', entries: entries, openDetail: true);
      expect(_row('id-84'), findsNothing);
      final list = find.byKey(const ValueKey('cda-directory-results'));
      final scrollable = find.descendant(
        of: list,
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        _row('id-84'),
        500,
        scrollable: scrollable,
      );
      final offset = tester.state<ScrollableState>(scrollable).position.pixels;
      expect(offset, greaterThan(0));
      final searchTop = tester.getTopLeft(_search).dy;
      await _tap(tester, _row('id-84'));
      expect(find.text('Detalle id-84'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(tester.state<ScrollableState>(scrollable).position.pixels, offset);
      expect(tester.getTopLeft(_search).dy, searchTop);
      await tester.enterText(_search, 'CDA 0');
      await tester.pumpAndSettle();
      expect(tester.state<ScrollableState>(scrollable).position.pixels, 0);
      expect(_row('id-0'), findsOneWidget);
      await tester.scrollUntilVisible(
        _row('id-60'),
        500,
        scrollable: scrollable,
      );
      await _filters(tester);
      await _tap(tester, find.byKey(const ValueKey('cda-filter-department')));
      await _tap(tester, find.text('Antioquia'));
      await _apply(tester);
      expect(tester.state<ScrollableState>(scrollable).position.pixels, 0);
    },
  );

  for (final width in [360.0, 390.0, 412.0, 430.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('portrait $width text $scale keeps rows and filters usable', (
        tester,
      ) async {
        await _pump(
          tester,
          query: 'cda',
          width: width,
          scale: scale,
          entries: [
            _entry(
              'long',
              'CDA Revisión Técnico Mecánica del Valle de Aburrá',
              'Archipiélago de San Andrés, Providencia y Santa Catalina',
              'San Andrés',
            ),
          ],
        );
        expect(tester.takeException(), isNull);
        expect(tester.getSize(_row('long')).height, greaterThanOrEqualTo(48));
        expect(find.byType(Scaffold), findsOneWidget);
        await _filters(tester);
        await _tap(tester, find.byKey(const ValueKey('cda-filter-department')));
        await tester.enterText(
          find.byKey(const ValueKey('cda-picker-search')),
          'archipielago',
        );
        await tester.pump();
        await _tap(
          tester,
          find.text('Archipiélago de San Andrés, Providencia y Santa Catalina'),
        );
        await _tap(tester, find.text('Ambos'));
        await _apply(tester);
        expect(
          find.byKey(const ValueKey('cda-directory-empty')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}

final _search = find.byKey(const ValueKey('cda-directory-search'));
Finder _row(String id) => find.byKey(ValueKey('cda-directory-entry-$id'));

List<String> _visibleIds(WidgetTester tester) => tester
    .widgetList<InkWell>(
      find.byWidgetPredicate(
        (widget) =>
            widget is InkWell &&
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'cda-directory-entry-',
            ),
      ),
    )
    .map(
      (widget) => (widget.key! as ValueKey<String>).value.replaceFirst(
        'cda-directory-entry-',
        '',
      ),
    )
    .toList();

Future<void> _tap(WidgetTester tester, Finder finder) async {
  final target = finder.evaluate().length > 1 ? finder.first : finder;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _filters(WidgetTester tester) =>
    _tap(tester, find.byKey(const ValueKey('cda-directory-filters')));
Future<void> _apply(WidgetTester tester) =>
    _tap(tester, find.byKey(const ValueKey('cda-filters-apply')));
Finder _choiceChip(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is ChoiceChip &&
      widget.label is Text &&
      (widget.label as Text).data == label,
);

Future<void> _pump(
  WidgetTester tester, {
  String query = '',
  List<CdaCatalogEntry>? entries,
  bool openDetail = false,
  double width = 390,
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 800);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildPicoRadarTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) => CdaDirectoryView(
            catalog: _catalog(
              entries ??
                  [
                    _entry(
                      'unknown',
                      'CDA Motos sin evidencia',
                      'Boyacá',
                      'Tunja',
                    ),
                    _entry('both', 'CDA Ambos', 'Antioquia', 'Bello'),
                    _entry('car', 'CDA Revisión', 'Antioquia', 'Medellín'),
                    _entry('moto', 'CDA Dos', 'Boyacá', 'Tunja'),
                  ],
            ),
            initialQuery: query,
            verifiedVehicleTypes: const {
              'car': {'car'},
              'moto': {'motorcycle'},
              'both': {'car', 'motorcycle'},
            },
            onOpen: (entry) {
              if (openDetail) {
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(),
                      body: Text('Detalle ${entry.id}'),
                    ),
                  ),
                );
              }
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

CdaCatalogEntry _entry(
  String id,
  String name,
  String department,
  String city,
) => CdaCatalogEntry(
  id: id,
  name: name,
  nit: null,
  municipality: city,
  department: department,
  departmentCode: '05',
  sourceYear: 2026,
  sourceMonth: 7,
  sourceMonthName: 'JULIO',
  certified: true,
  novelty: 'NO',
  sourceVerifiedAt: DateTime.utc(2026, 8, 31),
  generatedAt: DateTime.utc(2026, 8, 31),
);

CdaCatalog _catalog(List<CdaCatalogEntry> entries) => CdaCatalog(
  source: CdaCatalogSource(
    provider: 'RUNT',
    datasetId: 'epfm-5fhb',
    datasetName: 'CDA fixture',
    sourceUrl: cdaCatalogSourceUrl,
    sourceVerifiedAt: DateTime.utc(2026, 8, 31),
    latestSourceYear: 2026,
    latestSourceMonth: 7,
    latestSourceMonthName: 'JULIO',
  ),
  metrics: CdaCatalogMetrics(
    sourceRows: entries.length,
    cdaSourceRows: entries.length,
    latestSourcePeriod: '2026-07',
    globalLatestSourcePeriod: '2026-07',
    futureSourcePeriodsIgnored: false,
    latestPeriodCdaRows: entries.length,
    currentUniqueCdaCount: entries.length,
    staleHistoricalCdaExcludedCount: 0,
    certificoNotSiCount: 0,
    unsafeNoveltyCount: 0,
    ambiguousCurrentDuplicateCount: 0,
    uniqueCdaCount: entries.length,
    excludedCurrentStatusCount: 0,
    municipalityCount: 3,
    departmentCount: 2,
    sponsoredCdaCount: 0,
  ),
  entries: entries,
);
