import '../../driving/domain/traffic_camera.dart';
import '../data/toll_inventory.dart';
import '../domain/trip_plan.dart';
import 'route_geometry_index.dart';

enum RouteAssociationCertainty { nearbyUnconfirmed }

extension TollPreviewSemantics on TollInventoryRecord {
  String get previewOperationLabel => switch (operationClassification) {
    TollOperationClassification.inventoriedOperationNotConfirmed =>
      'Operación actual no confirmada por la fuente',
    TollOperationClassification.sourceReportsOperating =>
      'La fuente reporta operación; vigencia actual no confirmada',
    TollOperationClassification.nonOperationalHistorical =>
      'Registro histórico reportado como no operativo',
    TollOperationClassification.damagedReviewRequired =>
      'Registro siniestrado; requiere revisión',
  };
}

class TripRouteAssociation<T> {
  const TripRouteAssociation({
    required this.location,
    required this.passageIndex,
    required this.projection,
    required this.certainty,
  });

  final T location;
  final int passageIndex;
  final RouteProjection projection;
  final RouteAssociationCertainty certainty;
}

class TripRouteAssociations {
  TripRouteAssociations({
    required this.routeId,
    required this.geometryQuality,
    required List<TripRouteAssociation<TollInventoryRecord>> tolls,
    required List<TripRouteAssociation<TrafficCamera>> cameras,
  }) : tolls = List.unmodifiable(tolls),
       cameras = List.unmodifiable(cameras);

  final String routeId;
  final RouteGeometryQuality geometryQuality;
  final List<TripRouteAssociation<TollInventoryRecord>> tolls;
  final List<TripRouteAssociation<TrafficCamera>> cameras;

  int get uniqueTollLocationCount =>
      tolls.map((item) => item.location.id).toSet().length;

  int get uniqueCameraLocationCount =>
      cameras.map((item) => item.location.id).toSet().length;
}

class TripRouteAssociator {
  const TripRouteAssociator({
    this.corridorMeters = RouteGeometryIndex.defaultCorridorMeters,
  });

  final double corridorMeters;

  TripRouteAssociations associate({
    required String routeId,
    required List<TripCoordinate> geometry,
    required Iterable<TollInventoryRecord> tolls,
    required Iterable<TrafficCamera> cameras,
  }) {
    final index = RouteGeometryIndex(geometry);
    return TripRouteAssociations(
      routeId: routeId,
      geometryQuality: index.quality,
      tolls: _associateLocations<TollInventoryRecord>(
        index: index,
        locations: tolls,
        idOf: (record) => record.id,
        coordinateOf: (record) => TripCoordinate(
          latitude: record.latitude,
          longitude: record.longitude,
        ),
      ),
      cameras: _associateLocations<TrafficCamera>(
        index: index,
        locations: cameras,
        idOf: (camera) => camera.id,
        coordinateOf: (camera) => TripCoordinate(
          latitude: camera.latitude,
          longitude: camera.longitude,
        ),
      ),
    );
  }

  List<TripRouteAssociation<T>> _associateLocations<T>({
    required RouteGeometryIndex index,
    required Iterable<T> locations,
    required String Function(T) idOf,
    required TripCoordinate Function(T) coordinateOf,
  }) {
    final result = <TripRouteAssociation<T>>[];
    final orderedLocations = locations.toList()
      ..sort((left, right) => idOf(left).compareTo(idOf(right)));
    for (final location in orderedLocations) {
      final passages = index.projectPassages(
        coordinateOf(location),
        corridorMeters: corridorMeters,
      );
      for (
        var passageIndex = 0;
        passageIndex < passages.length;
        passageIndex++
      ) {
        result.add(
          TripRouteAssociation(
            location: location,
            passageIndex: passageIndex,
            projection: passages[passageIndex],
            certainty: RouteAssociationCertainty.nearbyUnconfirmed,
          ),
        );
      }
    }
    result.sort((left, right) {
      final along = left.projection.alongRouteMeters.compareTo(
        right.projection.alongRouteMeters,
      );
      if (along != 0) {
        return along;
      }
      final id = idOf(left.location).compareTo(idOf(right.location));
      return id != 0 ? id : left.passageIndex.compareTo(right.passageIndex);
    });
    return result;
  }
}

class TripRouteAssociationMemoizer {
  TripRouteAssociationMemoizer({this.associator = const TripRouteAssociator()});

  final TripRouteAssociator associator;
  _AssociationCacheKey? _key;
  TripRouteAssociations? _value;

  TripRouteAssociations resolve({
    required String routeId,
    required List<TripCoordinate> geometry,
    required String tollVersion,
    required List<TollInventoryRecord> tolls,
    required String cameraPackIdentity,
    required List<TrafficCamera> cameras,
  }) {
    final key = _AssociationCacheKey(
      routeId: routeId,
      geometry: geometry,
      tollVersion: tollVersion,
      tolls: tolls,
      cameraPackIdentity: cameraPackIdentity,
      cameras: cameras,
    );
    if (key.matches(_key) && _value != null) {
      return _value!;
    }
    _key = key;
    return _value = associator.associate(
      routeId: routeId,
      geometry: geometry,
      tolls: tolls,
      cameras: cameras,
    );
  }
}

class _AssociationCacheKey {
  const _AssociationCacheKey({
    required this.routeId,
    required this.geometry,
    required this.tollVersion,
    required this.tolls,
    required this.cameraPackIdentity,
    required this.cameras,
  });

  final String routeId;
  final List<TripCoordinate> geometry;
  final String tollVersion;
  final List<TollInventoryRecord> tolls;
  final String cameraPackIdentity;
  final List<TrafficCamera> cameras;

  bool matches(_AssociationCacheKey? other) =>
      other != null &&
      routeId == other.routeId &&
      identical(geometry, other.geometry) &&
      tollVersion == other.tollVersion &&
      identical(tolls, other.tolls) &&
      cameraPackIdentity == other.cameraPackIdentity &&
      identical(cameras, other.cameras);
}
