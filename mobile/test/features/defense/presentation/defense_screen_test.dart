import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/features/defense/application/defense_case_providers.dart';
import 'package:picoradar/features/defense/data/defense_case.dart';
import 'package:picoradar/features/defense/data/defense_case_store.dart';
import 'package:picoradar/features/defense/data/defense_case_summary.dart';
import 'package:picoradar/features/defense/presentation/defense_screen.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/vehicle_status/platform/external_launcher.dart';

late _MemoryDefenseCaseStore _store;
late _FakeExternalLauncher _launcher;

void main() {
  var ids = 0;

  setUp(() {
    ids = 0;
    _store = _MemoryDefenseCaseStore(
      idGenerator: () => 'case-${(++ids).toString().padLeft(4, '0')}',
      now: () => DateTime.utc(2026, 9, 3, 8),
    );
    _launcher = _FakeExternalLauncher();
  });

  testWidgets('requires a vehicle before exposing case actions', (
    tester,
  ) async {
    await _pumpScreen(tester);

    expect(find.byKey(const ValueKey('defense-no-vehicle')), findsOneWidget);
    expect(find.byKey(const ValueKey('defense-create-case')), findsNothing);
  });

  testWidgets('creates and lists a local defense case', (tester) async {
    final vehicle = _vehicle();

    await _pumpScreen(tester, vehicles: [vehicle], active: vehicle);
    await tester.tap(find.byKey(const ValueKey('defense-create-case')));
    await _pumpDialog(tester);
    await _fillForm(
      tester,
      reference: 'CMP-789',
      authority: 'Secretaria de Movilidad',
      incidentDate: '2026-09-01',
      notificationDate: '2026-09-04',
      facts: 'Recibi una notificacion y quiero ordenar los soportes.',
    );
    await tester.tap(find.byKey(const ValueKey('defense-form-save')));
    await _pumpAsyncUi(tester);

    expect(
      (await _store.listForVehicle(vehicle.id)).single.authority,
      'Secretaria de Movilidad',
    );
    expect(find.text('Secretaria de Movilidad'), findsOneWidget);
    expect(find.text('Referencia: CMP-789'), findsOneWidget);
    expect(
      find.text('Recibi una notificacion y quiero ordenar los soportes.'),
      findsOneWidget,
    );
    expect(
      (await _store.listForVehicle(vehicle.id)).single.vehicleId,
      vehicle.id,
    );
  });

  testWidgets('edits an existing case', (tester) async {
    final vehicle = _vehicle();
    final created = await _store.createCase(
      _draft(vehicleId: vehicle.id, facts: 'Hechos iniciales'),
    );

    await _pumpScreen(tester, vehicles: [vehicle], active: vehicle);
    final editButton = find.byKey(ValueKey('defense-edit-${created.id}'));
    await tester.ensureVisible(editButton);
    await tester.pump();
    await tester.tap(editButton);
    await _pumpDialog(tester);
    await tester.enterText(
      find.byKey(const ValueKey('defense-reference-field')),
      'CMP-EDIT',
    );
    await tester.enterText(
      find.byKey(const ValueKey('defense-facts-field')),
      'Hechos editados por el usuario',
    );
    await tester.tap(find.byKey(const ValueKey('defense-form-save')));
    await _pumpAsyncUi(tester);

    expect(find.text('Referencia: CMP-EDIT'), findsOneWidget);
    expect(find.text('Hechos editados por el usuario'), findsOneWidget);
  });

  testWidgets('deletes only after confirmation', (tester) async {
    final vehicle = _vehicle();
    final created = await _store.createCase(_draft(vehicleId: vehicle.id));

    await _pumpScreen(tester, vehicles: [vehicle], active: vehicle);
    final deleteButton = find.byKey(ValueKey('defense-delete-${created.id}'));
    await tester.ensureVisible(deleteButton);
    await tester.pump();
    await tester.tap(deleteButton);
    await _pumpDialog(tester);
    expect(find.text('Eliminar expediente'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('defense-delete-cancel')));
    await _pumpAsyncUi(tester);
    expect(find.text('Secretaria de Movilidad'), findsOneWidget);

    await tester.ensureVisible(deleteButton);
    await tester.pump();
    await tester.tap(deleteButton);
    await _pumpDialog(tester);
    await tester.tap(find.byKey(const ValueKey('defense-delete-confirm')));
    await _pumpAsyncUi(tester);

    expect(find.byKey(const ValueKey('defense-empty-cases')), findsOneWidget);
    expect(await _store.listForVehicle(vehicle.id), isEmpty);
  });

  testWidgets('copy warning cancel and confirm guard clipboard handoff', (
    tester,
  ) async {
    var clipboardText = '';
    var clipboardWrites = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardWrites += 1;
            clipboardText = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final vehicle = _vehicle(plate: 'ABC123');
    final created = await _store.createCase(
      _draft(vehicleId: vehicle.id, facts: 'Solo organizo mis hechos.'),
    );

    await _pumpScreen(tester, vehicles: [vehicle], active: vehicle);
    final copyButton = find.byKey(ValueKey('defense-copy-${created.id}'));
    await tester.ensureVisible(copyButton);
    await tester.pump();
    await tester.tap(copyButton);
    await _pumpDialog(tester);

    expect(find.text('Copiar expediente'), findsOneWidget);
    expect(
      find.text(
        'El resumen saldra del almacenamiento cifrado de PicoRadar y quedara en el portapapeles del sistema.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('defense-copy-cancel')));
    await _pumpAsyncUi(tester);

    expect(clipboardWrites, 0);
    expect(find.text('Resumen neutral copiado.'), findsNothing);

    await tester.ensureVisible(copyButton);
    await tester.pump();
    await tester.tap(copyButton);
    await _pumpDialog(tester);
    await tester.tap(find.byKey(const ValueKey('defense-copy-confirm')));
    await _pumpAsyncUi(tester);

    expect(clipboardWrites, 1);
    expect(clipboardText, startsWith(defensePrudentDisclaimer));
    expect(clipboardText, contains('Vehiculo: ABC123'));
    expect(clipboardText, contains('Solo organizo mis hechos.'));
    expect(
      clipboardText.toLowerCase(),
      isNot(contains(['se', 'anula'].join(' '))),
    );
    expect(
      clipboardText.toLowerCase(),
      isNot(contains(['gana', 'ras'].join())),
    );
    expect(find.text('Resumen neutral copiado.'), findsOneWidget);
  });

  testWidgets('clipboard exception is visible without success claim', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            throw PlatformException(code: 'clipboard-denied');
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final vehicle = _vehicle();
    final created = await _store.createCase(_draft(vehicleId: vehicle.id));

    await _pumpScreen(tester, vehicles: [vehicle], active: vehicle);
    final copyButton = find.byKey(ValueKey('defense-copy-${created.id}'));
    await tester.ensureVisible(copyButton);
    await tester.pump();
    await tester.tap(copyButton);
    await _pumpDialog(tester);
    await tester.tap(find.byKey(const ValueKey('defense-copy-confirm')));
    await _pumpAsyncUi(tester);

    expect(
      find.text('No pudimos copiar el resumen al portapapeles.'),
      findsOneWidget,
    );
    expect(find.text('Resumen neutral copiado.'), findsNothing);
  });

  testWidgets('clipboard false is visible without success claim', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            return false;
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final vehicle = _vehicle();
    final created = await _store.createCase(_draft(vehicleId: vehicle.id));

    await _pumpScreen(tester, vehicles: [vehicle], active: vehicle);
    final copyButton = find.byKey(ValueKey('defense-copy-${created.id}'));
    await tester.ensureVisible(copyButton);
    await tester.pump();
    await tester.tap(copyButton);
    await _pumpDialog(tester);
    await tester.tap(find.byKey(const ValueKey('defense-copy-confirm')));
    await _pumpAsyncUi(tester);

    expect(
      find.text('No pudimos copiar el resumen al portapapeles.'),
      findsOneWidget,
    );
    expect(find.text('Resumen neutral copiado.'), findsNothing);
  });

  testWidgets('opens SIMIT and Corte links through external launcher', (
    tester,
  ) async {
    final vehicle = _vehicle();

    await _pumpScreen(
      tester,
      vehicles: [vehicle],
      active: vehicle,
      launcher: _launcher,
    );
    await tester.tap(find.byKey(const ValueKey('defense-open-simit')));
    await tester.tap(find.byKey(const ValueKey('defense-open-c038')));
    await tester.tap(find.byKey(const ValueKey('defense-open-c321')));

    expect(_launcher.opened, [defenseSimitUrl, defenseC038Url, defenseC321Url]);
  });

  testWidgets('launcher false shows visible message', (tester) async {
    final vehicle = _vehicle();
    _launcher.openResult = false;

    await _pumpScreen(
      tester,
      vehicles: [vehicle],
      active: vehicle,
      launcher: _launcher,
    );
    await tester.tap(find.byKey(const ValueKey('defense-open-simit')));
    await _pumpAsyncUi(tester);

    expect(_launcher.opened, [defenseSimitUrl]);
    expect(find.text('No pudimos abrir SIMIT.'), findsOneWidget);
  });

  testWidgets('launcher exception shows visible message', (tester) async {
    final vehicle = _vehicle();
    _launcher.openError = StateError('launcher failed');

    await _pumpScreen(
      tester,
      vehicles: [vehicle],
      active: vehicle,
      launcher: _launcher,
    );
    await tester.tap(find.byKey(const ValueKey('defense-open-c038')));
    await _pumpAsyncUi(tester);

    expect(_launcher.opened, [defenseC038Url]);
    expect(find.text('No pudimos abrir C-038/20.'), findsOneWidget);
  });

  testWidgets('dispose during launcher is lifecycle safe', (tester) async {
    final vehicle = _vehicle();
    final pendingOpen = Completer<void>();
    _launcher.delay = pendingOpen.future;

    await _pumpScreen(
      tester,
      vehicles: [vehicle],
      active: vehicle,
      launcher: _launcher,
    );
    await tester.tap(find.byKey(const ValueKey('defense-open-c321')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());

    pendingOpen.complete();
    await tester.pump();

    expect(_launcher.opened, [defenseC321Url]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dispose during delayed save is lifecycle safe', (tester) async {
    final vehicle = _vehicle();
    final pendingCreate = Completer<void>();
    final delayedStore = _DelayedCreateStore(delay: pendingCreate.future);

    await _pumpScreen(
      tester,
      vehicles: [vehicle],
      active: vehicle,
      store: delayedStore,
    );
    await tester.tap(find.byKey(const ValueKey('defense-create-case')));
    await _pumpDialog(tester);
    await _fillForm(
      tester,
      authority: 'Secretaria',
      incidentDate: '2026-09-01',
      facts: 'Hechos de lifecycle',
    );
    await tester.tap(find.byKey(const ValueKey('defense-form-save')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());

    pendingCreate.complete();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('target responsive viewports avoid overflow', (tester) async {
    final vehicle = _vehicle(registrationCity: 'Bogota');
    const cases = [
      (Size(360, 800), 1.0),
      (Size(360, 800), 2.0),
      (Size(390, 844), 1.5),
      (Size(412, 915), 2.0),
    ];

    for (final testCase in cases) {
      await _pumpScreen(
        tester,
        vehicles: [vehicle],
        active: vehicle,
        size: testCase.$1,
        textScale: testCase.$2,
      );

      expect(find.byKey(const ValueKey('defense-screen')), findsOneWidget);
      expect(find.byKey(const ValueKey('defense-create-case')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  List<VehicleProfile> vehicles = const [],
  VehicleProfile? active,
  DefenseCaseStore? store,
  ExternalLauncher? launcher,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        vehicleListProvider.overrideWith((ref) async => vehicles),
        activeVehicleProvider.overrideWith((ref) async => active),
        defenseCaseStoreProvider.overrideWithValue(store ?? _store),
        externalLauncherProvider.overrideWithValue(
          launcher ?? _FakeExternalLauncher(),
        ),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: const DefenseScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _pumpDialog(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _pumpAsyncUi(WidgetTester tester) async {
  await tester.pump();
  await tester.idle();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pump();
  await tester.idle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

Future<void> _fillForm(
  WidgetTester tester, {
  String reference = '',
  required String authority,
  required String incidentDate,
  String notificationDate = '',
  required String facts,
}) async {
  await tester.enterText(
    find.byKey(const ValueKey('defense-reference-field')),
    reference,
  );
  await tester.enterText(
    find.byKey(const ValueKey('defense-authority-field')),
    authority,
  );
  await tester.enterText(
    find.byKey(const ValueKey('defense-incident-date-field')),
    incidentDate,
  );
  await tester.enterText(
    find.byKey(const ValueKey('defense-notification-date-field')),
    notificationDate,
  );
  await tester.enterText(
    find.byKey(const ValueKey('defense-facts-field')),
    facts,
  );
}

VehicleProfile _vehicle({
  String id = 'vehicle-a',
  String plate = 'ABC123',
  VehicleKind kind = VehicleKind.car,
  VehicleServiceType serviceType = VehicleServiceType.private,
  String? registrationCity,
}) {
  return VehicleProfile(
    id: id,
    plate: plate,
    kind: kind,
    serviceType: serviceType,
    registrationCity: registrationCity,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

DefenseCaseDraft _draft({
  required String vehicleId,
  String? reference = 'CMP-123',
  String authority = 'Secretaria de Movilidad',
  String facts = 'Hechos escritos por el usuario',
}) {
  return DefenseCaseDraft(
    vehicleId: vehicleId,
    reference: reference,
    authority: authority,
    incidentDate: DateTime.utc(2026, 9),
    facts: facts,
  );
}

class _FakeExternalLauncher implements ExternalLauncher {
  var openResult = true;
  Object? openError;
  Future<void>? delay;
  final opened = <String>[];

  @override
  Future<bool> callPhone(String phone) async => true;

  @override
  Future<bool> openExternal(String uri) async {
    opened.add(uri);
    final pending = delay;
    if (pending != null) {
      await pending;
    }
    final error = openError;
    if (error != null) {
      throw error;
    }
    return openResult;
  }
}

class _DelayedCreateStore extends _MemoryDefenseCaseStore {
  _DelayedCreateStore({required this.delay});

  final Future<void> delay;

  @override
  Future<DefenseCase> createCase(DefenseCaseDraft draft) async {
    await delay;
    return super.createCase(draft);
  }
}

class _MemoryDefenseCaseStore extends DefenseCaseStore {
  _MemoryDefenseCaseStore({
    DateTime Function()? now,
    String Function()? idGenerator,
  }) : _now = now ?? DateTime.now,
       _idGenerator = idGenerator ?? (() => 'case-id');

  final DateTime Function() _now;
  final String Function() _idGenerator;
  final _items = <DefenseCase>[];

  @override
  Future<List<DefenseCase>> listForVehicle(String vehicleId) async {
    final filtered = [
      for (final item in _items)
        if (item.vehicleId == vehicleId) item,
    ];
    filtered.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return filtered;
  }

  @override
  Future<DefenseCase> createCase(DefenseCaseDraft draft) async {
    final now = _now().toUtc();
    final item = DefenseCase(
      id: _idGenerator(),
      vehicleId: draft.vehicleId.trim(),
      reference: _blankToNull(draft.reference),
      authority: draft.authority.trim(),
      incidentDate: draft.incidentDate,
      notificationDate: draft.notificationDate,
      facts: draft.facts.trim(),
      createdAt: now,
      updatedAt: now,
    );
    _items.add(item);
    return item;
  }

  @override
  Future<DefenseCase> updateCase({
    required String caseId,
    required DefenseCaseDraft draft,
  }) async {
    final index = _items.indexWhere((item) => item.id == caseId);
    if (index < 0) {
      throw const DefenseCaseStoreException(DefenseCaseStore.missingCaseCode);
    }
    final current = _items[index];
    final updated = DefenseCase(
      id: current.id,
      vehicleId: current.vehicleId,
      reference: _blankToNull(draft.reference),
      authority: draft.authority.trim(),
      incidentDate: draft.incidentDate,
      notificationDate: draft.notificationDate,
      facts: draft.facts.trim(),
      createdAt: current.createdAt,
      updatedAt: _now().toUtc(),
    );
    _items[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteCase(String caseId) async {
    _items.removeWhere((item) => item.id == caseId);
  }

  String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
