import '../../../plate_test_fonts.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:go_router/go_router.dart';
import 'package:picoradar/app/app.dart';
import 'package:picoradar/app/app_clock.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/startup/startup_gate.dart';
import 'package:picoradar/core/database/app_database.dart'
    hide VehicleObligation;
import 'package:picoradar/app/theme/app_tokens.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/garage/presentation/vehicle_detail_screen.dart';
import 'package:picoradar/features/home/data/home_banner_config.dart';
import 'package:picoradar/features/home/presentation/home_screen.dart';
import 'package:picoradar/features/location/application/location_controller.dart';
import 'package:picoradar/features/location/data/location_preferences.dart';
import 'package:picoradar/features/location/domain/jurisdiction_location_resolver.dart';
import 'package:picoradar/features/location/platform/device_location_gateway.dart';
import 'package:picoradar/features/pico_placa/data/pico_jurisdiction_catalog.dart';
import 'package:picoradar/features/pico_placa/data/pico_preferences.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_day_evaluation.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_rule.dart';
import 'package:picoradar/features/pico_placa/platform/pico_notifications.dart';
import 'package:picoradar/features/pico_placa/presentation/pico_detail_screen.dart';
import 'package:picoradar/features/trip/data/trip_municipality_catalog.dart';
import 'package:picoradar/features/vehicle_status/data/vehicle_obligation_store.dart';
import 'package:picoradar/features/vehicle_status/domain/vehicle_obligation.dart';
import 'package:picoradar/features/vehicle_status/platform/obligation_notifications.dart';
import 'package:picoradar/features/visual_assets/data/visual_asset_catalogs.dart';
import 'package:picoradar/features/visual_assets/data/visual_asset_preferences.dart';

import '../../../test_app_harness.dart';
import 'v01b_test_font.dart';

void main() {
  setUpAll(loadPlateTestFonts);
  setUpAll(loadV01bTestFont);
  late TestAppHarness harness;

  setUp(() {
    harness = TestAppHarness();
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'obligation error preserves reliable Pico and slot bounds scale=$scale',
      (tester) async {
        final vehicle = await _readyHome(harness, plate: 'ABC126');
        final pending = Completer<List<VehicleObligation>>();
        var attempts = 0;
        await _pump(
          tester,
          harness,
          Scaffold(
            body: ProviderScope(
              retry: (count, error) =>
                  count < 1 ? const Duration(milliseconds: 20) : null,
              overrides: [
                vehicleObligationsProvider(vehicle.id).overrideWith((ref) {
                  attempts++;
                  return pending.future;
                }),
              ],
              child: const HomeScreen(),
            ),
          ),
          textScaleFactor: scale,
          homeEvaluation: const RestrictionDayEvaluation(
            status: RestrictionDayStatus.allowed,
            effectiveWindows: [],
          ),
        );
        final grid = find.byKey(const ValueKey('home-status-grid'));
        final pico = find.byKey(const ValueKey('home-status-today'));
        final soat = find.byKey(const ValueKey('home-status-soat'));
        final rtm = find.byKey(const ValueKey('home-status-rtm'));
        final before = [
          tester.getRect(grid),
          tester.getRect(pico),
          tester.getRect(soat),
          tester.getRect(rtm),
        ];
        final picoText = tester
            .widget<Text>(find.byKey(const ValueKey('home-summary-main')))
            .data;
        expect(picoText, 'Puede circular');
        pending.completeError(Exception('test-obligation-storage-unavailable'));
        await _pumpAsyncHome(tester);
        expect(pico, findsOneWidget);
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('home-summary-main')))
              .data,
          picoText,
        );
        expect([
          tester.getRect(grid),
          tester.getRect(pico),
          tester.getRect(soat),
          tester.getRect(rtm),
        ], before);
        expect(find.text('No disponible'), findsNWidgets(2));
        expect(find.text('Consultando'), findsNothing);
        expect(find.text('Sin configurar'), findsNothing);
        expect(find.textContaining('test-obligation-storage'), findsNothing);
        for (final card in [soat, rtm]) {
          expect(
            tester
                .widgetList<InkWell>(
                  find.descendant(of: card, matching: find.byType(InkWell)),
                )
                .any((widget) => widget.onTap != null),
            isTrue,
          );
        }
        await tester.pump(const Duration(seconds: 1));
        expect(attempts, 2);
        expect(find.text('Consultando'), findsNothing);
        expect(pico, findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('deferred obligation outer slot size is stable scale=$scale', (
      tester,
    ) async {
      final vehicle = await _readyHome(harness, plate: 'ABC126');
      final pending = Completer<List<VehicleObligation>>();
      await _pump(
        tester,
        harness,
        Scaffold(
          body: ProviderScope(
            overrides: [
              vehicleObligationsProvider(vehicle.id)
                  .overrideWith((ref) => pending.future),
            ],
            child: const HomeScreen(),
          ),
        ),
        textScaleFactor: scale,
      );
      final slot = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_FocusedStatusGrid',
      );
      final before = tester.getRect(slot);
      pending.complete([]);
      await _pumpAsyncHome(tester);
      expect(tester.getRect(slot), before);
      expect(tester.takeException(), isNull);
    });

    for (final configured in [false, true]) {
      testWidgets(
        'deferred obligations keep Home geometry scale=$scale configured=$configured',
        (tester) async {
          final vehicle = await _readyHome(harness, plate: 'ABC126');
          final pending = Completer<List<VehicleObligation>>();
          await _pump(
            tester,
            harness,
            Scaffold(
              body: ProviderScope(
                overrides: [
                  vehicleObligationsProvider(vehicle.id)
                      .overrideWith((ref) => pending.future),
                ],
                child: const HomeScreen(),
              ),
            ),
            textScaleFactor: scale,
          );
          final grid = find.byKey(const ValueKey('home-status-grid'));
          final soat = find.byKey(const ValueKey('home-status-soat'));
          final rtm = find.byKey(const ValueKey('home-status-rtm'));
          final before = [
            tester.getRect(grid),
            tester.getRect(soat),
            tester.getRect(rtm),
          ];
          expect(find.text('Consultando'), findsNWidgets(2));
          expect(find.text('Sin configurar'), findsNothing);
          pending.complete([
            if (configured)
              for (final type in [
                VehicleObligationType.soat,
                VehicleObligationType.rtm,
              ])
                VehicleObligation(
                  id: type.name,
                  vehicleId: vehicle.id,
                  type: type,
                  reminderEnabled: false,
                  dueDate: DateTime(2027, 1, 20),
                  createdAt: DateTime(2026),
                  updatedAt: DateTime(2026),
                ),
          ]);
          await _pumpAsyncHome(tester);
          expect([
            tester.getRect(grid),
            tester.getRect(soat),
            tester.getRect(rtm),
          ], before);
          expect(find.text('Consultando'), findsNothing);
          expect(
            find.text('Sin configurar'),
            configured ? findsNothing : findsNWidgets(2),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final change in ['city', 'plate']) {
    testWidgets(
      'A3 Home retains selected identity through $change replacement',
      (tester) async {
        harness.now = DateTime(2026, 8, 27, 12);
        final selected = await _createVehicle(harness, plate: 'BBB125');
        final active = await _readyHome(harness, plate: 'AAA126');
        await _setVehicleCreatedAt(
          harness,
          selected.id,
          DateTime.utc(2026, 1, 1),
        );
        await _setVehicleCreatedAt(
          harness,
          active.id,
          DateTime.utc(2026, 1, 2),
        );
        final store = _FakeRestrictionStore(harness.database, harness.now);
        await _pumpFullHomeApp(tester, harness, restrictionStore: store);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(HomeScreen)),
        );
        expect(container.read(homeFocusedVehicleIdProvider), active.id);
        await tester.fling(
          find.byKey(const ValueKey('home-vehicle-page-view')),
          const Offset(-600, 0),
          1200,
        );
        await tester.pumpAndSettle();
        expect(container.read(homeFocusedVehicleIdProvider), selected.id);
        final gate = Completer<void>();
        store.pendingLoad = gate;
        addTearDown(() {
          if (!gate.isCompleted) gate.complete();
        });
        if (change == 'city') {
          await harness.preferences.setString(
            picoJurisdictionPreferenceKey,
            'co-dc-bogota',
          );
          container.invalidate(selectedPicoJurisdictionIdProvider);
        } else {
          await harness.repository.updateVehicle(
            id: selected.id,
            plate: 'BBB124',
            kind: selected.kind,
          );
          container.invalidate(vehicleListProvider);
        }
        await _pumpAsyncHome(tester);
        expect(
          find.byKey(const ValueKey('home-vehicle-page-view')),
          findsOneWidget,
        );
        expect(container.read(homeFocusedVehicleIdProvider), selected.id);
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('home-summary-main')))
              .data,
          'Por verificar',
        );
        gate.complete();
        await _pumpAsyncHome(tester);
        expect(container.read(homeFocusedVehicleIdProvider), selected.id);
        expect((await harness.repository.getActiveVehicle())?.id, active.id);
        await tester.ensureVisible(
          find.byKey(const ValueKey('home-status-today')),
        );
        await tester.tap(find.byKey(const ValueKey('home-status-today')));
        await _pumpAsyncHome(tester);
        expect(
          tester
              .widget<PicoDetailScreen>(find.byType(PicoDetailScreen))
              .vehicleId,
          selected.id,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final width in [360.0, 390.0, 412.0, 430.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('A6 Home banner full text $width scale $scale', (
        tester,
      ) async {
        await _readyHome(harness, plate: 'ABC126');
        const campaign = HomeBannerCampaign(
          kind: HomeBannerKind.house,
          enabled: true,
          priority: 1,
          id: 'audit-banner',
          label: 'ALIADO PREMIUM · DEMO',
          title: 'Protección que te acompaña',
          subtitle: 'Espacio preparado para campañas de aliados verificados.',
          ctaText: 'Conocer más',
          targetUrl: 'https://picoradar.co/demo/home-ally',
        );
        await _pumpHome(
          tester,
          harness,
          viewportSize: Size(width, 915),
          textScaleFactor: scale,
          homeBanner: campaign,
        );
        final banner = find.byKey(const ValueKey('home-bottom-banner-slot'));
        await tester.ensureVisible(banner);
        await tester.pump();
        final bounds = tester.getRect(banner).inflate(0.5);
        for (final label in [
          campaign.label,
          campaign.title,
          campaign.subtitle,
          campaign.ctaText,
        ]) {
          final text = find.descendant(of: banner, matching: find.text(label));
          expect(text, findsOneWidget);
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: text, matching: find.byType(RichText)),
          );
          expect(paragraph.didExceedMaxLines, isFalse, reason: label);
          for (final box in paragraph.getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: label.length),
          )) {
            expect(
              bounds.contains(
                paragraph.localToGlobal(Offset(box.right, box.bottom)),
              ),
              isTrue,
              reason: label,
            );
          }
        }
        expect(
          tester
              .widget<InkWell>(find.byKey(const ValueKey('home-bottom-banner')))
              .onTap,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  group('Home V2 shell states', () {
    for (final size in const [
      Size(360, 800),
      Size(390, 844),
      Size(412, 915),
      Size(430, 932),
    ]) {
      for (final scale in const [1.0, 1.5, 2.0]) {
        testWidgets('V01B Home status readable ${size.width} scale $scale', (
          tester,
        ) async {
          harness.now = DateTime(2026, 8, 27, 12);
          final vehicle = await _readyHome(harness, plate: 'ABC126');
          await _pumpHome(
            tester,
            harness,
            viewportSize: size,
            textScaleFactor: scale,
            bottomNavigationBar: const SizedBox(height: 82),
          );
          final card = find.byKey(ValueKey('home-vehicle-card-${vehicle.id}'));
          final summary = find.byKey(const ValueKey('home-status-today'));
          expect(
            find.textContaining(RegExp('mañana', caseSensitive: false)),
            findsNothing,
          );
          expect(find.text('Particular'), findsNothing);
          expect(
            find.descendant(
              of: card,
              matching: find.text('Tiene pico y placa hoy'),
            ),
            findsNothing,
          );
          expect(
            find.descendant(of: summary, matching: find.byType(FittedBox)),
            findsNothing,
          );
          expect(
            tester
                .widget<Text>(find.byKey(const ValueKey('home-summary-main')))
                .style!
                .fontSize,
            18,
          );
          for (final text in tester.widgetList<Text>(
            find.descendant(of: summary, matching: find.byType(Text)),
          )) {
            expect(text.style!.fontSize, greaterThanOrEqualTo(14));
          }
          expect(tester.getSize(summary).height, greaterThanOrEqualTo(100));
          if (scale == 1) {
            expect(tester.getSize(summary).height, lessThanOrEqualTo(132));
          }
          final plate = find.descendant(
            of: card,
            matching: findPlateNumber('ABC 126'),
          );
          expect(
            tester.getCenter(plate).dx,
            closeTo(tester.getCenter(card).dx, 1),
          );
          final asset = tester.widget<Image>(
            find.byKey(ValueKey('vehicle-visual-image-${vehicle.id}')),
          );
          expect(asset.fit, BoxFit.contain);
          final imageBounds = tester.getRect(
            find.byKey(ValueKey('vehicle-visual-image-${vehicle.id}')),
          );
          expect(imageBounds.height, greaterThan(120));
          expect(
            imageBounds.bottom,
            lessThanOrEqualTo(tester.getTopLeft(plate).dy),
          );
          final clipped = <String>[];
          for (final surface in [
            card,
            find.byKey(const ValueKey('home-status-today')),
          ]) {
            await tester.ensureVisible(surface);
            await tester.pump();
            expect(surface.hitTestable(), findsOneWidget);
            final surfaceBounds = tester.getRect(surface);
            for (final element
                in find
                    .descendant(of: surface, matching: find.byType(RichText))
                    .evaluate()) {
              final paragraph = element.renderObject! as RenderParagraph;
              if (paragraph.didExceedMaxLines) {
                clipped.add(paragraph.text.toPlainText());
              }
              final boxes = paragraph.getBoxesForSelection(
                TextSelection(
                  baseOffset: 0,
                  extentOffset: paragraph.text.toPlainText().length,
                ),
              );
              for (final box in boxes) {
                expect(
                  surfaceBounds.contains(
                    paragraph.localToGlobal(Offset(box.left, box.top)),
                  ),
                  isTrue,
                  reason: paragraph.text.toPlainText(),
                );
                expect(
                  surfaceBounds.contains(
                    paragraph.localToGlobal(Offset(box.right, box.bottom)),
                  ),
                  isTrue,
                  reason: paragraph.text.toPlainText(),
                );
              }
            }
          }
          expect(clipped, isEmpty, reason: 'Essential Home status is clipped');
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets(
      'Home measured layout fits Mi A3 and grows without losing focus',
      (tester) async {
        harness.now = DateTime(2026, 8, 27, 12);
        await _createVehicle(harness, plate: 'XYZ125');
        final vehicle = await _readyHome(harness, plate: 'ABC126');
        tester.view.padding = const FakeViewPadding(top: 24);
        addTearDown(tester.view.resetPadding);
        await _pumpHome(
          tester,
          harness,
          viewportSize: const Size(360, 780),
          bottomNavigationBar: const SizedBox(height: 96),
          homeBanner: const HomeBannerCampaign(
            id: 'layout-full-banner',
            kind: HomeBannerKind.house,
            enabled: true,
            label: 'PicoRadar',
            title: 'Protección que te acompaña',
            subtitle: 'Espacio preparado para campañas y aliados.',
            ctaText: 'Conocer más',
            targetUrl: 'https://picoradar.co/demo/home-ally',
            priority: 1,
          ),
        );
        await tester.pumpAndSettle();

        final scroll = find.byKey(const ValueKey('home-v2-scroll'));
        final carousel = find.byKey(const ValueKey('home-vehicle-carousel'));
        final pageView = find.byKey(const ValueKey('home-vehicle-page-view'));
        final controller = tester.widget<PageView>(pageView).controller!;
        final initialPage = controller.page;
        final container = ProviderScope.containerOf(
          tester.element(find.byType(HomeScreen)),
        );
        expect(container.read(homeFocusedVehicleIdProvider), vehicle.id);
        final position = tester
            .state<ScrollableState>(
              find
                  .descendant(of: scroll, matching: find.byType(Scrollable))
                  .first,
            )
            .position;
        final smallHeight = tester.getSize(carousel).height;
        expect(smallHeight, inInclusiveRange(188, 359));
        expect(position.maxScrollExtent, 0);
        expect(
          tester.widget<SingleChildScrollView>(scroll).physics,
          isA<NeverScrollableScrollPhysics>(),
        );
        final banner = find.byKey(const ValueKey('home-bottom-banner'));
        expect(banner, findsOneWidget);
        expect(tester.getSize(banner).height, greaterThanOrEqualTo(96));
        final viewport = tester.getRect(scroll);
        expect(tester.getRect(banner).top, greaterThanOrEqualTo(viewport.top));
        expect(
          tester.getRect(banner).bottom,
          lessThanOrEqualTo(viewport.bottom),
        );
        expect(
          find.byKey(const ValueKey('home-bottom-banner-cta')),
          findsOneWidget,
        );
        await tester.drag(banner, const Offset(0, -100));
        await tester.pumpAndSettle();
        expect(position.pixels, 0);

        tester.view.physicalSize = const Size(360, 1000);
        await tester.pumpAndSettle();
        expect(tester.getSize(carousel).height, greaterThan(smallHeight));
        expect(tester.getSize(carousel).height, lessThanOrEqualTo(360));
        expect(tester.widget<PageView>(pageView).controller, same(controller));
        expect(controller.page, initialPage);
        expect(container.read(homeFocusedVehicleIdProvider), vehicle.id);
        expect(position.maxScrollExtent, 0);
        expect(tester.binding.hasScheduledFrame, isFalse);
        expect(tester.takeException(), isNull);
      },
    );

    for (final naming in [
      (nickname: '  Familiar  ', brand: 'Toyota', expected: 'Familiar'),
      (nickname: '   ', brand: '  Renault  ', expected: 'Renault'),
      (nickname: null, brand: null, expected: 'Mi vehículo'),
    ]) {
      testWidgets(
        'Home name band uses ${naming.expected} without status text',
        (tester) async {
          harness.now = DateTime(2026, 8, 27, 12);
          final vehicle = await _readyHome(
            harness,
            plate: 'ABC126',
            nickname: naming.nickname,
            brand: naming.brand,
          );
          await _pumpHome(tester, harness);
          final band = find.byKey(
            ValueKey('home-vehicle-name-band-${vehicle.id}'),
          );
          expect(
            find.descendant(of: band, matching: find.byType(Text)),
            findsOneWidget,
          );
          expect(
            tester
                .widget<Text>(
                  find.byKey(ValueKey('home-vehicle-name-${vehicle.id}')),
                )
                .data,
            naming.expected,
          );
          final icon = tester.widget<Icon>(
            find.byKey(ValueKey('home-vehicle-status-${vehicle.id}')),
          );
          expect(
            icon.semanticLabel,
            todayStatusText(RestrictionDayStatus.restricted),
          );
          expect(icon.color, statusColor(RestrictionDayStatus.restricted));
          final card = find.byKey(ValueKey('home-vehicle-card-${vehicle.id}'));
          final nameBounds = tester.getRect(
            find.byKey(ValueKey('home-vehicle-name-${vehicle.id}')),
          );
          expect(
            nameBounds.center.dx,
            closeTo(tester.getRect(card).center.dx, 1),
          );
          expect(
            nameBounds.left,
            greaterThanOrEqualTo(
              tester
                      .getRect(
                        find.byKey(
                          ValueKey('home-vehicle-status-${vehicle.id}'),
                        ),
                      )
                      .right +
                  8,
            ),
          );
          expect(
            find.descendant(
              of: card,
              matching: find.text('Tiene pico y placa hoy'),
            ),
            findsNothing,
          );
          expect(
            find.descendant(of: card, matching: find.text('No puede circular')),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final width in [360.0, 390.0, 412.0, 430.0]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets('Home name is centered without collision $width/$scale', (
          tester,
        ) async {
          final vehicle = await _readyHome(
            harness,
            plate: 'ABC124',
            nickname: 'Mi carro familiar',
          );
          await _pumpHome(
            tester,
            harness,
            viewportSize: Size(width, 844),
            textScaleFactor: scale,
          );
          final name = tester.getRect(
            find.byKey(ValueKey('home-vehicle-name-${vehicle.id}')),
          );
          final band = tester.getRect(
            find.byKey(ValueKey('home-vehicle-name-band-${vehicle.id}')),
          );
          final icon = tester.getRect(
            find.byKey(ValueKey('home-vehicle-status-${vehicle.id}')),
          );
          expect(name.center.dx, closeTo(band.center.dx, 1));
          expect(name.left, greaterThanOrEqualTo(icon.right + 8));
          expect(name.top, greaterThanOrEqualTo(band.top));
          expect(name.bottom, lessThanOrEqualTo(band.bottom));
          expect(tester.takeException(), isNull);
        });
      }
    }

    for (final plateCase in [
      (
        kind: VehicleKind.car,
        service: VehicleServiceType.private,
        plate: 'ABC126',
        city: '  Bogota  ',
        label: 'BOGOTA',
      ),
      (
        kind: VehicleKind.car,
        service: VehicleServiceType.taxi,
        plate: 'TAX078',
        city: 'Bogota',
        label: 'BOGOTA',
      ),
      (
        kind: VehicleKind.motorcycle,
        service: VehicleServiceType.private,
        plate: 'ABC12D',
        city: 'Bogota',
        label: 'COLOMBIA',
      ),
      (
        kind: VehicleKind.car,
        service: VehicleServiceType.private,
        plate: 'ABC126',
        city: null,
        label: 'COLOMBIA',
      ),
      (
        kind: VehicleKind.car,
        service: VehicleServiceType.taxi,
        plate: 'TAX078',
        city: '   ',
        label: 'COLOMBIA',
      ),
    ]) {
      testWidgets(
        'Home plate registration ${plateCase.kind.name} ${plateCase.service.name} ${plateCase.label}',
        (tester) async {
          final vehicle = await _readyHome(
            harness,
            plate: plateCase.plate,
            kind: plateCase.kind,
            serviceType: plateCase.service,
            registrationCity: plateCase.city,
            nickname: 'Mi carro familiar',
          );
          await _pumpHome(
            tester,
            harness,
            viewportSize: const Size(360, 780),
            textScaleFactor: 2,
            bottomNavigationBar: const SizedBox(height: 96),
          );
          await tester.pumpAndSettle();
          final card = find.byKey(ValueKey('home-vehicle-card-${vehicle.id}'));
          final registration = find.descendant(
            of: card,
            matching: find.byKey(
              const ValueKey('colombian-plate-registration-label'),
            ),
          );
          expect(tester.widget<Text>(registration).data, plateCase.label);
          final badge = tester.widget<Container>(
            find.descendant(
              of: card,
              matching: find.byKey(const ValueKey('colombian-plate-badge')),
            ),
          );
          expect(
            (badge.decoration! as BoxDecoration).color,
            plateCase.service == VehicleServiceType.taxi
                ? Colors.white
                : AppColors.plateYellow,
          );
          final plate = find.descendant(
            of: card,
            matching: find.byKey(const ValueKey('colombian-plate-last-group')),
          );
          expect(
            tester.getRect(registration).top,
            greaterThanOrEqualTo(tester.getRect(plate).bottom),
          );
          expect(
            tester.getCenter(registration).dx,
            closeTo(tester.getCenter(card).dx, 1),
          );
          final bounds = tester.getRect(card);
          for (final element
              in find
                  .descendant(of: card, matching: find.byType(RichText))
                  .evaluate()) {
            final paragraph = element.renderObject! as RenderParagraph;
            expect(paragraph.didExceedMaxLines, isFalse);
            for (final box in paragraph.getBoxesForSelection(
              TextSelection(
                baseOffset: 0,
                extentOffset: paragraph.text.toPlainText().length,
              ),
            )) {
              expect(
                bounds.contains(
                  paragraph.localToGlobal(Offset(box.left, box.top)),
                ),
                isTrue,
                reason: paragraph.text.toPlainText(),
              );
              expect(
                bounds.contains(
                  paragraph.localToGlobal(Offset(box.right, box.bottom)),
                ),
                isTrue,
                reason: paragraph.text.toPlainText(),
              );
            }
          }
          expect(tester.binding.hasScheduledFrame, isFalse);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('no vehicle keeps the branded header and R01 empty state', (
      tester,
    ) async {
      await _pumpHome(tester, harness);

      expect(find.byKey(const ValueKey('home-brand-lockup')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-empty-state')), findsOneWidget);
      expect(find.text('No tienes vehículos todavía'), findsOneWidget);
      expect(find.text('Agregar vehículo'), findsOneWidget);
    });

    testWidgets('vehicle without city remains Home V2 and fails closed', (
      tester,
    ) async {
      await _createVehicle(harness, plate: 'ABC123');

      await _pumpHome(tester, harness);

      expect(
        find.byKey(const ValueKey('home-vehicle-carousel')),
        findsOneWidget,
      );
      expect(find.text('Selecciona dónde vas a conducir'), findsOneWidget);
      expect(find.text('Por verificar'), findsWidgets);
      expect(find.text('Puede circular'), findsNothing);
    });

    testWidgets('location pin is compact and does not prompt on startup', (
      tester,
    ) async {
      final gateway = _FakeDeviceLocationGateway()
        ..permission = DeviceLocationPermission.granted;
      await _readyHome(
        harness,
        plate: 'ABC124',
        jurisdictionId: 'co-dc-bogota',
      );

      await _pumpHome(tester, harness, deviceLocationGateway: gateway);

      final locationCard = find.byKey(const ValueKey('home-location-card'));
      expect(locationCard, findsOneWidget);
      expect(find.text('Ubicación'), findsNothing);
      expect(find.text('Bogotá'), findsOneWidget);
      final locationSize = tester.getSize(locationCard);
      expect(locationSize.height, 48);
      expect(locationSize.width, 48);
      expect(
        tester.getTopLeft(locationCard).dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const ValueKey('home-vehicle-carousel')))
              .dy,
        ),
      );
      expect(gateway.checkPermissionCalls, 1);
      expect(gateway.requestPermissionCalls, 0);
      expect(gateway.positionCalls, 0);
      expect(
        find.byKey(const ValueKey('home-location-satellite-status')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('Estado GPS desconocido')),
        findsOneWidget,
      );
    });

    testWidgets('location pin stays compact at small phone width', (
      tester,
    ) async {
      await _readyHome(
        harness,
        plate: 'ABC124',
        jurisdictionId: 'co-dc-bogota',
      );

      await _pumpHome(tester, harness, viewportSize: const Size(360, 800));

      final locationSize = tester.getSize(
        find.byKey(const ValueKey('home-location-card')),
      );
      expect(locationSize.height, 48);
      expect(locationSize.width, 48);
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
        'status strip keeps full Medellín at ${viewport.size.width.toInt()} '
        'text scale ${viewport.textScale}',
        (tester) async {
          await _readyHome(
            harness,
            plate: 'ABC124',
            jurisdictionId: 'co-ant-medellin',
          );

          await _pumpHome(
            tester,
            harness,
            viewportSize: viewport.size,
            textScaleFactor: viewport.textScale,
          );

          final card = find.byKey(const ValueKey('home-status-today'));
          final city = find.descendant(
            of: card,
            matching: find.text('Medellín'),
          );
          final cityWidget = tester.widget<Text>(city);
          final cardRect = tester.getRect(card);
          final cityRect = tester.getRect(city);

          expect(cityWidget.overflow, isNot(TextOverflow.ellipsis));
          expect(cityRect.left, greaterThanOrEqualTo(cardRect.left));
          expect(cityRect.right, lessThanOrEqualTo(cardRect.right));
          expect(cityRect.top, greaterThanOrEqualTo(cardRect.top));
          expect(cityRect.bottom, lessThanOrEqualTo(cardRect.bottom));
          expect(
            find.byKey(const ValueKey('home-location-satellite-status')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'long city label wraps in status strip at 360 and text scale 2',
      (tester) async {
        await _readyHome(
          harness,
          plate: 'ABC124',
          jurisdictionId: 'co-san-bucaramanga-metro',
        );

        await _pumpHome(
          tester,
          harness,
          viewportSize: const Size(360, 800),
          textScaleFactor: 2,
        );

        final card = find.byKey(const ValueKey('home-status-today'));
        final city = find.descendant(
          of: card,
          matching: find.text('Área metropolitana de Bucaramanga'),
        );
        final cityWidget = tester.widget<Text>(city);
        final cardRect = tester.getRect(card);
        final cityRect = tester.getRect(city);

        expect(cityWidget.maxLines, isNull);
        expect(cityWidget.overflow, isNot(TextOverflow.ellipsis));
        expect(cityRect.right, lessThanOrEqualTo(cardRect.right));
        expect(cityRect.bottom, lessThanOrEqualTo(cardRect.bottom));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('location sheet switches manual jurisdiction from Home', (
      tester,
    ) async {
      await _readyHome(
        harness,
        plate: 'ABC124',
        jurisdictionId: 'co-ant-medellin',
      );
      await _pumpHome(tester, harness);

      await tester.tap(find.byKey(const ValueKey('home-location-card')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('jurisdiction-co-dc-bogota')));
      await tester.pumpAndSettle();

      expect(
        await harness.preferences.getString(picoJurisdictionPreferenceKey),
        'co-dc-bogota',
      );
      expect(
        await harness.preferences.getString(locationModePreferenceKey),
        'manual',
      );
    });

    testWidgets('location sheet GPS auto does one-shot foreground detection', (
      tester,
    ) async {
      final gateway = _FakeDeviceLocationGateway()
        ..permission = DeviceLocationPermission.granted
        ..point = const DeviceLocationPoint(
          latitude: 4.7110,
          longitude: -74.0721,
          accuracyMeters: 80,
        );
      await _readyHome(
        harness,
        plate: 'ABC124',
        jurisdictionId: 'co-ant-medellin',
      );
      await _pumpHome(tester, harness, deviceLocationGateway: gateway);

      await tester.tap(find.byKey(const ValueKey('home-location-card')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('location-gps-auto-option')));
      await tester.pumpAndSettle();

      expect(gateway.requestPermissionCalls, 0);
      expect(gateway.positionCalls, 1);
      expect(
        await harness.preferences.getString(picoJurisdictionPreferenceKey),
        'co-dc-bogota',
      );
      expect(
        await harness.preferences.getString(locationModePreferenceKey),
        'gpsAuto',
      );
      final gpsCardSize = tester.getSize(
        find.byKey(const ValueKey('home-location-card')),
      );
      expect(gpsCardSize.height, 48);
      expect(gpsCardSize.width, 48);
      expect(find.text('GPS activo'), findsNothing);
      final satellite = tester.widget<Icon>(
        find.byKey(const ValueKey('home-location-satellite-status')),
      );
      expect(satellite.color, AppColors.green);
      expect(
        find.byKey(const ValueKey('home-location-satellite-lock')),
        findsNothing,
      );
    });

    testWidgets('fresh GPS expires without interaction or another GPS read', (
      tester,
    ) async {
      var visualNow = harness.now.toUtc();
      final gateway = _FakeDeviceLocationGateway()
        ..permission = DeviceLocationPermission.granted
        ..point = const DeviceLocationPoint(
          latitude: 4.7110,
          longitude: -74.0721,
          accuracyMeters: 80,
        );
      await _readyHome(
        harness,
        plate: 'ABC124',
        jurisdictionId: 'co-ant-medellin',
      );
      await harness.preferences.setString(
        locationModePreferenceKey,
        LocationMode.gpsAuto.value,
      );
      await _pumpHome(
        tester,
        harness,
        deviceLocationGateway: gateway,
        homeGpsClock: () => visualNow,
      );
      expect(_satelliteColor(tester), AppColors.green);
      final permissionCalls = gateway.checkPermissionCalls;
      final requestCalls = gateway.requestPermissionCalls;
      final positionCalls = gateway.positionCalls;

      visualNow = visualNow.add(locationRefreshTtl);
      await tester.pump(locationRefreshTtl);

      expect(_satelliteColor(tester), AppColors.blue.withValues(alpha: 0.72));
      expect(
        find.bySemanticsLabel(RegExp('Estado GPS desconocido')),
        findsOneWidget,
      );
      expect(gateway.checkPermissionCalls, permissionCalls);
      expect(gateway.requestPermissionCalls, requestCalls);
      expect(gateway.positionCalls, positionCalls);
    });

    testWidgets('new detected sample replaces the pending visual expiry', (
      tester,
    ) async {
      var visualNow = harness.now.toUtc();
      final gateway = _FakeDeviceLocationGateway()
        ..permission = DeviceLocationPermission.granted
        ..point = const DeviceLocationPoint(
          latitude: 4.7110,
          longitude: -74.0721,
          accuracyMeters: 80,
        );
      await _readyHome(
        harness,
        plate: 'ABC124',
        jurisdictionId: 'co-ant-medellin',
      );
      await harness.preferences.setString(
        locationModePreferenceKey,
        LocationMode.gpsAuto.value,
      );
      await _pumpHome(
        tester,
        harness,
        deviceLocationGateway: gateway,
        homeGpsClock: () => visualNow,
        currentInstantClock: () => visualNow,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );

      visualNow = visualNow.add(const Duration(minutes: 10));
      await tester.pump(const Duration(minutes: 10));
      container.invalidate(currentInstantProvider);
      await container
          .read(locationStateProvider.notifier)
          .refreshGps(requestPermission: false, force: true);
      await _pumpAsyncHome(tester);
      expect(_satelliteColor(tester), AppColors.green);
      final permissionCalls = gateway.checkPermissionCalls;
      final requestCalls = gateway.requestPermissionCalls;
      final positionCalls = gateway.positionCalls;

      visualNow = visualNow.add(const Duration(minutes: 10));
      await tester.pump(const Duration(minutes: 10));
      expect(_satelliteColor(tester), AppColors.green);

      visualNow = visualNow.add(const Duration(minutes: 10));
      await tester.pump(const Duration(minutes: 10));
      expect(_satelliteColor(tester), AppColors.blue.withValues(alpha: 0.72));
      expect(gateway.checkPermissionCalls, permissionCalls);
      expect(gateway.requestPermissionCalls, requestCalls);
      expect(gateway.positionCalls, positionCalls);
    });

    testWidgets('disposing Home cancels pending visual GPS expiry', (
      tester,
    ) async {
      var visualNow = harness.now.toUtc();
      final gateway = _FakeDeviceLocationGateway()
        ..permission = DeviceLocationPermission.granted
        ..point = const DeviceLocationPoint(
          latitude: 4.7110,
          longitude: -74.0721,
          accuracyMeters: 80,
        );
      await _readyHome(
        harness,
        plate: 'ABC124',
        jurisdictionId: 'co-ant-medellin',
      );
      await harness.preferences.setString(
        locationModePreferenceKey,
        LocationMode.gpsAuto.value,
      );
      await _pumpHome(
        tester,
        harness,
        deviceLocationGateway: gateway,
        homeGpsClock: () => visualNow,
      );
      expect(_satelliteColor(tester), AppColors.green);
      final permissionCalls = gateway.checkPermissionCalls;
      final requestCalls = gateway.requestPermissionCalls;
      final positionCalls = gateway.positionCalls;

      await tester.pumpWidget(const SizedBox.shrink());
      visualNow = visualNow.add(locationRefreshTtl);
      await tester.pump(locationRefreshTtl);

      expect(tester.takeException(), isNull);
      expect(gateway.checkPermissionCalls, permissionCalls);
      expect(gateway.requestPermissionCalls, requestCalls);
      expect(gateway.positionCalls, positionCalls);
    });

    testWidgets('revoked GPS on resume replaces stale detected state', (
      tester,
    ) async {
      final gateway = _FakeDeviceLocationGateway()
        ..permission = DeviceLocationPermission.granted
        ..point = const DeviceLocationPoint(
          latitude: 4.7110,
          longitude: -74.0721,
          accuracyMeters: 80,
        );
      await _readyHome(
        harness,
        plate: 'ABC124',
        jurisdictionId: 'co-ant-medellin',
      );
      await harness.preferences.setString(
        locationModePreferenceKey,
        LocationMode.gpsAuto.value,
      );

      await _pumpHome(tester, harness, deviceLocationGateway: gateway);
      expect(
        tester
            .widget<Icon>(
              find.byKey(const ValueKey('home-location-satellite-status')),
            )
            .color,
        AppColors.green,
      );

      gateway.permission = DeviceLocationPermission.denied;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(gateway.requestPermissionCalls, 0);
      expect(
        tester
            .widget<Icon>(
              find.byKey(const ValueKey('home-location-satellite-status')),
            )
            .color,
        AppColors.navy.withValues(alpha: 0.42),
      );
      expect(
        find.byKey(const ValueKey('home-location-satellite-lock')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('GPS desactivado')), findsOneWidget);
    });

    testWidgets('newer revoked probe wins over an older granted completion', (
      tester,
    ) async {
      final gateway = _ControlledDeviceLocationGateway();
      await _readyHome(
        harness,
        plate: 'ABC124',
        jurisdictionId: 'co-dc-bogota',
      );

      await _pumpHome(tester, harness, deviceLocationGateway: gateway);
      expect(gateway.serviceChecks, hasLength(1));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(gateway.serviceChecks, hasLength(2));

      gateway.serviceChecks[1].complete(true);
      await tester.pump();
      expect(gateway.permissionChecks, hasLength(1));
      gateway.permissionChecks[0].complete(DeviceLocationPermission.denied);
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const ValueKey('home-location-satellite-lock')),
        findsOneWidget,
      );

      gateway.serviceChecks[0].complete(true);
      await tester.pump();
      expect(gateway.permissionChecks, hasLength(1));

      expect(
        find.byKey(const ValueKey('home-location-satellite-lock')),
        findsOneWidget,
      );
      expect(gateway.requestPermissionCalls, 0);
    });

    testWidgets('pending lifecycle probe is harmless after Home is disposed', (
      tester,
    ) async {
      final gateway = _ControlledDeviceLocationGateway();
      await _readyHome(
        harness,
        plate: 'ABC124',
        jurisdictionId: 'co-dc-bogota',
      );

      await _pumpHome(tester, harness, deviceLocationGateway: gateway);
      expect(gateway.serviceChecks, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());

      gateway.serviceChecks.single.complete(true);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(gateway.permissionChecks, isEmpty);
      expect(gateway.requestPermissionCalls, 0);
    });

    testWidgets('sheet close reprobes disabled GPS after permission grant', (
      tester,
    ) async {
      final gateway = _FakeDeviceLocationGateway()
        ..permission = DeviceLocationPermission.denied
        ..permissionAfterRequest = DeviceLocationPermission.granted
        ..point = const DeviceLocationPoint(
          latitude: 4.7110,
          longitude: -74.0721,
          accuracyMeters: 80,
        );
      await _readyHome(
        harness,
        plate: 'ABC124',
        jurisdictionId: 'co-ant-medellin',
      );
      await _pumpHome(tester, harness, deviceLocationGateway: gateway);
      expect(
        find.byKey(const ValueKey('home-location-satellite-lock')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('home-location-card')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('location-gps-auto-option')));
      await tester.pumpAndSettle();

      expect(gateway.requestPermissionCalls, 1);
      expect(gateway.checkPermissionCalls, greaterThanOrEqualTo(3));
      expect(
        find.byKey(const ValueKey('home-location-satellite-lock')),
        findsNothing,
      );
      expect(
        tester
            .widget<Icon>(
              find.byKey(const ValueKey('home-location-satellite-status')),
            )
            .color,
        AppColors.green,
      );
    });

    testWidgets(
      'old detected sample is neutral despite cached global instant',
      (tester) async {
        harness.now = DateTime.now().toUtc().subtract(const Duration(hours: 2));
        final gateway = _FakeDeviceLocationGateway()
          ..permission = DeviceLocationPermission.granted
          ..point = const DeviceLocationPoint(
            latitude: 4.7110,
            longitude: -74.0721,
            accuracyMeters: 80,
          );
        await _readyHome(
          harness,
          plate: 'ABC124',
          jurisdictionId: 'co-ant-medellin',
        );
        await harness.preferences.setString(
          locationModePreferenceKey,
          LocationMode.gpsAuto.value,
        );

        await _pumpHome(
          tester,
          harness,
          deviceLocationGateway: gateway,
          homeGpsClock: DateTime.now,
        );

        expect(gateway.positionCalls, 1);
        expect(gateway.requestPermissionCalls, 0);
        expect(
          tester
              .widget<Icon>(
                find.byKey(const ValueKey('home-location-satellite-status')),
              )
              .color,
          AppColors.blue.withValues(alpha: 0.72),
        );
      },
    );

    testWidgets('future detected sample is never presented as current GPS', (
      tester,
    ) async {
      harness.now = DateTime.now().toUtc().add(const Duration(hours: 2));
      final gateway = _FakeDeviceLocationGateway()
        ..permission = DeviceLocationPermission.granted
        ..point = const DeviceLocationPoint(
          latitude: 4.7110,
          longitude: -74.0721,
          accuracyMeters: 80,
        );
      await _readyHome(
        harness,
        plate: 'ABC124',
        jurisdictionId: 'co-ant-medellin',
      );
      await harness.preferences.setString(
        locationModePreferenceKey,
        LocationMode.gpsAuto.value,
      );

      await _pumpHome(
        tester,
        harness,
        deviceLocationGateway: gateway,
        homeGpsClock: DateTime.now,
      );

      expect(gateway.requestPermissionCalls, 0);
      expect(
        tester
            .widget<Icon>(
              find.byKey(const ValueKey('home-location-satellite-status')),
            )
            .color,
        AppColors.blue.withValues(alpha: 0.72),
      );
    });

    testWidgets('resume TTL refresh does not request permission implicitly', (
      tester,
    ) async {
      final gateway = _FakeDeviceLocationGateway()
        ..permission = DeviceLocationPermission.granted
        ..point = const DeviceLocationPoint(
          latitude: 4.7110,
          longitude: -74.0721,
          accuracyMeters: 80,
        );
      await _readyHome(
        harness,
        plate: 'ABC124',
        jurisdictionId: 'co-ant-medellin',
      );
      await harness.preferences.setString(
        locationModePreferenceKey,
        LocationMode.gpsAuto.value,
      );

      await _pumpHome(tester, harness, deviceLocationGateway: gateway);

      expect(gateway.requestPermissionCalls, 0);
      expect(gateway.positionCalls, 1);
      expect(
        await harness.preferences.getString(picoJurisdictionPreferenceKey),
        'co-dc-bogota',
      );
    });

    testWidgets(
      'Home GPS auto refreshes city despite a recent cached jurisdiction',
      (tester) async {
        harness.now = DateTime(2026, 9, 10, 0, 2);
        final gateway = _FakeDeviceLocationGateway()
          ..permission = DeviceLocationPermission.granted
          ..point = const DeviceLocationPoint(
            latitude: 6.2442,
            longitude: -75.5812,
            accuracyMeters: 35,
          );
        final vehicle = await _readyHome(
          harness,
          plate: 'BOG126',
          jurisdictionId: 'co-dc-bogota',
        );
        await harness.preferences.setString(
          locationModePreferenceKey,
          LocationMode.gpsAuto.value,
        );
        await harness.preferences.setInt(
          lastGpsRefreshAtPreferenceKey,
          harness.now
              .toUtc()
              .subtract(const Duration(minutes: 2))
              .millisecondsSinceEpoch,
        );

        await _pumpHome(tester, harness, deviceLocationGateway: gateway);

        expect(gateway.requestPermissionCalls, 0);
        expect(gateway.positionCalls, 1);
        expect(
          await harness.preferences.getString(picoJurisdictionPreferenceKey),
          'co-ant-medellin',
        );
        expect(find.text('Medellín'), findsWidgets);
        expect(
          find.byKey(ValueKey('home-vehicle-status-${vehicle.id}')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('home-status-today')),
            matching: find.text('Tiene pico y placa hoy'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('home-status-today')),
            matching: find.byKey(const ValueKey('home-summary-main')),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('one vehicle hides the counter and renders the status grid', (
      tester,
    ) async {
      final vehicle = await _readyHome(
        harness,
        plate: 'ABC124',
        brand: 'Toyota',
      );
      await harness.preferences.setString(
        selectedAvatarPreferenceKey,
        'avatar_003',
      );

      await _pumpHome(tester, harness);

      expect(
        find.byKey(const ValueKey('home-avatar-image-avatar_003')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('vehicle-visual-image-${vehicle.id}')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('home-carousel-counter')), findsNothing);
      expect(find.byKey(const ValueKey('home-status-grid')), findsOneWidget);
      expect(find.text('SOAT'), findsOneWidget);
      expect(find.text('Tecnomecánica'), findsOneWidget);
      expect(find.text('Comparendos'), findsNothing);
    });

    for (final width in [360.0, 390.0, 412.0, 430.0]) {
      testWidgets('obligation cards remove outer space, not content $width', (
        tester,
      ) async {
        await _readyHome(harness, plate: 'ABC124');
        await _pumpHome(tester, harness, viewportSize: Size(width, 844));
        for (final key in ['home-status-soat', 'home-status-rtm']) {
          final card = find.byKey(ValueKey(key));
          expect(tester.getSize(card).height, 64);
          final text = find.descendant(of: card, matching: find.byType(Text));
          expect(tester.widgetList<Text>(text).map((t) => t.style?.fontSize), [
            11.5,
            14,
            12,
          ]);
          final rect = tester.getRect(card);
          for (final element in text.evaluate()) {
            final bounds = tester.getRect(find.byWidget(element.widget));
            expect(bounds.top, greaterThanOrEqualTo(rect.top));
            expect(bounds.bottom, lessThanOrEqualTo(rect.bottom));
          }
          final icons = tester.widgetList<Icon>(
            find.descendant(of: card, matching: find.byType(Icon)),
          );
          expect(icons.map((i) => i.size), [20, 18]);
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('standard viewport renders compact status IA', (tester) async {
      await _readyHome(harness, plate: 'ABC124');

      await _pumpHome(tester, harness, viewportSize: const Size(390, 844));

      final summary = tester.getTopLeft(
        find.byKey(const ValueKey('home-status-today')),
      );
      final soat = tester.getTopLeft(
        find.byKey(const ValueKey('home-status-soat')),
      );
      final rtm = tester.getTopLeft(
        find.byKey(const ValueKey('home-status-rtm')),
      );
      final summaryBottom = tester.getBottomLeft(
        find.byKey(const ValueKey('home-status-today')),
      );

      expect(summary.dx, lessThanOrEqualTo(soat.dx));
      expect(soat.dy, greaterThan(summaryBottom.dy));
      expect((soat.dy - rtm.dy).abs(), lessThan(1));
      expect(rtm.dx, greaterThan(soat.dx));
      expect(
        find.byKey(const ValueKey('home-status-comparendos')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('home-status-today')),
          matching: find.byIcon(Icons.chevron_right_rounded),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('home-status-pico-action')),
        findsOneWidget,
      );
    });

    testWidgets('compact top bar removes greeting copy', (tester) async {
      await _readyHome(harness, plate: 'ABC124');

      await _pumpHome(tester, harness, viewportSize: const Size(390, 844));

      expect(
        find.byKey(const ValueKey('home-compact-top-bar')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('home-user-controls-capsule')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('picoradar-avatar-control')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('picoradar-bell-control')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('home-avatar-button')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-brand-lockup')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('home-notification-bell')),
        findsOneWidget,
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('home-compact-top-bar')))
            .height,
        56,
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('picoradar-avatar-control')))
            .height,
        48,
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('picoradar-bell-control')))
            .width,
        48,
      );
      final avatarLeft = tester
          .getTopLeft(find.byKey(const ValueKey('picoradar-avatar-control')))
          .dx;
      final locationLeft = tester
          .getTopLeft(find.byKey(const ValueKey('home-location-card')))
          .dx;
      final bellLeft = tester
          .getTopLeft(find.byKey(const ValueKey('picoradar-bell-control')))
          .dx;
      expect(avatarLeft, lessThan(locationLeft));
      expect(locationLeft, lessThan(bellLeft));
      expect(find.text('¡Hola!'), findsNothing);
      expect(find.text('Así están tus vehículos hoy'), findsNothing);
    });

    testWidgets('standard viewport does not ellipsize primary status text', (
      tester,
    ) async {
      await _readyHome(harness, plate: 'ABC126');

      await _pumpHome(tester, harness, viewportSize: const Size(360, 800));

      _expectNoEllipsisInCard(tester, const ValueKey('home-status-today'), [
        'Tiene pico y placa hoy',
        'Restricción finalizada',
      ]);
      _expectNoEllipsisInCard(tester, const ValueKey('home-status-soat'), [
        'SOAT',
        'Sin configurar',
      ]);
      _expectNoEllipsisInCard(tester, const ValueKey('home-status-rtm'), [
        'Tecnomecánica',
        'Sin configurar',
      ]);
    });

    testWidgets('390x844 keeps essential Home content above bottom nav', (
      tester,
    ) async {
      await _readyHome(harness, plate: 'ABC124');

      await _pumpHome(
        tester,
        harness,
        viewportSize: const Size(390, 844),
        bottomNavigationBar: const SizedBox(
          key: ValueKey('test-bottom-nav-budget'),
          height: 96,
        ),
      );

      final bannerBottom = tester.getBottomLeft(
        find.byKey(const ValueKey('home-bottom-banner-slot')),
      );

      expect(bannerBottom.dy, lessThanOrEqualTo(844 - 96));
      expect(find.byKey(const ValueKey('home-start-driving')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('360x800 keeps essential Home content above bottom nav', (
      tester,
    ) async {
      await _readyHome(harness, plate: 'ABC124');

      await _pumpHome(
        tester,
        harness,
        viewportSize: const Size(360, 800),
        bottomNavigationBar: const SizedBox(
          key: ValueKey('test-bottom-nav-budget'),
          height: 96,
        ),
      );

      final bannerBottom = tester.getBottomLeft(
        find.byKey(const ValueKey('home-bottom-banner-slot')),
      );

      expect(bannerBottom.dy, lessThanOrEqualTo(800 - 96));
      expect(find.byKey(const ValueKey('home-start-driving')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('avatar picker selects locally and persists after restart', (
      tester,
    ) async {
      await _readyHome(harness, plate: 'ABC124');
      await _pumpHome(tester, harness);

      await tester.ensureVisible(
        find.byKey(const ValueKey('home-avatar-button')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('home-avatar-button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('header-change-avatar')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('header-open-settings')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('header-change-avatar')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('avatar-picker-grid')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('avatar-option-avatar_004')));
      await tester.pumpAndSettle();

      expect(
        await harness.preferences.getString(selectedAvatarPreferenceKey),
        'avatar_004',
      );

      await _pumpHome(tester, harness);
      expect(
        find.byKey(const ValueKey('home-avatar-image-avatar_004')),
        findsOneWidget,
      );
    });

    testWidgets('avatar menu opens Settings without adding a header button', (
      tester,
    ) async {
      await _readyHome(harness, plate: 'ABC124');
      await _pumpHomeApp(tester, harness);

      expect(
        find.byKey(const ValueKey('picoradar-avatar-control')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('picoradar-bell-control')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('home-avatar-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('header-open-settings')));
      await tester.pumpAndSettle();

      expect(find.text('settings-route'), findsOneWidget);
    });

    testWidgets('vehicle detail picker stores override and auto reset', (
      tester,
    ) async {
      final vehicle = await _readyHome(
        harness,
        plate: 'ABC124',
        brand: 'Toyota',
      );
      await _pumpHomeApp(tester, harness);

      await tester.tap(find.byKey(ValueKey('home-vehicle-card-${vehicle.id}')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('detail-change-vehicle-image')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('detail-change-vehicle-image')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('vehicle-visual-picker-grid')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('vehicle-visual-option-veh_car_toyota_01')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('vehicle-visual-option-veh_moto_yamaha_01')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey('vehicle-visual-option-veh_car_toyota_01')),
      );
      await tester.pumpAndSettle();
      expect(
        await harness.preferences.getString(
          vehicleVisualPreferenceKey(vehicle.id),
        ),
        'veh_car_toyota_01',
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('detail-change-vehicle-image')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('detail-change-vehicle-image')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('vehicle-visual-auto-option')),
      );
      await tester.pumpAndSettle();

      expect(
        await harness.preferences.getString(
          vehicleVisualPreferenceKey(vehicle.id),
        ),
        isNull,
      );
    });

    testWidgets('three vehicles center restricted card without auto advance', (
      tester,
    ) async {
      final first = await _createVehicle(harness, plate: 'AAA111');
      final restricted = await _createVehicle(
        harness,
        plate: 'TST453',
        nickname: 'Familiar',
        year: 2026,
      );
      final last = await _createVehicle(
        harness,
        plate: 'MOT789',
        kind: VehicleKind.motorcycle,
        nickname: 'Moto QA',
      );
      // SQLite stores seconds; distinct fixture times make ordering deterministic.
      await _setVehicleCreatedAt(harness, first.id, DateTime.utc(2026, 1, 1));
      await _setVehicleCreatedAt(
        harness,
        restricted.id,
        DateTime.utc(2026, 1, 2),
      );
      await _setVehicleCreatedAt(harness, last.id, DateTime.utc(2026, 1, 3));
      await harness.preferences.setString(
        picoJurisdictionPreferenceKey,
        'co-ant-medellin',
      );

      await _pumpHome(tester, harness);
      final pageView = tester.widget<PageView>(
        find.byKey(const ValueKey('home-vehicle-page-view')),
      );

      expect(pageView.controller?.viewportFraction, closeTo(0.64, 0.001));
      expect(pageView.pageSnapping, isTrue);
      final carouselHeight = tester
          .getSize(find.byKey(const ValueKey('home-vehicle-carousel')))
          .height;
      expect(carouselHeight, greaterThanOrEqualTo(188));
      expect(carouselHeight, lessThanOrEqualTo(360));
      expect(
        find.byKey(const ValueKey('home-carousel-counter')),
        findsOneWidget,
      );
      expect(find.text('2 de 3'), findsOneWidget);
      expect(find.byKey(const ValueKey('home-carousel-dot-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-carousel-dot-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-carousel-dot-2')), findsOneWidget);
      expect(findPlateNumber('TST 453'), findsOneWidget);
      expect(
        tester.getCenter(findPlateNumber('TST 453')).dx,
        closeTo(
          tester
              .getCenter(
                find.byKey(ValueKey('home-vehicle-card-${restricted.id}')),
              )
              .dx,
          1,
        ),
      );
      expect(find.text('Tiene pico y placa hoy'), findsOneWidget);
      expect(find.byKey(const ValueKey('home-summary-main')), findsOneWidget);
      final restrictedSummary = tester.widget<Text>(
        find.text('Tiene pico y placa hoy'),
      );
      expect(restrictedSummary.overflow, isNot(TextOverflow.ellipsis));

      await tester.pump(const Duration(seconds: 3));
      expect(find.text('2 de 3'), findsOneWidget);
    });
  });

  group('Home V2 priority and focus', () {
    testWidgets('manual focus stays until returning from another tab', (
      tester,
    ) async {
      final favorite = await _createVehicle(harness, plate: 'AAA111');
      await _setVehicleCreatedAt(
        harness,
        favorite.id,
        DateTime.utc(2026, 1, 1),
      );
      final restricted = await _createVehicle(harness, plate: 'ABC123');
      await harness.repository.setActiveVehicle(favorite.id);
      await harness.preferences.setString(
        picoJurisdictionPreferenceKey,
        'co-ant-medellin',
      );
      await _pumpFullHomeApp(tester, harness);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      expect(container.read(homeFocusedVehicleIdProvider), restricted.id);
      await tester.fling(
        find.byKey(const ValueKey('home-vehicle-page-view')),
        const Offset(-600, 0),
        1200,
      );
      await tester.pumpAndSettle();
      expect(container.read(homeFocusedVehicleIdProvider), favorite.id);
      container.invalidate(homeVehicleSnapshotsProvider);
      await _pumpAsyncHome(tester);
      expect(container.read(homeFocusedVehicleIdProvider), favorite.id);
      await tester.tap(find.byKey(const ValueKey('tab-garage')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tab-home')));
      await tester.pumpAndSettle();
      expect(container.read(homeFocusedVehicleIdProvider), restricted.id);
      expect((await harness.repository.getActiveVehicle())?.id, favorite.id);
    });

    testWidgets('return from vehicle detail preserves manually focused page', (
      tester,
    ) async {
      final favorite = await _createVehicle(harness, plate: 'AAA111');
      await _setVehicleCreatedAt(
        harness,
        favorite.id,
        DateTime.utc(2026, 1, 1),
      );
      await _createVehicle(harness, plate: 'ABC123');
      await harness.repository.setActiveVehicle(favorite.id);
      await harness.preferences.setString(
        picoJurisdictionPreferenceKey,
        'co-ant-medellin',
      );
      await _pumpFullHomeApp(tester, harness);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      await tester.fling(
        find.byKey(const ValueKey('home-vehicle-page-view')),
        const Offset(-600, 0),
        1200,
      );
      await tester.pumpAndSettle();
      expect(container.read(homeFocusedVehicleIdProvider), favorite.id);
      final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
      router.push('/garage/vehicle/${favorite.id}');
      await tester.pumpAndSettle();
      router.pop();
      await tester.pumpAndSettle();
      expect(container.read(homeFocusedVehicleIdProvider), favorite.id);
    });

    test('restricted ties use alphabetical ordering, not favorite', () {
      final active = _snapshot('active', RestrictionDayStatus.restricted);
      final other = _snapshot('other', RestrictionDayStatus.restricted);

      expect(
        pickInitialHomeVehicleIndex(
          snapshots: [other, active],
          now: DateTime(2026, 9, 11, 12),
        ),
        1,
      );
    });

    test('non-favorite restricted starts restricted', () {
      expect(
        pickInitialHomeVehicleIndex(
          snapshots: [
            _snapshot('active', RestrictionDayStatus.allowed),
            _snapshot('restricted', RestrictionDayStatus.restricted),
          ],
          now: DateTime(2026, 9, 11, 12),
        ),
        1,
      );
    });

    test('multiple restricted without active uses deterministic first', () {
      expect(
        pickInitialHomeVehicleIndex(
          snapshots: [
            _snapshot('first', RestrictionDayStatus.restricted),
            _snapshot('second', RestrictionDayStatus.restricted),
          ],
          now: DateTime(2026, 9, 11, 12),
        ),
        0,
      );
    });

    test('none restricted uses alphabetical fallback', () {
      expect(
        pickInitialHomeVehicleIndex(
          snapshots: [
            _snapshot('first', RestrictionDayStatus.allowed),
            _snapshot('active', RestrictionDayStatus.allowed),
          ],
          now: DateTime(2026, 9, 11, 12),
        ),
        1,
      );
      expect(
        pickInitialHomeVehicleIndex(
          snapshots: [_snapshot('first', RestrictionDayStatus.allowed)],
          now: DateTime(2026, 9, 11, 12),
        ),
        0,
      );
    });

    test(
      'stale and unknown precede allowed without a verified restriction',
      () {
        expect(
          pickInitialHomeVehicleIndex(
            snapshots: [
              _snapshot('stale', RestrictionDayStatus.stale),
              _snapshot('active', RestrictionDayStatus.allowed),
            ],
            now: DateTime(2026, 9, 11, 12),
          ),
          0,
        );
        expect(
          pickInitialHomeVehicleIndex(
            snapshots: [
              _snapshot('unknown', RestrictionDayStatus.unknown),
              _snapshot('active', RestrictionDayStatus.allowed),
            ],
            now: DateTime(2026, 9, 11, 12),
          ),
          0,
        );
      },
    );

    testWidgets('swipe changes focused vehicle and lower cards follow it', (
      tester,
    ) async {
      final second = await _createVehicle(harness, plate: 'ABC124');
      final active = await _createVehicle(harness, plate: 'AAA111');
      await _setVehicleCreatedAt(harness, second.id, DateTime.utc(2026, 8, 1));
      await _setVehicleCreatedAt(harness, active.id, DateTime.utc(2026, 8, 2));
      await VehicleObligationStore(harness.database).upsert(
        vehicleId: second.id,
        type: VehicleObligationType.soat,
        dueDate: DateTime(2026, 9, 26),
      );
      await harness.repository.setActiveVehicle(active.id);
      await harness.preferences.setString(
        picoJurisdictionPreferenceKey,
        'co-ant-medellin',
      );

      await _pumpHome(tester, harness);
      expect(find.text('Sin configurar'), findsAtLeastNWidgets(2));

      await tester.fling(
        find.byKey(const ValueKey('home-vehicle-page-view')),
        const Offset(-600, 0),
        1200,
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(find.text('2 de 2'), findsOneWidget);
      expect(find.text('30 días'), findsOneWidget);
      expect((await harness.repository.getActiveVehicle())?.id, active.id);
    });

    testWidgets('unrelated rebuild keeps Home snapshots visible', (
      tester,
    ) async {
      await _readyHome(harness, plate: 'ABC124');

      await _pumpHome(tester, harness);
      expect(find.byKey(const ValueKey('home-status-grid')), findsOneWidget);

      await tester.pump();

      expect(find.byKey(const ValueKey('home-status-grid')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('home-vehicle-carousel')),
        findsOneWidget,
      );
      expect(find.text('Sin configurar'), findsAtLeastNWidgets(2));
    });

    testWidgets('card tap opens that vehicle detail without mutating active', (
      tester,
    ) async {
      final active = await _createVehicle(harness, plate: 'AAA111');
      final restricted = await _createVehicle(harness, plate: 'ABC123');
      await harness.repository.setActiveVehicle(active.id);
      await harness.preferences.setString(
        picoJurisdictionPreferenceKey,
        'co-ant-medellin',
      );

      await _pumpHomeApp(tester, harness);
      expect(findPlateNumber('ABC 123'), findsOneWidget);
      await tester.tap(
        find.byKey(ValueKey('home-vehicle-card-${restricted.id}')),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(find.text('Detalle del vehículo'), findsOneWidget);
      expect(findPlateNumber(restricted.plate), findsOneWidget);
      expect((await harness.repository.getActiveVehicle())?.id, active.id);
    });

    testWidgets('Conducir from Home never replaces the favorite', (
      tester,
    ) async {
      final active = await _createVehicle(harness, plate: 'AAA111');
      await _createVehicle(harness, plate: 'ABC123');
      await harness.repository.setActiveVehicle(active.id);
      await harness.preferences.setString(
        picoJurisdictionPreferenceKey,
        'co-ant-medellin',
      );

      await _pumpFullHomeApp(tester, harness);
      expect(find.text('Tiene pico y placa hoy'), findsOneWidget);
      expect((await harness.repository.getActiveVehicle())?.id, active.id);

      await tester.tap(find.byKey(const ValueKey('tab-drive')));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(find.byKey(const ValueKey('start-driving')), findsOneWidget);
      expect((await harness.repository.getActiveVehicle())?.id, active.id);
    });

    testWidgets('Conducir from another tab keeps the global active vehicle', (
      tester,
    ) async {
      final active = await _createVehicle(harness, plate: 'AAA111');
      await _createVehicle(harness, plate: 'ABC123');
      await harness.repository.setActiveVehicle(active.id);
      await harness.preferences.setString(
        picoJurisdictionPreferenceKey,
        'co-ant-medellin',
      );

      await _pumpFullHomeApp(tester, harness);
      await tester.tap(find.byKey(const ValueKey('tab-garage')));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const ValueKey('tab-drive')));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(find.byKey(const ValueKey('start-driving')), findsOneWidget);
      expect((await harness.repository.getActiveVehicle())?.id, active.id);
    });
  });

  group('Home current restriction summary', () {
    for (final reduced in [false, true]) {
      testWidgets('Home clock hand ticks alone, reduced motion=$reduced', (
        tester,
      ) async {
        harness.now = DateTime(2026, 8, 27, 4);
        final vehicle = await _readyHome(harness, plate: 'ABC126');
        final enabled = ValueNotifier(true);
        addTearDown(enabled.dispose);
        await _pumpHome(
          tester,
          harness,
          wrap: (child) => ValueListenableBuilder<bool>(
            valueListenable: enabled,
            builder: (context, tick, _) => TickerMode(
              enabled: tick,
              child: MediaQuery(
                data: MediaQueryData(disableAnimations: reduced),
                child: child,
              ),
            ),
          ),
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(HomeScreen)),
        );
        final provider = homeVehicleSnapshotsProvider(
          HomeVehicleSnapshotsRequest(
            vehicles: [vehicle],
            selectedJurisdiction: _jurisdictions[1],
          ),
        );
        final snapshot = container.read(provider).requireValue;
        Future<List<int>> pixels() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('home-countdown-clock')),
          );
          return (await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 4);
            final bytes = await image.toByteData();
            image.dispose();
            return bytes!.buffer.asUint8List().toList();
          }))!;
        }

        final initial = await pixels();
        await tester.pump(const Duration(seconds: 1));
        final next = await pixels();
        expect(
          next,
          reduced ? orderedEquals(initial) : isNot(orderedEquals(initial)),
        );
        expect(find.text('Empieza en 1 h'), findsOneWidget);
        expect(
          identical(container.read(provider).requireValue, snapshot),
          isTrue,
        );
        enabled.value = false;
        await tester.pump();
        final hidden = await pixels();
        await tester.pump(const Duration(seconds: 3));
        expect(await pixels(), orderedEquals(hidden));
        enabled.value = true;
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        final paused = await pixels();
        await tester.pump(const Duration(seconds: 3));
        expect(await pixels(), orderedEquals(paused));
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump(const Duration(seconds: 1));
        expect(
          await pixels(),
          reduced ? orderedEquals(paused) : isNot(orderedEquals(paused)),
        );
        final paint = tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byKey(const ValueKey('home-countdown-clock')),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!;
        var repaints = 0;
        void recordRepaint() => repaints++;
        paint.addListener(recordRepaint);
        final navigator = Navigator.of(tester.element(find.byType(HomeScreen)));
        unawaited(
          navigator.push<void>(
            MaterialPageRoute(
              builder: (_) => const Scaffold(body: Text('Covered route')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final coveredRepaints = repaints;
        await tester.pump(const Duration(seconds: 3));
        expect(repaints, coveredRepaints);
        navigator.pop();
        await tester.pumpAndSettle();
        final restoredRepaints = repaints;
        await tester.pump(const Duration(seconds: 1));
        expect(
          repaints,
          reduced ? restoredRepaints : greaterThan(restoredRepaints),
        );
        paint.removeListener(recordRepaint);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('missing windows cannot claim a timed restriction', (
      tester,
    ) async {
      await _readyHome(harness, plate: 'ABC126');
      await _pumpHome(
        tester,
        harness,
        homeEvaluation: const RestrictionDayEvaluation(
          status: RestrictionDayStatus.restricted,
          effectiveWindows: [],
        ),
      );
      expect(find.text('Por verificar'), findsOneWidget);
      expect(find.text('Tiene pico y placa hoy'), findsNothing);
      expect(
        find.byKey(const ValueKey('home-summary-countdown')),
        findsNothing,
      );
    });

    for (final width in [360.0, 390.0, 412.0, 430.0]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets('single window countdown layout $width/$scale', (
          tester,
        ) async {
          harness.now = DateTime(2026, 8, 27, 17, 45);
          await _readyHome(harness, plate: 'ABC126');
          await _pumpHome(
            tester,
            harness,
            viewportSize: Size(width, 844),
            textScaleFactor: scale,
          );
          final summary = find.byKey(const ValueKey('home-status-today'));
          await tester.ensureVisible(summary);
          await tester.pump();
          final bounds = tester.getRect(summary);
          if (scale == 1) expect(bounds.height, inInclusiveRange(100, 108));
          final keys = [
            'home-summary-label',
            'home-summary-main',
            'home-summary-countdown',
            'home-summary-city',
          ];
          Rect? previous;
          for (final key in keys) {
            final finder = find.byKey(ValueKey(key));
            final rect = tester.getRect(finder);
            expect(rect.top, greaterThanOrEqualTo(bounds.top));
            expect(rect.bottom, lessThanOrEqualTo(bounds.bottom));
            if (previous != null) {
              expect(rect.top, greaterThan(previous.bottom));
            }
            previous = rect;
            final paragraph = tester.renderObject<RenderParagraph>(finder);
            expect(paragraph.didExceedMaxLines, isFalse);
          }
          expect(find.text('Termina en 2 h 15 min'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }

    for (final scenario in [
      (hour: 1, minute: 0, second: 0, countdown: 'Empieza en 4 h'),
      (hour: 4, minute: 59, second: 0, countdown: 'Empieza en 1 min'),
      (hour: 4, minute: 59, second: 59, countdown: 'Empieza en 1 min'),
      (hour: 5, minute: 0, second: 0, countdown: 'Termina en 15 h'),
      (hour: 17, minute: 45, second: 0, countdown: 'Termina en 2 h 15 min'),
      (hour: 19, minute: 59, second: 59, countdown: 'Termina en 1 min'),
      (hour: 20, minute: 0, second: 0, countdown: null),
    ]) {
      testWidgets(
        'Home countdown ${scenario.hour}:${scenario.minute}:${scenario.second}',
        (tester) async {
          harness.now = DateTime(
            2026,
            8,
            27,
            scenario.hour,
            scenario.minute,
            scenario.second,
          );
          await _readyHome(harness, plate: 'ABC126');
          await _pumpHome(tester, harness);
          expect(find.text('Tiene pico y placa hoy'), findsOneWidget);
          final main = tester.widget<Text>(
            find.byKey(const ValueKey('home-summary-main')),
          );
          final countdown = find.byKey(
            const ValueKey('home-summary-countdown'),
          );
          if (scenario.countdown == null) {
            expect(main.data, 'Restricción finalizada');
            expect(countdown, findsNothing);
            expect(
              find.byKey(const ValueKey('home-countdown-clock')),
              findsNothing,
            );
          } else {
            expect(
              main.data!.replaceAll('\u00a0', ' '),
              '5:00 a. m. – 8:00 p. m.',
            );
            expect(tester.widget<Text>(countdown).data, scenario.countdown);
            expect(
              find.byKey(const ValueKey('home-countdown-clock')),
              findsOneWidget,
            );
            expect(
              find.byWidgetPredicate(
                (w) =>
                    w is Text &&
                    (w.data?.replaceAll('\u00a0', ' ') ==
                        '5:00 a. m. – 8:00 p. m.'),
              ),
              findsOneWidget,
            );
            expect(
              tester
                  .getSize(find.byKey(const ValueKey('home-status-today')))
                  .height,
              inInclusiveRange(100, 108),
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }

    const splitWindows = [
      RestrictionDayWindow(startMinute: 300, endMinute: 540),
      RestrictionDayWindow(startMinute: 960, endMinute: 1200),
    ];
    for (final scenario in [
      (
        status: RestrictionDayStatus.restricted,
        hour: 4,
        main: '5:00 a. m. – 9:00 a. m.\n4:00 p. m. – 8:00 p. m.',
      ),
      (
        status: RestrictionDayStatus.restricted,
        hour: 5,
        main: '5:00 a. m. – 9:00 a. m.\n4:00 p. m. – 8:00 p. m.',
      ),
      (
        status: RestrictionDayStatus.restricted,
        hour: 12,
        main: '5:00 a. m. – 9:00 a. m.\n4:00 p. m. – 8:00 p. m.',
      ),
      (
        status: RestrictionDayStatus.restricted,
        hour: 20,
        main: 'Restricción finalizada',
      ),
      (status: RestrictionDayStatus.allowed, hour: 12, main: 'Puede circular'),
      (status: RestrictionDayStatus.unknown, hour: 12, main: 'Por verificar'),
      (status: RestrictionDayStatus.stale, hour: 12, main: 'Datos vencidos'),
    ]) {
      testWidgets('summary phase ${scenario.main}', (tester) async {
        harness.now = DateTime(2026, 8, 27, scenario.hour);
        final vehicle = await _readyHome(harness, plate: 'ABC126');
        final restricted = scenario.status == RestrictionDayStatus.restricted;
        await _pumpHome(
          tester,
          harness,
          homeEvaluation: RestrictionDayEvaluation(
            status: scenario.status,
            effectiveWindows: restricted ? splitWindows : const [],
          ),
        );
        final main = tester.widget<Text>(
          find.byKey(const ValueKey('home-summary-main')),
        );
        expect(main.data!.replaceAll('\u00a0', ' '), scenario.main);
        final label = tester.widget<Text>(
          find.byKey(const ValueKey('home-summary-label')),
        );
        final allowed = scenario.status == RestrictionDayStatus.allowed;
        expect(
          label.data,
          restricted
              ? 'Tiene pico y placa hoy'
              : allowed
              ? 'Sin pico y placa hoy'
              : 'Pico y placa',
        );
        expect(
          label.style!.color,
          restricted
              ? AppColors.red
              : allowed
              ? AppColors.green
              : const Color(0xFFCDDBE6),
        );
        final summaryIcon = find.byKey(
          const ValueKey('home-summary-status-icon'),
        );
        expect(
          find.descendant(
            of: summaryIcon,
            matching: find.byIcon(Icons.check_circle_outline_rounded),
          ),
          allowed ? findsOneWidget : findsNothing,
        );
        if (allowed) {
          expect(main.style!.color, Colors.white);
          expect(
            find.descendant(
              of: summaryIcon,
              matching: find.byIcon(Icons.directions_car_rounded),
            ),
            findsNothing,
          );
          expect(
            find.ancestor(
              of: find.byKey(const ValueKey('home-summary-main')),
              matching: find.byType(DecoratedBox),
            ),
            findsNothing,
          );
          expect(
            tester
                .getSize(find.byKey(const ValueKey('home-status-today')))
                .height,
            inInclusiveRange(100, 108),
          );
        }
        final semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Ver pico y placa',
          ),
        );
        expect(semantics.properties.value, contains(scenario.main));
        expect(semantics.properties.value, isNot(contains('\u00a0')));
        expect(semantics.properties.value, contains('Medellín'));
        expect(
          find.text('Tiene pico y placa hoy'),
          restricted ? findsOneWidget : findsNothing,
        );
        final icon = tester.widget<Icon>(
          find.byKey(ValueKey('home-vehicle-status-${vehicle.id}')),
        );
        expect(
          icon.color,
          restricted
              ? AppColors.red
              : scenario.status == RestrictionDayStatus.allowed
              ? AppColors.green
              : AppColors.orange,
        );
        final material = tester.widget<Material>(
          find
              .ancestor(
                of: find.byKey(ValueKey('home-vehicle-card-${vehicle.id}')),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(material.shadowColor, icon.color!.withValues(alpha: 0.4));
        expect(material.elevation, greaterThan(0));
        expect(material.animationDuration, Duration.zero);
        if (restricted && scenario.hour < 20) {
          final windows = tester.widget<Text>(
            find.byKey(const ValueKey('home-summary-main')),
          );
          expect(
            windows.data!.replaceAll('\u00a0', ' '),
            '5:00 a. m. – 9:00 a. m.\n4:00 p. m. – 8:00 p. m.',
          );
          expect(windows.data, contains('5:00\u00a0a.\u00a0m.'));
          expect(
            semantics.properties.value,
            contains('5:00 a. m. – 9:00 a. m.\n4:00 p. m. – 8:00 p. m.'),
          );
          final expectedCountdown = switch (scenario.hour) {
            4 => 'Empieza en 1 h',
            5 => 'Este tramo termina en 4 h',
            _ => 'Próximo tramo en 4 h',
          };
          expect(find.text(expectedCountdown), findsOneWidget);
          expect(semantics.properties.value, contains(expectedCountdown));
          expect(semantics.properties.liveRegion, isNot(true));
          if (scenario.hour == 12) {
            expect(find.text('Sin restricción ahora'), findsOneWidget);
          }
        } else {
          expect(find.text('No puede circular'), findsNothing);
          expect(
            find.byKey(const ValueKey('home-summary-countdown')),
            findsNothing,
          );
        }
        expect(
          find.textContaining(RegExp('mañana', caseSensitive: false)),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      });
    }

    for (final width in [360.0, 390.0, 412.0, 430.0]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets('summary split windows bounds $width scale $scale', (
          tester,
        ) async {
          harness.now = DateTime(2026, 8, 27, 12);
          await _readyHome(harness, plate: 'ABC126');
          await _pumpHome(
            tester,
            harness,
            viewportSize: Size(width, 932),
            textScaleFactor: scale,
            homeEvaluation: const RestrictionDayEvaluation(
              status: RestrictionDayStatus.restricted,
              effectiveWindows: splitWindows,
            ),
          );
          final summary = find.byKey(const ValueKey('home-status-today'));
          await tester.ensureVisible(summary);
          await tester.pump();
          final bounds = tester.getRect(summary);
          for (final element
              in find
                  .descendant(of: summary, matching: find.byType(RichText))
                  .evaluate()) {
            final paragraph = element.renderObject! as RenderParagraph;
            expect(paragraph.didExceedMaxLines, isFalse);
            final text = paragraph.text.toPlainText();
            for (final box in paragraph.getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: text.length),
            )) {
              expect(
                bounds.contains(
                  paragraph.localToGlobal(Offset(box.left, box.top)),
                ),
                isTrue,
                reason: text,
              );
              expect(
                bounds.contains(
                  paragraph.localToGlobal(Offset(box.right, box.bottom)),
                ),
                isTrue,
                reason: text,
              );
            }
          }
          final windows = tester.getRect(
            find.byKey(const ValueKey('home-summary-main')),
          );
          final city = tester.getRect(
            find.byKey(const ValueKey('home-summary-city')),
          );
          expect(city.top, greaterThan(windows.bottom));
          expect(
            tester
                .getSize(find.byKey(const ValueKey('home-summary-status-icon')))
                .width,
            greaterThanOrEqualTo(56),
          );
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('minute changes phase without reloading daily snapshots', (
      tester,
    ) async {
      harness.now = DateTime(2026, 8, 27, 4, 59);
      final vehicle = await _readyHome(harness, plate: 'ABC126');
      final gateway = _FakeDeviceLocationGateway();
      await _pumpHome(tester, harness, deviceLocationGateway: gateway);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      final provider = homeVehicleSnapshotsProvider(
        HomeVehicleSnapshotsRequest(
          vehicles: [vehicle],
          selectedJurisdiction: _jurisdictions[1],
        ),
      );
      final first = container.read(provider).requireValue;
      final gpsCalls = gateway.positionCalls;
      harness.now = DateTime(2026, 8, 27, 5);
      container.invalidate(currentInstantProvider);
      container.invalidate(bogotaNowProvider);
      await _pumpAsyncHome(tester);
      expect(find.text('Termina en 15 h'), findsOneWidget);
      expect(identical(container.read(provider).requireValue, first), isTrue);
      harness.now = DateTime(2026, 8, 27, 20);
      container.invalidate(currentInstantProvider);
      container.invalidate(bogotaNowProvider);
      await _pumpAsyncHome(tester);
      expect(find.text('Restricción finalizada'), findsOneWidget);
      expect(identical(container.read(provider).requireValue, first), isTrue);
      expect(gateway.positionCalls, gpsCalls);
      container.invalidate(bundledRestrictionsProvider);
      await _pumpAsyncHome(tester);
      final refreshed = container.read(provider).requireValue;
      expect(identical(refreshed, first), isFalse);
      harness.now = DateTime(2026, 8, 28);
      container.invalidate(currentInstantProvider);
      container.invalidate(bogotaNowProvider);
      await _pumpAsyncHome(tester);
      expect(
        identical(container.read(provider).requireValue, refreshed),
        isFalse,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('home-summary-main')))
            .data,
        'Puede circular',
      );
      expect(container.read(homeFocusedVehicleIdProvider), vehicle.id);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
    'Home countdown follows real clock ticks and resume without coverage reload',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      harness.now = DateTime(2026, 9, 10, 4, 59);
      var nowUtc = DateTime.utc(2026, 9, 10, 9, 59);
      await _readyHome(harness, plate: 'BOG126');
      final store = _FakeRestrictionStore(harness.database, harness.now);
      await _pumpFullHomeApp(
        tester,
        harness,
        appClockNow: () => nowUtc,
        restrictionStore: store,
      );
      expect(find.text('Empieza en 1 min'), findsOneWidget);
      final loads = store.loadCalls;
      nowUtc = DateTime.utc(2026, 9, 10, 10);
      await tester.pump(const Duration(minutes: 1));
      await _pumpAsyncHome(tester);
      expect(find.text('Termina en 15 h'), findsOneWidget);
      expect(store.loadCalls, loads);
      nowUtc = DateTime.utc(2026, 9, 10, 10, 1);
      await tester.pump(const Duration(minutes: 1));
      await _pumpAsyncHome(tester);
      expect(find.text('Termina en 14 h 59 min'), findsOneWidget);
      expect(store.loadCalls, loads);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      nowUtc = DateTime.utc(2026, 9, 11, 1);
      await tester.pump(const Duration(minutes: 1));
      expect(find.text('Termina en 14 h 59 min'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _pumpAsyncHome(tester);
      expect(find.text('Restricción finalizada'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('home-summary-countdown')),
        findsNothing,
      );
      // A corrected wall clock on resume must recalculate, not decrement old state.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      nowUtc = DateTime.utc(2026, 9, 10, 9, 59);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _pumpAsyncHome(tester);
      expect(find.text('Empieza en 1 min'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('real AppClock rolls Home and Pico from September 9 to 10', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    harness.now = DateTime(2026, 9, 9, 23, 59);
    var nowUtc = DateTime.utc(2026, 9, 10, 4, 59);
    final store = _FakeRestrictionStore(harness.database, harness.now);
    final active = await _createVehicle(harness, plate: 'AAA111');
    final focused = await _createVehicle(harness, plate: 'BOG126');
    await _setVehicleCreatedAt(harness, active.id, DateTime.utc(2026, 1, 2));
    await _setVehicleCreatedAt(harness, focused.id, DateTime.utc(2026, 1, 1));
    await harness.repository.setActiveVehicle(active.id);
    await harness.preferences.setString(
      picoJurisdictionPreferenceKey,
      'co-ant-medellin',
    );
    await _pumpFullHomeApp(
      tester,
      harness,
      appClockNow: () => nowUtc,
      restrictionStore: store,
    );
    final appState = tester.state(find.byType(PicoRadarApp));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PicoRadarApp)),
    );
    expect(container.exists(appClockProvider), isTrue);
    expect(container.read(appClockProvider), nowUtc);
    expect(container.read(bogotaNowProvider), DateTime(2026, 9, 9, 23, 59));
    expect(container.read(homeFocusedVehicleIdProvider), focused.id);
    expect(
      container
          .read(vehicleListProvider)
          .requireValue
          .map((vehicle) => vehicle.id),
      [active.id, focused.id],
    );
    expect(
      tester
          .widget<PageView>(
            find.byKey(const ValueKey('home-vehicle-page-view')),
          )
          .controller!
          .page,
      1,
    );
    await tester.fling(
      find.byKey(const ValueKey('home-vehicle-page-view')),
      const Offset(600, 0),
      1200,
    );
    await tester.pumpAndSettle();
    expect(container.read(homeFocusedVehicleIdProvider), active.id);
    await tester.fling(
      find.byKey(const ValueKey('home-vehicle-page-view')),
      const Offset(-600, 0),
      1200,
    );
    await tester.pumpAndSettle();
    expect(container.read(homeFocusedVehicleIdProvider), focused.id);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('home-summary-main'))).data,
      'Puede circular',
    );
    final homePages = tester
        .widget<PageView>(find.byKey(const ValueKey('home-vehicle-page-view')))
        .controller;

    await tester.ensureVisible(find.byKey(const ValueKey('home-status-today')));
    await tester.tap(find.byKey(const ValueKey('home-status-today')));
    await _pumpPicoShell(tester);
    await _pumpAsyncHome(tester);
    expect(find.byKey(const ValueKey('pico-personal-identity')), findsOneWidget);
    expect(findPlateNumber(focused.plate), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Hoy · Mié 09/09/2026'),
      160,
      scrollable: find
          .descendant(
            of: find.byType(PicoDetailScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Hoy · Mié 09/09/2026'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('pico-summary-main'))).data,
      'Puede circular',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('pico-personal-month-calendar')));
    await tester.pumpAndSettle();
        await tester.pumpAndSettle();
    Finder todayMarker(String date, String status) => find.ancestor(
      of: find.byKey(ValueKey('pico-month-day-$date')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Hoy · $date $status' &&
            widget.properties.selected == true,
      ),
    );
    expect(todayMarker('2026-09-09', 'Sin pico y placa'), findsOneWidget);
    expect(todayMarker('2026-09-10', 'Con pico y placa'), findsNothing);

    // The injected source advances; only AppClock's minute timer publishes it.
    store.pendingLoad = Completer<void>();
    addTearDown(() {
      final pending = store.pendingLoad;
      if (pending != null && !pending.isCompleted) pending.complete();
    });
    nowUtc = DateTime.utc(2026, 9, 10, 5);
    expect(container.read(bogotaNowProvider).day, 9);
    await tester.pump(const Duration(minutes: 1));
    await _pumpAsyncHome(tester);
    expect(container.read(appClockProvider), nowUtc);
    expect(container.read(currentInstantProvider), nowUtc);
    expect(container.read(bogotaNowProvider), DateTime(2026, 9, 10));
    expect(todayMarker('2026-09-09', 'Sin pico y placa'), findsNothing);
    expect(todayMarker('2026-09-10', 'Por verificar'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('pico-summary-main')),
      -200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('pico-scroll-root')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Hoy · Jue 10/09/2026'),
      -100,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('pico-scroll-root')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Hoy · Jue 10/09/2026'), findsOneWidget);
    expect(find.text('Hoy · Mié 09/09/2026'), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('pico-summary-main'))).data,
      'Por verificar',
    );
    expect(find.text('No puede circular'), findsNothing);

    await tester.binding.handlePopRoute();
    await _pumpAsyncHome(tester);
    expect(
      identical(tester.state(find.byType(PicoRadarApp)), appState),
      isTrue,
    );
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(container.read(homeFocusedVehicleIdProvider), focused.id);
    expect(
      identical(
        tester
            .widget<PageView>(
              find.byKey(const ValueKey('home-vehicle-page-view')),
            )
            .controller,
        homePages,
      ),
      isTrue,
    );
    expect(
      tester
          .widget<PageView>(
            find.byKey(const ValueKey('home-vehicle-page-view')),
          )
          .controller!
          .page,
      closeTo(1, 0.001),
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('home-summary-main'))).data,
      'Por verificar',
    );
    expect(find.text('Puede circular'), findsNothing);
    expect(
      tester
          .widget<Icon>(
            find.byKey(ValueKey('home-vehicle-status-${focused.id}')),
          )
          .color,
      AppColors.orange,
    );
    store.pendingLoad!.complete();
    store.pendingLoad = null;
    await _pumpAsyncHome(tester);
    final homeMain = tester.widget<Text>(
      find.byKey(const ValueKey('home-summary-main')),
    );
    expect(homeMain.data!.replaceAll('\u00a0', ' '), '5:00 a. m. – 8:00 p. m.');
    expect(find.text('Tiene pico y placa hoy'), findsOneWidget);
    expect(find.text('No puede circular'), findsNothing);
    expect(container.read(homeFocusedVehicleIdProvider), focused.id);
    expect(homePages!.page, closeTo(1, 0.001));

    await tester.ensureVisible(find.byKey(const ValueKey('home-status-today')));
    await tester.tap(find.byKey(const ValueKey('home-status-today')));
    await _pumpPicoShell(tester);
    await _pumpAsyncHome(tester);
    expect(find.text('Hoy · Jue 10/09/2026'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('pico-summary-main'))).data,
      '5:00\u00a0a.\u00a0m. – 8:00\u00a0p.\u00a0m.',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('pico-personal-month-calendar')));
    await tester.pumpAndSettle();
        await tester.pumpAndSettle();
    expect(todayMarker('2026-09-10', 'Con pico y placa'), findsOneWidget);
    expect(todayMarker('2026-09-09', 'Sin pico y placa'), findsNothing);
    expect(
      identical(tester.state(find.byType(PicoRadarApp)), appState),
      isTrue,
    );
    expect((await harness.repository.getActiveVehicle())?.id, active.id);
    expect(
      await harness.preferences.getString(picoJurisdictionPreferenceKey),
      'co-ant-medellin',
    );
    expect(tester.takeException(), isNull);
  });

  group('Home V2 data truth', () {
    testWidgets('SOAT and RTM missing show Sin configurar', (tester) async {
      await _readyHome(harness, plate: 'ABC124');

      await _pumpHome(tester, harness);

      expect(find.text('Sin configurar'), findsAtLeastNWidgets(2));
      expect(find.text('0 pendientes'), findsNothing);
      expect(find.text('Consultar'), findsNothing);
    });

    testWidgets('real SOAT and RTM due dates derive summaries', (tester) async {
      final vehicle = await _readyHome(harness, plate: 'ABC124');
      final store = VehicleObligationStore(harness.database);
      await store.upsert(
        vehicleId: vehicle.id,
        type: VehicleObligationType.soat,
        dueDate: DateTime(2026, 9, 26),
      );
      await store.upsert(
        vehicleId: vehicle.id,
        type: VehicleObligationType.rtm,
        dueDate: DateTime(2026, 12, 31),
      );

      await _pumpHome(tester, harness);

      expect(find.text('30 días'), findsOneWidget);
      expect(find.text('126 días'), findsOneWidget);
      expect(find.text('Vence pronto según la fecha guardada'), findsOneWidget);
      expect(find.text('Vigente según la fecha guardada'), findsOneWidget);
    });

    testWidgets('stale and unknown restrictions never render green allowed', (
      tester,
    ) async {
      harness.now = DateTime(2027, 1, 2);
      await _readyHome(harness, plate: 'ABC124');

      await _pumpHome(tester, harness);

      expect(find.text('Datos vencidos'), findsWidgets);
      expect(find.text('Puede circular'), findsNothing);

      harness = TestAppHarness();
      await _readyHome(
        harness,
        plate: 'TAX123',
        serviceType: VehicleServiceType.taxi,
      );
      await _pumpHome(tester, harness);

      expect(find.text('Por verificar'), findsWidgets);
      expect(find.text('Puede circular'), findsNothing);
    });

    testWidgets('promo and C14 card stay out of compact Home', (tester) async {
      await _readyHome(harness, plate: 'ABC124');

      await _pumpHome(tester, harness);

      expect(find.text('Más control, más tranquilidad.'), findsNothing);
      expect(
        find.textContaining('Próximamente nuevas funciones'),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('home-status-comparendos')),
        findsNothing,
      );
      expect(find.textContaining('PicoRadar Protect'), findsNothing);
      expect(find.byKey(const ValueKey('home-start-driving')), findsNothing);
    });
  });

  group('Home V2 module tap reliability', () {
    testWidgets('Summary sends active taxi to Pico without mutating active', (
      tester,
    ) async {
      final activeTaxi = await _createVehicle(
        harness,
        plate: 'TAX125',
        serviceType: VehicleServiceType.taxi,
        brand: 'Taxi',
        year: 2022,
      );
      final toyota = await _createVehicle(
        harness,
        plate: 'ABC124',
        brand: 'Toyota',
        year: 2023,
      );
      final renault = await _createVehicle(
        harness,
        plate: 'REN126',
        brand: 'Renault',
        year: 2024,
      );
      await _setVehicleCreatedAt(
        harness,
        activeTaxi.id,
        DateTime.utc(2026, 8, 3),
      );
      await _setVehicleCreatedAt(harness, toyota.id, DateTime.utc(2026, 8, 2));
      await _setVehicleCreatedAt(harness, renault.id, DateTime.utc(2026, 8, 1));
      await harness.repository.setActiveVehicle(activeTaxi.id);
      await harness.preferences.setString(
        picoJurisdictionPreferenceKey,
        'co-dc-bogota',
      );

      await _pumpHomeApp(tester, harness);

      await _openSummaryAndExpectPico(tester, activeTaxi);
      expect((await harness.repository.getActiveVehicle())?.id, activeTaxi.id);
    });

    testWidgets('Summary, SOAT and RTM use focused non-active vehicle', (
      tester,
    ) async {
      final activeTaxi = await _createVehicle(
        harness,
        plate: 'TAX129',
        serviceType: VehicleServiceType.taxi,
        brand: 'Taxi',
        year: 2022,
      );
      final toyota = await _createVehicle(
        harness,
        plate: 'ABC123',
        brand: 'Toyota',
        year: 2023,
      );
      await _createVehicle(
        harness,
        plate: 'REN126',
        brand: 'Renault',
        year: 2024,
      );
      await _setVehicleCreatedAt(
        harness,
        activeTaxi.id,
        DateTime.utc(2026, 8, 3),
      );
      await _setVehicleCreatedAt(harness, toyota.id, DateTime.utc(2026, 8, 2));
      await harness.repository.setActiveVehicle(activeTaxi.id);
      await harness.preferences.setString(
        picoJurisdictionPreferenceKey,
        'co-dc-bogota',
      );

      await _pumpHomeApp(tester, harness);

      await tester.tap(find.byKey(const ValueKey('home-status-soat')));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('module-soat-${toyota.id}'), findsOneWidget);
      expect((await harness.repository.getActiveVehicle())?.id, activeTaxi.id);

      await _goHome(tester);
      await tester.tap(find.byKey(const ValueKey('home-status-rtm')));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('module-tecnomecanica-${toyota.id}'), findsOneWidget);
      expect((await harness.repository.getActiveVehicle())?.id, activeTaxi.id);

      await _goHome(tester);
      await _openSummaryAndExpectPico(tester, toyota);
      expect((await harness.repository.getActiveVehicle())?.id, activeTaxi.id);
    });

    testWidgets('Summary can target a third focused vehicle', (tester) async {
      final activeTaxi = await _createVehicle(
        harness,
        plate: 'TAX129',
        serviceType: VehicleServiceType.taxi,
        brand: 'Taxi',
      );
      await _createVehicle(harness, plate: 'ABC124', brand: 'Toyota');
      final renault = await _createVehicle(
        harness,
        plate: 'REN123',
        brand: 'Renault',
      );
      await _setVehicleCreatedAt(harness, renault.id, DateTime.utc(2026, 8, 3));
      await harness.repository.setActiveVehicle(activeTaxi.id);
      await harness.preferences.setString(
        picoJurisdictionPreferenceKey,
        'co-dc-bogota',
      );

      await _pumpHomeApp(tester, harness);

      await _openSummaryAndExpectPico(tester, renault);
      expect((await harness.repository.getActiveVehicle())?.id, activeTaxi.id);
    });

    testWidgets('explicit Pico vehicle uses third vehicle directly', (
      tester,
    ) async {
      final activeTaxi = await _createVehicle(
        harness,
        plate: 'TAX129',
        serviceType: VehicleServiceType.taxi,
      );
      await _createVehicle(harness, plate: 'ABC124', brand: 'Toyota');
      final renault = await _createVehicle(
        harness,
        plate: 'REN126',
        brand: 'Renault',
      );
      await harness.repository.setActiveVehicle(activeTaxi.id);
      await harness.preferences.setString(
        picoJurisdictionPreferenceKey,
        'co-dc-bogota',
      );

      await _pumpDetail(tester, harness, vehicleId: renault.id);

      expect(find.byKey(const ValueKey('pico-personal-identity')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('pico-personal-calendar')),
        findsOneWidget,
      );
      expect(findPlateNumber(renault.plate), findsOneWidget);
      expect((await harness.repository.getActiveVehicle())?.id, activeTaxi.id);
    });

    testWidgets(
      'Home focused vehicle never promotes to favorite through Conducir',
      (tester) async {
        final activeTaxi = await _createVehicle(
          harness,
          plate: 'TAX129',
          serviceType: VehicleServiceType.taxi,
        );
        await _createVehicle(harness, plate: 'ABC123', brand: 'Toyota');
        await harness.repository.setActiveVehicle(activeTaxi.id);
        await harness.preferences.setString(
          picoJurisdictionPreferenceKey,
          'co-dc-bogota',
        );

        await _pumpFullHomeApp(tester, harness);
        expect(
          (await harness.repository.getActiveVehicle())?.id,
          activeTaxi.id,
        );

        await tester.tap(find.byKey(const ValueKey('tab-drive')));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));

        expect(
          (await harness.repository.getActiveVehicle())?.id,
          activeTaxi.id,
        );
      },
    );

    testWidgets('Summary card routes consistently to Pico detail', (
      tester,
    ) async {
      final vehicle = await _readyHome(harness, plate: 'ABC124');
      await _pumpHomeApp(tester, harness);

      for (final target in [
        'home-status-today',
        'home-summary-status-icon',
        'home-summary-main',
        'home-summary-city',
      ]) {
        await tester.tap(find.byKey(ValueKey(target)));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('pico-personal-identity')), findsOneWidget);
        expect(findPlateNumber(vehicle.plate), findsOneWidget);

        final router = GoRouter.of(
          tester.element(find.byKey(const ValueKey('pico-personal-identity'))),
        );
        router.go('/home');
        await _pumpAsyncHome(tester);
      }
    });

    testWidgets('SOAT card routes consistently', (tester) async {
      final vehicle = await _readyHome(harness, plate: 'ABC124');
      await _pumpHomeApp(tester, harness);

      for (var i = 0; i < 10; i += 1) {
        await tester.tap(find.byKey(const ValueKey('home-status-soat')));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        expect(find.text('module-soat-${vehicle.id}'), findsOneWidget);

        final router = GoRouter.of(
          tester.element(find.text('module-soat-${vehicle.id}')),
        );
        router.go('/home');
        await _pumpAsyncHome(tester);
      }
    });

    testWidgets('RTM card routes consistently', (tester) async {
      final vehicle = await _readyHome(harness, plate: 'ABC124');
      await _pumpHomeApp(tester, harness);

      for (var i = 0; i < 10; i += 1) {
        await tester.tap(find.byKey(const ValueKey('home-status-rtm')));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        expect(find.text('module-tecnomecanica-${vehicle.id}'), findsOneWidget);

        final router = GoRouter.of(
          tester.element(find.text('module-tecnomecanica-${vehicle.id}')),
        );
        router.go('/home');
        await _pumpAsyncHome(tester);
      }
    });
  });

  group('Home V2 notifications and accessibility', () {
    testWidgets('bell opens explicit notification activation sheet', (
      tester,
    ) async {
      await _readyHome(harness, plate: 'ABC124');

      await _pumpHome(tester, harness);
      expect(
        find.byKey(const ValueKey('home-enable-notifications')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('home-notification-bell')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('home-notification-sheet')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('home-enable-notifications')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('notification-sheet-close')),
        findsOneWidget,
      );

      final close = find.byKey(const ValueKey('notification-sheet-close'));
      await tester.ensureVisible(close);
      await tester.tap(close);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('home-notification-sheet')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('home-compact-top-bar')),
        findsOneWidget,
      );
    });

    testWidgets('denied notification permission does not re-prompt', (
      tester,
    ) async {
      await _readyHome(harness, plate: 'ABC124');
      await savePicoAlertPreferences(
        harness.preferences,
        const PicoAlertPreferences(
          enabled: true,
          dayBeforeEnabled: true,
          sameDayEnabled: true,
          dayBeforeMinute: 19 * 60,
          sameDayMinute: 5 * 60,
          permissionRequested: true,
          permissionGranted: false,
        ),
      );

      await _pumpHome(tester, harness);
      await tester.tap(find.byKey(const ValueKey('home-notification-bell')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const ValueKey('home-enable-notifications')),
        findsNothing,
      );
      expect(
        find.textContaining('Permiso de notificaciones desactivado'),
        findsOneWidget,
      );
    });

    testWidgets(
      'granted notification settings remain available in bell sheet',
      (tester) async {
        await _readyHome(harness, plate: 'ABC124');
        await savePicoAlertPreferences(
          harness.preferences,
          const PicoAlertPreferences(
            enabled: true,
            dayBeforeEnabled: true,
            sameDayEnabled: true,
            dayBeforeMinute: 19 * 60,
            sameDayMinute: 5 * 60,
            permissionRequested: true,
            permissionGranted: true,
          ),
        );

        await _pumpHome(tester, harness);
        await tester.tap(find.byKey(const ValueKey('home-notification-bell')));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Recordatorios habilitados'), findsOneWidget);
        expect(find.text('Día anterior'), findsOneWidget);
        expect(find.text('Hora día anterior'), findsOneWidget);
        expect(find.text('19:00'), findsOneWidget);
        expect(find.text('Mismo día'), findsOneWidget);
        expect(find.text('Hora mismo día'), findsOneWidget);
        expect(find.text('05:00'), findsOneWidget);
      },
    );

    testWidgets('alert preference toggle is saved from the bell sheet', (
      tester,
    ) async {
      await _readyHome(harness, plate: 'ABC124');
      await savePicoAlertPreferences(
        harness.preferences,
        const PicoAlertPreferences(
          enabled: true,
          dayBeforeEnabled: true,
          sameDayEnabled: true,
          dayBeforeMinute: 19 * 60,
          sameDayMinute: 5 * 60,
          permissionRequested: true,
          permissionGranted: true,
        ),
      );

      await _pumpHome(tester, harness);
      await tester.tap(find.byKey(const ValueKey('home-notification-bell')));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await tester.ensureVisible(
        find.byKey(const ValueKey('pico-alerts-enabled')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('pico-alerts-enabled')));
      await tester.pump();

      final loaded = await loadPicoAlertPreferences(harness.preferences);
      expect(loaded.enabled, isFalse);
      expect(loaded.permissionRequested, isTrue);
      expect(loaded.permissionGranted, isTrue);
    });

    testWidgets('reduced motion keeps restricted state readable', (
      tester,
    ) async {
      await _readyHome(harness, plate: 'ABC123');

      await _pumpHome(
        tester,
        harness,
        wrap: (child) => MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: child,
        ),
      );

      expect(find.text('Tiene pico y placa hoy'), findsOneWidget);
      expect(find.byIcon(Icons.block_rounded), findsWidgets);
    });
  });

  group('Home V2 viewport QA', () {
    final cases = <({String name, Size size, double textScale})>[
      (name: '360x800', size: Size(360, 800), textScale: 1),
      (name: '390x844', size: Size(390, 844), textScale: 1),
      (name: '412x915', size: Size(412, 915), textScale: 1),
      (name: '390x844 textScale 1.5', size: Size(390, 844), textScale: 1.5),
      (name: '390x844 textScale 2.0', size: Size(390, 844), textScale: 2),
    ];

    for (final viewport in cases) {
      testWidgets('renders without layout exceptions at ${viewport.name}', (
        tester,
      ) async {
        await _readyHome(harness, plate: 'ABC124');

        await _pumpHome(
          tester,
          harness,
          viewportSize: viewport.size,
          textScaleFactor: viewport.textScale,
        );

        expect(find.byKey(const ValueKey('home-brand-lockup')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('home-user-controls-capsule')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('picoradar-avatar-control')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('home-vehicle-carousel')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('home-status-grid')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('home-bottom-banner-slot')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Pico detail continuity', () {
    testWidgets('/pico shows city overview', (tester) async {
      await _readyHome(
        harness,
        plate: 'TAX078',
        serviceType: VehicleServiceType.taxi,
        jurisdictionId: 'co-dc-bogota',
      );

      await _pumpDetail(tester, harness);

      expect(find.byKey(const ValueKey('pico-city-screen')), findsOneWidget);
      expect(find.byKey(const ValueKey('pico-city-screen')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('pico-city-top-controls')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('pico-city-category-segment')),
        findsOneWidget,
      );
      final heroArt = tester.widget<Image>(find.descendant(
        of: find.byKey(const ValueKey('pico-city-hero-art')), matching: find.byType(Image)),
      );
      final heroArtProvider = heroArt.image as ResizeImage;
      expect(
        (heroArtProvider.imageProvider as AssetImage).assetName,
        'assets/vehicles/veh_car_generic_01.webp',
      );
    });

    testWidgets('/pico with vehicleId shows its direct monthly calendar', (tester) async {
      final vehicle = await _readyHome(harness, plate: 'TAX078',
        serviceType: VehicleServiceType.taxi, jurisdictionId: 'co-dc-bogota');
      await _pumpDetail(tester, harness, vehicleId: vehicle.id);
      expect(find.byKey(const ValueKey('pico-personal-identity')), findsOneWidget);
      expect(findPlateNumber(vehicle.plate), findsOneWidget);
      final calendar = find.byKey(const ValueKey('pico-personal-month-calendar'));
      await tester.ensureVisible(calendar);
      await tester.pumpAndSettle();
      expect(find.text('Agosto 2026'), findsOneWidget);
      for (var day = 1; day <= 31; day++) {
        expect(find.byKey(ValueKey('pico-month-day-2026-08-${day.toString().padLeft(2, '0')}')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('pico-month-status-2026-08-28-restricted')), findsOneWidget);
      expect(find.byKey(const ValueKey('pico-personal-calendar-mode')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('pico-month-day-2026-08-28')));
      await tester.pumpAndSettle();
      expect(find.text('Con pico y placa'), findsOneWidget);
      expect(find.text('5:30 a. m. – 9:00 p. m.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('personal Pico month mode renders engine-derived states', (
      tester,
    ) async {
      final vehicle = await _readyHome(
        harness,
        plate: 'ABC123',
        jurisdictionId: 'co-dc-bogota',
      );

      await _pumpDetail(tester, harness, vehicleId: vehicle.id);
      await tester.ensureVisible(
        find.byKey(const ValueKey('pico-personal-month-calendar')),
      );
      await tester.pumpAndSettle();
            await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('pico-personal-calendar')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('pico-personal-month-calendar')),
        findsOneWidget,
      );
      expect(find.text('Agosto 2026'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('pico-month-day-2026-08-01')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('pico-month-status-2026-08-27-restricted')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('pico-month-status-2026-08-28-allowed')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('pico-month-next')));
      await tester.pumpAndSettle();

      expect(find.text('Septiembre 2026'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('pico-month-status-2026-09-01-stale')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('pico-month-previous')));
      await tester.pumpAndSettle();

      expect(find.text('Agosto 2026'), findsOneWidget);
      expect(
        await harness.preferences.getString('pico_calendar_visible_month'),
        isNull,
      );
    });

    testWidgets('personal Pico month date opens local day detail', (
      tester,
    ) async {
      final vehicle = await _readyHome(
        harness,
        plate: 'ABC123',
        jurisdictionId: 'co-dc-bogota',
      );

      await _pumpDetail(tester, harness, vehicleId: vehicle.id);
      await tester.ensureVisible(
        find.byKey(const ValueKey('pico-personal-month-calendar')),
      );
      await tester.pumpAndSettle();
            await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('pico-month-day-2026-08-27')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pico-month-day-2026-08-27')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('pico-month-day-detail-sheet')),
        findsOneWidget,
      );
      final daySheet = find.byKey(
        const ValueKey('pico-month-day-detail-sheet'),
      );
      expect(
        find.descendant(of: daySheet, matching: find.text('Con pico y placa')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: daySheet,
          matching: find.text('6:00 a. m. – 9:00 p. m.'),
        ),
        findsOneWidget,
      );
      expect(
        find.text('Restricción calculada para este vehículo.'),
        findsOneWidget,
      );
    });

    testWidgets('personal Pico month navigation preserves summary and selected vehicle', (tester) async {
      final vehicle = await _readyHome(harness, plate: 'ABC123', jurisdictionId: 'co-dc-bogota');
      await _pumpDetail(tester, harness, vehicleId: vehicle.id);
      final calendar = find.byKey(const ValueKey('pico-personal-month-calendar'));
      await tester.ensureVisible(calendar);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pico-month-next')));
      await tester.pumpAndSettle();
      expect(find.text('Septiembre 2026'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pico-month-previous')));
      await tester.pumpAndSettle();
      expect(find.text('Agosto 2026'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('pico-summary-today')));
      await tester.pumpAndSettle();
      expect(find.text('Tiene pico y placa hoy'), findsOneWidget);
      expect((await harness.repository.getActiveVehicle())?.id, vehicle.id);
      expect(find.byKey(const ValueKey('pico-personal-calendar-mode')), findsNothing);
    });

    testWidgets('personal Pico keeps notifications in Home without duplicate bell', (tester) async {
      final vehicle = await _readyHome(harness, plate: 'ABC124', jurisdictionId: 'co-dc-bogota');
      await _pumpDetail(tester, harness, vehicleId: vehicle.id);
      expect(find.byKey(const ValueKey('pico-notification-bell')), findsNothing);
      expect(find.byKey(const ValueKey('pico-personal-hero-back')).hitTestable(), findsOneWidget);
      expect(find.byKey(const ValueKey('pico-personal-change-city')).hitTestable(), findsOneWidget);
    });

    testWidgets('city week exposes seven days and vehicles in their sheet', (tester) async {
      final vehicle = await _readyHome(harness, plate: 'ABC123', jurisdictionId: 'co-ant-medellin');
      await _pumpDetail(tester, harness);
      for (var day = 0; day < 7; day++) {
        expect(find.byKey(ValueKey('pico-city-week-day-$day')), findsOneWidget);
      }
      await _openCityVehicles(tester);
      expect(find.byKey(ValueKey('pico-city-vehicle-${vehicle.id}')), findsOneWidget);
      expect(find.byKey(const ValueKey('pico-city-vehicles-sheet')), findsOneWidget);
      expect(find.byKey(const ValueKey('pico-city-add-vehicle')), findsOneWidget);
    });

    testWidgets('P04 Medellin shows digit basis, hours and weekly rotation', (tester) async {
      harness.now = DateTime(2026, 8, 31, 12);
      await _readyHome(harness, plate: 'ABC125', jurisdictionId: 'co-ant-medellin');
      await _pumpDetail(tester, harness);
      expect(find.text('5 · 8'), findsWidgets);
      expect(find.textContaining('Último dígito'), findsWidgets);
      expect(find.textContaining('5:00 a. m.'), findsWidgets);
      await tester.ensureVisible(find.byKey(const ValueKey('pico-city-category-motorcycles')));
      await tester.tap(find.byKey(const ValueKey('pico-city-category-motorcycles')));
      await _pumpAsyncHome(tester);
      expect(find.textContaining('Primer número'), findsWidgets);
      expect(find.text('5 · 8'), findsWidgets);
    });

    testWidgets('P04 Medellin taxi fails closed with explicit copy', (tester) async {
      harness.now = DateTime(2026, 8, 31, 12);
      await _readyHome(harness, plate: 'ABC125', jurisdictionId: 'co-ant-medellin');
      await _pumpDetail(tester, harness);
      await tester.tap(find.byKey(const ValueKey('pico-city-category-taxis')));
      await _pumpAsyncHome(tester);
      expect(find.text('Por verificar'), findsWidgets);
      expect(find.text('Sin restricción hoy'), findsNothing);
      await _openCityRules(tester);
      expect(find.textContaining('no disponible'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('P04 Bogota date-parity rules show the current seven-day week', (tester) async {
      harness.now = DateTime(2026, 8, 28, 12);
      await _readyHome(harness, plate: 'ABC125', jurisdictionId: 'co-dc-bogota');
      await _pumpDetail(tester, harness);
      expect(find.textContaining('Paridad de fecha'), findsWidgets);
      for (var index = 0; index < 7; index++) {
        final cell = find.byKey(ValueKey('pico-city-week-day-$index'));
        expect(cell, findsOneWidget);
        final expected = index.isEven ? '6' : '3';
        expect(find.descendant(of: cell, matching: find.text(expected)), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('pico-city-week-day-7')), findsNothing);
    });

    testWidgets('city info icon and official source CTA are functional', (tester) async {
      await _readyHome(harness, plate: 'ABC123', jurisdictionId: 'co-dc-bogota');
      await _pumpDetail(tester, harness);
      await tester.tap(find.byKey(const ValueKey('pico-city-info')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('pico-city-info-sheet')), findsOneWidget);
      Navigator.of(tester.element(find.byKey(const ValueKey('pico-city-info-sheet')))).pop();
      await tester.pumpAndSettle();
      await _openCityRules(tester);
      expect(find.byKey(const ValueKey('pico-city-rule-source-sheet')), findsOneWidget);
      expect(find.textContaining('alcaldiabogota.gov.co'), findsWidgets);
    });

    testWidgets('city selector searches national catalog and runtime states', (
      tester,
    ) async {
      await _readyHome(
        harness,
        plate: 'ABC123',
        jurisdictionId: 'co-ant-medellin',
      );

      await _pumpDetail(tester, harness);
      await tester.tap(find.byKey(const ValueKey('pico-city-change')));
      await _pumpAsyncHome(tester);

      expect(find.byKey(const ValueKey('pico-city-search')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('pico-city-section-available')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('pico-city-section-upcoming')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('pico-city-status-co-ant-medellin')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('pico-city-status-co-dc-bogota')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('pico-city-option-co-ant-medellin')),
          matching: find.text('Carros, Motos · Cobertura vigente'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('pico-city-option-co-dc-bogota')),
          matching: find.text('Carros, Motos, Taxis · Cobertura vigente'),
        ),
        findsOneWidget,
      );
      expect(find.text('Próximamente'), findsWidgets);
      await _waitForPicoCityOption(tester, 'co-vac-cali');
      expect(
        find.byKey(const ValueKey('pico-city-option-co-vac-cali')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('pico-city-search')),
        'cali',
      );
      await _pumpAsyncHome(tester);

      expect(
        find.byKey(const ValueKey('pico-city-option-co-ant-medellin')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('pico-city-option-co-dc-bogota')),
        findsNothing,
      );
      final caliTile = tester.widget<ListTile>(
        find.byKey(const ValueKey('pico-city-option-co-vac-cali')),
      );
      expect(caliTile.enabled, isFalse);
      expect(find.text('Cali'), findsOneWidget);
      expect(
        find.text('Valle del Cauca · Cobertura en preparación'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('pico-city-search')),
        'pere',
      );
      await _pumpAsyncHome(tester);
      expect(
        find.byKey(const ValueKey('pico-city-option-co-ris-pereira')),
        findsOneWidget,
      );
      expect(find.text('Risaralda · Cobertura en preparación'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('pico-city-search')),
        'arme',
      );
      await _pumpAsyncHome(tester);
      expect(
        find.byKey(const ValueKey('pico-city-option-co-qui-armenia')),
        findsOneWidget,
      );
      expect(find.text('Quindío · Cobertura en preparación'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('pico-city-search')),
        'bogota',
      );
      await _pumpAsyncHome(tester);
      await _waitForPicoCityOption(tester, 'co-dc-bogota');
      expect(
        find.byKey(const ValueKey('pico-city-option-co-vac-cali')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('pico-city-option-co-dc-bogota')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('pico-city-option-co-dc-bogota')),
      );
      await _pumpAsyncHome(tester);

      expect(find.text('Bogotá'), findsWidgets);
      expect(
        await harness.preferences.getString(picoJurisdictionPreferenceKey),
        'co-ant-medellin',
      );
    });

    testWidgets(
      'personal Pico selector applies temporary jurisdiction without mutation',
      (tester) async {
        final vehicle = await _readyHome(
          harness,
          plate: 'ABC123',
          jurisdictionId: 'co-ant-medellin',
        );

        await _pumpDetail(tester, harness, vehicleId: vehicle.id);
        await tester.tap(
          find.byKey(const ValueKey('pico-personal-change-city')),
        );
        await _pumpAsyncHome(tester);

        expect(find.text('Ciudad para este vehículo'), findsOneWidget);
        expect(find.byKey(const ValueKey('pico-city-search')), findsOneWidget);

        await tester.enterText(
          find.byKey(const ValueKey('pico-city-search')),
          'bogota',
        );
        await _pumpAsyncHome(tester);
        await _waitForPicoCityOption(tester, 'co-dc-bogota');
        await tester.tap(
          find.byKey(const ValueKey('pico-city-option-co-dc-bogota')),
        );
        await _pumpAsyncHome(tester);

        expect(find.byKey(const ValueKey('pico-personal-identity')), findsOneWidget);
        expect(find.text('Bogotá'), findsAtLeastNWidgets(1));
        expect(
          await harness.preferences.getString(picoJurisdictionPreferenceKey),
          'co-ant-medellin',
        );
        expect((await harness.repository.getActiveVehicle())?.id, vehicle.id);
        expect(
          (await harness.repository.getVehicle(vehicle.id))?.registrationCity,
          'Bogota',
        );
      },
    );

    testWidgets(
      'transient jurisdiction does not mutate global city until adopted',
      (tester) async {
        await _readyHome(
          harness,
          plate: 'ABC123',
          jurisdictionId: 'co-ant-medellin',
        );

        await _pumpDetail(tester, harness);
        await tester.tap(find.byKey(const ValueKey('pico-city-change')));
        await _pumpAsyncHome(tester);
        await _waitForPicoCityOption(tester, 'co-dc-bogota');
        await tester.tap(
          find.byKey(const ValueKey('pico-city-option-co-dc-bogota')),
        );
        await _pumpAsyncHome(tester);

        expect(find.text('Bogotá'), findsWidgets);
        expect(
          await harness.preferences.getString(picoJurisdictionPreferenceKey),
          'co-ant-medellin',
        );

        await tester.tap(find.byKey(const ValueKey('pico-city-change')));
        await _pumpAsyncHome(tester);
        await tester.tap(find.byKey(const ValueKey('pico-city-adopt')));
        await _pumpAsyncHome(tester);

        expect(
          await harness.preferences.getString(picoJurisdictionPreferenceKey),
          'co-dc-bogota',
        );
        expect(
          await harness.preferences.getString(locationModePreferenceKey),
          'manual',
        );
      },
    );

    testWidgets('vehicle shortcut preserves transient city in personal route', (
      tester,
    ) async {
      final vehicle = await _readyHome(
        harness,
        plate: 'ABC123',
        jurisdictionId: 'co-ant-medellin',
      );

      await _pumpPicoApp(tester, harness);
      await tester.tap(find.byKey(const ValueKey('pico-city-change')));
      await _pumpAsyncHome(tester);
      await _waitForPicoCityOption(tester, 'co-dc-bogota');
      await tester.tap(
        find.byKey(const ValueKey('pico-city-option-co-dc-bogota')),
      );
      await _pumpAsyncHome(tester);
      await _openCityVehicles(tester);
      await _pumpAsyncHome(tester);
      await tester.tap(find.byKey(ValueKey('pico-city-vehicle-${vehicle.id}')));
      await _pumpAsyncHome(tester);

      expect(find.byKey(const ValueKey('pico-personal-identity')), findsOneWidget);
      expect(find.text('Bogotá'), findsAtLeastNWidgets(1));
      expect(
        await harness.preferences.getString(picoJurisdictionPreferenceKey),
        'co-ant-medellin',
      );
    });

    testWidgets('P03 Apps city Pico stays inside the Apps shell', (
      tester,
    ) async {
      await _readyHome(
        harness,
        plate: 'ABC123',
        jurisdictionId: 'co-dc-bogota',
      );

      await _pumpFullHomeApp(tester, harness);
      await _openShellPicoFromApps(tester);

      expect(find.byKey(const ValueKey('pico-city-screen')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('app-bottom-navigation')),
        findsOneWidget,
      );
      expect(_selectedBottomNavLabels(tester), contains('Apps'));

      await tester.tap(find.byKey(const ValueKey('tab-apps')));
      await _pumpAsyncHome(tester);
      expect(
        find.byKey(const ValueKey('apps-launcher-overlay')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('tab-apps')));
      await _pumpAsyncHome(tester);
      expect(find.byKey(const ValueKey('apps-launcher-overlay')), findsNothing);
      expect(find.byKey(const ValueKey('pico-city-screen')), findsOneWidget);
    });

    testWidgets('P03 personal Pico preserves Home origin and Back', (
      tester,
    ) async {
      await _readyHome(
        harness,
        plate: 'ABC123',
        jurisdictionId: 'co-dc-bogota',
      );

      await _pumpFullHomeApp(tester, harness);
      await tester.ensureVisible(
        find.byKey(const ValueKey('home-status-today')),
      );
      await _pumpAsyncHome(tester);
      await tester.tap(find.byKey(const ValueKey('home-status-today')));
      await _pumpPicoShell(tester);

      expect(find.byKey(const ValueKey('pico-personal-identity')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('app-bottom-navigation')),
        findsOneWidget,
      );
      expect(_selectedBottomNavLabels(tester), contains('Inicio'));

      await tester.binding.handlePopRoute();
      await _pumpAsyncHome(tester);

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('pico-personal-identity')), findsNothing);
    });

    testWidgets('P03 Pico shell exits through root bottom destinations', (
      tester,
    ) async {
      await _readyHome(
        harness,
        plate: 'ABC123',
        jurisdictionId: 'co-dc-bogota',
      );

      await _pumpFullHomeApp(tester, harness);
      await _goToShellPico(tester);
      await tester.tap(find.byKey(const ValueKey('tab-home')));
      await _pumpAsyncHome(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('pico-city-screen')), findsNothing);

      await _goToShellPico(tester);
      await tester.tap(find.byKey(const ValueKey('tab-garage')));
      await _pumpAsyncHome(tester);
      expect(
        find.byKey(const ValueKey('garage-compact-top-bar')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('pico-city-screen')), findsNothing);

      await _goToShellPico(tester);
      await tester.tap(find.byKey(const ValueKey('tab-trip')));
      await _pumpAsyncHome(tester);
      expect(find.byKey(const ValueKey('trip-screen')), findsOneWidget);
      expect(find.byKey(const ValueKey('pico-city-screen')), findsNothing);

      await _goToShellPico(tester);
      await tester.tap(find.byKey(const ValueKey('tab-drive')));
      await _pumpAsyncHome(tester);
      expect(find.byKey(const ValueKey('start-driving')), findsOneWidget);
      expect(find.byKey(const ValueKey('pico-city-screen')), findsNothing);
    });

    testWidgets(
      'P03 city vehicle shortcut preserves Apps origin and transient city',
      (tester) async {
        final vehicle = await _readyHome(
          harness,
          plate: 'ABC123',
          jurisdictionId: 'co-ant-medellin',
        );

        await _pumpFullHomeApp(tester, harness);
        await _openShellPicoFromApps(tester);
        await tester.tap(find.byKey(const ValueKey('pico-city-change')));
        await _pumpAsyncHome(tester);
        await _waitForPicoCityOption(tester, 'co-dc-bogota');
        await tester.tap(
          find.byKey(const ValueKey('pico-city-option-co-dc-bogota')),
        );
        await _pumpAsyncHome(tester);
        await _openCityVehicles(tester);
        await _pumpAsyncHome(tester);

        await tester.tap(
          find.byKey(ValueKey('pico-city-vehicle-${vehicle.id}')),
        );
        await _pumpPersonalPico(tester);

        expect(find.byKey(const ValueKey('pico-personal-identity')), findsOneWidget);
        expect(_selectedBottomNavLabels(tester), contains('Apps'));
        expect(find.text('Bogotá'), findsAtLeastNWidgets(1));
        expect(
          await harness.preferences.getString(picoJurisdictionPreferenceKey),
          'co-ant-medellin',
        );

        await tester.binding.handlePopRoute();
        await _pumpAsyncHome(tester);

        expect(find.byKey(const ValueKey('pico-city-screen')), findsOneWidget);
        expect(_selectedBottomNavLabels(tester), contains('Apps'));
      },
    );

    testWidgets('pico detail does not show allowed after staleAfter', (
      tester,
    ) async {
      harness.now = DateTime(2026, 9, 1, 7);
      await _readyHome(
        harness,
        plate: 'ABC123',
        jurisdictionId: 'co-dc-bogota',
      );

      await _pumpDetail(
        tester,
        harness,
        vehicleId: (await harness.repository.getActiveVehicle())?.id,
      );

      final verdict = tester.widget<Text>(
        find.byKey(const ValueKey('pico-summary-main')),
      );
      expect(verdict.data, 'Datos vencidos');
      expect(find.text('Sin pico y placa hoy'), findsNothing);
    });

    testWidgets(
      'Bogota plate is evaluated by effective Medellin city, not registration',
      (tester) async {
        harness.now = DateTime(2026, 9, 10, 0, 2);
        final vehicle = await _readyHome(
          harness,
          plate: 'BOG126',
          jurisdictionId: 'co-ant-medellin',
        );

        await _pumpHome(tester, harness);

        final vehicleCard = find.byKey(
          ValueKey('home-vehicle-card-${vehicle.id}'),
        );
        expect(find.text('Medellín'), findsWidgets);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('home-status-today')),
            matching: find.text('Tiene pico y placa hoy'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('home-status-today')),
            matching: find.byKey(const ValueKey('home-summary-main')),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: vehicleCard,
            matching: find.text('Puede circular'),
          ),
          findsNothing,
        );

        final homeVerdict = tester.widget<Text>(
          find.byKey(const ValueKey('home-summary-main')),
        );
        expect(
          homeVerdict.data!.replaceAll('\u00a0', ' '),
          '5:00 a. m. – 8:00 p. m.',
        );
        expect(find.text('No puede circular'), findsNothing);
        final homeWindows = tester.widget<Text>(
          find.byKey(const ValueKey('home-summary-main')),
        );
        expect(
          homeWindows.data!.replaceAll('\u00a0', ' '),
          '5:00 a. m. – 8:00 p. m.',
        );
        expect(
          tester
              .widget<Icon>(
                find.byKey(ValueKey('home-vehicle-status-${vehicle.id}')),
              )
              .color,
          AppColors.red,
        );
        await _pumpDetail(tester, harness, vehicleId: vehicle.id);

        expect(find.text('Medellín'), findsAtLeastNWidgets(1));
        final verdict = tester.widget<Text>(
          find.byKey(const ValueKey('pico-summary-main')),
        );
        expect(verdict.data, '5:00\u00a0a.\u00a0m. – 8:00\u00a0p.\u00a0m.');
        expect(find.text('No puede circular'), findsNothing);
        expect(find.text('5:00 a. m. – 8:00 p. m.'), findsWidgets);
      },
    );

    testWidgets('invalid explicit vehicle falls back to active without crash', (
      tester,
    ) async {
      final active = await _readyHome(
        harness,
        plate: 'ABC124',
        jurisdictionId: 'co-dc-bogota',
      );

      await _pumpDetail(tester, harness, vehicleId: 'missing');

      expect(find.byKey(const ValueKey('pico-personal-identity')), findsOneWidget);
      expect(findPlateNumber(active.plate), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _pumpHome(
  WidgetTester tester,
  TestAppHarness harness, {
  Size viewportSize = _defaultViewportSize,
  double? textScaleFactor,
  Widget? bottomNavigationBar,
  Widget Function(Widget child)? wrap,
  DeviceLocationGateway? deviceLocationGateway,
  DateTime Function()? homeGpsClock,
  DateTime Function()? currentInstantClock,
  RestrictionDayEvaluation? homeEvaluation,
  HomeBannerCampaign? homeBanner,
}) async {
  await _pump(
    tester,
    harness,
    Scaffold(
      body: const HomeScreen(),
      bottomNavigationBar: bottomNavigationBar,
    ),
    viewportSize: viewportSize,
    textScaleFactor: textScaleFactor,
    wrap: wrap,
    deviceLocationGateway: deviceLocationGateway,
    homeGpsClock: homeGpsClock,
    currentInstantClock: currentInstantClock,
    homeEvaluation: homeEvaluation,
    homeBanner: homeBanner,
  );
}

Future<void> _pumpDetail(
  WidgetTester tester,
  TestAppHarness harness, {
  String? vehicleId,
  String? jurisdictionId,
}) async {
  await _pump(
    tester,
    harness,
    PicoDetailScreen(vehicleId: vehicleId, jurisdictionId: jurisdictionId),
  );
}

Future<void> _pumpHomeApp(WidgetTester tester, TestAppHarness harness) async {
  await _installWidgetChannelMock(tester, harness);
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/pico',
        builder: (context, state) => PicoDetailScreen(
          vehicleId: state.uri.queryParameters['vehicleId'],
          jurisdictionId: state.uri.queryParameters['jurisdictionId'],
        ),
      ),
      GoRoute(
        path: '/home/pico',
        builder: (context, state) => PicoDetailScreen(
          vehicleId: state.uri.queryParameters['vehicleId'],
          jurisdictionId: state.uri.queryParameters['jurisdictionId'],
        ),
      ),
      GoRoute(
        path: '/garage/pico',
        builder: (context, state) => PicoDetailScreen(
          vehicleId: state.uri.queryParameters['vehicleId'],
          jurisdictionId: state.uri.queryParameters['jurisdictionId'],
        ),
      ),
      GoRoute(
        path: '/apps/pico',
        builder: (context, state) => PicoDetailScreen(
          vehicleId: state.uri.queryParameters['vehicleId'],
          jurisdictionId: state.uri.queryParameters['jurisdictionId'],
        ),
      ),
      GoRoute(
        path: '/garage/vehicle/:id',
        builder: (context, state) =>
            VehicleDetailScreen(vehicleId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/drive', builder: (context, state) => const Text('drive')),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const Text('settings-route'),
      ),
      GoRoute(
        path: '/apps/module/:id',
        builder: (context, state) => Text(
          'module-${state.pathParameters['id']}-${state.uri.queryParameters['vehicleId']}',
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    _providerScope(
      harness,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
      ),
    ),
  );
  await _pumpAsyncHome(tester);
}

Future<void> _pumpPicoApp(WidgetTester tester, TestAppHarness harness) async {
  await _installWidgetChannelMock(tester, harness);
  final router = GoRouter(
    initialLocation: '/pico',
    routes: [
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/garage',
        builder: (context, state) => const Text('garage'),
      ),
      GoRoute(
        path: '/onboarding/vehicle',
        builder: (context, state) => const Text('onboarding'),
      ),
      GoRoute(
        path: '/pico',
        builder: (context, state) => PicoDetailScreen(
          vehicleId: state.uri.queryParameters['vehicleId'],
          jurisdictionId: state.uri.queryParameters['jurisdictionId'],
        ),
      ),
      GoRoute(
        path: '/apps/pico',
        builder: (context, state) => PicoDetailScreen(
          vehicleId: state.uri.queryParameters['vehicleId'],
          jurisdictionId: state.uri.queryParameters['jurisdictionId'],
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    _providerScope(
      harness,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
      ),
    ),
  );
  await _pumpAsyncHome(tester);
}

Future<void> _openShellPicoFromApps(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('tab-apps')));
  await _pumpAsyncHome(tester);
  await tester.tap(find.byKey(const ValueKey('app-module-pico')));
  await _pumpPicoShell(tester);
}

Future<void> _goToShellPico(WidgetTester tester) async {
  final routeContent = [
    find.byKey(const ValueKey('pico-city-screen')),
    find.byKey(const ValueKey('pico-personal-identity')),
    find.byType(HomeScreen),
    find.byType(Scaffold),
  ].firstWhere((finder) => finder.evaluate().isNotEmpty);
  GoRouter.of(routeContent.evaluate().first).go('/apps/pico');
  await _pumpPicoShell(tester);
}

Future<void> _pumpPicoShell(WidgetTester tester) async {
  for (var i = 0; i < 20; i += 1) {
    await tester.pump(const Duration(milliseconds: 300));
    if (find.byKey(const ValueKey('pico-city-screen')).evaluate().isNotEmpty ||
        find.byKey(const ValueKey('pico-personal-identity')).evaluate().isNotEmpty) {
      return;
    }
  }
}

Future<void> _pumpPersonalPico(WidgetTester tester) async {
  for (var i = 0; i < 20; i += 1) {
    await tester.pump(const Duration(milliseconds: 300));
    if (find.byKey(const ValueKey('pico-personal-identity')).evaluate().isNotEmpty) {
      return;
    }
  }
}

List<String> _selectedBottomNavLabels(WidgetTester tester) {
  return tester
      .widgetList<Semantics>(find.byType(Semantics))
      .where((widget) => widget.properties.selected == true)
      .map((widget) => widget.properties.label)
      .whereType<String>()
      .toList();
}

Future<void> _openSummaryAndExpectPico(
  WidgetTester tester,
  VehicleProfile vehicle,
) async {
  await tester.tap(find.byKey(const ValueKey('home-status-today')));
  await _pumpPersonalPico(tester);
  expect(find.byKey(const ValueKey('pico-personal-identity')), findsOneWidget);
  expect(findPlateNumber(vehicle.plate), findsAtLeastNWidgets(1));
}

Future<void> _goHome(WidgetTester tester) async {
  final routeContent = [
    find.byKey(const ValueKey('pico-personal-identity')),
    find.byKey(const ValueKey('pico-city-screen')),
    find.textContaining('module-'),
    find.byType(HomeScreen),
    find.byType(Scaffold),
  ].firstWhere((finder) => finder.evaluate().isNotEmpty);
  final router = GoRouter.of(routeContent.evaluate().first);
  router.go('/home');
  await _pumpAsyncHome(tester);
}

Future<void> _pumpFullHomeApp(
  WidgetTester tester,
  TestAppHarness harness, {
  DateTime Function()? appClockNow,
  RestrictionStore? restrictionStore,
}) async {
  await _installWidgetChannelMock(tester, harness);
  await tester.pumpWidget(
    _providerScope(
      harness,
      appClockNow: appClockNow,
      restrictionStore: restrictionStore,
      child: const PicoRadarApp(),
    ),
  );
  await _pumpAsyncHome(tester);
}

Future<void> _pump(
  WidgetTester tester,
  TestAppHarness harness,
  Widget child, {
  Size viewportSize = _defaultViewportSize,
  double? textScaleFactor,
  Widget Function(Widget child)? wrap,
  DeviceLocationGateway? deviceLocationGateway,
  DateTime Function()? homeGpsClock,
  DateTime Function()? currentInstantClock,
  RestrictionDayEvaluation? homeEvaluation,
  HomeBannerCampaign? homeBanner,
}) async {
  await _installWidgetChannelMock(tester, harness, viewportSize: viewportSize);
  if (textScaleFactor != null) {
    tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  final app = _providerScope(
    harness,
    child: MaterialApp(home: child),
    deviceLocationGateway: deviceLocationGateway,
    homeGpsClock: homeGpsClock,
    currentInstantClock: currentInstantClock,
    homeEvaluation: homeEvaluation,
    homeBanner: homeBanner,
  );
  await tester.pumpWidget(wrap == null ? app : wrap(app));
  await _pumpAsyncHome(tester);
}

Widget _providerScope(
  TestAppHarness harness, {
  required Widget child,
  DateTime Function()? appClockNow,
  RestrictionStore? restrictionStore,
  DeviceLocationGateway? deviceLocationGateway,
  DateTime Function()? homeGpsClock,
  DateTime Function()? currentInstantClock,
  RestrictionDayEvaluation? homeEvaluation,
  HomeBannerCampaign? homeBanner,
}) {
  return ProviderScope(
    overrides: [
      if (homeBanner != null)
        homeBannerCampaignProvider.overrideWith((ref) async => homeBanner),
      if (homeEvaluation != null)
        homeVehicleSnapshotsProvider.overrideWith(
          (ref, request) async => [
            for (final vehicle in request.vehicles)
              HomeVehicleSnapshot(vehicle: vehicle, today: homeEvaluation),
          ],
        ),
      appDatabaseProvider.overrideWithValue(harness.database),
      appPreferencesProvider.overrideWithValue(harness.preferences),
      tripMunicipalityCatalogProvider.overrideWithValue(
        AsyncValue.data(TestAppHarness.tripCatalog),
      ),
      bundledRestrictionsProvider.overrideWith((ref) async {}),
      restrictionJurisdictionsProvider.overrideWith(
        (ref) async => _jurisdictions,
      ),
      restrictionStoreProvider.overrideWithValue(
        restrictionStore ??
            _FakeRestrictionStore(harness.database, harness.now),
      ),
      picoJurisdictionCatalogProvider.overrideWith(
        (ref) async => PicoJurisdictionCatalog.fromJson(
          jsonDecode(File(picoJurisdictionCatalogAssetPath).readAsStringSync())
              as Map<String, Object?>,
        ),
      ),
      picoNotificationSchedulerProvider.overrideWithValue(
        _FakePicoNotificationScheduler(),
      ),
      if (appClockNow != null)
        appClockNowProvider.overrideWithValue(appClockNow)
      else ...[
        bogotaNowProvider.overrideWith((ref) => harness.now),
        currentInstantProvider.overrideWith(
          (ref) => (currentInstantClock ?? () => harness.now.toUtc())().toUtc(),
        ),
      ],
      homeGpsClockProvider.overrideWithValue(
        homeGpsClock ?? () => harness.now.toUtc(),
      ),
      startupReadinessProvider.overrideWith(
        (ref) async => const StartupReadiness(
          imageAssets: [],
          vehicleCount: 0,
          selectedJurisdictionId: null,
        ),
      ),
      deviceLocationGatewayProvider.overrideWithValue(
        deviceLocationGateway ?? _FakeDeviceLocationGateway(),
      ),
      avatarCatalogProvider.overrideWith(
        (ref) async => AvatarCatalog.fromJson(
          jsonDecode(File(avatarCatalogAssetPath).readAsStringSync())
              as Map<String, Object?>,
        ),
      ),
      vehicleVisualCatalogProvider.overrideWith(
        (ref) async => VehicleVisualCatalog.fromJson(
          jsonDecode(File(vehicleCatalogAssetPath).readAsStringSync())
              as Map<String, Object?>,
        ),
      ),
    ],
    child: child,
  );
}

void _expectNoEllipsisInCard(
  WidgetTester tester,
  ValueKey<String> cardKey,
  List<String> labels,
) {
  final card = find.byKey(cardKey);
  for (final label in labels) {
    final labelFinder = find.descendant(of: card, matching: find.text(label));
    expect(labelFinder, findsWidgets, reason: label);
    final widgets = tester.widgetList<Text>(labelFinder);
    expect(
      widgets.any((widget) => widget.overflow == TextOverflow.ellipsis),
      isFalse,
      reason: label,
    );
  }
}

Future<void> _installWidgetChannelMock(
  WidgetTester tester,
  TestAppHarness harness, {
  Size viewportSize = _defaultViewportSize,
}) async {
  _configureMobileViewport(tester, viewportSize);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('co.picoradar.app/widget'),
        (_) async => null,
      );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await harness.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('co.picoradar.app/widget'),
          null,
        );
  });
}

const _defaultViewportSize = Size(390, 844);

void _configureMobileViewport(WidgetTester tester, Size viewportSize) {
  tester.view.physicalSize = viewportSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pumpAsyncHome(WidgetTester tester) async {
  for (var i = 0; i < 6; i += 1) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _waitForPicoCityOption(WidgetTester tester, String id) async {
  final finder = find.byKey(ValueKey('pico-city-option-$id'));
  for (var i = 0; i < 20; i += 1) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  expect(finder, findsOneWidget);
}

Future<VehicleProfile> _readyHome(
  TestAppHarness harness, {
  required String plate,
  String jurisdictionId = 'co-ant-medellin',
  VehicleKind kind = VehicleKind.car,
  VehicleServiceType serviceType = VehicleServiceType.private,
  String? nickname,
  String? registrationCity = 'Bogota',
  String? brand,
  String? model,
}) async {
  final vehicle = await _createVehicle(
    harness,
    plate: plate,
    kind: kind,
    serviceType: serviceType,
    nickname: nickname,
    registrationCity: registrationCity,
    brand: brand,
    model: model,
  );
  await harness.repository.setActiveVehicle(vehicle.id);
  await harness.preferences.setString(
    picoJurisdictionPreferenceKey,
    jurisdictionId,
  );
  return vehicle;
}

Future<VehicleProfile> _createVehicle(
  TestAppHarness harness, {
  required String plate,
  VehicleKind kind = VehicleKind.car,
  VehicleServiceType serviceType = VehicleServiceType.private,
  String? nickname,
  String? registrationCity = 'Bogota',
  String? brand,
  String? model,
  int? year,
}) async {
  return harness.repository.createVehicle(
    plate: plate,
    kind: kind,
    serviceType: serviceType,
    nickname: nickname,
    registrationCity: registrationCity,
    brand: brand,
    model: model,
    year: year,
  );
}

Future<void> _setVehicleCreatedAt(
  TestAppHarness harness,
  String vehicleId,
  DateTime createdAt,
) async {
  await (harness.database.update(
    harness.database.vehicles,
  )..where((row) => row.id.equals(vehicleId))).write(
    VehiclesCompanion(createdAt: Value(createdAt), updatedAt: Value(createdAt)),
  );
}

HomeVehicleSnapshot _snapshot(String id, RestrictionDayStatus status) {
  return HomeVehicleSnapshot(
    vehicle: VehicleProfile(
      id: id,
      plate: id.toUpperCase().padRight(6, '1').substring(0, 6),
      kind: VehicleKind.car,
      serviceType: VehicleServiceType.private,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    today: RestrictionDayEvaluation(
      status: status,
      effectiveWindows: status == RestrictionDayStatus.restricted
          ? const [RestrictionDayWindow(startMinute: 300, endMinute: 1200)]
          : const [],
    ),
  );
}

const _jurisdictions = [
  RestrictionJurisdiction(id: 'co-dc-bogota', name: 'Bogotá'),
  RestrictionJurisdiction(id: 'co-ant-medellin', name: 'Medellín'),
  RestrictionJurisdiction(
    id: 'co-san-bucaramanga-metro',
    name: 'Área metropolitana de Bucaramanga',
  ),
];

const _medellinWindows = [
  RestrictionTimeWindow(startMinute: 300, endMinute: 1200),
];

class _FakeRestrictionStore extends RestrictionStore {
  _FakeRestrictionStore(super.database, this.now);

  final DateTime now;
  Completer<void>? pendingLoad;
  int loadCalls = 0;

  @override
  Future<RestrictionRuleSet> loadCoverage(
    String jurisdictionId,
    VehicleKind vehicleKind,
    VehicleServiceType serviceType,
    DateTime now,
  ) async {
    loadCalls += 1;
    final pending = pendingLoad;
    if (pending != null) {
      await pending.future;
    }
    if (jurisdictionId == 'co-ant-medellin' &&
        serviceType == VehicleServiceType.taxi) {
      return const RestrictionRuleSet(
        coverageKnown: false,
        dataIsStale: false,
        rules: [],
      );
    }

    final staleAfter = jurisdictionId == 'co-ant-medellin'
        ? DateTime.utc(2027, 1, 1, 5)
        : DateTime.utc(2026, 9, 1, 5);
    final stale = jurisdictionId == 'co-ant-medellin'
        ? this.now.isAfter(DateTime(2026, 12, 31, 23, 59))
        : this.now.isAfter(DateTime(2026, 8, 31, 23, 59));
    if (jurisdictionId == 'co-ant-medellin') {
      final digitPosition = vehicleKind == VehicleKind.motorcycle
          ? RestrictionDigitPosition.firstNumeric
          : RestrictionDigitPosition.lastNumeric;
      return RestrictionRuleSet(
        coverageKnown: true,
        dataIsStale: stale,
        staleAfter: staleAfter,
        rules: [
          _rule(
            id: 'medellin-h2-monday',
            jurisdictionId: jurisdictionId,
            vehicleKinds: {vehicleKind},
            serviceTypes: {serviceType},
            weekdays: {DateTime.monday},
            digitPosition: digitPosition,
            digits: {5, 8},
            timeWindows: _medellinWindows,
          ),
          _rule(
            id: 'medellin-h2-tuesday',
            jurisdictionId: jurisdictionId,
            vehicleKinds: {vehicleKind},
            serviceTypes: {serviceType},
            weekdays: {DateTime.tuesday},
            digitPosition: digitPosition,
            digits: {1, 4},
            timeWindows: _medellinWindows,
          ),
          _rule(
            id: 'medellin-h2-wednesday',
            jurisdictionId: jurisdictionId,
            vehicleKinds: {vehicleKind},
            serviceTypes: {serviceType},
            weekdays: {DateTime.wednesday},
            digitPosition: digitPosition,
            digits: {0, 2},
            timeWindows: _medellinWindows,
          ),
          _rule(
            id: 'medellin-h2-thursday',
            jurisdictionId: jurisdictionId,
            vehicleKinds: {vehicleKind},
            serviceTypes: {serviceType},
            weekdays: {DateTime.thursday},
            digitPosition: digitPosition,
            digits: {3, 6},
            timeWindows: _medellinWindows,
          ),
          _rule(
            id: 'medellin-h2-friday',
            jurisdictionId: jurisdictionId,
            vehicleKinds: {vehicleKind},
            serviceTypes: {serviceType},
            weekdays: {DateTime.friday},
            digitPosition: digitPosition,
            digits: {7, 9},
            timeWindows: _medellinWindows,
          ),
        ],
        verifiedAt: DateTime(2026, 8, 1),
        sourceUrls: const ['https://www.medellin.gov.co/source'],
      );
    }

    return RestrictionRuleSet(
      coverageKnown: true,
      dataIsStale: stale,
      staleAfter: staleAfter,
      rules: [
        _rule(
          id: 'bogota-private-odd-date',
          jurisdictionId: jurisdictionId,
          vehicleKinds: {VehicleKind.car},
          serviceTypes: {VehicleServiceType.private},
          weekdays: null,
          dateParity: RestrictionDateParity.odd,
          digits: {3},
          appliesOnHolidays: false,
        ),
        _rule(
          id: 'bogota-private-even-date',
          jurisdictionId: jurisdictionId,
          vehicleKinds: {VehicleKind.car},
          serviceTypes: {VehicleServiceType.private},
          weekdays: null,
          dateParity: RestrictionDateParity.even,
          digits: {6},
          appliesOnHolidays: false,
        ),
        _rule(
          id: 'bogota-taxi-thursday',
          jurisdictionId: jurisdictionId,
          vehicleKinds: {VehicleKind.car},
          serviceTypes: {VehicleServiceType.taxi},
          weekdays: {DateTime.thursday},
          digits: {5, 6},
          timeWindows: const [
            RestrictionTimeWindow(startMinute: 330, endMinute: 1260),
          ],
        ),
        _rule(
          id: 'bogota-taxi-friday',
          jurisdictionId: jurisdictionId,
          vehicleKinds: {VehicleKind.car},
          serviceTypes: {VehicleServiceType.taxi},
          weekdays: {DateTime.friday},
          digits: {7, 8},
          timeWindows: const [
            RestrictionTimeWindow(startMinute: 330, endMinute: 1260),
          ],
        ),
      ],
      verifiedAt: DateTime(2026, 8, 1),
      sourceUrls: const ['https://bogota.gov.co/source'],
    );
  }
}

RestrictionRule _rule({
  required String id,
  required String jurisdictionId,
  required Set<VehicleKind> vehicleKinds,
  required Set<VehicleServiceType> serviceTypes,
  required Set<int>? weekdays,
  required Set<int> digits,
  RestrictionDateParity? dateParity,
  RestrictionDigitPosition digitPosition = RestrictionDigitPosition.lastNumeric,
  List<RestrictionTimeWindow> timeWindows = const [
    RestrictionTimeWindow(startMinute: 360, endMinute: 1260),
  ],
  bool appliesOnHolidays = true,
}) {
  return RestrictionRule(
    id: id,
    jurisdictionId: jurisdictionId,
    priority: 100,
    effect: RestrictionEffect.restrict,
    validFrom: DateTime(2026, 8),
    validUntil: DateTime(2026, 12, 31, 23, 59, 59),
    vehicleKinds: vehicleKinds,
    serviceTypes: serviceTypes,
    weekdays: weekdays,
    dateParity: dateParity,
    digitPosition: digitPosition,
    digits: digits,
    timeWindows: timeWindows,
    appliesOnHolidays: appliesOnHolidays,
  );
}

class _FakePicoNotificationScheduler extends PicoNotificationScheduler {
  @override
  Future<void> initialize({void Function(String route)? onRoute}) async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool?> areNotificationsEnabled() async => true;

  @override
  Future<void> reschedule(List<PicoNotificationPlan> plans) async {}

  @override
  Future<void> cancelPicoNotifications() async {}

  @override
  Future<void> rescheduleObligationNotifications(
    List<ObligationNotificationPlan> plans,
  ) async {}

  @override
  Future<void> cancelObligationNotifications() async {}
}

Color? _satelliteColor(WidgetTester tester) {
  return tester
      .widget<Icon>(
        find.byKey(const ValueKey('home-location-satellite-status')),
      )
      .color;
}

class _FakeDeviceLocationGateway implements DeviceLocationGateway {
  bool serviceEnabled = true;
  DeviceLocationPermission permission = DeviceLocationPermission.granted;
  DeviceLocationPermission? permissionAfterRequest;
  DeviceLocationResult? positionResult;
  DeviceLocationPoint point = const DeviceLocationPoint(
    latitude: 6.2442,
    longitude: -75.5812,
    accuracyMeters: 60,
  );
  int checkPermissionCalls = 0;
  int requestPermissionCalls = 0;
  int positionCalls = 0;
  int openAppSettingsCalls = 0;
  int openLocationSettingsCalls = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<DeviceLocationPermission> checkPermission() async {
    checkPermissionCalls += 1;
    return permission;
  }

  @override
  Future<DeviceLocationPermission> requestPermission() async {
    requestPermissionCalls += 1;
    permission = permissionAfterRequest ?? permission;
    return permission;
  }

  @override
  Future<DeviceLocationResult> getCurrentPosition() async {
    positionCalls += 1;
    return positionResult ?? DeviceLocationSuccess(point);
  }

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCalls += 1;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    openLocationSettingsCalls += 1;
    return true;
  }
}

class _ControlledDeviceLocationGateway implements DeviceLocationGateway {
  final serviceChecks = <Completer<bool>>[];
  final permissionChecks = <Completer<DeviceLocationPermission>>[];
  int requestPermissionCalls = 0;

  @override
  Future<bool> isLocationServiceEnabled() {
    final result = Completer<bool>();
    serviceChecks.add(result);
    return result.future;
  }

  @override
  Future<DeviceLocationPermission> checkPermission() {
    final result = Completer<DeviceLocationPermission>();
    permissionChecks.add(result);
    return result.future;
  }

  @override
  Future<DeviceLocationPermission> requestPermission() async {
    requestPermissionCalls += 1;
    return DeviceLocationPermission.denied;
  }

  @override
  Future<DeviceLocationResult> getCurrentPosition() async {
    throw StateError('Position must not be requested by a status probe.');
  }

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}
Future<void> _openCityVehicles(WidgetTester tester) async {
  final action = find.byKey(const ValueKey('pico-city-vehicles-open'));
  await tester.ensureVisible(action);
  await tester.pumpAndSettle();
  await tester.tap(action);
  await _pumpAsyncHome(tester);
}
Future<void> _openCityRules(WidgetTester tester) async {
  final action = find.byKey(const ValueKey('pico-city-rule-open'));
  await tester.ensureVisible(action);
  await tester.pumpAndSettle();
  await tester.tap(action);
  await tester.pumpAndSettle();
}
