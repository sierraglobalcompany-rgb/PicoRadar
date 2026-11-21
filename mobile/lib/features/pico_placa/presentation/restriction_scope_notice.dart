import '../../garage/data/vehicle_profile.dart';

String? bogotaUrbanRestrictionScopeNotice({
  required String jurisdictionId,
  required VehicleKind vehicleKind,
  required VehicleServiceType serviceType,
  required DateTime localDate,
}) {
  if (vehicleKind != VehicleKind.car ||
      jurisdictionId != 'co-dc-bogota' ||
      serviceType != VehicleServiceType.private ||
      localDate.year != 2026 ||
      localDate.month != 11) {
    return null;
  }
  if (localDate.day == 2 || localDate.day == 16) {
    return 'Restricción ordinaria urbana no aplica; retorno regional no evaluado.';
  }
  return 'Solo pico y placa urbano general. No evalúa retorno regional por corredores ni excepciones individuales.';
}
