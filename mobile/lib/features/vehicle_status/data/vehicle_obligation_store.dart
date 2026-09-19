import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../../alerts/data/alert_settings.dart';
import '../domain/vehicle_obligation.dart';

class VehicleObligationStore {
  const VehicleObligationStore(this.database);

  final db.AppDatabase database;

  Future<VehicleObligation?> get(
    String vehicleId,
    VehicleObligationType type,
  ) async {
    final rows =
        await (database.select(database.vehicleObligations)..where(
              (row) => row.id.equals(vehicleObligationId(vehicleId, type)),
            ))
            .get();
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  Future<List<VehicleObligation>> listForVehicle(String vehicleId) async {
    final rows =
        await (database.select(database.vehicleObligations)
              ..where((row) => row.vehicleId.equals(vehicleId))
              ..orderBy([(row) => OrderingTerm(expression: row.type)]))
            .get();
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<List<VehicleObligation>> listAll() async {
    final rows =
        await (database.select(database.vehicleObligations)..orderBy([
              (row) => OrderingTerm(expression: row.vehicleId),
              (row) => OrderingTerm(expression: row.type),
            ]))
            .get();
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<VehicleObligation> upsert({
    required String vehicleId,
    required VehicleObligationType type,
    DateTime? startDate,
    DateTime? dueDate,
    Map<String, String> details = const {},
    bool reminderEnabled = true,
  }) => database.transaction(() async {
    final id = vehicleObligationId(vehicleId, type);
    final now = DateTime.now().toUtc();
    final existing = await get(vehicleId, type);
    var effectiveReminder = reminderEnabled;
    if (existing == null) {
      final category = switch (type) {
        VehicleObligationType.soat => AlertCategory.soat,
        VehicleObligationType.rtm => AlertCategory.rtm,
        VehicleObligationType.insurance => AlertCategory.insurance,
        VehicleObligationType.tax => null,
      };
      if (category != null) {
        final saved = await AlertSettingsStore(database)
            .load(vehicleId, category);
        // Inherit the pre-creation choice once; later module edits own the flag.
        effectiveReminder = saved?.enabled ?? reminderEnabled;
      }
    }
    await database
        .into(database.vehicleObligations)
        .insertOnConflictUpdate(
          db.VehicleObligationsCompanion.insert(
            id: id,
            vehicleId: vehicleId,
            type: type.value,
            status: 'configured',
            startDate: Value(_dateOnly(startDate)),
            dueDate: Value(_dateOnly(dueDate)),
            detailsJson: Value(encodeVehicleObligationDetails(details)),
            reminderEnabled: Value(effectiveReminder),
            createdAt: Value(existing?.createdAt ?? now),
            updatedAt: Value(now),
          ),
        );
    return (await get(vehicleId, type))!;
  });

  Future<void> delete(String vehicleId, VehicleObligationType type) async {
    await (database.delete(database.vehicleObligations)
          ..where((row) => row.id.equals(vehicleObligationId(vehicleId, type))))
        .go();
  }

  Future<VehicleObligation> saveTaxAuthority(
    String vehicleId,
    String authorityId,
  ) => database.transaction(() async {
    final chosen = authorityId.trim();
    if (chosen.isEmpty) throw ArgumentError.value(authorityId, 'authorityId');
    final vehicle = await (database.select(
      database.vehicles,
    )..where((row) => row.id.equals(vehicleId))).getSingleOrNull();
    if (vehicle == null) throw StateError('El vehículo ya no está disponible.');
    final current = await get(vehicleId, VehicleObligationType.tax);
    if (current?.details['authorityId'] == chosen) return current!;
    return upsert(
      vehicleId: vehicleId,
      type: VehicleObligationType.tax,
      startDate: current?.startDate,
      dueDate: current?.dueDate,
      details: {...?current?.details, 'authorityId': chosen},
      reminderEnabled: current?.reminderEnabled ?? false,
    );
  });

  VehicleObligation _fromRow(db.VehicleObligation row) {
    return VehicleObligation(
      id: row.id,
      vehicleId: row.vehicleId,
      type: VehicleObligationType.fromValue(row.type),
      startDate: row.startDate,
      dueDate: row.dueDate,
      details: parseVehicleObligationDetails(row.detailsJson),
      reminderEnabled: row.reminderEnabled,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  DateTime? _dateOnly(DateTime? value) {
    if (value == null) {
      return null;
    }
    return DateTime(value.year, value.month, value.day);
  }
}
