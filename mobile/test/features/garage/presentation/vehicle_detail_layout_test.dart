import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/theme/app_theme.dart';
import 'package:picoradar/core/design_system/branding.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/garage/presentation/vehicle_detail_screen.dart';
import 'package:picoradar/features/vehicle_status/domain/vehicle_obligation.dart';

import '../../../plate_test_fonts.dart';
import '../../../test_app_harness.dart';

const _bottomNavigationHeight = 88.0;
const _bottomNavigationKey = ValueKey('layout-bottom-navigation');
const _primaryActions = ['detail-status-pico', 'detail-status-soat'];
const _secondaryActions = [
  'detail-status-rtm',
  'detail-status-insurance',
  'detail-status-tax',
  'detail-delete-vehicle',
];
const _statusDestinations = {
  'detail-status-pico': '/garage/pico',
  'detail-status-soat': '/apps/module/soat',
  'detail-status-rtm': '/apps/module/tecnomecanica',
  'detail-status-insurance': '/apps/module/seguro_asistencia',
  'detail-status-tax': '/apps/module/impuestos',
};
const _accessibleNames = {
  'detail-back': 'volver',
  'detail-edit-vehicle': 'editar',
  'detail-change-vehicle-image': 'cambiar imagen',
  'detail-vehicle-image': 'cambiar imagen',
  'detail-status-pico': 'pico y placa',
  'detail-status-soat': 'soat',
  'detail-status-rtm': 'tecnomec',
  'detail-status-insurance': 'seguro',
  'detail-status-tax': 'impuestos',
  'detail-delete-vehicle': 'eliminar',
  'detail-more-actions': 'gestiones',
};

void main() {
  setUpAll(loadPlateTestFonts);
  late TestAppHarness harness;

  setUp(() {
    harness = TestAppHarness();
  });

  tearDown(() async {
    await harness.dispose();
  });

  for (final size in const [
    Size(360, 780),
    Size(360, 800),
    Size(390, 844),
    Size(412, 915),
    Size(430, 932),
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'detail fits ${size.width}x${size.height} text=$scale above bottom nav',
        (tester) async {
          await _openDetail(tester, harness, size: size, scale: scale);

          _expectNoScrollOrException(tester);
          expect(
            tester.getSize(find.byKey(_bottomNavigationKey)).height,
            _bottomNavigationHeight,
          );
          expect(
            MediaQuery.textScalerOf(
              tester.element(find.byType(VehicleDetailScreen)),
            ).scale(16),
            16 * scale,
          );
          _expectIdentity(tester);
          _expectActions(tester, _primaryActions);

          final more = _action('detail-more-actions');
          if (more.evaluate().isNotEmpty) {
            _expectCompactFirstPage(tester);
            await tester.tap(more);
            await tester.pumpAndSettle();
            _expectNoScrollOrException(tester);
            _expectActions(tester, _secondaryActions);
            _expectActions(tester, ['detail-back']);

            await tester.tap(_action('detail-back'));
            await tester.pumpAndSettle();
            _expectCompactFirstPage(tester);
            _expectIdentity(tester);
          } else {
            _expectActions(tester, _secondaryActions);
          }
          _expectNoScrollOrException(tester);
        },
      );
    }
  }

  for (final kind in const [
    (
      name: 'private car',
      kind: VehicleKind.car,
      service: VehicleServiceType.private,
    ),
    (name: 'taxi', kind: VehicleKind.car, service: VehicleServiceType.taxi),
    (
      name: 'motorcycle',
      kind: VehicleKind.motorcycle,
      service: VehicleServiceType.private,
    ),
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('${kind.name} identity and actions fit text=$scale', (
        tester,
      ) async {
        final fixture = await _openDetail(
          tester,
          harness,
          size: const Size(360, 780),
          scale: scale,
          kind: kind.kind,
          serviceType: kind.service,
        );
        _expectIdentity(tester);
        final plate = tester.widget<ColombianPlateBadge>(
          find.descendant(
            of: find.byType(VehicleDetailScreen),
            matching: find.byType(ColombianPlateBadge),
          ),
        );
        expect(plate.plate, fixture.vehicle.plate);
        expect(plate.publicService, kind.service == VehicleServiceType.taxi);
        if (kind.kind == VehicleKind.motorcycle) {
          expect(plate.registrationLabel, 'COLOMBIA');
        }
        await _expectBothActionPages(tester);
      });
    }
  }

  for (final size in const [Size(360, 780), Size(430, 932)]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('long city stays readable ${size.width} text=$scale', (
        tester,
      ) async {
        const city = 'San Andr\u00e9s de Tumaco, Nari\u00f1o';
        const nickname = 'Mi veh\u00edculo familiar de todos los d\u00edas';
        await _openDetail(
          tester,
          harness,
          size: size,
          scale: scale,
          city: city,
          nickname: nickname,
        );
        expect(find.text(city).hitTestable(), findsOneWidget);
        expect(find.text(nickname).hitTestable(), findsOneWidget);
        _expectIdentity(tester);
        await _expectBothActionPages(tester);
      });

      for (final fail in [false, true]) {
        testWidgets(
          'status loading to ${fail ? 'error' : 'dates'} fits ${size.width} text=$scale',
          (tester) async {
            final pending = Completer<List<VehicleObligation>>();
            addTearDown(() {
              if (!pending.isCompleted) pending.complete([]);
            });
            final fixture = await _openDetail(
              tester,
              harness,
              size: size,
              scale: scale,
              obligations: pending.future,
            );
            final splitBefore = _action('detail-more-actions')
                .evaluate()
                .isNotEmpty;
            _expectStatusText('detail-status-soat', 'Cargando\u2026');
            _expectIdentity(tester);
            await _expectBothActionPages(tester, status: 'Cargando\u2026');

            if (fail) {
              pending.completeError(StateError('Test obligation load failed'));
            } else {
              pending.complete(_datedObligations(fixture.vehicle, harness.now));
            }
            await tester.pumpAndSettle();
            expect(
              _action('detail-more-actions').evaluate().isNotEmpty,
              splitBefore,
              reason: 'Loading completion must preserve the action-page mode',
            );
            _expectIdentity(tester);
            _expectStatusText(
              'detail-status-soat',
              fail ? 'No disponible' : 'Vence 30 sep',
            );
            await _expectBothActionPages(
              tester,
              status: fail ? 'No disponible' : null,
            );
            if (!fail) {
              if (splitBefore) {
                await tester.tap(_action('detail-more-actions'));
                await tester.pumpAndSettle();
              }
              _expectStatusText('detail-status-rtm', 'Vence 5 sep');
              _expectStatusText('detail-status-insurance', 'Fecha vencida');
              _expectNoScrollOrException(tester);
            }
          },
        );
      }
    }
  }

  testWidgets(
    'smallest phone with large text uses reversible compact actions',
    (tester) async {
      final fixture = await _openDetail(
        tester,
        harness,
        size: const Size(360, 780),
        scale: 2,
      );
      final preferencesBefore = {...harness.preferences.values};
      _expectCompactFirstPage(tester);
      _expectNoScrollOrException(tester);

      await tester.tap(_action('detail-more-actions'));
      await tester.pumpAndSettle();
      _expectActions(tester, _secondaryActions);
      _expectActions(tester, ['detail-back']);
      _expectNoScrollOrException(tester);

      await tester.tap(_action('detail-back'));
      await tester.pumpAndSettle();
      _expectCompactFirstPage(tester);
      expect(fixture.router.canPop(), isTrue);

      await tester.tap(_action('detail-back'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('layout-garage-origin')),
        findsOneWidget,
      );
      expect(find.byType(VehicleDetailScreen), findsNothing);
      expect(fixture.router.canPop(), isFalse);
      expect(
        await harness.repository.getVehicle(fixture.vehicle.id),
        isNotNull,
      );
      expect(harness.preferences.values, preferencesBefore);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'editing long metadata recalculates layout on the same detail route',
    (tester) async {
      final fixture = await _openDetail(
        tester,
        harness,
        size: const Size(360, 720),
        scale: 1,
        nickname: 'Mazda',
      );
      final detail = tester.element(find.byType(VehicleDetailScreen));
      final container = ProviderScope.containerOf(detail);
      final preferencesBefore = {...harness.preferences.values};
      expect(_action('detail-more-actions'), findsNothing);
      _expectNoScrollOrException(tester);

      await tester.tap(_action('detail-edit-vehicle'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<_Destination>(find.byType(_Destination)).uri.path,
        '/garage/vehicle/${fixture.vehicle.id}/edit',
      );
      // Force a different layout mode; shorter metadata still fits in full.
      const nickname =
          'Mi veh\u00edculo familiar de todos los d\u00edas para recorrer Colombia '
          'y visitar a toda la familia durante las vacaciones';
      const city = 'San Andr\u00e9s de Tumaco, Nari\u00f1o';
      final vehicle = fixture.vehicle;
      // The destination is a stub; persist and refresh as the real editor does.
      await harness.repository.updateVehicle(
        id: vehicle.id,
        plate: vehicle.plate,
        kind: vehicle.kind,
        serviceType: vehicle.serviceType,
        subtype: vehicle.subtype,
        nickname: nickname,
        registrationCity: city,
        brand: vehicle.brand,
        model: vehicle.model,
        year: vehicle.year,
        color: vehicle.color,
        fuel: vehicle.fuel,
      );
      container.invalidate(vehicleListProvider);
      await container.read(vehicleListProvider.future);
      await tester.tap(find.byKey(const ValueKey('layout-destination-back')));
      await tester.pumpAndSettle();

      expect(tester.element(find.byType(VehicleDetailScreen)), same(detail));
      expect(find.text(nickname).hitTestable(), findsOneWidget);
      expect(find.text(city).hitTestable(), findsOneWidget);
      _expectCompactFirstPage(tester);
      _expectIdentity(tester);
      await _expectBothActionPages(tester);
      expect(harness.preferences.values, preferencesBefore);
      expect(
        (await harness.repository.getVehicle(vehicle.id))?.nickname,
        nickname,
      );
    },
  );

  for (final resize in const [
    (size: Size(360, 800), compact: true),
    (size: Size(430, 1600), compact: false),
  ]) {
    testWidgets('system back after resize compact=${resize.compact}', (
      tester,
    ) async {
      final fixture = await _openDetail(
        tester,
        harness,
        size: const Size(360, 780),
        scale: 2,
      );
      _expectCompactFirstPage(tester);
      await tester.tap(_action('detail-more-actions'));
      await tester.pumpAndSettle();
      _expectActions(tester, _secondaryActions);

      tester.view.physicalSize = resize.size;
      await tester.pumpAndSettle();
      _expectNoScrollOrException(tester);
      _expectActions(tester, _secondaryActions);
      if (resize.compact) {
        expect(_action('detail-status-pico').hitTestable(), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        _expectCompactFirstPage(tester);
        _expectIdentity(tester);
        _expectNoScrollOrException(tester);
        expect(fixture.router.canPop(), isTrue);
      } else {
        _expectActions(tester, _primaryActions);
        _expectIdentity(tester);
        expect(_action('detail-more-actions'), findsNothing);
      }

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(VehicleDetailScreen), findsNothing);
      expect(
        find.byKey(const ValueKey('layout-garage-origin')),
        findsOneWidget,
      );
      expect(fixture.router.canPop(), isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  for (final viewport in const [
    (size: Size(430, 932), scale: 1.0),
    (size: Size(360, 780), scale: 2.0),
  ]) {
    for (final key in ['detail-edit-vehicle', ..._statusDestinations.keys]) {
      testWidgets(
        '$key pushes correct vehicle and returns to detail text=${viewport.scale}',
        (tester) async {
          final fixture = await _openDetail(
            tester,
            harness,
            size: viewport.size,
            scale: viewport.scale,
          );
          final preferencesBefore = {...harness.preferences.values};
          final detailElement = tester.element(
            find.byType(VehicleDetailScreen),
          );
          if (_secondaryActions.contains(key) &&
              _action('detail-more-actions').evaluate().isNotEmpty) {
            await tester.tap(_action('detail-more-actions'));
            await tester.pumpAndSettle();
          }
          _expectActions(tester, [key]);
          await tester.tap(_action(key));
          await tester.pumpAndSettle();

          final destination = tester.widget<_Destination>(
            find.byType(_Destination),
          );
          expect(
            destination.uri.path,
            key == 'detail-edit-vehicle'
                ? '/garage/vehicle/${fixture.vehicle.id}/edit'
                : _statusDestinations[key],
          );
          if (key != 'detail-edit-vehicle') {
            expect(
              destination.uri.queryParameters['vehicleId'],
              fixture.vehicle.id,
            );
          }
          expect(fixture.router.canPop(), isTrue);
          expect(tester.takeException(), isNull);

          await tester.tap(
            find.byKey(const ValueKey('layout-destination-back')),
          );
          await tester.pumpAndSettle();
          expect(find.byType(_Destination), findsNothing);
          expect(find.byType(VehicleDetailScreen), findsOneWidget);
          expect(
            tester.element(find.byType(VehicleDetailScreen)),
            same(detailElement),
          );
          _expectActions(tester, [key]);
          _expectNoScrollOrException(tester);
          expect(fixture.router.canPop(), isTrue);
          expect(harness.preferences.values, preferencesBefore);
          expect(
            (await harness.repository.getVehicle(fixture.vehicle.id))?.plate,
            fixture.vehicle.plate,
          );
        },
      );
    }
  }
}

Future<({GoRouter router, VehicleProfile vehicle})> _openDetail(
  WidgetTester tester,
  TestAppHarness harness, {
  required Size size,
  required double scale,
  VehicleKind kind = VehicleKind.car,
  VehicleServiceType serviceType = VehicleServiceType.private,
  String city = 'Bogota',
  String nickname = 'Mi Mazda familiar',
  Future<List<VehicleObligation>>? obligations,
}) async {
  // Repository mutations must run in the widget test's async zone.
  final vehicle = await harness.repository.createVehicle(
    plate: kind == VehicleKind.motorcycle ? 'AAA11A' : 'AAA111',
    kind: kind,
    serviceType: serviceType,
    nickname: nickname,
    registrationCity: city,
    brand: 'Mazda',
    model: 'CX-30',
    year: 2024,
    color: 'Gris',
  );
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  // testWidgets enables and disposes semantics before its end-of-test checks.

  final router = GoRouter(
    initialLocation: '/garage',
    routes: [
      ShellRoute(
        builder: (_, _, child) => Scaffold(
          body: child,
          bottomNavigationBar: const SizedBox(
            key: _bottomNavigationKey,
            height: _bottomNavigationHeight,
          ),
        ),
        routes: [
          GoRoute(
            path: '/garage',
            builder: (context, _) => Center(
              key: const ValueKey('layout-garage-origin'),
              child: TextButton(
                key: const ValueKey('layout-open-detail'),
                onPressed: () => context.push('/garage/vehicle/${vehicle.id}'),
                child: const Text('Abrir detalle'),
              ),
            ),
          ),
          GoRoute(
            path: '/garage/vehicle/:id',
            builder: (_, state) =>
                VehicleDetailScreen(vehicleId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/garage/vehicle/:id/edit',
            builder: (_, state) => _Destination(uri: state.uri),
          ),
          for (final path in _statusDestinations.values)
            GoRoute(
              path: path,
              builder: (_, state) => _Destination(uri: state.uri),
            ),
        ],
      ),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
  });
  await harness.pump(
    tester,
    childOverride: ProviderScope(
      overrides: [
        if (obligations != null)
          vehicleObligationsProvider(vehicle.id)
              .overrideWith((ref) => obligations),
      ],
      child: MaterialApp.router(
        theme: buildPicoRadarTheme(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('layout-open-detail')));
  await tester.pumpAndSettle();
  expect(router.canPop(), isTrue);
  return (router: router, vehicle: vehicle);
}

Finder _action(String key) => find.descendant(
  of: find.byType(VehicleDetailScreen),
  matching: find.byKey(ValueKey(key)),
);

void _expectNoScrollOrException(WidgetTester tester) {
  expect(tester.takeException(), isNull);
  expect(find.byType(VehicleDetailScreen), findsOneWidget);
  expect(
    find.descendant(
      of: find.byType(VehicleDetailScreen),
      matching: find.byType(Scrollable),
    ),
    findsNothing,
  );
  _expectParagraphBounds(tester);
}

void _expectActions(WidgetTester tester, List<String> keys) {
  final navTop = tester.getTopLeft(find.byKey(_bottomNavigationKey)).dy;
  final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  for (final key in keys) {
    final action = _action(key);
    expect(action, findsOneWidget, reason: key);
    expect(action.hitTestable(), findsOneWidget, reason: key);
    final rect = tester.getRect(action);
    expect(rect.isEmpty, isFalse, reason: key);
    expect(rect.left, greaterThanOrEqualTo(0), reason: key);
    expect(rect.right, lessThanOrEqualTo(width), reason: key);
    expect(rect.top, greaterThanOrEqualTo(0), reason: key);
    expect(rect.bottom, lessThanOrEqualTo(navTop), reason: key);
    // Status keys identify the Material frame; its InkWell owns the tap node.
    final semanticsTarget = key.startsWith('detail-status-')
        ? find.descendant(of: action, matching: find.byType(InkWell))
        : action;
    expect(semanticsTarget, findsOneWidget, reason: key);
    final semantics = tester.getSemantics(semanticsTarget).getSemanticsData();
    expect(semantics.hasAction(SemanticsAction.tap), isTrue, reason: key);
    // Flutter exposes Tooltip text in SemanticsData.tooltip, not always label.
    // Require the expected name on the same node that exposes the tap action.
    final name = '${semantics.label} ${semantics.tooltip}'.trim().toLowerCase();
    expect(name, contains(_accessibleNames[key]!), reason: key);
    _expectParagraphBounds(tester, within: action, contentBounds: rect);
  }
}

List<VehicleObligation> _datedObligations(
  VehicleProfile vehicle,
  DateTime now,
) => [
  for (final entry in [
    (VehicleObligationType.soat, DateTime(2026, 9, 30)),
    (VehicleObligationType.rtm, DateTime(2026, 9, 5)),
    (VehicleObligationType.insurance, DateTime(2026, 8, 26)),
  ])
    VehicleObligation(
      id: '${vehicle.id}:${entry.$1.value}',
      vehicleId: vehicle.id,
      type: entry.$1,
      dueDate: entry.$2,
      reminderEnabled: false,
      createdAt: now,
      updatedAt: now,
    ),
];

void _expectStatusText(String key, String text) {
  expect(
    find.descendant(of: _action(key), matching: find.textContaining(text)),
    findsOneWidget,
    reason: '$key must display $text',
  );
}

Future<void> _expectBothActionPages(
  WidgetTester tester, {
  String? status,
}) async {
  _expectNoScrollOrException(tester);
  _expectActions(tester, _primaryActions);
  if (status != null) _expectStatusText('detail-status-soat', status);
  final split = _action('detail-more-actions').evaluate().isNotEmpty;
  if (split) {
    _expectCompactFirstPage(tester);
    await tester.tap(_action('detail-more-actions'));
    await tester.pumpAndSettle();
  }
  _expectActions(tester, _secondaryActions);
  if (status != null) {
    for (final key in _secondaryActions.take(3)) {
      _expectStatusText(key, status);
    }
  }
  _expectNoScrollOrException(tester);
  if (split) {
    _expectActions(tester, ['detail-back']);
    await tester.tap(_action('detail-back'));
    await tester.pumpAndSettle();
    _expectCompactFirstPage(tester);
    _expectNoScrollOrException(tester);
  }
}

void _expectParagraphBounds(
  WidgetTester tester, {
  Finder? within,
  Rect? contentBounds,
}) {
  final viewport = Rect.fromLTWH(
    0,
    0,
    tester.view.physicalSize.width / tester.view.devicePixelRatio,
    tester.getTopLeft(find.byKey(_bottomNavigationKey)).dy,
  );
  final paragraphs = find.descendant(
    of: within ?? find.byType(VehicleDetailScreen),
    matching: find.byType(RichText),
  );
  if (within == null) expect(paragraphs, findsWidgets);
  for (final element in paragraphs.evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    final text = paragraph.text.toPlainText();
    if (text.trim().isEmpty) continue;
    expect(paragraph.didExceedMaxLines, isFalse, reason: 'Truncated: $text');
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: text.length),
    );
    expect(boxes, isNotEmpty, reason: 'No rendered text: $text');
    for (final box in boxes) {
      final local = box.toRect();
      final global = MatrixUtils.transformRect(
        paragraph.getTransformTo(null),
        local,
      );
      // Selection boxes include font metrics, not just glyph ink. For example,
      // the Roboto detail heading starts at -0.501953 dp with height: 1.15.
      // A paragraph's layout bounds are not a clip, so that overhang alone
      // is not truncation. Keep checks against the actual visible boundaries.
      _expectRectInside(global, viewport, 'Viewport: $text');
      if (contentBounds != null) {
        _expectRectInside(global, contentBounds, 'Action: $text');
      }
      // Check real clipping ancestors instead of assuming the paragraph clips.
      RenderObject child = paragraph;
      var parent = child.parent;
      while (parent != null) {
        final clip = parent.describeApproximatePaintClip(child);
        if (clip != null) {
          final inParent = MatrixUtils.transformRect(
            paragraph.getTransformTo(parent),
            local,
          );
          _expectRectInside(
            inParent,
            clip,
            'Clipped by ${parent.runtimeType}: $text',
          );
        }
        child = parent;
        parent = child.parent;
      }
    }
  }
}

void _expectRectInside(Rect inner, Rect outer, String reason) {
  const tolerance = 0.5;
  expect(
    inner.left,
    greaterThanOrEqualTo(outer.left - tolerance),
    reason: reason,
  );
  expect(
    inner.top,
    greaterThanOrEqualTo(outer.top - tolerance),
    reason: reason,
  );
  expect(
    inner.right,
    lessThanOrEqualTo(outer.right + tolerance),
    reason: reason,
  );
  expect(
    inner.bottom,
    lessThanOrEqualTo(outer.bottom + tolerance),
    reason: reason,
  );
}

void _expectIdentity(WidgetTester tester) {
  _expectActions(tester, [
    'detail-back',
    'detail-edit-vehicle',
    'detail-change-vehicle-image',
    'detail-vehicle-image',
  ]);
  final cameraIcons = find.descendant(
    of: _action('detail-change-vehicle-image'),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Icon &&
          {
            Icons.camera_alt,
            Icons.camera_alt_outlined,
            Icons.camera_alt_rounded,
            Icons.camera_alt_sharp,
            Icons.photo_camera,
            Icons.photo_camera_outlined,
            Icons.photo_camera_rounded,
            Icons.photo_camera_sharp,
          }.contains(widget.icon),
    ),
  );
  expect(cameraIcons, findsOneWidget);
  final plate = find.descendant(
    of: find.byType(VehicleDetailScreen),
    matching: find.byType(ColombianPlateBadge),
  );
  expect(plate, findsOneWidget);
  final scale = MediaQuery.textScalerOf(
    tester.element(find.byType(VehicleDetailScreen)),
  ).scale(1);
  expect(tester.getSize(plate).width, closeTo(96 * scale, 0.01));
  expect(plate.hitTestable(), findsOneWidget);
  for (final entry in const {
    'colombian-plate-first-group': 20.0,
    'colombian-plate-last-group': 20.0,
    'colombian-plate-registration-label': 10.0,
  }.entries) {
    final text = find.descendant(
      of: plate,
      matching: find.byKey(ValueKey(entry.key)),
    );
    expect(text, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(text);
    expect(paragraph.text.style?.fontSize, entry.value, reason: entry.key);
    expect(
      paragraph.textScaler.scale(entry.value),
      closeTo(entry.value * scale, 0.01),
      reason: '${entry.key} must retain the requested text scale',
    );
    final transform = paragraph.getTransformTo(null);
    final origin = MatrixUtils.transformPoint(transform, Offset.zero);
    for (final axis in const [Offset(1, 0), Offset(0, 1)]) {
      expect(
        (MatrixUtils.transformPoint(transform, axis) - origin).distance,
        closeTo(1, 0.001),
        reason: '${entry.key} must not be visually shrunk by a transform',
      );
    }
  }
}

void _expectCompactFirstPage(WidgetTester tester) {
  _expectActions(tester, [..._primaryActions, 'detail-more-actions']);
  expect(
    find.descendant(
      of: _action('detail-more-actions'),
      matching: find.text('M\u00e1s gestiones'),
    ),
    findsOneWidget,
  );
  for (final key in _secondaryActions) {
    expect(_action(key).hitTestable(), findsNothing, reason: key);
  }
  expect(
    tester.getRect(_action('detail-status-pico')).bottom,
    lessThanOrEqualTo(tester.getRect(_action('detail-status-soat')).top),
  );
  expect(
    tester.getRect(_action('detail-status-soat')).bottom,
    lessThanOrEqualTo(tester.getRect(_action('detail-more-actions')).top),
  );
}

class _Destination extends StatelessWidget {
  const _Destination({required this.uri});

  final Uri uri;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        key: const ValueKey('layout-destination-back'),
        onPressed: () => context.pop(),
        child: const Text('Volver al detalle'),
      ),
    ),
  );
}
