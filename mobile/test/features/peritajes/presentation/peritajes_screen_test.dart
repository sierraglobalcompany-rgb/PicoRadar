import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/theme/app_theme.dart';
import 'package:picoradar/core/storage/app_preferences.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/peritajes/data/peritajes_draft_store.dart';
import 'package:picoradar/features/peritajes/domain/peritajes_checklist.dart';
import 'package:picoradar/features/peritajes/presentation/peritajes_screen.dart';
import 'package:picoradar/features/vehicle_status/platform/external_launcher.dart';

import '../../services/presentation/v01b_tools_test_font.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadV01bToolsTestFont);
  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915),
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'V01B X02 delete is visually distinct and cancel preserves draft $size/$scale',
        (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final preferences = _MemoryPreferences();
          final store = PeritajesDraftStore(preferences);
          await store.saveDraft(
            'vehicle-1',
            PeritajesDraft(
              checkedItems: const {'identidad y documentos'},
              notes: 'QA local',
              updatedAt: DateTime(2026),
            ),
          );
          await _pumpPeritajes(
            tester,
            vehicleId: 'vehicle-1',
            vehicles: [_vehicle()],
            preferences: preferences,
            size: size,
          );
          await _tapVisible(tester, const ValueKey('peritajes-restore-draft'));
          final before = preferences.values['peritajes.draft.v1.vehicle-1'];
          final save = find.byKey(const ValueKey('peritajes-save-draft'));
          final saveFill = tester
              .widget<Material>(
                find
                    .descendant(of: save, matching: find.byType(Material))
                    .first,
              )
              .color;
          await _tapVisible(tester, const ValueKey('peritajes-delete-draft'));
          final confirm = find.widgetWithText(FilledButton, 'Eliminar');
          final cancel = find.widgetWithText(TextButton, 'Cancelar');
          expect(confirm.hitTestable(), findsOneWidget);
          expect(cancel.hitTestable(), findsOneWidget);
          final confirmFill = tester
              .widget<Material>(
                find
                    .descendant(of: confirm, matching: find.byType(Material))
                    .first,
              )
              .color;
          expect(
            confirmFill,
            isNot(saveFill),
            reason: 'Deletion must be visually distinct from saving',
          );
          await tester.tap(cancel);
          await tester.pumpAndSettle();
          expect(preferences.values['peritajes.draft.v1.vehicle-1'], before);
          expect(find.text('QA local'), findsOneWidget);
          expect(_tileValue(tester, 'identidad y documentos'), isTrue);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'V01B S05B actions expose working semantic taps $size/$scale',
        (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final semantics = tester.ensureSemantics();
          try {
            final launcher = _FakeExternalLauncher();
            final preferences = _MemoryPreferences();
            final router = await _pumpPeritajes(
              tester,
              vehicleId: 'vehicle-1',
              vehicles: [_vehicle(registrationCity: 'Cali')],
              launcher: launcher,
              preferences: preferences,
              size: size,
            );
            await _tapVisible(
              tester,
              const ValueKey('peritajes-check-identidad y documentos'),
            );
            final notes = find.byKey(const ValueKey('peritajes-notes-field'));
            await tester.ensureVisible(notes);
            await tester.pumpAndSettle();
            await tester.enterText(notes, 'QA keyboard notes');
            tester.view.viewInsets = const FakeViewPadding(bottom: 300);
            addTearDown(tester.view.resetViewInsets);
            await tester.pumpAndSettle();
            final save = find.byKey(const ValueKey('peritajes-save-draft'));
            await tester.ensureVisible(save);
            await tester.pumpAndSettle();
            expect(save.hitTestable(), findsOneWidget);
            expect(
              tester.getRect(save).bottom,
              lessThanOrEqualTo(size.height - 300),
            );
            await tester.tap(save);
            await tester.pumpAndSettle();
            final draft = await PeritajesDraftStore(preferences)
                .loadDraft('vehicle-1');
            expect(draft!.notes, 'QA keyboard notes');
            expect(draft.checkedItems, {'identidad y documentos'});
            tester.view.resetViewInsets();
            tester.testTextInput.hide();
            await tester.pumpAndSettle();
            for (final entry in [
              ('peritajes-open-documents', 'Abrir Documentos'),
              ('peritajes-search-maps', 'Buscar peritaje vehicular'),
            ]) {
              final action = find.byKey(ValueKey(entry.$1));
              await tester.ensureVisible(action);
              await tester.pumpAndSettle();
              expect(action.hitTestable(), findsOneWidget);
              expect(tester.getSize(action).height, greaterThanOrEqualTo(44));
              final node = tester.getSemantics(find.bySemanticsLabel(entry.$2));
              expect(
                node.getSemanticsData().hasAction(SemanticsAction.tap),
                isTrue,
                reason:
                    '${entry.$1} must be activatable by assistive technology',
              );
              node.owner!.performAction(node.id, SemanticsAction.tap);
              await tester.pumpAndSettle();
              if (entry.$1 == 'peritajes-open-documents') {
                expect(
                  find.text('documents vehicleId=vehicle-1'),
                  findsOneWidget,
                );
                router.pop();
                await tester.pumpAndSettle();
              }
              expect(tester.takeException(), isNull);
            }
            expect(
              Uri.parse(launcher.openedUris.single).queryParameters['query'],
              'peritaje vehicular Cali',
            );
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }

  testWidgets('requires an existing vehicle and shows required copy', (
    tester,
  ) async {
    await _pumpPeritajes(
      tester,
      vehicleId: 'vehicle-1',
      vehicles: [_vehicle()],
    );

    expect(find.byKey(const ValueKey('peritajes-screen')), findsOneWidget);
    expect(find.text('Checklist de revisión'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('peritajes-warning-copy')),
      findsOneWidget,
    );
    expect(find.text(peritajesProfessionalInspectionWarning), findsOneWidget);
    for (final item in peritajesChecklistItems) {
      expect(find.text(peritajesChecklistLabel(item)), findsOneWidget);
    }

    await _pumpPeritajes(tester, vehicleId: null, vehicles: [_vehicle()]);
    expect(find.byKey(const ValueKey('peritajes-go-garage')), findsOneWidget);

    await _pumpPeritajes(tester, vehicleId: 'missing', vehicles: [_vehicle()]);
    expect(find.byKey(const ValueKey('peritajes-go-garage')), findsOneWidget);
  });

  testWidgets('saves and restores a local draft per vehicle', (tester) async {
    final preferences = _MemoryPreferences();
    await _pumpPeritajes(
      tester,
      vehicleId: 'vehicle-1',
      vehicles: [_vehicle()],
      preferences: preferences,
    );

    await _tapVisible(
      tester,
      const ValueKey('peritajes-check-identidad y documentos'),
    );
    await tester.enterText(
      find.byKey(const ValueKey('peritajes-notes-field')),
      'Revisar golpe en puerta izquierda.',
    );
    await _tapVisible(tester, const ValueKey('peritajes-save-draft'));
    await tester.pump();

    final saved = preferences.values['peritajes.draft.v1.vehicle-1'];
    expect(saved, isA<String>());
    expect(saved as String, contains('identidad y documentos'));
    expect(saved, contains('Revisar golpe en puerta izquierda.'));

    await _tapVisible(
      tester,
      const ValueKey('peritajes-check-identidad y documentos'),
    );
    await tester.enterText(
      find.byKey(const ValueKey('peritajes-notes-field')),
      'Texto temporal',
    );
    await _tapVisible(tester, const ValueKey('peritajes-restore-draft'));
    await tester.pump();

    expect(_tileValue(tester, 'identidad y documentos'), isTrue);
    expect(find.text('Revisar golpe en puerta izquierda.'), findsOneWidget);
  });

  testWidgets('canceling draft delete leaves storage and form unchanged', (
    tester,
  ) async {
    final preferences = _MemoryPreferences();
    final store = PeritajesDraftStore(preferences);
    await store.saveDraft(
      'vehicle-1',
      PeritajesDraft(
        checkedItems: const {'identidad y documentos'},
        notes: 'Borrador existente.',
        updatedAt: DateTime(2026),
      ),
    );

    await _pumpPeritajes(
      tester,
      vehicleId: 'vehicle-1',
      vehicles: [_vehicle()],
      preferences: preferences,
    );
    await _tapVisible(
      tester,
      const ValueKey('peritajes-check-identidad y documentos'),
    );
    await tester.enterText(
      find.byKey(const ValueKey('peritajes-notes-field')),
      'Texto en edición.',
    );

    await _tapVisible(tester, const ValueKey('peritajes-delete-draft'));
    expect(find.text('Borrar borrador'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(
      preferences.values.containsKey('peritajes.draft.v1.vehicle-1'),
      isTrue,
    );
    expect(_tileValue(tester, 'identidad y documentos'), isTrue);
    expect(find.text('Texto en edición.'), findsOneWidget);
  });

  testWidgets('confirming draft delete clears storage and form', (
    tester,
  ) async {
    final preferences = _MemoryPreferences();
    final store = PeritajesDraftStore(preferences);
    await store.saveDraft(
      'vehicle-1',
      PeritajesDraft(
        checkedItems: const {'identidad y documentos'},
        notes: 'Borrador existente.',
        updatedAt: DateTime(2026),
      ),
    );

    await _pumpPeritajes(
      tester,
      vehicleId: 'vehicle-1',
      vehicles: [_vehicle()],
      preferences: preferences,
    );
    await _tapVisible(
      tester,
      const ValueKey('peritajes-check-identidad y documentos'),
    );
    await tester.enterText(
      find.byKey(const ValueKey('peritajes-notes-field')),
      'Texto en edición.',
    );

    await _tapVisible(tester, const ValueKey('peritajes-delete-draft'));
    expect(find.text('Borrar borrador'), findsOneWidget);
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    expect(
      preferences.values.containsKey('peritajes.draft.v1.vehicle-1'),
      isFalse,
    );
    expect(_tileValue(tester, 'identidad y documentos'), isFalse);
    expect(find.text('Texto en edición.'), findsNothing);
  });

  testWidgets('restore is explicit and scoped to the selected vehicle', (
    tester,
  ) async {
    final preferences = _MemoryPreferences();
    final store = PeritajesDraftStore(preferences);
    await store.saveDraft(
      'vehicle-1',
      PeritajesDraft(
        checkedItems: const {'motor/transmision'},
        notes: 'Compresión pendiente.',
        updatedAt: DateTime(2026),
      ),
    );

    await _pumpPeritajes(
      tester,
      vehicleId: 'vehicle-1',
      vehicles: [_vehicle()],
      preferences: preferences,
    );

    expect(_tileValue(tester, 'motor/transmision'), isFalse);
    expect(find.text('Compresión pendiente.'), findsNothing);

    await _tapVisible(tester, const ValueKey('peritajes-restore-draft'));
    await tester.pump();

    expect(_tileValue(tester, 'motor/transmision'), isTrue);
    expect(find.text('Compresión pendiente.'), findsOneWidget);

    await _pumpPeritajes(
      tester,
      vehicleId: 'vehicle-2',
      vehicles: [_vehicle(id: 'vehicle-2', plate: 'DEF456')],
      preferences: preferences,
    );
    await _tapVisible(tester, const ValueKey('peritajes-restore-draft'));
    await tester.pump();

    expect(_tileValue(tester, 'motor/transmision'), isFalse);
    expect(find.text('Compresión pendiente.'), findsNothing);
  });

  testWidgets('opens Documentos with push and back returns to Peritajes', (
    tester,
  ) async {
    final router = await _pumpPeritajes(
      tester,
      vehicleId: 'vehicle-1',
      vehicles: [_vehicle()],
    );

    await _tapVisible(tester, const ValueKey('peritajes-open-documents'));
    await tester.pumpAndSettle();

    expect(find.text('documents vehicleId=vehicle-1'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('peritajes-screen')), findsOneWidget);
  });

  testWidgets('searches peritaje vehicular in Google Maps', (tester) async {
    final launcher = _FakeExternalLauncher();
    await _pumpPeritajes(
      tester,
      vehicleId: 'vehicle-1',
      vehicles: [_vehicle(registrationCity: 'Medellín')],
      launcher: launcher,
    );

    await _tapVisible(tester, const ValueKey('peritajes-search-maps'));
    await tester.pump();

    final opened = Uri.parse(launcher.openedUris.single);
    expect(opened.scheme, 'https');
    expect(opened.host, 'www.google.com');
    expect(opened.path, '/maps/search/');
    expect(opened.queryParameters, {
      'api': '1',
      'query': 'peritaje vehicular Medellín',
    });
  });

  testWidgets('launcher false shows a visible error', (tester) async {
    final launcher = _FakeExternalLauncher(openResult: false);
    await _pumpPeritajes(
      tester,
      vehicleId: 'vehicle-1',
      vehicles: [_vehicle(registrationCity: 'Cali')],
      launcher: launcher,
    );

    await _tapVisible(tester, const ValueKey('peritajes-search-maps'));
    await tester.pump();

    expect(find.text('No pudimos abrir Google Maps.'), findsOneWidget);
  });

  testWidgets('launcher exception shows a visible error', (tester) async {
    await _pumpPeritajes(
      tester,
      vehicleId: 'vehicle-1',
      vehicles: [_vehicle(registrationCity: 'Cali')],
      launcher: _FakeExternalLauncher(throwOnOpen: true),
    );

    await _tapVisible(tester, const ValueKey('peritajes-search-maps'));
    await tester.pump();

    expect(find.text('No pudimos abrir Google Maps.'), findsOneWidget);
  });

  testWidgets('busy state resets after launcher failure', (tester) async {
    final pendingOpen = Completer<bool>();
    await _pumpPeritajes(
      tester,
      vehicleId: 'vehicle-1',
      vehicles: [_vehicle(registrationCity: 'Cali')],
      launcher: _FakeExternalLauncher(pendingOpen: pendingOpen),
    );

    await _tapVisible(tester, const ValueKey('peritajes-search-maps'));
    await tester.pump();

    expect(_actionCardEnabled(tester, 'peritajes-search-maps'), isFalse);

    pendingOpen.complete(false);
    await tester.pumpAndSettle();

    expect(_actionCardEnabled(tester, 'peritajes-search-maps'), isTrue);
    expect(find.text('No pudimos abrir Google Maps.'), findsOneWidget);
  });

  testWidgets('dispose during launch does not update UI or throw', (
    tester,
  ) async {
    final pendingOpen = Completer<bool>();
    await _pumpPeritajes(
      tester,
      vehicleId: 'vehicle-1',
      vehicles: [_vehicle(registrationCity: 'Cali')],
      launcher: _FakeExternalLauncher(pendingOpen: pendingOpen),
    );

    await _tapVisible(tester, const ValueKey('peritajes-search-maps'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    pendingOpen.complete(false);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('No pudimos abrir Google Maps.'), findsNothing);
  });
}

Future<GoRouter> _pumpPeritajes(
  WidgetTester tester, {
  required String? vehicleId,
  required List<VehicleProfile> vehicles,
  _MemoryPreferences? preferences,
  ExternalLauncher? launcher,
  Size size = const Size(390, 844),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();

  final router = GoRouter(
    initialLocation: '/peritajes',
    routes: [
      GoRoute(
        path: '/peritajes',
        builder: (context, state) => PeritajesScreen(vehicleId),
      ),
      GoRoute(
        path: '/garage',
        builder: (context, state) => const Scaffold(body: Text('garage')),
      ),
      GoRoute(
        path: '/apps/module/documentos',
        builder: (context, state) => Scaffold(
          body: Text(
            'documents vehicleId=${state.uri.queryParameters['vehicleId']}',
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        vehicleListProvider.overrideWithValue(AsyncValue.data(vehicles)),
        appPreferencesProvider.overrideWithValue(
          preferences ?? _MemoryPreferences(),
        ),
        externalLauncherProvider.overrideWithValue(
          launcher ?? _FakeExternalLauncher(),
        ),
      ],
      child: MaterialApp.router(
        theme: buildPicoRadarTheme(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  return router;
}

bool? _tileValue(WidgetTester tester, String item) {
  return tester
      .widget<CheckboxListTile>(find.byKey(ValueKey('peritajes-check-$item')))
      .value;
}

bool _actionCardEnabled(WidgetTester tester, String keyName) {
  final tile = find.descendant(
    of: find.byKey(ValueKey(keyName)),
    matching: find.byType(ListTile),
  );
  return tester.widget<ListTile>(tile).enabled;
}

Future<void> _tapVisible(WidgetTester tester, ValueKey<String> key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 300));
}

VehicleProfile _vehicle({
  String id = 'vehicle-1',
  String plate = 'ABC123',
  String? registrationCity,
}) {
  return VehicleProfile(
    id: id,
    plate: plate,
    kind: VehicleKind.car,
    serviceType: VehicleServiceType.private,
    registrationCity: registrationCity,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

class _MemoryPreferences implements AppPreferences {
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

class _FakeExternalLauncher implements ExternalLauncher {
  _FakeExternalLauncher({
    this.openResult = true,
    this.pendingOpen,
    this.throwOnOpen = false,
  });

  final bool openResult;
  final Completer<bool>? pendingOpen;
  final bool throwOnOpen;
  final openedUris = <String>[];

  @override
  Future<bool> callPhone(String phone) async => true;

  @override
  Future<bool> openExternal(String uri) {
    openedUris.add(uri);
    if (throwOnOpen) {
      return Future.error(StateError('launcher failed'));
    }
    final completer = pendingOpen;
    if (completer != null) {
      return completer.future;
    }
    return Future.value(openResult);
  }
}
