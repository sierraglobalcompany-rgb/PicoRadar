import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app.dart';
import 'package:picoradar/app/router/app_router.dart';
import 'package:picoradar/features/alerts/application/alert_center.dart';
import 'package:picoradar/features/alerts/data/alert_settings.dart';
import 'package:picoradar/features/alerts/platform/alert_alarm_gateway.dart';
import 'package:picoradar/features/alerts/presentation/alerts_screen.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';

import '../../test_app_harness.dart';
import '../home/presentation/v01b_test_font.dart';

void main() {
  setUpAll(() async {
    await loadV01bTestFont();
    final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
    final icons = FontLoader('MaterialIcons');
    icons.addFont(
      File('${artifacts.path}/material_fonts/MaterialIcons-Regular.otf')
          .readAsBytes()
          .then(ByteData.sublistView),
    );
    await icons.load();
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
        'alerts real shell ${size.width}x${size.height} text $scale',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final harness = TestAppHarness();
          addTearDown(harness.dispose);
          final car = VehicleProfile(
            id: 'demo',
            plate: 'DEM123',
            kind: VehicleKind.car,
            serviceType: VehicleServiceType.private,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          );
          final data = AlertCenterData(
            permission: true,
            capabilities: const AlarmCapabilities(supported: true),
            rows: [
              for (final type in AlertCategory.values)
                AlertCenterRow(
                  vehicle: car,
                  category: type,
                  settings: const AlertSettings(),
                  scheduled: false,
                  dueDate: type == AlertCategory.pico
                      ? null
                      : DateTime(2027, 1, 20),
                ),
            ],
          );
          await harness.pump(
            tester,
            childOverride: ProviderScope(
              overrides: [
                alertCenterProvider.overrideWith((ref) async => data),
              ],
              child: const PicoRadarApp(),
            ),
            wrap: (child) => MediaQuery(
              data: MediaQueryData(
                size: size,
                padding: const EdgeInsets.only(top: 24, bottom: 24),
                textScaler: TextScaler.linear(scale),
              ),
              child: child,
            ),
          );
          final context = tester.element(find.byType(PicoRadarApp));
          final router = ProviderScope.containerOf(context)
              .read(appRouterProvider);
          router.go('/home/alerts');
          await tester.pumpAndSettle();
          expect(find.byType(AlertsScreen), findsOneWidget);
          expect(find.text('Alertas y recordatorios'), findsOneWidget);
          expect(find.byKey(const ValueKey('tab-apps')), findsOneWidget);
          final first = find.byKey(const ValueKey('alerts-demo-pico'));
          await tester.tap(first);
          await tester.pumpAndSettle();
          expect(find.text('Recordatorio'), findsWidgets);
          expect(tester.takeException(), isNull);
          await tester.tapAt(tester.getTopLeft(first) + const Offset(80, 28));
          await tester.pumpAndSettle();
          expect(find.text('Recordatorio'), findsNothing);
          expect(find.byType(SnackBar), findsNothing);
          if (size == const Size(390, 844) &&
              scale == 1 &&
              Platform.environment['PICORADAR_ALERT_CAPTURE'] != null) {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byType(RepaintBoundary).first,
            );
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              File(Platform.environment['PICORADAR_ALERT_CAPTURE']!)
                  .writeAsBytesSync(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.scrollUntilVisible(
            find.text('Vista previa y prueba'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(
            find.text('Vista previa y prueba').hitTestable(),
            findsOneWidget,
          );
          await tester.tap(find.text('Vista previa y prueba'));
          await tester.pumpAndSettle();
          expect(find.text('DEM123'), findsWidgets);
          expect(find.text('Probar notificación'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
