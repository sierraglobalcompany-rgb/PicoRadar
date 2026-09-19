import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/home/data/partner_inquiry_client.dart';
import 'package:picoradar/features/home/data/partner_inquiry_config.dart';
import 'package:picoradar/features/home/presentation/home_partner_carousel.dart';

void main() {
  testWidgets('carousel has four manual slides and never auto advances', (
    tester,
  ) async {
    await _pumpCarousel(tester);

    expect(find.byKey(const ValueKey('home-partner-carousel')), findsOneWidget);
    expect(find.text('Automotor de demostración'), findsOneWidget);
    expect(find.text('1 de 4'), findsOneWidget);

    await tester.pump(const Duration(seconds: 20));

    expect(find.text('Automotor de demostración'), findsOneWidget);
    expect(find.text('1 de 4'), findsOneWidget);
  });

  testWidgets('cards do not overflow across the Home viewport matrix', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    for (final variant in const [
      (Size(360, 800), 1.0),
      (Size(390, 844), 1.0),
      (Size(412, 915), 1.0),
      (Size(390, 844), 1.5),
      (Size(390, 844), 2.0),
    ]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = variant.$1;
      tester.platformDispatcher.textScaleFactorTestValue = variant.$2;

      await _pumpCarousel(tester);
      await _goToRecruitmentSlide(tester);

      expect(tester.takeException(), isNull, reason: 'variant: $variant');
    }
  });

  testWidgets('first three slides open local explanation only', (tester) async {
    final client = _RecordingPartnerInquiryClient();
    await _pumpCarousel(tester, client: client);

    for (final entry in const [
      ('automotor', 'Automotor de demostración'),
      ('insurance', 'Seguro de demostración'),
      ('appraisal', 'Peritaje de demostración'),
    ]) {
      expect(find.text(entry.$2), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('home-partner-slide-${entry.$1}')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('home-partner-demo-${entry.$1}')),
        findsOneWidget,
      );
      expect(find.text('No se recopilan ni envían datos.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('partner-inquiry-submit')),
        findsNothing,
      );
      Navigator.of(tester.element(find.text('Cerrar'))).pop();
      await tester.pumpAndSettle();
      if (entry.$1 != 'appraisal') {
        await tester.fling(
          find.byKey(const ValueKey('home-partner-page-view')),
          const Offset(-500, 0),
          1200,
        );
        await tester.pumpAndSettle();
      }
    }

    expect(client.submissions, isEmpty);
  });

  testWidgets('fourth slide opens full consented partner form in dev tests', (
    tester,
  ) async {
    final client = _RecordingPartnerInquiryClient();
    await _pumpCarousel(tester, client: client, ready: true);
    await _goToRecruitmentSlide(tester);

    await tester.tap(
      find.byKey(const ValueKey('home-partner-slide-recruitment')),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(PartnerInquiryForm),
        matching: find.text('Quiero ser aliado'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('partner-inquiry-business')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('partner-inquiry-contact')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('partner-inquiry-email')), findsOneWidget);
    expect(find.byKey(const ValueKey('partner-inquiry-phone')), findsOneWidget);
    expect(find.byKey(const ValueKey('partner-inquiry-city')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('partner-inquiry-category')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('partner-inquiry-message')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('partner-inquiry-privacy-link')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('partner-inquiry-business')),
      'Taller Ejemplo SAS',
    );
    await tester.enterText(
      find.byKey(const ValueKey('partner-inquiry-contact')),
      'Persona Ejemplo',
    );
    await tester.enterText(
      find.byKey(const ValueKey('partner-inquiry-email')),
      'contacto@example.test',
    );
    await tester.enterText(
      find.byKey(const ValueKey('partner-inquiry-phone')),
      '+57 300 000 0000',
    );
    await tester.enterText(
      find.byKey(const ValueKey('partner-inquiry-city')),
      'Medellín',
    );
    await tester.enterText(
      find.byKey(const ValueKey('partner-inquiry-message')),
      'Quiero conocer el programa.',
    );

    final submit = find.byKey(const ValueKey('partner-inquiry-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(client.submissions, isEmpty);
    expect(find.text('Debes autorizar el contacto.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('partner-inquiry-consent')));
    await tester.pump();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(client.submissions, hasLength(1));
    expect(client.submissions.single.businessName, 'Taller Ejemplo SAS');
    expect(client.submissions.single.consentVersion, 'dev-test-v1');
    expect(find.text('Solicitud recibida'), findsOneWidget);
  });

  testWidgets('recruitment form remains closed when readiness gate is off', (
    tester,
  ) async {
    await _pumpCarousel(tester);
    await _goToRecruitmentSlide(tester);

    await tester.tap(
      find.byKey(const ValueKey('home-partner-slide-recruitment')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Programa en preparación'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('partner-inquiry-business')),
      findsNothing,
    );
  });
}

Future<void> _pumpCarousel(
  WidgetTester tester, {
  _RecordingPartnerInquiryClient? client,
  bool ready = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        partnerInquiryConfigProvider.overrideWithValue(
          ready ? _readyConfig : const PartnerInquiryConfig.disabled(),
        ),
        partnerInquiryClientProvider.overrideWithValue(
          client ?? _RecordingPartnerInquiryClient(),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: HomePartnerCarousel()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _goToRecruitmentSlide(WidgetTester tester) async {
  for (var index = 0; index < 3; index++) {
    await tester.fling(
      find.byKey(const ValueKey('home-partner-page-view')),
      const Offset(-500, 0),
      1200,
    );
    await tester.pumpAndSettle();
  }
  expect(find.text('Haz crecer tu negocio con PicoRadar'), findsOneWidget);
  expect(find.text('4 de 4'), findsOneWidget);
}

const _readyConfig = PartnerInquiryConfig(
  enabled: true,
  apiBaseUrl: 'http://127.0.0.1:8000',
  privacyVersion: 'dev-test-v1',
  privacyUrl: 'https://example.test/dev-privacy',
  adminReviewConfigured: true,
  allowInsecureDev: true,
);

class _RecordingPartnerInquiryClient implements PartnerInquiryClient {
  final submissions = <PartnerInquiryDraft>[];

  @override
  Future<PartnerInquiryReceipt> submit(PartnerInquiryDraft draft) async {
    submissions.add(draft);
    return const PartnerInquiryReceipt(id: 'pi_test', status: 'pending');
  }
}
