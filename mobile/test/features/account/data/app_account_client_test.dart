import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/account/data/app_account_client.dart';
import 'package:picoradar/features/account/data/app_account_config.dart';

void main() {
  final token = List.filled(64, 'a').join();
  final config = AppAccountConfig(
    enabled: true,
    emailEnabled: true,
    apiBaseUrl: 'https://api.example.test',
    privacyUrl: 'https://example.test/privacy',
    privacyVersion: 'v1',
  );

  test('OTP requests contain only account fields and verified token uses dedicated storage key', () async {
    final adapter = _RecordingAdapter()
      ..body = jsonEncode({
        'data': {
          'token': token,
          'profile': {
            'id': 'synthetic-id',
            'name': null,
            'email': 'person@example.test',
            'phone': null,
            'municipality': null,
            'categories': [],
            'privacyVersion': 'v1',
            'marketingConsent': false,
          },
        },
      });
    final storage = _FakeTokenStorage();
    final client = HttpAppAccountClient(
      Dio()..httpClientAdapter = adapter,
      config: config,
      storage: storage,
    );

    await client.requestOtp(' person@example.test ', privacyAccepted: true);
    expect(
      Uri.parse(adapter.requests.single.path).path,
      '/api/v1/app-accounts/otp',
    );
    expect(adapter.requests.single.data, {
      'email': 'person@example.test',
      'privacyAccepted': true,
    });
    expect(
      adapter.requests.single.headers.containsKey('Authorization'),
      isFalse,
    );

    await client.verifyOtp('person@example.test', '123456');
    expect(adapter.requests.last.data, {
      'email': 'person@example.test',
      'code': '123456',
    });
    expect(storage.values[appAccountTokenStorageKey], token);
    expect(storage.values.containsKey('file_master_key_v1'), isFalse);
  });

  test(
    'malformed error response is typed and does not create an account session',
    () async {
      final adapter = _RecordingAdapter()
        ..statusCode = 503
        ..body = '{invalid-json';
      final storage = _FakeTokenStorage();
      final client = HttpAppAccountClient(
        Dio()..httpClientAdapter = adapter,
        config: config,
        storage: storage,
      );

      await expectLater(
        client.verifyOtp('person@example.test', '123456'),
        throwsA(isA<AppAccountFailure>()),
      );
      expect(storage.values.containsKey(appAccountTokenStorageKey), isFalse);
    },
  );

  test('malformed OTP profile does not replace an existing session', () async {
    final adapter = _RecordingAdapter()
      ..body = jsonEncode({
        'data': {
          'token': token,
          'profile': {'categories': 'car'},
        },
      });
    const previousToken =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    final storage = _FakeTokenStorage()
      ..values[appAccountTokenStorageKey] = previousToken;
    final client = HttpAppAccountClient(
      Dio()..httpClientAdapter = adapter,
      config: config,
      storage: storage,
    );

    await expectLater(
      client.verifyOtp('person@example.test', '123456'),
      throwsA(
        isA<AppAccountFailure>().having(
          (failure) => failure.code,
          'code',
          'invalid_response',
        ),
      ),
    );
    expect(storage.values[appAccountTokenStorageKey], previousToken);
  });

  test(
    'failed token persistence does not return an authenticated profile',
    () async {
      final adapter = _RecordingAdapter()
        ..body = jsonEncode({
          'data': {
            'token': token,
            'profile': {
              'id': 'synthetic-id',
              'name': null,
              'email': 'person@example.test',
              'phone': null,
              'municipality': null,
              'categories': [],
              'privacyVersion': 'v1',
              'marketingConsent': false,
            },
          },
        });
      final storage = _FakeTokenStorage()..failWrites = true;
      final client = HttpAppAccountClient(
        Dio()..httpClientAdapter = adapter,
        config: config,
        storage: storage,
      );

      await expectLater(
        client.verifyOtp('person@example.test', '123456'),
        throwsA(isA<StateError>()),
      );
      expect(storage.values.containsKey(appAccountTokenStorageKey), isFalse);
    },
  );

  test('profile payload is allowlisted and logout preserves local garage and documents', () async {
    final adapter = _RecordingAdapter()
      ..body = jsonEncode({
        'data': {
          'profile': {
            'id': 'synthetic-id',
            'name': 'Perfil sintético',
            'email': 'person@example.test',
            'phone': null,
            'municipality': 'Bogotá',
            'categories': ['car'],
            'privacyVersion': 'v1',
            'marketingConsent': false,
          },
        },
      });
    final storage = _FakeTokenStorage()
      ..values[appAccountTokenStorageKey] = token;
    storage.localData['garage'] = 'synthetic vehicle stays local';
    storage.localData['documents'] = 'synthetic file stays local';
    final client = HttpAppAccountClient(
      Dio()..httpClientAdapter = adapter,
      config: config,
      storage: storage,
    );

    await client.updateProfile(
      name: 'Perfil sintético',
      phone: '',
      municipality: 'Bogotá',
      categories: ['car'],
    );
    expect(adapter.requests.single.data.keys.toSet(), {
      'name',
      'phone',
      'municipality',
      'categories',
    });
    expect(adapter.requests.single.data.containsKey('plate'), isFalse);
    expect(adapter.requests.single.data.containsKey('garage'), isFalse);
    expect(adapter.requests.single.headers['Authorization'], 'Bearer $token');

    await client.logout();
    expect(storage.values.containsKey(appAccountTokenStorageKey), isFalse);
    expect(storage.localData, {
      'garage': 'synthetic vehicle stays local',
      'documents': 'synthetic file stays local',
    });

    storage.values[appAccountTokenStorageKey] = token;
    await client.suppress();
    expect(storage.values.containsKey(appAccountTokenStorageKey), isFalse);
    expect(storage.localData, {
      'garage': 'synthetic vehicle stays local',
      'documents': 'synthetic file stays local',
    });
  });

  test('HTTP redirect is not followed for an account request', () async {
    final adapter = _RecordingAdapter()
      ..statusCode = 302
      ..headers = {
        'location': ['https://other.example.test/'],
      };
    final client = HttpAppAccountClient(
      Dio()..httpClientAdapter = adapter,
      config: config,
      storage: _FakeTokenStorage(),
    );

    await expectLater(
      client.requestOtp('person@example.test', privacyAccepted: true),
      throwsA(isA<AppAccountFailure>()),
    );
    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.followRedirects, isFalse);
  });

  test('offline suppression keeps the secure token for a retry and local data intact', () async {
    final adapter = _RecordingAdapter()
      ..statusCode = 503
      ..body = const {
        'error': {'code': 'not_configured'},
      };
    final storage = _FakeTokenStorage()
      ..values[appAccountTokenStorageKey] = token;
    storage.localData['garage'] = 'synthetic vehicle';
    storage.localData['documents'] = 'synthetic local document';
    final client = HttpAppAccountClient(
      Dio()..httpClientAdapter = adapter,
      config: config,
      storage: storage,
    );

    await expectLater(client.suppress(), throwsA(isA<AppAccountFailure>()));
    expect(storage.values[appAccountTokenStorageKey], token);
    expect(storage.localData, {
      'garage': 'synthetic vehicle',
      'documents': 'synthetic local document',
    });
  });
}

class _FakeTokenStorage implements AppAccountTokenStorage {
  final values = <String, String>{};
  final localData = <String, String>{};
  bool failWrites = false;

  @override
  Future<void> deleteSecret(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> readSecret(String key) async => values[key];

  @override
  Future<void> writeSecret(String key, String value) async {
    if (failWrites) throw StateError('synthetic secure storage failure');
    values[key] = value;
  }
}

class _RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Object? body = const {
    'data': {'status': 'accepted'},
  };
  int statusCode = 200;
  Map<String, List<String>> headers = const {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final content = body is String ? body as String : jsonEncode(body);
    return ResponseBody.fromString(
      content,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
