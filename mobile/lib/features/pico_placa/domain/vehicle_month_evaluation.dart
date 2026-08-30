import '../../garage/data/vehicle_profile.dart';
import '../data/restriction_store.dart';
import 'restriction_day_evaluation.dart';

class VehicleMonthDayEvaluation {
  const VehicleMonthDayEvaluation({
    required this.date,
    required this.evaluation,
  });

  final DateTime date;
  final RestrictionDayEvaluation evaluation;
}

List<VehicleMonthDayEvaluation> evaluateVehicleMonth({
  required RestrictionRuleSet ruleSet,
  required String jurisdictionId,
  required VehicleProfile vehicle,
  required int year,
  required int month,
}) {
  final daysInMonth = DateTime(year, month + 1, 0).day;
  return [
    for (var day = 1; day <= daysInMonth; day += 1)
      VehicleMonthDayEvaluation(
        date: DateTime(year, month, day),
        evaluation: evaluateRestrictionDay(
          ruleSet: ruleSet,
          jurisdictionId: jurisdictionId,
          plate: vehicle.plate,
          vehicleKind: vehicle.kind,
          serviceType: vehicle.serviceType,
          date: DateTime(year, month, day),
        ),
      ),
  ];
}
