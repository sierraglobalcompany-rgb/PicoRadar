import '../../../plate_test_fonts.dart';

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:picoradar/app/app.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/core/storage/app_preferences.dart';
import 'package:picoradar/features/apps_launcher/presentation/module_placeholder_screen.dart';
import 'package:picoradar/features/documents/presentation/documents_screen.dart';
import 'package:picoradar/features/defense/data/defense_case_store.dart';
import 'package:picoradar/features/garage/application/vehicle_associated_data_cleaner.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/garage/data/vehicle_repository.dart';
import 'package:picoradar/features/garage/presentation/garage_screen.dart';
import 'package:picoradar/features/maintenance/presentation/maintenance_screen.dart';
import 'package:picoradar/features/peritajes/data/peritajes_draft_store.dart';
import 'package:picoradar/features/pico_placa/data/pico_preferences.dart';
import 'package:picoradar/features/pico_placa/presentation/pico_detail_screen.dart';
import 'package:picoradar/features/visual_assets/data/visual_asset_preferences.dart';
import 'package:picoradar/features/visual_assets/presentation/visual_asset_widgets.dart';
import 'package:picoradar/features/vehicle_status/data/private_vehicle_document_store.dart';
import 'package:picoradar/features/vehicle_status/data/vehicle_obligation_store.dart';
import 'package:picoradar/features/vehicle_status/domain/vehicle_obligation.dart';

import '../../../test_app_harness.dart';
import '../../home/presentation/v01b_test_font.dart';

void main() {
  setUpAll(loadPlateTestFonts);
  setUpAll(loadV01bTestFont);
  late TestAppHarness harness;

  setUp(() {
    harness = TestAppHarness();
  });

  tearDown(() async {
    await harness.dispose();
  });

  testWidgets('A4 Garage waits for delayed initial active identity', (
    tester,
  ) async {
    final seeded = await _seedThreeVehicles(harness);
    final active = Completer<VehicleProfile?>();
    addTearDown(() {
      if (!active.isCompleted) active.complete(seeded.active);
    });
    await harness.pump(
      tester,
      vehicleListOverride: [seeded.newest, seeded.active, seeded.oldest],
      childOverride: ProviderScope(
        overrides: [activeVehicleProvider.overrideWith((ref) => active.future)],
        child: const MaterialApp(home: Scaffold(body: GarageScreen())),
      ),
    );
    active.complete(seeded.active);
    await tester.pumpAndSettle();
    _expectGarageInfoPanel(tester, seeded.active);
    expect(find.text('2 de 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'A4 Garage favorite edge is a 48dp action not vehicle navigation',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final vehicle = await _createVehicle(harness, plate: 'ABC123');
        await harness.repository.setActiveVehicle(vehicle.id);
        await _openGarage(tester, harness);
        final favorite = find.byKey(ValueKey('garage-favorite-${vehicle.id}'));
        expect(tester.getSize(favorite).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(favorite).height, greaterThanOrEqualTo(48));
        expect(
          find.descendant(
            of: favorite,
            matching: find.byIcon(Icons.star_rounded),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('garage-filter-segment')),
            matching: find.byIcon(Icons.star_border_rounded),
          ),
          findsOneWidget,
        );
        await tester.tapAt(tester.getTopLeft(favorite) + const Offset(2, 2));
        await tester.pumpAndSettle();
        expect((await harness.repository.getActiveVehicle())?.id, vehicle.id);
        expect(find.byTooltip('Vehículo favorito'), findsOneWidget);
        expect(find.bySemanticsLabel('Vehículo favorito'), findsOneWidget);
        expect(find.text('Detalle del vehículo'), findsNothing);
        expect(find.byKey(const ValueKey('garage-info-panel')), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'favorite initial read error shows retry without inventing a selection',
    (tester) async {
      final seeded = await _seedThreeVehicles(harness);
      final repository = _RecordingVehicleRepository(harness);
      var fail = true;
      var reads = 0;
      await harness.pump(
        tester,
        vehicleListOverride: [seeded.newest, seeded.active],
        childOverride: ProviderScope(
          retry: (_, _) => null,
          overrides: [
            vehicleRepositoryProvider.overrideWithValue(repository),
            activeVehicleProvider.overrideWith((ref) async {
              reads += 1;
              if (fail) throw StateError('private storage failure');
              return seeded.active;
            }),
          ],
          child: const MaterialApp(home: Scaffold(body: GarageScreen())),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('No pudimos cargar el vehículo favorito.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('garage-v2-scroll')), findsNothing);
      expect(find.text('No hay vehículo favorito.'), findsNothing);
      expect(find.textContaining('private storage failure'), findsNothing);
      expect(repository.favoriteVehicleIds, isEmpty);
      expect(reads, 1);
      fail = false;
      await tester.tap(find.byKey(const ValueKey('garage-favorite-retry')));
      await tester.pumpAndSettle();
      expect(reads, 2);
      _expectGarageInfoPanel(tester, seeded.active);
      expect(
        find.byKey(const ValueKey('garage-favorite-read-error')),
        findsNothing,
      );
      expect(repository.favoriteVehicleIds, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final favoriteFilter in [false, true]) {
    testWidgets(
      'favorite refresh error keeps known selection and focus filter=$favoriteFilter',
      (tester) async {
        final seeded = await _seedThreeVehicles(harness);
        var fail = false;
        await harness.pump(
          tester,
          vehicleListOverride: [seeded.newest, seeded.active, seeded.oldest],
          childOverride: ProviderScope(
            retry: (_, _) => null,
            overrides: [
              activeVehicleProvider.overrideWith((ref) async {
                if (fail) throw StateError('private refresh failure');
                return seeded.active;
              }),
            ],
            child: const MaterialApp(home: Scaffold(body: GarageScreen())),
          ),
        );
        await tester.pumpAndSettle();
        if (favoriteFilter) {
          await tester.tap(find.text('Favorito'));
          await tester.pumpAndSettle();
        } else {
          await _focusNewestVehicle(tester);
        }
        final container = ProviderScope.containerOf(
          tester.element(find.byType(GarageScreen)),
        );
        fail = true;
        container.invalidate(activeVehicleProvider);
        await tester.pumpAndSettle();
        expect(
          find.text(
            'No pudimos actualizar el favorito. Se muestra el último favorito conocido.',
          ),
          findsOneWidget,
        );
        _expectGarageInfoPanel(
          tester,
          favoriteFilter ? seeded.active : seeded.newest,
        );
        expect(find.byTooltip('Vehículo favorito'), findsOneWidget);
        expect(find.text(favoriteFilter ? '1 de 1' : '1 de 3'), findsOneWidget);
        final favoriteControl = find.byKey(
          ValueKey(
            'garage-favorite-${favoriteFilter ? seeded.active.id : seeded.newest.id}',
          ),
        );
        expect(tester.widget<InkWell>(favoriteControl).onTap, isNull);
        expect(find.textContaining('private refresh failure'), findsNothing);
        fail = false;
        await tester.tap(find.byKey(const ValueKey('garage-favorite-retry')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('garage-favorite-read-error')),
          findsNothing,
        );
        _expectGarageInfoPanel(
          tester,
          favoriteFilter ? seeded.active : seeded.newest,
        );
        expect(find.text(favoriteFilter ? '1 de 1' : '1 de 3'), findsOneWidget);
        expect(tester.widget<InkWell>(favoriteControl).onTap, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'favorite error after a null value still shows unavailable state',
    (tester) async {
      final seeded = await _seedThreeVehicles(harness);
      var fail = false;
      await harness.pump(
        tester,
        vehicleListOverride: [seeded.active],
        childOverride: ProviderScope(
          retry: (_, _) => null,
          overrides: [
            activeVehicleProvider.overrideWith((ref) async {
              if (fail) throw StateError('read failed');
              return null;
            }),
          ],
          child: const MaterialApp(home: Scaffold(body: GarageScreen())),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GarageScreen)),
      );
      fail = true;
      container.invalidate(activeVehicleProvider);
      await tester.pumpAndSettle();
      expect(
        find.text('No pudimos cargar el vehículo favorito.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('garage-v2-scroll')), findsNothing);
      expect(find.text('No hay vehículo favorito.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'favorite save failure keeps persisted favorite control and focus',
    (tester) async {
      final seeded = await _seedThreeVehicles(harness);
      final repository = _RecordingVehicleRepository(harness)
        ..failSetActive = true;
      await _openGarage(tester, harness, vehicleRepository: repository);
      await _focusNewestVehicle(tester);
      await tester.tap(
        find.byKey(ValueKey('garage-favorite-${seeded.newest.id}')),
      );
      await tester.pumpAndSettle();
      expect(
        (await harness.repository.getActiveVehicle())?.id,
        seeded.active.id,
      );
      _expectGarageInfoPanel(tester, seeded.newest);
      expect(
        find.text('No pudimos guardar el favorito. Inténtalo de nuevo.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<InkWell>(
              find.byKey(ValueKey('garage-favorite-${seeded.newest.id}')),
            )
            .onTap,
        isNotNull,
      );
      expect(
        find.descendant(
          of: find.byKey(ValueKey('garage-favorite-${seeded.newest.id}')),
          matching: find.byIcon(Icons.star_border_rounded),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('favorite changes only after save and keeps Todos focus', (
    tester,
  ) async {
    final seeded = await _seedThreeVehicles(harness);
    final repository = _RecordingVehicleRepository(harness)
      ..favoriteGate = Completer<void>();
    addTearDown(() {
      if (!repository.favoriteGate!.isCompleted) {
        repository.favoriteGate!.complete();
      }
    });
    await _openGarage(tester, harness, vehicleRepository: repository);
    await _focusNewestVehicle(tester);
    final favoriteControl = find.byKey(
      ValueKey('garage-favorite-${seeded.newest.id}'),
    );
    await tester.tap(favoriteControl);
    await tester.pump();
    expect(repository.favoriteStarted.isCompleted, isTrue);
    expect(tester.widget<InkWell>(favoriteControl).onTap, isNull);
    final disabledOpacity = find
        .ancestor(of: favoriteControl, matching: find.byType(Opacity))
        .first;
    expect(tester.widget<Opacity>(disabledOpacity).opacity, lessThan(1));
    final favoriteSemantics = tester
        .widgetList<Semantics>(
          find.ancestor(of: favoriteControl, matching: find.byType(Semantics)),
        )
        .firstWhere(
          (widget) => widget.properties.label == 'Usar como favorito',
        );
    expect(favoriteSemantics.properties.enabled, isFalse);
    await tester.tap(favoriteControl);
    await tester.pump();
    expect(repository.favoriteVehicleIds, [seeded.newest.id]);
    expect(find.text('Detalle del vehículo'), findsNothing);
    expect((await harness.repository.getActiveVehicle())?.id, seeded.active.id);
    expect(
      find.descendant(
        of: favoriteControl,
        matching: find.byIcon(Icons.star_border_rounded),
      ),
      findsOneWidget,
    );
    repository.favoriteGate!.complete();
    await tester.pumpAndSettle();
    expect((await harness.repository.getActiveVehicle())?.id, seeded.newest.id);
    expect(tester.widget<InkWell>(favoriteControl).onTap, isNotNull);
    expect(
      find.descendant(
        of: favoriteControl,
        matching: find.byIcon(Icons.star_rounded),
      ),
      findsOneWidget,
    );
    _expectGarageInfoPanel(tester, seeded.newest);
    expect(find.text('1 de 3'), findsOneWidget);
    await tester.tap(favoriteControl);
    await tester.pumpAndSettle();
    expect(repository.favoriteVehicleIds, [seeded.newest.id]);
  });

  testWidgets('A4 favorite completion after Garage disposal is safe', (
    tester,
  ) async {
    final seeded = await _seedThreeVehicles(harness);
    final repository = _RecordingVehicleRepository(harness)
      ..favoriteGate = Completer<void>();
    await _openGarage(tester, harness, vehicleRepository: repository);
    await _focusNewestVehicle(tester);
    addTearDown(() {
      if (!repository.favoriteGate!.isCompleted) {
        repository.favoriteGate!.complete();
      }
    });
    await tester.tap(
      find.byKey(ValueKey('garage-favorite-${seeded.newest.id}')),
    );
    await tester.pump();
    expect(repository.favoriteStarted.isCompleted, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    repository.favoriteGate!.complete();
    await tester.pumpAndSettle();
    expect((await harness.repository.getActiveVehicle())?.id, seeded.newest.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'favorite completion invalidates active after Garage is removed',
    (tester) async {
      final seeded = await _seedThreeVehicles(harness);
      final repository = _RecordingVehicleRepository(harness)
        ..favoriteGate = Completer<void>();
      final visible = ValueNotifier(true);
      addTearDown(visible.dispose);
      addTearDown(() {
        if (!repository.favoriteGate!.isCompleted) {
          repository.favoriteGate!.complete();
        }
      });
      await harness.pump(
        tester,
        childOverride: ProviderScope(
          overrides: [vehicleRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder<bool>(
                valueListenable: visible,
                builder: (_, show, _) =>
                    show ? const GarageScreen() : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GarageScreen)),
      );
      await _focusNewestVehicle(tester);
      await tester.tap(
        find.byKey(ValueKey('garage-favorite-${seeded.newest.id}')),
      );
      await tester.pump();
      visible.value = false;
      await tester.pump();
      repository.favoriteGate!.complete();
      await tester.pumpAndSettle();
      expect(
        (await container.read(activeVehicleProvider.future))?.id,
        seeded.newest.id,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Todos uses alphabetical order without changing favorite', (
    tester,
  ) async {
    final seeded = await _seedThreeVehicles(harness);
    await _openGarage(
      tester,
      harness,
      vehicleListOverride: [seeded.oldest, seeded.active, seeded.newest],
    );
    final pages = tester.widget<PageView>(find.byType(PageView));
    pages.controller!.jumpToPage(0);
    await tester.pumpAndSettle();
    _expectGarageInfoPanel(tester, seeded.newest);
    pages.controller!.jumpToPage(2);
    await tester.pumpAndSettle();
    final panel = find.byKey(const ValueKey('garage-info-panel'));
    expect(
      find.descendant(
        of: panel,
        matching: findPlateNumber(seeded.oldest.plate),
      ),
      findsOneWidget,
    );
    expect((await harness.repository.getActiveVehicle())?.id, seeded.active.id);
  });

  testWidgets(
    'Garage never writes automatic favorite for unresolved identity',
    (tester) async {
      final seeded = await _seedThreeVehicles(harness);
      final repository = _RecordingVehicleRepository(harness);
      await harness.pump(
        tester,
        childOverride: ProviderScope(
          overrides: [
            vehicleRepositoryProvider.overrideWithValue(repository),
            activeVehicleProvider.overrideWith((ref) async => null),
          ],
          child: const MaterialApp(home: Scaffold(body: GarageScreen())),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.favoriteVehicleIds, isEmpty);
      expect(repository.activeReadCount, 0);
      expect(
        (await harness.repository.getActiveVehicle())?.id,
        seeded.active.id,
      );
    },
  );

  testWidgets(
    'favorite filter follows persisted change without resetting filter',
    (tester) async {
      final seeded = await _seedThreeVehicles(harness);
      await _openGarage(tester, harness);
      await tester.tap(find.text('Favorito'));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GarageScreen)),
      );
      await harness.repository.setActiveVehicle(seeded.newest.id);
      container.invalidate(activeVehicleProvider);
      await tester.pumpAndSettle();
      _expectGarageInfoPanel(tester, seeded.newest);
      expect(find.text('1 de 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final failDelete in [false, true]) {
    testWidgets(
      'delete blocks favorite control taps and preserves repository outcome failure=$failDelete',
      (tester) async {
        final seeded = await _seedThreeVehicles(harness);
        final repository = _RecordingVehicleRepository(harness)
          ..failDelete = failDelete
          ..deleteGate = Completer<void>();
        addTearDown(() {
          if (!repository.deleteGate!.isCompleted) {
            repository.deleteGate!.complete();
          }
        });
        await _openGarage(
          tester,
          harness,
          vehicleRepository: repository,
          vehicleAssociatedDataCleaner: _RecordingVehicleDataCleaner(),
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('garage-action-delete')),
        );
        await tester.tap(
          find.byKey(const ValueKey('garage-confirm-delete-vehicle')),
        );
        await _expirePendingDeletion(tester);
        expect(repository.deleteStarted.isCompleted, isTrue);
        final favoriteControl = find.byKey(
          ValueKey('garage-favorite-${seeded.active.id}'),
        );
        expect(tester.widget<InkWell>(favoriteControl).onTap, isNull);
        await tester.tap(favoriteControl);
        await tester.pump();
        expect(find.text('Detalle del vehículo'), findsNothing);

        expect(repository.favoriteVehicleIds, isEmpty);
        repository.deleteGate!.complete();
        await tester.pumpAndSettle();
        expect(
          (await harness.repository.getActiveVehicle())?.id,
          failDelete ? seeded.active.id : seeded.newest.id,
        );
        expect(
          await harness.repository.getVehicle(seeded.active.id),
          failDelete ? isNotNull : isNull,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final width in [360.0, 390.0, 412.0, 430.0]) {
    testWidgets('A4 Garage title fully reflows at scale 2 width $width', (
      tester,
    ) async {
      final vehicle = await _createVehicle(harness, plate: 'ABC123');
      await _openGarage(
        tester,
        harness,
        size: Size(width, 915),
        textScaleFactor: 2,
      );
      final title = find.byKey(ValueKey('garage-vehicle-title-${vehicle.id}'));
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: title, matching: find.byType(RichText)),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(tester.widget<Text>(title).style!.fontSize, 18);
      final card = tester
          .getRect(find.byKey(ValueKey('garage-vehicle-card-${vehicle.id}')))
          .inflate(0.5);
      for (final box in paragraph.getBoxesForSelection(
        TextSelection(
          baseOffset: 0,
          extentOffset: paragraph.text.toPlainText().length,
        ),
      )) {
        expect(
          card.contains(paragraph.localToGlobal(Offset(box.right, box.bottom))),
          isTrue,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('A7 Garage detail identifies registration city explicitly', (
    tester,
  ) async {
    final vehicle = await _createVehicle(
      harness,
      plate: 'ABC123',
      city: 'Medellín',
    );
    await _openGarage(tester, harness);
    await tester.tap(find.byKey(ValueKey('garage-vehicle-card-${vehicle.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Matrícula'), findsWidgets);
    expect(find.text('Ciudad'), findsNothing);
    expect(find.text('Medellín'), findsOneWidget);
  });

  for (final size in const [Size(360, 800), Size(390, 844), Size(412, 915)]) {
    for (final scale in const [1.0, 1.5, 2.0]) {
      testWidgets('V01B Garage identity readable ${size.width} scale $scale', (
        tester,
      ) async {
        await _createVehicle(
          harness,
          plate: 'ABC123',
          city: 'Medellín, Antioquia',
        );
        await _openGarage(
          tester,
          harness,
          size: size,
          textScaleFactor: scale,
          boundedSettle: true,
        );
        final panel = find.byKey(const ValueKey('garage-info-panel'));
        await tester.ensureVisible(panel);
        await tester.pump();
        final clipped = <String>[];
        for (final element
            in find
                .descendant(of: panel, matching: find.byType(RichText))
                .evaluate()) {
          final paragraph = element.renderObject! as RenderParagraph;
          if (paragraph.didExceedMaxLines) {
            clipped.add(paragraph.text.toPlainText());
          }
        }
        expect(clipped, isEmpty, reason: 'Vehicle identity is clipped');
        expect(find.text('Medellín, Antioquia').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'Garage favorite control accessible ${size.width} scale $scale',
        (tester) async {
          final seeded = await _seedThreeVehicles(harness);
          await _openGarage(
            tester,
            harness,
            size: size,
            textScaleFactor: scale,
            boundedSettle: true,
          );
          await _focusNewestVehicle(tester);
          final action = find.byKey(
            ValueKey('garage-favorite-${seeded.newest.id}'),
          );
          await tester.ensureVisible(action);
          await tester.pump();
          expect(tester.getSize(action), const Size(48, 48));
          expect(find.byTooltip('Usar como favorito'), findsWidgets);
          expect(action.hitTestable(), findsOneWidget);
          await tester.tap(action);
          await tester.pumpAndSettle();
          expect(
            (await harness.repository.getActiveVehicle())?.id,
            seeded.newest.id,
          );
          expect(tester.takeException(), isNull);
        },
      );
      testWidgets('V01B Garage filters readable ${size.width} scale $scale', (
        tester,
      ) async {
        await _seedThreeVehicles(harness);
        await _openGarage(
          tester,
          harness,
          size: size,
          textScaleFactor: scale,
          boundedSettle: true,
        );
        final segment = find.byKey(const ValueKey('garage-filter-segment'));
        if (scale == 1) {
          expect(tester.getSize(segment).height, 48);
        }
        for (final label in ['Favorito', 'Todos']) {
          final text = find.descendant(of: segment, matching: find.text(label));
          final paragraph = tester.renderObject<RenderParagraph>(text);
          final boxes = paragraph.getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: label.length),
          );
          expect(boxes, isNotEmpty);
          expect(
            boxes.map((box) => box.top).toSet(),
            hasLength(1),
            reason: '$label must remain one complete word on one visual line',
          );
          for (final box in boxes) {
            expect(
              box.right,
              lessThanOrEqualTo(paragraph.size.width + 0.5),
              reason: '$label fades before the end of its label',
            );
            expect(box.bottom, lessThanOrEqualTo(paragraph.size.height + 0.5));
            final bounds = tester.getRect(segment).inflate(0.5);
            expect(
              bounds.contains(
                paragraph.localToGlobal(Offset(box.right, box.bottom)),
              ),
              isTrue,
            );
          }
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(text.hitTestable(), findsOneWidget);
          await tester.tap(text);
          await tester.pumpAndSettle();
          final semantics = tester.widgetList<Semantics>(
            find.ancestor(of: text, matching: find.byType(Semantics)),
          );
          expect(
            semantics.any(
              (widget) =>
                  widget.properties.label == label &&
                  widget.properties.selected == true,
            ),
            isTrue,
          );
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  testWidgets('garage v2 shows owner structure and real vehicle data', (
    tester,
  ) async {
    await _seedThreeVehicles(harness);

    await _openGarage(tester, harness);

    expect(
      find.byKey(const ValueKey('garage-compact-top-bar')),
      findsOneWidget,
    );
    expect(find.text('PicoRadar'), findsOneWidget);
    expect(find.byKey(const ValueKey('garage-filter-segment')), findsOneWidget);
    expect(find.text('Todos'), findsOneWidget);
    expect(find.text('Favorito'), findsOneWidget);
    expect(find.text('Favoritos'), findsNothing);
    expect(find.text('Activos'), findsNothing);
    expect(find.text('Estado'), findsNothing);
    expect(find.text('Hacer activo'), findsNothing);
    expect(
      find.byKey(const ValueKey('garage-vehicle-carousel')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('garage-info-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('garage-add-vehicle')), findsOneWidget);
    expect(find.byKey(const ValueKey('garage-quick-actions')), findsOneWidget);
    expect(find.byKey(const ValueKey('garage-action-detail')), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('garage-quick-actions'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('garage-add-vehicle'))).dy,
      ),
    );
    expect(
      find.text('Tus vehículos y su estado en un solo lugar.'),
      findsNothing,
    );

    expect(find.text('Mazda CX-5'), findsWidgets);
    expect(findPlateNumber('ABC123'), findsWidgets);
    expect(find.text('Carro particular'), findsOneWidget);
    expect(find.text('Bogotá D. C.'), findsOneWidget);
    expect(find.text('Particular'), findsOneWidget);
    expect(find.text('2022'), findsWidgets);
    expect(find.text('24.560 km'), findsNothing);
    expect(find.text('Sin comparendos'), findsNothing);
    expect(find.text('0 comparendos'), findsNothing);
  });

  testWidgets(
    'one vehicle keeps count simple and uses vehicle visual resolver',
    (tester) async {
      final vehicle = await _createVehicle(
        harness,
        plate: 'AAA111',
        brand: 'Mazda',
        model: 'CX-5',
        year: 2022,
      );
      await harness.repository.setActiveVehicle(vehicle.id);

      await _openGarage(tester, harness);

      expect(find.text('1 de 1'), findsOneWidget);
      expect(find.byKey(ValueKey('garage-carousel-dot-0')), findsNothing);
      expect(find.byType(VehicleVisualImage), findsOneWidget);
    },
  );

  testWidgets('initial focus is active and swipe does not mutate active', (
    tester,
  ) async {
    final seeded = await _seedThreeVehicles(harness);

    await _openGarage(tester, harness);

    expect(find.text('2 de 3'), findsOneWidget);
    expect(findPlateNumber(seeded.active.plate), findsWidgets);
    expect((await harness.repository.getActiveVehicle())?.id, seeded.active.id);

    await tester.drag(
      find.byKey(const ValueKey('garage-vehicle-carousel')),
      const Offset(-320, 0),
    );
    await tester.pumpAndSettle();

    expect((await harness.repository.getActiveVehicle())?.id, seeded.active.id);
    expect(find.text('No activo'), findsNothing);
  });

  testWidgets(
    'focused vehicle card opens its detail without changing active vehicle',
    (tester) async {
      final seeded = await _seedThreeVehicles(harness);

      await _openGarage(tester, harness);
      await _focusNewestVehicle(tester);
      _expectGarageInfoPanel(tester, seeded.newest);
      await tester.tap(
        find.byKey(ValueKey('garage-vehicle-card-${seeded.newest.id}')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Detalle del vehículo'), findsOneWidget);
      expect(findPlateNumber(seeded.newest.plate), findsOneWidget);
      expect(find.text('No activo'), findsNothing);
      expect(find.text('Activo'), findsNothing);
      expect(find.byKey(const ValueKey('detail-make-active')), findsNothing);
      expect(
        (await harness.repository.getActiveVehicle())?.id,
        seeded.active.id,
      );
    },
  );

  testWidgets('explicit favorite control changes the sole favorite', (
    tester,
  ) async {
    final seeded = await _seedThreeVehicles(harness);

    await _openGarage(tester, harness);
    await _focusNewestVehicle(tester);
    await _tapVisible(
      tester,
      find.byKey(ValueKey('garage-favorite-${seeded.newest.id}')),
    );

    final active = await harness.repository.getActiveVehicle();
    expect(active?.id, seeded.newest.id);
    expect(find.text('Activo'), findsNothing);
  });

  testWidgets('P02-FIX1 non-active state keeps actions visible and scoped', (
    tester,
  ) async {
    final seeded = await _seedThreeVehicles(harness);

    await _openGarage(tester, harness);
    await _focusNewestVehicle(tester);

    _expectGarageInfoPanel(tester, seeded.newest);
    expect(find.text('No activo'), findsNothing);
    expect(
      find.byKey(const ValueKey('garage-action-make-active')),
      findsNothing,
    );
    expect((await harness.repository.getActiveVehicle())?.id, seeded.active.id);
    _expectGarageCoreAboveNav(tester, reason: 'non-active focused');

    await tester.tap(
      find.byKey(ValueKey('garage-vehicle-card-${seeded.newest.id}')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Detalle del vehículo'), findsOneWidget);
    expect(findPlateNumber(seeded.newest.plate), findsOneWidget);

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    await _focusNewestVehicle(tester);
    await tester.tap(
      find.byKey(ValueKey('garage-favorite-${seeded.newest.id}')),
    );
    await tester.pumpAndSettle();

    expect((await harness.repository.getActiveVehicle())?.id, seeded.newest.id);
    expect(find.text('Activo'), findsNothing);
    _expectGarageCoreAboveNav(tester, reason: 'after make active');
  });

  testWidgets('favorite filter persists the single selection on reopening', (
    tester,
  ) async {
    final seeded = await _seedThreeVehicles(harness);

    await _openGarage(tester, harness);
    await tester.tap(
      find.byKey(ValueKey('garage-favorite-${seeded.active.id}')),
    );
    await tester.pumpAndSettle();

    expect((await harness.repository.getActiveVehicle())?.id, seeded.active.id);

    await tester.tap(find.text('Favorito'));
    await tester.pumpAndSettle();

    expect(find.text('1 de 1'), findsOneWidget);
    expect(findPlateNumber(seeded.active.plate), findsWidgets);

    await _openGarage(tester, harness);
    await tester.tap(find.text('Favorito'));
    await tester.pumpAndSettle();

    expect(find.text('1 de 1'), findsOneWidget);
    expect(findPlateNumber(seeded.active.plate), findsWidgets);
  });

  testWidgets(
    'favorite filter shows exactly one vehicle and Todos restores the list',
    (tester) async {
      final seeded = await _seedThreeVehicles(harness);

      await _openGarage(tester, harness, size: const Size(480, 900));
      await tester.tap(find.text('Favorito'));
      await tester.pumpAndSettle();

      expect(find.text('1 de 1'), findsOneWidget);
      expect(findPlateNumber(seeded.active.plate), findsWidgets);
      await tester.tap(find.text('Todos'));
      await tester.pumpAndSettle();
      expect(find.text('2 de 3'), findsOneWidget);
    },
  );

  testWidgets(
    'root actions navigate with focused vehicle and avoid dead CTAs',
    (tester) async {
      final seeded = await _seedThreeVehicles(harness);

      await _openGarage(tester, harness);
      await _focusNewestVehicle(tester);
      final focused = seeded.newest;

      await _tapVisible(
        tester,
        find.byKey(const ValueKey('garage-action-documents')),
        settle: false,
      );
      final documents = tester.widget<DocumentsScreen>(
        find.byType(DocumentsScreen),
      );
      expect(documents.vehicleId, focused.id);
      expect(find.byKey(const ValueKey('documents-go-garage')), findsNothing);
      expect(find.byType(ModulePlaceholderScreen), findsNothing);
      expect(
        (await harness.repository.getActiveVehicle())?.id,
        seeded.active.id,
      );

      await tester.tap(find.byKey(const ValueKey('tab-garage')));
      await tester.pumpAndSettle();
      await _focusNewestVehicle(tester);
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('garage-action-maintenance')),
        settle: false,
      );
      final maintenance = tester.widget<MaintenanceScreen>(
        find.byType(MaintenanceScreen),
      );
      expect(maintenance.vehicleId, focused.id);
      expect(find.byKey(const ValueKey('maintenance-empty')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('maintenance-missing-vehicle')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('garage-maintenance-soon-sheet')),
        findsNothing,
      );
      expect(
        find.textContaining(RegExp('próximamente|proximamente')),
        findsNothing,
      );
      expect(find.byType(ModulePlaceholderScreen), findsNothing);
      expect(
        (await harness.repository.getActiveVehicle())?.id,
        seeded.active.id,
      );

      await tester.tap(find.byKey(const ValueKey('tab-garage')));
      await tester.pumpAndSettle();
      await _focusNewestVehicle(tester);
      await tester.tap(
        find.byKey(ValueKey('garage-vehicle-card-${focused.id}')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Detalle del vehículo'), findsOneWidget);
      expect(findPlateNumber(focused.plate), findsOneWidget);
    },
  );

  testWidgets('module routes from Garage fail closed for invalid vehicleId', (
    tester,
  ) async {
    final seeded = await _seedThreeVehicles(harness);

    await _openGarage(tester, harness);
    await _goTo(tester, '/apps/module/documentos?vehicleId=missing');

    expect(find.byType(DocumentsScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('documents-go-garage')), findsOneWidget);
    expect(find.byType(ModulePlaceholderScreen), findsNothing);
    expect((await harness.repository.getActiveVehicle())?.id, seeded.active.id);

    await _goTo(tester, '/apps/module/talleres?vehicleId=missing');

    expect(find.byType(MaintenanceScreen), findsOneWidget);
    expect(
      find.byKey(const ValueKey('maintenance-missing-vehicle')),
      findsOneWidget,
    );
    expect(find.byType(ModulePlaceholderScreen), findsNothing);
    expect(
      find.textContaining(RegExp('próximamente|proximamente')),
      findsNothing,
    );
    expect((await harness.repository.getActiveVehicle())?.id, seeded.active.id);
  });

  testWidgets(
    'delete dialog cancel shows full local-data copy and performs no mutations',
    (tester) async {
      final seeded = await _seedThreeVehicles(harness);
      final cleaner = _RecordingVehicleDataCleaner();

      await _openGarage(tester, harness, vehicleAssociatedDataCleaner: cleaner);
      await _focusNewestVehicle(tester);
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('garage-action-delete')),
      );

      expect(find.text('¿Eliminar este vehículo?'), findsOneWidget);
      expect(findPlateNumber(seeded.newest.plate), findsWidgets);
      expect(
        find.text(
          'Se eliminarán el vehículo y sus datos locales asociados:\n'
          'mantenimientos, obligaciones, documentos cifrados,\n'
          'expedientes de Defensa, borrador de Peritajes y nota de Comparendos.\n'
          'Tendrás 5 segundos para deshacer. Después, la eliminación será irreversible.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(cleaner.deletedVehicleIds, isEmpty);
      expect(await harness.repository.getVehicle(seeded.newest.id), isNotNull);
      expect(await harness.repository.getVehicle(seeded.active.id), isNotNull);
    },
  );

  testWidgets(
    'delete action removes focused only and active fallback stays deterministic',
    (tester) async {
      final seeded = await _seedThreeVehicles(harness);

      await _openGarage(tester, harness);
      await _focusNewestVehicle(tester);
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('garage-action-delete')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('garage-confirm-delete-vehicle')),
      );
      await _expirePendingDeletion(tester);

      expect(await harness.repository.getVehicle(seeded.newest.id), isNull);
      expect(
        (await harness.repository.getActiveVehicle())?.id,
        seeded.active.id,
      );

      await _tapVisible(
        tester,
        find.byKey(const ValueKey('garage-action-delete')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('garage-confirm-delete-vehicle')),
      );
      await _expirePendingDeletion(tester);

      expect(await harness.repository.getVehicle(seeded.active.id), isNull);
      expect(
        (await harness.repository.getActiveVehicle())?.id,
        seeded.oldest.id,
      );
    },
  );

  for (final cancellation in [
    'undo',
    'hide',
    'dismiss',
    'navigation',
    'unmount',
  ]) {
    testWidgets(
      'pending Garage deletion cancels on $cancellation without touching data',
      (tester) async {
        final seeded = await _seedThreeVehicles(harness);
        final cleaner = _RecordingVehicleDataCleaner();
        final repository = _RecordingVehicleRepository(harness);
        await VehicleObligationStore(harness.database).upsert(
          vehicleId: seeded.active.id,
          type: VehicleObligationType.soat,
          dueDate: DateTime(2027, 1, 1),
        );
        await tester.runAsync(() async {
          final source = File('${harness.documentRoot.path}/undo-source.pdf');
          await source.writeAsBytes([1, 2, 3]);
          await harness.documentStore.importDocument(
            vehicleId: seeded.active.id,
            documentType: PrivateVehicleDocumentType.soat,
            source: source,
            originalName: 'undo-source.pdf',
            mimeType: 'application/pdf',
          );
        });
        await _openGarage(
          tester,
          harness,
          vehicleRepository: repository,
          vehicleAssociatedDataCleaner: cleaner,
        );
        final preferencesBefore = {...harness.preferences.values};
        final filesBefore = {
          for (final file
              in harness.documentRoot
                  .listSync(recursive: true)
                  .whereType<File>())
            file.path: file.readAsBytesSync(),
        };
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('garage-action-delete')),
        );
        await tester.tap(
          find.byKey(const ValueKey('garage-confirm-delete-vehicle')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Eliminación pendiente'), findsOneWidget);
        expect(cleaner.deletedVehicleIds, isEmpty);
        expect(repository.deletedVehicleIds, isEmpty);
        expect(
          tester
              .widget<InkWell>(
                find.byKey(ValueKey('garage-favorite-${seeded.active.id}')),
              )
              .onTap,
          isNull,
        );
        expect(
          tester
              .widget<InkWell>(
                find.byKey(const ValueKey('garage-action-delete')),
              )
              .onTap,
          isNull,
        );
        await tester.pump(const Duration(seconds: 2));
        switch (cancellation) {
          case 'undo':
            await tester.tap(find.text('Deshacer'));
          case 'hide':
            ScaffoldMessenger.of(tester.element(find.byType(GarageScreen)))
                .hideCurrentSnackBar();
          case 'dismiss':
            await tester.drag(find.byType(SnackBar), const Offset(0, 200));
          case 'navigation':
            await _goTo(tester, '/home');
            await _goTo(tester, '/garage');
          case 'unmount':
            await tester.pumpWidget(const SizedBox.shrink());
        }
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(cleaner.deletedVehicleIds, isEmpty);
        expect(repository.deletedVehicleIds, isEmpty);
        expect(await repository.getVehicle(seeded.active.id), isNotNull);
        expect((await repository.getActiveVehicle())?.id, seeded.active.id);
        expect(harness.preferences.values, preferencesBefore);
        expect(
          await VehicleObligationStore(harness.database)
              .get(seeded.active.id, VehicleObligationType.soat),
          isNotNull,
        );
        expect(
          harness.documentRoot
              .listSync(recursive: true)
              .whereType<File>()
              .map((file) => file.path),
          unorderedEquals(filesBefore.keys),
        );
        for (final entry in filesBefore.entries) {
          expect(File(entry.key).readAsBytesSync(), entry.value);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Garage waits full undo window and does not queue duplicate actions',
    (tester) async {
      final seeded = await _seedThreeVehicles(harness);
      final cleaner = _RecordingVehicleDataCleaner();
      final repository = _RecordingVehicleRepository(harness);
      await _openGarage(
        tester,
        harness,
        vehicleRepository: repository,
        vehicleAssociatedDataCleaner: cleaner,
      );
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('garage-action-delete')),
      );
      await tester.tap(
        find.byKey(const ValueKey('garage-confirm-delete-vehicle')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('garage-action-delete')));
      await tester.pump();
      expect(find.byType(AlertDialog), findsNothing);
      await tester.pump(const Duration(seconds: 4));
      expect(cleaner.deletedVehicleIds, isEmpty);
      expect(repository.deletedVehicleIds, isEmpty);
      expect((await repository.getActiveVehicle())?.id, seeded.active.id);
      expect(await repository.getVehicle(seeded.active.id), isNotNull);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(cleaner.deletedVehicleIds, [seeded.active.id]);
      expect(repository.deletedVehicleIds, [seeded.active.id]);
      expect(await repository.getVehicle(seeded.active.id), isNull);
      expect((await repository.getActiveVehicle())?.id, seeded.newest.id);
      expect(find.text('Eliminación pendiente'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'delete action ignores a second confirmation while deletion is running',
    (tester) async {
      final seeded = await _seedThreeVehicles(harness);
      final cleaner = _RecordingVehicleDataCleaner()..gate = Completer<void>();
      final repository = _RecordingVehicleRepository(harness);

      await _openGarage(
        tester,
        harness,
        vehicleAssociatedDataCleaner: cleaner,
        vehicleRepository: repository,
      );
      await _focusNewestVehicle(tester);
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('garage-action-delete')),
      );
      await tester.tap(
        find.byKey(const ValueKey('garage-confirm-delete-vehicle')),
      );
      await _expirePendingDeletion(tester);
      await tester.tap(find.byKey(const ValueKey('garage-action-delete')));
      await tester.pump();

      expect(cleaner.deletedVehicleIds, [seeded.newest.id]);
      final confirmButton = find.byKey(
        const ValueKey('garage-confirm-delete-vehicle'),
      );
      if (confirmButton.evaluate().isNotEmpty) {
        expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);
      }
      expect(cleaner.deletedVehicleIds, [seeded.newest.id]);

      cleaner.gate!.complete();
      await tester.pumpAndSettle();

      expect(repository.deletedVehicleIds, [seeded.newest.id]);
      expect(await harness.repository.getVehicle(seeded.newest.id), isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'delete action cleans associated private data before vehicle row',
    (tester) async {
      final seeded = await _seedThreeVehicles(harness);
      final cleaner = _RecordingVehicleDataCleaner();

      await _openGarage(tester, harness, vehicleAssociatedDataCleaner: cleaner);
      await _focusNewestVehicle(tester);
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('garage-action-delete')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('garage-confirm-delete-vehicle')),
      );
      await _expirePendingDeletion(tester);

      expect(cleaner.deletedVehicleIds, [seeded.newest.id]);
      expect(await harness.repository.getVehicle(seeded.newest.id), isNull);
      expect(
        (await harness.repository.getActiveVehicle())?.id,
        seeded.active.id,
      );
    },
  );

  testWidgets('delete action keeps vehicle when associated cleanup fails', (
    tester,
  ) async {
    final seeded = await _seedThreeVehicles(harness);
    final cleaner = _RecordingVehicleDataCleaner()..fail = true;

    await _openGarage(tester, harness, vehicleAssociatedDataCleaner: cleaner);
    await _focusNewestVehicle(tester);
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('garage-action-delete')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('garage-confirm-delete-vehicle')),
    );
    await _expirePendingDeletion(tester);

    expect(cleaner.deletedVehicleIds, [seeded.newest.id]);
    expect(
      find.text('No pudimos limpiar los datos asociados. Inténtalo de nuevo.'),
      findsOneWidget,
    );
    expect(await harness.repository.getVehicle(seeded.newest.id), isNotNull);
    expect((await harness.repository.getActiveVehicle())?.id, seeded.active.id);
  });

  testWidgets('delete action is safe if screen disposes during cleanup', (
    tester,
  ) async {
    final seeded = await _seedThreeVehicles(harness);
    final cleaner = _RecordingVehicleDataCleaner()..gate = Completer<void>();
    final repository = _RecordingVehicleRepository(harness);

    await _openGarage(
      tester,
      harness,
      vehicleAssociatedDataCleaner: cleaner,
      vehicleRepository: repository,
    );
    await _focusNewestVehicle(tester);
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('garage-action-delete')),
    );
    await tester.tap(
      find.byKey(const ValueKey('garage-confirm-delete-vehicle')),
    );
    await _expirePendingDeletion(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    cleaner.gate!.complete();
    await tester.pumpAndSettle();

    expect(cleaner.deletedVehicleIds, [seeded.newest.id]);
    expect(repository.deletedVehicleIds, [seeded.newest.id]);
    expect(tester.takeException(), isNull);
  });

  for (final targetIndex in [0, 1, 2]) {
    testWidgets('focus helper selects newest identity at index $targetIndex', (
      tester,
    ) async {
      final seeded = await _seedThreeVehicles(harness);
      final order = [seeded.active, seeded.oldest]
        ..insert(targetIndex, seeded.newest);
      await _openGarage(tester, harness, vehicleListOverride: order);
      await _focusNewestVehicle(tester);
      _expectGarageInfoPanel(tester, seeded.newest);
      expect(
        (await harness.repository.getActiveVehicle())?.id,
        seeded.active.id,
      );
    });
  }

  testWidgets(
    'delete action reports repository failure after private cleanup',
    (tester) async {
      final seeded = await _seedThreeVehicles(harness);
      final cleaner = _RecordingVehicleDataCleaner();
      final repository = _RecordingVehicleRepository(harness)
        ..failDelete = true;

      await _openGarage(
        tester,
        harness,
        vehicleAssociatedDataCleaner: cleaner,
        vehicleRepository: repository,
      );
      await _focusNewestVehicle(tester);
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('garage-action-delete')),
      );
      await tester.tap(
        find.byKey(const ValueKey('garage-confirm-delete-vehicle')),
      );
      await _expirePendingDeletion(tester);

      expect(cleaner.deletedVehicleIds, [seeded.newest.id]);
      expect(repository.deletedVehicleIds, [seeded.newest.id]);
      expect(
        find.text(
          'Los datos privados se limpiaron, pero no pudimos eliminar el vehículo. Inténtalo de nuevo.',
        ),
        findsOneWidget,
      );
      expect(await harness.repository.getVehicle(seeded.newest.id), isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('delete failure keeps active and favorite state unchanged', (
    tester,
  ) async {
    final seeded = await _seedThreeVehicles(harness);
    final cleaner = _RecordingVehicleDataCleaner();
    final repository = _RecordingVehicleRepository(harness)..failDelete = true;

    await _openGarage(
      tester,
      harness,
      vehicleAssociatedDataCleaner: cleaner,
      vehicleRepository: repository,
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('garage-action-delete')),
    );
    await tester.tap(
      find.byKey(const ValueKey('garage-confirm-delete-vehicle')),
    );
    await _expirePendingDeletion(tester);

    expect(cleaner.deletedVehicleIds, [seeded.active.id]);
    expect(repository.deletedVehicleIds, [seeded.active.id]);
    expect(await harness.repository.getVehicle(seeded.active.id), isNotNull);
    expect((await harness.repository.getActiveVehicle())?.id, seeded.active.id);
    expect(
      find.text(
        'Los datos privados se limpiaron, pero no pudimos eliminar el vehículo. Inténtalo de nuevo.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'delete failure after favorite fallback rolls back visible selection',
    (tester) async {
      final seeded = await _seedThreeVehicles(harness);
      final preferences = _FailingVisualCleanupPreferences();
      await preferences.setString(
        VehicleRepository.activeVehiclePreferenceKey,
        seeded.active.id,
      );
      final repository = VehicleRepository(
        database: harness.database,
        preferences: preferences,
      );
      final cleaner = _RecordingVehicleDataCleaner();
      await _openGarage(
        tester,
        harness,
        preferences: preferences,
        vehicleRepository: repository,
        vehicleAssociatedDataCleaner: cleaner,
      );
      await tester.tap(find.text('Favorito'));
      await tester.pumpAndSettle();
      preferences.failedKey = vehicleVisualPreferenceKey(seeded.active.id);
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('garage-action-delete')),
      );
      await tester.tap(
        find.byKey(const ValueKey('garage-confirm-delete-vehicle')),
      );
      await _expirePendingDeletion(tester);
      expect(cleaner.deletedVehicleIds, [seeded.active.id]);
      expect(await repository.getVehicle(seeded.active.id), isNotNull);
      expect((await repository.getActiveVehicle())?.id, seeded.active.id);
      _expectGarageInfoPanel(tester, seeded.active);
      expect(find.text('1 de 1'), findsOneWidget);
      expect(
        find.text(
          'Los datos privados se limpiaron, pero no pudimos eliminar el vehículo. Inténtalo de nuevo.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'post-row delete failure does not restore selection to deleted vehicle',
    (tester) async {
      final seeded = await _seedThreeVehicles(harness);
      final cleaner = _RecordingVehicleDataCleaner();
      final repository = _RecordingVehicleRepository(harness)
        ..throwAfterDelete = true;

      await _openGarage(
        tester,
        harness,
        vehicleAssociatedDataCleaner: cleaner,
        vehicleRepository: repository,
      );
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('garage-action-delete')),
      );
      await tester.tap(
        find.byKey(const ValueKey('garage-confirm-delete-vehicle')),
      );
      await _expirePendingDeletion(tester);

      expect(cleaner.deletedVehicleIds, [seeded.active.id]);
      expect(repository.deletedVehicleIds, [seeded.active.id]);
      expect(await harness.repository.getVehicle(seeded.active.id), isNull);
      final activeAfterDelete = await harness.repository.getActiveVehicle();
      expect(activeAfterDelete?.id, isNot(seeded.active.id));
      expect({
        seeded.oldest.id,
        seeded.newest.id,
      }, contains(activeAfterDelete?.id));
      expect(
        find.text(
          'El vehículo se eliminó, pero no pudimos completar algunos ajustes locales.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'delete action delegates favorite fallback to repository without UI writes',
    (tester) async {
      final seeded = await _seedThreeVehicles(harness);
      final cleaner = _RecordingVehicleDataCleaner();
      final repository = _RecordingVehicleRepository(harness)
        ..failSetActive = true;

      await _openGarage(
        tester,
        harness,
        vehicleAssociatedDataCleaner: cleaner,
        vehicleRepository: repository,
      );
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('garage-action-delete')),
      );
      await tester.tap(
        find.byKey(const ValueKey('garage-confirm-delete-vehicle')),
      );
      await _expirePendingDeletion(tester);

      expect(cleaner.deletedVehicleIds, [seeded.active.id]);
      expect(repository.deletedVehicleIds, [seeded.active.id]);
      expect(repository.favoriteVehicleIds, isEmpty);
      expect(await harness.repository.getVehicle(seeded.active.id), isNull);
      expect(
        (await harness.repository.getActiveVehicle())?.id,
        seeded.newest.id,
      );
      expect(
        find.text('No pudimos completar la eliminación. Inténtalo de nuevo.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'deleting favorite keeps Favorito filter on repository fallback',
    (tester) async {
      final seeded = await _seedThreeVehicles(harness);
      await _openGarage(tester, harness);
      await tester.tap(find.text('Favorito'));
      await tester.pumpAndSettle();
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('garage-action-delete')),
      );
      await tester.tap(
        find.byKey(const ValueKey('garage-confirm-delete-vehicle')),
      );
      await _expirePendingDeletion(tester);
      expect(await harness.repository.getVehicle(seeded.active.id), isNull);
      expect(
        (await harness.repository.getActiveVehicle())?.id,
        seeded.newest.id,
      );
      _expectGarageInfoPanel(tester, seeded.newest);
      expect(find.text('1 de 1'), findsOneWidget);
      expect(find.text('Deshacer'), findsNothing);
    },
  );

  testWidgets('detail deletion failure stays on detail with an error', (
    tester,
  ) async {
    final seeded = await _seedThreeVehicles(harness);
    final repository = _RecordingVehicleRepository(harness)..failDelete = true;
    await _openGarage(tester, harness, vehicleRepository: repository);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(GarageScreen)),
    );
    expect(
      container.read(vehicleObligationStoreProvider).database,
      same(harness.database),
    );
    await tester.tap(
      find.byKey(ValueKey('garage-vehicle-card-${seeded.active.id}')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Activo'), findsNothing);
    expect(find.byKey(const ValueKey('detail-status-soat')), findsOneWidget);
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('detail-delete-vehicle')),
    );
    await tester.tap(find.byKey(const ValueKey('confirm-delete-vehicle')));
    await _expirePendingDeletion(tester);
    expect(find.text('Detalle del vehículo'), findsOneWidget);
    expect(
      find.text(
        'Los datos privados se limpiaron, pero no pudimos eliminar el vehículo. Inténtalo de nuevo.',
      ),
      findsOneWidget,
    );
    expect(await harness.repository.getVehicle(seeded.active.id), isNotNull);
    expect((await harness.repository.getActiveVehicle())?.id, seeded.active.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('add vehicle opens existing onboarding', (tester) async {
    await _openGarage(tester, harness);
    await tester.tap(find.byKey(const ValueKey('garage-add-vehicle')).first);
    await tester.pumpAndSettle();

    expect(find.text('Agregar vehículo'), findsWidgets);
    expect(
      find.byKey(const ValueKey('vehicle-choice-privateCar')),
      findsOneWidget,
    );
  });

  testWidgets('adding another vehicle does not replace active vehicle', (
    tester,
  ) async {
    final active = await _createVehicle(harness, plate: 'AAA111');
    await harness.repository.setActiveVehicle(active.id);

    await _openGarage(tester, harness, size: const Size(480, 900));
    await _tapVisible(tester, find.byKey(const ValueKey('garage-add-vehicle')));
    await tester.pumpAndSettle();
    await _completeOnboarding(
      tester,
      choiceKey: 'vehicle-choice-taxi',
      plate: 'TAX123',
    );

    expect((await harness.repository.getActiveVehicle())?.id, active.id);
    expect(await harness.repository.listVehicles(), hasLength(2));
  });

  testWidgets('detail keeps vehicle status routes scoped to tapped vehicle', (
    tester,
  ) async {
    await _createVehicle(harness, plate: 'AAA111');
    final other = await _createVehicle(harness, plate: 'BBB222');
    await harness.repository.setActiveVehicle(other.id);
    await VehicleObligationStore(harness.database).upsert(
      vehicleId: other.id,
      type: VehicleObligationType.soat,
      dueDate: DateTime(2026, 12, 31),
    );

    await _openGarage(tester, harness);
    await tester.tap(find.byKey(ValueKey('garage-vehicle-card-${other.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('detail-status-soat')));
    await tester.pumpAndSettle();

    expect(findPlateNumber('BBB222'), findsWidgets);
    expect(find.text('SOAT ACTIVO'), findsOneWidget);
    expect(find.text('¡Todo en regla!'), findsOneWidget);
    expect((await harness.repository.getActiveVehicle())?.id, other.id);
  });

  testWidgets(
    'P03 detail Pico entry opens scoped personal Pico inside Garage shell',
    (tester) async {
      await harness.preferences.setString(
        picoJurisdictionPreferenceKey,
        'co-dc-bogota',
      );
      final seeded = await _seedThreeVehicles(harness);

      await _openGarage(tester, harness);
      await _focusNewestVehicle(tester);
      await tester.tap(
        find.byKey(ValueKey('garage-vehicle-card-${seeded.newest.id}')),
      );
      await tester.pumpAndSettle();

      expect(findPlateNumber(seeded.newest.plate), findsWidgets);
      expect(
        find.text('Pendiente de activar datos de movilidad'),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('detail-status-pico')), findsOneWidget);
      expect(find.byKey(const ValueKey('detail-status-pico')).hitTestable(), findsOneWidget);

      final picoEntry = find.byKey(const ValueKey('detail-status-pico'));
      await tester.ensureVisible(picoEntry);
      await tester.pump();
      await tester.tap(picoEntry);
      await _pumpPicoRoute(tester);

      expect(find.byType(PicoDetailScreen), findsOneWidget);
      final pico = tester.widget<PicoDetailScreen>(
        find.byType(PicoDetailScreen),
      );
      expect(pico.vehicleId, seeded.newest.id);
      expect(
        find.byKey(const ValueKey('app-bottom-navigation')),
        findsOneWidget,
      );
      expect(_selectedBottomNavLabels(tester), contains('Garaje'));
      expect(
        (await harness.repository.getActiveVehicle())?.id,
        seeded.active.id,
      );
    },
  );

  testWidgets('Apps overlay opens over Garage and closes back to same focus', (
    tester,
  ) async {
    final seeded = await _seedThreeVehicles(harness);

    await _openGarage(tester, harness);
    await _focusNewestVehicle(tester);
    expect(findPlateNumber(seeded.newest.plate), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('tab-apps')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('apps-launcher-overlay')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('garage-compact-top-bar')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('tab-apps')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('apps-launcher-overlay')), findsNothing);
    expect(findPlateNumber(seeded.newest.plate), findsWidgets);
  });

  testWidgets('notification close returns to the same Garage focus', (
    tester,
  ) async {
    final seeded = await _seedThreeVehicles(harness);

    await _openGarage(tester, harness);
    await _focusNewestVehicle(tester);
    await tester.tap(find.byKey(const ValueKey('garage-notification-bell')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('notification-sheet-close')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-notification-sheet')), findsNothing);
    expect(findPlateNumber(seeded.newest.plate), findsWidgets);
    expect((await harness.repository.getActiveVehicle())?.id, seeded.active.id);
  });

  testWidgets('quick actions stay three columns at text scale 1', (
    tester,
  ) async {
    await _seedThreeVehicles(harness);
    await _openGarage(tester, harness);

    final maintenance = find.byKey(const ValueKey('garage-action-maintenance'));
    final documents = find.byKey(const ValueKey('garage-action-documents'));
    final delete = find.byKey(const ValueKey('garage-action-delete'));

    expect(tester.getTopLeft(maintenance).dy, tester.getTopLeft(documents).dy);
    expect(tester.getTopLeft(documents).dy, tester.getTopLeft(delete).dy);
    expect(
      tester.getTopLeft(maintenance).dx,
      lessThan(tester.getTopLeft(documents).dx),
    );
    expect(
      tester.getTopLeft(documents).dx,
      lessThan(tester.getTopLeft(delete).dx),
    );
  });

  for (final viewport in <({Size size, double textScale})>[
    (size: const Size(360, 800), textScale: 1.5),
    (size: const Size(360, 800), textScale: 2),
    (size: const Size(390, 844), textScale: 1.5),
    (size: const Size(390, 844), textScale: 2),
    (size: const Size(412, 915), textScale: 1.5),
    (size: const Size(412, 915), textScale: 2),
  ]) {
    testWidgets(
      'quick action labels remain readable at ${viewport.size.width.toInt()} '
      'text scale ${viewport.textScale}',
      (tester) async {
        await _seedThreeVehicles(harness);
        await _openGarage(
          tester,
          harness,
          size: viewport.size,
          textScaleFactor: viewport.textScale,
        );

        final actions = <({String key, String label})>[
          (key: 'garage-action-maintenance', label: 'Mantenimiento'),
          (key: 'garage-action-documents', label: 'Documentos'),
          (key: 'garage-action-delete', label: 'Eliminar'),
        ];
        for (final action in actions) {
          final actionFinder = find.byKey(ValueKey(action.key));
          final labelFinder = find.descendant(
            of: actionFinder,
            matching: find.text(action.label),
          );
          final label = tester.widget<Text>(labelFinder);
          final actionRect = tester.getRect(actionFinder);
          final labelRect = tester.getRect(labelFinder);

          expect(label.softWrap, isTrue, reason: action.label);
          expect(
            label.overflow,
            isNot(TextOverflow.fade),
            reason: action.label,
          );
          expect(labelRect.left, greaterThanOrEqualTo(actionRect.left));
          expect(labelRect.right, lessThanOrEqualTo(actionRect.right));
          expect(labelRect.top, greaterThanOrEqualTo(actionRect.top));
          expect(labelRect.bottom, lessThanOrEqualTo(actionRect.bottom));
        }

        final maintenanceTop = tester
            .getTopLeft(find.byKey(const ValueKey('garage-action-maintenance')))
            .dy;
        final documentsTop = tester
            .getTopLeft(find.byKey(const ValueKey('garage-action-documents')))
            .dy;
        final deleteTop = tester
            .getTopLeft(find.byKey(const ValueKey('garage-action-delete')))
            .dy;
        expect(maintenanceTop, lessThan(documentsTop));
        expect(documentsTop, lessThan(deleteTop));
        expect(
          tester
              .getTopLeft(find.byKey(const ValueKey('garage-add-vehicle')))
              .dy,
          greaterThan(
            tester
                .getBottomLeft(
                  find.byKey(const ValueKey('garage-quick-actions')),
                )
                .dy,
          ),
        );
      },
    );
  }

  testWidgets('Garage V2 viewports and text scales do not overflow', (
    tester,
  ) async {
    for (final viewport in [
      (name: '360x800', size: const Size(360, 800), scale: 1.0),
      (name: '360x780', size: const Size(360, 780), scale: 1.0),
      (name: '390x844', size: const Size(390, 844), scale: 1.0),
      (name: '412x915', size: const Size(412, 915), scale: 1.0),
      (name: '390x844 textScale 1.5', size: const Size(390, 844), scale: 1.5),
      (name: '390x844 textScale 2.0', size: const Size(390, 844), scale: 2.0),
    ]) {
      await _seedThreeVehicles(harness);
      await _openGarage(
        tester,
        harness,
        size: viewport.size,
        textScaleFactor: viewport.scale,
        boundedSettle: true,
      );

      expect(
        find.byKey(const ValueKey('garage-v2-scroll')),
        findsOneWidget,
        reason: viewport.name,
      );
      expect(tester.takeException(), isNull, reason: viewport.name);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await harness.dispose();
      harness = TestAppHarness();
    }
  });

  testWidgets('Garage carousel widens and grows when larger phones have room', (
    tester,
  ) async {
    final smallSeeded = await _seedThreeVehicles(harness);
    await _openGarage(
      tester,
      harness,
      size: const Size(360, 780),
      boundedSettle: true,
    );
    await _focusNewestVehicle(tester);
    final smallCarousel = tester.getSize(
      find.byKey(const ValueKey('garage-vehicle-carousel')),
    );
    final smallArt = tester.getSize(
      find.byKey(ValueKey('garage-vehicle-art-${smallSeeded.newest.id}')),
    );
    final smallPager = tester.widget<PageView>(
      find.descendant(
        of: find.byKey(const ValueKey('garage-vehicle-carousel')),
        matching: find.byType(PageView),
      ),
    );
    expect(smallPager.controller!.viewportFraction, moreOrLessEquals(0.70));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await harness.dispose();
    harness = TestAppHarness();

    final largeSeeded = await _seedThreeVehicles(harness);
    await _openGarage(
      tester,
      harness,
      size: const Size(430, 932),
      boundedSettle: true,
    );
    await _focusNewestVehicle(tester);
    final largeCarousel = tester.getSize(
      find.byKey(const ValueKey('garage-vehicle-carousel')),
    );
    final largeArt = tester.getSize(
      find.byKey(ValueKey('garage-vehicle-art-${largeSeeded.newest.id}')),
    );
    final largeScroll = tester.widget<SingleChildScrollView>(
      find.byKey(const ValueKey('garage-v2-scroll')),
    );

    expect(largeCarousel.height, greaterThan(smallCarousel.height));
    expect(largeArt.height, greaterThan(smallArt.height));
    expect(largeScroll.physics, isA<NeverScrollableScrollPhysics>());
    expect(tester.takeException(), isNull);
  });

  testWidgets('Garage V2 standard phones fit owner layout without scrolling', (
    tester,
  ) async {
    for (final viewport in [
      (name: '360x800', size: const Size(360, 800)),
      (name: '360x780', size: const Size(360, 780)),
      (name: '390x844', size: const Size(390, 844)),
      (name: '412x915', size: const Size(412, 915)),
    ]) {
      await _seedThreeVehicles(harness);
      await _openGarage(
        tester,
        harness,
        size: viewport.size,
        boundedSettle: true,
      );

      _expectGarageCoreAboveNav(tester, reason: '${viewport.name} active');
      await _focusNewestVehicle(tester);
      expect(find.text('No activo'), findsNothing);
      expect(
        find.byKey(const ValueKey('garage-action-make-active')),
        findsNothing,
      );
      _expectGarageCoreAboveNav(tester, reason: '${viewport.name} non-active');
      expect(tester.takeException(), isNull, reason: viewport.name);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await harness.dispose();
      harness = TestAppHarness();
    }
  });
}

class _SeededVehicles {
  const _SeededVehicles({
    required this.oldest,
    required this.active,
    required this.newest,
  });

  final VehicleProfile oldest;
  final VehicleProfile active;
  final VehicleProfile newest;
}

Future<_SeededVehicles> _seedThreeVehicles(TestAppHarness harness) async {
  final oldest = await _createVehicle(
    harness,
    plate: 'MOT123',
    kind: VehicleKind.motorcycle,
    nickname: 'Yamaha MT-07',
    year: 2021,
  );
  final active = await _createVehicle(
    harness,
    plate: 'ABC123',
    brand: 'Mazda',
    model: 'CX-5',
    year: 2022,
    city: 'Bogotá D. C.',
  );
  final newest = await _createVehicle(
    harness,
    plate: 'XYZ789',
    brand: 'Chevrolet',
    model: 'Onix',
    year: 2020,
    city: 'Medellín',
  );
  await harness.repository.setActiveVehicle(active.id);
  return _SeededVehicles(oldest: oldest, active: active, newest: newest);
}

Future<VehicleProfile> _createVehicle(
  TestAppHarness harness, {
  required String plate,
  VehicleKind kind = VehicleKind.car,
  VehicleServiceType serviceType = VehicleServiceType.private,
  String? subtype,
  String? nickname,
  String city = 'Bogota',
  String? brand,
  String? model,
  int? year,
  String? color,
}) {
  return harness.repository.createVehicle(
    plate: plate,
    kind: kind,
    serviceType: serviceType,
    subtype: subtype,
    nickname: nickname,
    registrationCity: city,
    brand: brand,
    model: model,
    year: year,
    color: color,
  );
}

Future<void> _openGarage(
  WidgetTester tester,
  TestAppHarness harness, {
  Size size = const Size(390, 844),
  double textScaleFactor = 1,
  bool boundedSettle = false,
  VehicleAssociatedDataCleaner? vehicleAssociatedDataCleaner,
  VehicleRepository? vehicleRepository,
  AppPreferences? preferences,
  List<VehicleProfile>? vehicleListOverride,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await harness.pump(
    tester,
    vehicleAssociatedDataCleaner: vehicleAssociatedDataCleaner,
    vehicleListOverride: vehicleListOverride,
    childOverride: preferences == null && vehicleRepository == null
        ? null
        : ProviderScope(
            overrides: [
              if (preferences != null)
                appPreferencesProvider.overrideWithValue(preferences),
              vehicleRepositoryProvider.overrideWithValue(
                vehicleRepository ?? harness.repository,
              ),
            ],
            child: const PicoRadarApp(),
          ),
  );
  await tester.tap(find.byKey(const ValueKey('tab-garage')));
  if (boundedSettle) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));
  } else {
    await tester.pumpAndSettle();
  }
}

class _RecordingVehicleDataCleaner extends VehicleAssociatedDataCleaner {
  _RecordingVehicleDataCleaner()
    : super(
        documentStore: PrivateVehicleDocumentStore(),
        defenseCaseStore: DefenseCaseStore(),
        peritajesDraftStore: PeritajesDraftStore(_MemoryPreferences()),
        preferences: _MemoryPreferences(),
      );

  final deletedVehicleIds = <String>[];
  Completer<void>? gate;
  var fail = false;

  @override
  Future<void> deleteForVehicle(String vehicleId) async {
    deletedVehicleIds.add(vehicleId);
    if (fail) {
      throw StateError('cleanup failed');
    }
    final activeGate = gate;
    if (activeGate != null) {
      await activeGate.future;
    }
  }
}

class _RecordingVehicleRepository extends VehicleRepository {
  _RecordingVehicleRepository(TestAppHarness harness)
    : super(database: harness.database, preferences: harness.preferences);

  final deletedVehicleIds = <String>[];
  var failDelete = false;
  var failSetActive = false;
  var throwAfterDelete = false;
  final favoriteVehicleIds = <String>[];
  int activeReadCount = 0;
  Completer<void>? favoriteGate;
  final favoriteStarted = Completer<void>();
  Completer<void>? deleteGate;
  final deleteStarted = Completer<void>();

  @override
  Future<VehicleProfile?> getActiveVehicle() {
    activeReadCount += 1;
    return super.getActiveVehicle();
  }

  @override
  Future<void> deleteVehicle(String id) async {
    deletedVehicleIds.add(id);
    if (!deleteStarted.isCompleted) deleteStarted.complete();
    final gate = deleteGate;
    if (gate != null) await gate.future;
    if (failDelete) {
      throw StateError('delete failed');
    }
    await super.deleteVehicle(id);
    if (throwAfterDelete) {
      throw StateError('delete post-row failure');
    }
  }

  @override
  Future<void> setActiveVehicle(String id) async {
    favoriteVehicleIds.add(id);
    if (!favoriteStarted.isCompleted) favoriteStarted.complete();
    final gate = favoriteGate;
    if (gate != null) await gate.future;
    if (failSetActive) {
      throw StateError('active fallback failed');
    }
    await super.setActiveVehicle(id);
  }
}

class _FailingVisualCleanupPreferences extends _MemoryPreferences {
  String? failedKey;

  @override
  Future<void> remove(String key) async {
    if (key == failedKey) throw StateError('visual cleanup failed');
    await super.remove(key);
  }
}

class _MemoryPreferences implements AppPreferences {
  final values = <String, Object?>{};

  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;

  @override
  Future<int?> getInt(String key) async => values[key] as int?;

  @override
  Future<String?> getString(String key) async => values[key] as String?;

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<void> setBool(String key, bool value) async {
    values[key] = value;
  }

  @override
  Future<void> setInt(String key, int value) async {
    values[key] = value;
  }

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

Future<void> _goTo(WidgetTester tester, String location) async {
  final context = tester.element(
    find.byKey(const ValueKey('app-bottom-navigation')),
  );
  GoRouter.of(context).go(location);
  await tester.pumpAndSettle();
}

Future<void> _focusNewestVehicle(WidgetTester tester) async {
  final target = find.descendant(
    of: find.byKey(const ValueKey('garage-info-panel')),
    matching: findPlateNumber('XYZ789'),
  );
  await tester.ensureVisible(
    find.byKey(const ValueKey('garage-vehicle-carousel')),
  );
  await tester.pumpAndSettle();
  final carousel = find.byKey(const ValueKey('garage-vehicle-carousel'));
  final pageView = find.descendant(
    of: carousel,
    matching: find.byType(PageView),
  );
  final pageWidth =
      tester.getSize(pageView).width *
      tester.widget<PageView>(pageView).controller!.viewportFraction;
  // Locate by identity so callers do not depend on carousel ordering.
  for (final direction in [-1, 1]) {
    for (var attempt = 0; attempt < 3; attempt += 1) {
      if (target.evaluate().isNotEmpty) {
        return;
      }
      await tester.timedDrag(
        carousel,
        Offset(direction * pageWidth, 0),
        const Duration(milliseconds: 500),
      );
      await tester.pumpAndSettle();
    }
  }
  expect(target, findsOneWidget);
}

void _expectGarageInfoPanel(WidgetTester tester, VehicleProfile vehicle) {
  final panel = find.byKey(const ValueKey('garage-info-panel'));
  expect(
    find.descendant(of: panel, matching: findPlateNumber(vehicle.plate)),
    findsOneWidget,
  );
  expect(
    find.descendant(of: panel, matching: find.text(vehicle.registrationCity!)),
    findsOneWidget,
  );
  expect(
    find.descendant(of: panel, matching: find.text('${vehicle.year}')),
    findsOneWidget,
  );
}

void _expectGarageCoreAboveNav(WidgetTester tester, {required String reason}) {
  final infoPanel = tester.getSize(
    find.byKey(const ValueKey('garage-info-panel')),
  );
  final addBottom = tester
      .getBottomLeft(find.byKey(const ValueKey('garage-add-vehicle')))
      .dy;
  final actionsBottom = tester
      .getBottomLeft(find.byKey(const ValueKey('garage-quick-actions')))
      .dy;
  final navTop = tester
      .getTopLeft(find.byKey(const ValueKey('app-bottom-navigation')))
      .dy;

  expect(infoPanel.height, lessThanOrEqualTo(122), reason: reason);
  expect(addBottom, lessThan(navTop), reason: reason);
  expect(actionsBottom, lessThan(navTop), reason: reason);
  expect(find.byKey(const ValueKey('garage-action-detail')), findsNothing);
  expect(
    find.byKey(const ValueKey('garage-action-maintenance')),
    findsOneWidget,
  );
  expect(find.byKey(const ValueKey('garage-action-documents')), findsOneWidget);
  expect(find.byKey(const ValueKey('garage-action-delete')), findsOneWidget);
}

List<String> _selectedBottomNavLabels(WidgetTester tester) {
  return tester
      .widgetList<Semantics>(find.byType(Semantics))
      .where((widget) => widget.properties.selected == true)
      .map((widget) => widget.properties.label)
      .whereType<String>()
      .toList();
}

Future<void> _tapVisible(
  WidgetTester tester,
  Finder finder, {
  bool settle = true,
}) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }
}

Future<void> _expirePendingDeletion(WidgetTester tester) async {
  await tester.pumpAndSettle();
  expect(find.text('Eliminación pendiente'), findsOneWidget);
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

Future<void> _pumpPicoRoute(WidgetTester tester) async {
  for (var i = 0; i < 20; i += 1) {
    await tester.pump(const Duration(milliseconds: 300));
    if (find.byType(PicoDetailScreen).evaluate().isNotEmpty) {
      return;
    }
  }
}

Future<void> _completeOnboarding(
  WidgetTester tester, {
  required String choiceKey,
  String plate = 'abc 123',
  String city = 'Bogota',
}) async {
  await tester.tap(find.byKey(ValueKey(choiceKey)));
  await tester.pumpAndSettle();
  await _enterText(tester, 'vehicle-plate-field', plate);
  await _selectManualCity(tester, city);
  await _tapSave(tester);
}

Future<void> _enterText(WidgetTester tester, String key, String value) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.enterText(finder, value);
  await tester.pump();
}

Future<void> _selectManualCity(WidgetTester tester, String value) async {
  await tester.ensureVisible(find.byKey(const ValueKey('vehicle-city-field')));
  await tester.tap(find.byKey(const ValueKey('vehicle-city-field')));
  await tester.pumpAndSettle();
  await _enterText(tester, 'registration-city-search-field', value);
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(const ValueKey('registration-city-manual-option')),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapSave(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('vehicle-save-button'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}
