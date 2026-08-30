import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_module.dart';

final moduleFeatureFlagsProvider = Provider<Map<String, bool>>((ref) {
  return const {};
});

const primaryModules = [
  AppModule(
    id: 'pico',
    title: 'Pico y placa',
    icon: Icons.event_available_outlined,
    requiresVehicle: false,
    destination: '/apps/pico',
    featureFlagKey: 'module_pico_enabled',
  ),
  AppModule(
    id: 'fotomultas',
    title: 'Fotomultas',
    icon: Icons.speed_outlined,
    requiresVehicle: false,
    destination: '/apps/module/fotomultas',
    featureFlagKey: 'module_fotomultas_enabled',
  ),
  AppModule(
    id: 'comparendos',
    title: 'Comparendos',
    icon: Icons.receipt_long_outlined,
    requiresVehicle: true,
    destination: '/apps/module/comparendos',
    featureFlagKey: 'module_comparendos_enabled',
  ),
  AppModule(
    id: 'soat',
    title: 'SOAT',
    icon: Icons.verified_user_outlined,
    requiresVehicle: true,
    destination: '/apps/module/soat',
    featureFlagKey: 'module_soat_enabled',
  ),
  AppModule(
    id: 'tecnomecanica',
    title: 'Tecnomecánica',
    icon: Icons.build_circle_outlined,
    requiresVehicle: true,
    destination: '/apps/module/tecnomecanica',
    featureFlagKey: 'module_tecnomecanica_enabled',
  ),
  AppModule(
    id: 'impuestos',
    title: 'Impuestos',
    icon: Icons.account_balance_outlined,
    requiresVehicle: true,
    destination: '/apps/module/impuestos',
    featureFlagKey: 'module_impuestos_enabled',
  ),
  AppModule(
    id: 'documentos',
    title: 'Documentos',
    icon: Icons.folder_copy_outlined,
    requiresVehicle: true,
    destination: '/apps/module/documentos',
    featureFlagKey: 'module_documentos_enabled',
  ),
  AppModule(
    id: 'seguro_asistencia',
    title: 'Seguro y asistencia',
    icon: Icons.health_and_safety_outlined,
    requiresVehicle: true,
    destination: '/apps/module/seguro_asistencia',
    featureFlagKey: 'module_seguro_asistencia_enabled',
  ),
  AppModule(
    id: 'defensa',
    title: 'Defensa',
    icon: Icons.gavel_outlined,
    requiresVehicle: true,
    destination: '/apps/module/defensa',
    featureFlagKey: 'module_defensa_enabled',
  ),
];

const secondaryModules = [
  AppModule(
    id: 'servicios',
    title: 'Servicios',
    icon: Icons.handyman_outlined,
    requiresVehicle: false,
    destination: '/apps/module/servicios',
    featureFlagKey: 'module_servicios_enabled',
  ),
  AppModule(
    id: 'compra_venta',
    title: 'Compra/Venta',
    icon: Icons.sell_outlined,
    requiresVehicle: false,
    destination: '/apps/module/compra_venta',
    featureFlagKey: 'module_compra_venta_enabled',
  ),
  AppModule(
    id: 'tramites',
    title: 'Trámites',
    icon: Icons.assignment_outlined,
    requiresVehicle: false,
    destination: '/apps/module/tramites',
    featureFlagKey: 'module_tramites_enabled',
  ),
  AppModule(
    id: 'peritajes',
    title: 'Peritajes',
    icon: Icons.fact_check_outlined,
    requiresVehicle: false,
    destination: '/apps/module/peritajes',
    featureFlagKey: 'module_peritajes_enabled',
  ),
  AppModule(
    id: 'talleres',
    title: 'Talleres',
    icon: Icons.car_repair_outlined,
    requiresVehicle: false,
    destination: '/apps/module/talleres',
    featureFlagKey: 'module_talleres_enabled',
  ),
  AppModule(
    id: 'peajes_estado_vial',
    title: 'Peajes y estado vial',
    icon: Icons.route_outlined,
    requiresVehicle: false,
    destination: '/trip',
    featureFlagKey: 'module_peajes_estado_vial_enabled',
  ),
];

List<AppModule> visibleModules(
  Iterable<AppModule> modules,
  Map<String, bool> flags,
) {
  return modules
      .where((module) {
        final key = module.featureFlagKey;
        return key == null || (flags[key] ?? true);
      })
      .toList(growable: false);
}

AppModule? findModuleById(String id) {
  for (final module in [...primaryModules, ...secondaryModules]) {
    if (module.id == id) {
      return module;
    }
  }
  return null;
}
