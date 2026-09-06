import 'dart:isolate';

import '../../driving/domain/traffic_camera.dart';
import '../data/toll_inventory.dart';
import '../domain/trip_plan.dart';
import 'trip_route_associations.dart';

class TripRouteAssociationRequest {
  const TripRouteAssociationRequest({
    required this.routeId,
    required this.geometry,
    required this.tollVersion,
    required this.tolls,
    required this.cameraVersion,
    required this.cameras,
  });

  final String routeId;
  final List<TripCoordinate> geometry;
  final String tollVersion;
  final List<TollInventoryRecord> tolls;
  final String cameraVersion;
  final List<TrafficCamera> cameras;
}

abstract interface class TripRouteAssociationResolver {
  Future<TripRouteAssociations> resolve(TripRouteAssociationRequest request);
}

typedef TripRouteAssociationCompute = Future<TripRouteAssociations> Function(
  TripRouteAssociationRequest request,
);

class CachedTripRouteAssociationResolver
    implements TripRouteAssociationResolver {
  CachedTripRouteAssociationResolver({TripRouteAssociationCompute? compute})
    : _compute = compute ?? _computeInIsolate;

  final TripRouteAssociationCompute _compute;
  final Map<_AssociationCacheKey, Future<TripRouteAssociations>> _cache = {};

  @override
  Future<TripRouteAssociations> resolve(TripRouteAssociationRequest request) {
    final key = _AssociationCacheKey(
      routeId: request.routeId,
      geometryIdentity: identityHashCode(request.geometry),
      tollVersion: request.tollVersion,
      cameraVersion: request.cameraVersion,
    );
    final cached = _cache[key];
    if (cached != null) {
      return cached;
    }
    final pending = _compute(request);
    _cache[key] = pending;
    pending.then<void>(
      (_) {},
      onError: (_, _) {
        _cache.remove(key);
      },
    );
    return pending;
  }
}

Future<TripRouteAssociations> _computeInIsolate(
  TripRouteAssociationRequest request,
) => Isolate.run(
  () => const TripRouteAssociator().associate(
    routeId: request.routeId,
    geometry: request.geometry,
    tolls: request.tolls,
    cameras: request.cameras,
  ),
);

class _AssociationCacheKey {
  const _AssociationCacheKey({
    required this.routeId,
    required this.geometryIdentity,
    required this.tollVersion,
    required this.cameraVersion,
  });

  final String routeId;
  final int geometryIdentity;
  final String tollVersion;
  final String cameraVersion;

  @override
  bool operator ==(Object other) =>
      other is _AssociationCacheKey &&
      routeId == other.routeId &&
      geometryIdentity == other.geometryIdentity &&
      tollVersion == other.tollVersion &&
      cameraVersion == other.cameraVersion;

  @override
  int get hashCode =>
      Object.hash(routeId, geometryIdentity, tollVersion, cameraVersion);
}
