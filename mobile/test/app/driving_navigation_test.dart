import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:picoradar/app/shell/app_shell.dart';
import 'package:picoradar/features/driving/application/driving_controller.dart';
import 'package:picoradar/features/driving/data/driving_preferences.dart';

void main() {
  testWidgets('internal tab change cannot hide an active driving session', (
    tester,
  ) async {
    final harness = await _pumpShell(tester, initialLocation: '/drive');

    await tester.tap(find.byKey(const ValueKey('tab-trip')));
    await tester.pumpAndSettle();

    expect(find.text('Finalizar conducción'), findsOneWidget);
    expect(find.byKey(const ValueKey('drive-root')), findsOneWidget);
    expect(harness.controller.stopCalls, 0);

    await tester.tap(find.text('Seguir conduciendo'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('drive-root')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tab-trip')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finalizar y salir'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('trip-root')), findsOneWidget);
    expect(harness.controller.stopCalls, 1);
    expect(harness.controller.state.requireValue.isActive, isFalse);
  });

  testWidgets('back confirms active driving then returns to Home', (
    tester,
  ) async {
    final harness = await _pumpShell(tester, initialLocation: '/drive');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Finalizar conducción'), findsOneWidget);
    expect(find.byKey(const ValueKey('drive-root')), findsOneWidget);

    await tester.tap(find.text('Finalizar y salir'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-root')), findsOneWidget);
    expect(harness.controller.stopCalls, 1);
  });

  testWidgets('back from an inactive non-Home root returns to Home', (
    tester,
  ) async {
    await _pumpShell(tester, initialLocation: '/trip', drivingActive: false);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-root')), findsOneWidget);
  });
}

Future<_ShellHarness> _pumpShell(
  WidgetTester tester, {
  required String initialLocation,
  bool drivingActive = true,
}) async {
  final controller = _ShellDrivingController(drivingActive);
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          for (final tab in AppTab.values)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: tab.route.path,
                  builder: (context, state) => Scaffold(
                    body: Center(
                      child: Text(
                        '${tab.label} root',
                        key: ValueKey('${tab.name}-root'),
                      ),
                    ),
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
      overrides: [drivingControllerProvider.overrideWith(() => controller)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return _ShellHarness(controller);
}

class _ShellHarness {
  const _ShellHarness(this.controller);

  final _ShellDrivingController controller;
}

class _ShellDrivingController extends DrivingController {
  _ShellDrivingController(this.active);

  final bool active;
  int stopCalls = 0;

  @override
  Future<DrivingState> build() async => DrivingState(
    status: active ? DrivingSessionStatus.active : DrivingSessionStatus.idle,
    preferences: defaultDrivingPreferences,
    cameraCount: 0,
    cameraSpeedKnownCount: 0,
  );

  @override
  Future<void> stop() async {
    stopCalls += 1;
    state = AsyncData(
      state.requireValue.copyWith(
        status: DrivingSessionStatus.idle,
        clearCurrentPoint: true,
      ),
    );
  }
}
