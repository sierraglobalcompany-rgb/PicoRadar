import 'dart:math';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import 'maintenance_record.dart';

typedef MaintenanceIdGenerator = String Function();

class MaintenanceRepository {
  MaintenanceRepository({
    required this.database,
    MaintenanceIdGenerator? idGenerator,
  }) : _idGenerator = idGenerator ?? _secureId;

  final db.AppDatabase database;
  final MaintenanceIdGenerator _idGenerator;

  Future<List<MaintenanceRecord>> listByVehicle(String vehicleId) async {
    final rows =
        await (database.select(database.maintenanceRecords)
              ..where((row) => row.vehicleId.equals(vehicleId))
              ..orderBy([
                (row) => OrderingTerm(
                  expression: row.serviceDate,
                  mode: OrderingMode.desc,
                ),
                (row) => OrderingTerm(
                  expression: row.createdAt,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<MaintenanceRecord?> get(String id) async {
    final rows = await (database.select(
      database.maintenanceRecords,
    )..where((row) => row.id.equals(id))).get();
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

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
    final now = DateTime.now().toUtc();
    final id = _idGenerator();
    final normalized = _normalizeInput(
      serviceDate: serviceDate,
      type: type,
      description: description,
      odometer: odometer,
      costCents: costCents,
      nextServiceDate: nextServiceDate,
      nextOdometer: nextOdometer,
    );

    await database
        .into(database.maintenanceRecords)
        .insert(
          db.MaintenanceRecordsCompanion.insert(
            id: id,
            vehicleId: vehicleId,
            serviceDate: normalized.serviceDate,
            odometer: Value(normalized.odometer),
            type: normalized.type,
            description: normalized.description,
            costCents: Value(normalized.costCents),
            nextServiceDate: Value(normalized.nextServiceDate),
            nextOdometer: Value(normalized.nextOdometer),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    return (await get(id))!;
  }

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
    final existing = await get(id);
    if (existing == null) {
      throw MaintenanceRepositoryException(
        'Maintenance record does not exist: $id.',
      );
    }
    final normalized = _normalizeInput(
      serviceDate: serviceDate,
      type: type,
      description: description,
      odometer: odometer,
      costCents: costCents,
      nextServiceDate: nextServiceDate,
      nextOdometer: nextOdometer,
    );
    final timestamp = DateTime.now().toUtc();
    final minimumUpdatedAt = existing.updatedAt.add(const Duration(seconds: 1));
    final now = timestamp.isAfter(minimumUpdatedAt)
        ? timestamp
        : minimumUpdatedAt;

    await (database.update(
      database.maintenanceRecords,
    )..where((row) => row.id.equals(id))).write(
      db.MaintenanceRecordsCompanion(
        serviceDate: Value(normalized.serviceDate),
        odometer: Value(normalized.odometer),
        type: Value(normalized.type),
        description: Value(normalized.description),
        costCents: Value(normalized.costCents),
        nextServiceDate: Value(normalized.nextServiceDate),
        nextOdometer: Value(normalized.nextOdometer),
        updatedAt: Value(now),
      ),
    );

    return (await get(id))!;
  }

  Future<void> delete(String id) async {
    await (database.delete(
      database.maintenanceRecords,
    )..where((row) => row.id.equals(id))).go();
  }

  MaintenanceRecord _fromRow(db.MaintenanceRecord row) {
    return MaintenanceRecord(
      id: row.id,
      vehicleId: row.vehicleId,
      serviceDate: row.serviceDate,
      odometer: row.odometer,
      type: row.type,
      description: row.description,
      costCents: row.costCents,
      nextServiceDate: row.nextServiceDate,
      nextOdometer: row.nextOdometer,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  _MaintenanceInput _normalizeInput({
    required DateTime serviceDate,
    required String type,
    required String description,
    int? odometer,
    int? costCents,
    DateTime? nextServiceDate,
    int? nextOdometer,
  }) {
    final normalizedType = type.trim();
    final normalizedDescription = description.trim();
    if (normalizedType.isEmpty) {
      throw const MaintenanceRepositoryException('Type is required.');
    }
    if (normalizedDescription.isEmpty) {
      throw const MaintenanceRepositoryException('Description is required.');
    }
    _validateNonNegative('odometer', odometer);
    _validateNonNegative('costCents', costCents);
    _validateNonNegative('nextOdometer', nextOdometer);
    return _MaintenanceInput(
      serviceDate: _dateOnly(serviceDate),
      type: normalizedType,
      description: normalizedDescription,
      odometer: odometer,
      costCents: costCents,
      nextServiceDate: _optionalDateOnly(nextServiceDate),
      nextOdometer: nextOdometer,
    );
  }

  void _validateNonNegative(String field, int? value) {
    if (value != null && value < 0) {
      throw MaintenanceRepositoryException('$field cannot be negative.');
    }
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime? _optionalDateOnly(DateTime? value) {
    return value == null ? null : _dateOnly(value);
  }

  static String _secureId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}

class _MaintenanceInput {
  const _MaintenanceInput({
    required this.serviceDate,
    required this.type,
    required this.description,
    this.odometer,
    this.costCents,
    this.nextServiceDate,
    this.nextOdometer,
  });

  final DateTime serviceDate;
  final String type;
  final String description;
  final int? odometer;
  final int? costCents;
  final DateTime? nextServiceDate;
  final int? nextOdometer;
}

class MaintenanceRepositoryException implements Exception {
  const MaintenanceRepositoryException(this.message);

  final String message;

  @override
  String toString() => 'MaintenanceRepositoryException: $message';
}
