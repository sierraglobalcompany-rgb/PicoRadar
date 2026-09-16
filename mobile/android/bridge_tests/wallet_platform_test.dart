import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:picoradar/features/documents/platform/wallet_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('co.picoradar.app/wallet');
  const platform = WalletPlatform(channel: channel);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('cancel is null, successful scan has private JPEG paths', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    expect(await platform.scan(), isNull);
    expect(calls.single.arguments, {'maxPages': 2});
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => [
        {
          'path': '/data/user/0/app/no_backup/wallet_capture/front.jpg',
          'originalName': 'scan-front.jpg',
          'mimeType': 'image/jpeg',
        },
      ],
    );
    final files = await platform.scan(maxPages: 1);
    expect(files!.single.mimeType, 'image/jpeg');
    expect(files.single.path, startsWith('/data/'));
  });

  test('invalid scan limit never reaches native code', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    await expectLater(platform.scan(maxPages: 3), throwsArgumentError);
    await expectLater(platform.scan(maxPages: 0), throwsArgumentError);
    expect(calls, isEmpty);
  });

  test('native and absent-plugin unsupported are typed failures', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(
        code: 'unsupported',
        message: 'Scanner unavailable',
      );
    });
    await expectLater(
      platform.scan(),
      throwsA(
        isA<WalletPlatformException>().having(
          (e) => e.code,
          'code',
          'unsupported',
        ),
      ),
    );
    messenger.setMockMethodCallHandler(channel, null);
    await expectLater(
      platform.openPdf('/private/document.pdf'),
      throwsA(
        isA<WalletPlatformException>().having(
          (e) => e.code,
          'code',
          'unsupported',
        ),
      ),
    );
  });

  test('iOS fails explicitly without calling Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    await expectLater(
      platform.setSecure(true),
      throwsA(isA<WalletPlatformException>()),
    );
    expect(calls, isEmpty);
  });

  test(
    'PDF session and PNG use agreed wire methods and zero-based pages',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return switch (call.method) {
          'openPdf' => {'id': 'session', 'pageCount': 2},
          'renderPdfPage' => Uint8List.fromList([
            137,
            80,
            78,
            71,
            13,
            10,
            26,
            10,
          ]),
          'noBackupDirectory' => '/data/user/0/app/no_backup',
          _ => null,
        };
      });
      await platform.setSecure(true);
      expect(await platform.noBackupDirectory(), endsWith('/no_backup'));
      final pdf = await platform.openPdf('/private/document.pdf');
      expect(pdf.pageCount, 2);
      expect(await platform.renderPdfPage(pdf.id, 0, 1080), isA<Uint8List>());
      await platform.closePdf(pdf.id);
      expect(calls[0].arguments, {'enabled': true});
      expect(calls[3].arguments, {'id': 'session', 'page': 0, 'width': 1080});
    },
  );

  test('malformed native PDF response is rejected', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {'id': '', 'pageCount': 0},
    );
    await expectLater(
      platform.openPdf('/private/doc.pdf'),
      throwsA(
        isA<WalletPlatformException>().having(
          (e) => e.code,
          'code',
          'invalid_result',
        ),
      ),
    );
  });

  test('render bounds are checked before native invocation', () async {
    await expectLater(
      platform.renderPdfPage('id', -1, 100),
      throwsArgumentError,
    );
    await expectLater(
      platform.renderPdfPage('id', 0, 2049),
      throwsArgumentError,
    );
    await expectLater(platform.renderPdfPage('', 0, 100), throwsArgumentError);
  });

  test('legacy PDFs retain all pages beyond 100', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'openPdf'
          ? {'id': 'legacy', 'pageCount': 350}
          : Uint8List.fromList([137, 80, 78, 71]);
    });
    expect((await platform.openPdf('/private/legacy.pdf')).pageCount, 350);
    await platform.renderPdfPage('legacy', 349, 1000);
    expect(calls.last.arguments, {'id': 'legacy', 'page': 349, 'width': 1000});
  });

  test('scan cleanup forwards only explicit paths', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    await platform.deleteScanTemps(['/private/scan.jpg']);
    expect(calls.single.method, 'deleteScanTemps');
    expect(calls.single.arguments, {
      'paths': ['/private/scan.jpg'],
    });
  });
}
