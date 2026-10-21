import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/branding.dart';
import '../../onboarding/data/registration_city_catalog.dart';
import '../data/vehicle_profile.dart';

class VehiclePlateBadge extends ConsumerWidget {
  const VehiclePlateBadge({
    required this.vehicle,
    this.compact = false,
    this.compactWidth = 96,
    this.micro = false,
    this.microNumberFontSize,
    super.key,
  });

  final VehicleProfile vehicle;
  final bool compact;
  final double compactWidth;
  final bool micro;
  final double? microNumberFontSize;

  static double contentHeight(
    BuildContext context,
    VehicleProfile vehicle,
    double width, {
    double compactWidth = 96,
  }) {
    final raw = vehicle.registrationCity?.trim() ?? '';
    final caption = vehicle.kind == VehicleKind.motorcycle || raw.isEmpty
        ? 'COLOMBIA'
        : raw.toUpperCase();
    return ColombianPlateBadge.detailedHeight(
      plate: vehicle.plate,
      registration: caption,
      width: width,
      textScaler: MediaQuery.textScalerOf(context),
      compactWidth: compactWidth,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registration = vehicle.registrationCity?.trim() ?? '';
    final isMotorcycle = vehicle.kind == VehicleKind.motorcycle;
    var caption = 'COLOMBIA';
    if (!isMotorcycle && registration.isNotEmpty) {
      // Local, shared load; never part of the critical startup barrier.
      final catalog = ref.watch(registrationCityCatalogProvider);
      caption =
          catalog.asData?.value.plateMunicipality(registration) ?? registration;
    }
    return ColombianPlateBadge(
      plate: vehicle.plate,
      compact: compact,
      compactWidth: compactWidth,
      micro: micro,
      microNumberFontSize: microNumberFontSize,
      detailed: true,
      registrationLabel: caption.toUpperCase(),
      publicService:
          !isMotorcycle && vehicle.serviceType == VehicleServiceType.taxi,
    );
  }
}
