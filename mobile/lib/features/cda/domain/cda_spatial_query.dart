import 'package:latlong2/latlong.dart';

import '../data/cda_catalog.dart';
import '../data/cda_geography.dart';

class CdaSpatialBounds {
  const CdaSpatialBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  // Includes San Andres and Providencia as well as continental Colombia.
  static const national = CdaSpatialBounds(
    south: -4.3,
    west: -81.85,
    north: 13.6,
    east: -66.7,
  );
  final double south, west, north, east;

  bool contains(double latitude, double longitude) =>
      latitude >= south &&
      latitude <= north &&
      (west <= east
          ? longitude >= west && longitude <= east
          : longitude >= west || longitude <= east);
}

class CdaSpatialMatch {
  const CdaSpatialMatch({
    required this.entry,
    required this.site,
    this.distanceMeters,
  });
  final CdaCatalogEntry entry;
  final CdaSite site;
  final double? distanceMeters;
  LatLng get point => LatLng(site.latitude!, site.longitude!);
}

/// In-memory intersection only. Approval of the operational geography is the
/// caller's publication gate; individual site evidence is still checked here.
List<CdaSpatialMatch> queryCdaSites({
  required CdaCatalog catalog,
  required CdaGeography geography,
  required DateTime now,
  String query = '',
  String? departmentCode,
  String? municipality,
  Set<String> vehicleTypes = const {},
  LatLng? origin,
  double? radiusMeters,
  CdaSpatialBounds? bounds,
}) {
  final matching = searchCdaCatalog(catalog.entries, query);
  const distance = Distance(roundResult: false, calculator: Haversine());
  final results = <CdaSpatialMatch>[];
  for (final entry in matching) {
    final site = geography.byId[entry.id];
    if (site == null || !site.matches(entry) || !site.mapEligibleAt(now)) {
      continue;
    }
    final latitude = site.latitude!, longitude = site.longitude!;
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      continue;
    }
    if (departmentCode != null && entry.departmentCode != departmentCode) {
      continue;
    }
    if (municipality != null && entry.municipality != municipality) {
      continue;
    }
    if (!site.verifiedVehicleTypes(now).containsAll(vehicleTypes)) {
      continue;
    }
    if (bounds != null && !bounds.contains(latitude, longitude)) {
      continue;
    }
    final meters = origin == null
        ? null
        : distance(origin, LatLng(latitude, longitude));
    if (radiusMeters != null && (meters == null || meters > radiusMeters)) {
      continue;
    }
    results.add(
      CdaSpatialMatch(entry: entry, site: site, distanceMeters: meters),
    );
  }
  results.sort((a, b) {
    if (origin != null) {
      final byDistance = a.distanceMeters!.compareTo(b.distanceMeters!);
      if (byDistance != 0) {
        return byDistance;
      }
    }
    final byName = a.entry.name.compareTo(b.entry.name);
    return byName != 0 ? byName : a.entry.id.compareTo(b.entry.id);
  });
  return List.unmodifiable(results);
}

class CdaSpatialGroup {
  CdaSpatialGroup(Iterable<CdaSpatialMatch> members)
    : members = List.unmodifiable(members);
  final List<CdaSpatialMatch> members;
  CdaSpatialMatch get anchor => members.first;
}

/// World-projected logical pixels keep buckets stable while panning. The
/// representative is an actual sede, never an invented or reassigned point.
List<CdaSpatialGroup> groupCdaSites(
  Iterable<CdaSpatialMatch> matches, {
  required ({double x, double y}) Function(double latitude, double longitude)
  project,
  double cellSize = 64,
}) {
  if (!cellSize.isFinite || cellSize <= 0) {
    throw ArgumentError.value(cellSize, 'cellSize');
  }
  final sorted = matches.toList()
    ..sort((a, b) => a.entry.id.compareTo(b.entry.id));
  final cells = <(int, int), List<CdaSpatialMatch>>{};
  for (final match in sorted) {
    final pixel = project(match.site.latitude!, match.site.longitude!);
    final cell = ((pixel.x / cellSize).floor(), (pixel.y / cellSize).floor());
    cells.putIfAbsent(cell, () => []).add(match);
  }
  return List.unmodifiable(cells.values.map(CdaSpatialGroup.new));
}
