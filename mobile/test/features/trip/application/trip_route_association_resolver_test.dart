import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/driving/domain/traffic_camera.dart';
import 'package:picoradar/features/trip/application/route_geometry_index.dart';
import 'package:picoradar/features/trip/application/trip_route_association_resolver.dart';
import 'package:picoradar/features/trip/application/trip_route_associations.dart';
import 'package:picoradar/features/trip/data/toll_inventory.dart';
import 'package:picoradar/features/trip/domain/trip_plan.dart';

void main() {
  const geometry = [
    TripCoordinate(latitude: 6.240, longitude: -75.580),
    TripCoordinate(latitude: 6.250, longitude: -75.570),
  ];
  final tolls = [_toll()];
  final cameras = [_camera()];

  TripRouteAssociationRequest request({
    String routeId = 'route-a',
    String tollVersion = 'tolls-v1',
    String cameraVersion = 'cameras-v1',
    List<TripCoordinate> routeGeometry = geometry,
  }) => TripRouteAssociationRequest(
    routeId: routeId,
    geometry: routeGeometry,
    tollVersion: tollVersion,
    tolls: tolls,
    cameraVersion: cameraVersion,
    cameras: cameras,
  );

  test(
    'resolver caches one future per route and local dataset versions',
    () async {
      var computations = 0;
      final resolver = CachedTripRouteAssociationResolver(
        compute: (input) async {
          computations++;
          return const TripRouteAssociator().associate(
            routeId: input.routeId,
            geometry: input.geometry,
            tolls: input.tolls,
            cameras: input.cameras,
          );
        },
      );

      final first = resolver.resolve(request());
      final repeated = resolver.resolve(request());
      expect(identical(first, repeated), isTrue);
      await first;
      expect(computations, 1);

      await resolver.resolve(
        request(routeGeometry: List<TripCoordinate>.of(geometry)),
      );
      await resolver.resolve(request(routeId: 'route-b'));
      await resolver.resolve(
        request(routeId: 'route-b', tollVersion: 'tolls-v2'),
      );
      await resolver.resolve(
        request(
          routeId: 'route-b',
          tollVersion: 'tolls-v2',
          cameraVersion: 'cameras-v2',
        ),
      );
      expect(computations, 5);
    },
  );

  test('default resolver computes a valid snapshot asynchronously', () async {
    final result = await CachedTripRouteAssociationResolver().resolve(
      request(),
    );

    expect(result.geometryQuality, RouteGeometryQuality.polyline);
    expect(result.uniqueTollLocationCount, 1);
    expect(result.uniqueCameraLocationCount, 1);
  });
}

TollInventoryRecord _toll() => const TollInventoryRecord(
  id: 'toll-1',
  name: 'Peaje de prueba',
  exactSourceName: 'PEAJE DE PRUEBA',
  department: 'Antioquia',
  recordKind: TollRecordKind.physicalStation,
  operationStatusRaw: 'Inventariado',
  operationClassification:
      TollOperationClassification.inventoriedOperationNotConfirmed,
  latitude: 6.245,
  longitude: -75.575,
  chargeEventVerified: false,
  tariffsBySourceCategoryCop: {
    'category_1': null,
    'category_2': null,
    'category_3': null,
    'category_4': null,
    'category_5': null,
    'category_6': null,
    'category_7': null,
  },
  inventorySource: 'https://example.test/inventory',
  gpsSource: 'https://example.test/gps',
);

TrafficCamera _camera() => const TrafficCamera(
  id: 'camera-1',
  department: 'Antioquia',
  municipality: 'Medellín',
  jurisdiction: 'Medellín',
  address: 'Vía de prueba',
  latitude: 6.245,
  longitude: -75.575,
  status: 'Aprobada',
  technology: null,
  kind: CameraKind.mixed,
  speedLimitKmh: null,
);
