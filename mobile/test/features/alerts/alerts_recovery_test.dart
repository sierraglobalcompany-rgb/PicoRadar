import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/features/alerts/application/alert_center.dart';
import 'package:picoradar/features/alerts/application/save_alert_settings.dart';
import 'package:picoradar/features/alerts/data/alert_settings.dart';
import 'package:picoradar/features/alerts/platform/alert_alarm_gateway.dart';
import 'package:picoradar/features/alerts/presentation/alerts_screen.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/data/pico_preferences.dart';
import 'package:picoradar/features/pico_placa/platform/pico_notifications.dart';
import 'package:picoradar/features/vehicle_status/data/vehicle_obligation_store.dart';
import 'package:picoradar/features/vehicle_status/domain/vehicle_obligation.dart';

const _legacy = PicoAlertPreferences(
  enabled: true,
  dayBeforeEnabled: true,
  sameDayEnabled: true,
  dayBeforeMinute: 1140,
  sameDayMinute: 300,
  permissionRequested: true,
  permissionGranted: true,
);
final _car = VehicleProfile(
  id: 'v1',
  plate: 'DEM123',
  kind: VehicleKind.car,
  serviceType: VehicleServiceType.private,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  test('explicit off remains off before the obligation exists', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final obligations = VehicleObligationStore(db);
    await _seed(db, obligations);
    await obligations.delete('v1', VehicleObligationType.soat);
    await db.writeAlertSettings('v1', 'soat', '{"enabled":false}');
    final container = _centerContainer(db);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    final data = await container.read(alertCenterProvider.future);
    final soat = data.rows.singleWhere((r) => r.category == AlertCategory.soat);
    expect(soat.settings.enabled, isFalse);
    expect(soat.dueDate, isNull);
    expect(soat.scheduled, isFalse);
  });

  test(
    'delayed save survives disposal of the entire provider container',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final obligations = VehicleObligationStore(db);
      await _seed(db, obligations);
      final store = _DelayedStore(db);
      final container = ProviderContainer(
        overrides: [alertSettingsStoreProvider.overrideWithValue(store)],
      );
      final save = saveAlertSettings(
        container,
        vehicleId: 'v1',
        category: AlertCategory.soat,
        settings: const AlertSettings(enabled: false),
      );
      container.dispose();
      store.release.complete();
      await save;
      expect(
        (await obligations.get(
          'v1',
          VehicleObligationType.soat,
        ))!.reminderEnabled,
        isFalse,
      );
    },
  );

  test('scheduled failure is observed before sync and the next refresh can recover', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await _seed(db, VehicleObligationStore(db));
    var latched = true;
    var observations = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AlertAlarmGateway.channel, (call) async {
          expect(call.method, 'status');
          expect(call.arguments, isNull);
          observations++;
          final code = latched ? 'PLAYBACK_FAILED' : null;
          latched = false;
          return {'testState': 'idle', 'failureCode': code};
        });
    final container = _centerContainer(db, nativeStatus: true);
    addTearDown(() async {
      container.dispose();
      await db.close();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AlertAlarmGateway.channel, null);
    });
    final failed = await container.read(alertCenterProvider.future);
    expect(observations, 1);
    expect(failed.schedulingFailed, isTrue);
    expect(
      failed.alarmFailureMessage,
      'No se pudo reproducir la alarma. Revisa el sonido y vuelve a probar.',
    );
    container.invalidate(alertCenterProvider);
    final recovered = await container.read(alertCenterProvider.future);
    expect(observations, 2);
    expect(recovered.schedulingFailed, isFalse);
    expect(recovered.alarmFailureMessage, isNull);
  });

  testWidgets('consumed failure while backgrounded remains visible on resume', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    await tester.runAsync(() => _seed(db, VehicleObligationStore(db)));
    final gateway = _ConsumedFailureGateway();
    final container = _centerContainer(db, gateway: gateway);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      container.dispose();
      await db.close();
    });
    await tester.runAsync(() => container.read(alertCenterProvider.future));
    await _pump(tester, container);
    await tester.scrollUntilVisible(find.text('Vista previa y prueba'), 200);
    await tester.tap(find.text('Vista previa y prueba'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Probar sonido de alarma'));
    await tester.tap(find.text('Probar sonido de alarma'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(gateway.observations, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    gateway.state = AlarmTestState.failed;
    gateway.pendingStatus.complete(
      const AlarmStatus(
        testState: AlarmTestState.failed,
        failureCode: 'PLAYBACK_FAILED',
      ),
    );
    await tester.pump();
    expect(find.byType(SnackBar), findsNothing);
    expect(gateway.observations, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    for (var frame = 0; frame < 50; frame++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
      if (gateway.observations >= 3 &&
          !container.read(alertCenterProvider).isLoading) {
        break;
      }
    }
    await tester.pumpAndSettle();
    final recovered = container.read(alertCenterProvider).requireValue;
    const message =
        'No se pudo iniciar la alarma. Revisa los permisos y vuelve a probar.';
    expect(gateway.observations, 3);
    expect(recovered.alarmFailureMessage, message);
    expect(recovered.schedulingFailed, isTrue);
    expect(recovered.rows.every((row) => !row.scheduled), isTrue);
    await tester.scrollUntilVisible(find.text(message), -200);
    expect(find.text(message).hitTestable(), findsOneWidget);
    expect(find.textContaining('Programada:'), findsNothing);
    expect(find.text('Sonido de alarma iniciado.'), findsNothing);
    await tester.scrollUntilVisible(find.text('Vista previa y prueba'), 200);
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Vista previa y prueba'),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  for (final unmount in [false, true]) {
    testWidgets('save refreshes owner and schedules after unmount=$unmount', (
      tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());
      final store = _DelayedStore(db);
      final obligations = VehicleObligationStore(db);
      await tester.runAsync(() => _seed(db, obligations));
      final projected = <String, bool>{};
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          alertSettingsStoreProvider.overrideWithValue(store),
          picoAlertPreferencesProvider.overrideWith((ref) async => _legacy),
          picoNotificationSyncProvider.overrideWith((ref) async {
            projected['pico'] =
                (await store.load('v1', AlertCategory.soat))?.enabled ?? true;
          }),
          obligationNotificationSyncProvider.overrideWith((ref) async {
            projected['obligations'] = (await obligations.get(
              'v1',
              VehicleObligationType.soat,
            ))!.reminderEnabled;
          }),
          alertCenterProvider.overrideWith((ref) async => _screenData()),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      final owner = vehicleObligationProvider((
        'v1',
        VehicleObligationType.soat,
      ));
      final other = vehicleObligationProvider((
        'v2',
        VehicleObligationType.soat,
      ));
      await tester.runAsync(() async {
        expect((await container.read(owner.future))!.reminderEnabled, isTrue);
        await container.read(vehicleObligationsProvider('v1').future);
        await container.read(other.future);
        await container.read(picoNotificationSyncProvider.future);
        await container.read(obligationNotificationSyncProvider.future);
      });
      await _pump(tester, container);
      await _toggle(tester);
      expect(store.started, isTrue);
      if (unmount) await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        store.release.complete();
        await store.finished.future;
        await Future<void>.delayed(Duration.zero);
        await container.read(picoNotificationSyncProvider.future);
        await container.read(obligationNotificationSyncProvider.future);
        expect(projected, {'pico': false, 'obligations': false});
        expect((await container.read(owner.future))!.reminderEnabled, isFalse);
        expect(
          (await container.read(vehicleObligationsProvider('v1').future))
              .single
              .reminderEnabled,
          isFalse,
        );
        expect((await container.read(other.future))!.reminderEnabled, isTrue);
        // The date editor consumes this cached provider when it reopens.
        final current = (await container.read(owner.future))!;
        await obligations.upsert(
          vehicleId: 'v1',
          type: VehicleObligationType.soat,
          dueDate: DateTime(2027, 2, 20),
          reminderEnabled: current.reminderEnabled,
        );
        expect(
          (await obligations.get(
            'v1',
            VehicleObligationType.soat,
          ))!.reminderEnabled,
          isFalse,
        );
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  for (final failure in [
    'initialize',
    'permission',
    'capabilities',
    'unknown',
  ]) {
    testWidgets(
      '$failure preserves controls and opens OS settings then recovers',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        final obligations = VehicleObligationStore(db);
        await tester.runAsync(() => _seed(db, obligations));
        final scheduler = _PermissionScheduler(failure);
        final gateway = _PermissionGateway(failure);
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vehicleListProvider.overrideWith((ref) async => [_car]),
            picoAlertPreferencesProvider.overrideWith((ref) async => _legacy),
            picoNotificationSchedulerProvider.overrideWithValue(scheduler),
            alarmGatewayProvider.overrideWithValue(gateway),
            picoNotificationSyncProvider.overrideWith((ref) async {}),
            obligationNotificationSyncProvider.overrideWith((ref) async {}),
            restrictionJurisdictionsProvider.overrideWith((ref) async => []),
            selectedPicoJurisdictionIdProvider.overrideWith(
              (ref) async => null,
            ),
            bogotaNowProvider.overrideWithValue(DateTime(2027, 1, 19)),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await db.close();
        });
        await _pump(tester, container);
        await tester.runAsync(() async {
          // AsyncError is allowed to settle so the assertions describe lost UI,
          // not just an unhandled future from the test itself.
          try {
            await container.read(alertCenterProvider.future);
          } catch (_) {}
        });
        await tester.pumpAndSettle();
        expect(find.text('Permisos sin confirmar'), findsOneWidget);
        expect(find.byKey(const ValueKey('alerts-v1-soat')), findsOneWidget);
        expect(find.textContaining('Programada:'), findsNothing);
        final settings = find.text('Ajustes');
        expect(
          tester
              .getSize(
                find.ancestor(of: settings, matching: find.byType(TextButton)),
              )
              .height,
          greaterThanOrEqualTo(48),
        );
        await tester.tap(settings);
        await tester.pumpAndSettle();
        expect(gateway.settingsOpened, 1);
        final result = container.read(alertCenterProvider).requireValue;
        expect(result.schedulingFailed, isTrue);
        expect(result.rows.every((row) => !row.scheduled), isTrue);
        scheduler.failure = null;
        gateway.failure = null;
        await tester.tap(find.byTooltip('Actualizar'));
        await tester.pump();
        await tester.runAsync(
          () => container
              .read(alertCenterProvider.future)
              .timeout(const Duration(seconds: 5)),
        );
        await tester.pumpAndSettle();
        expect(find.text('Notificaciones permitidas'), findsOneWidget);
        expect(find.text('Permisos sin confirmar'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

ProviderContainer _centerContainer(
  AppDatabase db, {
  bool nativeStatus = false,
  AlertAlarmGateway? gateway,
}) => ProviderContainer(
  overrides: [
    appDatabaseProvider.overrideWithValue(db),
    vehicleListProvider.overrideWith((ref) async => [_car]),
    picoAlertPreferencesProvider.overrideWith((ref) async => _legacy),
    picoNotificationSchedulerProvider.overrideWithValue(
      _PermissionScheduler(null),
    ),
    alarmGatewayProvider.overrideWithValue(
      gateway ?? _PermissionGateway(null, nativeStatus: nativeStatus),
    ),
    picoNotificationSyncProvider.overrideWith((ref) async {}),
    obligationNotificationSyncProvider.overrideWith((ref) async {}),
    restrictionJurisdictionsProvider.overrideWith((ref) async => []),
    selectedPicoJurisdictionIdProvider.overrideWith((ref) async => null),
    bogotaNowProvider.overrideWithValue(DateTime(2027, 1, 19)),
  ],
);

Future<void> _seed(AppDatabase db, VehicleObligationStore obligations) async {
  for (final id in ['v1', 'v2']) {
    await db
        .into(db.vehicles)
        .insert(
          VehiclesCompanion.insert(
            id: id,
            plate: id == 'v1' ? 'DEM123' : 'DEM456',
          ),
        );
    await obligations.upsert(
      vehicleId: id,
      type: VehicleObligationType.soat,
      dueDate: DateTime(2027, 1, 20),
    );
  }
}

AlertCenterData _screenData() => AlertCenterData(
  permission: true,
  capabilities: const AlarmCapabilities(),
  rows: [
    AlertCenterRow(
      vehicle: _car,
      category: AlertCategory.soat,
      settings: const AlertSettings(),
      scheduled: false,
      dueDate: DateTime(2027, 1, 20),
    ),
  ],
);

Future<void> _pump(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: AlertsScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _toggle(WidgetTester tester) async {
  final tile = find.byKey(const ValueKey('alerts-v1-soat'));
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(SwitchListTile, 'Recordatorio'));
  await tester.pump();
}

class _DelayedStore extends AlertSettingsStore {
  _DelayedStore(super.database);
  final release = Completer<void>();
  final finished = Completer<void>();
  bool started = false;
  @override
  Future<void> save(
    String vehicleId,
    AlertCategory category,
    AlertSettings settings,
  ) async {
    started = true;
    await release.future;
    await super.save(vehicleId, category, settings);
    finished.complete();
  }
}

class _PermissionScheduler extends PicoNotificationScheduler {
  _PermissionScheduler(this.failure);
  String? failure;
  @override
  Future<void> initialize({void Function(String route)? onRoute}) async {
    if (failure == 'initialize') throw PlatformException(code: 'unavailable');
  }

  @override
  Future<bool?> areNotificationsEnabled() async {
    if (failure == 'permission') throw PlatformException(code: 'unavailable');
    return failure == 'unknown' ? null : true;
  }

  @override
  Future<Set<int>> pendingIds() async => {};
}

class _PermissionGateway extends AlertAlarmGateway {
  _PermissionGateway(this.failure, {this.nativeStatus = false});
  String? failure;
  final bool nativeStatus;
  int settingsOpened = 0;
  @override
  Future<AlarmStatus> status() async => nativeStatus
      ? await super.status()
      : const AlarmStatus(testState: AlarmTestState.idle);
  @override
  Future<AlarmCapabilities> capabilities() async {
    if (failure == 'capabilities') throw PlatformException(code: 'unavailable');
    return const AlarmCapabilities(
      supported: true,
      notifications: true,
      exact: true,
    );
  }

  @override
  Future<void> openNotificationSettings() async {
    settingsOpened++;
  }
}

class _ConsumedFailureGateway extends _PermissionGateway {
  _ConsumedFailureGateway() : super(null);
  final pendingStatus = Completer<AlarmStatus>();
  var state = AlarmTestState.idle;
  var observations = 0;

  @override
  Future<void> test() async {
    state = AlarmTestState.starting;
  }

  @override
  Future<AlarmStatus> status() async {
    observations++;
    if (state == AlarmTestState.starting) return pendingStatus.future;
    // The prior observation consumed the code, but native failed is sticky.
    return AlarmStatus(testState: state);
  }
}
