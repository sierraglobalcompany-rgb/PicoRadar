import 'dart:async';
import 'dart:convert';
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

TripPlanRequest _request({bool confirmed = true}) => TripPlanRequest(
  requestId: 'request-1',
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
