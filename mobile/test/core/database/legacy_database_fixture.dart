// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

/// Creates the real pre-v9 SQLite schema used by migration regression tests.
///
/// These are historical v6, v7, and v8 layouts. In particular, coverage rows
/// do not have `coverage_completeness` until the v9-to-v10 migration, and v7
/// private documents have only driver and vehicle owners.
void createLegacyDatabaseFixture(Database database, {required int version}) {
  if (version < 6 || version > 8) {
    throw ArgumentError.value(
      version,
      'version',
      'Expected schema v6, v7, or v8',
    );
  }

  database.execute('PRAGMA foreign_keys = ON');
  _createV1Tables(database);
  _upgradeVehiclesToV2(database);
  _createV3CoverageTable(database);
  _upgradeObligationsToV4(database);
  _createV5MaintenanceTable(database);
  _upgradeDatasetVersionsToV6(database);

  if (version >= 7) {
    _createV7WalletTables(database);
  }
  if (version >= 8) {
    _upgradeWalletTablesToV8(database);
  }

  database.execute('PRAGMA user_version = $version');
}

void _createV1Tables(Database database) {
  database.execute('''
    CREATE TABLE vehicles (
      id TEXT NOT NULL PRIMARY KEY,
      plate TEXT NOT NULL,
      nickname TEXT,
      kind TEXT NOT NULL DEFAULT 'car',
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
  database.execute(
    'CREATE UNIQUE INDEX vehicles_plate_idx ON vehicles (plate)',
  );
  database.execute('''
    CREATE TABLE vehicle_obligations (
      id TEXT NOT NULL PRIMARY KEY,
      vehicle_id TEXT NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
      type TEXT NOT NULL CHECK (length(type) BETWEEN 1 AND 32),
      status TEXT NOT NULL CHECK (length(status) BETWEEN 1 AND 32),
      due_date INTEGER,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
  database.execute(
    'CREATE INDEX vehicle_obligations_vehicle_id_idx '
    'ON vehicle_obligations (vehicle_id)',
  );
  database.execute(
    'CREATE INDEX vehicle_obligations_due_date_idx '
    'ON vehicle_obligations (due_date)',
  );
  database.execute('''
    CREATE TABLE notification_preferences (
      id TEXT NOT NULL PRIMARY KEY,
      restriction_alerts_enabled INTEGER NOT NULL DEFAULT 1
        CHECK (restriction_alerts_enabled IN (0, 1)),
      obligation_reminders_enabled INTEGER NOT NULL DEFAULT 1
        CHECK (obligation_reminders_enabled IN (0, 1)),
      updated_at INTEGER NOT NULL
    )
  ''');
  database.execute('''
    CREATE TABLE dataset_versions (
      id TEXT NOT NULL PRIMARY KEY,
      dataset_key TEXT NOT NULL CHECK (length(dataset_key) BETWEEN 1 AND 64),
      version TEXT NOT NULL CHECK (length(version) BETWEEN 1 AND 64),
      sha256 TEXT,
      status TEXT NOT NULL CHECK (length(status) BETWEEN 1 AND 32),
      applied_at INTEGER NOT NULL
    )
  ''');
  database.execute(
    'CREATE UNIQUE INDEX dataset_versions_dataset_key_idx '
    'ON dataset_versions (dataset_key)',
  );
}

void _upgradeVehiclesToV2(Database database) {
  database.execute(
    "ALTER TABLE vehicles ADD COLUMN service_type TEXT NOT NULL DEFAULT 'private'",
  );
  for (final column in ['subtype', 'registration_city', 'brand', 'model']) {
    database.execute('ALTER TABLE vehicles ADD COLUMN $column TEXT');
  }
  database.execute('ALTER TABLE vehicles ADD COLUMN year INTEGER');
  database.execute('ALTER TABLE vehicles ADD COLUMN color TEXT');
  database.execute('ALTER TABLE vehicles ADD COLUMN fuel TEXT');
}

void _createV3CoverageTable(Database database) {
  database.execute('''
    CREATE TABLE restriction_coverages (
      id TEXT NOT NULL PRIMARY KEY,
      jurisdiction_id TEXT NOT NULL CHECK (length(jurisdiction_id) BETWEEN 1 AND 64),
      jurisdiction_name TEXT NOT NULL CHECK (length(jurisdiction_name) BETWEEN 1 AND 128),
      vehicle_kind TEXT NOT NULL CHECK (length(vehicle_kind) BETWEEN 1 AND 32),
      service_type TEXT NOT NULL CHECK (length(service_type) BETWEEN 1 AND 32),
      rules_json TEXT NOT NULL,
      verified_at INTEGER NOT NULL,
      stale_after INTEGER NOT NULL,
      source_urls_json TEXT NOT NULL,
      updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
    )
  ''');
  database.execute(
    'CREATE UNIQUE INDEX restriction_coverages_lookup_idx '
    'ON restriction_coverages '
    '(jurisdiction_id, vehicle_kind, service_type)',
  );
}

void _upgradeObligationsToV4(Database database) {
  database.execute(
    'ALTER TABLE vehicle_obligations ADD COLUMN start_date INTEGER',
  );
  database.execute(
    'ALTER TABLE vehicle_obligations ADD COLUMN details_json TEXT',
  );
  database.execute('''
    ALTER TABLE vehicle_obligations
    ADD COLUMN reminder_enabled INTEGER NOT NULL DEFAULT 1
      CHECK (reminder_enabled IN (0, 1))
  ''');
}

void _createV5MaintenanceTable(Database database) {
  database.execute('''
    CREATE TABLE maintenance_records (
      id TEXT NOT NULL PRIMARY KEY,
      vehicle_id TEXT NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
      service_date INTEGER NOT NULL,
      odometer INTEGER,
      type TEXT NOT NULL CHECK (length(type) BETWEEN 1 AND 64),
      description TEXT NOT NULL CHECK (length(description) BETWEEN 1 AND 500),
      cost_cents INTEGER,
      next_service_date INTEGER,
      next_odometer INTEGER,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
  database.execute(
    'CREATE INDEX maintenance_records_vehicle_id_idx '
    'ON maintenance_records (vehicle_id)',
  );
  database.execute(
    'CREATE INDEX maintenance_records_service_date_idx '
    'ON maintenance_records (service_date)',
  );
}

void _upgradeDatasetVersionsToV6(Database database) {
  database.execute('''
    ALTER TABLE dataset_versions
    ADD COLUMN publication_revision INTEGER NOT NULL DEFAULT 0
  ''');
}

void _createV7WalletTables(Database database) {
  database.execute('''
    CREATE TABLE driver_profiles (
      id TEXT NOT NULL PRIMARY KEY,
      slot INTEGER NOT NULL UNIQUE,
      encrypted_metadata BLOB NOT NULL,
      CHECK (slot IN (0, 1)),
      CHECK ((slot = 0 AND id = 'principal') OR
        (slot = 1 AND id <> 'principal'))
    )
  ''');
  database.execute('''
    CREATE TABLE private_documents (
      id TEXT NOT NULL PRIMARY KEY,
      driver_id TEXT REFERENCES driver_profiles(id) ON DELETE CASCADE,
      vehicle_id TEXT REFERENCES vehicles(id) ON DELETE CASCADE,
      type TEXT NOT NULL CHECK (length(type) BETWEEN 1 AND 32),
      encrypted_metadata BLOB NOT NULL,
      imported_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
      CHECK ((driver_id IS NOT NULL AND vehicle_id IS NULL) OR
        (driver_id IS NULL AND vehicle_id IS NOT NULL))
    )
  ''');
  database.execute(
    'CREATE UNIQUE INDEX private_documents_driver_type_idx '
    'ON private_documents (driver_id, type)',
  );
  database.execute(
    'CREATE UNIQUE INDEX private_documents_vehicle_type_idx '
    'ON private_documents (vehicle_id, type)',
  );
  database.execute('''
    CREATE TABLE wallet_migrations (
      id TEXT NOT NULL PRIMARY KEY,
      encrypted_metadata BLOB NOT NULL,
      completed_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
    )
  ''');
}

void _upgradeWalletTablesToV8(Database database) {
  database.execute('''
    CREATE TABLE wallet_preparations (
      id TEXT NOT NULL PRIMARY KEY,
      encrypted_metadata BLOB NOT NULL
    )
  ''');
  database.execute('''
    CREATE TABLE private_documents_v8 (
      id TEXT NOT NULL PRIMARY KEY,
      driver_id TEXT REFERENCES driver_profiles(id) ON DELETE CASCADE,
      vehicle_id TEXT REFERENCES vehicles(id) ON DELETE CASCADE,
      preparation_id TEXT REFERENCES wallet_preparations(id) ON DELETE CASCADE,
      type TEXT NOT NULL CHECK (length(type) BETWEEN 1 AND 32),
      encrypted_metadata BLOB NOT NULL,
      imported_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
      CHECK ((driver_id IS NOT NULL) + (vehicle_id IS NOT NULL) +
        (preparation_id IS NOT NULL) = 1)
    )
  ''');
  database.execute('''
    INSERT INTO private_documents_v8
      (id, driver_id, vehicle_id, type, encrypted_metadata, imported_at)
    SELECT id, driver_id, vehicle_id, type, encrypted_metadata, imported_at
    FROM private_documents
  ''');
  database.execute('DROP TABLE private_documents');
  database.execute(
    'ALTER TABLE private_documents_v8 RENAME TO private_documents',
  );
  database.execute(
    'CREATE UNIQUE INDEX private_documents_driver_type_idx '
    'ON private_documents (driver_id, type)',
  );
  database.execute(
    'CREATE UNIQUE INDEX private_documents_vehicle_type_idx '
    'ON private_documents (vehicle_id, type)',
  );
  database.execute(
    'CREATE UNIQUE INDEX private_documents_preparation_type_idx '
    'ON private_documents (preparation_id, type)',
  );
}
