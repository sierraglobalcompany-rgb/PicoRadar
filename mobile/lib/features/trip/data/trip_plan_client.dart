import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/trip_plan.dart';

final tripPlanClientProvider = Provider<TripPlanClient>((ref) {
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

class TripPlanClient {
  TripPlanClient({
    required this._dio,
    this._baseUri,
    this._operationTimeout = const Duration(seconds: 30),
  });
  final Dio _dio;
  final Uri? _baseUri;
  final Duration _operationTimeout;

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
        throw TripPlanFailure(_safeCode(code, response.statusCode));
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

String _safeCode(Object? code, int? status) {
  const allowed = {
    'validation',
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
        payable != null && (stations == null || payable > stations)) {
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
