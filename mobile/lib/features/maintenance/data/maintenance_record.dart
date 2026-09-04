class MaintenanceRecord {
  const MaintenanceRecord({
    required this.id,
    required this.vehicleId,
    required this.serviceDate,
    required this.type,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    this.odometer,
    this.costCents,
    this.nextServiceDate,
    this.nextOdometer,
  });

  final String id;
  final String vehicleId;
  final DateTime serviceDate;
  final int? odometer;
  final String type;
  final String description;
  final int? costCents;
  final DateTime? nextServiceDate;
  final int? nextOdometer;
  final DateTime createdAt;
  final DateTime updatedAt;
}
