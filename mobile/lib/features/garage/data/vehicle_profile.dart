enum VehicleKind {
  car('car'),
  motorcycle('motorcycle');

  const VehicleKind(this.value);

  final String value;

  static VehicleKind fromValue(String value) {
    return switch (value) {
      'car' => VehicleKind.car,
      'motorcycle' => VehicleKind.motorcycle,
      _ => throw ArgumentError.value(
        value,
        'kind',
        'Unsupported vehicle kind.',
      ),
    };
  }
}

enum VehicleServiceType {
  private('private'),
  taxi('taxi');

  const VehicleServiceType(this.value);

  final String value;

  static VehicleServiceType fromValue(String value) {
    return switch (value) {
      'private' => VehicleServiceType.private,
      'taxi' => VehicleServiceType.taxi,
      _ => throw ArgumentError.value(
        value,
        'serviceType',
        'Unsupported vehicle service type.',
      ),
    };
  }
}

class VehicleProfile {
  const VehicleProfile({
    required this.id,
    required this.plate,
    required this.kind,
    required this.serviceType,
    required this.createdAt,
    required this.updatedAt,
    this.subtype,
    this.nickname,
    this.registrationCity,
    this.brand,
    this.model,
    this.year,
    this.color,
    this.fuel,
  });

  final String id;
  final String plate;
  final VehicleKind kind;
  final VehicleServiceType serviceType;
  final String? subtype;
  final String? nickname;
  final String? registrationCity;
  final String? brand;
  final String? model;
  final int? year;
  final String? color;
  final String? fuel;
  final DateTime createdAt;
  final DateTime updatedAt;
}
