import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/shell/app_shell.dart';
import 'package:picoradar/app/theme/app_theme.dart';
import 'package:picoradar/core/storage/app_preferences.dart';
import 'package:picoradar/features/buy_sell/data/buy_sell_draft.dart';
import 'package:picoradar/features/buy_sell/presentation/buy_sell_screen.dart';
import 'package:picoradar/features/buy_sell/presentation/purchase_documents_screen.dart';
import 'package:picoradar/features/comparendos/data/territorial_catalog.dart';
import 'package:picoradar/features/documents/application/wallet_providers.dart';
import 'package:picoradar/features/documents/application/wallet_session.dart';
import 'package:picoradar/features/documents/data/wallet_store.dart';
import 'package:picoradar/features/documents/platform/wallet_platform.dart';
import 'package:picoradar/features/garage/data/garage_favorites.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/location/application/location_controller.dart';
import 'package:picoradar/features/location/platform/device_location_gateway.dart';
import 'package:picoradar/features/onboarding/data/registration_city_catalog.dart';
import 'package:picoradar/features/vehicle_status/data/tax_catalog.dart';
import 'package:picoradar/features/vehicle_status/platform/external_launcher.dart';

import '../../../plate_test_fonts.dart';

late MemoryPreferences _preferences;
late _FakeExternalLauncher _launcher;
late _FakeLocationGateway _locationGateway;
late _PurchaseWalletStore _walletStore;
late RegistrationCityCatalog _cities;
late TaxCatalog _taxCatalog;
late TerritorialCatalog _territorialCatalog;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadPlateTestFonts);
  purchaseReviewShellTests();
  setUpAll(() {
    _cities = RegistrationCityCatalog.fromJson(
      jsonDecode(File(registrationCityCatalogAssetPath).readAsStringSync())
          as Map<String, Object?>,
    );
    _taxCatalog = TaxCatalog.fromJsonString(
      File(bundledTaxCatalogAsset).readAsStringSync(),
    );
    _territorialCatalog = TerritorialCatalog.fromJson(
      jsonDecode(File(territorialCatalogAssetPath).readAsStringSync())
          as Map<String, Object?>,
    );
  });

  for (final size in const [
    Size(360, 780),
    Size(360, 800),
    Size(390, 844),
    Size(412, 915),
    Size(430, 932),
  ]) {
    for (final scale in const [1.0, 1.5, 2.0]) {
      testWidgets('purchase fits real shell $size text $scale', (tester) async {
        await _pumpScreen(
          tester,
          surfaceSize: size,
          textScale: scale,
          withShell: true,
        );
        await tester.tap(find.byKey(const ValueKey('buy-sell-prepare-buy')));
        await tester.pumpAndSettle();
        final screen = find.byKey(const ValueKey('buy-sell-purchase-screen'));
        final header = tester.widget<DecoratedBox>(
          find.byKey(const ValueKey('buy-sell-purchase-header')),
        );
        expect(
          (header.decoration as BoxDecoration).color,
          const Color(0xFF143963),
        );
        if (size == const Size(360, 780)) {
          await _capturePurchase(tester, 'purchase-text-$scale');
        }
        final navTop = tester
            .getTopLeft(find.byKey(const ValueKey('app-bottom-navigation')))
            .dy;
        if (scale == 1) {
          for (final key in [
            'buy-sell-purchase-save-progress',
            'buy-sell-purchase-notes',
            'buy-sell-purchase-copy-summary',
            'buy-sell-purchase-about',
            'buy-sell-add-candidate-data',
            'buy-sell-attach-registration',
            'buy-sell-purchase-back',
            'buy-sell-my-preparations',
            for (final id in BuySellPreparationStepIds.buy)
              'buy-sell-purchase-step-$id',
          ]) {
            final control = find.byKey(ValueKey(key));
            expect(control.hitTestable(), findsOneWidget, reason: key);
            expect(
              tester.getBottomLeft(control).dy,
              lessThanOrEqualTo(navTop),
              reason: key,
            );
            expect(
              tester.getSize(control).height,
              greaterThanOrEqualTo(48),
              reason: key,
            );
          }
          for (final scrollable in tester.stateList<ScrollableState>(
            find.descendant(of: screen, matching: find.byType(Scrollable)),
          )) {
            expect(scrollable.position.maxScrollExtent, 0);
          }
          expect(
            tester
                .getSize(find.byKey(const ValueKey('buy-sell-purchase-header')))
                .height,
            inInclusiveRange(160, 168),
          );
        } else {
          await tester.ensureVisible(
            find.byKey(const ValueKey('buy-sell-purchase-save-progress')),
          );
          await tester.pumpAndSettle();
          expect(
            find
                .byKey(const ValueKey('buy-sell-purchase-save-progress'))
                .hitTestable(),
            findsOneWidget,
          );
        }
        for (final paragraph in tester.renderObjectList<RenderParagraph>(
          find.descendant(of: screen, matching: find.byType(RichText)),
        )) {
          expect(
            paragraph.didExceedMaxLines,
            isFalse,
            reason: paragraph.text.toPlainText(),
          );
          final boxes = paragraph.getBoxesForSelection(
            TextSelection(
              baseOffset: 0,
              extentOffset: paragraph.text.toPlainText().length,
            ),
          );
          for (final box in boxes) {
            expect(
              box.right,
              lessThanOrEqualTo(paragraph.size.width + 1),
              reason: paragraph.text.toPlainText(),
            );
            expect(
              box.bottom,
              lessThanOrEqualTo(paragraph.size.height + 2 * scale),
              reason: paragraph.text.toPlainText(),
            );
          }
        }
        expect(tester.takeException(), isNull);
        if (size == const Size(360, 780) && scale == 1) {
          await _capturePurchase(tester, 'purchase-normal');
        }
      });
    }
  }

  setUp(() {
    _preferences = MemoryPreferences();
    _launcher = _FakeExternalLauncher();
    _walletStore = _PurchaseWalletStore();
    _locationGateway = _FakeLocationGateway.success(
      const DeviceLocationPoint(
        latitude: 6.244200,
        longitude: -75.581200,
        accuracyMeters: 18,
      ),
    );
  });

  testWidgets(
    'six reviews work without vehicle context and persist v4 checks',
    (tester) async {
      await _pumpScreen(
        tester,
        withShell: true,
        surfaceSize: const Size(360, 780),
      );
      await tester.tap(find.byKey(const ValueKey('buy-sell-prepare-buy')));
      await tester.pumpAndSettle();
      expect(find.textContaining('BOG127'), findsNothing);
      expect(find.text('0 de 6'), findsOneWidget);
      final save = find.byKey(
        const ValueKey('buy-sell-purchase-save-progress'),
      );
      final originalBounds = tester.getRect(save);
      var count = 0;
      for (final id in BuySellPreparationStepIds.buy) {
        final step = find.byKey(ValueKey('buy-sell-purchase-step-$id'));
        final before = tester.getRect(step);
        await tester.tap(step);
        await tester.pumpAndSettle();
        expect(find.text('$count de 6'), findsOneWidget);
        expect(
          find.text('Puedes consultar sin agregar un vehículo'),
          findsOneWidget,
        );
        await _tapVisible(
          tester,
          find.byKey(ValueKey('buy-sell-purchase-reviewed-$id')),
        );
        await _closeReview(tester);
        count++;
        expect(find.text('$count de 6'), findsOneWidget);
        expect(tester.getRect(step), before);
        expect(tester.getRect(save), originalBounds);
        final material = tester.widget<Material>(
          find.ancestor(of: step, matching: find.byType(Material)).first,
        );
        expect(material.color, const Color(0xFF1D62C6));
        if (count == 2 || count == 6) {
          await _capturePurchase(tester, 'purchase-$count-reviewed');
        }
      }
      await tester.tap(save);
      await tester.pumpAndSettle();
      final draft = await loadBuySellDraft(_preferences);
      expect(draft!.candidateVehicle.isEmpty, isTrue);
      expect(_savedJson()['version'], 4);
      expect(
        draft.preparationFor(BuySellMode.buy).checkedItems,
        containsAll(BuySellPreparationStepIds.buy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'malformed JSON preserves the draft and reports restoration failure',
    () async {
      await _preferences.setString(buySellDraftPreferenceKey, '{bad json');

      await expectLater(loadBuySellDraft(_preferences), throwsFormatException);

      expect(
        await _preferences.getString(buySellDraftPreferenceKey),
        '{bad json',
      );
    },
  );

  for (final missingField in ['purchaseContext', 'archivedPurchases']) {
    test(
      'v4 rejects missing $missingField without discarding the source',
      () async {
        final data = jsonDecode(
          BuySellDraft.empty().toJsonString(),
        ) as Map<String, dynamic>;
        expect(data['version'], 4);
        data.remove(missingField);
        final source = jsonEncode(data);
        await _preferences.setString(buySellDraftPreferenceKey, source);

        await expectLater(
          loadBuySellDraft(_preferences),
          throwsFormatException,
        );

        expect(await _preferences.getString(buySellDraftPreferenceKey), source);
      },
    );
  }

  testWidgets('failed restoration blocks saving over the original source', (
    tester,
  ) async {
    const source = '{bad json';
    await _preferences.setString(buySellDraftPreferenceKey, source);
    await _pumpScreen(tester);
    expect(find.textContaining('el guardado está bloqueado'), findsOneWidget);

    await _openPurchase(tester);
    await _savePurchase(tester);

    expect(await _preferences.getString(buySellDraftPreferenceKey), source);
    expect(
      find.text('Preparación guardada en este dispositivo.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  for (final historicalDeclaration in [false, true]) {
    testWidgets(
      'summary refers to the private folder; historical declaration $historicalDeclaration',
      (tester) async {
        await _seedCandidate();
        if (historicalDeclaration) {
          final legacy = _savedJson()
            ..['version'] = 3
            ..['candidateRegistrationAttachment'] = {'frontImage': true};
          await _preferences.setString(
            buySellDraftPreferenceKey,
            jsonEncode(legacy),
          );
        }
        String? copied;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await _pumpScreen(tester);
        await _openPurchase(tester);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('buy-sell-attach-registration')),
            matching: find.text('Adjuntar matrícula'),
          ),
          findsOneWidget,
        );
        expect(find.text('Ver matrícula'), findsNothing);
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('buy-sell-purchase-copy-summary')),
        );

        expect(
          copied,
          contains(
            'Matrícula y soportes: consultar la carpeta privada de esta preparación.',
          ),
        );
        expect(copied, contains('MDE456'));
        expect(copied, isNot(contains('Sin archivo adjunto')));
        expect(copied, isNot(contains('Copia pendiente de importar')));
        expect(
          copied!.contains(
            'Existe una declaración histórica de adjunto; no acredita una copia importada.',
          ),
          historicalDeclaration,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('legacy v1 draft migrates into the selected preparation mode', () async {
    await _preferences.setString(
      buySellDraftPreferenceKey,
      jsonEncode({
        'version': 1,
        'mode': 'sell',
        'candidatePlate': 'ABC123',
        'city': 'Medellín',
        'notes': 'Lista para mostrar',
        'checkedItems': ['Preparar comparendos y paz y salvo.'],
      }),
    );

    final draft = await loadBuySellDraft(_preferences);

    expect(draft, isNotNull);
    expect(draft!.mode, BuySellMode.sell);
    expect(draft.candidatePlate, 'ABC123');
    expect(draft.preparationFor(BuySellMode.sell).notes, 'Lista para mostrar');
    expect(
      draft.preparationFor(BuySellMode.sell).checkedItems,
      contains(BuySellPreparationStepIds.comparendos),
    );
    expect(draft.preparationFor(BuySellMode.buy).checkedItems, isEmpty);
  });

  testWidgets('renders commercial cover with three demo banners and tools', (
    tester,
  ) async {
    await _pumpScreen(tester, activeVehicle: _vehicle());

    expect(find.byKey(const ValueKey('buy-sell-screen')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('buy-sell-sponsor-carousel')),
      findsOneWidget,
    );
    final bannerSize = tester.getSize(
      find.byKey(const ValueKey('buy-sell-sponsor-frame')),
    );
    expect(bannerSize.height, inInclusiveRange(258, 272));
    expect(bannerSize.height, lessThanOrEqualTo(844 * 0.35));
    expect(
      tester.getSize(find.byKey(const ValueKey('buy-sell-back'))),
      const Size(48, 48),
    );
    expect(find.textContaining('Patrocinado · Demostración'), findsOneWidget);
    expect(find.text('¿Comprar o vender?'), findsOneWidget);
    expect(find.text('Preparar\ncompra'), findsOneWidget);
    expect(find.text('Preparar\nventa'), findsOneWidget);
    expect(find.text('Herramientas'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('buy-sell-tools-row'))).height,
      92,
    );
    expect(
      tester
          .getSize(
            find.byKey(
              const ValueKey('buy-sell-tool-icon-buy-sell-open-comparendos'),
            ),
          )
          .height,
      greaterThanOrEqualTo(30),
    );
    expect(
      find.byKey(const ValueKey('buy-sell-open-comparendos')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('buy-sell-open-tramites')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('buy-sell-open-peritajes')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('buy-sell-open-documents')),
      findsOneWidget,
    );
    expect(find.text('Compra/Venta'), findsNothing);

    expect(find.byKey(const ValueKey('buy-sell-sponsor-info')), findsOneWidget);
  });

  testWidgets('compact phone keeps banner proportional and tools starting', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      activeVehicle: _vehicle(),
      surfaceSize: const Size(360, 780),
    );

    final bannerSize = tester.getSize(
      find.byKey(const ValueKey('buy-sell-sponsor-frame')),
    );
    expect(bannerSize.height, inInclusiveRange(240, 252));
    expect(bannerSize.height, lessThanOrEqualTo(780 * 0.35));
    expect(
      tester.getSize(find.byKey(const ValueKey('buy-sell-back'))),
      const Size(48, 48),
    );
    expect(find.text('Conocer al aliado'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Herramientas')).dy, lessThan(610));
    expect(
      tester.getSize(find.byKey(const ValueKey('buy-sell-tools-row'))).height,
      84,
    );
    expect(
      tester.getBottomLeft(find.byKey(const ValueKey('buy-sell-tools-row'))).dy,
      lessThanOrEqualTo(700),
    );
    expect(
      find.byKey(const ValueKey('buy-sell-open-comparendos')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('buy-sell-open-tramites')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('buy-sell-open-peritajes')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('buy-sell-open-documents')),
      findsOneWidget,
    );
  });

  testWidgets('large text keeps the cover usable without clipped controls', (
    tester,
  ) async {
    for (final textScale in const [1.5, 2.0]) {
      await _pumpScreen(
        tester,
        activeVehicle: _vehicle(),
        surfaceSize: const Size(360, 780),
        textScale: textScale,
      );

      expect(find.byKey(const ValueKey('buy-sell-screen')), findsOneWidget);
      expect(find.text('Conocer al aliado'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('buy-sell-open-comparendos')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('buy and sell guides persist separate progress locally', (
    tester,
  ) async {
    await _pumpScreen(tester, activeVehicle: _vehicle());

    await tester.ensureVisible(
      find.byKey(const ValueKey('buy-sell-prepare-buy')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('buy-sell-prepare-buy')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('buy-sell-purchase-screen')),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('buy-sell-purchase-step-comparendos')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('buy-sell-purchase-step-comparendos')),
    );
    await tester.pumpAndSettle();
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('buy-sell-purchase-reviewed-comparendos')),
    );
    await _closeReview(tester);
    await tester.tap(find.byKey(const ValueKey('buy-sell-purchase-notes')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('buy-sell-notes')),
      'Comprar con peritaje.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Listo').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('buy-sell-purchase-save-progress')),
    );
    await tester.pumpAndSettle();
    Navigator.of(
      tester.element(find.byKey(const ValueKey('buy-sell-purchase-screen'))),
    ).pop();
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('buy-sell-prepare-sell')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('buy-sell-prepare-sell')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('buy-sell-check-saleContract')));
    await tester.enterText(
      find.byKey(const ValueKey('buy-sell-notes')),
      'Venta con contrato.',
    );
    await _scrollSheetUntilVisible(
      tester,
      const ValueKey('buy-sell-save-draft'),
    );
    await tester.tap(find.byKey(const ValueKey('buy-sell-save-draft')));
    await tester.pumpAndSettle();

    final draft = await loadBuySellDraft(_preferences);
    expect(draft, isNotNull);
    expect(draft!.mode, BuySellMode.sell);
    expect(
      draft.preparationFor(BuySellMode.buy).checkedItems,
      contains(BuySellPreparationStepIds.comparendos),
    );
    expect(
      draft.preparationFor(BuySellMode.sell).checkedItems,
      contains('saleContract'),
    );
    expect(
      draft.preparationFor(BuySellMode.buy).notes,
      'Comprar con peritaje.',
    );
    expect(draft.preparationFor(BuySellMode.sell).notes, 'Venta con contrato.');
  });

  testWidgets(
    'candidate city is selected from the bundled catalog and saved in v4',
    (tester) async {
      await _pumpScreen(tester, activeVehicle: _vehicle());
      await _openPurchase(tester);
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('buy-sell-add-candidate-data')),
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('buy-sell-candidate-plate')),
            )
            .controller!
            .text,
        isEmpty,
      );
      await tester.enterText(
        find.byKey(const ValueKey('buy-sell-candidate-plate')),
        'mde456',
      );
      await tester.enterText(
        find.byKey(const ValueKey('buy-sell-candidate-brand-line')),
        'Mazda 2',
      );
      await tester.enterText(
        find.byKey(const ValueKey('buy-sell-candidate-model-year')),
        '2024',
      );
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('buy-sell-candidate-city')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('buy-sell-city-fallback-search')),
        'Medell',
      );
      await tester.pumpAndSettle();
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('buy-sell-city-Medellín - Antioquia')),
      );
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('buy-sell-save-candidate-data')),
      );
      final draft = await loadBuySellDraft(_preferences);
      expect(draft!.candidateVehicle.plate, 'MDE456');
      expect(draft.candidateVehicle.brandLine, 'Mazda 2');
      expect(draft.candidateVehicle.modelYear, '2024');
      expect(draft.candidateVehicle.registrationCity, 'Medellín - Antioquia');
      expect(draft.candidateVehicle.registrationCityConfirmed, isTrue);
      expect(
        _cities.containsDisplayName(draft.candidateVehicle.registrationCity),
        isTrue,
      );
      expect(draft.candidatePlate, 'MDE456');
      expect(_savedJson()['version'], 4);
      expect(_launcher.openedUris, isEmpty);
    },
  );

  for (final hasFavorite in [false, true]) {
    testWidgets(
      'SIMIT stays available with no candidate; favorite $hasFavorite',
      (tester) async {
        await _pumpScreen(
          tester,
          activeVehicle: hasFavorite ? _vehicle() : null,
        );
        await _openPurchase(tester);
        await _openReview(tester, BuySellPreparationStepIds.comparendos);
        expect(
          find.text('Puedes consultar sin agregar un vehículo'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(OutlinedButton, 'Copiar placa'),
          findsNothing,
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('purchase-open-simit')),
        );
        expect(_launcher.openedUris, [simitConsultationUrl]);
        await _closeReview(tester);
        expect(find.text('0 de 6'), findsOneWidget);
        await _savePurchase(tester);
        final draft = await loadBuySellDraft(_preferences);
        expect(draft!.candidateVehicle.isEmpty, isTrue);
        expect(draft.preparationFor(BuySellMode.buy).checkedItems, isEmpty);
        expect(draft.purchaseContext.comparendosAuthorityId, isEmpty);
      },
    );
  }

  testWidgets(
    'tax selector works without a plate and distinguishes pending links',
    (tester) async {
      await _pumpScreen(tester);
      await _openPurchase(tester);
      await _openReview(tester, BuySellPreparationStepIds.taxes);
      expect(
        find.textContaining('Selecciona la entidad que quieres consultar.'),
        findsOneWidget,
      );
      await _chooseAuthority(
        tester,
        'Buscar entidad tributaria',
        'Amazonas',
        _taxCatalog.authorityById('amazonas')!.name,
      );
      expect(
        find.text('Enlace directo de consulta pendiente de confirmar.'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(
          OutlinedButton,
          'Consultar o pagar en el portal oficial',
        ),
        findsNothing,
      );
      await _chooseAuthority(
        tester,
        'Buscar entidad tributaria',
        'Bogotá',
        _taxCatalog.authorityById('bogota')!.name,
      );
      await _tapVisible(
        tester,
        find.widgetWithText(
          OutlinedButton,
          'Consultar o pagar en el portal oficial',
        ),
      );
      expect(_launcher.openedUris, [
        _taxCatalog.authorityById('bogota')!.portalUrl,
      ]);
      final draft = await loadBuySellDraft(_preferences);
      expect(draft!.purchaseContext.taxAuthorityId, 'bogota');
      expect(draft.candidateVehicle.isEmpty, isTrue);
      expect(draft.preparationFor(BuySellMode.buy).checkedItems, isEmpty);
      await _closeReview(tester);
      await _openReview(tester, BuySellPreparationStepIds.taxes);
      expect(find.textContaining('Entidad seleccionada:'), findsOneWidget);
      expect(find.textContaining('Sugerida por matrícula'), findsNothing);
      await _closeReview(tester);
    },
  );

  testWidgets(
    'transfer offers RUNT and verified VUS without selecting a vehicle',
    (tester) async {
      await _pumpScreen(tester);
      await _openPurchase(tester);
      await _openReview(tester, BuySellPreparationStepIds.transfer);
      await _tapVisible(
        tester,
        find.widgetWithText(OutlinedButton, 'Directorio oficial RUNT'),
      );
      final authority = _territorialCatalog.authorities.singleWhere(
        (a) => a.id == 'co-bogota',
      );
      await _chooseAuthority(
        tester,
        'Buscar organismo de tránsito',
        authority.name,
        authority.name,
      );
      for (final label in [
        'Requisitos de traspaso',
        'Citas y radicación',
        'Formularios oficiales',
      ]) {
        await _tapVisible(tester, find.widgetWithText(OutlinedButton, label));
      }
      expect(_launcher.openedUris, [
        runtActorsDirectoryUrl,
        authority.transferUrl,
        authority.appointmentUrl,
        authority.formsUrl,
      ]);
      final draft = await loadBuySellDraft(_preferences);
      expect(draft!.purchaseContext.transitAuthorityId, 'co-bogota');
      expect(draft.candidateVehicle.isEmpty, isTrue);
      expect(draft.preparationFor(BuySellMode.buy).checkedItems, isEmpty);
      await _closeReview(tester);
    },
  );

  testWidgets(
    'unconfirmed transfer entries stay searchable with RUNT fallback',
    (tester) async {
      final pending = _territorialCatalog.authorities.firstWhere(
        (a) =>
            a.officeMunicipality == 'Leticia' &&
            a.verificationStatus == 'pending',
      );
      await _pumpScreen(tester);
      await _openPurchase(tester);
      await _openReview(tester, BuySellPreparationStepIds.transfer);
      await _chooseAuthority(
        tester,
        'Buscar organismo de tránsito',
        pending.name,
        pending.name,
      );
      expect(
        find.textContaining('Competencia para matrícula y traspaso pendiente'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(OutlinedButton, 'Requisitos de traspaso'),
        findsNothing,
      );
      await _tapVisible(
        tester,
        find.widgetWithText(
          OutlinedButton,
          'Consultar directorio oficial RUNT',
        ),
      );
      expect(_launcher.openedUris, [runtActorsDirectoryUrl]);
      expect(
        (await loadBuySellDraft(_preferences))!
            .purchaseContext
            .transitAuthorityId,
        pending.id,
      );
      await _closeReview(tester);
    },
  );

  testWidgets(
    'temporary garage selection differs from candidate and favorite',
    (tester) async {
      await _seedCandidate();
      final favorite = _vehicle(id: 'favorite');
      final other = _vehicle(id: 'other', plate: 'CAL234');
      await _preferences.setString(
        garageFavoriteVehicleIdsPreferenceKey,
        jsonEncode([favorite.id]),
      );
      await _pumpScreen(
        tester,
        activeVehicle: favorite,
        garageVehicles: [favorite, other],
      );
      await _openPurchase(tester);
      await _openReview(tester, BuySellPreparationStepIds.comparendos);
      expect(find.textContaining('Vehículo candidato: MDE456'), findsOneWidget);
      expect(find.textContaining('BOG127'), findsNothing);
      await _tapVisible(
        tester,
        find.widgetWithText(OutlinedButton, 'Usar un vehículo del Garaje'),
      );
      await _tapVisible(tester, find.widgetWithText(ListTile, 'CAL234'));
      expect(
        find.textContaining('Consulta temporal del Garaje: CAL234'),
        findsOneWidget,
      );
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('purchase-open-simit')),
      );
      await _tapVisible(
        tester,
        find.widgetWithText(OutlinedButton, 'Volver al vehículo candidato'),
      );
      expect(find.textContaining('Vehículo candidato: MDE456'), findsOneWidget);
      await _closeReview(tester);
      await _savePurchase(tester);
      final draft = await loadBuySellDraft(_preferences);
      expect(draft!.candidateVehicle.plate, 'MDE456');
      expect(draft.purchaseContext.preparationId, 'purchase-candidate-a');
      expect(draft.archivedPurchases, isEmpty);
      expect(await loadGarageFavoriteVehicleIds(_preferences), {favorite.id});
      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const ValueKey('buy-sell-purchase-screen'))),
      );
      expect(
        (await container.read(activeVehicleProvider.future))!.id,
        favorite.id,
      );
      expect(_launcher.openedUris, [simitConsultationUrl]);
    },
  );

  for (final hasCandidate in [false, true]) {
    testWidgets(
      'real purchase documents use preparation owner; candidate $hasCandidate',
      (tester) async {
        if (hasCandidate) await _seedCandidate();
        final favorite = _vehicle(id: 'favorite');
        await _preferences.setString(
          garageFavoriteVehicleIdsPreferenceKey,
          jsonEncode([favorite.id]),
        );
        final favoriteDocumentCallbacks = <String>[];
        await _pumpScreen(
          tester,
          activeVehicle: favorite,
          withPurchaseDocuments: true,
          onOpenDocuments: (vehicle) =>
              favoriteDocumentCallbacks.add(vehicle.id),
        );
        await _openPurchase(tester);
        await _openReview(tester, BuySellPreparationStepIds.documents);
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('buy-sell-purchase-open-documents')),
        );
        final screen = tester.widget<PurchaseDocumentsScreen>(
          find.byType(PurchaseDocumentsScreen),
        );
        final draft = await loadBuySellDraft(_preferences);
        expect(screen.preparationId, draft!.purchaseContext.preparationId);
        expect(screen.preparationId, isNotEmpty);
        expect(screen.preparationId, isNot(favorite.id));
        expect(
          screen.ownerLabel,
          hasCandidate ? contains('MDE456') : 'Vehículo que quieres comprar',
        );
        expect(screen.ownerLabel, isNot(contains('BOG127')));
        expect(screen.initialType, isNull);
        expect(find.text('0 copias locales'), findsOneWidget);
        expect(_walletStore.owners, isNotEmpty);
        expect(
          _walletStore.owners,
          everyElement(WalletOwner.preparation(screen.preparationId)),
        );
        expect(favoriteDocumentCallbacks, isEmpty);
        expect(await loadGarageFavoriteVehicleIds(_preferences), {favorite.id});
        expect(draft.preparationFor(BuySellMode.buy).checkedItems, isEmpty);
        await _tapVisible(tester, find.byTooltip('Volver'));
        await _closeReview(tester);
        // The header opens the same real folder with the traffic-license section.
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('buy-sell-attach-registration')),
        );
        final registration = tester.widget<PurchaseDocumentsScreen>(
          find.byType(PurchaseDocumentsScreen),
        );
        expect(registration.preparationId, screen.preparationId);
        expect(registration.initialType, WalletDocumentType.trafficLicense);
        expect(favoriteDocumentCallbacks, isEmpty);
        await _tapVisible(tester, find.byTooltip('Volver'));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'changing candidate archives only after confirmation and permits marking a new review',
    (tester) async {
      await _seedCandidate();
      await _pumpScreen(tester, activeVehicle: _vehicle());
      await _openPurchase(tester);
      for (final confirm in [false, true]) {
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('buy-sell-add-candidate-data')),
        );
        await tester.enterText(
          find.byKey(const ValueKey('buy-sell-candidate-plate')),
          'NUE789',
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('buy-sell-save-candidate-data')),
        );
        expect(find.text('Preparar otro vehículo'), findsOneWidget);
        await _tapVisible(
          tester,
          find.widgetWithText(
            confirm ? FilledButton : TextButton,
            confirm ? 'Crear preparación' : 'Cancelar',
          ),
        );
        final draft = (await loadBuySellDraft(_preferences))!;
        expect(draft.candidateVehicle.plate, confirm ? 'NUE789' : 'MDE456');
        if (!confirm) {
          expect(draft.purchaseContext.preparationId, 'purchase-candidate-a');
          expect(draft.archivedPurchases, isEmpty);
        } else {
          expect(
            draft.purchaseContext.preparationId,
            isNot('purchase-candidate-a'),
          );
          expect(draft.purchaseContext.preparationId, isNotEmpty);
          expect(
            draft.archivedPurchases.single.context.preparationId,
            'purchase-candidate-a',
          );
          expect(draft.archivedPurchases.single.candidate.plate, 'MDE456');
          expect(
            draft.archivedPurchases.single.preparation.notes,
            'Candidato original',
          );
          expect(draft.preparationFor(BuySellMode.buy).checkedItems, isEmpty);
          expect(draft.preparationFor(BuySellMode.buy).notes, isEmpty);
        }
      }
      await _openReview(tester, BuySellPreparationStepIds.comparendos);
      final reviewed = find.byKey(
        const ValueKey('buy-sell-purchase-reviewed-comparendos'),
      );
      // A new preparation starts with const empty checks; UI edits need a mutable copy.
      await _tapVisible(tester, reviewed);
      expect(tester.takeException(), isNull);
      await _tapVisible(tester, reviewed);
      expect(tester.takeException(), isNull);
      await _tapVisible(tester, reviewed);
      await _closeReview(tester);
      expect(find.text('1 de 6'), findsOneWidget);
      await _savePurchase(tester);
      final saved = (await loadBuySellDraft(_preferences))!;
      expect(saved.candidateVehicle.plate, 'NUE789');
      expect(saved.preparationFor(BuySellMode.buy).checkedItems, {
        BuySellPreparationStepIds.comparendos,
      });
      expect(saved.archivedPurchases.single.candidate.plate, 'MDE456');
      expect(saved.archivedPurchases.single.preparation.checkedItems, isEmpty);
      expect(_savedJson()['version'], 4);
      expect(tester.takeException(), isNull);
    },
  );

  for (final picker in ['taxes', 'transfer', 'city']) {
    testWidgets('$picker picker remains usable with 2x text and keyboard', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        textScale: 2,
        surfaceSize: const Size(360, 780),
      );
      await _openPurchase(tester);
      late Finder search;
      late Finder row;
      late String query;
      if (picker == 'city') {
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('buy-sell-add-candidate-data')),
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('buy-sell-candidate-city')),
        );
        search = find.byKey(const ValueKey('buy-sell-city-fallback-search'));
        query = 'Medell';
        row = find.byKey(const ValueKey('buy-sell-city-Medellín - Antioquia'));
      } else {
        await _openReview(
          tester,
          picker == 'taxes'
              ? BuySellPreparationStepIds.taxes
              : BuySellPreparationStepIds.transfer,
        );
        await _tapVisible(
          tester,
          find.widgetWithText(
            OutlinedButton,
            picker == 'taxes'
                ? 'Buscar entidad tributaria'
                : 'Buscar organismo de tránsito',
          ),
        );
        search = find.byKey(const ValueKey('purchase-authority-search'));
        final name = picker == 'taxes'
            ? _taxCatalog.authorities.singleWhere((a) => a.id == 'bogota').name
            : _territorialCatalog.authorities
                  .singleWhere((a) => a.id == 'co-bogota')
                  .name;
        query = name;
        row = find.widgetWithText(ListTile, name);
        if (picker == 'transfer') {
          expect(
            find.textContaining('2 organismos con traspaso confirmado.'),
            findsOneWidget,
          );
        }
      }
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.ensureVisible(search);
      await tester.enterText(search, query);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        row,
        120,
        scrollable: _pickerScrollable(),
      );
      await _tapVisible(tester, row);
      expect(search, findsNothing);
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
    });
  }

  testWidgets('tool callbacks keep the selected vehicle scoped', (
    tester,
  ) async {
    final vehicle = _vehicle(id: 'vehicle-a');
    final opened = <String>[];
    await _pumpScreen(
      tester,
      activeVehicle: vehicle,
      onOpenComparendos: (vehicle) => opened.add('comparendos:${vehicle.id}'),
      onOpenTramites: (vehicle) => opened.add('tramites:${vehicle.id}'),
      onOpenDocuments: (vehicle) => opened.add('documents:${vehicle.id}'),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('buy-sell-open-comparendos')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('buy-sell-open-comparendos')));
    await tester.ensureVisible(
      find.byKey(const ValueKey('buy-sell-open-tramites')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('buy-sell-open-tramites')));
    await tester.ensureVisible(
      find.byKey(const ValueKey('buy-sell-open-documents')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('buy-sell-open-documents')));

    expect(opened, [
      'comparendos:vehicle-a',
      'tramites:vehicle-a',
      'documents:vehicle-a',
    ]);
  });

  testWidgets('peritajes opens Google Maps with GPS coordinates by default', (
    tester,
  ) async {
    await _pumpScreen(tester, activeVehicle: _vehicle());

    await tester.ensureVisible(
      find.byKey(const ValueKey('buy-sell-open-peritajes')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('buy-sell-open-peritajes')));
    await tester.pumpAndSettle();

    expect(_launcher.openedUris, hasLength(1));
    expect(
      _launcher.openedUris.single,
      contains('peritaje+vehicular+cerca+de+6.244200%2C-75.581200'),
    );
  });

  testWidgets('peritajes fallback requires selecting a catalog city', (
    tester,
  ) async {
    _locationGateway = const _FakeLocationGateway.error(
      DeviceLocationFailure.serviceDisabled,
      serviceEnabled: false,
    );
    await _pumpScreen(tester, activeVehicle: _vehicle());

    await tester.ensureVisible(
      find.byKey(const ValueKey('buy-sell-open-peritajes')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('buy-sell-open-peritajes')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('buy-sell-city-fallback-search')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('buy-sell-city-fallback-search')),
      'Medell',
    );
    await tester.pumpAndSettle();
    expect(_launcher.openedUris, isEmpty);

    await tester.tap(
      find.byKey(const ValueKey('buy-sell-city-Medellín - Antioquia')),
    );
    await tester.pumpAndSettle();

    expect(_launcher.openedUris, hasLength(1));
    expect(_launcher.openedUris.single, contains('peritaje+vehicular+Medell'));
  });

  for (final succeeds in [true, false]) {
    testWidgets(
      'closing appraisal review ignores delayed GPS; success $succeeds',
      (tester) async {
        final gateway = _DelayedLocationGateway();
        _locationGateway = gateway;
        await _pumpScreen(tester);
        await _openPurchase(tester);
        await _openReview(tester, BuySellPreparationStepIds.appraisal);
        final locate = find.byKey(
          const ValueKey('buy-sell-purchase-open-appraisal'),
        );
        await tester.ensureVisible(locate);
        await tester.pumpAndSettle();
        await tester.tap(locate);
        // The unresolved GPS request intentionally keeps the busy indicator alive.
        await tester.pump(const Duration(milliseconds: 100));
        expect(gateway.requests, 1);
        expect(gateway.result.isCompleted, isFalse);

        await tester.tap(find.byTooltip('Cerrar revisión'));
        await tester.pumpAndSettle();
        gateway.result.complete(
          succeeds
              ? const DeviceLocationSuccess(
                  DeviceLocationPoint(
                    latitude: 6.2442,
                    longitude: -75.5812,
                    accuracyMeters: 18,
                  ),
                )
              : const DeviceLocationError(
                  DeviceLocationFailure.positionUnavailable,
                ),
        );
        await tester.pumpAndSettle();

        expect(_launcher.openedUris, isEmpty);
        expect(
          find.byKey(const ValueKey('buy-sell-city-fallback-search')),
          findsNothing,
        );
        expect(find.byTooltip('Cerrar revisión'), findsNothing);
        expect(find.text('0 de 6'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final accuracy in [1000.0, 1001.0]) {
    testWidgets('appraisal GPS enforces accuracy threshold: $accuracy meters', (
      tester,
    ) async {
      _locationGateway = _FakeLocationGateway.success(
        DeviceLocationPoint(
          latitude: 6.2442,
          longitude: -75.5812,
          accuracyMeters: accuracy,
        ),
      );
      await _pumpScreen(tester);
      await _openPurchase(tester);
      await _openReview(tester, BuySellPreparationStepIds.appraisal);
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('buy-sell-purchase-open-appraisal')),
      );

      if (accuracy <= 1000) {
        expect(_launcher.openedUris, hasLength(1));
        expect(_launcher.openedUris.single, contains('6.244200%2C-75.581200'));
        expect(
          find.byKey(const ValueKey('buy-sell-city-fallback-search')),
          findsNothing,
        );
      } else {
        expect(_launcher.openedUris, isEmpty);
        expect(
          find.byKey(const ValueKey('buy-sell-city-fallback-search')),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('contract draft copies text and does not expose PDF generation', (
    tester,
  ) async {
    await _pumpScreen(tester, activeVehicle: _vehicle());
    await tester.ensureVisible(
      find.byKey(const ValueKey('buy-sell-prepare-sell')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('buy-sell-prepare-sell')));
    await tester.pumpAndSettle();
    await _scrollSheetUntilVisible(
      tester,
      const ValueKey('buy-sell-open-contract'),
    );
    await tester.tap(find.byKey(const ValueKey('buy-sell-open-contract')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('buy-sell-contract-vehicle-plate')),
      'BOG127',
    );
    await tester.enterText(
      find.byKey(const ValueKey('buy-sell-contract-buyer')),
      'Comprador Demo',
    );
    await tester.enterText(
      find.byKey(const ValueKey('buy-sell-contract-seller')),
      'Vendedor Demo',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('buy-sell-contract-preview')),
      findsOneWidget,
    );
    expect(find.textContaining('BOG127'), findsWidgets);
    expect(find.textContaining('Generar PDF'), findsNothing);
    await _scrollSheetUntilVisible(
      tester,
      const ValueKey('buy-sell-save-contract'),
    );
    await tester.tap(find.byKey(const ValueKey('buy-sell-save-contract')));
    await tester.pumpAndSettle();

    final draft = await loadBuySellDraft(_preferences);
    expect(draft!.contract.vehiclePlate, 'BOG127');
    expect(draft.contract.buyerName, 'Comprador Demo');
  });
}

void purchaseReviewShellTests() {
  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets(
      'six optional reviews stay above real navigation at text $scale',
      (tester) async {
        await _pumpScreen(
          tester,
          surfaceSize: const Size(360, 780),
          textScale: scale,
          withShell: true,
        );
        await _openPurchase(tester);
        for (final id in BuySellPreparationStepIds.buy) {
          await _openReview(tester, id);
          expect(
            find.text('Puedes consultar sin agregar un vehículo'),
            findsOneWidget,
          );
          final reviewed = find.byKey(
            ValueKey('buy-sell-purchase-reviewed-$id'),
          );
          await tester.ensureVisible(reviewed);
          await tester.pumpAndSettle();
          expect(reviewed.hitTestable(), findsOneWidget);
          final done = find.widgetWithText(FilledButton, 'Listo');
          await tester.ensureVisible(done);
          await tester.pumpAndSettle();
          expect(done.hitTestable(), findsOneWidget);
          expect(tester.getSize(done).height, greaterThanOrEqualTo(48));
          expect(
            tester.getBottomLeft(done).dy,
            lessThanOrEqualTo(
              tester
                  .getTopLeft(
                    find.byKey(const ValueKey('app-bottom-navigation')),
                  )
                  .dy,
            ),
          );
          expect(tester.takeException(), isNull);
          await _closeReview(tester);
        }
      },
    );
  }
}

Map<String, dynamic> _savedJson() =>
    jsonDecode(_preferences.values[buySellDraftPreferenceKey]! as String)
        as Map<String, dynamic>;

Future<void> _seedCandidate() => saveBuySellDraft(
  _preferences,
  BuySellDraft.empty()
      .copyWith(
        candidatePlate: 'MDE456',
        city: 'Medellín - Antioquia',
        candidateVehicle: const BuySellCandidateVehicle(
          plate: 'MDE456',
          brandLine: 'Mazda 2',
          modelYear: '2024',
          registrationCity: 'Medellín - Antioquia',
          registrationCityConfirmed: true,
        ),
        purchaseContext: const PurchaseConsultationContext(
          preparationId: 'purchase-candidate-a',
        ),
      )
      .updatePreparation(
        BuySellMode.buy,
        const BuySellPreparation(notes: 'Candidato original'),
      ),
);

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _openPurchase(WidgetTester tester) =>
    _tapVisible(tester, find.byKey(const ValueKey('buy-sell-prepare-buy')));

Future<void> _openReview(WidgetTester tester, String id) =>
    _tapVisible(tester, find.byKey(ValueKey('buy-sell-purchase-step-$id')));

Future<void> _closeReview(WidgetTester tester) =>
    _tapVisible(tester, find.byTooltip('Cerrar revisión'));

Future<void> _savePurchase(WidgetTester tester) => _tapVisible(
  tester,
  find.byKey(const ValueKey('buy-sell-purchase-save-progress')),
);

Future<void> _chooseAuthority(
  WidgetTester tester,
  String action,
  String query,
  String name,
) async {
  await _tapVisible(tester, find.widgetWithText(OutlinedButton, action));
  await tester.enterText(
    find.byKey(const ValueKey('purchase-authority-search')),
    query,
  );
  await tester.pumpAndSettle();
  final row = find.widgetWithText(ListTile, name);
  await tester.scrollUntilVisible(row, 120, scrollable: _pickerScrollable());
  await _tapVisible(tester, row);
}

Finder _pickerScrollable() => find
    .descendant(
      of: find.byType(CustomScrollView).last,
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _scrollSheetUntilVisible(
  WidgetTester tester,
  ValueKey<String> key,
) async {
  await tester.scrollUntilVisible(
    find.byKey(key),
    220,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  VehicleProfile? activeVehicle,
  List<VehicleProfile>? garageVehicles,
  bool withPurchaseDocuments = false,
  ValueChanged<VehicleProfile>? onOpenComparendos,
  ValueChanged<VehicleProfile>? onOpenTramites,
  ValueChanged<VehicleProfile>? onOpenDocuments,
  Size surfaceSize = const Size(390, 844),
  double textScale = 1,
  bool withShell = false,
}) async {
  tester.view.physicalSize = surfaceSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final vehicles = garageVehicles ?? <VehicleProfile>[?activeVehicle];
  final home = BuySellScreen(
    onOpenComparendos: onOpenComparendos,
    onOpenTramites: onOpenTramites,
    onOpenDocuments: onOpenDocuments,
  );
  final router = withShell
      ? GoRouter(
          initialLocation: '/apps/module/compra_venta',
          routes: [
            StatefulShellRoute.indexedStack(
              builder: (context, state, shell) =>
                  AppShell(navigationShell: shell),
              branches: [
                for (final tab in AppTab.values)
                  StatefulShellBranch(
                    routes: [
                      GoRoute(
                        path: tab.route.path,
                        builder: (_, _) => const SizedBox(),
                        routes: [
                          if (tab == AppTab.apps)
                            GoRoute(
                              path: 'module/compra_venta',
                              // The existing cover reserves navigation twice.
                              // Isolate its layout; pushed purchase routes still
                              // receive the real shell constraints and insets.
                              builder: (_, _) => OverflowBox(
                                alignment: Alignment.topCenter,
                                minHeight: surfaceSize.height,
                                maxHeight: surfaceSize.height,
                                child: home,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ],
        )
      : null;
  if (router != null) addTearDown(router.dispose);
  Widget mediaBuilder(BuildContext context, Widget? child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(textScale),
      padding: withShell
          ? const EdgeInsets.only(top: 35, bottom: 48)
          : EdgeInsets.zero,
      viewPadding: withShell
          ? const EdgeInsets.only(top: 35, bottom: 48)
          : EdgeInsets.zero,
    ),
    child: RepaintBoundary(
      key: const ValueKey('purchase-test-capture'),
      child: child!,
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appPreferencesProvider.overrideWithValue(_preferences),
        activeVehicleProvider.overrideWith((ref) async => activeVehicle),
        vehicleListProvider.overrideWith((ref) async => vehicles),
        externalLauncherProvider.overrideWithValue(_launcher),
        deviceLocationGatewayProvider.overrideWithValue(_locationGateway),
        taxCatalogProvider.overrideWith((ref) async => _taxCatalog),
        territorialCatalogProvider.overrideWith(
          (ref) async => _territorialCatalog,
        ),
        if (withPurchaseDocuments) ...[
          walletStoreProvider.overrideWithValue(_walletStore),
          walletPlatformProvider.overrideWithValue(_PurchaseWalletPlatform()),
          walletSessionProvider.overrideWith((ref) {
            final session = WalletSession(
              authenticator: _PurchaseWalletAuthenticator(),
              preferences: _PurchaseWalletPreferences(),
            );
            ref.onDispose(session.dispose);
            return session;
          }),
        ],
        registrationCityCatalogProvider.overrideWithValue(
          AsyncValue.data(_cities),
        ),
      ],
      child: router != null
          ? MaterialApp.router(
              theme: buildPicoRadarTheme(),
              routerConfig: router,
              builder: mediaBuilder,
            )
          : MaterialApp(
              theme: buildPicoRadarTheme(),
              builder: mediaBuilder,
              home: home,
            ),
    ),
  );
  await tester.pump();
  for (var i = 0; i < 4; i += 1) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _capturePurchase(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('PURCHASE_CAPTURE')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('purchase-test-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('build/purchase-review')
      ..createSync(recursive: true);
    await File('${directory.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

VehicleProfile _vehicle({String id = 'vehicle-1', String plate = 'BOG127'}) {
  return VehicleProfile(
    id: id,
    plate: plate,
    kind: VehicleKind.car,
    serviceType: VehicleServiceType.private,
    registrationCity: 'Bogotá - Bogotá D.C.',
    brand: 'Renault',
    model: 'Duster',
    year: 2020,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

class _PurchaseWalletStore extends Fake implements WalletStore {
  final owners = <WalletOwner?>[];
  final preparations = <String>{};

  @override
  Future<WalletMigrationReport> initialize() async =>
      const WalletMigrationReport();

  @override
  Future<WalletOwner> ensurePreparation(
    String id, {
    bool Function()? isAuthorized,
  }) async {
    expect(isAuthorized?.call(), isTrue);
    preparations.add(id);
    return WalletOwner.preparation(id);
  }

  @override
  Future<bool> preparationExists(String id) async => preparations.contains(id);

  @override
  Future<List<WalletDocument>> listDocuments({WalletOwner? owner}) async {
    owners.add(owner);
    return [];
  }
}

class _PurchaseWalletPlatform extends WalletPlatform {
  @override
  Future<void> setSecure(bool enabled) async {}
}

class _PurchaseWalletAuthenticator implements WalletDeviceAuthenticator {
  @override
  Future<bool> canAuthenticate() async => true;

  @override
  Future<WalletAuthenticationResult> authenticate() async =>
      WalletAuthenticationResult.success;
}

class _PurchaseWalletPreferences implements WalletSecurityPreferencesStore {
  @override
  Future<WalletSecurityPreferences> read() async =>
      const WalletSecurityPreferences(offerSeen: true);

  @override
  Future<void> write(WalletSecurityPreferences preferences) async {}
}

class _FakeExternalLauncher implements ExternalLauncher {
  final openedUris = <String>[];

  @override
  Future<bool> openExternal(String uri) async {
    openedUris.add(uri);
    return true;
  }

  @override
  Future<bool> callPhone(String phone) async => true;
}

class MemoryPreferences implements AppPreferences {
  final values = <String, Object?>{};

  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;

  @override
  Future<int?> getInt(String key) async => values[key] as int?;

  @override
  Future<String?> getString(String key) async => values[key] as String?;

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<void> setBool(String key, bool value) async {
    values[key] = value;
  }

  @override
  Future<void> setInt(String key, int value) async {
    values[key] = value;
  }

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

class _DelayedLocationGateway extends _FakeLocationGateway {
  _DelayedLocationGateway()
    : super.error(DeviceLocationFailure.positionUnavailable);

  final result = Completer<DeviceLocationResult>();
  int requests = 0;

  @override
  Future<DeviceLocationResult> getCurrentPosition() {
    requests++;
    return result.future;
  }
}

class _FakeLocationGateway implements DeviceLocationGateway {
  const _FakeLocationGateway.success(this.point)
    : failure = null,
      serviceEnabled = true;

  const _FakeLocationGateway.error(this.failure, {this.serviceEnabled = true})
    : point = null;

  final DeviceLocationPoint? point;
  final DeviceLocationFailure? failure;
  final bool serviceEnabled;

  @override
  Future<DeviceLocationPermission> checkPermission() async {
    return DeviceLocationPermission.granted;
  }

  @override
  Future<DeviceLocationResult> getCurrentPosition() async {
    final point = this.point;
    if (point != null) {
      return DeviceLocationSuccess(point);
    }
    return DeviceLocationError(
      failure ?? DeviceLocationFailure.positionUnavailable,
    );
  }

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<DeviceLocationPermission> requestPermission() async {
    return DeviceLocationPermission.granted;
  }
}
