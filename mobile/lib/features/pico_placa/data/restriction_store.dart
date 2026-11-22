import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../garage/data/vehicle_profile.dart';
import '../domain/restriction_rule.dart';
import 'restriction_dataset.dart';

class RestrictionRuleSet {
  const RestrictionRuleSet({
    required this.coverageKnown,
    required this.dataIsStale,
    required this.rules,
    this.coverageCompleteness = CoverageCompleteness.legacy,
    this.consultationEnabled = true,
    this.jurisdictionConsultationEnabled = true,
    this.jurisdictionName,
    this.verifiedAt,
    this.staleAfter,
    this.sourceUrls = const [],
  });

  final bool coverageKnown;
  final bool dataIsStale;
  final CoverageCompleteness coverageCompleteness;
  final bool consultationEnabled;
  final bool jurisdictionConsultationEnabled;
  final List<RestrictionRule> rules;
  final String? jurisdictionName;
  final DateTime? verifiedAt;
  final DateTime? staleAfter;
  final List<String> sourceUrls;
}

class RestrictionStore {
  const RestrictionStore(this.database);

  final AppDatabase database;

  Future<List<RestrictionJurisdiction>> listJurisdictions() async {
    final coverageRows =
        await (database.selectOnly(
                database.restrictionCoverages,
                distinct: true,
              )
              ..addColumns([
                database.restrictionCoverages.jurisdictionId,
                database.restrictionCoverages.jurisdictionName,
              ])
              ..orderBy([
                OrderingTerm.asc(
                  database.restrictionCoverages.jurisdictionName,
                ),
              ]))
            .get();
    final availabilityRows = await database
        .select(database.restrictionJurisdictionAvailability)
        .get();
    final availabilityById = {
      for (final row in availabilityRows) row.jurisdictionId: row,
    };

    return coverageRows
        .map((row) {
          final id = row.read(database.restrictionCoverages.jurisdictionId)!;
          final availability = availabilityById[id];
          return RestrictionJurisdiction(
            id: id,
            name: row.read(database.restrictionCoverages.jurisdictionName)!,
            municipalityCodes: availability == null
                ? null
                : List<String>.from(
                    jsonDecode(availability.municipalityCodesJson) as List,
                  ),
            consultationEnabled: availability?.consultationEnabled,
          );
        })
        .toList(growable: false);
  }

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
    final availability = await (database.select(
      database.restrictionJurisdictionAvailability,
    )..where((value) => value.jurisdictionId.equals(jurisdictionId))).get();
    final rulesJson = row.rulesJson;
    return RestrictionRuleSet(
      coverageKnown: true,
      dataIsStale: !now.toUtc().isBefore(row.staleAfter.toUtc()),
      rules: restrictionRulesFromJson(
        rulesJson,
        jurisdictionId: row.jurisdictionId,
        vehicleKind: vehicleKind,
        serviceType: serviceType,
        schemaVersion:
            row.coverageCompleteness == CoverageCompleteness.legacy.name
            ? 1
            : 2,
      ),
      coverageCompleteness: _coverageCompleteness(row.coverageCompleteness),
      consultationEnabled:
          restrictionConsultationEnabledFromJson(rulesJson),
      jurisdictionConsultationEnabled: availability.isEmpty
          ? true
          : availability.single.consultationEnabled,
      jurisdictionName: row.jurisdictionName,
      verifiedAt: row.verifiedAt,
      staleAfter: row.staleAfter,
      sourceUrls: restrictionSourceUrlsFromJson(row.sourceUrlsJson),
    );
  }
}

CoverageCompleteness _coverageCompleteness(String value) => switch (value) {
  'legacy' => CoverageCompleteness.legacy,
  'complete' => CoverageCompleteness.complete,
  'partial' => CoverageCompleteness.partial,
  _ => throw StateError('Invalid persisted restriction coverage completeness.'),
};

class RestrictionJurisdiction {
  const RestrictionJurisdiction({
    required this.id,
    required this.name,
    this.municipalityCodes,
    this.consultationEnabled,
  });

  final String id;
  final String name;
  final List<String>? municipalityCodes;
  final bool? consultationEnabled;
}
