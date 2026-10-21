import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:picoradar/app/app.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/router/app_router.dart';
import 'package:picoradar/app/startup/startup_gate.dart';
import 'package:picoradar/features/pico_placa/data/pico_preferences.dart';
import 'package:picoradar/features/pico_placa/platform/pico_notifications.dart';
import 'package:picoradar/features/vehicle_status/data/private_vehicle_document_store.dart';

import '../../test_app_harness.dart';

void main() {
  for (final disposeBeforePermission in [false, true]) {
    testWidgets(
      'resume initialization recovery refreshes permission safely: dispose=$disposeBeforePermission',
      (tester) async {
        final scheduler = _RecoveringScheduler();
        final preferences = _PermissionPreferences();
        await preferences.setBool(picoNotificationPermissionRequestedKey, true);
        await preferences.setBool(picoNotificationPermissionGrantedKey, false);
        final router = GoRouter(
          routes: [GoRoute(path: '/', builder: (_, _) => const Text('Ready'))],
        );
        final container = ProviderContainer(
          overrides: [
            appRouterProvider.overrideWithValue(router),
            currentInstantProvider.overrideWithValue(DateTime.utc(2026, 9, 10)),
            appPreferencesProvider.overrideWithValue(preferences),
            picoNotificationSchedulerProvider.overrideWithValue(scheduler),
            privateVehicleDocumentStoreProvider.overrideWithValue(
              _DocumentStore(),
            ),
            startupReadinessProvider.overrideWith(
              (ref) async => const StartupReadiness(
                imageAssets: [],
                vehicleCount: 0,
                selectedJurisdictionId: null,
              ),
            ),
            picoWidgetSyncProvider.overrideWith((ref) async {}),
            picoNotificationSyncProvider.overrideWith((ref) async {}),
            obligationNotificationSyncProvider.overrideWith((ref) async {}),
            maintenanceNotificationSyncProvider.overrideWith((ref) async {}),
            datasetSyncRunProvider.overrideWith((ref) async => null),
          ],
        );
        try {
          expect(
            (await container.read(picoAlertPreferencesProvider.future))
                .permissionGranted,
            isFalse,
          );
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const PicoRadarApp(),
            ),
          );
          for (var i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
          expect(find.text('Ready'), findsOneWidget);
          expect(scheduler.initializations, 1);
          expect(scheduler.permissionChecks, 0);

          // The first attempt fails only after the first usable content frame.
          scheduler.firstInitialization.completeError(
            PlatformException(code: 'private-unlogged'),
          );
          await tester.pump();
          final reported = tester.takeException();
          expect(reported, isA<FlutterError>());
          expect(reported.toString(), isNot(contains('private-unlogged')));
          expect(scheduler.permissionChecks, 0);
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pump();
          expect(scheduler.initializations, 2);
          expect(scheduler.permissionChecks, 1);
          if (disposeBeforePermission) {
            await tester.pumpWidget(const SizedBox.shrink());
          }
          preferences.boolWrites.clear();
          scheduler.permission.complete(true);
          await tester.pump();
          expect(
            (await loadPicoAlertPreferences(preferences)).permissionGranted,
            !disposeBeforePermission,
          );
          expect(
            (await container.read(picoAlertPreferencesProvider.future))
                .permissionGranted,
            !disposeBeforePermission,
          );
          expect(scheduler.permissionRequests, 0);
          expect(scheduler.permissionChecks, 1);
          expect(tester.takeException(), isNull);
          expect(
            preferences.boolWrites,
            disposeBeforePermission
                ? isEmpty
                : [picoNotificationPermissionGrantedKey],
          );
          if (!disposeBeforePermission) {
            scheduler.currentPermission = false;
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.paused,
            );
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.resumed,
            );
            await tester.pump();
            expect(scheduler.permissionChecks, 2);
            expect(
              (await container.read(picoAlertPreferencesProvider.future))
                  .permissionGranted,
              isFalse,
            );
            scheduler.currentPermission = true;
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.paused,
            );
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.resumed,
            );
            await tester.pump();
            expect(scheduler.permissionChecks, 3);
            expect(
              (await loadPicoAlertPreferences(preferences)).permissionGranted,
              isTrue,
            );
            expect(scheduler.permissionRequests, 0);
          }
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
          router.dispose();
        }
      },
    );
  }

  for (final failFirst in [false, true]) {
    testWidgets(
      'app starts routing before content, sync after paint and retries safely: fail=$failFirst',
      (tester) async {
        final readiness = Completer<StartupReadiness>();
        final scheduler = _Scheduler(failFirst: failFirst);
        var painted = false;
        final starts = <String>[];
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) =>
                  CustomPaint(painter: _PaintProbe(() => painted = true)),
            ),
          ],
        );
        final container = ProviderContainer(
          overrides: [
            appRouterProvider.overrideWithValue(router),
            currentInstantProvider.overrideWithValue(
              DateTime.utc(2026, 9, 10, 12),
            ),
            appPreferencesProvider.overrideWithValue(MemoryPreferences()),
            picoNotificationSchedulerProvider.overrideWithValue(scheduler),
            startupReadinessProvider.overrideWith((ref) => readiness.future),
            picoWidgetSyncProvider.overrideWith((ref) async {
              expect(painted, isTrue);
              starts.add('widget');
            }),
            picoNotificationSyncProvider.overrideWith((ref) async {
              expect(painted, isTrue);
              starts.add('pico');
            }),
            obligationNotificationSyncProvider.overrideWith((ref) async {
              expect(painted, isTrue);
              starts.add('obligations');
            }),
            maintenanceNotificationSyncProvider.overrideWith((ref) async {}),
            datasetSyncRunProvider.overrideWith((ref) async {
              expect(painted, isTrue);
              starts.add('dataset');
              return null;
            }),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(router.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const PicoRadarApp(),
          ),
        );
        await tester.pump();
        expect(scheduler.initializations, 1);
        if (failFirst) {
          final reported = tester.takeException();
          expect(reported, isA<FlutterError>());
          expect(reported.toString(), isNot(contains('private-unlogged')));
        }
        expect(starts, isEmpty);
        readiness.complete(
          const StartupReadiness(
            imageAssets: [],
            vehicleCount: 0,
            selectedJurisdictionId: null,
          ),
        );
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(
          starts,
          unorderedEquals(['widget', 'pico', 'obligations', 'dataset']),
        );
        expect(scheduler.initializations, failFirst ? 2 : 1);
        await tester.pumpWidget(const SizedBox.shrink());
        scheduler.initialized.complete();
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _Scheduler extends PicoNotificationScheduler {
  _Scheduler({required this.failFirst});
  final bool failFirst;
  final initialized = Completer<void>();
  int initializations = 0;

  @override
  Future<void> initialize({void Function(String route)? onRoute}) {
    initializations++;
    if (failFirst && initializations == 1) {
      return Future.error(PlatformException(code: 'private-unlogged'));
    }
    return initialized.future;
  }
}

class _RecoveringScheduler extends PicoNotificationScheduler {
  final firstInitialization = Completer<void>();
  final permission = Completer<bool?>();
  int initializations = 0;
  int permissionChecks = 0;
  int permissionRequests = 0;
  bool? currentPermission;

  @override
  Future<void> initialize({void Function(String route)? onRoute}) {
    initializations++;
    return initializations == 1 ? firstInitialization.future : Future.value();
  }

  @override
  Future<bool?> areNotificationsEnabled() {
    permissionChecks++;
    return permissionChecks == 1
        ? permission.future
        : Future.value(currentPermission);
  }

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return true;
  }
}

class _DocumentStore extends PrivateVehicleDocumentStore {
  @override
  Future<void> purgeViewerCache({
    PrivateVehicleDocumentMetadata? metadata,
  }) async {}
}

class _PermissionPreferences extends MemoryPreferences {
  final boolWrites = <String>[];
  @override
  Future<void> setBool(String key, bool value) {
    boolWrites.add(key);
    return super.setBool(key, value);
  }
}

class _PaintProbe extends CustomPainter {
  _PaintProbe(this.onPaint);
  final VoidCallback onPaint;

  @override
  void paint(Canvas canvas, Size size) => onPaint();

  @override
  bool shouldRepaint(_PaintProbe oldDelegate) => false;
}
