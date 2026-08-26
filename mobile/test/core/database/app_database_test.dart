import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/database/app_database.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('AppDatabase', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('creates schema version 1 with the C03 tables', () async {
      expect(db.schemaVersion, AppDatabase.currentSchemaVersion);

      await db
          .into(db.vehicles)
          .insert(VehiclesCompanion.insert(id: 'vehicle-1', plate: 'ABC123'));
      await db
          .into(db.notificationPreferences)
          .insert(NotificationPreferencesCompanion.insert(id: 'default'));
      await db
          .into(db.datasetVersions)
          .insert(
            DatasetVersionsCompanion.insert(
              id: 'dataset-restrictions',
              datasetKey: 'restrictions',
              version: '1',
              status: 'current',
            ),
          );
      await db
          .into(db.vehicleObligations)
          .insert(
            VehicleObligationsCompanion.insert(
              id: 'obligation-soat',
              vehicleId: 'vehicle-1',
              type: 'soat',
              status: 'pending',
            ),
          );

      expect(await db.select(db.vehicles).get(), hasLength(1));
      expect(await db.select(db.notificationPreferences).get(), hasLength(1));
      expect(await db.select(db.datasetVersions).get(), hasLength(1));
      expect(await db.select(db.vehicleObligations).get(), hasLength(1));
    });

    test('enforces local identity constraints and vehicle relation', () async {
      await db
          .into(db.vehicles)
          .insert(VehiclesCompanion.insert(id: 'vehicle-1', plate: 'ABC123'));

      await expectLater(
        db
            .into(db.vehicles)
            .insert(VehiclesCompanion.insert(id: 'vehicle-2', plate: 'ABC123')),
        throwsException,
      );

      await expectLater(
        db
            .into(db.vehicleObligations)
            .insert(
              VehicleObligationsCompanion.insert(
                id: 'orphan-obligation',
                vehicleId: 'missing-vehicle',
                type: 'soat',
                status: 'pending',
              ),
            ),
        throwsException,
      );
    });

    test('reopens schema 1 without destroying existing local data', () async {
      final tempDir = await Directory.systemTemp.createTemp('picoradar_db_');
      final dbPath = '${tempDir.path}${Platform.pathSeparator}app.sqlite';

      try {
        final first = AppDatabase(NativeDatabase(File(dbPath)));
        await first
            .into(first.vehicles)
            .insert(VehiclesCompanion.insert(id: 'vehicle-1', plate: 'ABC123'));
        await first.close();

        final second = AppDatabase(NativeDatabase(File(dbPath)));
        final vehicles = await second.select(second.vehicles).get();
        await second.close();

        expect(vehicles, hasLength(1));
        expect(vehicles.single.plate, 'ABC123');
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}
