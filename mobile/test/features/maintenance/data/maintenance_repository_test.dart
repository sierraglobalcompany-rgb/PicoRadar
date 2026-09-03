import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/features/maintenance/data/maintenance_repository.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('MaintenanceRepository', () {
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
      await database
          .into(database.vehicles)
          .insert(VehiclesCompanion.insert(id: 'vehicle-2', plate: 'XYZ789'));
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'creates and lists records by vehicle descending by service date',
      () async {
        await repository.create(
          vehicleId: 'vehicle-1',
          serviceDate: DateTime(2026, 1, 10, 15),
          type: 'Aceite',
          description: 'Cambio de aceite y filtro.',
        );
        await repository.create(
          vehicleId: 'vehicle-2',
          serviceDate: DateTime(2026, 4, 10),
          type: 'Frenos',
          description: 'Pastillas delanteras.',
        );
        await repository.create(
          vehicleId: 'vehicle-1',
          serviceDate: DateTime(2026, 8, 20),
          type: 'Llantas',
          description: 'Alineación y balanceo.',
          odometer: 45000,
          costCents: 18000000,
          nextServiceDate: DateTime(2027, 2, 20, 12),
          nextOdometer: 55000,
        );

        final records = await repository.listByVehicle('vehicle-1');

        expect(records.map((record) => record.type), ['Llantas', 'Aceite']);
        expect(records.first.serviceDate, DateTime(2026, 8, 20));
        expect(records.first.nextServiceDate, DateTime(2027, 2, 20));
        expect(records.first.odometer, 45000);
        expect(records.first.costCents, 18000000);
        expect(records.first.nextOdometer, 55000);
      },
    );

    test('edits and deletes a maintenance record', () async {
      final created = await repository.create(
        vehicleId: 'vehicle-1',
        serviceDate: DateTime(2026, 8, 20),
        type: 'Aceite',
        description: 'Aceite.',
      );

      final edited = await repository.edit(
        id: created.id,
        serviceDate: DateTime(2026, 8, 21),
        type: 'Cambio de aceite',
        description: 'Aceite y filtros.',
        odometer: 46000,
        costCents: 19000000,
      );

      expect(edited.vehicleId, 'vehicle-1');
      expect(edited.serviceDate, DateTime(2026, 8, 21));
      expect(edited.type, 'Cambio de aceite');
      expect(edited.description, 'Aceite y filtros.');
      expect(edited.odometer, 46000);
      expect(edited.costCents, 19000000);
      expect(edited.updatedAt.isAfter(created.updatedAt), isTrue);

      await repository.delete(created.id);

      expect(await repository.listByVehicle('vehicle-1'), isEmpty);
    });

    test('rejects empty text and negative numeric values', () async {
      await expectLater(
        repository.create(
          vehicleId: 'vehicle-1',
          serviceDate: DateTime(2026, 8, 20),
          type: '  ',
          description: 'Aceite.',
        ),
        throwsA(isA<MaintenanceRepositoryException>()),
      );

      await expectLater(
        repository.create(
          vehicleId: 'vehicle-1',
          serviceDate: DateTime(2026, 8, 20),
          type: 'Aceite',
          description: '',
        ),
        throwsA(isA<MaintenanceRepositoryException>()),
      );

      await expectLater(
        repository.create(
          vehicleId: 'vehicle-1',
          serviceDate: DateTime(2026, 8, 20),
          type: 'Aceite',
          description: 'Aceite.',
          odometer: -1,
        ),
        throwsA(isA<MaintenanceRepositoryException>()),
      );
    });
  });
}
