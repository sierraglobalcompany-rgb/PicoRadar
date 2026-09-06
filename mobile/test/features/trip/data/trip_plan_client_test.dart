import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/trip/data/trip_municipality_catalog.dart';
import 'package:picoradar/features/trip/data/trip_plan_client.dart';
import 'package:picoradar/features/trip/domain/trip_plan.dart';

void main() {
  late Dio dio;
  late _Adapter adapter;
  late TripPlanClient client;
  setUp(() {
    adapter = _Adapter();
    dio = Dio()..httpClientAdapter = adapter;
    client = TripPlanClient(
      dio: dio,
      baseUri: Uri.parse('https://api.example.test'),
    );
  });
  tearDown(() => dio.close(force: true));

  test(
    'contradictory payable counts preserve route but invalidate tolls',
    () async {
      for (final count in [0, 2]) {
        adapter.body = _plan();
        adapter.body['routes'][0]['tolls']['stationCount'] = 2;
        adapter.body['routes'][0]['tolls']['payableCount'] = count;
        expect(
          (await client.preview(_request())).routes.single.tolls.coverage,
          TripTollCoverage.unknown,
        );
      }
      adapter.body = _plan();
      final tolls = adapter.body['routes'][0]['tolls'];
      tolls['coverage'] = 'no_charge_confirmed';
      tolls['totalMinor'] = 0;
      tolls['charges'] = [];
      tolls['stationCount'] = 1;
      tolls['payableCount'] = 1;
      expect(
        (await client.preview(_request())).routes.single.tolls.coverage,
        TripTollCoverage.unknown,
      );
    },
  );

  test('unconfirmed vehicle never reaches adapter', () async {
    await expectLater(
      client.preview(_request(confirmed: false)),
      throwsA(
        isA<TripPlanFailure>().having(
          (e) => e.code,
          'code',
          'unsupported_vehicle',
        ),
      ),
    );
    expect(adapter.calls, 0);
  });

  test('departure window error retains only bounded server limit', () async {
    adapter.status = 422;
    adapter.body = {
      'error': {
        'code': 'departure_window',
        'maxFutureDays': 7,
        'message': 'private server text',
      },
    };
    await expectLater(
      client.preview(_request()),
      throwsA(
        isA<TripPlanFailure>()
            .having((e) => e.code, 'code', 'departure_window')
            .having((e) => e.maxFutureDays, 'days', 7),
      ),
    );
    expect(adapter.calls, 1);
  });

  test(
    'partial positive subtotal cannot claim zero payable occurrences',
    () async {
      final tolls = adapter.body['routes'][0]['tolls'];
      tolls['coverage'] = 'partial';
      tolls['totalMinor'] = null;
      tolls['subtotalMinor'] = 1200000;
      tolls['missingRates'] = 1;
      tolls['charges'].add({'name': 'Unknown station', 'amountMinor': null});
      tolls['stationCount'] = 2;
      tolls['payableCount'] = 0;
      final route = (await client.preview(_request())).routes.single;
      expect(route.distanceMeters, 400000);
      expect(route.tolls.coverage, TripTollCoverage.unknown);
    },
  );

  test(
    'overall deadline closes a slow continuous body without retry',
    () async {
      final stream = StreamController<Uint8List>();
      adapter.stream = stream.stream;
      final ticks = Timer.periodic(
        const Duration(milliseconds: 20),
        (_) => stream.add(Uint8List.fromList([32])),
      );
      final bounded = TripPlanClient(
        dio: dio,
        baseUri: Uri.parse('https://api.example.test'),
        operationTimeout: const Duration(milliseconds: 100),
      );
      try {
        await expectLater(
          bounded.preview(_request()),
          throwsA(
            isA<TripPlanFailure>().having((e) => e.code, 'code', 'timeout'),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(adapter.closed, isTrue);
        expect(adapter.calls, 1);
      } finally {
        ticks.cancel();
        unawaited(stream.close());
      }
    },
  );

  test(
    'only explicit safe fields leave phone; UTC and route identity retained',
    () async {
      final plan = await client.preview(_request());
      final body = adapter.last!.data as Map<String, Object?>;
      expect(body.keys.toSet(), {
        'requestId',
        'origin',
        'destination',
        'departureUtc',
        'timeZone',
        'vehicleCategory',
        'paymentMethod',
        'alternatives',
      });
      expect(jsonEncode(body), isNot(contains('PRIVATE123')));
      expect(jsonEncode(body), isNot(contains('private-vehicle')));
      expect(adapter.last!.uri.path, '/api/v1/trips/preview');
      expect(
        plan.routes.single.arrivalUtc(_request().departureUtc),
        DateTime.utc(2026, 9, 7, 8),
      );
      expect(plan.routes.single.tolls.totalMinor, 1200000);
      expect(adapter.calls, 1);
    },
  );
  test('unconfigured or unsafe endpoint never sends a request', () async {
    for (final uri in [
      null,
      Uri.parse('http://public.example'),
      Uri.parse('https://user:secret@api.example'),
    ]) {
      await expectLater(
        TripPlanClient(dio: dio, baseUri: uri).preview(_request()),
        throwsA(isA<TripPlanFailure>()),
      );
    }
    expect(adapter.calls, 0);
  });
  test('stale request ID and invalid values rejected', () async {
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (p) => p['requestId'] = 'old',
      (p) => p['routes'][0]['distanceMeters'] = -1,
      (p) => p['routes'][0]['durationSeconds'] = 'fast',
      (p) => p['routes'].add(p['routes'][0]),
      (p) => p['origin']['latitude'] = double.infinity,
    ]) {
      adapter.body = _plan();
      mutate(adapter.body);
      await expectLater(
        client.preview(_request()),
        throwsA(isA<TripPlanFailure>()),
      );
    }
  });
  test(
    'missing route geometry is rejected without fabricating a route',
    () async {
      adapter.body = _plan();
      adapter.body['routes'][0].remove('geometry');

      await expectLater(
        client.preview(_request()),
        throwsA(
          isA<TripPlanFailure>().having(
            (error) => error.code,
            'code',
            'invalid_upstream',
          ),
        ),
      );
    },
  );
  test(
    'decodes ordered GeoJSON coordinates as immutable route geometry',
    () async {
      final geometry = (await client.preview(_request()))
          .routes
          .single
          .geometry;

      expect(geometry, hasLength(3));
      expect(geometry[0].latitude, 6.24);
      expect(geometry[0].longitude, -75.58);
      expect(geometry[1].latitude, 5.5);
      expect(geometry[1].longitude, -75.0);
      expect(geometry[2].latitude, 4.60);
      expect(geometry[2].longitude, -74.08);
      expect(
        () =>
            geometry.add(const TripCoordinate(latitude: 4.7, longitude: -74.2)),
        throwsUnsupportedError,
      );
    },
  );
  test('accepts the PHP-normalized boundary fixture', () async {
    adapter.body = jsonDecode(
      File('test/fixtures/trip/tollguru_normalized_plan.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;

    final route = (await client.preview(_request(requestId: 'trip-test-001')))
        .routes
        .single;

    expect(
      route.id,
      'b0e15b7c343826ec635f703f9ecda9dc23897181d986e6fae4b752434b00cb8f',
    );
    expect(route.geometry, hasLength(3));
    expect(route.geometry.first.latitude, 6.2442);
    expect(route.geometry.first.longitude, -75.5812);
    expect(route.geometry.last.latitude, 6.1533);
    expect(route.geometry.last.longitude, -75.374);
    expect(route.tolls.totalMinor, 1800030);
  });
  test(
    'accepts three routes at the 3000-coordinate transport ceiling',
    () async {
      adapter.body = _planWithRoutes(3000);
      final encodedPayload = utf8.encode(jsonEncode(adapter.body));

      expect(encodedPayload.length, greaterThan(150000));
      expect(encodedPayload.length, lessThanOrEqualTo(262144));

      final routes = (await client.preview(_request())).routes;

      expect(routes, hasLength(3));
      for (final route in routes) {
        expect(route.geometry, hasLength(3000));
      }
    },
  );
  test('rejects route geometry above the 3000-coordinate ceiling', () async {
    adapter.body = _plan();
    adapter.body['routes'][0]['geometry']['coordinates'] =
        _colombianCoordinates(3001);

    await expectLater(
      client.preview(_request()),
      throwsA(
        isA<TripPlanFailure>().having(
          (error) => error.code,
          'code',
          'invalid_upstream',
        ),
      ),
    );
  });
  test('malformed route geometry is rejected as invalid upstream', () async {
    final invalidGeometries = <Object>[
      {'type': 'Point', 'coordinates': const []},
      {
        'type': 'LineString',
        'coordinates': const [
          [-75.58, 6.24],
        ],
      },
      {
        'type': 'LineString',
        'coordinates': const [
          [-75.58, 6.24],
          [-74.08, 181],
        ],
      },
      {
        'type': 'LineString',
        'coordinates': const [
          [-75.58, 6.24],
          [-181, 4.60],
        ],
      },
      {
        'type': 'LineString',
        'coordinates': const [
          [-75.58, 6.24, 1000],
          [-74.08, 4.60],
        ],
      },
    ];

    for (final geometry in invalidGeometries) {
      adapter.body = _plan();
      adapter.body['routes'][0]['geometry'] = geometry;

      await expectLater(
        client.preview(_request()),
        throwsA(
          isA<TripPlanFailure>().having(
            (error) => error.code,
            'code',
            'invalid_upstream',
          ),
        ),
        reason: 'must reject $geometry',
      );
    }
  });
  test(
    'bad toll data preserves real route km and ETA with unknown coverage',
    () async {
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (t) => t['currency'] = 'USD',
        (t) => t['totalMinor'] = 1200001,
        (t) => t['totalMinor'] = 1.5,
      ]) {
        adapter.body = _plan();
        mutate(adapter.body['routes'][0]['tolls']);
        final route = (await client.preview(_request())).routes.single;
        expect(route.distanceMeters, 400000);
        expect(route.tolls.coverage, TripTollCoverage.unknown);
        expect(route.tolls.totalMinor, isNull);
      }
    },
  );
  test(
    'unknown empty toll list is not zero; partial has subtotal only',
    () async {
      adapter.body = _plan();
      adapter.body['routes'][0]['tolls'] = {
        'coverage': 'unknown',
        'currency': 'COP',
        'vehicleCategory': 'car',
        'paymentMethod': 'cash',
        'charges': [],
        'missingRates': 0,
      };
      expect(
        (await client.preview(_request())).routes.single.tolls.totalMinor,
        isNull,
      );
      adapter.body['routes'][0]['tolls']['coverage'] = 'partial';
      adapter.body['routes'][0]['tolls']['subtotalMinor'] = 0;
      adapter.body['routes'][0]['tolls']['missingRates'] = 1;
      expect(
        (await client.preview(_request())).routes.single.tolls.coverage,
        TripTollCoverage.partial,
      );
    },
  );
  test(
    'server failure is allowlisted without raw secret or POST retry',
    () async {
      for (final status in [401, 403, 429, 500, 502, 504]) {
        adapter.status = status;
        adapter.body = {
          'error': {
            'code': 'secret-private-body',
            'message': 'PRIVATE123 secret',
          },
        };
        try {
          await client.preview(_request());
          fail('must fail');
        } on TripPlanFailure catch (e) {
          expect(e.toString(), isNot(contains('PRIVATE123')));
          expect(e.code, isNot('secret-private-body'));
        }
      }
      expect(adapter.calls, 6);
    },
  );
  test('cancellation never returns a completed plan', () async {
    final token = CancelToken()..cancel();
    await expectLater(
      client.preview(_request(), cancelToken: token),
      throwsA(isA<TripPlanFailure>()),
    );
    expect(adapter.calls, 0);
  });
}

TripPlanRequest _request({
  bool confirmed = true,
  String requestId = 'request-1',
}) => TripPlanRequest(
  requestId: requestId,
  origin: const TripMunicipality(
    code: '05001',
    municipality: 'Medellin',
    department: 'Antioquia',
  ),
  destination: const TripMunicipality(
    code: '11001',
    municipality: 'Bogota',
    department: 'Bogota',
  ),
  vehicle: VehicleProfile(
    id: 'private-vehicle',
    plate: 'PRIVATE123',
    kind: VehicleKind.car,
    serviceType: VehicleServiceType.private,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  ),
  departureUtc: DateTime.utc(2026, 9, 7, 4),
  standardVehicleConfirmed: confirmed,
);

Map<String, dynamic> _planWithRoutes(int vertices) {
  final plan = _plan();
  final template = plan['routes'][0];
  plan['routes'] = List.generate(3, (index) {
    final route = jsonDecode(jsonEncode(template)) as Map<String, dynamic>;
    route['id'] = 'route-${index + 1}';
    route['durationSeconds'] = 14400 + (index * 600);
    route['geometry']['coordinates'] = _colombianCoordinates(
      vertices,
      variant: index,
    );
    return route;
  });
  return plan;
}

List<List<double>> _colombianCoordinates(int count, {int variant = 0}) =>
    List.generate(count, (index) {
      final ratio = index / (count - 1);
      final offset = index > 0 && index < count - 1 ? variant * 0.00001 : 0;
      final latitude = double.parse(
        (6.24 + ((4.60 - 6.24) * ratio) + offset).toStringAsFixed(5),
      );
      final longitude = double.parse(
        (-75.58 + ((-74.08 + 75.58) * ratio)).toStringAsFixed(5),
      );
      return [longitude, latitude];
    }, growable: false);

Map<String, dynamic> _plan() => {
  'requestId': 'request-1',
  'generatedAtUtc': '2026-09-06T00:00:00Z',
  'provider': 'TollGuru',
  'attribution': 'TollGuru / MapUp',
  'origin': {
    'label': 'Medellin, Antioquia, Colombia',
    'latitude': 6.24,
    'longitude': -75.58,
  },
  'destination': {
    'label': 'Bogota, Colombia',
    'latitude': 4.60,
    'longitude': -74.08,
  },
  'routes': [
    {
      'id': 'route-1',
      'summary': 'Road fixture, tests only',
      'distanceMeters': 400000,
      'durationSeconds': 14400,
      'timeBasis': 'static',
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          [-75.58, 6.24],
          [-75.0, 5.5],
          [-74.08, 4.60],
        ],
      },
      'tolls': {
        'coverage': 'complete',
        'currency': 'COP',
        'totalMinor': 1200000,
        'subtotalMinor': null,
        'missingRates': 0,
        'paymentMethod': 'cash',
        'vehicleCategory': 'car',
        'charges': [
          {
            'name': 'Test station',
            'amountMinor': 1200000,
            'sourceUrl': 'https://tollguru.com',
            'effectiveAt': null,
          },
        ],
      },
    },
  ],
};

class _Adapter implements HttpClientAdapter {
  Stream<Uint8List>? stream;
  bool closed = false;
  Map<String, dynamic> body = _plan();
  int status = 200;
  int calls = 0;
  RequestOptions? last;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    last = options;
    if (stream != null) {
      return ResponseBody(stream!, status, onClose: () => closed = true);
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
