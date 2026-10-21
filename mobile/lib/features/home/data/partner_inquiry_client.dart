import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'partner_inquiry_config.dart';

final partnerInquiryClientProvider = Provider<PartnerInquiryClient>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 10),
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  return HttpPartnerInquiryClient(
    dio,
    config: ref.watch(partnerInquiryConfigProvider),
  );
});

abstract interface class PartnerInquiryClient {
  Future<PartnerInquiryReceipt> submit(PartnerInquiryDraft draft);
}

class HttpPartnerInquiryClient implements PartnerInquiryClient {
  HttpPartnerInquiryClient(this._dio, {required this.config});

  final Dio _dio;
  final PartnerInquiryConfig config;

  @override
  Future<PartnerInquiryReceipt> submit(PartnerInquiryDraft draft) async {
    final baseUri = config.apiBaseUri;
    if (!config.isAvailable || baseUri == null) {
      throw const PartnerInquiryFailure('not_configured');
    }
    try {
      final response = await _dio.post<Object?>(
        baseUri.resolve('/api/v1/partner-inquiries').toString(),
        data: draft.toJson(),
        options: Options(
          followRedirects: false,
          maxRedirects: 0,
          validateStatus: (_) => true,
          headers: {
            'Accept': 'application/json',
            'Idempotency-Key': draft.idempotencyKey,
          },
        ),
      );
      final body = _jsonMap(response.data);
      if (response.statusCode != 200 && response.statusCode != 201) {
        final error = body?['error'];
        final code = error is Map ? error['code']?.toString() : null;
        throw PartnerInquiryFailure(_safeFailureCode(code));
      }
      final data = body?['data'];
      if (data is! Map || data['id'] is! String || data['status'] is! String) {
        throw const PartnerInquiryFailure('invalid_response');
      }
      return PartnerInquiryReceipt(
        id: data['id'] as String,
        status: data['status'] as String,
      );
    } on PartnerInquiryFailure {
      rethrow;
    } on DioException catch (error) {
      throw PartnerInquiryFailure(switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout => 'timeout',
        _ => 'network',
      });
    } on FormatException {
      throw const PartnerInquiryFailure('invalid_response');
    } on TypeError {
      throw const PartnerInquiryFailure('invalid_response');
    }
  }

  Map<String, Object?>? _jsonMap(Object? source) {
    final decoded = source is String ? jsonDecode(source) : source;
    if (decoded is! Map) return null;
    return Map<String, Object?>.from(decoded);
  }

  String _safeFailureCode(String? code) {
    const allowed = {
      'validation_failed',
      'rate_limited',
      'idempotency_conflict',
      'not_configured',
      'server_error',
    };
    return allowed.contains(code) ? code! : 'server_error';
  }
}

class PartnerInquiryDraft {
  const PartnerInquiryDraft({
    required this.idempotencyKey,
    required this.businessName,
    required this.contactName,
    required this.email,
    required this.phone,
    required this.city,
    required this.category,
    required this.message,
    required this.consentVersion,
  });

  final String idempotencyKey;
  final String businessName;
  final String contactName;
  final String email;
  final String phone;
  final String city;
  final String category;
  final String message;
  final String consentVersion;

  Map<String, Object?> toJson() => {
    'businessName': businessName.trim(),
    'contactName': contactName.trim(),
    'email': email.trim(),
    'phone': phone.trim(),
    'city': city.trim(),
    'category': category,
    'message': message.trim().isEmpty ? null : message.trim(),
    'consentAccepted': true,
    'consentVersion': consentVersion,
  };
}

class PartnerInquiryReceipt {
  const PartnerInquiryReceipt({required this.id, required this.status});

  final String id;
  final String status;
}

class PartnerInquiryFailure implements Exception {
  const PartnerInquiryFailure(this.code);

  final String code;
}

String newPartnerInquiryIdempotencyKey() {
  final random = Random.secure();
  final bytes = List<int>.generate(12, (_) => random.nextInt(256));
  final suffix = bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
  return 'mobile-${DateTime.now().microsecondsSinceEpoch}-$suffix';
}
