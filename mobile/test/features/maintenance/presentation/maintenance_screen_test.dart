import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/core/database/app_database.dart';
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
  });
}

Future<void> _pump(
  WidgetTester tester,
  AppDatabase database,
  MaintenanceRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        maintenanceRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(home: MaintenanceScreen(vehicleId: 'vehicle-1')),
    ),
  );
  await tester.pumpAndSettle();
}
