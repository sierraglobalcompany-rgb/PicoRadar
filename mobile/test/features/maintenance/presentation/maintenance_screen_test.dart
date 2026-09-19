import 'dart:async';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/theme/app_theme.dart';
import 'package:picoradar/core/database/app_database.dart'
    hide MaintenanceRecord;
import 'package:picoradar/core/storage/app_preferences.dart';
import 'package:picoradar/features/maintenance/data/maintenance_record.dart';
import 'package:picoradar/features/maintenance/data/maintenance_repository.dart';
import 'package:picoradar/features/maintenance/presentation/maintenance_screen.dart';
import 'package:picoradar/features/location/application/location_controller.dart';
import 'package:picoradar/features/location/platform/device_location_gateway.dart';
import 'package:picoradar/features/onboarding/data/registration_city_catalog.dart';
import 'package:picoradar/features/vehicle_status/platform/external_launcher.dart';

import '../../services/presentation/v01b_tools_test_font.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadV01bToolsTestFont);
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('MaintenanceScreen', () {
    late AppDatabase database;
    late MaintenanceRepository repository;
    var nextId = 0;

    setUp(() async {
      nextId = 0;
      database = AppDatabase(NativeDatabase.memory());
      repository = MaintenanceRepository(
        database: database,
        idGenerator: () {
          nextId += 1;
          return 'maintenance-$nextId';
        },
      );
      await database
          .into(database.vehicles)
          .insert(VehiclesCompanion.insert(id: 'vehicle-1', plate: 'ABC123'));
    });

    tearDown(() async {
      await database.close();
    });

    for (final size in [
      const Size(360, 800),
      const Size(390, 844),
      const Size(412, 915),
    ]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets(
          'V01B S06 complete maintenance values remain readable $size/$scale',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = size;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            await repository.create(
              vehicleId: 'vehicle-1',
              serviceDate: DateTime(2026, 9, 5),
              type: 'Aceite',
              description: 'Cambio de aceite y filtros',
              odometer: 145000,
              costCents: 18000000,
              nextServiceDate: DateTime(2027, 12, 31),
              nextOdometer: 150000,
            );
            await _pump(
              tester,
              database,
              repository,
              theme: buildPicoRadarTheme(),
            );
            for (final value in [
              '145.000 km',
              '\$180.000',
              'Próximo: 31 DIC 2027',
              'Próximo: 150.000 km',
            ]) {
              final label = find.text(value);
              await tester.ensureVisible(label);
              await tester.pumpAndSettle();
              final paragraph = tester.renderObject<RenderParagraph>(label);
              final fullText = TextPainter(
                text: paragraph.text,
                textDirection: paragraph.textDirection,
                textScaler: paragraph.textScaler,
              )..layout(maxWidth: paragraph.size.width);
              expect(paragraph.didExceedMaxLines, isFalse, reason: value);
              expect(
                fullText.height,
                lessThanOrEqualTo(paragraph.size.height + 0.1),
                reason:
                    '$value must paint completely, not clip inside its chip',
              );
              fullText.dispose();
              expect(tester.takeException(), isNull);
            }
          },
        );
      }
    }

    testWidgets('shows visible title and empty state', (tester) async {
      await _pump(tester, database, repository);

      expect(find.text('Talleres'), findsOneWidget);
      expect(find.byKey(const ValueKey('maintenance-empty')), findsOneWidget);
      expect(find.text('Sin registros todavía'), findsOneWidget);
    });

    testWidgets(
      'selects another vehicle without changing the garage favorite',
      (tester) async {
        await database
            .into(database.vehicles)
            .insert(VehiclesCompanion.insert(id: 'vehicle-2', plate: 'XYZ987'));
        await repository.create(
          vehicleId: 'vehicle-2',
          serviceDate: DateTime(2026, 9, 10),
          type: 'Frenos',
          description: 'Pastillas delanteras',
        );
        await _pump(tester, database, repository);

        await tester.tap(
          find.byKey(const ValueKey('maintenance-vehicle-selector')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('XYZ987').last);
        await tester.pumpAndSettle();

        expect(find.text('Frenos'), findsOneWidget);
        expect(find.text('Pastillas delanteras'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('maintenance-summary')),
          findsOneWidget,
        );
      },
    );

    testWidgets('opens a nearby workshop search with a punctual GPS reading', (
      tester,
    ) async {
      final launcher = _FakeLauncher();
      await _pump(
        tester,
        database,
        repository,
        locationGateway: const _SuccessfulLocationGateway(),
        launcher: launcher,
      );

      await tester.tap(find.byKey(const ValueKey('maintenance-find-workshop')));
      await tester.pumpAndSettle();

      expect(launcher.opened, hasLength(1));
      expect(
        Uri.parse(launcher.opened.single).queryParameters['query'],
        'taller mecánico cerca de 6.244200,-75.581200',
      );
    });

    testWidgets(
      'missing vehicleId selects the first available vehicle locally',
      (tester) async {
        final repository = _FakeMaintenanceRepository(database);

        await _pump(tester, database, repository, vehicleId: null);

        expect(find.text('Talleres'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('maintenance-vehicle-selector')),
          findsOneWidget,
        );
        expect(find.text('ABC123'), findsOneWidget);
        expect(repository.listedVehicleIds, contains('vehicle-1'));
      },
    );

    testWidgets(
      'nonexistent vehicleId shows maintenance garage CTA without query',
      (tester) async {
        final repository = _FakeMaintenanceRepository(database);

        await _pump(tester, database, repository, vehicleId: 'vehicle-missing');

        expect(
          find.byKey(const ValueKey('maintenance-missing-vehicle')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('maintenance-go-garage')),
          findsOneWidget,
        );
        expect(find.text('Documentos'), findsNothing);
        expect(repository.listedVehicleIds, isEmpty);
      },
    );

    testWidgets('creates, edits, and deletes a record', (tester) async {
      await _pump(tester, database, repository);

      await tester.tap(find.byKey(const ValueKey('maintenance-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('maintenance-type-field')),
        'Aceite',
      );
      await tester.enterText(
        find.byKey(const ValueKey('maintenance-description-field')),
        'Cambio de aceite y filtros',
      );
      await tester.enterText(
        find.byKey(const ValueKey('maintenance-odometer-field')),
        '45000',
      );
      await tester.enterText(
        find.byKey(const ValueKey('maintenance-cost-field')),
        '180000',
      );
      await tester.tap(find.byKey(const ValueKey('maintenance-save')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('maintenance-list')), findsOneWidget);
      expect(find.text('Aceite'), findsOneWidget);
      expect(find.text('Cambio de aceite y filtros'), findsOneWidget);
      expect(find.text('45.000 km'), findsOneWidget);
      expect(find.text('\$180.000'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('maintenance-card-maintenance-1')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('maintenance-type-field')),
        'Frenos',
      );
      await tester.enterText(
        find.byKey(const ValueKey('maintenance-description-field')),
        'Pastillas delanteras',
      );
      await tester.tap(find.byKey(const ValueKey('maintenance-save')));
      await tester.pumpAndSettle();

      expect(find.text('Frenos'), findsOneWidget);
      expect(find.text('Pastillas delanteras'), findsOneWidget);
      expect(find.text('Aceite'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('maintenance-menu-maintenance-1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('maintenance-confirm-delete')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('maintenance-empty')), findsOneWidget);
    });

    testWidgets('dispose while editor saves does not use disposed context', (
      tester,
    ) async {
      final repository = _FakeMaintenanceRepository(database)
        ..createCompleter = Completer<void>();
      await _pump(tester, database, repository);

      await tester.tap(find.byKey(const ValueKey('maintenance-add')));
      await tester.pumpAndSettle();
      await _fillRequiredEditorFields(tester);
      await tester.tap(find.byKey(const ValueKey('maintenance-save')));
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      repository.createCompleter!.complete();
      await tester.pump();

      expect(repository.createCalls, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('F10 dismissed saving sheet refreshes its vehicle list', (
      tester,
    ) async {
      final repository = _FakeMaintenanceRepository(database)
        ..createCompleter = Completer<void>();
      await _pump(tester, database, repository);
      await tester.tap(find.byKey(const ValueKey('maintenance-add')));
      await tester.pumpAndSettle();
      await _fillRequiredEditorFields(tester);
      await tester.tap(find.byKey(const ValueKey('maintenance-save')));
      await tester.pump();
      Navigator.of(
        tester.element(find.byKey(const ValueKey('maintenance-editor'))),
      ).pop();
      await tester.pumpAndSettle();
      repository.createCompleter!.complete();
      await tester.pumpAndSettle();
      expect(repository.records, hasLength(1));
      expect(find.text('Cambio de aceite y filtros'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('double tap creates exactly one record', (tester) async {
      final repository = _FakeMaintenanceRepository(database)
        ..createCompleter = Completer<void>();
      await _pump(tester, database, repository);

      await tester.tap(find.byKey(const ValueKey('maintenance-add')));
      await tester.pumpAndSettle();
      await _fillRequiredEditorFields(tester);
      await tester.tap(find.byKey(const ValueKey('maintenance-save')));
      await tester.tap(find.byKey(const ValueKey('maintenance-save')));

      expect(repository.createCalls, 1);

      repository.createCompleter!.complete();
      await tester.pumpAndSettle();

      expect(repository.records, hasLength(1));
      expect(find.byKey(const ValueKey('maintenance-list')), findsOneWidget);
    });

    testWidgets('repository failure shows visible save message', (
      tester,
    ) async {
      final repository = _FakeMaintenanceRepository(database)
        ..createError = const MaintenanceRepositoryException('boom');
      await _pump(tester, database, repository);

      await tester.tap(find.byKey(const ValueKey('maintenance-add')));
      await tester.pumpAndSettle();
      await _fillRequiredEditorFields(tester);
      await tester.tap(find.byKey(const ValueKey('maintenance-save')));
      await tester.pumpAndSettle();

      expect(
        find.text('No pudimos guardar el mantenimiento. Intenta de nuevo.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('maintenance-editor')), findsOneWidget);
    });

    testWidgets('repository failure shows visible delete message', (
      tester,
    ) async {
      final repository = _FakeMaintenanceRepository(database)
        ..records.add(_record(id: 'maintenance-1'))
        ..deleteError = const MaintenanceRepositoryException('boom');
      await _pump(tester, database, repository);

      await tester.tap(
        find.byKey(const ValueKey('maintenance-menu-maintenance-1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('maintenance-confirm-delete')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('No pudimos eliminar el mantenimiento. Intenta de nuevo.'),
        findsOneWidget,
      );
      expect(repository.records, hasLength(1));
    });

    testWidgets('editor sheet is shown above a shell bottom nav', (
      tester,
    ) async {
      await _pumpWithBottomNav(tester, database, repository);

      await tester.tap(find.byKey(const ValueKey('maintenance-add')));
      await tester.pumpAndSettle();

      final editorBottom = tester
          .getRect(find.byKey(const ValueKey('maintenance-editor')))
          .bottom;
      final navTop = tester
          .getRect(find.byKey(const ValueKey('test-bottom-nav')))
          .top;

      expect(editorBottom, greaterThan(navTop));
    });
  });
}

Future<void> _pump(
  WidgetTester tester,
  AppDatabase database,
  MaintenanceRepository repository, {
  String? vehicleId = 'vehicle-1',
  ThemeData? theme,
  DeviceLocationGateway? locationGateway,
  ExternalLauncher? launcher,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        appPreferencesProvider.overrideWithValue(_MemoryPreferences()),
        maintenanceRepositoryProvider.overrideWithValue(repository),
        if (locationGateway != null)
          deviceLocationGatewayProvider.overrideWithValue(locationGateway),
        if (launcher != null)
          externalLauncherProvider.overrideWithValue(launcher),
        registrationCityCatalogProvider.overrideWithValue(
          const AsyncData(RegistrationCityCatalog(records: [])),
        ),
      ],
      child: MaterialApp(
        theme: theme,
        home: MaintenanceScreen(vehicleId: vehicleId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpWithBottomNav(
  WidgetTester tester,
  AppDatabase database,
  MaintenanceRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        appPreferencesProvider.overrideWithValue(_MemoryPreferences()),
        maintenanceRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => const MaintenanceScreen(vehicleId: 'vehicle-1'),
            ),
          ),
          bottomNavigationBar: const SizedBox(
            key: ValueKey('test-bottom-nav'),
            height: 88,
            child: Text('Garaje bottom nav'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _fillRequiredEditorFields(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('maintenance-type-field')),
    'Aceite',
  );
  await tester.enterText(
    find.byKey(const ValueKey('maintenance-description-field')),
    'Cambio de aceite y filtros',
  );
}

MaintenanceRecord _record({
  String id = 'maintenance-1',
  String vehicleId = 'vehicle-1',
  String type = 'Aceite',
  String description = 'Cambio de aceite.',
}) {
  final now = DateTime(2026, 9, 1);
  return MaintenanceRecord(
    id: id,
    vehicleId: vehicleId,
    serviceDate: now,
    type: type,
    description: description,
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeMaintenanceRepository extends MaintenanceRepository {
  _FakeMaintenanceRepository(AppDatabase database) : super(database: database);

  final records = <MaintenanceRecord>[];
  final listedVehicleIds = <String>[];
  var createCalls = 0;
  Object? createError;
  Object? deleteError;
  Completer<void>? createCompleter;

  @override
  Future<List<MaintenanceRecord>> listByVehicle(String vehicleId) async {
    listedVehicleIds.add(vehicleId);
    return records
        .where((record) => record.vehicleId == vehicleId)
        .toList(growable: false);
  }

  @override
  Future<MaintenanceRecord> create({
    required String vehicleId,
    required DateTime serviceDate,
    required String type,
    required String description,
    int? odometer,
    int? costCents,
    DateTime? nextServiceDate,
    int? nextOdometer,
  }) async {
    createCalls += 1;
    await createCompleter?.future;
    final error = createError;
    if (error != null) {
      throw error;
    }
    final now = DateTime(2026, 9, createCalls);
    final record = MaintenanceRecord(
      id: 'maintenance-$createCalls',
      vehicleId: vehicleId,
      serviceDate: serviceDate,
      type: type,
      description: description,
      odometer: odometer,
      costCents: costCents,
      nextServiceDate: nextServiceDate,
      nextOdometer: nextOdometer,
      createdAt: now,
      updatedAt: now,
    );
    records.add(record);
    return record;
  }

  @override
  Future<MaintenanceRecord> edit({
    required String id,
    required DateTime serviceDate,
    required String type,
    required String description,
    int? odometer,
    int? costCents,
    DateTime? nextServiceDate,
    int? nextOdometer,
  }) async {
    final index = records.indexWhere((record) => record.id == id);
    final existing = records[index];
    final edited = MaintenanceRecord(
      id: existing.id,
      vehicleId: existing.vehicleId,
      serviceDate: serviceDate,
      type: type,
      description: description,
      odometer: odometer,
      costCents: costCents,
      nextServiceDate: nextServiceDate,
      nextOdometer: nextOdometer,
      createdAt: existing.createdAt,
      updatedAt: existing.updatedAt.add(const Duration(seconds: 1)),
    );
    records[index] = edited;
    return edited;
  }

  @override
  Future<void> delete(String id) async {
    final error = deleteError;
    if (error != null) {
      throw error;
    }
    records.removeWhere((record) => record.id == id);
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

class _SuccessfulLocationGateway implements DeviceLocationGateway {
  const _SuccessfulLocationGateway();

  @override
  Future<DeviceLocationPermission> checkPermission() async =>
      DeviceLocationPermission.granted;

  @override
  Future<DeviceLocationResult> getCurrentPosition() async =>
      const DeviceLocationSuccess(
        DeviceLocationPoint(
          latitude: 6.2442,
          longitude: -75.5812,
          accuracyMeters: 12,
        ),
      );

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<DeviceLocationPermission> requestPermission() async =>
      DeviceLocationPermission.granted;
}

class _FakeLauncher implements ExternalLauncher {
  final opened = <String>[];

  @override
  Future<bool> callPhone(String phone) async => true;

  @override
  Future<bool> openExternal(String uri) async {
    opened.add(uri);
    return true;
  }
}
