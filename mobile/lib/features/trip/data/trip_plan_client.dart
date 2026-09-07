import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/trip_plan.dart';

const tripDemoEnabled =
    bool.fromEnvironment('PICORADAR_TRIP_DEMO_ENABLED') &&
    String.fromEnvironment('APP_ENV') == 'dev' &&
    !kReleaseMode;

final tripPlanClientProvider = Provider<TripPlanClient>((ref) {
  if (tripDemoEnabled) {
    return const _DemoTripPlanClient();
  }
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 25),
      sendTimeout: const Duration(seconds: 10),
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  const configured = String.fromEnvironment('API_BASE_URL');
  return TripPlanClient(dio: dio, baseUri: Uri.tryParse(configured));
});

// Must match TollGuruTripPreview::MAX_GEOMETRY_POINTS.
const _maximumGeometryPoints = 3000;

abstract interface class TripPlanClient {
  factory TripPlanClient({
    required Dio dio,
    Uri? baseUri,
    Duration operationTimeout = const Duration(seconds: 30),
  }) {
    return _HttpTripPlanClient._(dio, baseUri, operationTimeout);
  }

  Future<TripPlan> preview(TripPlanRequest request, {CancelToken? cancelToken});
}

class _HttpTripPlanClient implements TripPlanClient {
  _HttpTripPlanClient._(this._dio, this._baseUri, this._operationTimeout);

  final Dio _dio;
  final Uri? _baseUri;
  final Duration _operationTimeout;

  @override
  Future<TripPlan> preview(
    TripPlanRequest request, {
    CancelToken? cancelToken,
  }) {
    final operationToken = CancelToken();
    if (cancelToken?.isCancelled ?? false) operationToken.cancel();
    cancelToken?.whenCancel.then((_) => operationToken.cancel());
    return _preview(request, cancelToken: operationToken).timeout(
      _operationTimeout,
      onTimeout: () {
        operationToken.cancel();
        throw const TripPlanFailure('timeout');
      },
    );
  }

  Future<TripPlan> _preview(
    TripPlanRequest request, {
    required CancelToken cancelToken,
  }) async {
    final base = _baseUri;
    if (base == null ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        (base.scheme != 'https' &&
            !(base.scheme == 'http' &&
                const {'localhost', '127.0.0.1', '::1'}.contains(base.host)))) {
      throw const TripPlanFailure('not_configured');
    }
    if (!request.standardVehicleConfirmed) {
      throw const TripPlanFailure('unsupported_vehicle');
    }
    try {
      final response = await _dio.post<ResponseBody>(
        base.resolve('/api/v1/trips/preview').toString(),
        data: request.toJson(),
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: false,
          maxRedirects: 0,
          validateStatus: (_) => true,
          headers: {'Accept': 'application/json'},
        ),
      );
      final body = response.data;
      if (body == null) throw const FormatException();
      final bytes = <int>[];
      try {
        await for (final chunk in body.stream.timeout(
          const Duration(seconds: 25),
        )) {
          if (bytes.length + chunk.length > 262144) {
            throw const FormatException();
          }
          bytes.addAll(chunk);
        }
      } finally {
        // Dio's public cancellation path closes its response and subscription.
        cancelToken.cancel();
      }
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      if (response.statusCode != 200) {
        final error = decoded['error'];
        final code = error is Map ? error['code'] : null;
        final safeCode = _safeCode(code, response.statusCode);
        throw TripPlanFailure(
          safeCode,
          maxFutureDays: safeCode == 'departure_window' && error is Map
              ? _integer(error['maxFutureDays'], minimum: 1, maximum: 30)
              : null,
        );
      }
      final plan = _parsePlan(decoded, request.vehicleCategory);
      if (plan.requestId != request.requestId) throw const FormatException();
      return plan;
    } on TripPlanFailure {
      rethrow;
    } on DioException catch (error) {
      throw TripPlanFailure(switch (error.type) {
        DioExceptionType.cancel => 'cancelled',
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout => 'timeout',
        _ => 'network',
      });
    } on TimeoutException {
      throw const TripPlanFailure('timeout');
    } on FormatException {
      throw const TripPlanFailure('invalid_upstream');
    } on TypeError {
      throw const TripPlanFailure('invalid_upstream');
    }
  }
}

class _DemoTripPlanClient implements TripPlanClient {
  const _DemoTripPlanClient();

  @override
  Future<TripPlan> preview(
    TripPlanRequest request, {
    CancelToken? cancelToken,
  }) async {
    if (cancelToken?.isCancelled ?? false) {
      throw const TripPlanFailure('cancelled');
    }
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (cancelToken?.isCancelled ?? false) {
      throw const TripPlanFailure('cancelled');
    }
    final medellinBogota =
        request.origin.code == '05001' && request.destination.code == '11001';
    return TripPlan(
      requestId: request.requestId,
      generatedAtUtc: DateTime.utc(2026, 9, 7, 15),
      provider: 'DEMO local PicoRadar',
      attribution: tripDemoWarningLabel,
      origin: TripResolvedPoint(
        label: request.origin.displayName,
        latitude: medellinBogota ? 6.2442 : 1.2136,
        longitude: medellinBogota ? -75.5812 : -77.2811,
      ),
      destination: TripResolvedPoint(
        label: request.destination.displayName,
        latitude: medellinBogota ? 4.7110 : 0.8303,
        longitude: medellinBogota ? -74.0721 : -77.6446,
      ),
      routes: medellinBogota
          ? _medellinBogotaRoutes(request.vehicleCategory)
          : _unknownCoverageRoutes(request.vehicleCategory),
    );
  }
}

List<TripRouteOption> _medellinBogotaRoutes(String category) => [
  TripRouteOption(
    id: 'demo-magdalena',
    summary: 'Ruta DEMO Magdalena Medio',
    distanceMeters: 415000,
    durationSeconds: 26400,
    timeBasis: 'static',
    geometry: const [
      TripCoordinate(latitude: 6.2442, longitude: -75.5812),
      TripCoordinate(latitude: 6.155, longitude: -75.365),
      TripCoordinate(latitude: 5.885, longitude: -74.85),
      TripCoordinate(latitude: 5.45, longitude: -74.7),
      TripCoordinate(latitude: 5.08, longitude: -74.45),
      TripCoordinate(latitude: 4.711, longitude: -74.0721),
    ],
    tolls: TripTolls(
      coverage: TripTollCoverage.complete,
      vehicleCategory: category,
      stationCount: 2,
      payableCount: 2,
      totalMinor: 5800000,
      charges: const [
        TripTollCharge(
          name: 'Peaje DEMO Alfa',
          amountMinor: 2800000,
          effectiveAt: '2026-09-01',
          sourceUrl: 'https://example.test/viaje-demo/peaje-alfa',
        ),
        TripTollCharge(
          name: 'Peaje DEMO Beta',
          amountMinor: 3000000,
          effectiveAt: '2026-09-01',
          sourceUrl: 'https://example.test/viaje-demo/peaje-beta',
        ),
      ],
    ),
  ),
  TripRouteOption(
    id: 'demo-pintada',
    summary: 'Ruta DEMO La Pintada',
    distanceMeters: 428000,
    durationSeconds: 28200,
    timeBasis: 'static',
    geometry: const [
      TripCoordinate(latitude: 6.2442, longitude: -75.5812),
      TripCoordinate(latitude: 5.74, longitude: -75.62),
      TripCoordinate(latitude: 5.32, longitude: -75.05),
      TripCoordinate(latitude: 5.05, longitude: -74.55),
      TripCoordinate(latitude: 4.711, longitude: -74.0721),
    ],
    tolls: TripTolls(
      coverage: TripTollCoverage.partial,
      vehicleCategory: category,
      stationCount: 3,
      payableCount: 1,
      subtotalMinor: 3150000,
      missingRates: 2,
      charges: const [
        TripTollCharge(
          name: 'Peaje DEMO Gamma',
          amountMinor: 3150000,
          effectiveAt: '2026-08-15',
          sourceUrl: 'https://example.test/viaje-demo/peaje-gamma',
        ),
        TripTollCharge(name: 'Peaje DEMO sin tarifa confirmada'),
      ],
    ),
  ),
];

List<TripRouteOption> _unknownCoverageRoutes(String category) => [
  TripRouteOption(
    id: 'demo-unknown',
    summary: 'Ruta DEMO con cobertura incierta',
    distanceMeters: 86200,
    durationSeconds: 7200,
    timeBasis: 'static',
    geometry: const [
      TripCoordinate(latitude: 1.2136, longitude: -77.2811),
      TripCoordinate(latitude: 1.12, longitude: -77.36),
      TripCoordinate(latitude: 0.98, longitude: -77.49),
      TripCoordinate(latitude: 0.8303, longitude: -77.6446),
    ],
    tolls: TripTolls(
      coverage: TripTollCoverage.unknown,
      vehicleCategory: category,
      stationCount: null,
      missingRates: 1,
    ),
  ),
  TripRouteOption(
    id: 'demo-local',
    summary: 'Alternativa DEMO sin tarifa verificada',
    distanceMeters: 94300,
    durationSeconds: 8100,
    timeBasis: 'static',
    geometry: const [
      TripCoordinate(latitude: 1.2136, longitude: -77.2811),
      TripCoordinate(latitude: 1.05, longitude: -77.25),
      TripCoordinate(latitude: 0.91, longitude: -77.42),
      TripCoordinate(latitude: 0.8303, longitude: -77.6446),
    ],
    tolls: TripTolls(
      coverage: TripTollCoverage.partial,
      vehicleCategory: category,
      stationCount: 2,
      payableCount: 0,
      subtotalMinor: 0,
      missingRates: 1,
      charges: const [TripTollCharge(name: 'Peaje DEMO por verificar')],
    ),
  ),
];

String _safeCode(Object? code, int? status) {
  const allowed = {
    'validation',
    'departure_window',
    'no_route',
    'unsupported_vehicle',
    'not_configured',
    'quota',
    'timeout',
    'invalid_upstream',
    'network',
  };
  if (code is String && allowed.contains(code)) return code;
  return switch (status) {
    429 => 'quota',
    504 => 'timeout',
    422 => 'validation',
    _ => 'invalid_upstream',
  };
}

TripPlan _parsePlan(Map<String, dynamic> json, String category) {
  final rows = json['routes'];
  if (rows is! List || rows.isEmpty || rows.length > 3) {
    throw const FormatException();
  }
  final routes = <TripRouteOption>[];
  final ids = <String>{};
  for (final raw in rows) {
    final row = _object(raw);
    final id = _text(row['id']);
    if (!ids.add(id)) throw const FormatException();
    final basis = _text(row['timeBasis']);
    if (!const {'static', 'traffic'}.contains(basis)) {
      throw const FormatException();
    }
    routes.add(
      TripRouteOption(
        id: id,
        summary: _text(row['summary']),
        distanceMeters: _integer(
          row['distanceMeters'],
          minimum: 1,
          maximum: 10000000,
        ),
        durationSeconds: _integer(
          row['durationSeconds'],
          minimum: 1,
          maximum: 604800,
        ),
        timeBasis: basis,
        geometry: _geometry(row['geometry']),
        tolls: _tolls(row['tolls'], category),
      ),
    );
  }
  routes.sort((a, b) => a.durationSeconds.compareTo(b.durationSeconds));
  return TripPlan(
    requestId: _text(json['requestId']),
    generatedAtUtc: _instant(json['generatedAtUtc']),
    provider: _text(json['provider']),
    attribution: _text(json['attribution']),
    origin: _point(json['origin']),
    destination: _point(json['destination']),
    routes: routes,
  );
}

List<TripCoordinate> _geometry(Object? value) {
  final json = _object(value);
  if (json['type'] != 'LineString') throw const FormatException();
  final rows = json['coordinates'];
  if (rows is! List ||
      rows.length < 2 ||
      rows.length > _maximumGeometryPoints) {
    throw const FormatException();
  }
  final points = <TripCoordinate>[];
  for (final raw in rows) {
    if (raw is! List || raw.length != 2) throw const FormatException();
    final longitude = raw[0];
    final latitude = raw[1];
    if (longitude is! num ||
        latitude is! num ||
        !longitude.isFinite ||
        !latitude.isFinite ||
        longitude.abs() > 180 ||
        latitude.abs() > 90) {
      throw const FormatException();
    }
    points.add(
      TripCoordinate(
        latitude: latitude.toDouble(),
        longitude: longitude.toDouble(),
      ),
    );
  }
  return points;
}

TripResolvedPoint _point(Object? value) {
  final json = _object(value);
  final lat = json['latitude'];
  final lon = json['longitude'];
  if (lat is! num ||
      lon is! num ||
      !lat.isFinite ||
      !lon.isFinite ||
      lat.abs() > 90 ||
      lon.abs() > 180) {
    throw const FormatException();
  }
  return TripResolvedPoint(
    label: _text(json['label']),
    latitude: lat.toDouble(),
    longitude: lon.toDouble(),
  );
}

TripTolls _tolls(Object? value, String category) {
  try {
    final json = _object(value);
    if (json['currency'] != 'COP' ||
        json['vehicleCategory'] != category ||
        json['paymentMethod'] != 'cash') {
      throw const FormatException();
    }
    final coverage = switch (json['coverage']) {
      'complete' => TripTollCoverage.complete,
      'partial' => TripTollCoverage.partial,
      'unknown' => TripTollCoverage.unknown,
      'no_charge_confirmed' => TripTollCoverage.noChargeConfirmed,
      'unsupported_vehicle' => TripTollCoverage.unsupportedVehicle,
      _ => throw const FormatException(),
    };
    final rows = json['charges'];
    if (rows is! List || rows.length > 500) throw const FormatException();
    final charges = <TripTollCharge>[];
    for (final raw in rows) {
      final row = _object(raw);
      final source = row['sourceUrl'];
      String? safeSource;
      if (source != null) {
        final uri = Uri.tryParse(_text(source, maximum: 2048));
        if (uri == null ||
            uri.scheme != 'https' ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty ||
            uri.hasQuery ||
            uri.hasFragment) {
          throw const FormatException();
        }
        safeSource = uri.toString();
      }
      final effective = row['effectiveAt'];
      if (effective != null &&
          (effective is! String ||
              !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(effective) ||
              DateTime.tryParse(effective) == null)) {
        throw const FormatException();
      }
      charges.add(
        TripTollCharge(
          name: _text(row['name']),
          amountMinor: _optionalInteger(row['amountMinor']),
          sourceUrl: safeSource,
          effectiveAt: effective as String?,
        ),
      );
    }
    final total = _optionalInteger(json['totalMinor']);
    final subtotal = _optionalInteger(json['subtotalMinor']);
    final missing = _integer(json['missingRates'], maximum: 500);
    final stations = _optionalInteger(json['stationCount'], maximum: 500);
    final payable = _optionalInteger(json['payableCount'], maximum: 500);
    final sum = charges.fold<int>(0, (s, c) => s + (c.amountMinor ?? 0));
    final absent = charges.where((c) => c.amountMinor == null).length;
    final positive = charges.where((c) => (c.amountMinor ?? 0) > 0).length;
    if (stations != null && stations < charges.length ||
        payable != null &&
            (stations == null || payable > stations || payable < positive)) {
      throw const FormatException();
    }
    switch (coverage) {
      case TripTollCoverage.complete:
        if (charges.isEmpty ||
            (payable != null && payable != positive) ||
            absent != 0 ||
            missing != 0 ||
            total != sum ||
            subtotal != null) {
          throw const FormatException();
        }
      case TripTollCoverage.partial:
        if (total != null ||
            subtotal != sum ||
            missing < absent ||
            missing == 0) {
          throw const FormatException();
        }
      case TripTollCoverage.noChargeConfirmed:
        if (total != 0 ||
            (payable != null && payable != 0) ||
            subtotal != null ||
            missing != 0 ||
            absent != 0 ||
            sum != 0) {
          throw const FormatException();
        }
      case TripTollCoverage.unknown:
      case TripTollCoverage.unsupportedVehicle:
        if (total != null || subtotal != null) throw const FormatException();
    }
    return TripTolls(
      coverage: coverage,
      vehicleCategory: category,
      totalMinor: total,
      subtotalMinor: subtotal,
      missingRates: missing,
      stationCount: stations,
      payableCount: payable,
      charges: charges,
    );
  } on FormatException {
    return TripTolls(
      coverage: TripTollCoverage.unknown,
      vehicleCategory: category,
    );
  } on TypeError {
    return TripTolls(
      coverage: TripTollCoverage.unknown,
      vehicleCategory: category,
    );
  }
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map<String, dynamic>) throw const FormatException();
  return value;
}

String _text(Object? value, {int maximum = 400}) {
  if (value is! String ||
      value.trim().isEmpty ||
      value.length > maximum ||
      RegExp(r'[\x00-\x1F]').hasMatch(value)) {
    throw const FormatException();
  }
  return value.trim();
}

int _integer(Object? value, {int minimum = 0, int maximum = 1000000000000}) {
  if (value is! int || value < minimum || value > maximum) {
    throw const FormatException();
  }
  return value;
}

int? _optionalInteger(Object? value, {int maximum = 1000000000000}) =>
    value == null ? null : _integer(value, maximum: maximum);
DateTime _instant(Object? value) {
  final raw = _text(value);
  if (!raw.endsWith('Z')) throw const FormatException();
  final date = DateTime.tryParse(raw);
  if (date == null) throw const FormatException();
  return date.toUtc();
}
