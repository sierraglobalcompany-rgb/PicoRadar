import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/shell/app_shell.dart';

void main() {
  testWidgets('Apps and navigation animation do not repaint static route', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final painter = _PaintCounter();
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppShell(navigationShell: shell),
          branches: [
            for (final tab in AppTab.values)
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: tab.route.path,
                    builder: (context, state) => CustomPaint(
                      painter: painter,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vehicleListProvider.overrideWith((ref) async => []),
          activeVehicleProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    final initialPaints = painter.paints;
    expect(initialPaints, greaterThan(0));
    await tester.tap(find.byKey(const ValueKey('tab-apps')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('apps-launcher-panel')), findsOneWidget);
    expect(painter.paints, initialPaints);
    await tester.tap(find.byKey(const ValueKey('tab-apps')));
    await tester.pumpAndSettle();
    expect(painter.paints, initialPaints);
    expect(tester.takeException(), isNull);
  });
}

class _PaintCounter extends CustomPainter {
  int paints = 0;

  @override
  void paint(Canvas canvas, Size size) {
    paints++;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _PaintCounter oldDelegate) => false;
}
