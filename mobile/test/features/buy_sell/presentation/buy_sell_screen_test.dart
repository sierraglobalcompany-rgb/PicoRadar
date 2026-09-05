import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/theme/app_theme.dart';
import 'package:picoradar/core/storage/app_preferences.dart';
import 'package:picoradar/features/buy_sell/data/buy_sell_draft.dart';
import 'package:picoradar/features/buy_sell/presentation/buy_sell_screen.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';

import '../../../test_app_harness.dart';
import '../../services/presentation/v01b_tools_test_font.dart';

late MemoryPreferences _preferences;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadV01bToolsTestFont);
  setUp(() {
    _preferences = MemoryPreferences();
  });

  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915),
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'V01B S03 compact heading retains editable draft with keyboard $size/$scale',
        (tester) async {
          await _pumpScreen(
            tester,
            activeVehicle: _vehicle(),
            size: size,
            textScale: scale,
          );
          final heading = tester.renderObject<RenderParagraph>(
            find.text('Preparación de compra/venta'),
          );
          final metrics = TextPainter(
            text: heading.text,
            textDirection: heading.textDirection,
            textScaler: heading.textScaler,
          )..layout(maxWidth: heading.size.width);
          if (scale == 1) {
            expect(
              metrics.computeLineMetrics(),
              hasLength(1),
              reason: 'Repeated heading should not displace the preparation form with a second line at normal scale',
            );
          }
          expect(heading.didExceedMaxLines, isFalse);
          expect(metrics.height, lessThanOrEqualTo(heading.size.height + 0.1));
          metrics.dispose();
          for (final label in ['Comprar', 'Vender']) {
            final choice = find.text(label);
            await tester.ensureVisible(choice);
            await tester.pumpAndSettle();
            final paragraph = tester.renderObject<RenderParagraph>(choice);
            final boxes = paragraph.getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: label.length),
            );
            expect(boxes, isNotEmpty);
            expect(
              boxes.map((box) => box.top).toSet(),
              hasLength(1),
              reason:
                  '$label must not leave an orphan letter at enlarged scale',
            );
            expect(choice.hitTestable(), findsOneWidget);
          }
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          addTearDown(tester.view.resetViewInsets);
          await tester.pumpAndSettle();
          for (final entry in [
            ('buy-sell-candidate-plate', 'QA1234'),
            ('buy-sell-city', 'Pereira'),
            ('buy-sell-notes', 'QA keyboard notes'),
          ]) {
            final field = find.byKey(ValueKey(entry.$1));
            await tester.ensureVisible(field);
            await tester.pumpAndSettle();
            expect(field.hitTestable(), findsOneWidget);
            await tester.enterText(field, entry.$2);
            await tester.pumpAndSettle();
          }
          final save = find.byKey(const ValueKey('buy-sell-save-draft'));
          await Scrollable.ensureVisible(tester.element(save), alignment: 0.5);
          await tester.pumpAndSettle();
          expect(save.hitTestable(), findsOneWidget);
          expect(
            tester.getRect(save).bottom,
            lessThanOrEqualTo(size.height - 300),
          );
          await tester.tap(save);
          await tester.pumpAndSettle();
          final draft = await loadBuySellDraft(_preferences);
          expect(draft!.candidatePlate, 'QA1234');
          expect(draft.city, 'Pereira');
          expect(draft.notes, 'QA keyboard notes');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  test('malformed JSON removes the draft key and returns null', () async {
    await _preferences.setString(buySellDraftPreferenceKey, '{bad json');

    final draft = await loadBuySellDraft(_preferences);

    expect(draft, isNull);
    expect(await _preferences.getString(buySellDraftPreferenceKey), isNull);
  });

  test('wrong field type removes the draft key and returns null', () async {
    await _preferences.setString(
      buySellDraftPreferenceKey,
      jsonEncode({
        'version': 1,
        'mode': 'buy',
        'candidatePlate': 123,
        'city': 'Cali',
        'notes': '',
        'checkedItems': ['Revisar comparendos y obligaciones.'],
      }),
    );

    final draft = await loadBuySellDraft(_preferences);

    expect(draft, isNull);
    expect(await _preferences.getString(buySellDraftPreferenceKey), isNull);
  });

  test('non-string checklist removes the draft key and returns null', () async {
    await _preferences.setString(
      buySellDraftPreferenceKey,
      jsonEncode({
        'version': 1,
        'mode': 'sell',
        'candidatePlate': 'ABC123',
        'city': 'Cali',
        'notes': '',
        'checkedItems': ['Preparar comparendos y obligaciones.', 7],
      }),
    );

    final draft = await loadBuySellDraft(_preferences);

    expect(draft, isNull);
    expect(await _preferences.getString(buySellDraftPreferenceKey), isNull);
  });

  test('invalid mode removes the draft key and returns null', () async {
    await _preferences.setString(
      buySellDraftPreferenceKey,
      jsonEncode({
        'version': 1,
        'mode': 'lease',
        'candidatePlate': 'ABC123',
        'city': 'Cali',
        'notes': '',
        'checkedItems': <String>[],
      }),
    );

    final draft = await loadBuySellDraft(_preferences);

    expect(draft, isNull);
    expect(await _preferences.getString(buySellDraftPreferenceKey), isNull);
  });

  test('incompatible version removes the draft key and returns null', () async {
    await _preferences.setString(
      buySellDraftPreferenceKey,
      jsonEncode({
        'version': 2,
        'mode': 'buy',
        'candidatePlate': 'ABC123',
        'city': 'Cali',
        'notes': '',
        'checkedItems': <String>[],
      }),
    );

    final draft = await loadBuySellDraft(_preferences);

    expect(draft, isNull);
    expect(await _preferences.getString(buySellDraftPreferenceKey), isNull);
  });

  testWidgets('shows buy mode by default and keeps mandatory warning', (
    tester,
  ) async {
    await _pumpScreen(tester, activeVehicle: null);

    expect(find.byKey(const ValueKey('buy-sell-screen')), findsOneWidget);
    expect(find.text('Comprar'), findsOneWidget);
    expect(find.text('Vender'), findsOneWidget);
    expect(find.text('Revisar comparendos y obligaciones.'), findsOneWidget);
    expect(find.text(buySellMandatoryCopy), findsOneWidget);
    expect(
      find.byKey(const ValueKey('buy-sell-no-active-vehicle')),
      findsOneWidget,
    );
  });

  testWidgets('switches to sell checklist without adding marketplace copy', (
    tester,
  ) async {
    await _pumpScreen(tester, activeVehicle: null);

    await tester.tap(find.text('Vender'));
    await tester.pumpAndSettle();

    expect(find.text('Preparar comparendos y obligaciones.'), findsOneWidget);
    expect(find.textContaining('precio sugerido'), findsNothing);
    expect(find.textContaining('chat'), findsNothing);
    expect(find.textContaining('reserva'), findsNothing);
    expect(find.textContaining('pago'), findsNothing);
  });

  testWidgets('saves one explicit local draft with the approved key', (
    tester,
  ) async {
    await _pumpScreen(tester, activeVehicle: _vehicle());

    await tester.tap(find.text('Vender'));
    await tester.enterText(
      find.byKey(const ValueKey('buy-sell-candidate-plate')),
      'ABC123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('buy-sell-city')),
      'Medellín',
    );
    await tester.enterText(
      find.byKey(const ValueKey('buy-sell-notes')),
      'Pedir certificado antes de separar.',
    );
    await tester.tap(
      find.byKey(
        const ValueKey('buy-sell-check-Preparar comparendos y obligaciones.'),
      ),
    );
    await _tapVisible(tester, const ValueKey('buy-sell-save-draft'));
    await tester.pumpAndSettle();

    expect(find.text('Borrador guardado en este dispositivo.'), findsOneWidget);
    expect(_preferences.values.keys, [buySellDraftPreferenceKey]);
    final saved = jsonDecode(
      (await _preferences.getString(buySellDraftPreferenceKey))!,
    ) as Map<String, Object?>;
    expect(saved['mode'], 'sell');
    expect(saved['candidatePlate'], 'ABC123');
    expect(saved['city'], 'Medellín');
    expect(saved['notes'], 'Pedir certificado antes de separar.');
    expect(saved['checkedItems'], ['Preparar comparendos y obligaciones.']);
  });

  testWidgets('restores a saved draft on open and by explicit action', (
    tester,
  ) async {
    await _preferences.setString(
      buySellDraftPreferenceKey,
      const BuySellDraft(
        mode: BuySellMode.sell,
        candidatePlate: 'XYZ987',
        city: 'Bogotá',
        notes: 'Revisar improntas.',
        checkedItems: {'Confirmar trámites de traspaso.'},
      ).toJsonString(),
    );

    await _pumpScreen(tester, activeVehicle: _vehicle());

    expect(find.text('XYZ987'), findsOneWidget);
    expect(find.text('Bogotá'), findsOneWidget);
    expect(find.text('Revisar improntas.'), findsOneWidget);
    final checkbox = tester.widget<CheckboxListTile>(
      find.byKey(
        const ValueKey('buy-sell-check-Confirmar trámites de traspaso.'),
      ),
    );
    expect(checkbox.value, isTrue);

    await tester.enterText(find.byKey(const ValueKey('buy-sell-city')), 'Cali');
    await _tapVisible(tester, const ValueKey('buy-sell-restore-draft'));
    await tester.pumpAndSettle();

    expect(find.text('Bogotá'), findsOneWidget);
    expect(find.text('Borrador restaurado.'), findsOneWidget);
  });

  testWidgets('delete cancel keeps the draft and confirm removes it', (
    tester,
  ) async {
    await _preferences.setString(
      buySellDraftPreferenceKey,
      const BuySellDraft(
        mode: BuySellMode.buy,
        candidatePlate: 'ABC123',
        city: 'Cali',
        notes: 'Pendiente peritaje.',
        checkedItems: {},
      ).toJsonString(),
    );
    await _pumpScreen(tester, activeVehicle: _vehicle());

    await _tapVisible(tester, const ValueKey('buy-sell-delete-draft'));
    await tester.pumpAndSettle();

    expect(find.text('Eliminar borrador'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('buy-sell-delete-cancel')));
    await tester.pumpAndSettle();

    expect(await _preferences.getString(buySellDraftPreferenceKey), isNotNull);
    expect(find.text('ABC123'), findsOneWidget);

    await _tapVisible(tester, const ValueKey('buy-sell-delete-draft'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('buy-sell-delete-confirm')));
    await tester.pumpAndSettle();

    expect(await _preferences.getString(buySellDraftPreferenceKey), isNull);
    expect(find.text('ABC123'), findsOneWidget);
    expect(find.text('Borrador eliminado.'), findsOneWidget);
  });

  testWidgets('copy summary includes form state and mandatory warning', (
    tester,
  ) async {
    var clipboardText = '';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    await _pumpScreen(tester, activeVehicle: _vehicle());

    await tester.enterText(
      find.byKey(const ValueKey('buy-sell-candidate-plate')),
      'ABC123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('buy-sell-city')),
      'Pereira',
    );
    await tester.tap(
      find.byKey(
        const ValueKey('buy-sell-check-Revisar comparendos y obligaciones.'),
      ),
    );
    await _tapVisible(tester, const ValueKey('buy-sell-copy-summary'));
    await tester.pumpAndSettle();

    expect(clipboardText, contains('Preparacion comprar - PicoRadar'));
    expect(clipboardText, contains('Placa candidata: ABC123'));
    expect(clipboardText, contains('Ciudad: Pereira'));
    expect(clipboardText, contains('[x] Revisar comparendos y obligaciones.'));
    expect(clipboardText, contains(buySellMandatoryCopy));
    expect(find.text('Resumen copiado.'), findsOneWidget);
  });

  testWidgets('malformed draft does not throw on open and removes key', (
    tester,
  ) async {
    await _preferences.setString(buySellDraftPreferenceKey, '{bad json');

    await _pumpScreen(tester, activeVehicle: _vehicle());

    expect(tester.takeException(), isNull);
    expect(await _preferences.getString(buySellDraftPreferenceKey), isNull);
    final restoreButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('buy-sell-restore-draft')),
    );
    expect(restoreButton.onPressed, isNotNull);
  });

  testWidgets('restore storage failure is visible and not stuck', (
    tester,
  ) async {
    final preferences = _FailingPreferences(failGetString: true);

    await _pumpScreen(
      tester,
      activeVehicle: _vehicle(),
      preferences: preferences,
    );

    expect(find.text('No se pudo restaurar el borrador.'), findsOneWidget);
    final restoreButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('buy-sell-restore-draft')),
    );
    expect(restoreButton.onPressed, isNotNull);
  });

  testWidgets('save storage failure is visible', (tester) async {
    final preferences = _FailingPreferences(failSetString: true);

    await _pumpScreen(
      tester,
      activeVehicle: _vehicle(),
      preferences: preferences,
    );

    await _tapVisible(tester, const ValueKey('buy-sell-save-draft'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo guardar el borrador.'), findsOneWidget);
  });

  testWidgets('clipboard failure is visible', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            throw PlatformException(code: 'clipboard-failed');
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    await _pumpScreen(tester, activeVehicle: _vehicle());

    await _tapVisible(tester, const ValueKey('buy-sell-copy-summary'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo copiar el resumen.'), findsOneWidget);
  });

  testWidgets('draft actions run one operation at a time', (tester) async {
    final preferences = _DelayedSetPreferences();
    await _pumpScreen(
      tester,
      activeVehicle: _vehicle(),
      preferences: preferences,
    );

    await _tapVisible(tester, const ValueKey('buy-sell-save-draft'));
    await tester.pump();

    final saveButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('buy-sell-save-draft')),
    );
    final restoreButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('buy-sell-restore-draft')),
    );
    final deleteButton = tester.widget<TextButton>(
      find.byKey(const ValueKey('buy-sell-delete-draft')),
    );
    final copyButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('buy-sell-copy-summary')),
    );
    expect(saveButton.onPressed, isNull);
    expect(restoreButton.onPressed, isNull);
    expect(deleteButton.onPressed, isNull);
    expect(copyButton.onPressed, isNull);

    preferences.completeSet();
    await tester.pumpAndSettle();

    expect(find.text('Borrador guardado en este dispositivo.'), findsOneWidget);
  });

  testWidgets('dispose during restore does not throw', (tester) async {
    final preferences = _DelayedGetPreferences();
    await _pumpScreen(
      tester,
      activeVehicle: _vehicle(),
      preferences: preferences,
      settleInitialRestore: false,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    preferences.completeGet(null);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('dispose during save does not throw', (tester) async {
    final preferences = _DelayedSetPreferences();
    await _pumpScreen(
      tester,
      activeVehicle: _vehicle(),
      preferences: preferences,
    );

    await _tapVisible(tester, const ValueKey('buy-sell-save-draft'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    preferences.completeSet();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('vehicle actions are disabled without an active vehicle', (
    tester,
  ) async {
    await _pumpScreen(tester, activeVehicle: null);

    for (final key in _vehicleActionKeys) {
      final button = tester.widget<OutlinedButton>(find.byKey(ValueKey(key)));
      expect(button.onPressed, isNull, reason: key);
    }
  });

  testWidgets('vehicle actions use the active vehicle when available', (
    tester,
  ) async {
    final opened = <String>[];
    final vehicle = _vehicle(id: 'active-vehicle', plate: 'ACT123');
    await _pumpScreen(
      tester,
      activeVehicle: vehicle,
      onOpenComparendos: (vehicle) => opened.add('comparendos:${vehicle.id}'),
      onOpenTramites: (vehicle) => opened.add('tramites:${vehicle.id}'),
      onOpenPeritajes: (vehicle) => opened.add('peritajes:${vehicle.id}'),
      onOpenDocuments: (vehicle) => opened.add('documents:${vehicle.id}'),
    );

    for (final key in _vehicleActionKeys) {
      final action = find.byKey(ValueKey(key));
      await tester.ensureVisible(action);
      await tester.pump();
      await tester.tap(action);
      await tester.pump();
    }

    expect(opened, [
      'comparendos:active-vehicle',
      'tramites:active-vehicle',
      'peritajes:active-vehicle',
      'documents:active-vehicle',
    ]);
  });

  testWidgets('phone viewports and text scale do not throw', (tester) async {
    for (final testCase in const [
      (Size(360, 800), 1.0),
      (Size(390, 844), 1.5),
      (Size(412, 915), 2.0),
    ]) {
      await _pumpScreen(
        tester,
        activeVehicle: _vehicle(),
        size: testCase.$1,
        textScale: testCase.$2,
      );

      expect(find.byKey(const ValueKey('buy-sell-screen')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}

Future<void> _tapVisible(WidgetTester tester, ValueKey<String> key) async {
  final finder = find.byKey(key);
  await Scrollable.ensureVisible(
    tester.element(finder),
    alignment: 0.5,
    duration: const Duration(milliseconds: 1),
  );
  await tester.pump(const Duration(milliseconds: 20));
  await tester.tap(finder);
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required VehicleProfile? activeVehicle,
  ValueChanged<VehicleProfile>? onOpenComparendos,
  ValueChanged<VehicleProfile>? onOpenTramites,
  ValueChanged<VehicleProfile>? onOpenPeritajes,
  ValueChanged<VehicleProfile>? onOpenDocuments,
  AppPreferences? preferences,
  Size size = const Size(430, 2000),
  double textScale = 1,
  bool settleInitialRestore = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appPreferencesProvider.overrideWithValue(preferences ?? _preferences),
        activeVehicleProvider.overrideWithValue(AsyncValue.data(activeVehicle)),
      ],
      child: MaterialApp(
        theme: buildPicoRadarTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: BuySellScreen(
          onOpenComparendos: onOpenComparendos,
          onOpenTramites: onOpenTramites,
          onOpenPeritajes: onOpenPeritajes,
          onOpenDocuments: onOpenDocuments,
        ),
      ),
    ),
  );
  await tester.pump();
  if (settleInitialRestore) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

VehicleProfile _vehicle({
  String id = 'vehicle-a',
  String plate = 'ABC123',
  VehicleKind kind = VehicleKind.car,
}) {
  return VehicleProfile(
    id: id,
    plate: plate,
    kind: kind,
    serviceType: VehicleServiceType.private,
    brand: 'Renault',
    model: 'Sandero',
    year: 2022,
    registrationCity: 'Medellín',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

const _vehicleActionKeys = [
  'buy-sell-open-comparendos',
  'buy-sell-open-tramites',
  'buy-sell-open-peritajes',
  'buy-sell-open-documents',
];

class _FailingPreferences extends MemoryPreferences {
  _FailingPreferences({this.failGetString = false, this.failSetString = false});

  final bool failGetString;
  final bool failSetString;

  @override
  Future<String?> getString(String key) async {
    if (failGetString) {
      throw StateError('getString failed');
    }
    return super.getString(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    if (failSetString) {
      throw StateError('setString failed');
    }
    await super.setString(key, value);
  }
}

class _DelayedGetPreferences extends MemoryPreferences {
  final _getCompleter = Completer<String?>();

  @override
  Future<String?> getString(String key) => _getCompleter.future;

  void completeGet(String? value) {
    _getCompleter.complete(value);
  }
}

class _DelayedSetPreferences extends MemoryPreferences {
  final _setCompleter = Completer<void>();

  @override
  Future<void> setString(String key, String value) async {
    await _setCompleter.future;
    await super.setString(key, value);
  }

  void completeSet() {
    if (!_setCompleter.isCompleted) {
      _setCompleter.complete();
    }
  }
}
