import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/vehicle_status/presentation/insurance_quote_demo.dart';

final _vehicle = VehicleProfile(
  id: 'demo-vehicle',
  plate: 'BOG127',
  kind: VehicleKind.car,
  serviceType: VehicleServiceType.private,
  brand: 'Marca de ejemplo',
  model: 'Modelo de ejemplo',
  year: 2024,
  registrationCity: 'Bogot\u00e1',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Future<void> _pump(
  WidgetTester tester, {
  double scale = 1,
  double width = 390,
  double height = 844,
  double keyboard = 0,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, height),
          textScaler: TextScaler.linear(scale),
          viewInsets: EdgeInsets.only(bottom: keyboard),
        ),
        child: Scaffold(body: InsuranceQuoteDemoSheet(vehicle: _vehicle)),
      ),
    ),
  );
}

Future<void> _fill(WidgetTester tester) async {
  for (final entry in const {
    'department': 'Bogot\u00e1 D.C.',
    'circulation': 'Medell\u00edn',
  }.entries) {
    final field = find.byKey(ValueKey('insurance-demo-${entry.key}'));
    await tester.ensureVisible(field);
    await tester.enterText(field, entry.value);
  }
}

Future<void> _next(WidgetTester tester) async {
  final next = find.byKey(const ValueKey('insurance-demo-next'));
  await tester.ensureVisible(next);
  await tester.tap(next);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('production entry point does not expose demonstration', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showInsuranceQuoteDemo(context, _vehicle),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    if (insuranceQuoteDemoAvailable) return;
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(InsuranceQuoteDemoSheet), findsNothing);
  });

  testWidgets(
    'required vehicle data is validated without changing original vehicle',
    (tester) async {
      await _pump(tester);
      await _next(tester);
      expect(
        find.text('Completa este dato del veh\u00edculo.'),
        findsNWidgets(2),
      );
      expect(find.text('1 de 3 \u00b7 Veh\u00edculo'), findsOneWidget);
      expect(_vehicle.registrationCity, 'Bogot\u00e1');
      expect(_vehicle.plate, 'BOG127');
    },
  );

  testWidgets('invalid model year and plate cannot advance', (tester) async {
    await _pump(tester);
    await _fill(tester);
    for (final entry in const {'plate': '***', 'year': 'abc'}.entries) {
      final field = find.byKey(ValueKey('insurance-demo-${entry.key}'));
      await tester.ensureVisible(field);
      await tester.enterText(field, entry.value);
    }
    await _next(tester);
    expect(find.text('Revisa el a\u00f1o.'), findsOneWidget);
    expect(find.text('Revisa el formato de la placa.'), findsOneWidget);
  });

  testWidgets(
    'applicant is fictitious read-only and both consents are required',
    (tester) async {
      await _pump(tester);
      await _fill(tester);
      await _next(tester);
      expect(find.byType(EditableText), findsNothing);
      expect(find.text('ejemplo@example.invalid'), findsOneWidget);
      await _next(tester);
      final next = find.byKey(const ValueKey('insurance-demo-next'));
      expect(tester.widget<FilledButton>(next).onPressed, isNull);
      final terms = find.byKey(const ValueKey('insurance-demo-terms'));
      final privacy = find.byKey(const ValueKey('insurance-demo-privacy'));
      expect(tester.widget<CheckboxListTile>(terms).value, isFalse);
      expect(tester.widget<CheckboxListTile>(privacy).value, isFalse);
      await tester.ensureVisible(terms);
      await tester.tap(terms);
      await tester.pump();
      expect(tester.widget<FilledButton>(next).onPressed, isNull);
      await tester.ensureVisible(privacy);
      await tester.tap(privacy);
      await tester.pump();
      expect(tester.widget<FilledButton>(next).onPressed, isNotNull);
      await _next(tester);
      expect(
        find.text(
          'Demostraci\u00f3n finalizada. No se envi\u00f3 ninguna solicitud.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('insurance-demo-next')), findsNothing);
    },
  );

  testWidgets('completion requires no HTTP client or transport', (
    tester,
  ) async {
    final original = HttpOverrides.current;
    final forbidden = _NoHttp();
    HttpOverrides.global = forbidden;
    addTearDown(() => HttpOverrides.global = original);
    await _pump(tester);
    await _fill(tester);
    await _next(tester);
    await _next(tester);
    for (final key in ['insurance-demo-terms', 'insurance-demo-privacy']) {
      final tile = find.byKey(ValueKey(key));
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pump();
    }
    await _next(tester);
    expect(forbidden.attempts, 0);
    expect(
      find.byKey(const ValueKey('insurance-demo-finished')),
      findsOneWidget,
    );
  });

  for (final width in [360.0, 390.0, 412.0, 430.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'demo scroll keeps controls reachable at $width x $scale with keyboard',
        (tester) async {
          await _pump(
            tester,
            width: width,
            height: 780,
            scale: scale,
            keyboard: 280,
          );
          await _fill(tester);
          await _next(tester);
          expect(tester.takeException(), isNull);
          expect(find.byType(EditableText), findsNothing);
          await _next(tester);
          for (final key in [
            'insurance-demo-terms',
            'insurance-demo-privacy',
            'insurance-demo-next',
          ]) {
            final control = find.byKey(ValueKey(key));
            await tester.ensureVisible(control);
            expect(tester.getSize(control).height, greaterThanOrEqualTo(48));
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

class _NoHttp extends HttpOverrides {
  var attempts = 0;
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('Quote demonstration must not create an HTTP client.');
  }
}
