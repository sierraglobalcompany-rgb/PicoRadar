import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/alerts/application/alert_center.dart';
import 'package:picoradar/features/alerts/platform/alert_alarm_gateway.dart';
import 'package:picoradar/features/alerts/presentation/alerts_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var requests = 0;
  var observations = 0;
  late Future<Object?> Function() status;

  setUp(() {
    requests = 0;
    observations = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AlertAlarmGateway.channel, (call) async {
          expect(call.arguments, isNull);
          if (call.method == 'test') {
            requests++;
            return null;
          }
          if (call.method == 'status') {
            observations++;
            return status();
          }
          throw PlatformException(code: 'unexpected_method');
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AlertAlarmGateway.channel, null);
  });

  test(
    'status keeps finite permission codes and rejects private error text',
    () async {
      status = () async => {
        'testState': 'failed',
        'failureCode': 'EXACT_ACCESS_REQUIRED',
      };
      const gateway = AlertAlarmGateway();
      final denied = await gateway.status();
      expect(denied.failureCode, 'EXACT_ACCESS_REQUIRED');
      expect(
        denied.failureMessage,
        'La alarma necesita permisos. Revísalos en los ajustes del teléfono.',
      );
      status = () async => {
        'testState': 'failed',
        'failureCode': 'private-DEM123-/storage/document',
      };
      final unknown = await gateway.status();
      expect(unknown.failureCode, 'ALARM_OPERATION_FAILED');
      expect(unknown.failureMessage, isNot(contains('DEM123')));
      expect(requests, 0);
      expect(observations, 2);
    },
  );

  testWidgets('starting observations stop at the fifteen second deadline', (
    tester,
  ) async {
    status = () async => {'testState': 'starting', 'failureCode': null};
    await _pump(tester);
    await _requestTest(tester);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(
      find.text(
        'No se pudo confirmar el sonido de la alarma. Revisa los permisos y vuelve a probar.',
      ),
      findsOneWidget,
    );
    expect(observations, inInclusiveRange(1, 31));
    final count = observations;
    await tester.pump(const Duration(seconds: 20));
    expect(observations, count);
  });

  for (final terminal in [
    'ringing',
    'failed',
    'stopped',
    'missed',
    'snoozed',
  ]) {
    testWidgets('test acknowledgement waits for native $terminal', (
      tester,
    ) async {
      var state = 'starting';
      status = () async => {
        'testState': state,
        'failureCode': state == 'failed' ? 'PLAYBACK_FAILED' : null,
      };
      await _pump(tester);
      await _requestTest(tester);
      expect(requests, 1);
      expect(observations, greaterThan(0));
      expect(find.text('Esperando confirmación de la alarma…'), findsOneWidget);
      expect(find.text('Sonido de alarma iniciado.'), findsNothing);
      state = terminal;
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      final message = switch (terminal) {
        'ringing' => 'Sonido de alarma iniciado.',
        'failed' => 'No se pudo reproducir la alarma. Revisa el sonido y vuelve a probar.',
        'stopped' => 'Prueba de alarma detenida.',
        'missed' =>
          'La prueba de alarma no llegó a iniciarse. Vuelve a intentarlo.',
        _ => 'Prueba de alarma pospuesta.',
      };
      expect(find.text(message), findsOneWidget);
      expect(find.text('Esperando confirmación de la alarma…'), findsNothing);
      final count = observations;
      await tester.pump(const Duration(seconds: 16));
      expect(observations, count);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('hung native observation times out within fifteen seconds', (
    tester,
  ) async {
    final response = Completer<Object?>();
    status = () => response.future;
    await _pump(tester);
    await _requestTest(tester);
    await tester.pump(const Duration(seconds: 15));
    await tester.pump();
    expect(
      find.text(
        'No se pudo confirmar el sonido de la alarma. Revisa los permisos y vuelve a probar.',
      ),
      findsOneWidget,
    );
    expect(find.text('Esperando confirmación de la alarma…'), findsNothing);
    response.complete({'testState': 'ringing', 'failureCode': null});
    await tester.pump();
    expect(find.text('Sonido de alarma iniciado.'), findsNothing);
    expect(observations, 1);
  });

  for (final leave in ['dispose', 'background']) {
    testWidgets('pending observation is ignored after $leave', (tester) async {
      final response = Completer<Object?>();
      status = () => response.future;
      await _pump(tester);
      await _requestTest(tester);
      expect(observations, 1);
      if (leave == 'dispose') {
        await tester.pumpWidget(const SizedBox.shrink());
      } else {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      }
      response.complete({'testState': 'ringing', 'failureCode': null});
      await tester.pump();
      await tester.pump(const Duration(seconds: 16));
      expect(observations, 1);
      expect(find.text('Sonido de alarma iniciado.'), findsNothing);
      expect(tester.takeException(), isNull);
      if (leave == 'background') {
        await tester.pumpWidget(const SizedBox.shrink());
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      }
    });
  }

  testWidgets('unknown native error never enters user copy', (tester) async {
    status = () async => {
      'testState': 'failed',
      'failureCode': 'private-DEM123-/storage/document',
    };
    await _pump(tester);
    await _requestTest(tester);
    await tester.pump();
    expect(observations, 1);
    expect(find.textContaining('DEM123'), findsNothing);
    expect(
      find.text(
        'No se pudo iniciar la alarma. Revisa los permisos y vuelve a probar.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a test cannot start after the app enters background', (
    tester,
  ) async {
    status = () async => {'testState': 'ringing', 'failureCode': null};
    await _pump(tester);
    await tester.scrollUntilVisible(find.text('Vista previa y prueba'), 200);
    await tester.tap(find.text('Vista previa y prueba'));
    await tester.pumpAndSettle();
    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Probar sonido de alarma'),
    );
    button.onPressed!();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    final actualRequests = requests;
    await tester.pumpWidget(const SizedBox.shrink());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(actualRequests, 0);
    expect(observations, 0);
  });
}

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        alertCenterProvider.overrideWith(
          (ref) async => const AlertCenterData(
            rows: [],
            permission: true,
            capabilities: AlarmCapabilities(
              supported: true,
              notifications: true,
              exact: true,
            ),
          ),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: AlertsScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _requestTest(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('Vista previa y prueba'), 200);
  await tester.tap(find.text('Vista previa y prueba'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Probar sonido de alarma'));
  await tester.tap(find.text('Probar sonido de alarma'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}
