import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/pico_placa/platform/pico_notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');

  setUp(AndroidFlutterLocalNotificationsPlugin.registerWith);
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  for (final payload in ['/pico', '/pico?vehicleId=car-2']) {
    test(
      'concurrent initialization shares native work and launch delivery: $payload',
      () async {
        final entered = Completer<void>();
        final release = Completer<void>();
        var initializations = 0;
        var launches = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              if (call.method == 'initialize') {
                initializations++;
                if (!entered.isCompleted) entered.complete();
                await release.future;
                return true;
              }
              if (call.method == 'getNotificationAppLaunchDetails') {
                launches++;
                return {
                  'notificationLaunchedApp': true,
                  'notificationResponse': {
                    'payload': payload,
                    'notificationId': 42,
                    'notificationResponseType': 0,
                  },
                };
              }
              throw StateError('Unexpected method ${call.method}');
            });
        final scheduler = PicoNotificationScheduler();
        final first = scheduler.initialize();
        await entered.future;
        final routes = <String>[];
        final second = scheduler.initialize(onRoute: routes.add);
        release.complete();
        await Future.wait([first, second]);
        await scheduler.initialize(onRoute: routes.add);
        expect(initializations, 1);
        expect(launches, 1);
        expect(routes, [payload]);
      },
    );
  }

  test('failed launch lookup can retry initialization', () async {
    var initializations = 0;
    var launches = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'initialize') {
            initializations++;
            return true;
          }
          if (call.method == 'getNotificationAppLaunchDetails') {
            launches++;
            if (launches == 1) throw PlatformException(code: 'test-failure');
            return {'notificationLaunchedApp': false};
          }
          throw StateError('Unexpected method ${call.method}');
        });
    final scheduler = PicoNotificationScheduler();
    await expectLater(
      scheduler.initialize(),
      throwsA(isA<PlatformException>()),
    );
    await scheduler.initialize();
    expect(initializations, 2);
    expect(launches, 2);
  });
}
