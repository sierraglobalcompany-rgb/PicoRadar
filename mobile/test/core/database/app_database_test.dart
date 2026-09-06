import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/database/app_database.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

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

    test('creates schema v6 with publication revisions', () async {
      expect(db.schemaVersion, AppDatabase.currentSchemaVersion);
      expect(db.schemaVersion, 6);

      await db
          .into(db.vehicles)
          .insert(
            VehiclesCompanion.insert(
              id: 'vehicle-1',
              plate: 'ABC123',
              serviceType: const Value('taxi'),
              subtype: const Value('car_sedan'),
              registrationCity: const Value('Bogota'),
              brand: const Value('Mazda'),
              model: const Value('2'),
              year: const Value(2021),
              color: const Value('Rojo'),
              fuel: const Value('Gasolina'),
            ),
          );
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
              startDate: Value(DateTime(2026, 1, 1)),
              dueDate: Value(DateTime(2026, 12, 31)),
              detailsJson: const Value('{"insurerName":"ACME"}'),
              reminderEnabled: const Value(true),
            ),
          );
      await db
          .into(db.maintenanceRecords)
          .insert(
            MaintenanceRecordsCompanion.insert(
              id: 'maintenance-1',
              vehicleId: 'vehicle-1',
              serviceDate: DateTime(2026, 8, 20),
              type: 'Cambio de aceite',
              description: 'Aceite y filtros.',
              odometer: const Value(45000),
              costCents: const Value(18000000),
              nextServiceDate: Value(DateTime(2027, 2, 20)),
              nextOdometer: const Value(55000),
            ),
          );

      expect(await db.select(db.vehicles).get(), hasLength(1));
      expect(await db.select(db.notificationPreferences).get(), hasLength(1));
      expect(await db.select(db.datasetVersions).get(), hasLength(1));
      final datasetVersion = await db
          .customSelect('SELECT publication_revision FROM dataset_versions')
          .getSingle();
      expect(datasetVersion.read<int>('publication_revision'), 0);
      expect(await db.select(db.vehicleObligations).get(), hasLength(1));
      expect(await db.select(db.maintenanceRecords).get(), hasLength(1));
      expect(await db.select(db.restrictionCoverages).get(), isEmpty);
    });

    test('migrates schema v1 to v6 preserving existing vehicles', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'picoradar_migration_',
      );
      final dbPath = '${tempDir.path}${Platform.pathSeparator}app.sqlite';

      try {
        _createLegacyV1Database(dbPath);

        final migrated = AppDatabase(NativeDatabase(File(dbPath)));
        final vehicles = await migrated.select(migrated.vehicles).get();
        final version = await migrated
            .customSelect('PRAGMA user_version')
            .get();
        await migrated.close();

        expect(version.single.data['user_version'], 6);
        expect(vehicles, hasLength(1));
        expect(vehicles.single.id, 'vehicle-1');
        expect(vehicles.single.plate, 'ABC123');
        expect(vehicles.single.serviceType, 'private');
        expect(vehicles.single.subtype, isNull);
        expect(vehicles.single.registrationCity, isNull);
        expect(vehicles.single.brand, isNull);
        expect(vehicles.single.model, isNull);
        expect(vehicles.single.year, isNull);
        expect(vehicles.single.color, isNull);
        expect(vehicles.single.fuel, isNull);
      } finally {
        await _deleteTempDir(tempDir);
      }
    });

    test(
      'migrates schema v2 to v6 preserving vehicles and adding coverages',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'picoradar_migration_v2_',
        );
        final dbPath = '${tempDir.path}${Platform.pathSeparator}app.sqlite';

        try {
          _createLegacyV2Database(dbPath);

          final migrated = AppDatabase(NativeDatabase(File(dbPath)));
          final vehicles = await migrated.select(migrated.vehicles).get();
          final coverages = await migrated
              .select(migrated.restrictionCoverages)
              .get();
          final version = await migrated
              .customSelect('PRAGMA user_version')
              .get();
          await migrated.close();

          expect(version.single.data['user_version'], 6);
          expect(vehicles, hasLength(1));
          expect(vehicles.single.id, 'vehicle-1');
          expect(vehicles.single.plate, 'ABC123');
          expect(coverages, isEmpty);
        } finally {
          await _deleteTempDir(tempDir);
        }
      },
    );

    test(
      'migrates schema v3 to v6 preserving local data and defaults',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'picoradar_migration_v3_',
        );
        final dbPath = '${tempDir.path}${Platform.pathSeparator}app.sqlite';

        try {
          _createLegacyV3Database(dbPath);

          final migrated = AppDatabase(NativeDatabase(File(dbPath)));
          final vehicles = await migrated.select(migrated.vehicles).get();
          final coverages = await migrated
              .select(migrated.restrictionCoverages)
              .get();
          final obligations = await migrated
              .select(migrated.vehicleObligations)
              .get();
          final version = await migrated
              .customSelect('PRAGMA user_version')
              .get();
          await migrated.close();

          expect(version.single.data['user_version'], 6);
          expect(vehicles, hasLength(1));
          expect(vehicles.single.plate, 'ABC123');
          expect(coverages, hasLength(1));
          expect(coverages.single.jurisdictionId, 'co-dc-bogota');
          expect(obligations, hasLength(1));
          expect(obligations.single.id, 'vehicle-1:soat');
          expect(obligations.single.dueDate, DateTime(2026, 12, 31));
          expect(obligations.single.startDate, isNull);
          expect(obligations.single.detailsJson, isNull);
          expect(obligations.single.reminderEnabled, isTrue);
        } finally {
          await _deleteTempDir(tempDir);
        }
      },
    );

    test(
      'migrates schema v4 to v6 preserving vehicles and obligations',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'picoradar_migration_v4_',
        );
        final dbPath = '${tempDir.path}${Platform.pathSeparator}app.sqlite';

        try {
          _createLegacyV4Database(dbPath);

          final migrated = AppDatabase(NativeDatabase(File(dbPath)));
          final vehicles = await migrated.select(migrated.vehicles).get();
          final obligations = await migrated
              .select(migrated.vehicleObligations)
              .get();
          final maintenanceRecords = await migrated
              .select(migrated.maintenanceRecords)
              .get();
          final version = await migrated
              .customSelect('PRAGMA user_version')
              .get();
          await migrated.close();

          expect(version.single.data['user_version'], 6);
          expect(vehicles, hasLength(1));
          expect(vehicles.single.plate, 'ABC123');
          expect(obligations, hasLength(1));
          expect(obligations.single.id, 'vehicle-1:soat');
          expect(obligations.single.reminderEnabled, isTrue);
          expect(maintenanceRecords, isEmpty);
        } finally {
          await _deleteTempDir(tempDir);
        }
      },
    );

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

      await expectLater(
        db
            .into(db.maintenanceRecords)
            .insert(
              MaintenanceRecordsCompanion.insert(
                id: 'orphan-maintenance',
                vehicleId: 'missing-vehicle',
                serviceDate: DateTime(2026, 8, 20),
                type: 'Aceite',
                description: 'Cambio de aceite.',
              ),
            ),
        throwsException,
      );
    });

    test('cascades maintenance records when deleting a vehicle', () async {
      await db
          .into(db.vehicles)
          .insert(VehiclesCompanion.insert(id: 'vehicle-1', plate: 'ABC123'));
      await db
          .into(db.maintenanceRecords)
          .insert(
            MaintenanceRecordsCompanion.insert(
              id: 'maintenance-1',
              vehicleId: 'vehicle-1',
              serviceDate: DateTime(2026, 8, 20),
              type: 'Aceite',
              description: 'Cambio de aceite.',
            ),
          );

      await (db.delete(
        db.vehicles,
      )..where((row) => row.id.equals('vehicle-1'))).go();

      expect(await db.select(db.maintenanceRecords).get(), isEmpty);
    });

    test('reopens schema 6 without destroying existing local data', () async {
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

    test('migrates schema v5 to v6 preserving dataset selection', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'picoradar_migration_v5_',
      );
      final dbPath = '${tempDir.path}${Platform.pathSeparator}app.sqlite';

      try {
        _createLegacyV5Database(dbPath);

        final migrated = AppDatabase(NativeDatabase(File(dbPath)));
        final selected = await migrated
            .customSelect(
              'SELECT version, sha256, publication_revision '
              'FROM dataset_versions WHERE dataset_key = ?',
              variables: [Variable.withString('tolls_inventory')],
            )
            .getSingle();
        final version = await migrated
            .customSelect('PRAGMA user_version')
            .get();
        await migrated.close();

        expect(version.single.data['user_version'], 6);
        expect(selected.read<String>('version'), 'opaque-v1');
        expect(selected.read<String>('sha256'), 'a' * 64);
        expect(selected.read<int>('publication_revision'), 0);
      } finally {
        await _deleteTempDir(tempDir);
      }
    });
  });
}

void _createLegacyV5Database(String path) {
  _createLegacyV4Database(path);
  final sqlite = sqlite3.open(path);

  try {
    sqlite.execute('''
CREATE TABLE maintenance_records (
  id TEXT NOT NULL PRIMARY KEY,
  vehicle_id TEXT NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  service_date INTEGER NOT NULL,
  odometer INTEGER NULL,
  type TEXT NOT NULL,
  description TEXT NOT NULL,
  cost_cents INTEGER NULL,
  next_service_date INTEGER NULL,
  next_odometer INTEGER NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)
''');
    sqlite.execute(
      'CREATE INDEX maintenance_records_vehicle_id_idx '
      'ON maintenance_records (vehicle_id)',
    );
    sqlite.execute(
      'CREATE INDEX maintenance_records_service_date_idx '
      'ON maintenance_records (service_date)',
    );
    sqlite.execute(
      "INSERT INTO dataset_versions "
      "(id, dataset_key, version, sha256, status, applied_at) "
      "VALUES ('tolls_inventory', 'tolls_inventory', 'opaque-v1', "
      "'${'a' * 64}', 'installed', 0)",
    );
    sqlite.execute('PRAGMA user_version = 5');
  } finally {
    sqlite.close();
  }
}

void _createLegacyV4Database(String path) {
  _createLegacyV3Database(path);
  final sqlite = sqlite3.open(path);

  try {
    sqlite.execute(
      'ALTER TABLE vehicle_obligations ADD COLUMN start_date INTEGER NULL',
    );
    sqlite.execute(
      'ALTER TABLE vehicle_obligations ADD COLUMN details_json TEXT NULL',
    );
    sqlite.execute(
      'ALTER TABLE vehicle_obligations ADD COLUMN reminder_enabled INTEGER NOT NULL DEFAULT 1',
    );
    sqlite.execute('PRAGMA user_version = 4');
  } finally {
    sqlite.close();
  }
}

void _createLegacyV2Database(String path) {
  _createLegacyV1Database(path);
  final sqlite = sqlite3.open(path);

  try {
    sqlite.execute(
      "ALTER TABLE vehicles ADD COLUMN service_type TEXT NOT NULL DEFAULT 'private'",
    );
    sqlite.execute('ALTER TABLE vehicles ADD COLUMN subtype TEXT NULL');
    sqlite.execute(
      'ALTER TABLE vehicles ADD COLUMN registration_city TEXT NULL',
    );
    sqlite.execute('ALTER TABLE vehicles ADD COLUMN brand TEXT NULL');
    sqlite.execute('ALTER TABLE vehicles ADD COLUMN model TEXT NULL');
    sqlite.execute('ALTER TABLE vehicles ADD COLUMN year INTEGER NULL');
    sqlite.execute('ALTER TABLE vehicles ADD COLUMN color TEXT NULL');
    sqlite.execute('ALTER TABLE vehicles ADD COLUMN fuel TEXT NULL');
    sqlite.execute('PRAGMA user_version = 2');
  } finally {
    sqlite.close();
  }
}

void _createLegacyV3Database(String path) {
  _createLegacyV2Database(path);
  final sqlite = sqlite3.open(path);
  final now = DateTime.utc(2026).millisecondsSinceEpoch;
  final due = DateTime(2026, 12, 31).millisecondsSinceEpoch ~/ 1000;

  try {
    sqlite.execute('''
CREATE TABLE restriction_coverages (
  id TEXT NOT NULL PRIMARY KEY,
  jurisdiction_id TEXT NOT NULL,
  jurisdiction_name TEXT NOT NULL,
  vehicle_kind TEXT NOT NULL,
  service_type TEXT NOT NULL,
  rules_json TEXT NOT NULL,
  verified_at INTEGER NOT NULL,
  stale_after INTEGER NOT NULL,
  source_urls_json TEXT NOT NULL,
  updated_at INTEGER NOT NULL
)
''');
    sqlite.execute(
      'CREATE UNIQUE INDEX restriction_coverages_lookup_idx '
      'ON restriction_coverages (jurisdiction_id, vehicle_kind, service_type)',
    );
    sqlite.execute(
      '''
INSERT INTO restriction_coverages (
  id,
  jurisdiction_id,
  jurisdiction_name,
  vehicle_kind,
  service_type,
  rules_json,
  verified_at,
  stale_after,
  source_urls_json,
  updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
''',
      [
        'coverage-1',
        'co-dc-bogota',
        'Bogota',
        'car',
        'private',
        '[]',
        now,
        now,
        '[]',
        now,
      ],
    );
    sqlite.execute(
      '''
INSERT INTO vehicle_obligations (
  id,
  vehicle_id,
  type,
  status,
  due_date,
  created_at,
  updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?)
''',
      ['vehicle-1:soat', 'vehicle-1', 'soat', 'configured', due, now, now],
    );
    sqlite.execute('PRAGMA user_version = 3');
  } finally {
    sqlite.close();
  }
}

void _createLegacyV1Database(String path) {
  final sqlite = sqlite3.open(path);
  final now = DateTime.utc(2026).millisecondsSinceEpoch;

  try {
    sqlite.execute('''
CREATE TABLE vehicles (
  id TEXT NOT NULL PRIMARY KEY,
  plate TEXT NOT NULL,
  nickname TEXT NULL,
  kind TEXT NOT NULL DEFAULT 'car',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)
''');
    sqlite.execute(
      'CREATE UNIQUE INDEX vehicles_plate_idx ON vehicles (plate)',
    );
    sqlite.execute('''
CREATE TABLE vehicle_obligations (
  id TEXT NOT NULL PRIMARY KEY,
  vehicle_id TEXT NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  status TEXT NOT NULL,
  due_date INTEGER NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)
''');
    sqlite.execute(
      'CREATE INDEX vehicle_obligations_vehicle_id_idx '
      'ON vehicle_obligations (vehicle_id)',
    );
    sqlite.execute(
      'CREATE INDEX vehicle_obligations_due_date_idx '
      'ON vehicle_obligations (due_date)',
    );
    sqlite.execute('''
CREATE TABLE notification_preferences (
  id TEXT NOT NULL PRIMARY KEY,
  restriction_alerts_enabled INTEGER NOT NULL DEFAULT 1,
  obligation_reminders_enabled INTEGER NOT NULL DEFAULT 1,
  updated_at INTEGER NOT NULL
)
''');
    sqlite.execute('''
CREATE TABLE dataset_versions (
  id TEXT NOT NULL PRIMARY KEY,
  dataset_key TEXT NOT NULL,
  version TEXT NOT NULL,
  sha256 TEXT NULL,
  status TEXT NOT NULL,
  applied_at INTEGER NOT NULL
)
''');
    sqlite.execute(
      'CREATE UNIQUE INDEX dataset_versions_dataset_key_idx '
      'ON dataset_versions (dataset_key)',
    );
    sqlite.execute(
      '''
INSERT INTO vehicles (id, plate, nickname, kind, created_at, updated_at)
VALUES (?, ?, ?, ?, ?, ?)
''',
      ['vehicle-1', 'ABC123', 'Primer carro', 'car', now, now],
    );
    sqlite.execute('PRAGMA user_version = 1');
  } finally {
    sqlite.close();
  }
}

Future<void> _deleteTempDir(Directory directory) async {
  for (var attempt = 0; attempt < 5; attempt++) {
    try {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
      return;
    } on FileSystemException {
      if (attempt < 4) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  }
}
