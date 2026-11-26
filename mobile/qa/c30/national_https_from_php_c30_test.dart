// Opt-in C30 TLS-only test. Run from the prepared Android-only mobile copy:
// flutter test --no-pub qa/c30/national_https_from_php_c30_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/core/config/app_config.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/core/storage/app_preferences.dart';
import 'package:picoradar/core/sync/dataset_sync_service.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/pico_placa/data/restriction_dataset.dart';
import 'package:picoradar/features/pico_placa/data/restriction_store.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_day_evaluation.dart';
import 'package:picoradar/features/pico_placa/domain/restriction_rule.dart';

const _expectedManifestSha256 =
    'f244ceb0cee6c56ab3d1f7ffb72ea78190be14aa0d38804052a107ef1f0676fa';
const _expectedPayloadSha256 =
    'af1955879edc63725fb8c8332cddd627c6d8b5116a15bd0feefb1ecc358cfd7e';
const _manifestPath = '/v1/manifest.json';
const _payloadPath =
    '/storage/datasets/restrictions/r2-7f969a248a68/'
    'restrictions-r2-7f969a248a68.json';
const _jurisdictionId = 'co-c28-synthetic-99999';
final _fixedNow = DateTime.utc(2026, 11, 23, 12);

void main() {
  test('imports exact C29 bytes over trusted HTTPS and rejects an untrusted CA', () async {
    final staticRoot = _requiredEnvironment('PICORADAR_C30_STATIC_ROOT');
    final caPem = _requiredEnvironment('PICORADAR_C30_TLS_CA_PEM');
    final chainPem = _requiredEnvironment('PICORADAR_C30_TLS_CHAIN_PEM');
    final leafKeyPem = _requiredEnvironment('PICORADAR_C30_TLS_LEAF_KEY_PEM');
    _assertTlsMaterialOutsideStaticRoot(staticRoot, [
      caPem,
      chainPem,
      leafKeyPem,
    ]);

    final manifestFile = File(
      '$staticRoot${Platform.pathSeparator}storage'
      '${Platform.pathSeparator}app${Platform.pathSeparator}public'
      '${Platform.pathSeparator}manifest${Platform.pathSeparator}v1'
      '${Platform.pathSeparator}manifest.json',
    );
    final payloadFile = File(
      '$staticRoot${Platform.pathSeparator}storage'
      '${Platform.pathSeparator}app${Platform.pathSeparator}public'
      '${Platform.pathSeparator}datasets${Platform.pathSeparator}restrictions'
      '${Platform.pathSeparator}r2-7f969a248a68'
      '${Platform.pathSeparator}restrictions-r2-7f969a248a68.json',
    );
    expect(await manifestFile.exists(), isTrue);
    expect(await payloadFile.exists(), isTrue);

    final manifestBytes = await manifestFile.readAsBytes();
    final payloadBytes = await payloadFile.readAsBytes();
    final manifestSha256 = await _sha256Hex(manifestBytes);
    final payloadSha256 = await _sha256Hex(payloadBytes);
    expect(manifestBytes, hasLength(424));
    expect(payloadBytes, hasLength(936));
    expect(manifestSha256, _expectedManifestSha256);
    expect(payloadSha256, _expectedPayloadSha256);

    final manifest = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(manifestBytes)) as Map,
    );
    expect(manifest['schemaVersion'], 1);
    expect(manifest['generatedAt'], '2026-11-23T12:00:00+00:00');
    expect(manifest['minAppVersion'], '1.0.0');
    final datasets = Map<String, dynamic>.from(manifest['datasets'] as Map);
    expect(datasets.keys, {restrictionsDatasetKey});
    final entry = Map<String, dynamic>.from(
      datasets[restrictionsDatasetKey] as Map,
    );
    expect(entry['version'], 'r2-7f969a248a68');
    expect(entry['publicationRevision'], 2);
    expect(entry['sha256'], _expectedPayloadSha256);
    final declaredUrl = entry['url'] as String;
    final declaredUri = Uri.parse(declaredUrl);
    expect(declaredUrl, _payloadPath);
    expect(declaredUri.hasScheme, isFalse);
    expect(declaredUri.hasAuthority, isFalse);
    expect(declaredUri.hasQuery, isFalse);
    expect(declaredUri.hasFragment, isFalse);
    expect(declaredUri.pathSegments, isNot(contains('..')));

    final payload = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(payloadBytes)) as Map,
    );
    expect(payload['schemaVersion'], 2);
    expect(payload['datasetKey'], restrictionsDatasetKey);
    expect(payload['version'], entry['version']);

    final serverContext = SecurityContext()
      ..useCertificateChain(chainPem)
      ..usePrivateKey(leafKeyPem);
    final server = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      serverContext,
    );
    StreamSubscription<HttpRequest>? requestSubscription;
    final requests = <_ObservedRequest>[];
    AppDatabase? positiveDatabase;
    AppDatabase? negativeDatabase;
    Dio? positiveDio;
    Dio? negativeDio;
    Dio? healthDio;
    Directory? positiveTemporaryDirectory;
    Directory? negativeTemporaryDirectory;
    try {
      expect(server.address, InternetAddress.loopbackIPv4);
      final baseUri = Uri(
        scheme: 'https',
        host: InternetAddress.loopbackIPv4.address,
        port: server.port,
      );
      final manifestUri = baseUri.resolve(_manifestPath);
      final payloadUri = baseUri.resolveUri(declaredUri);
      final config = AppConfig(
        cdnBaseUrl: baseUri.toString(),
        manifestUrl: manifestUri.toString(),
      );
      expect(_sameOrigin(config.cdnBaseUri, manifestUri), isTrue);
      expect(_sameOrigin(config.cdnBaseUri, payloadUri), isTrue);
      expect(config.cdnBaseUri.scheme, 'https');

      requestSubscription = server.listen((request) async {
        final allowed =
            request.method == 'GET' &&
            !request.uri.hasQuery &&
            (request.uri.path == _manifestPath ||
                request.uri.path == _payloadPath);
        final List<int>? bytes;
        final int status;
        if (!allowed) {
          bytes = null;
          status = HttpStatus.notFound;
        } else if (request.uri.path == _manifestPath) {
          bytes = manifestBytes;
          status = HttpStatus.ok;
        } else {
          bytes = payloadBytes;
          status = HttpStatus.ok;
        }
        requests.add(
          _ObservedRequest(request.method, request.uri.path, status),
        );
        request.response.statusCode = status;
        if (bytes != null) {
          request.response.headers.contentType = ContentType.json;
          request.response.headers.contentLength = bytes.length;
          request.response.add(bytes);
        }
        await request.response.close();
      });

      final trustedContext = SecurityContext(withTrustedRoots: false)
        ..setTrustedCertificates(caPem);
      positiveDio = _newDio(trustedContext);
      final positiveDb = AppDatabase(NativeDatabase.memory());
      positiveDatabase = positiveDb;
      positiveTemporaryDirectory = await Directory.systemTemp.createTemp(
        'picoradar_c30_https_trusted_',
      );
      final positiveService = _newSyncService(
        database: positiveDb,
        preferences: _MemoryPreferences(),
        config: config,
        http: positiveDio,
        tempDirectory: positiveTemporaryDirectory,
      );
      final syncResult = await positiveService.sync();
      expect(syncResult.imported, contains(restrictionsDatasetKey));

      final installed = await positiveDb
          .select(positiveDb.datasetVersions)
          .get();
      expect(installed, hasLength(1));
      expect(installed.single.datasetKey, restrictionsDatasetKey);
      expect(installed.single.version, 'r2-7f969a248a68');
      expect(installed.single.publicationRevision, 2);
      expect(installed.single.sha256, _expectedPayloadSha256);

      final coverage = await RestrictionStore(positiveDb).loadCoverage(
        _jurisdictionId,
        VehicleKind.car,
        VehicleServiceType.private,
        _fixedNow,
      );
      expect(coverage.coverageKnown, isTrue);
      expect(coverage.coverageCompleteness, CoverageCompleteness.partial);
      expect(coverage.consultationEnabled, isFalse);
      expect(coverage.jurisdictionConsultationEnabled, isFalse);
      expect(coverage.rules, isNotEmpty);
      final evaluation = evaluateRestrictionDay(
        ruleSet: coverage,
        jurisdictionId: _jurisdictionId,
        plate: 'ABC123',
        vehicleKind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
        date: _fixedNow,
      );
      expect(evaluation.status, RestrictionDayStatus.unknown);
      expect(evaluation.status, isNot(RestrictionDayStatus.allowed));
      expect(requests, [
        const _ObservedRequest('GET', _manifestPath, HttpStatus.ok),
        const _ObservedRequest('GET', _payloadPath, HttpStatus.ok),
      ]);

      final beforeUntrustedAttempt = requests.length;
      final successfulGetsBeforeUntrustedAttempt = requests
          .where(
            (request) =>
                request.method == 'GET' && request.status == HttpStatus.ok,
          )
          .length;
      final untrustedContext = SecurityContext(withTrustedRoots: false);
      negativeDio = _newDio(untrustedContext);
      final negativeDb = AppDatabase(NativeDatabase.memory());
      negativeDatabase = negativeDb;
      final negativePreferences = _MemoryPreferences();
      negativeTemporaryDirectory = await Directory.systemTemp.createTemp(
        'picoradar_c30_https_untrusted_',
      );
      final negativeService = _newSyncService(
        database: negativeDb,
        preferences: negativePreferences,
        config: config,
        http: negativeDio,
        tempDirectory: negativeTemporaryDirectory,
      );

      Object? tlsFailure;
      try {
        await negativeService.sync();
      } on DioException catch (error) {
        tlsFailure = _findCertificateHandshakeFailure(error);
      }
      expect(
        tlsFailure,
        isNotNull,
        reason: 'The untrusted client must fail specifically on certificate validation.',
      );
      expect(requests, hasLength(beforeUntrustedAttempt));
      expect(
        requests
            .where(
              (request) =>
                  request.method == 'GET' && request.status == HttpStatus.ok,
            )
            .length,
        successfulGetsBeforeUntrustedAttempt,
      );
      expect(
        await negativeDb.select(negativeDb.datasetVersions).get(),
        isEmpty,
      );
      expect(negativePreferences.isEmpty, isTrue);
      stdout.writeln(
        'C30_TLS_UNTRUSTED_REJECT=PASS '
        'failure=${tlsFailure.runtimeType}:certificate_validation '
        'successful_gets=0 imported_versions=0',
      );

      final healthContext = SecurityContext(withTrustedRoots: false)
        ..setTrustedCertificates(caPem);
      healthDio = _newDio(healthContext);
      final healthResponse = await healthDio.get<List<int>>(
        manifestUri.toString(),
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: false,
        ),
      );
      expect(healthResponse.statusCode, HttpStatus.ok);
      expect(healthResponse.data, manifestBytes);
      final deniedResponse = await healthDio.get<List<int>>(
        baseUri.resolve('/not-allowlisted').toString(),
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: false,
          validateStatus: (status) => status != null,
        ),
      );
      expect(deniedResponse.statusCode, HttpStatus.notFound);
      expect(requests, [
        const _ObservedRequest('GET', _manifestPath, HttpStatus.ok),
        const _ObservedRequest('GET', _payloadPath, HttpStatus.ok),
        const _ObservedRequest('GET', _manifestPath, HttpStatus.ok),
        const _ObservedRequest('GET', '/not-allowlisted', HttpStatus.notFound),
      ]);

      stdout.writeln(
        'C30_C29_BYTES=PASS '
        'manifest_bytes=${manifestBytes.length} manifest_sha256=$manifestSha256 '
        'payload_bytes=${payloadBytes.length} payload_sha256=$payloadSha256',
      );
      stdout.writeln(
        'C30_HTTPS_ENDPOINTS=PASS '
        'requests=${requests.map((request) => request.summary).join(';')} '
        'routes_allowlisted=2',
      );
      stdout.writeln(
        'C30_DART_HTTPS_SYNC=PASS version=r2-7f969a248a68 '
        'revision=2 coverage=OFF/partial evaluation=UNKNOWN',
      );
    } finally {
      await requestSubscription?.cancel();
      await server.close(force: true);
      positiveDio?.close(force: true);
      negativeDio?.close(force: true);
      healthDio?.close(force: true);
      await positiveDatabase?.close();
      await negativeDatabase?.close();
      if (positiveTemporaryDirectory != null &&
          await positiveTemporaryDirectory.exists()) {
        await positiveTemporaryDirectory.delete(recursive: true);
      }
      if (negativeTemporaryDirectory != null &&
          await negativeTemporaryDirectory.exists()) {
        await negativeTemporaryDirectory.delete(recursive: true);
      }
    }
  }, timeout: const Timeout(Duration(seconds: 90)));
}

String _requiredEnvironment(String name) {
  final value = Platform.environment[name]?.trim();
  if (value == null || value.isEmpty) {
    throw StateError('$name is required for the C30 opt-in TLS test.');
  }
  return value;
}

void _assertTlsMaterialOutsideStaticRoot(
  String staticRoot,
  List<String> materialPaths,
) {
  final root = Directory(staticRoot).resolveSymbolicLinksSync();
  final rootPrefix = '${root.toLowerCase()}${Platform.pathSeparator}';
  for (final path in materialPaths) {
    final canonical = File(path).resolveSymbolicLinksSync().toLowerCase();
    if (canonical.startsWith(rootPrefix)) {
      throw StateError('C30 TLS material must remain outside the static root.');
    }
  }
}

Dio _newDio(SecurityContext context) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
      sendTimeout: const Duration(seconds: 8),
    ),
  );
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () => HttpClient(context: context),
  );
  return dio;
}

DatasetSyncService _newSyncService({
  required AppDatabase database,
  required _MemoryPreferences preferences,
  required AppConfig config,
  required Dio http,
  required Directory tempDirectory,
}) => DatasetSyncService(
  database: database,
  preferences: preferences,
  config: config,
  importers: {
    restrictionsDatasetKey: (db, json) =>
        importRestrictionsDataset(db, json, now: () => _fixedNow),
  },
  http: http,
  tempDirectory: tempDirectory,
  now: () => _fixedNow,
);

Object? _findCertificateHandshakeFailure(Object error) {
  Object? current = error;
  for (var depth = 0; depth < 5 && current != null; depth += 1) {
    if (current is TlsException) {
      final detail = current.toString().toLowerCase();
      final certificateFailure =
          detail.contains('cert') ||
          detail.contains('unknown ca') ||
          detail.contains('issuer') ||
          detail.contains('trust');
      return certificateFailure ? current : null;
    }
    if (current is DioException) {
      current = current.error;
    } else if (current is SocketException) {
      current = current.osError;
    } else {
      return null;
    }
  }
  return null;
}

bool _sameOrigin(Uri left, Uri right) =>
    left.scheme == right.scheme &&
    left.host == right.host &&
    _effectivePort(left) == _effectivePort(right);

int _effectivePort(Uri uri) =>
    uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);

Future<String> _sha256Hex(List<int> bytes) async {
  final digest = await Sha256().hash(bytes);
  return digest.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}

class _ObservedRequest {
  const _ObservedRequest(this.method, this.path, this.status);

  final String method;
  final String path;
  final int status;

  String get summary => '$method $path=$status';

  @override
  bool operator ==(Object other) =>
      other is _ObservedRequest &&
      method == other.method &&
      path == other.path &&
      status == other.status;

  @override
  int get hashCode => Object.hash(method, path, status);
}

class _MemoryPreferences implements AppPreferences {
  final Map<String, Object?> _values = {};

  bool get isEmpty => _values.isEmpty;

  @override
  Future<bool?> getBool(String key) async => _values[key] as bool?;

  @override
  Future<int?> getInt(String key) async => _values[key] as int?;

  @override
  Future<String?> getString(String key) async => _values[key] as String?;

  @override
  Future<void> remove(String key) async => _values.remove(key);

  @override
  Future<void> setBool(String key, bool value) async => _values[key] = value;

  @override
  Future<void> setInt(String key, int value) async => _values[key] = value;

  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }
}
