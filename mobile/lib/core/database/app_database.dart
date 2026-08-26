import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

@TableIndex(name: 'vehicles_plate_idx', columns: {#plate}, unique: true)
class Vehicles extends Table {
  TextColumn get id => text()();
  TextColumn get plate => text().withLength(min: 1, max: 12)();
  TextColumn get nickname => text().nullable()();
  TextColumn get kind => text().withDefault(const Constant('car'))();
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
  DateTimeColumn get dueDate => dateTime().nullable()();
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
  DateTimeColumn get appliedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Vehicles,
    VehicleObligations,
    NotificationPreferences,
    DatasetVersions,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'picoradar'));

  static const currentSchemaVersion = 1;

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

    throw UnsupportedError(
      'No Drift migration path is defined from schema $from to $to.',
    );
  }
}
