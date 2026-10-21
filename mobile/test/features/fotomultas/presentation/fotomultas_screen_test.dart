import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:picoradar/app/router/app_routes.dart';
import 'package:picoradar/app/theme/app_theme.dart';
import 'package:picoradar/app/shell/app_shell.dart';
import 'package:picoradar/core/design_system/navigation.dart';
import 'package:picoradar/features/driving/data/camera_pack_loader.dart';
import 'package:picoradar/features/driving/domain/traffic_camera.dart';
import 'package:picoradar/features/fotomultas/presentation/fotomultas_screen.dart';
import 'package:picoradar/features/fotomultas/presentation/department_geometry.dart';
import 'package:picoradar/features/vehicle_status/platform/external_launcher.dart';

import '../../vehicle_status/presentation/v01b_obligations_test_font.dart';

late DepartmentGeometry _geometry;
late Uint8List _tileBytes;
late CameraPack _inventory;

void main() {
  setUpAll(() async {
    await loadV01bObligationsTestFont();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    _inventory = CameraPack.fromJson(
      (jsonDecode(
        await File('assets/datasets/cameras/cameras_v1.json').readAsString(),
      ) as Map).cast<String, Object?>(),
    );
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const Color(0xffeff4f6), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(1, 1);
    _tileBytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
    image.dispose();
    picture.dispose();
    _geometry = DepartmentGeometry.fromJson(
      jsonDecode(await File(departmentGeometryAsset).readAsString())
          as Map<String, dynamic>,
    );
  });
  for (final size in const [
    Size(360, 780),
    Size(360, 800),
    Size(390, 844),
    Size(412, 915),
    Size(430, 932),
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('department mockup geometry $size text $scale', (
        tester,
      ) async {
        await _pumpScreen(
          tester,
          size: size,
          textScale: scale,
          productionTheme: true,
          bottomNavigation: true,
          loader: _realPack,
        );
        await tester.pumpAndSettle();
        await _chooseDepartment(tester, 'ANT');
        final selection = find.byKey(
          const ValueKey('fotomultas-compact-selection'),
        );
        if (selection.evaluate().isNotEmpty) {
          await tester.tap(selection);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byKey(const ValueKey('fotomultas-view-cameras')));
        await tester.pumpAndSettle();
        final map = tester.getRect(
          find.byKey(const ValueKey('fotomultas-department-map')),
        );
        final clear = tester.getRect(
          find.byKey(const ValueKey('fotomultas-map-clear-area')),
        );
        expect(map.width, size.width);
        if (scale == 1) {
          expect(map.height, greaterThanOrEqualTo(500));
          expect(clear.height, greaterThanOrEqualTo(330));
        }
        expect(clear.height, greaterThanOrEqualTo(220));
        for (final key in [
          'fotomultas-open-camera-search',
          'fotomultas-speed-filter',
          'fotomultas-department-open-source',
          'fotomultas-open-driving',
          'fotomultas-department-zoom-in',
          'fotomultas-department-zoom-out',
          'fotomultas-department-reset',
        ]) {
          final control = find.byKey(ValueKey(key));
          expect(tester.getSize(control).height, greaterThanOrEqualTo(48));
          expect(control.hitTestable(), findsOneWidget);
          expect(tester.getRect(control).overlaps(clear), isFalse, reason: key);
        }
        final zoom = find.byKey(
          const ValueKey('fotomultas-department-zoom-in'),
        );
        final zoomRect = tester.getRect(zoom);
        final filterRect = tester.getRect(
          find.byKey(const ValueKey('fotomultas-speed-filter')),
        );
        final upperBand = filterRect.expandToInclude(
          tester.getRect(find.byKey(const ValueKey('fotomultas-result-count'))),
        );
        expect(zoomRect.top, closeTo(upperBand.bottom + 12, 1));
        expect(zoomRect.right, closeTo(map.right - 12, 1));
        expect(zoomRect.center.dy, lessThan(map.center.dy));
        final surface = find.descendant(
          of: zoom,
          matching: find.byType(DecoratedBox),
        );
        expect(tester.getSize(surface), const Size(36, 36));
        expect(
          (tester.widget<DecoratedBox>(surface).decoration as BoxDecoration)
              .color!
              .a,
          closeTo(.78, .01),
        );
        expect(find.text('76 de 76'), findsOneWidget);
        for (final label in ['Fotomultas', 'Antioquia', '76 de 76']) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.text(label),
              matching: find.byType(RichText),
            ),
          );
          expect(paragraph.didExceedMaxLines, isFalse, reason: label);
        }
        final source = find.byKey(
          const ValueKey('fotomultas-department-open-source'),
        );
        final driving = find.byKey(const ValueKey('fotomultas-open-driving'));
        final attribution = tester.getRect(
          find.byKey(const ValueKey('fotomultas-map-attribution')),
        );
        expect(attribution.overlaps(tester.getRect(source)), isFalse);
        expect(attribution.overlaps(tester.getRect(driving)), isFalse);
        expect(attribution.bottom, lessThanOrEqualTo(map.bottom));
        if (find.text('Abrir Conducir').evaluate().isEmpty) {
          for (final control in [source, driving]) {
            expect(tester.getSize(control), const Size(48, 48));
            final icon = find.descendant(
              of: control,
              matching: find.byType(Icon),
            );
            expect(tester.getCenter(icon), tester.getCenter(control));
          }
        }
        debugPrint(
          'DEPARTMENT_METRICS $size scale=$scale map=${map.height} clear=${clear.height}',
        );
        expect(find.byType(TextField), findsNothing);
        await _capture(
          tester,
          'department-${size.width.toInt()}x${size.height.toInt()}-$scale',
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets(
    'department sheets apply and cancel without changing the camera',
    (tester) async {
      final launcher = _FakeExternalLauncher();
      var loads = 0;
      await _pumpScreen(
        tester,
        launcher: launcher,
        loader: () async {
          loads++;
          return _pack();
        },
      );
      await tester.pumpAndSettle();
      await _openDepartmentList(tester, 'BOG');
      await tester.tap(find.byKey(const ValueKey('fotomultas-view-toggle')));
      await tester.pumpAndSettle();
      final map = find.byKey(const ValueKey('fotomultas-department-map'));
      final controller = tester.widget<FlutterMap>(map).mapController!;
      controller.move(const LatLng(4.7, -74.1), 12);
      await tester.pumpAndSettle();
      final center = controller.camera.center;
      final zoom = controller.camera.zoom;
      await tester.tap(
        find.byKey(const ValueKey('fotomultas-open-camera-search')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('fotomultas-search-field')),
        'not applied',
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('2 de 2'), findsOneWidget);
      await _searchCameras(tester, 'cl 80');
      expect(find.text('1 de 2'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('fotomultas-speed-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sin velocidad reportada'));
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('1 de 2'), findsOneWidget);
      await _filterSpeed(tester, 'Sin velocidad reportada');
      expect(find.text('0 de 2'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('fotomultas-view-toggle')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('fotomultas-department-zoom-in')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('fotomultas-view-toggle')));
      await tester.pumpAndSettle();
      expect(tester.widget<FlutterMap>(map).mapController, same(controller));
      expect(controller.camera.center, center);
      expect(controller.camera.zoom, zoom);
      await tester.tap(
        find.byKey(const ValueKey('fotomultas-department-open-source')),
      );
      await tester.pumpAndSettle();
      expect(launcher.openedUris, isEmpty);
      expect(
        find.byKey(const ValueKey('fotomultas-department-source-sheet')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('fotomultas-department-source-link')),
      );
      await tester.pumpAndSettle();
      expect(launcher.openedUris, [_sourceUrl]);
      expect(loads, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'department long name remains complete and extra height goes to map',
    (tester) async {
      for (final scale in [1.0, 1.5, 2.0]) {
        double? previousMapHeight;
        double? previousHeaderHeight;
        for (final height in [780.0, 932.0]) {
          await _pumpScreen(
            tester,
            size: Size(360, height),
            textScale: scale,
            productionTheme: true,
            bottomNavigation: true,
            loader: _realPack,
          );
          await tester.pumpAndSettle();
          await _openDepartmentList(tester, 'NSA');
          await tester.tap(
            find.byKey(const ValueKey('fotomultas-view-toggle')),
          );
          await tester.pumpAndSettle();
          final name = find.descendant(
            of: find.byKey(const ValueKey('fotomultas-department-header')),
            matching: find.text('Norte de Santander'),
          );
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: name, matching: find.byType(RichText)),
          );
          expect(paragraph.didExceedMaxLines, isFalse);
          final mapHeight = tester
              .getSize(find.byKey(const ValueKey('fotomultas-department-map')))
              .height;
          final headerHeight = tester
              .getSize(
                find.byKey(const ValueKey('fotomultas-department-header')),
              )
              .height;
          if (previousMapHeight != null) {
            expect(mapHeight - previousMapHeight, closeTo(152, .1));
            expect(headerHeight, previousHeaderHeight);
          }
          previousMapHeight = mapHeight;
          previousHeaderHeight = headerHeight;
          await _capture(tester, 'department-long-$height-$scale');
          expect(tester.takeException(), isNull);
        }
      }
    },
  );
  testWidgets(
    'empty results and tile failure share one recoverable status band',
    (tester) async {
      for (final scale in [1.0, 2.0]) {
        await _pumpScreen(
          tester,
          size: const Size(360, 780),
          textScale: scale,
          productionTheme: true,
          bottomNavigation: true,
        );
        await tester.pumpAndSettle();
        await _openDepartmentList(tester, 'BOG');
        await tester.tap(find.byKey(const ValueKey('fotomultas-view-toggle')));
        await tester.pumpAndSettle();
        final map = find.byKey(const ValueKey('fotomultas-department-map'));
        final controller = tester.widget<FlutterMap>(map).mapController!;
        final center = controller.camera.center;
        final zoom = controller.camera.zoom;
        await _searchCameras(tester, 'sin coincidencias');
        final tiles = tester.widget<TileLayer>(find.byType(TileLayer));
        final tile = TileImage(
          vsync: tester,
          coordinates: const TileCoordinates(0, 0, 4),
          imageProvider: MemoryImage(_tileBytes),
          onLoadComplete: (_) {},
          onLoadError: (_, _, _) {},
          tileDisplay: const TileDisplay.instantaneous(),
          errorImage: null,
          cancelLoading: Completer<void>(),
        );
        tiles.errorTileCallback!(
          tile,
          StateError('test unavailable'),
          StackTrace.current,
        );
        await tester.pump();
        await tester.pumpAndSettle();
        tile.dispose();
        final status = find.byKey(const ValueKey('fotomultas-map-status'));
        expect(status, findsOneWidget);
        expect(
          find.descendant(
            of: status,
            matching: find.text('Mapa no disponible'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: status, matching: find.text('Sin resultados')),
          findsOneWidget,
        );
        for (final key in [
          'fotomultas-open-camera-search',
          'fotomultas-speed-filter',
          'fotomultas-department-reset',
          'fotomultas-department-open-source',
        ]) {
          expect(
            tester
                .getRect(status)
                .overlaps(tester.getRect(find.byKey(ValueKey(key)))),
            isFalse,
          );
        }
        await _capture(tester, 'department-offline-empty-$scale');
        await tester.tap(find.byKey(const ValueKey('fotomultas-retry-tiles')));
        await tester.pumpAndSettle();
        expect(find.text('Mapa no disponible'), findsNothing);
        expect(find.text('Sin resultados'), findsOneWidget);
        expect(controller.camera.center, center);
        expect(controller.camera.zoom, zoom);
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets('clear search remains a draft until confirmed', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpScreen(tester);
    await tester.pumpAndSettle();
    await _openDepartmentList(tester, 'BOG');
    for (final key in [
      'fotomultas-open-camera-search',
      'fotomultas-speed-filter',
      'fotomultas-department-open-source',
      'fotomultas-open-driving',
    ]) {
      expect(
        tester
            .getSemantics(find.byKey(ValueKey(key)))
            .getSemanticsData()
            .hasAction(ui.SemanticsAction.tap),
        isTrue,
        reason: key,
      );
    }
    final searchNode = tester.getSemantics(
      find.byKey(const ValueKey('fotomultas-open-camera-search')),
    );
    searchNode.owner!.performAction(searchNode.id, ui.SemanticsAction.tap);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('fotomultas-search-field')),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    semantics.dispose();
    await _searchCameras(tester, 'cl 80');
    expect(find.text('1 de 2'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('fotomultas-open-camera-search')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limpiar'));
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('1 de 2'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('fotomultas-open-camera-search')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limpiar'));
    await tester.tap(find.byKey(const ValueKey('fotomultas-apply-search')));
    await tester.pumpAndSettle();
    expect(find.text('2 de 2'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
  testWidgets('department source validates URLs and offers an explicit retry', (
    tester,
  ) async {
    for (final invalid in [false, true]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      final launcher = _FakeExternalLauncher(openResult: false);
      final pack = _pack();
      await _pumpScreen(
        tester,
        launcher: launcher,
        loader: () async => invalid
            ? CameraPack(
                source: const CameraPackSource(
                  name: 'ANSV',
                  pageUrl: 'file:///private',
                  dataUrl: _sourceUrl,
                  fetchedAtUtc: '2026-08-31T10:44:00-05:00',
                ),
                cameras: pack.cameras,
              )
            : pack,
      );
      await tester.pumpAndSettle();
      await _openDepartmentList(tester, 'BOG');
      await tester.tap(
        find.byKey(const ValueKey('fotomultas-department-open-source')),
      );
      await tester.pumpAndSettle();
      expect(launcher.openedUris, isEmpty);
      await tester.tap(
        find.byKey(const ValueKey('fotomultas-department-source-link')),
      );
      await tester.pumpAndSettle();
      expect(find.text('No pudimos abrir la fuente ANSV.'), findsOneWidget);
      expect(launcher.openedUris.length, invalid ? 0 : 1);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(launcher.openedUris.length, invalid ? 0 : 2);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('owner national map uses geographic polygons and zoom controls', (
    tester,
  ) async {
    await _pumpScreen(tester, size: const Size(360, 780));
    await tester.pumpAndSettle();
    expect(find.byType(PolygonLayer<String>), findsWidgets);
    expect(
      find.byKey(const ValueKey('fotomultas-country-zoom-in')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('fotomultas-country-zoom-out')),
      findsOneWidget,
    );
    expect(find.byType(TileLayer), findsNothing);
    for (final key in [
      'fotomultas-country-reset',
      'fotomultas-country-zoom-in',
      'fotomultas-country-zoom-out',
    ]) {
      final button = find.byKey(ValueKey(key));
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
      final surface = find.descendant(
        of: button,
        matching: find.byType(DecoratedBox),
      );
      expect(tester.getSize(surface).height, 36);
      final decoration =
          tester.widget<DecoratedBox>(surface).decoration as BoxDecoration;
      expect(decoration.color!.a, closeTo(0.78, 0.01));
    }
    expect(find.text('Sin departamento seleccionado'), findsNothing);
    expect(
      find.byKey(const ValueKey('fotomultas-selected-department')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('fotomultas-compact-selection')),
      findsNothing,
    );
  });
  testWidgets(
    'selection is compact and map camera does not jump on a map tap',
    (tester) async {
      await _pumpScreen(
        tester,
        size: const Size(360, 780),
        productionTheme: true,
        bottomNavigation: true,
        loader: _realPack,
      );
      await tester.pumpAndSettle();
      final map = find.byKey(const ValueKey('fotomultas-colombia-map'));
      final controller = tester
          .widget<FlutterMap>(
            find.descendant(of: map, matching: find.byType(FlutterMap)),
          )
          .mapController!;
      final fullHeight = tester.getSize(map).height;
      final footerY = tester
          .getTopLeft(find.byKey(const ValueKey('fotomultas-open-driving')))
          .dy;
      controller.move(_geometry.labelParts['ANT']!.anchor, 8);
      await tester.pumpAndSettle();
      final center = controller.camera.center;
      final zoom = controller.camera.zoom;
      await tester.tapAt(
        tester.getTopLeft(map) + controller.camera.latLngToScreenOffset(center),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('fotomultas-selected-department'));
      expect(card, findsOneWidget);
      final cardHeight = tester.getSize(card).height;
      expect(cardHeight, inInclusiveRange(72, 88));
      expect(
        tester
            .getSize(find.byKey(const ValueKey('fotomultas-view-cameras')))
            .height,
        greaterThanOrEqualTo(48),
      );
      expect(
        fullHeight - tester.getSize(map).height,
        closeTo(cardHeight + 4, 0.1),
      );
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('fotomultas-open-driving')))
            .dy,
        footerY,
      );
      expect(controller.camera.center, center);
      expect(controller.camera.zoom, zoom);
      await tester.tap(find.byKey(const ValueKey('fotomultas-country-reset')));
      await tester.pumpAndSettle();
      expect(card, findsNothing);
      expect(tester.getSize(map).height, fullHeight);
      final bounds = _geometry.continentalBounds;
      for (final point in [bounds.northWest, bounds.southEast]) {
        final offset = controller.camera.latLngToScreenOffset(point);
        expect(offset.dy, inInclusiveRange(0, fullHeight));
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('additional screen height goes to the map only', (tester) async {
    await _pumpScreen(
      tester,
      size: const Size(390, 844),
      productionTheme: true,
      bottomNavigation: true,
      loader: _realPack,
    );
    await tester.pumpAndSettle();
    await _chooseDepartment(tester, 'ANT');
    final map = find.byKey(const ValueKey('fotomultas-colombia-map'));
    final card = find.byKey(const ValueKey('fotomultas-selected-department'));
    final height = tester.getSize(map).height;
    final cardSize = tester.getSize(card);
    final searchSize = tester.getSize(
      find.byKey(const ValueKey('fotomultas-open-department-search')),
    );
    tester.view.physicalSize = const Size(390, 1044);
    await tester.pumpAndSettle();
    expect(tester.getSize(map).height - height, closeTo(200, 0.1));
    expect(tester.getSize(card), cardSize);
    expect(
      tester.getSize(
        find.byKey(const ValueKey('fotomultas-open-department-search')),
      ),
      searchSize,
    );
    expect(find.byType(Scrollable), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final size in const [
    Size(360, 780),
    Size(360, 800),
    Size(390, 844),
    Size(412, 915),
    Size(430, 932),
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('owner map with shell $size scale $scale', (tester) async {
        await _pumpScreen(
          tester,
          size: size,
          textScale: scale,
          productionTheme: true,
          bottomNavigation: true,
          loader: _realPack,
        );
        await tester.pumpAndSettle();
        final header = find.byKey(const ValueKey('fotomultas-national-header'));
        final title = find.byKey(const ValueKey('fotomultas-header-title'));
        final inventory = find.byKey(
          const ValueKey('fotomultas-header-inventory'),
        );
        expect(header, findsOneWidget);
        expect(find.text('Snapshot ANSV · 31/08/26'), findsOneWidget);
        expect(find.text('360 registros autorizados'), findsOneWidget);
        expect(
          tester.getRect(header).contains(tester.getRect(inventory).center),
          isTrue,
        );
        expect(
          tester.getRect(title).overlaps(tester.getRect(inventory)),
          isFalse,
        );
        if (scale == 1) {
          expect(tester.getRect(title).left, lessThanOrEqualTo(52));
          expect(
            tester.getRect(inventory).left,
            greaterThan(tester.getRect(title).right),
          );
          expect(
            tester.getRect(title).center.dy,
            closeTo(tester.getRect(inventory).center.dy, 1),
          );
        }
        final map = find.byKey(const ValueKey('fotomultas-colombia-map'));
        expect(tester.getSize(map).height, greaterThanOrEqualTo(220));
        expect(find.byType(Scrollable), findsNothing);
        expect(tester.takeException(), isNull);
        await _capture(
          tester,
          'national-${size.width.toInt()}x${size.height.toInt()}-$scale',
        );
        await _chooseDepartment(tester, 'ANT');
        expect(find.text('Antioquia'), findsWidgets);
        expect(tester.getSize(map).height, greaterThanOrEqualTo(220));
        final labels = find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith(
                'fotomultas-map-label-',
              ),
        );
        final rects = [
          for (final element in labels.evaluate())
            tester.getRect(find.byWidget(element.widget)),
        ];
        for (var i = 0; i < rects.length; i++) {
          for (var j = i + 1; j < rects.length; j++) {
            expect(rects[i].overlaps(rects[j]), isFalse);
          }
        }
        expect(tester.takeException(), isNull);
        await _capture(
          tester,
          'antioquia-${size.width.toInt()}x${size.height.toInt()}-$scale',
        );
      });
    }
  }
  testWidgets('department camera survives an empty filter and view switch', (
    tester,
  ) async {
    await _pumpScreen(tester);
    await tester.pumpAndSettle();
    await _openDepartmentList(tester, 'BOG');
    await tester.tap(find.byKey(const ValueKey('fotomultas-view-toggle')));
    await tester.pumpAndSettle();
    final finder = find.byKey(const ValueKey('fotomultas-department-map'));
    final controller = tester.widget<FlutterMap>(finder).mapController!;
    await tester.tap(
      find.byKey(const ValueKey('fotomultas-department-zoom-in')),
    );
    await tester.pumpAndSettle();
    final zoom = controller.camera.zoom;
    await _searchCameras(tester, 'no existe');
    await tester.pumpAndSettle();
    await _searchCameras(tester, '');
    await tester.pumpAndSettle();
    expect(tester.widget<FlutterMap>(finder).mapController, same(controller));
    expect(controller.camera.zoom, zoom);
  });
  testWidgets('pan and pinch never select or reload the inventory', (
    tester,
  ) async {
    var loads = 0;
    await _pumpScreen(
      tester,
      loader: () async {
        loads++;
        return _inventory;
      },
    );
    await tester.pumpAndSettle();
    final map = find.byKey(const ValueKey('fotomultas-colombia-map'));
    final center = tester.getCenter(map);
    final a = await tester.startGesture(
      center - const Offset(35, 0),
      pointer: 1,
    );
    final b = await tester.startGesture(
      center + const Offset(35, 0),
      pointer: 2,
    );
    await a.moveBy(const Offset(-40, 0));
    await b.moveBy(const Offset(40, 0));
    await tester.pump();
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    await tester.dragFrom(center, const Offset(45, -30));
    await tester.pumpAndSettle();
    expect(find.text('Sin departamento seleccionado'), findsNothing);
    expect(find.text('Departamentos cercanos'), findsNothing);
    expect(loads, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('small territory opens candidates and reset clears selection', (
    tester,
  ) async {
    await _pumpScreen(tester);
    await tester.pumpAndSettle();
    final map = find.byKey(const ValueKey('fotomultas-colombia-map'));
    final flutterMap = find
        .descendant(of: map, matching: find.byType(FlutterMap))
        .first;
    final controller = tester.widget<FlutterMap>(flutterMap).mapController!;
    final anchor = _geometry.labelParts['BOG']!.anchor;
    expect(
      _geometry.candidates(anchor, controller.camera.zoom).length,
      greaterThan(1),
    );
    final position =
        tester.getTopLeft(map) + controller.camera.latLngToScreenOffset(anchor);
    await tester.tapAt(position);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('Departamentos cercanos'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('fotomultas-department-tile-BOG')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('fotomultas-department-tile-BOG')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('fotomultas-view-cameras')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('fotomultas-country-reset')));
    await tester.pumpAndSettle();
    expect(find.text('Sin departamento seleccionado'), findsNothing);
    expect(
      find.byKey(const ValueKey('fotomultas-selected-department')),
      findsNothing,
    );
  });
  testWidgets('national selection and zoom survive the explorer', (
    tester,
  ) async {
    await _pumpScreen(tester);
    await tester.pumpAndSettle();
    await _chooseDepartment(tester, 'ANT');
    final national = find
        .descendant(
          of: find.byKey(const ValueKey('fotomultas-colombia-map')),
          matching: find.byType(FlutterMap),
        )
        .first;
    final controller = tester.widget<FlutterMap>(national).mapController!;
    final center = controller.camera.center;
    final zoom = controller.camera.zoom;
    await tester.tap(find.byKey(const ValueKey('fotomultas-view-cameras')));
    await tester.pumpAndSettle();
    await _backToCountry(tester);
    expect(tester.widget<FlutterMap>(national).mapController, same(controller));
    expect(controller.camera.center, center);
    expect(controller.camera.zoom, zoom);
    expect(find.text('Antioquia'), findsWidgets);
  });
  testWidgets('an outlying camera can be located explicitly from its list', (
    tester,
  ) async {
    await _pumpScreen(tester);
    await tester.pumpAndSettle();
    await _openDepartmentList(tester, 'ANT');
    await tester.tap(find.byKey(const ValueKey('fotomultas-camera-known-med')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fotomultas-locate-camera')));
    await tester.pumpAndSettle();
    final controller = tester
        .widget<FlutterMap>(
          find.byKey(const ValueKey('fotomultas-department-map')),
        )
        .mapController!;
    expect(controller.camera.center, const LatLng(4.7, -74.1));
    expect(controller.camera.zoom, 16);
  });
  testWidgets('coincident cameras expose every record, not only the first', (
    tester,
  ) async {
    await _pumpScreen(tester);
    await tester.pumpAndSettle();
    await _openDepartmentList(tester, 'BOG');
    await tester.tap(find.byKey(const ValueKey('fotomultas-view-toggle')));
    await tester.pumpAndSettle();
    final controller = tester
        .widget<FlutterMap>(
          find.byKey(const ValueKey('fotomultas-department-map')),
        )
        .mapController!;
    controller.move(const LatLng(4.7, -74.1), 16);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == '2 cámaras',
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('fotomultas-cluster-record-known-bog')),
      findsOneWidget,
    );
    final second = find.byKey(
      const ValueKey('fotomultas-cluster-record-unknown-bog'),
    );
    expect(second, findsOneWidget);
    await tester.tap(second);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('fotomultas-detail-sheet')),
      findsOneWidget,
    );
    expect(find.text('AK 30 - CL 45'), findsOneWidget);
  });
  for (final size in const [Size(360, 800), Size(390, 844), Size(412, 915)]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('V01B camera summary is readable $size scale $scale', (
        tester,
      ) async {
        await _pumpScreen(
          tester,
          size: size,
          textScale: scale,
          productionTheme: true,
        );
        await tester.pumpAndSettle();
        final metric = find.text('Snapshot ANSV · 31/08/26');
        final richText = find.descendant(
          of: metric,
          matching: find.byType(RichText),
        );
        final paragraph = tester.renderObject<RenderParagraph>(richText);
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(find.text('Snapshot ANSV · 31/08/26'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
      testWidgets('V01B camera detail actions reachable $size scale $scale', (
        tester,
      ) async {
        final launcher = _FakeExternalLauncher();
        await _pumpScreen(
          tester,
          launcher: launcher,
          size: size,
          textScale: scale,
          productionTheme: true,
        );
        await tester.pumpAndSettle();
        await _openDepartmentList(tester, 'BOG');
        final camera = find.byKey(
          const ValueKey('fotomultas-camera-known-bog'),
        );
        await _ensureCameraVisible(tester, camera);
        expect(camera, findsOneWidget);
        final address = find.descendant(
          of: camera,
          matching: find.text('AV CL 80 - CR 98'),
        );
        await tester.ensureVisible(address);
        await tester.pumpAndSettle();
        expect(address.hitTestable(), findsOneWidget);
        await tester.tap(address);
        await tester.pumpAndSettle();
        final source = find.byKey(const ValueKey('fotomultas-open-source'));
        await tester.ensureVisible(source);
        await tester.pumpAndSettle();
        expect(source.hitTestable(), findsOneWidget);
        await tester.tap(source);
        await tester.pump();
        expect(launcher.openedUris, [_sourceUrl]);
        final date = find.text('2026-08-31T10:44:00-05:00');
        await tester.ensureVisible(date);
        await tester.pumpAndSettle();
        expect(date.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('shows loading state while the camera pack resolves', (
    tester,
  ) async {
    final completer = Completer<CameraPack>();
    await _pumpScreen(tester, loader: () => completer.future);

    expect(find.byKey(const ValueKey('fotomultas-loading')), findsOneWidget);
    completer.complete(_pack());
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('fotomultas-country-screen')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('fotomultas-colombia-map')),
      findsOneWidget,
    );
  });

  testWidgets(
    'geometry failure keeps textual selection available and retries',
    (tester) async {
      var attempts = 0;
      await _pumpScreen(
        tester,
        geometryLoader: () async {
          if (++attempts == 1) throw const FormatException('fixture');
          return _geometry;
        },
      );
      await tester.pumpAndSettle();
      expect(find.text('No pudimos cargar el mapa.'), findsOneWidget);
      await _chooseDepartment(tester, 'ANT');
      expect(
        find.byKey(const ValueKey('fotomultas-view-cameras')),
        findsOneWidget,
      );
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.byType(PolygonLayer<String>), findsWidgets);
      expect(attempts, 2);
    },
  );
  testWidgets(
    'no island inset; long territory name remains available in search',
    (tester) async {
      for (final scale in [1.0, 1.5, 2.0]) {
        await _pumpScreen(
          tester,
          size: const Size(360, 780),
          textScale: scale,
          bottomNavigation: true,
          productionTheme: true,
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('fotomultas-island-inset')),
          findsNothing,
        );
        expect(find.byType(FlutterMap), findsOneWidget);
        await _chooseDepartment(tester, 'SAP');
        const name = 'San Andrés, Providencia y Santa Catalina';
        if (find.text('Ver departamento').evaluate().isNotEmpty) {
          expect(find.byTooltip(name), findsOneWidget);
        } else {
          expect(find.text(name), findsOneWidget);
        }
        expect(
          tester
              .getSize(find.byKey(const ValueKey('fotomultas-colombia-map')))
              .height,
          greaterThanOrEqualTo(220),
        );
        await _capture(tester, 'long-name-$scale');
        final compactSelection = find.byKey(
          const ValueKey('fotomultas-compact-selection'),
        );
        if (compactSelection.evaluate().isNotEmpty) {
          await tester.tap(compactSelection);
          await tester.pumpAndSettle();
          expect(find.text(name), findsWidgets);
          expect(find.text('Sin registros en este inventario'), findsWidgets);
          expect(
            find.byKey(const ValueKey('fotomultas-view-cameras')),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
  testWidgets('ten national map visits dispose the map tree cleanly', (
    tester,
  ) async {
    for (var i = 0; i < 10; i++) {
      await _pumpScreen(tester);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('fotomultas-country-zoom-in')),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(find.byType(FlutterMap), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'empty inventory territory opens an explanatory sheet, not tiles',
    (tester) async {
      await _pumpScreen(tester);
      await tester.pumpAndSettle();
      await _chooseDepartment(tester, 'AMA');
      await tester.tap(find.byKey(const ValueKey('fotomultas-view-cameras')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('fotomultas-empty-department-sheet')),
        findsOneWidget,
      );
      expect(find.text('Sin registros en este inventario'), findsWidgets);
      expect(find.byType(TileLayer), findsNothing);
    },
  );

  testWidgets('shows pack error and retries through cameraPackProvider', (
    tester,
  ) async {
    var shouldFail = true;
    var attempts = 0;
    await _pumpScreen(
      tester,
      loader: () {
        attempts += 1;
        if (shouldFail) {
          return Future<CameraPack>.error('pack unavailable');
        }
        return Future.value(_pack());
      },
    );
    await tester.pumpAndSettle();

    expect(find.text('No pudimos cargar las cámaras.'), findsOneWidget);
    expect(find.text('pack unavailable'), findsOneWidget);

    shouldFail = false;
    await tester.tap(find.byKey(const ValueKey('fotomultas-retry')));
    await tester.pumpAndSettle();

    expect(attempts, greaterThanOrEqualTo(2));
    expect(
      find.byKey(const ValueKey('fotomultas-country-screen')),
      findsOneWidget,
    );
  });

  testWidgets('calculates summary counts from the provided pack', (
    tester,
  ) async {
    await _pumpScreen(tester);

    expect(find.text('3 registros autorizados'), findsOneWidget);
    await tester.tap(find.text('Información y fuentes'));
    await tester.pumpAndSettle();
    expect(find.text('2 con velocidad reportada'), findsOneWidget);
    expect(find.text('1 sin velocidad reportada'), findsOneWidget);
    expect(
      find.text('Snapshot; no confirma operación actual.'),
      findsOneWidget,
    );
    expect(find.text('ANSV ubicaciones aprobadas'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('fotomultas-source-date')),
      findsOneWidget,
    );
    expect(
      find.textContaining('no consulta comparendos ni confirma una sanción'),
      findsOneWidget,
    );
  });

  testWidgets('searches by city, address, authority and normalized accents', (
    tester,
  ) async {
    await _pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('fotomultas-open-department-search')),
    );
    await tester.pumpAndSettle();
    final departmentField = find.byKey(
      const ValueKey('fotomultas-department-search-field'),
    );
    await tester.enterText(departmentField, 'bogota');
    await tester.pumpAndSettle();
    expect(find.text('Bogotá'), findsOneWidget);

    await tester.enterText(departmentField, 'antioquia');
    await tester.pumpAndSettle();
    expect(find.text('Antioquia'), findsOneWidget);

    await _openDepartmentList(tester, 'ANT');

    await _searchCameras(tester, 'medellin');
    await tester.pumpAndSettle();
    expect(find.text('CRA 43 A - CL 10'), findsOneWidget);
    expect(find.text('AV CL 80 - CR 98'), findsNothing);

    await _backToCountry(tester);
    await _openDepartmentList(tester, 'BOG');
    await _searchCameras(tester, 'cl 80');
    await tester.pumpAndSettle();
    expect(find.text('AV CL 80 - CR 98'), findsOneWidget);
    expect(find.text('CRA 43 A - CL 10'), findsNothing);

    await _searchCameras(tester, 'secretaria distrital');
    await tester.pumpAndSettle();
    expect(find.text('AV CL 80 - CR 98'), findsOneWidget);

    await _backToCountry(tester);
    await _openDepartmentList(tester, 'ANT');
    await _searchCameras(tester, 'transito de medellin');
    await tester.pumpAndSettle();
    expect(find.text('CRA 43 A - CL 10'), findsOneWidget);
  });

  testWidgets('filters cameras with and without reported speed', (
    tester,
  ) async {
    await _pumpScreen(tester);
    await tester.pumpAndSettle();
    await _openDepartmentList(tester, 'BOG');

    await _filterSpeed(tester, 'Con velocidad reportada');
    await tester.pumpAndSettle();

    expect(find.text('Velocidad reportada: 50 km/h'), findsOneWidget);
    expect(find.text('Velocidad no publicada'), findsNothing);

    await _filterSpeed(tester, 'Sin velocidad reportada');
    await tester.pumpAndSettle();

    expect(find.text('Velocidad no publicada'), findsOneWidget);
    expect(find.text('Velocidad reportada: 50 km/h'), findsNothing);
  });

  testWidgets('shows empty search state', (tester) async {
    await _pumpScreen(tester);
    await tester.pumpAndSettle();
    await _openDepartmentList(tester, 'BOG');

    await _searchCameras(tester, 'no existe');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('fotomultas-empty-search')),
      findsOneWidget,
    );
    expect(
      find.text('No encontramos cámaras con esa búsqueda.'),
      findsOneWidget,
    );
  });

  testWidgets('detail with known speed shows available ANSV fields', (
    tester,
  ) async {
    await _pumpScreen(tester, size: const Size(390, 1200));
    await tester.pumpAndSettle();
    await _openDepartmentList(tester, 'BOG');

    await tester.tap(find.byKey(const ValueKey('fotomultas-camera-known-bog')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('fotomultas-detail-sheet')),
      findsOneWidget,
    );
    expect(find.text('AV CL 80 - CR 98'), findsWidgets);
    expect(find.text('BOGOTA D.C · BOGOTA D.C'), findsWidgets);
    expect(find.text('Velocidad reportada por ANSV'), findsOneWidget);
    expect(find.text('Velocidad reportada: 50 km/h'), findsWidgets);
    expect(find.text('Radar Doppler'), findsOneWidget);
    expect(find.text('Fijo'), findsOneWidget);
    expect(find.text('DEI29CAM01'), findsOneWidget);
    expect(find.text('C02, C14'), findsOneWidget);
    expect(find.text('ANSV ubicaciones aprobadas'), findsOneWidget);
  });

  testWidgets('detail without speed omits empty optional fields', (
    tester,
  ) async {
    await _pumpScreen(tester, size: const Size(390, 1200));
    await tester.pumpAndSettle();
    await _openDepartmentList(tester, 'BOG');

    await tester.tap(
      find.byKey(const ValueKey('fotomultas-camera-unknown-bog')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Velocidad no publicada'), findsWidgets);
    expect(find.text('Tecnología'), findsNothing);
    expect(find.text('Tipo de instalación'), findsNothing);
    expect(find.text('Equipo'), findsNothing);
    expect(find.text('Códigos de infracción'), findsNothing);
  });

  testWidgets('source action opens ANSV and reports launcher failure', (
    tester,
  ) async {
    final launcher = _FakeExternalLauncher();
    await _pumpScreen(tester, launcher: launcher, size: const Size(390, 1200));
    await tester.pumpAndSettle();
    await _openDepartmentList(tester, 'BOG');

    await tester.tap(find.byKey(const ValueKey('fotomultas-camera-known-bog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fotomultas-open-source')));
    await tester.pump();

    expect(launcher.openedUris.single, _sourceUrl);

    final failingLauncher = _FakeExternalLauncher(openResult: false);
    await _pumpScreen(
      tester,
      launcher: failingLauncher,
      size: const Size(390, 1200),
    );
    await tester.pumpAndSettle();
    await _openDepartmentList(tester, 'BOG');
    await tester.tap(find.byKey(const ValueKey('fotomultas-camera-known-bog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fotomultas-open-source')));
    await tester.pump();

    expect(find.text('No pudimos abrir la fuente ANSV.'), findsOneWidget);

    final throwingLauncher = _FakeExternalLauncher(throwOnOpen: true);
    await _pumpScreen(
      tester,
      launcher: throwingLauncher,
      size: const Size(390, 1200),
    );
    await tester.pumpAndSettle();
    await _openDepartmentList(tester, 'BOG');
    await tester.tap(find.byKey(const ValueKey('fotomultas-camera-known-bog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fotomultas-open-source')));
    await tester.pump();

    expect(find.text('No pudimos abrir la fuente ANSV.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('main CTA and detail CTA open Conducir', (tester) async {
    await _pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('fotomultas-open-driving')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('drive-marker')), findsOneWidget);

    await _pumpScreen(tester, size: const Size(390, 1200));
    await tester.pumpAndSettle();
    await _openDepartmentList(tester, 'BOG');
    await tester.tap(find.byKey(const ValueKey('fotomultas-camera-known-bog')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('fotomultas-detail-open-driving')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('drive-marker')), findsOneWidget);
  });

  testWidgets('detail actions stay above the shell bottom navigation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await _pumpScreenWithBottomNavigation(tester);
    await _openDepartmentList(tester, 'BOG');
    expect(find.byKey(const ValueKey('fotomultas-list')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('fotomultas-camera-known-bog')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -120),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 600));

    final bottomNavRect = tester.getRect(
      find.byKey(const ValueKey('app-bottom-navigation')),
    );
    final drivingAction = find.byKey(
      const ValueKey('fotomultas-detail-open-driving'),
    );
    final sourceAction = find.byKey(const ValueKey('fotomultas-open-source'));

    expect(
      find.byKey(const ValueKey('fotomultas-detail-sheet')),
      findsOneWidget,
    );
    expect(drivingAction, findsOneWidget);
    expect(sourceAction, findsOneWidget);
    expect(tester.getRect(drivingAction).bottom, lessThan(bottomNavRect.top));
    expect(tester.getRect(sourceAction).bottom, lessThan(bottomNavRect.top));
    expect(
      tester.hitTestOnBinding(tester.getCenter(drivingAction)).path,
      isNotEmpty,
    );
    expect(
      tester.hitTestOnBinding(tester.getCenter(sourceAction)).path,
      isNotEmpty,
    );
  });

  testWidgets('target phones and text scales render without exceptions', (
    tester,
  ) async {
    const cases = [
      (Size(360, 800), 1.0),
      (Size(360, 800), 2.0),
      (Size(390, 844), 1.5),
      (Size(412, 915), 2.0),
    ];

    for (final testCase in cases) {
      await _pumpScreen(tester, size: testCase.$1, textScale: testCase.$2);
      expect(find.text('3 registros autorizados'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}

Future<void> _searchCameras(WidgetTester tester, String query) async {
  await tester.tap(find.byKey(const ValueKey('fotomultas-open-camera-search')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('fotomultas-search-field')),
    query,
  );
  await tester.tap(find.byKey(const ValueKey('fotomultas-apply-search')));
  await tester.pumpAndSettle();
}

Future<void> _filterSpeed(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const ValueKey('fotomultas-speed-filter')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.tap(find.byKey(const ValueKey('fotomultas-apply-filter')));
  await tester.pumpAndSettle();
}

Future<void> _chooseDepartment(WidgetTester tester, String code) async {
  final search = find.byKey(
    const ValueKey('fotomultas-department-search-field'),
  );
  if (search.evaluate().isEmpty) {
    await tester.tap(
      find.byKey(const ValueKey('fotomultas-open-department-search')),
    );
    await tester.pumpAndSettle();
  }
  await tester.enterText(search, _departmentQueryFor(code));
  await tester.pumpAndSettle();
  final department = find.byKey(ValueKey('fotomultas-department-tile-$code'));
  await tester.ensureVisible(department);
  await tester.tap(department);
  await tester.pumpAndSettle();
}

Future<void> _openDepartmentList(WidgetTester tester, String code) async {
  await _chooseDepartment(tester, code);
  final compact = find.byKey(const ValueKey('fotomultas-compact-selection'));
  if (compact.evaluate().isNotEmpty) {
    await tester.tap(compact);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(const ValueKey('fotomultas-view-cameras')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('fotomultas-view-toggle')));
  await tester.pumpAndSettle();
}

Future<void> _backToCountry(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Volver a Colombia'));
  await tester.pumpAndSettle();
}

Future<void> _ensureCameraVisible(WidgetTester tester, Finder camera) async {
  if (camera.evaluate().isEmpty || camera.hitTestable().evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      camera,
      120,
      scrollable: find.byType(Scrollable).last,
    );
  } else {
    await tester.ensureVisible(camera);
  }
  await tester.pumpAndSettle();
}

String _departmentQueryFor(String code) {
  return switch (code) {
    'SAP' => 'san andres',
    'AMA' => 'amazonas',
    'ANT' => 'antioquia',
    'BOG' => 'bogota',
    'NSA' => 'norte de santander',
    _ => code,
  };
}

Future<void> _pumpScreenWithBottomNavigation(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        departmentGeometryProvider.overrideWith((ref) async => _geometry),
        fotomultasTileProviderFactory.overrideWithValue(() => _TestTiles()),
        cameraPackProvider.overrideWith((ref) => Future.value(_pack())),
        externalLauncherProvider.overrideWithValue(_FakeExternalLauncher()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: const FotomultasScreen(),
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
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  Future<CameraPack> Function()? loader,
  ExternalLauncher? launcher,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool productionTheme = false,
  bool bottomNavigation = false,
  Future<DepartmentGeometry> Function()? geometryLoader,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const FotomultasScreen()),
      GoRoute(
        path: AppRoute.drive.path,
        builder: (context, state) => const _DriveMarker(),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        departmentGeometryProvider.overrideWith(
          (ref) async =>
              geometryLoader == null ? _geometry : await geometryLoader(),
        ),
        fotomultasTileProviderFactory.overrideWithValue(() => _TestTiles()),
        cameraPackProvider.overrideWith((ref) {
          return loader == null ? Future.value(_pack()) : loader();
        }),
        externalLauncherProvider.overrideWithValue(
          launcher ?? _FakeExternalLauncher(),
        ),
      ],
      child: MaterialApp.router(
        theme: productionTheme ? buildPicoRadarTheme() : null,
        routerConfig: router,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: RepaintBoundary(
              key: const ValueKey('fotomultas-test-capture'),
              child: bottomNavigation
                  ? Scaffold(
                      body: child,
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
                    )
                  : child ?? const SizedBox.shrink(),
            ),
          );
        },
      ),
    ),
  );
  await tester.pump();
}

CameraPack _pack() {
  return CameraPack(
    source: const CameraPackSource(
      name: 'ANSV ubicaciones aprobadas',
      pageUrl: _sourceUrl,
      dataUrl: _sourceUrl,
      fetchedAtUtc: '2026-08-31T10:44:00-05:00',
    ),
    cameras: [
      _camera(
        id: 'known-bog',
        department: 'BOGOTA D.C',
        municipality: 'BOGOTA D.C',
        address: 'AV CL 80 - CR 98',
        authority: 'SECRETARIA DISTRITAL DE MOVILIDAD',
        speed: 50,
        technology: 'Radar Doppler',
        installationType: 'Fijo',
        equipmentName: 'DEI29CAM01',
        codes: const ['C02', 'C14'],
      ),
      _camera(
        id: 'known-med',
        department: 'ANTIOQUIA',
        municipality: 'MEDELLÍN',
        address: 'CRA 43 A - CL 10',
        authority: 'SECRETARÍA DE TRÁNSITO DE MEDELLÍN',
        speed: 80,
        technology: 'Video Detección',
        installationType: 'Fijo',
        equipmentName: 'MED01',
      ),
      _camera(
        id: 'unknown-bog',
        department: 'BOGOTA D.C',
        municipality: 'BOGOTA D.C',
        address: 'AK 30 - CL 45',
        authority: 'SECRETARIA DISTRITAL DE MOVILIDAD',
      ),
    ],
  );
}

Future<CameraPack> _realPack() async => _inventory;

Future<void> _capture(WidgetTester tester, String name) async {
  final directory = Platform.environment['FOTOMULTAS_CAPTURE_DIR'];
  if (directory == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('fotomultas-test-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File('$directory/$name.png').writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

TrafficCamera _camera({
  required String id,
  required String department,
  required String municipality,
  required String address,
  required String authority,
  int? speed,
  String? technology,
  String? installationType,
  String? equipmentName,
  List<String> codes = const [],
}) {
  return TrafficCamera(
    id: id,
    department: department,
    municipality: municipality,
    jurisdiction: 'Distrital',
    address: address,
    latitude: 4.7,
    longitude: -74.1,
    status: 'Aprobada',
    technology: technology,
    kind: CameraKind.mixed,
    speedLimitKmh: speed,
    operationStatus: 'Operando',
    trafficAuthority: authority,
    installationType: installationType,
    equipmentName: equipmentName,
    rawInfractionCodes: codes,
  );
}

class _FakeExternalLauncher implements ExternalLauncher {
  _FakeExternalLauncher({this.openResult = true, this.throwOnOpen = false});

  final bool openResult;
  final bool throwOnOpen;
  final openedUris = <String>[];

  @override
  Future<bool> callPhone(String phone) async => true;

  @override
  Future<bool> openExternal(String uri) async {
    if (throwOnOpen) {
      throw StateError('launcher failed');
    }
    openedUris.add(uri);
    return openResult;
  }
}

class _DriveMarker extends StatelessWidget {
  const _DriveMarker();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Text('Conducir', key: ValueKey('drive-marker')),
    );
  }
}

const _sourceUrl =
    'https://fotodeteccion.ansv.gov.co/ubicaciones-aprobadas.html';

class _TestTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_tileBytes);
}
