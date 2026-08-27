import '../../../core/database/app_database.dart';
import '../../garage/data/vehicle_profile.dart';
import '../domain/restriction_rule.dart';
import 'restriction_dataset.dart';

class RestrictionRuleSet {
  const RestrictionRuleSet({
    required this.coverageKnown,
    required this.dataIsStale,
    required this.rules,
    this.jurisdictionName,
    this.verifiedAt,
    this.sourceUrls = const [],
  });

  final bool coverageKnown;
  final bool dataIsStale;
  final List<RestrictionRule> rules;
  final String? jurisdictionName;
  final DateTime? verifiedAt;
  final List<String> sourceUrls;
}

class RestrictionStore {
  const RestrictionStore(this.database);

  final AppDatabase database;

  Future<RestrictionRuleSet> loadCoverage(
    String jurisdictionId,
    VehicleKind vehicleKind,
    VehicleServiceType serviceType,
    DateTime now,
  ) async {
    final query = database.select(database.restrictionCoverages)
      ..where((row) => row.jurisdictionId.equals(jurisdictionId))
      ..where((row) => row.vehicleKind.equals(vehicleKind.value))
      ..where((row) => row.serviceType.equals(serviceType.value));
    final rows = await query.get();
    if (rows.isEmpty) {
      return const RestrictionRuleSet(
        coverageKnown: false,
        dataIsStale: false,
        rules: [],
      );
    }

    final row = rows.single;
    return RestrictionRuleSet(
      coverageKnown: true,
      dataIsStale: !now.toUtc().isBefore(row.staleAfter.toUtc()),
      rules: restrictionRulesFromJson(
        row.rulesJson,
        jurisdictionId: row.jurisdictionId,
        vehicleKind: vehicleKind,
        serviceType: serviceType,
      ),
      jurisdictionName: row.jurisdictionName,
      verifiedAt: row.verifiedAt,
      sourceUrls: restrictionSourceUrlsFromJson(row.sourceUrlsJson),
    );
  }
}
