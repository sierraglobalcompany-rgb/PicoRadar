import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/garage/presentation/vehicle_display.dart';

void main() {
  final timestamp = DateTime.utc(2026, 1, 1);

  VehicleProfile vehicle(VehicleKind kind, VehicleServiceType serviceType) {
    return VehicleProfile(
      id: '${kind.value}-${serviceType.value}',
      plate: 'SYN123',
      kind: kind,
      serviceType: serviceType,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  test(
    'vehicle type labels preserve supported types and unknown fallbacks',
    () {
      final car = vehicle(VehicleKind.car, VehicleServiceType.private);
      final taxi = vehicle(VehicleKind.car, VehicleServiceType.taxi);
      final motorcycle = vehicle(
        VehicleKind.motorcycle,
        VehicleServiceType.private,
      );
      final unknown = vehicle(VehicleKind.bus, VehicleServiceType.private);

      expect(vehicleTypeLabel(car), 'Carro particular');
      expect(shortVehicleTypeLabel(car), 'Carro');
      expect(vehicleTypeLabel(taxi), 'Taxi');
      expect(shortVehicleTypeLabel(taxi), 'Taxi');
      expect(vehicleTypeLabel(motorcycle), 'Moto');
      expect(shortVehicleTypeLabel(motorcycle), 'Moto');
      expect(vehicleTypeLabel(unknown), 'Vehículo no disponible');
      expect(shortVehicleTypeLabel(unknown), 'No disponible');
    },
  );
}
