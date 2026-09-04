import 'dart:async';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/core/database/app_database.dart'
    hide MaintenanceRecord;
import 'package:picoradar/core/storage/app_preferences.dart';
import 'package:picoradar/features/maintenance/data/maintenance_record.dart';
import 'package:picoradar/features/maintenance/data/maintenance_repository.dart';
import 'package:picoradar/features/maintenance/presentation/maintenance_screen.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('MaintenanceScreen', () {
    late AppDatabase database;
    late MaintenanceRepository repository;
    var nextId = 0;

    setUp(() async {
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

    testWidgets('shows visible title and empty state', (tester) async {
      await _pump(tester, database, repository);

      expect(find.text('Talleres y mantenimiento'), findsOneWidget);
      expect(find.byKey(const ValueKey('maintenance-empty')), findsOneWidget);
      expect(find.text('Sin registros todavía'), findsOneWidget);
    });

    testWidgets(
      'missing vehicleId shows maintenance garage CTA without query',
      (tester) async {
        final repository = _FakeMaintenanceRepository(database);

        await _pump(tester, database, repository, vehicleId: null);

        expect(find.text('Talleres y mantenimiento'), findsWidgets);
        expect(
          find.byKey(const ValueKey('maintenance-missing-vehicle')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('maintenance-go-garage')),
          findsOneWidget,
        );
        expect(find.text('Ir a Garaje'), findsOneWidget);
        expect(find.text('Documentos'), findsNothing);
        expect(repository.listedVehicleIds, isEmpty);
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
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        appPreferencesProvider.overrideWithValue(_MemoryPreferences()),
        maintenanceRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(home: MaintenanceScreen(vehicleId: vehicleId)),
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
