import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:picoradar/main.dart';

void main() {
  testWidgets('PicoRadar app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PicoRadarApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('PicoRadar'), findsOneWidget);
    expect(find.text('PicoRadar scaffold'), findsOneWidget);
  });
}
