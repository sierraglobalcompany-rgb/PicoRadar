import 'package:flutter/material.dart';

class AppModule {
  const AppModule({
    required this.id,
    required this.title,
    required this.icon,
    required this.requiresVehicle,
    required this.destination,
    this.featureFlagKey,
  });

  final String id;
  final String title;
  final IconData icon;
  final bool requiresVehicle;
  final String destination;
  final String? featureFlagKey;
}

String appModuleLocation(AppModule module, String? vehicleId) {
  final normalizedVehicleId = vehicleId?.trim();
  if (!module.requiresVehicle ||
      normalizedVehicleId == null ||
      normalizedVehicleId.isEmpty ||
      module.destination == '/trip') {
    return module.destination;
  }

  final uri = Uri.parse(module.destination);
  return uri
      .replace(
        queryParameters: {
          ...uri.queryParameters,
          'vehicleId': normalizedVehicleId,
        },
      )
      .toString();
}
