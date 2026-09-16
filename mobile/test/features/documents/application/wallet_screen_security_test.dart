import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/documents/application/wallet_providers.dart';
import 'package:picoradar/features/documents/platform/wallet_platform.dart';

class _Platform extends WalletPlatform {
  final values = <bool>[];
  bool fail = false;
  Completer<void>? pending;
  @override
  Future<void> setSecure(bool enabled) async {
    values.add(enabled);
    if (pending != null) await pending!.future;
    if (fail) throw const WalletPlatformException('secure_failed');
  }
}

void main() {
  test('closing wallet never unprotects its viewer', () async {
    final platform = _Platform();
    final security = WalletScreenSecurity(platform);
    final wallet = Object(), viewer = Object();
    await security.acquire(wallet);
    await security.acquire(viewer);
    await security.release(wallet);
    expect(platform.values, [true, true, true]);
    await security.release(viewer);
    expect(platform.values.last, isFalse);
  });
  test(
    'native failure propagates to owner and subsequent retry is possible',
    () async {
      final platform = _Platform()..fail = true;
      final security = WalletScreenSecurity(platform);
      final owner = Object();
      await expectLater(
        security.acquire(owner),
        throwsA(isA<WalletPlatformException>()),
      );
      platform.fail = false;
      await security.acquire(owner);
      expect(platform.values, [true, true]);
    },
  );
  test('rapid acquire/release is serialized, final scope wins', () async {
    final platform = _Platform()..pending = Completer<void>();
    final security = WalletScreenSecurity(platform);
    final first = Object(), second = Object();
    final a = security.acquire(first);
    final b = security.release(first);
    final c = security.acquire(second);
    platform.pending!.complete();
    await Future.wait([a, b, c]);
    expect(platform.values, [true, true, true]);
  });
}
