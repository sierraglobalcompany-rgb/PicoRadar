import 'dart:math';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/storage/app_preferences.dart';
import '../../visual_assets/data/visual_asset_preferences.dart';
import 'vehicle_profile.dart';

typedef VehicleIdGenerator = String Function();

class VehicleRepository {
  VehicleRepository({
    required this.database,
    required this.preferences,
    VehicleIdGenerator? idGenerator,
  }) : _idGenerator = idGenerator ?? _secureId;

  static const activeVehiclePreferenceKey = 'active_vehicle_id_v1';

  final AppDatabase database;
  final AppPreferences preferences;
  final VehicleIdGenerator _idGenerator;

  Future<List<VehicleProfile>> listVehicles() async {
    final rows =
        await (database.select(database.vehicles)..orderBy([
              (row) => OrderingTerm(
                expression: row.createdAt,
                mode: OrderingMode.desc,
              ),
            ]))
            .get();
    return rows.map(_vehicleFromRow).toList(growable: false);
  }

  Future<VehicleProfile?> getVehicle(String id) async {
    final row = await _vehicleRow(id);
    return row == null ? null : _vehicleFromRow(row);
  }

  Future<VehicleProfile> createVehicle({
    required String plate,
    required VehicleKind kind,
    VehicleServiceType serviceType = VehicleServiceType.private,
    String? subtype,
    String? nickname,
    String? registrationCity,
    String? brand,
    String? model,
    int? year,
    String? color,
    String? fuel,
  }) async {
    final now = DateTime.now().toUtc();
    _validateYear(year, now);
    _validateServiceType(kind, serviceType);
    final id = _idGenerator();
    final normalizedPlate = normalizePlate(plate);

    await database
        .into(database.vehicles)
        .insert(
          VehiclesCompanion.insert(
            id: id,
            plate: normalizedPlate,
            kind: Value(kind.value),
            serviceType: Value(serviceType.value),
            subtype: Value(_optionalText(subtype)),
            nickname: Value(_optionalText(nickname)),
            registrationCity: Value(_optionalText(registrationCity)),
            brand: Value(_optionalText(brand)),
            model: Value(_optionalText(model)),
            year: Value(year),
            color: Value(_optionalText(color)),
            fuel: Value(_optionalText(fuel)),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    return (await getVehicle(id))!;
  }

  Future<VehicleProfile> updateVehicle({
    required String id,
    required String plate,
    required VehicleKind kind,
    VehicleServiceType serviceType = VehicleServiceType.private,
    String? subtype,
    String? nickname,
    String? registrationCity,
    String? brand,
    String? model,
    int? year,
    String? color,
    String? fuel,
  }) async {
    final existing = await _vehicleRow(id);
    if (existing == null) {
      throw VehicleRepositoryException('Vehicle does not exist: $id.');
    }

    final timestamp = DateTime.now().toUtc();
    final minimumUpdatedAt = existing.updatedAt.add(const Duration(seconds: 1));
    final now = timestamp.isAfter(minimumUpdatedAt)
        ? timestamp
        : minimumUpdatedAt;
    _validateYear(year, now);
    _validateServiceType(kind, serviceType);
    await (database.update(
      database.vehicles,
    )..where((row) => row.id.equals(id))).write(
      VehiclesCompanion(
        plate: Value(normalizePlate(plate)),
        kind: Value(kind.value),
        serviceType: Value(serviceType.value),
        subtype: Value(_optionalText(subtype)),
        nickname: Value(_optionalText(nickname)),
        registrationCity: Value(_optionalText(registrationCity)),
        brand: Value(_optionalText(brand)),
        model: Value(_optionalText(model)),
        year: Value(year),
        color: Value(_optionalText(color)),
        fuel: Value(_optionalText(fuel)),
        updatedAt: Value(now),
      ),
    );

    return (await getVehicle(id))!;
  }

  Future<void> deleteVehicle(String id) async {
    await (database.delete(
      database.vehicles,
    )..where((row) => row.id.equals(id))).go();

    final activeId = await preferences.getString(activeVehiclePreferenceKey);
    if (activeId == id) {
      await preferences.remove(activeVehiclePreferenceKey);
    }
    await clearVehicleVisualOverride(preferences, id);
  }

  Future<VehicleProfile?> getActiveVehicle() async {
    final activeId = await preferences.getString(activeVehiclePreferenceKey);
    if (activeId == null || activeId.isEmpty) {
      return null;
    }

    final vehicle = await getVehicle(activeId);
    if (vehicle == null) {
      await preferences.remove(activeVehiclePreferenceKey);
    }
    return vehicle;
  }

  Future<void> setActiveVehicle(String id) async {
    if (await _vehicleRow(id) == null) {
      throw VehicleRepositoryException('Vehicle does not exist: $id.');
    }
    await preferences.setString(activeVehiclePreferenceKey, id);
  }

  Future<void> clearActiveVehicle() async {
    await preferences.remove(activeVehiclePreferenceKey);
  }

  static String normalizePlate(String plate) {
    final normalized = plate.trim().toUpperCase().replaceAll(
      RegExp(r'[\s-]+'),
      '',
    );

    if (normalized.isEmpty) {
      throw const VehicleRepositoryException('Plate is required.');
    }
    if (normalized.length > 12) {
      throw const VehicleRepositoryException('Plate is too long.');
    }
    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(normalized)) {
      throw const VehicleRepositoryException(
        'Plate must contain only letters and numbers.',
      );
    }
    return normalized;
  }

  Future<Vehicle?> _vehicleRow(String id) async {
    final rows = await (database.select(
      database.vehicles,
    )..where((row) => row.id.equals(id))).get();
    return rows.isEmpty ? null : rows.single;
  }

  VehicleProfile _vehicleFromRow(Vehicle row) {
    return VehicleProfile(
      id: row.id,
      plate: row.plate,
      kind: VehicleKind.fromValue(row.kind),
      serviceType: VehicleServiceType.fromValue(row.serviceType),
      subtype: row.subtype,
      nickname: row.nickname,
      registrationCity: row.registrationCity,
      brand: row.brand,
      model: row.model,
      year: row.year,
      color: row.color,
      fuel: row.fuel,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  static String _secureId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  String? _optionalText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  void _validateYear(int? year, DateTime now) {
    if (year == null) {
      return;
    }
    if (year < 1900 || year > now.year + 1) {
      throw VehicleRepositoryException('Vehicle year is out of range: $year.');
    }
  }

  void _validateServiceType(VehicleKind kind, VehicleServiceType serviceType) {
    if (kind == VehicleKind.motorcycle &&
        serviceType != VehicleServiceType.private) {
      throw const VehicleRepositoryException(
        'Motorcycles can only use private service type.',
      );
    }
  }
}

class VehicleRepositoryException implements Exception {
  const VehicleRepositoryException(this.message);

  final String message;

  @override
  String toString() => 'VehicleRepositoryException: $message';
}
