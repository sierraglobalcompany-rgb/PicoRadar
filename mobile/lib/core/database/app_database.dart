import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

@TableIndex(name: 'vehicles_plate_idx', columns: {#plate}, unique: true)
class Vehicles extends Table {
  TextColumn get id => text()();
  TextColumn get plate => text().withLength(min: 1, max: 12)();
  TextColumn get nickname => text().nullable()();
  TextColumn get kind => text().withDefault(const Constant('car'))();
  TextColumn get serviceType => text().withDefault(const Constant('private'))();
  TextColumn get subtype => text().nullable()();
  TextColumn get registrationCity => text().nullable()();
  TextColumn get brand => text().nullable()();
  TextColumn get model => text().nullable()();
  IntColumn get year => integer().nullable()();
  TextColumn get color => text().nullable()();
  TextColumn get fuel => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'vehicle_obligations_vehicle_id_idx', columns: {#vehicleId})
@TableIndex(name: 'vehicle_obligations_due_date_idx', columns: {#dueDate})
class VehicleObligations extends Table {
  TextColumn get id => text()();
  TextColumn get vehicleId =>
      text().references(Vehicles, #id, onDelete: KeyAction.cascade)();
  TextColumn get type => text().withLength(min: 1, max: 32)();
  TextColumn get status => text().withLength(min: 1, max: 32)();
  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get detailsJson => text().nullable()();
  BoolColumn get reminderEnabled =>
      boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'maintenance_records_vehicle_id_idx', columns: {#vehicleId})
@TableIndex(
  name: 'maintenance_records_service_date_idx',
  columns: {#serviceDate},
)
class MaintenanceRecords extends Table {
  TextColumn get id => text()();
  TextColumn get vehicleId =>
      text().references(Vehicles, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get serviceDate => dateTime()();
  IntColumn get odometer => integer().nullable()();
  TextColumn get type => text().withLength(min: 1, max: 64)();
  TextColumn get description => text().withLength(min: 1, max: 500)();
  IntColumn get costCents => integer().nullable()();
  DateTimeColumn get nextServiceDate => dateTime().nullable()();
  IntColumn get nextOdometer => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class NotificationPreferences extends Table {
  TextColumn get id => text()();
  BoolColumn get restrictionAlertsEnabled =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get obligationRemindersEnabled =>
      boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(
  name: 'dataset_versions_dataset_key_idx',
  columns: {#datasetKey},
  unique: true,
)
class DatasetVersions extends Table {
  TextColumn get id => text()();
  TextColumn get datasetKey => text().withLength(min: 1, max: 64)();
  TextColumn get version => text().withLength(min: 1, max: 64)();
  TextColumn get sha256 => text().nullable()();
  TextColumn get status => text().withLength(min: 1, max: 32)();
  IntColumn get publicationRevision =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get appliedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(
  name: 'restriction_coverages_lookup_idx',
  columns: {#jurisdictionId, #vehicleKind, #serviceType},
  unique: true,
)
class RestrictionCoverages extends Table {
  TextColumn get id => text()();
  TextColumn get jurisdictionId => text().withLength(min: 1, max: 64)();
  TextColumn get jurisdictionName => text().withLength(min: 1, max: 128)();
  TextColumn get vehicleKind => text().withLength(min: 1, max: 32)();
  TextColumn get serviceType => text().withLength(min: 1, max: 32)();
  TextColumn get rulesJson => text()();
  DateTimeColumn get verifiedAt => dateTime()();
  DateTimeColumn get staleAfter => dateTime()();
  TextColumn get sourceUrlsJson => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Vehicles,
    VehicleObligations,
    MaintenanceRecords,
    NotificationPreferences,
    DatasetVersions,
    RestrictionCoverages,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'picoradar'));

  static const currentSchemaVersion = 6;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: _upgrade,
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _upgrade(Migrator migrator, int from, int to) async {
    if (from >= to) {
      return;
    }

    if (from == 1) {
      await migrator.addColumn(vehicles, vehicles.serviceType);
      await migrator.addColumn(vehicles, vehicles.subtype);
      await migrator.addColumn(vehicles, vehicles.registrationCity);
      await migrator.addColumn(vehicles, vehicles.brand);
      await migrator.addColumn(vehicles, vehicles.model);
      await migrator.addColumn(vehicles, vehicles.year);
      await migrator.addColumn(vehicles, vehicles.color);
      await migrator.addColumn(vehicles, vehicles.fuel);
      from = 2;
    }

    if (from == 2) {
      await migrator.createTable(restrictionCoverages);
      from = 3;
    }

    if (from == 3) {
      await migrator.addColumn(
        vehicleObligations,
        vehicleObligations.startDate,
      );
      await migrator.addColumn(
        vehicleObligations,
        vehicleObligations.detailsJson,
      );
      await migrator.addColumn(
        vehicleObligations,
        vehicleObligations.reminderEnabled,
      );
      from = 4;
    }

    if (from == 4) {
      await migrator.createTable(maintenanceRecords);
      from = 5;
    }

    if (from == 5) {
      final hasPublicationRevision = await _columnExists(
        'dataset_versions',
        'publication_revision',
      );
      if (!hasPublicationRevision) {
        await migrator.addColumn(
          datasetVersions,
          datasetVersions.publicationRevision,
        );
      }
      from = 6;
    }

    if (from == to) {
      return;
    }

    throw UnsupportedError(
      'No Drift migration path is defined from schema $from to $to.',
    );
  }

  Future<bool> _columnExists(String tableName, String columnName) async {
    final columns = await customSelect('PRAGMA table_info($tableName)').get();
    return columns.any((row) => row.read<String>('name') == columnName);
  }
}
