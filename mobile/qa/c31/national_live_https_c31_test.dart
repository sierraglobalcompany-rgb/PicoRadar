// Opt-in only:
// flutter test --no-pub qa/c31/national_live_https_c31_test.dart
//
// The live case runs only when PICORADAR_C31_LIVE_HTTPS=1 and the integrator
// has supplied the matching C3 release contract plus private TLS material.
// All TLS files and sync temporaries must remain under PICORADAR_C31_PRIVATE_ROOT.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

const _manifestPath = '/v1/manifest.json';
const _manifestLimit = 64 * 1024;
const _payloadLimit = 4 * 1024 * 1024;
const _liveOptInVariable = 'PICORADAR_C31_LIVE_HTTPS';
const _expectedJurisdiction = 'c31-synthetic-off';

void main() {
  test('C31 upstream origin accepts only literal loopback HTTP', () {
    expect(
      _parseUpstreamOrigin('http://127.0.0.1:8879'),
      Uri.parse('http://127.0.0.1:8879'),
    );
    for (final invalid in [
      'https://127.0.0.1:8879',
      'http://localhost:8879',
      'http://127.0.0.1:80',
      'http://user@127.0.0.1:8879',
      'http://127.0.0.1:8879/admin',
      'http://127.0.0.1:8879/?x=1',
      'http://127.0.0.1:8879/#fragment',
      'http://192.0.2.1:8879',
    ]) {
      expect(
        () => _parseUpstreamOrigin(invalid),
        throwsFormatException,
        reason: 'Rejected upstream origin: $invalid',
      );
    }
  });

  test('C31 relay allowlist accepts only exact release GET routes', () {
    const version = 'c31-live-r1';
    const releasePath =
        '/storage/datasets/restrictions/c31-live-r1/'
        'restrictions-c31-live-r1.json';
    expect(_validateReleasePath(releasePath, version), releasePath);

    expect(
      _isAllowedRelayRequest(
        'GET',
        Uri.parse('https://127.0.0.1:9443/v1/manifest.json'),
        releasePath,
      ),
      isTrue,
    );
    expect(
      _isAllowedRelayRequest(
        'GET',
        Uri.parse('https://127.0.0.1:9443$releasePath'),
        releasePath,
      ),
      isTrue,
    );

    for (final request in [
      ('POST', '/v1/manifest.json'),
      ('GET', '/admin/restrictions'),
      ('GET', '/v1/manifest.json?next=/admin'),
      ('GET', '/v1/%6danifest.json'),
      ('GET', '/storage/datasets/restrictions/../manifest.json'),
      ('GET', '$releasePath?download=1'),
    ]) {
      expect(
        _isAllowedRelayRequest(
          request.$1,
          Uri.parse('https://127.0.0.1:9443${request.$2}'),
          releasePath,
        ),
        isFalse,
        reason: 'Rejected relay request: ${request.$1} ${request.$2}',
      );
    }

    expect(
      () => _validateReleasePath(
        '/storage/datasets/restrictions/../manifest.json',
        version,
      ),
      throwsFormatException,
    );
    expect(
      () => _validateReleasePath(
        '/storage/datasets/restrictions/c31-live-r1/'
        'restrictions-c31-live-r1.json?next=/admin',
        version,
      ),
      throwsFormatException,
    );
  });

  test(
    'C31 imports the live OFF release through a private HTTPS relay',
    () async {
      final contract = _C31LiveContract.fromEnvironment();
      await _runLiveSync(contract);
    },
    skip: Platform.environment[_liveOptInVariable] == '1' ? false : 'Set PICORADAR_C31_LIVE_HTTPS=1 after C3 supplies a valid live contract.',
    timeout: const Timeout(Duration(seconds: 120)),
  );
}

Future<void> _runLiveSync(_C31LiveContract contract) async {
  final temporaryDirectory = await contract.privateRoot.createTemp(
    'c31-flutter-sync-',
  );
  HttpServer? server;
  StreamSubscription<HttpRequest>? serverSubscription;
  HttpClient? upstreamClient;
  Dio? dio;
  AppDatabase? database;

  try {
    final serverContext = SecurityContext()
      ..useCertificateChain(contract.leafCertificatePath)
      ..usePrivateKey(contract.leafPrivateKeyPath);
    server = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      serverContext,
    );
    expect(server.address, InternetAddress.loopbackIPv4);

    final httpsOrigin = Uri(
      scheme: 'https',
      host: InternetAddress.loopbackIPv4.address,
      port: server.port,
    );
    final config = AppConfig(
      cdnBaseUrl: httpsOrigin.toString(),
      manifestUrl: httpsOrigin.resolve(_manifestPath).toString(),
    );
    expect(config.manifestUri.scheme, 'https');
    expect(_sameOrigin(config.cdnBaseUri, config.manifestUri), isTrue);

    upstreamClient = HttpClient()
      ..autoUncompress = false
      ..connectionTimeout = const Duration(seconds: 5)
      ..idleTimeout = const Duration(seconds: 10)
      ..findProxy = (_) => 'DIRECT';
    final relay = _LiveReleaseRelay(
      server: server,
      upstreamClient: upstreamClient,
      upstreamOrigin: contract.upstreamOrigin,
      releasePath: contract.releasePath,
      expectedManifestSha256: contract.manifestSha256,
      expectedPayloadSha256: contract.payloadSha256,
    );
    serverSubscription = server.listen((request) {
      unawaited(relay.handle(request));
    });

    final trustedContext = SecurityContext(withTrustedRoots: false)
      ..setTrustedCertificates(contract.caCertificatePath);
    final relayHttpClient = HttpClient(context: trustedContext)
      ..autoUncompress = false
      ..connectionTimeout = const Duration(seconds: 5)
      ..idleTimeout = const Duration(seconds: 10)
      ..findProxy = (_) => 'DIRECT';
    dio = _newDio(relayHttpClient);

    final manifestBytes = await _getRelayBytes(
      dio,
      config.manifestUri,
      _manifestLimit,
    );
    expect(await _sha256Hex(manifestBytes), contract.manifestSha256);
    final manifestJson = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(manifestBytes)) as Map,
    );
    _assertManifestRelease(manifestJson, contract, config.cdnBaseUri);

    final payloadUri = config.cdnBaseUri.resolve(contract.releasePath);
    expect(_sameOrigin(config.cdnBaseUri, payloadUri), isTrue);
    final payloadBytes = await _getRelayBytes(dio, payloadUri, _payloadLimit);
    expect(await _sha256Hex(payloadBytes), contract.payloadSha256);

    database = AppDatabase(NativeDatabase.memory());
    final service = DatasetSyncService(
      database: database,
      preferences: _MemoryPreferences(),
      config: config,
      importers: const {restrictionsDatasetKey: importRestrictionsDataset},
      http: dio,
      tempDirectory: temporaryDirectory,
    );
    final syncResult = await service.sync();
    expect(syncResult.imported, contains(restrictionsDatasetKey));

    final installed = await database
        .select(database.datasetVersions)
        .getSingle();
    expect(installed.datasetKey, restrictionsDatasetKey);
    expect(installed.version, contract.version);
    expect(installed.sha256, contract.payloadSha256);
    expect(installed.publicationRevision, contract.publicationRevision);

    final coverage = await RestrictionStore(database).loadCoverage(
      contract.jurisdictionId,
      VehicleKind.car,
      VehicleServiceType.private,
      contract.fixtureDate,
    );
    expect(coverage.coverageKnown, isTrue);
    expect(coverage.coverageCompleteness, CoverageCompleteness.partial);
    expect(coverage.consultationEnabled, isFalse);
    expect(coverage.jurisdictionConsultationEnabled, isFalse);
    expect(coverage.rules, isNotEmpty);

    final evaluation = evaluateRestrictionDay(
      ruleSet: coverage,
      jurisdictionId: contract.jurisdictionId,
      plate: 'QA0000',
      vehicleKind: VehicleKind.car,
      serviceType: VehicleServiceType.private,
      date: contract.fixtureDate,
    );
    expect(evaluation.status, RestrictionDayStatus.unknown);
    expect(evaluation.status, isNot(RestrictionDayStatus.allowed));

    final observationsBeforeDeniedRoute = relay.upstreamObservations.length;
    final deniedResponse = await dio.getUri<List<int>>(
      httpsOrigin.resolve('/admin/restrictions'),
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: false,
        validateStatus: (status) => status != null,
      ),
    );
    expect(deniedResponse.statusCode, HttpStatus.notFound);
    expect(
      relay.upstreamObservations,
      hasLength(observationsBeforeDeniedRoute),
      reason: 'A denied route must not contact Laravel.',
    );

    final expectedPaths = [
      _manifestPath,
      contract.releasePath,
      _manifestPath,
      contract.releasePath,
    ];
    expect(
      relay.upstreamObservations.map((item) => item.path).toList(),
      expectedPaths,
    );
    expect(relay.relayObservations.map((item) => item.path).toList(), [
      ...expectedPaths,
      '/admin/restrictions',
    ]);
    for (var index = 0; index < expectedPaths.length; index += 1) {
      final upstream = relay.upstreamObservations[index];
      final relayed = relay.relayObservations[index];
      final expectedHash = expectedPaths[index] == _manifestPath
          ? contract.manifestSha256
          : contract.payloadSha256;
      expect(upstream.method, 'GET');
      expect(upstream.status, HttpStatus.ok);
      expect(upstream.sha256, expectedHash);
      expect(upstream.cookieForwarded, isFalse);
      expect(relayed.method, 'GET');
      expect(relayed.status, HttpStatus.ok);
      expect(relayed.upstreamStatus, HttpStatus.ok);
      expect(relayed.sha256, expectedHash);
      expect(relayed.byteCount, upstream.byteCount);
    }
    expect(relay.failures, isEmpty);

    stdout.writeln(
      'C31_B_TLS=PASS private_ca_only=true loopback_san_verified=true '
      'global_trust_unchanged=true',
    );
    for (var index = 0; index < expectedPaths.length; index += 1) {
      final upstream = relay.upstreamObservations[index];
      final relayed = relay.relayObservations[index];
      stdout.writeln(
        'C31_B_UPSTREAM method=${upstream.method} path=${upstream.path} status=${upstream.status} bytes=${upstream.byteCount} sha256=${upstream.sha256}',
      );
      stdout.writeln(
        'C31_B_RELAY method=${relayed.method} path=${relayed.path} status=${relayed.status} bytes=${relayed.byteCount} sha256=${relayed.sha256}',
      );
    }
    stdout.writeln(
      'C31_B_SYNC imported=restrictions version=${installed.version} revision=${installed.publicationRevision} sha256=${installed.sha256!}',
    );
    stdout.writeln(
      'C31_B_UNKNOWN jurisdiction=${contract.jurisdictionId} coverage=partial consultation=OFF rules=${coverage.rules.length} evaluation=UNKNOWN',
    );
    stdout.writeln(
      'C31_B_ALLOWLIST denied=/admin/restrictions status=404 '
      'denied_route_upstream_calls=0',
    );
  } finally {
    await serverSubscription?.cancel();
    await server?.close(force: true);
    dio?.close(force: true);
    upstreamClient?.close(force: true);
    await database?.close();
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  }
}

Dio _newDio(HttpClient httpClient) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 5),
      followRedirects: false,
      maxRedirects: 0,
    ),
  );
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () => httpClient,
  );
  return dio;
}

Future<List<int>> _getRelayBytes(Dio dio, Uri uri, int maxBytes) async {
  final response = await dio.getUri<List<int>>(
    uri,
    options: Options(
      responseType: ResponseType.bytes,
      followRedirects: false,
      validateStatus: (status) => status != null,
    ),
  );
  if (response.statusCode != HttpStatus.ok) {
    throw StateError(
      'C31 relay GET ${uri.path} returned HTTP ${response.statusCode}',
    );
  }
  if (response.headers.value(HttpHeaders.setCookieHeader) != null ||
      response.headers.value(HttpHeaders.locationHeader) != null) {
    throw StateError('C31 relay returned a session or redirect header.');
  }
  final bytes = response.data;
  if (bytes == null || bytes.length > maxBytes) {
    throw StateError('C31 relay body is absent or exceeds its byte limit.');
  }
  return bytes;
}

void _assertManifestRelease(
  Map<String, dynamic> manifest,
  _C31LiveContract contract,
  Uri cdnBaseUri,
) {
  expect(manifest['schemaVersion'], 1);
  final datasets = manifest['datasets'];
  expect(datasets, isA<Map>());
  final entryValue = (datasets as Map)[restrictionsDatasetKey];
  expect(entryValue, isA<Map>());
  final entry = Map<String, dynamic>.from(entryValue as Map);
  expect(entry['version'], contract.version);
  expect(entry['sha256'], contract.payloadSha256);
  expect(entry['publicationRevision'], contract.publicationRevision);

  final rawUrl = entry['url'];
  expect(rawUrl, isA<String>());
  final declaredUrl = rawUrl as String;
  expect(declaredUrl.contains('%'), isFalse);
  expect(declaredUrl.contains(r'\'), isFalse);
  final declared = Uri.parse(declaredUrl);
  expect(declared.hasScheme, isFalse);
  expect(declared.hasAuthority, isFalse);
  expect(declared.hasQuery, isFalse);
  expect(declared.hasFragment, isFalse);
  expect(declared.path.contains('%'), isFalse);
  expect(declared.path.contains(r'\'), isFalse);
  expect(declared.pathSegments, isNot(contains('..')));
  expect(cdnBaseUri.resolveUri(declared).path, contract.releasePath);
}

Uri _parseUpstreamOrigin(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'http' ||
      uri.host != InternetAddress.loopbackIPv4.address ||
      !uri.hasPort ||
      uri.port < 1024 ||
      uri.port > 65535 ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.path.isNotEmpty && uri.path != '/')) {
    throw const FormatException(
      'C31 upstream must be a literal http://127.0.0.1:1024-65535 origin.',
    );
  }
  return uri;
}

String _validateReleasePath(String value, String version) {
  final uri = Uri.tryParse(value);
  final validVersion = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$');
  if (uri == null ||
      !validVersion.hasMatch(version) ||
      uri.hasScheme ||
      uri.hasAuthority ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.path != value ||
      value.contains('%') ||
      value.contains(r'\') ||
      uri.pathSegments.any((segment) => segment == '.' || segment == '..') ||
      value !=
          '/storage/datasets/restrictions/$version/restrictions-$version.json') {
    throw const FormatException(
      'C31 release path must be the exact restrictions route for its version.',
    );
  }
  return value;
}

bool _isAllowedRelayRequest(String method, Uri uri, String releasePath) {
  final rawUri = uri.toString();
  if (method != 'GET' ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.userInfo.isNotEmpty ||
      rawUri.contains('%') ||
      uri.path.contains(r'\')) {
    return false;
  }
  return uri.path == _manifestPath || uri.path == releasePath;
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

Future<List<int>> _readBounded(
  HttpClientResponse response,
  int maxBytes,
) async {
  if (response.contentLength > maxBytes) {
    throw StateError('C31 upstream declared a body over the byte limit.');
  }
  final builder = BytesBuilder(copy: false);
  var totalBytes = 0;
  await for (final chunk in response.timeout(const Duration(seconds: 15))) {
    totalBytes += chunk.length;
    if (totalBytes > maxBytes) {
      throw StateError('C31 upstream body exceeded the byte limit.');
    }
    builder.add(chunk);
  }
  return builder.takeBytes();
}

String _safeContentType(HttpHeaders headers) {
  final value = headers.value(HttpHeaders.contentTypeHeader);
  if (value == null || value.trim().isEmpty) {
    return ContentType.binary.mimeType;
  }
  try {
    ContentType.parse(value);
    return value;
  } on FormatException {
    return ContentType.binary.mimeType;
  }
}

String _requiredEnvironment(String name) {
  final value = Platform.environment[name]?.trim();
  if (value == null || value.isEmpty) {
    throw StateError('$name is required by the C31 live test.');
  }
  return value;
}

String _requiredSha256(String name) {
  final value = _requiredEnvironment(name).toLowerCase();
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) {
    throw FormatException('$name must be a SHA-256 hex value.');
  }
  return value;
}

String _canonicalFileInsidePrivateRoot(
  String environmentName,
  String privateRoot,
) {
  final file = File(_requiredEnvironment(environmentName));
  if (!file.existsSync()) {
    throw StateError('$environmentName does not exist.');
  }
  final canonical = file.resolveSymbolicLinksSync();
  if (!_isPathInside(canonical, privateRoot)) {
    throw StateError('$environmentName must remain inside C31 private root.');
  }
  return canonical;
}

bool _isPathInside(String childPath, String rootPath) {
  final root = rootPath
      .replaceAll(r'\', '/')
      .toLowerCase()
      .replaceAll(RegExp(r'/+$'), '');
  final child = childPath.replaceAll(r'\', '/').toLowerCase();
  return child.startsWith('$root/');
}

bool _sameCanonicalPath(String leftPath, String rightPath) =>
    leftPath
        .replaceAll(r'\', '/')
        .replaceAll(RegExp(r'/+$'), '')
        .toLowerCase() ==
    rightPath
        .replaceAll(r'\', '/')
        .replaceAll(RegExp(r'/+$'), '')
        .toLowerCase();

class _C31LiveContract {
  const _C31LiveContract({
    required this.upstreamOrigin,
    required this.releasePath,
    required this.manifestSha256,
    required this.payloadSha256,
    required this.version,
    required this.publicationRevision,
    required this.jurisdictionId,
    required this.fixtureDate,
    required this.privateRoot,
    required this.caCertificatePath,
    required this.leafCertificatePath,
    required this.leafPrivateKeyPath,
  });

  factory _C31LiveContract.fromEnvironment() {
    if (Platform.environment[_liveOptInVariable] != '1') {
      throw StateError('C31 live test is not opted in.');
    }
    final version = _requiredEnvironment('PICORADAR_C31_RELEASE_VERSION');
    final releasePath = _validateReleasePath(
      _requiredEnvironment('PICORADAR_C31_RELEASE_PATH'),
      version,
    );
    final revision = int.tryParse(
      _requiredEnvironment('PICORADAR_C31_PUBLICATION_REVISION'),
    );
    if (revision == null || revision <= 0) {
      throw const FormatException(
        'PICORADAR_C31_PUBLICATION_REVISION must be positive.',
      );
    }

    final dateValue = _requiredEnvironment('PICORADAR_C31_FIXTURE_DATE');
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateValue)) {
      throw const FormatException(
        'PICORADAR_C31_FIXTURE_DATE must use YYYY-MM-DD.',
      );
    }
    final fixtureDate = DateTime.parse(dateValue);
    if (fixtureDate.toIso8601String().substring(0, 10) != dateValue) {
      throw const FormatException('C31 fixture date is invalid.');
    }

    final privateRootDirectory = Directory(
      _requiredEnvironment('PICORADAR_C31_PRIVATE_ROOT'),
    );
    if (!privateRootDirectory.existsSync()) {
      throw StateError('PICORADAR_C31_PRIVATE_ROOT does not exist.');
    }
    final privateRoot = privateRootDirectory.resolveSymbolicLinksSync();
    final current = Directory.current.resolveSymbolicLinksSync();
    final mobileRoot =
        current.toLowerCase().endsWith('${Platform.pathSeparator}mobile')
        ? current
        : Directory('$current${Platform.pathSeparator}mobile').path;
    final repoRoot = Directory(mobileRoot).parent.resolveSymbolicLinksSync();
    if (_sameCanonicalPath(privateRoot, repoRoot) ||
        _isPathInside(privateRoot, repoRoot) ||
        _isPathInside(repoRoot, privateRoot)) {
      throw StateError('C31 private root must be outside the candidate repo.');
    }

    final caPath = _canonicalFileInsidePrivateRoot(
      'PICORADAR_C31_TLS_CA_PEM',
      privateRoot,
    );
    final chainPath = _canonicalFileInsidePrivateRoot(
      'PICORADAR_C31_TLS_CERT_CHAIN_PEM',
      privateRoot,
    );
    final keyPath = _canonicalFileInsidePrivateRoot(
      'PICORADAR_C31_TLS_LEAF_KEY_PEM',
      privateRoot,
    );
    if ({caPath, chainPath, keyPath}.length != 3) {
      throw StateError(
        'C31 TLS CA, leaf chain, and key must be distinct files.',
      );
    }

    return _C31LiveContract(
      upstreamOrigin: _parseUpstreamOrigin(
        _requiredEnvironment('PICORADAR_C31_UPSTREAM_ORIGIN'),
      ),
      releasePath: releasePath,
      manifestSha256: _requiredSha256('PICORADAR_C31_MANIFEST_SHA256'),
      payloadSha256: _requiredSha256('PICORADAR_C31_PAYLOAD_SHA256'),
      version: version,
      publicationRevision: revision,
      jurisdictionId: _requiredEnvironment('PICORADAR_C31_JURISDICTION_ID'),
      fixtureDate: fixtureDate,
      privateRoot: Directory(privateRoot),
      caCertificatePath: caPath,
      leafCertificatePath: chainPath,
      leafPrivateKeyPath: keyPath,
    ).._validateJurisdiction();
  }

  final Uri upstreamOrigin;
  final String releasePath;
  final String manifestSha256;
  final String payloadSha256;
  final String version;
  final int publicationRevision;
  final String jurisdictionId;
  final DateTime fixtureDate;
  final Directory privateRoot;
  final String caCertificatePath;
  final String leafCertificatePath;
  final String leafPrivateKeyPath;

  void _validateJurisdiction() {
    if (jurisdictionId != _expectedJurisdiction) {
      throw StateError('C31 requires its synthetic OFF jurisdiction.');
    }
  }
}

class _LiveReleaseRelay {
  _LiveReleaseRelay({
    required this.server,
    required this.upstreamClient,
    required this.upstreamOrigin,
    required this.releasePath,
    required this.expectedManifestSha256,
    required this.expectedPayloadSha256,
  });

  final HttpServer server;
  final HttpClient upstreamClient;
  final Uri upstreamOrigin;
  final String releasePath;
  final String expectedManifestSha256;
  final String expectedPayloadSha256;
  final upstreamObservations = <_UpstreamObservation>[];
  final relayObservations = <_RelayObservation>[];
  final failures = <String>[];

  Future<void> handle(HttpRequest request) async {
    final requestPath = request.uri.path;
    if (!_isAllowedRelayRequest(request.method, request.uri, releasePath)) {
      await _reply(
        request,
        path: requestPath,
        status: HttpStatus.notFound,
        upstreamStatus: null,
        bytes: const [],
        contentType: null,
      );
      return;
    }

    final maxBytes = requestPath == _manifestPath
        ? _manifestLimit
        : _payloadLimit;
    final expectedHash = requestPath == _manifestPath
        ? expectedManifestSha256
        : expectedPayloadSha256;

    try {
      final upstreamUri = upstreamOrigin.resolve(requestPath);
      if (!_sameOrigin(upstreamOrigin, upstreamUri)) {
        throw StateError('C31 relay attempted a non-origin request.');
      }
      final upstreamRequest = await upstreamClient.openUrl('GET', upstreamUri);
      upstreamRequest
        ..followRedirects = false
        ..persistentConnection = false;
      upstreamRequest.headers
        ..set(HttpHeaders.acceptEncodingHeader, 'identity')
        ..set(HttpHeaders.connectionHeader, 'close');
      final cookieForwarded =
          upstreamRequest.headers.value(HttpHeaders.cookieHeader) != null;
      final upstreamResponse = await upstreamRequest.close().timeout(
        const Duration(seconds: 10),
      );
      final bytes = await _readBounded(upstreamResponse, maxBytes);
      final digest = await _sha256Hex(bytes);
      final status = upstreamResponse.statusCode;
      upstreamObservations.add(
        _UpstreamObservation(
          method: 'GET',
          path: requestPath,
          status: status,
          byteCount: bytes.length,
          sha256: digest,
          cookieForwarded: cookieForwarded,
        ),
      );

      final contentEncoding = upstreamResponse.headers.value(
        HttpHeaders.contentEncodingHeader,
      );
      if (contentEncoding != null &&
          contentEncoding.trim().isNotEmpty &&
          contentEncoding.toLowerCase() != 'identity') {
        failures.add('$requestPath:unexpected-content-encoding');
        await _reply(
          request,
          path: requestPath,
          status: HttpStatus.badGateway,
          upstreamStatus: status,
          bytes: utf8.encode('C31 relay rejected encoded HTTP response.'),
          contentType: ContentType.text.mimeType,
        );
        return;
      }

      if (status == HttpStatus.ok && digest != expectedHash) {
        failures.add('$requestPath:sha256-mismatch');
        await _reply(
          request,
          path: requestPath,
          status: HttpStatus.badGateway,
          upstreamStatus: status,
          bytes: utf8.encode('C31 relay SHA-256 mismatch.'),
          contentType: ContentType.text.mimeType,
        );
        return;
      }

      await _reply(
        request,
        path: requestPath,
        status: status,
        upstreamStatus: status,
        bytes: bytes,
        contentType: _safeContentType(upstreamResponse.headers),
        sha256: digest,
      );
    } catch (error) {
      failures.add('$requestPath:${error.runtimeType}');
      await _reply(
        request,
        path: requestPath,
        status: HttpStatus.badGateway,
        upstreamStatus: null,
        bytes: utf8.encode('C31 relay upstream request failed.'),
        contentType: ContentType.text.mimeType,
      );
    }
  }

  Future<void> _reply(
    HttpRequest request, {
    required String path,
    required int status,
    required int? upstreamStatus,
    required List<int> bytes,
    required String? contentType,
    String? sha256,
  }) async {
    final response = request.response;
    response.statusCode = status;
    response.headers.set(HttpHeaders.contentLengthHeader, bytes.length);
    response.headers.set(HttpHeaders.connectionHeader, 'close');
    if (contentType != null) {
      response.headers.set(HttpHeaders.contentTypeHeader, contentType);
    }
    response.add(bytes);
    await response.close();
    relayObservations.add(
      _RelayObservation(
        method: request.method,
        path: path,
        status: status,
        upstreamStatus: upstreamStatus,
        byteCount: bytes.length,
        sha256: sha256 ?? await _sha256Hex(bytes),
      ),
    );
  }
}

class _UpstreamObservation {
  const _UpstreamObservation({
    required this.method,
    required this.path,
    required this.status,
    required this.byteCount,
    required this.sha256,
    required this.cookieForwarded,
  });

  final String method;
  final String path;
  final int status;
  final int byteCount;
  final String sha256;
  final bool cookieForwarded;
}

class _RelayObservation {
  const _RelayObservation({
    required this.method,
    required this.path,
    required this.status,
    required this.upstreamStatus,
    required this.byteCount,
    required this.sha256,
  });

  final String method;
  final String path;
  final int status;
  final int? upstreamStatus;
  final int byteCount;
  final String sha256;
}

class _MemoryPreferences implements AppPreferences {
  final Map<String, Object?> _values = {};

  @override
  Future<bool?> getBool(String key) async => _values[key] as bool?;

  @override
  Future<int?> getInt(String key) async => _values[key] as int?;

  @override
  Future<String?> getString(String key) async => _values[key] as String?;

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> setBool(String key, bool value) async {
    _values[key] = value;
  }

  @override
  Future<void> setInt(String key, int value) async {
    _values[key] = value;
  }

  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }
}
