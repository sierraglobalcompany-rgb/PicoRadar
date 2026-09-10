import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/driving/domain/traffic_camera.dart';
import 'package:picoradar/features/trip/application/route_geometry_index.dart';
import 'package:picoradar/features/trip/application/trip_route_associations.dart';
import 'package:picoradar/features/trip/data/toll_inventory.dart';
import 'package:picoradar/features/trip/domain/trip_plan.dart';

void main() {
  const geometry = [
    TripCoordinate(latitude: 6.240, longitude: -75.580),
    TripCoordinate(latitude: 6.240, longitude: -75.570),
    TripCoordinate(latitude: 6.250, longitude: -75.570),
  ];

  test('associations are stably ordered by progress then location id', () {
    final result = const TripRouteAssociator(corridorMeters: 80).associate(
      routeId: 'route-a',
      geometry: geometry,
      tolls: [_toll('z', -75.572), _toll('a', -75.578)],
      cameras: [_camera('cam-z', -75.571), _camera('cam-a', -75.579)],
    );

    expect(result.tolls.map((item) => item.location.id), ['a', 'z']);
    expect(result.cameras.map((item) => item.location.id), ['cam-a', 'cam-z']);
    expect(
      result.cameras.every(
        (item) => item.certainty == RouteAssociationCertainty.nearbyUnconfirmed,
      ),
      isTrue,
    );
  });

  test('counts unique locations separately from repeated passages', () {
    const repeated = [
      TripCoordinate(latitude: 6.240, longitude: -75.580),
      TripCoordinate(latitude: 6.240, longitude: -75.570),
      TripCoordinate(latitude: 6.250, longitude: -75.570),
      TripCoordinate(latitude: 6.250, longitude: -75.580),
      TripCoordinate(latitude: 6.240, longitude: -75.580),
      TripCoordinate(latitude: 6.240, longitude: -75.570),
    ];

    final result = const TripRouteAssociator(corridorMeters: 30).associate(
      routeId: 'route-loop',
      geometry: repeated,
      tolls: [_toll('toll-1', -75.575, latitude: 6.2401)],
      cameras: const [],
    );

    expect(result.tolls, hasLength(2));
    expect(result.uniqueTollLocationCount, 1);
    expect(result.tolls.map((item) => item.passageIndex), [0, 1]);
  });

  test('toll metadata never becomes an active charge or invented tariff', () {
    final toll = _toll('toll-1', -75.575);
    final result = const TripRouteAssociator().associate(
      routeId: 'route-a',
      geometry: geometry,
      tolls: [toll],
      cameras: const [],
    );

    expect(
      result.tolls.single.certainty,
      RouteAssociationCertainty.nearbyUnconfirmed,
    );
    expect(result.tolls.single.location.chargeEventVerified, isFalse);
    expect(
      result.tolls.single.location.tariffsBySourceCategoryCop.values,
      everyElement(isNull),
    );
    expect(
      result.tolls.single.location.operationClassification,
      TollOperationClassification.inventoriedOperationNotConfirmed,
    );
  });

  test('unusable repeated geometry produces no route associations', () {
    final result = const TripRouteAssociator().associate(
      routeId: 'route-degenerate',
      geometry: const [
        TripCoordinate(latitude: 6.24, longitude: -75.58),
        TripCoordinate(latitude: 6.24, longitude: -75.58),
      ],
      tolls: [_toll('toll-1', -75.58, latitude: 6.24)],
      cameras: [_camera('camera-1', -75.58)],
    );

    expect(result.geometryQuality, RouteGeometryQuality.unavailable);
    expect(result.tolls, isEmpty);
    expect(result.cameras, isEmpty);
  });

  test('toll preview labels preserve every audited source classification', () {
    expect(
      _toll(
        'inventory',
        -75.575,
        classification:
            TollOperationClassification.inventoriedOperationNotConfirmed,
      ).previewOperationLabel,
      'Operación actual no confirmada por la fuente',
    );
    expect(
      _toll(
        'reported',
        -75.575,
        classification: TollOperationClassification.sourceReportsOperating,
      ).previewOperationLabel,
      'La fuente reporta operación; vigencia actual no confirmada',
    );
    expect(
      _toll(
        'historical',
        -75.575,
        classification: TollOperationClassification.nonOperationalHistorical,
      ).previewOperationLabel,
      'Registro histórico reportado como no operativo',
    );
    expect(
      _toll(
        'review',
        -75.575,
        classification: TollOperationClassification.damagedReviewRequired,
      ).previewOperationLabel,
      'Registro siniestrado; requiere revisión',
    );
  });

  test('associates 184 tolls and 360 cameras within a realistic budget', () {
    final realisticGeometry = List.generate(
      1001,
      (index) =>
          TripCoordinate(latitude: 6.24, longitude: -75.58 + index * 0.00001),
      growable: false,
    );
    final tolls = List.generate(
      184,
      (index) => _toll(
        'toll-$index',
        -75.5799 + (index / 184) * 0.0098,
        latitude: 6.2401,
      ),
      growable: false,
    );
    final cameras = List.generate(
      360,
      (index) => _camera('camera-$index', -75.5799 + (index / 360) * 0.0098),
      growable: false,
    );
    final stopwatch = Stopwatch()..start();

    final result = const TripRouteAssociator().associate(
      routeId: 'route-realistic-volume',
      geometry: realisticGeometry,
      tolls: tolls,
      cameras: cameras,
    );
    stopwatch.stop();

    expect(result.uniqueTollLocationCount, 184);
    expect(result.uniqueCameraLocationCount, 360);
    expect(
      stopwatch.elapsed,
      lessThan(const Duration(seconds: 2)),
      reason: 'Association work must stay outside frame-by-frame map updates.',
    );
  });
}

TollInventoryRecord _toll(
  String id,
  double longitude, {
  double latitude = 6.2402,
  TollOperationClassification classification =
      TollOperationClassification.inventoriedOperationNotConfirmed,
}) {
  return TollInventoryRecord(
    id: id,
    name: 'Peaje $id',
    exactSourceName: 'PEAJE $id',
    department: 'Antioquia',
    recordKind: TollRecordKind.physicalStation,
    operationStatusRaw: 'Inventariado',
    operationClassification: classification,
    latitude: latitude,
    longitude: longitude,
    chargeEventVerified: false,
    tariffsBySourceCategoryCop: const {
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
}

TrafficCamera _camera(String id, double longitude) {
  return TrafficCamera(
    id: id,
    department: 'Antioquia',
    municipality: 'Medellín',
    jurisdiction: 'Medellín',
    address: 'Vía de prueba',
    latitude: 6.2402,
    longitude: longitude,
    status: 'Aprobada',
    technology: null,
    kind: CameraKind.mixed,
    speedLimitKmh: null,
  );
}
