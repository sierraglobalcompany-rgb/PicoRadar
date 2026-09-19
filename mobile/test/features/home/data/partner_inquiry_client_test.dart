import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/home/data/partner_inquiry_client.dart';
import 'package:picoradar/features/home/data/partner_inquiry_config.dart';

void main() {
  late Dio dio;
  late _PartnerAdapter adapter;

  setUp(() {
    adapter = _PartnerAdapter();
    dio = Dio()..httpClientAdapter = adapter;
  });

  tearDown(() => dio.close(force: true));

  test('posts the consented minimal payload with an idempotency key', () async {
    final client = HttpPartnerInquiryClient(dio, config: _readyConfig);

    final receipt = await client.submit(_draft);

    expect(receipt.id, 'pi_test');
    expect(receipt.status, 'pending');
    expect(adapter.calls, 1);
    expect(adapter.last!.method, 'POST');
    expect(
      adapter.last!.uri,
      Uri.parse('https://api.example.test/api/v1/partner-inquiries'),
    );
    expect(adapter.last!.headers['Idempotency-Key'], _draft.idempotencyKey);
    expect(adapter.last!.headers['Accept'], 'application/json');

    final body = Map<String, Object?>.from(adapter.last!.data as Map);
    expect(body['businessName'], 'Taller Ejemplo SAS');
    expect(body['consentAccepted'], isTrue);
    expect(body['consentVersion'], 'privacy-v1');
    for (final prohibited in const [
      'plate',
      'gps',
      'latitude',
      'longitude',
      'documents',
      'attachments',
    ]) {
      expect(body, isNot(contains(prohibited)));
    }
  });

  test(
    'fails closed before the network when readiness is incomplete',
    () async {
      final client = HttpPartnerInquiryClient(
        dio,
        config: const PartnerInquiryConfig.disabled(),
      );

      await expectLater(
        client.submit(_draft),
        throwsA(
          isA<PartnerInquiryFailure>().having(
            (failure) => failure.code,
            'code',
            'not_configured',
          ),
        ),
      );
      expect(adapter.calls, 0);
    },
  );

  test('exposes only allow-listed server failure codes', () async {
    adapter
      ..status = 418
      ..body = {
        'error': {'code': 'database_table_missing'},
      };
    final client = HttpPartnerInquiryClient(dio, config: _readyConfig);

    await expectLater(
      client.submit(_draft),
      throwsA(
        isA<PartnerInquiryFailure>().having(
          (failure) => failure.code,
          'code',
          'server_error',
        ),
      ),
    );
  });
}

const _readyConfig = PartnerInquiryConfig(
  enabled: true,
  apiBaseUrl: 'https://api.example.test',
  privacyVersion: 'privacy-v1',
  privacyUrl: 'https://example.test/privacy',
  adminReviewConfigured: true,
);

const _draft = PartnerInquiryDraft(
  idempotencyKey: 'mobile-test-idempotency-key',
  businessName: ' Taller Ejemplo SAS ',
  contactName: 'Persona Ejemplo',
  email: 'contacto@example.test',
  phone: '+57 300 000 0000',
  city: 'Medellin',
  category: 'workshop',
  message: '',
  consentVersion: 'privacy-v1',
);

class _PartnerAdapter implements HttpClientAdapter {
  int status = 201;
  Object? body = {
    'data': {'id': 'pi_test', 'status': 'pending'},
  };
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
