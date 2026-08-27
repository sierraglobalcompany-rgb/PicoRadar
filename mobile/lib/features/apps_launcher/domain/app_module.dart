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
