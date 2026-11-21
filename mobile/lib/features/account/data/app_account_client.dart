import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/app_secure_storage.dart';
import 'app_account_config.dart';

const appAccountTokenStorageKey = 'app_account_access_token_v1';

final appAccountClientProvider = Provider<AppAccountClient>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 10),
      followRedirects: false,
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  return HttpAppAccountClient(dio, config: ref.watch(appAccountConfigProvider));
});

abstract interface class AppAccountClient {
  Future<void> requestOtp(String email, {required bool privacyAccepted});
  Future<AppAccountProfile> verifyOtp(String email, String code);
  Future<AppAccountProfile> loadProfile();
  Future<AppAccountProfile> updateProfile({
    required String name,
    required String phone,
    required String municipality,
    required List<String> categories,
  });
  Future<bool> updateMarketing(bool accepted);
  Future<void> logout();
  Future<void> suppress();
}

class HttpAppAccountClient implements AppAccountClient {
  HttpAppAccountClient(
    this._dio, {
    required this.config,
    AppAccountTokenStorage? storage,
  }) : _storage = storage ?? SecureAppAccountTokenStorage(AppSecureStorage());

  final Dio _dio;
  final AppAccountConfig config;
  final AppAccountTokenStorage _storage;

  @override
  Future<void> requestOtp(String email, {required bool privacyAccepted}) async {
    await _send(
      'POST',
      '/api/v1/app-accounts/otp',
      body: {'email': email.trim(), 'privacyAccepted': privacyAccepted},
    );
  }

  @override
  Future<AppAccountProfile> verifyOtp(String email, String code) async {
    final data = await _send(
      'POST',
      '/api/v1/app-accounts/otp/verify',
      body: {'email': email.trim(), 'code': code.trim()},
    );
    final token = data['token'];
    if (token is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(token)) {
      throw const AppAccountFailure('invalid_response');
    }
    final profile = data['profile'];
    if (profile is! Map) throw const AppAccountFailure('invalid_response');
    final AppAccountProfile parsedProfile;
    try {
      parsedProfile = AppAccountProfile.fromJson(
        Map<String, Object?>.from(profile),
      );
    } on FormatException {
      throw const AppAccountFailure('invalid_response');
    } on TypeError {
      throw const AppAccountFailure('invalid_response');
    }
    await _storage.writeSecret(appAccountTokenStorageKey, token);
    return parsedProfile;
  }

  @override
  Future<AppAccountProfile> loadProfile() async {
    final data = await _send('GET', '/api/v1/app-account', authenticated: true);
    final profile = data['profile'];
    if (profile is! Map) throw const AppAccountFailure('invalid_response');
    return AppAccountProfile.fromJson(Map<String, Object?>.from(profile));
  }

  @override
  Future<AppAccountProfile> updateProfile({
    required String name,
    required String phone,
    required String municipality,
    required List<String> categories,
  }) async {
    final data = await _send(
      'PATCH',
      '/api/v1/app-account',
      authenticated: true,
      body: {
        'name': name.trim().isEmpty ? null : name.trim(),
        'phone': phone.trim().isEmpty ? null : phone.trim(),
        'municipality': municipality.trim().isEmpty
            ? null
            : municipality.trim(),
        'categories': categories,
      },
    );
    final profile = data['profile'];
    if (profile is! Map) throw const AppAccountFailure('invalid_response');
    return AppAccountProfile.fromJson(Map<String, Object?>.from(profile));
  }

  @override
  Future<bool> updateMarketing(bool accepted) async {
    final data = await _send(
      'PATCH',
      '/api/v1/app-account/marketing',
      authenticated: true,
      body: {'marketingConsent': accepted},
    );
    return data['marketingConsent'] == true;
  }

  @override
  Future<void> logout() async {
    await _send('POST', '/api/v1/app-account/logout', authenticated: true);
    await _storage.deleteSecret(appAccountTokenStorageKey);
  }

  @override
  Future<void> suppress() async {
    await _send('DELETE', '/api/v1/app-account', authenticated: true);
    await _storage.deleteSecret(appAccountTokenStorageKey);
  }

  Future<Map<String, Object?>> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
    bool authenticated = false,
  }) async {
    final base = config.apiBaseUri;
    if (!config.isAvailable || base == null) {
      throw const AppAccountFailure('not_configured');
    }
    final token = authenticated
        ? await _storage.readSecret(appAccountTokenStorageKey)
        : null;
    if (authenticated && token == null) {
      throw const AppAccountFailure('unauthorized');
    }
    final headers = <String, Object>{'Accept': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    try {
      final response = await _dio.request<Object?>(
        base.resolve(path).toString(),
        data: body,
        options: Options(
          method: method,
          headers: headers,
          followRedirects: false,
        ),
      );
      if (response.statusCode == 204) return <String, Object?>{};
      final decoded = _decode(response.data);
      if ((response.statusCode ?? 500) < 200 ||
          (response.statusCode ?? 500) >= 300) {
        throw AppAccountFailure(_errorCode(decoded));
      }
      final data = decoded?['data'];
      return data is Map
          ? Map<String, Object?>.from(data)
          : <String, Object?>{};
    } on AppAccountFailure {
      rethrow;
    } on DioException catch (error) {
      final data = _decode(error.response?.data);
      throw AppAccountFailure(
        error.response?.statusCode == 503 ? 'not_configured' : _errorCode(data),
      );
    } on FormatException {
      throw const AppAccountFailure('invalid_response');
    } on TypeError {
      throw const AppAccountFailure('invalid_response');
    }
  }

  Map<String, Object?>? _decode(Object? source) {
    final value = source is String ? jsonDecode(source) : source;
    return value is Map ? Map<String, Object?>.from(value) : null;
  }

  String _errorCode(Map<String, Object?>? response) {
    const safe = {
      'not_configured',
      'unauthorized',
      'rate_limited',
      'validation_failed',
      'invalid_or_expired_code',
      'server_error',
      'secure_transport_required',
    };
    final error = response?['error'];
    final code = error is Map ? error['code']?.toString() : null;
    return safe.contains(code) ? code! : 'server_error';
  }
}

abstract interface class AppAccountTokenStorage {
  Future<String?> readSecret(String key);
  Future<void> writeSecret(String key, String value);
  Future<void> deleteSecret(String key);
}

class SecureAppAccountTokenStorage implements AppAccountTokenStorage {
  const SecureAppAccountTokenStorage(this.storage);

  final AppSecureStorage storage;

  @override
  Future<String?> readSecret(String key) => storage.readSecret(key);

  @override
  Future<void> writeSecret(String key, String value) =>
      storage.writeSecret(key, value);

  @override
  Future<void> deleteSecret(String key) => storage.deleteSecret(key);
}

class AppAccountProfile {
  const AppAccountProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.municipality,
    required this.categories,
    required this.privacyVersion,
    required this.marketingConsent,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String municipality;
  final List<String> categories;
  final String privacyVersion;
  final bool marketingConsent;

  factory AppAccountProfile.fromJson(Map<String, Object?> json) {
    return AppAccountProfile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      municipality: json['municipality']?.toString() ?? '',
      categories: (json['categories'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      privacyVersion: json['privacyVersion']?.toString() ?? '',
      marketingConsent: json['marketingConsent'] == true,
    );
  }
}

class AppAccountFailure implements Exception {
  const AppAccountFailure(this.code);

  final String code;
}
