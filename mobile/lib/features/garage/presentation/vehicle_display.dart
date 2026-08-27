import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../data/vehicle_profile.dart';

String vehicleTypeLabel(VehicleProfile vehicle) {
  return switch ((vehicle.kind, vehicle.serviceType)) {
    (VehicleKind.car, VehicleServiceType.taxi) => 'Taxi',
    (VehicleKind.motorcycle, _) => 'Moto',
    _ => 'Carro particular',
  };
}

IconData vehicleIcon(VehicleProfile vehicle) {
  return switch ((vehicle.kind, vehicle.serviceType)) {
    (VehicleKind.car, VehicleServiceType.taxi) => Icons.local_taxi,
    (VehicleKind.motorcycle, _) => Icons.two_wheeler,
    _ => Icons.directions_car,
  };
}

Color vehicleAccent(VehicleProfile vehicle) {
  return switch ((vehicle.kind, vehicle.serviceType)) {
    (VehicleKind.car, VehicleServiceType.taxi) => AppColors.orange,
    (VehicleKind.motorcycle, _) => AppColors.blue,
    _ => AppColors.teal,
  };
}

String vehicleMakeModel(VehicleProfile vehicle) {
  return [
    vehicle.brand,
    vehicle.model,
  ].where((part) => part != null && part.trim().isNotEmpty).join(' ');
}
