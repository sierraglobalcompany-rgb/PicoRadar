import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/theme/app_theme.dart';
import 'package:picoradar/features/documents/application/wallet_providers.dart';
import 'package:picoradar/features/documents/application/wallet_session.dart';
import 'package:picoradar/features/documents/data/wallet_models.dart';
import 'package:picoradar/features/documents/platform/wallet_platform.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/vehicle_status/data/insurance_directory.dart';
import 'package:picoradar/features/vehicle_status/data/vehicle_obligation_store.dart';
import 'package:picoradar/features/vehicle_status/domain/vehicle_obligation.dart';
import 'package:picoradar/features/vehicle_status/platform/external_launcher.dart';
import 'package:picoradar/features/vehicle_status/presentation/insurance_owner_sheets.dart';
import 'package:picoradar/features/vehicle_status/presentation/insurance_quote_demo.dart';

import '../../../test_app_harness.dart';
import '../../../plate_test_fonts.dart';

const _type = VehicleObligationType.insurance;
const _secretPolicy = 'QA-PRIVATE-POLICY-NOT-FOR-URL';
const _assistance = InsuranceChannel(
  id: 'alpha-assistance',
  label: 'Asistencia Alfa',
  kind: 'phone',
  value: '#123',
  purpose: 'assistance',
  verified: true,
  sourceUrl: 'https://alpha.example/assistance',
  reviewedAt: '2026-09-13',
);
const _whatsapp = InsuranceChannel(
  id: 'alpha-chat',
  label: 'WhatsApp Alfa',
  kind: 'whatsapp',
  value: '573001234567',
  purpose: 'customerService',
  verified: true,
  sourceUrl: 'https://alpha.example/chat',
  reviewedAt: '2026-09-13',
);
const _unverified = InsuranceChannel(
  id: 'alpha-pending',
  label: 'Canal pendiente Alfa',
  kind: 'phone',
  value: '6011234567',
  purpose: 'assistance',
  verified: false,
  sourceUrl: 'https://alpha.example/pending',
  reviewedAt: '2026-09-13',
);
final _alpha = InsuranceCompany(
  id: 'alpha',
  name: 'Alfa Seguros',
  legalName: 'Alfa Seguros de prueba S.A.',
  aliases: const ['\u00c1lfa hist\u00f3rica'],
  website: 'https://alpha.example/',
  sourceUrl: 'https://alpha.example/evidence',
  reviewedAt: '2026-09-13',
  channels: const [_assistance, _whatsapp, _unverified],
  categories: const ['car', 'motorcycle'],
);
final _beta = InsuranceCompany(
  id: 'beta',
  name: 'Beta Seguros',
  legalName: 'Beta Seguros de prueba S.A.',
  aliases: const [],
  website: 'https://beta.example/',
  sourceUrl: 'https://beta.example/evidence',
  reviewedAt: '2026-09-13',
  channels: const [],
  categories: const ['car'],
);
final _directory = InsuranceDirectory(entries: [_alpha, _beta]);

void main() {
  setUpAll(loadPlateTestFonts);
  late TestAppHarness harness;
  late _ControlledStore store;
  late _Launcher launcher;
  late _Authenticator authenticator;
  late WalletSession session;
  late _SecurePlatform platform;
  late WalletScreenSecurity security;
  var documentReads = 0;
  final clipboard = <String>[];
  var clipboardFails = false;

  setUp(() {
    harness = TestAppHarness();
    store = _ControlledStore(harness.database);
    launcher = _Launcher();
    authenticator = _Authenticator();
    session = WalletSession(
      authenticator: authenticator,
      preferences: _ProtectedPreferences(),
    );
    platform = _SecurePlatform();
    documentReads = 0;
    clipboard.clear();
    clipboardFails = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            if (clipboardFails) {
              throw PlatformException(code: 'clipboard-unavailable');
            }
            clipboard.add((call.arguments as Map)['text'] as String);
          }
          if (call.method == 'Clipboard.hasStrings') {
            return {'value': clipboard.isNotEmpty};
          }
          return null;
        });
  });

  tearDown(() async {
    authenticator.finishPending();
    store.finishPending();
    session.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    await harness.dispose();
  });

  Future<VehicleProfile> car({String plate = 'BOG127'}) =>
      harness.repository.createVehicle(
        plate: plate,
        kind: VehicleKind.car,
        serviceType: VehicleServiceType.private,
        brand: 'Marca QA',
        model: 'Modelo QA',
        year: 2024,
        registrationCity: 'Bogot\u00e1',
      );

  Future<VehicleObligation> seed(
    VehicleProfile vehicle, {
    Map<String, String>? details,
  }) => VehicleObligationStore(harness.database).upsert(
    vehicleId: vehicle.id,
    type: _type,
    startDate: DateTime(2026, 1, 4),
    dueDate: DateTime(2027, 1, 4),
    reminderEnabled: true,
    details:
        details ??
        const {
          'providerId': 'alpha',
          'providerName': 'Alfa Seguros',
          'policyNumber': _secretPolicy,
          'legacyPrivateNote': 'retain-unedited-value',
        },
  );

  Future<void> mount(
    WidgetTester tester,
    VehicleProfile vehicle, {
    VehicleObligation? original,
    double scale = 1,
    double keyboard = 0,
    Size size = const Size(390, 844),
    Future<InsuranceDirectory> Function()? loadDirectory,
    List<WalletDocument>? documents,
  }) async {
    // Its serialized Future queue must originate in the widget test's fake-async zone.
    security = WalletScreenSecurity(platform);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await harness.pump(
      tester,
      externalLauncher: launcher,
      childOverride: ProviderScope(
        overrides: [
          insuranceDirectoryProvider.overrideWith(
            (_) async =>
                loadDirectory == null ? _directory : await loadDirectory(),
          ),
          vehicleObligationStoreProvider.overrideWithValue(store),
          vehicleRepositoryProvider.overrideWithValue(harness.repository),
          vehicleObligationProvider((vehicle.id, _type))
              .overrideWith((_) => store.get(vehicle.id, _type)),
          walletSessionProvider.overrideWithValue(session),
          walletScreenSecurityProvider.overrideWithValue(security),
          walletPlatformProvider.overrideWithValue(platform),
          walletDocumentsProvider(WalletOwner.vehicle(vehicle.id))
              .overrideWith((ref) async {
                final active = ref.watch(walletSessionProvider);
                active.addListener(ref.invalidateSelf);
                ref.onDispose(() => active.removeListener(ref.invalidateSelf));
                if (!active.accessAllowed) {
                  throw StateError('Wallet fixture locked');
                }
                documentReads++;
                return documents ?? <WalletDocument>[];
              }),
        ],
        child: MaterialApp(
          theme: buildPicoRadarTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              viewInsets: EdgeInsets.only(bottom: keyboard),
            ),
            child: RepaintBoundary(
              key: const ValueKey('insurance-screenshot-boundary'),
              child: child!,
            ),
          ),
          home: _SheetProbe(vehicle: vehicle, original: original),
        ),
      ),
    );
  }

  testWidgets(
    'direct editor requires authorization before revealing metadata',
    (tester) async {
      final vehicle = await car();
      final original = await seed(vehicle);
      await mount(tester, vehicle, original: original);
      authenticator.pending = Completer<WalletAuthenticationResult>();
      await _tap(tester, find.byKey(const ValueKey('open-editor')));
      expect(authenticator.calls, 1);
      expect(find.text(_secretPolicy), findsNothing);
      authenticator.pending!.complete(WalletAuthenticationResult.cancelled);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('insurance-editor-save')), findsNothing);
      expect(
        (await store.get(vehicle.id, _type))!.details['policyNumber'],
        _secretPolicy,
      );
    },
  );

  testWidgets(
    'editor saves original ID after favorite changes, preserving dates and unknown details',
    (tester) async {
      final first = await car();
      final second = await car(plate: 'KZA123');
      final original = await seed(first);
      final other = await seed(
        second,
        details: const {
          'providerName': 'Beta Seguros',
          'policyNumber': 'OTHER-UNCHANGED',
        },
      );
      await mount(tester, first, original: original);
      await _tap(tester, find.byKey(const ValueKey('open-editor')));
      await harness.repository.setActiveVehicle(second.id);
      await _enter(tester, 'policyNumber', 'QA-UPDATED-ORIGINAL');
      await _tap(tester, find.byKey(const ValueKey('insurance-editor-save')));
      final saved = await store.get(first.id, _type);
      final untouched = await store.get(second.id, _type);
      expect(saved!.details['policyNumber'], 'QA-UPDATED-ORIGINAL');
      expect(
        saved.details['legacyPrivateNote'],
        original.details['legacyPrivateNote'],
      );
      expect(saved.startDate, original.startDate);
      expect(saved.dueDate, original.dueDate);
      expect(saved.reminderEnabled, original.reminderEnabled);
      expect(untouched!.details, other.details);
      expect((await harness.repository.getActiveVehicle())!.id, second.id);
      expect(documentReads, 0);
      expect(launcher.urls, isEmpty);
    },
  );

  testWidgets('partial custom policy can save without inventing dates', (
    tester,
  ) async {
    final vehicle = await car();
    await mount(tester, vehicle);
    await _tap(tester, find.byKey(const ValueKey('open-editor')));
    await _enter(tester, 'providerName', 'Aseguradora local no catalogada');
    await _tap(tester, find.byKey(const ValueKey('insurance-editor-save')));
    final saved = await store.get(vehicle.id, _type);
    expect(saved!.details['providerName'], 'Aseguradora local no catalogada');
    expect(saved.details.containsKey('providerId'), isFalse);
    expect(saved.startDate, isNull);
    expect(saved.dueDate, isNull);
  });

  for (final field in ['start', 'due']) {
    testWidgets(
      'editor $field uses Spanish calendar only and cancellation preserves row',
      (tester) async {
        final vehicle = await car();
        final original = await seed(vehicle);
        await mount(tester, vehicle, original: original);
        await _tap(tester, find.byKey(const ValueKey('open-editor')));
        await _tap(tester, find.byKey(ValueKey('insurance-editor-$field')));
        final picker = tester.widget<DatePickerDialog>(
          find.byType(DatePickerDialog),
        );
        expect(picker.initialEntryMode, DatePickerEntryMode.calendarOnly);
        expect(
          picker.initialDate,
          field == 'start' ? original.startDate : original.dueDate,
        );
        expect(
          Localizations.localeOf(
            tester.element(find.byType(CalendarDatePicker)),
          ).languageCode,
          'es',
        );
        expect(find.byType(InputDatePickerFormField), findsNothing);
        await _tap(tester, find.text('Cancelar'));
        expect((await store.get(vehicle.id, _type))!.dueDate, original.dueDate);
        expect(store.saveCalls, 0);
      },
    );
  }

  testWidgets(
    'date order is checked but an expired policy remains registrable',
    (tester) async {
      final vehicle = await car();
      final original = await seed(vehicle);
      await mount(tester, vehicle, original: original);
      await _tap(tester, find.byKey(const ValueKey('open-editor')));
      await _enter(tester, 'due', '2020-01-01');
      await _tap(tester, find.byKey(const ValueKey('insurance-editor-save')));
      expect(
        find.text('El vencimiento no puede ser anterior al inicio.'),
        findsOneWidget,
      );
      expect(store.saveCalls, 0);
      await _enter(tester, 'start', '2019-01-01');
      await _tap(tester, find.byKey(const ValueKey('insurance-editor-save')));
      expect(
        (await store.get(vehicle.id, _type))!.dueDate,
        DateTime(2020, 1, 1),
      );
    },
  );

  testWidgets(
    'provider required and newly edited malformed phone is rejected',
    (tester) async {
      final vehicle = await car();
      await mount(tester, vehicle);
      await _tap(tester, find.byKey(const ValueKey('open-editor')));
      await _tap(tester, find.byKey(const ValueKey('insurance-editor-save')));
      expect(
        find.text('Selecciona o escribe una aseguradora.'),
        findsOneWidget,
      );
      await _enter(tester, 'providerName', 'Alfa Seguros');
      await _enter(
        tester,
        'assistancePhone',
        'https://unexpected.example/phone',
      );
      await _tap(tester, find.byKey(const ValueKey('insurance-editor-save')));
      expect(find.text('Revisa el tel\u00e9fono.'), findsOneWidget);
      expect(await store.get(vehicle.id, _type), isNull);
    },
  );

  testWidgets(
    'save failure retains draft and previous row and retry succeeds',
    (tester) async {
      final vehicle = await car();
      final original = await seed(vehicle);
      store.failSave = true;
      await mount(tester, vehicle, original: original);
      await _tap(tester, find.byKey(const ValueKey('open-editor')));
      await _enter(tester, 'policyNumber', 'QA-RETRY-DRAFT');
      await _tap(tester, find.byKey(const ValueKey('insurance-editor-save')));
      expect(find.textContaining('No se pudo guardar.'), findsOneWidget);
      expect((await store.get(vehicle.id, _type))!.details, original.details);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('insurance-editor-policyNumber')),
            )
            .controller!
            .text,
        'QA-RETRY-DRAFT',
      );
      store.failSave = false;
      await _tap(tester, find.byKey(const ValueKey('insurance-editor-save')));
      expect(
        (await store.get(vehicle.id, _type))!.details['policyNumber'],
        'QA-RETRY-DRAFT',
      );
      expect(store.saveCalls, 2);
    },
  );

  testWidgets(
    'concurrent edit with same persisted timestamp is not overwritten',
    (tester) async {
      final vehicle = await car();
      final original = await seed(vehicle);
      await mount(tester, vehicle, original: original);
      await _tap(tester, find.byKey(const ValueKey('open-editor')));
      await _enter(tester, 'policyNumber', 'STALE-DRAFT');
      // Model two writes in a single SQLite timestamp unit without relying on a clock delay.
      final currentDetails = {
        ...original.details,
        'policyNumber': 'LATEST-EXTERNAL-EDIT',
      };
      await harness.database.customStatement(
        'UPDATE vehicle_obligations SET details_json = ? WHERE id = ?',
        [jsonEncode(currentDetails), original.id],
      );
      expect(
        (await store.get(vehicle.id, _type))!.updatedAt,
        original.updatedAt,
      );
      await _tap(tester, find.byKey(const ValueKey('insurance-editor-save')));
      expect(
        (await store.get(vehicle.id, _type))!.details['policyNumber'],
        'LATEST-EXTERNAL-EDIT',
      );
      expect(find.textContaining('mientras editabas'), findsOneWidget);
      expect(store.saveCalls, 0);
    },
  );

  testWidgets(
    'deleted original vehicle cannot be recreated by an open editor',
    (tester) async {
      final vehicle = await car();
      final original = await seed(vehicle);
      await mount(tester, vehicle, original: original);
      await _tap(tester, find.byKey(const ValueKey('open-editor')));
      await harness.repository.deleteVehicle(vehicle.id);
      await _tap(tester, find.byKey(const ValueKey('insurance-editor-save')));
      expect(
        find.text('Este veh\u00edculo ya no est\u00e1 disponible.'),
        findsOneWidget,
      );
      expect(await store.get(vehicle.id, _type), isNull);
      expect(await harness.repository.getVehicle(vehicle.id), isNull);
    },
  );

  testWidgets(
    'pending save disables second submission until original write completes',
    (tester) async {
      final vehicle = await car();
      final original = await seed(vehicle);
      await mount(tester, vehicle, original: original);
      await _tap(tester, find.byKey(const ValueKey('open-editor')));
      store.hold = Completer<void>();
      final button = find.byKey(const ValueKey('insurance-editor-save'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await _frames(tester);
      expect(store.saveCalls, 1);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.tap(button);
      await _frames(tester);
      expect(store.saveCalls, 1);
      store.finishPending();
      await tester.pumpAndSettle();
      final saved = (await store.get(vehicle.id, _type))!;
      for (final entry in original.details.entries) {
        expect(saved.details[entry.key], entry.value);
      }
    },
  );

  testWidgets(
    'insurer change asks confirmation and retains manual contacts, dates and unrelated details',
    (tester) async {
      final vehicle = await car();
      final original = await seed(
        vehicle,
        details: const {
          'providerId': 'alpha',
          'providerName': 'Alfa Seguros',
          'policyNumber': _secretPolicy,
          'assistancePhone': '#111',
          'towPhone': '6011112222',
          'designatedDriverPhone': '3001112222',
          'legacyPrivateNote': 'retained',
        },
      );
      await mount(tester, vehicle, original: original);
      await _tap(tester, find.byKey(const ValueKey('open-editor')));
      await _tap(
        tester,
        find.byKey(const ValueKey('insurance-editor-insurer')),
      );
      await _tap(tester, find.text('Beta Seguros'));
      await _tap(tester, find.byKey(const ValueKey('insurance-editor-save')));
      expect(find.text('Cambiar aseguradora'), findsOneWidget);
      await _tap(tester, find.text('Revisar'));
      expect((await store.get(vehicle.id, _type))!.details, original.details);
      await _tap(tester, find.byKey(const ValueKey('insurance-editor-save')));
      await _tap(tester, find.text('Guardar cambios'));
      final saved = (await store.get(vehicle.id, _type))!;
      expect(saved.details['providerId'], 'beta');
      for (final key in [
        'policyNumber',
        'assistancePhone',
        'towPhone',
        'designatedDriverPhone',
        'legacyPrivateNote',
      ]) {
        expect(saved.details[key], original.details[key], reason: key);
      }
      expect(saved.startDate, original.startDate);
      expect(saved.dueDate, original.dueDate);
      expect(documentReads, 0);
    },
  );

  testWidgets(
    'explicit clearing removes only that custom phone while unchanged legacy extension survives',
    (tester) async {
      final vehicle = await car();
      final original = await seed(
        vehicle,
        details: const {
          'providerName': 'Alfa Seguros',
          'assistancePhone': '#111',
          'towPhone': '6011112222 ext. 3',
          'designatedDriverPhone': '3001112222',
        },
      );
      await mount(tester, vehicle, original: original);
      await _tap(tester, find.byKey(const ValueKey('open-editor')));
      await _enter(tester, 'assistancePhone', '');
      await _tap(tester, find.byKey(const ValueKey('insurance-editor-save')));
      final saved = (await store.get(vehicle.id, _type))!;
      // Existing obligation encoding removes empty values rather than storing them.
      expect(saved.details.containsKey('assistancePhone'), isFalse);
      expect(saved.details['towPhone'], original.details['towPhone']);
      expect(
        saved.details['designatedDriverPhone'],
        original.details['designatedDriverPhone'],
      );
      expect(saved.dueDate, original.dueDate);
    },
  );

  testWidgets(
    'exact accent-insensitive legacy alias gains canonical provider ID',
    (tester) async {
      final vehicle = await car();
      final original = await seed(
        vehicle,
        details: const {'providerName': 'ALFA HISTORICA'},
      );
      await mount(tester, vehicle, original: original);
      await _tap(tester, find.byKey(const ValueKey('open-editor')));
      await _tap(tester, find.byKey(const ValueKey('insurance-editor-save')));
      final saved = (await store.get(vehicle.id, _type))!;
      expect(saved.details['providerId'], 'alpha');
      expect(saved.details['providerName'], 'ALFA HISTORICA');
    },
  );

  testWidgets(
    'unrecognized historical ID is repaired only by an exact known alias',
    (tester) async {
      final vehicle = await car();
      final original = await seed(
        vehicle,
        details: const {
          'providerId': 'retired-alpha-id',
          'providerName': 'ALFA HISTORICA',
        },
      );
      await mount(tester, vehicle, original: original);
      await _tap(tester, find.byKey(const ValueKey('open-editor')));
      await _tap(tester, find.byKey(const ValueKey('insurance-editor-save')));
      final saved = (await store.get(vehicle.id, _type))!;
      expect(saved.details['providerId'], 'alpha');
      expect(saved.details['providerName'], original.details['providerName']);
    },
  );

  testWidgets(
    'unavailable directory does not block saving existing manual policy',
    (tester) async {
      final vehicle = await car();
      final original = await seed(vehicle);
      await mount(
        tester,
        vehicle,
        original: original,
        loadDirectory: () async =>
            throw StateError('fixture directory unavailable'),
      );
      await _tap(tester, find.byKey(const ValueKey('open-editor')));
      await _enter(tester, 'policyNumber', 'LOCAL-WITHOUT-DIRECTORY');
      await _tap(tester, find.byKey(const ValueKey('insurance-editor-save')));
      final saved = (await store.get(vehicle.id, _type))!;
      expect(saved.details['providerId'], original.details['providerId']);
      expect(saved.details['policyNumber'], 'LOCAL-WITHOUT-DIRECTORY');
      expect(saved.startDate, original.startDate);
      expect(saved.dueDate, original.dueDate);
    },
  );

  testWidgets(
    'policy editing cannot replace or remove an existing encrypted PDF',
    (tester) async {
      final vehicle = await car();
      final original = await seed(vehicle);
      late WalletDocument document;
      await tester.runAsync(() async {
        final file = File('${harness.documentRoot.path}/insurance-fixture.pdf');
        await file.writeAsString('%PDF-1.4\n% fictional policy fixture\n%%EOF');
        document = await harness.walletStore.saveDocument(
          owner: WalletOwner.vehicle(vehicle.id),
          type: WalletDocumentType.voluntaryInsurance,
          pdf: WalletDocumentInput(
            source: file,
            originalName: 'insurance-fixture.pdf',
            mimeType: 'application/pdf',
          ),
          isAuthorized: () => true,
        );
      });
      final encrypted = File(
        '${harness.documentRoot.path}/wallet_documents/${document.pdf!.encryptedRelativePath}',
      );
      final bytesBefore = await tester.runAsync(encrypted.readAsBytes);
      await mount(tester, vehicle, original: original);
      await _tap(tester, find.byKey(const ValueKey('open-editor')));
      await _enter(tester, 'policyNumber', 'UPDATED-NUMBER-NOT-A-PDF');
      await _tap(tester, find.byKey(const ValueKey('insurance-editor-save')));
      await tester.runAsync(() async {
        final after = await harness.walletStore.listDocuments(
          owner: WalletOwner.vehicle(vehicle.id),
        );
        expect(after.single.id, document.id);
        expect(
          after.single.pdf!.encryptedRelativePath,
          document.pdf!.encryptedRelativePath,
        );
        expect(await encrypted.readAsBytes(), bytesBefore);
      });
      expect(documentReads, 0);
    },
  );

  for (final throws in [false, true]) {
    testWidgets(
      'source open failure throws=$throws offers copy and retry without identifiers',
      (tester) async {
        final vehicle = await car();
        final original = await seed(vehicle);
        launcher.failNext = !throws;
        launcher.throwNext = throws;
        await mount(tester, vehicle, original: original);
        await _tap(tester, find.byKey(const ValueKey('open-directory')));
        expect(launcher.urls, isEmpty);
        await _tap(tester, find.text('Alfa Seguros').last);
        expect(launcher.urls, isEmpty);
        await _tap(tester, find.text('Fuente del directorio'));
        expect(find.text('No pudimos abrir este canal'), findsOneWidget);
        await _tap(tester, find.text('Copiar'));
        expect(clipboard, ['https://alpha.example/evidence']);
        await _tap(tester, find.text('Reintentar'));
        expect(launcher.urls, [
          'https://alpha.example/evidence',
          'https://alpha.example/evidence',
        ]);
        for (final url in launcher.urls) {
          expect(url, isNot(contains(vehicle.plate)));
          expect(url, isNot(contains(_secretPolicy)));
        }
      },
    );
  }

  testWidgets('channel evidence has a distinct explicit action', (
    tester,
  ) async {
    final vehicle = await car();
    await mount(tester, vehicle);
    await _tap(tester, find.byKey(const ValueKey('open-directory')));
    await _tap(tester, find.text('Alfa Seguros').last);
    await _tap(tester, find.byTooltip('Ver fuente del canal').first);
    expect(launcher.urls, [_assistance.sourceUrl]);
    expect(launcher.phones, isEmpty);
  });

  for (final key in ['assistancePhone', 'towPhone', 'designatedDriverPhone']) {
    testWidgets(
      'custom $key uses legacy call key and shows old failure message with retry',
      (tester) async {
        final vehicle = await car();
        final original = await seed(
          vehicle,
          details: {'providerName': 'Personal', key: '#555'},
        );
        launcher.failNext = true;
        await mount(tester, vehicle, original: original);
        await _tap(tester, find.byKey(const ValueKey('open-assistance')));
        expect(launcher.phones, isEmpty);
        await _tap(tester, find.byKey(ValueKey('call-$key')));
        expect(find.text('No pudimos iniciar la llamada.'), findsOneWidget);
        await _tap(tester, find.text('Reintentar'));
        expect(launcher.phones, ['#555', '#555']);
        expect(launcher.urls, isEmpty);
      },
    );
  }

  testWidgets(
    'verified WhatsApp opens only its number and unverified channel never opens',
    (tester) async {
      final vehicle = await car();
      await mount(tester, vehicle);
      await _tap(tester, find.byKey(const ValueKey('open-unverified')));
      expect(launcher.urls, isEmpty);
      expect(launcher.phones, isEmpty);
      await _tap(tester, find.byKey(const ValueKey('open-whatsapp')));
      expect(launcher.urls, ['https://wa.me/573001234567']);
      final uri = Uri.parse(launcher.urls.single);
      expect(uri.queryParameters, isEmpty);
      expect(uri.fragment, isEmpty);
    },
  );

  testWidgets(
    'clipboard failure remains an error and does not launch a channel',
    (tester) async {
      final vehicle = await car();
      final original = await seed(vehicle);
      clipboardFails = true;
      await mount(tester, vehicle, original: original);
      await _tap(tester, find.byKey(const ValueKey('open-assistance')));
      await _tap(tester, find.byTooltip('Copiar n\u00famero de p\u00f3liza'));
      expect(find.text('No se pudo copiar. Intenta de nuevo.'), findsOneWidget);
      expect(clipboard, isEmpty);
      expect(launcher.urls, isEmpty);
      expect(launcher.phones, isEmpty);
    },
  );

  testWidgets('public quote entry remains inactive without both dev gates', (
    tester,
  ) async {
    final vehicle = await car();
    await mount(tester, vehicle);
    if (insuranceQuoteDemoAvailable) return;
    await _tap(tester, find.byKey(const ValueKey('open-demo')));
    expect(find.byType(InsuranceQuoteDemoSheet), findsNothing);
    expect(launcher.urls, isEmpty);
    expect(launcher.phones, isEmpty);
  });

  testWidgets(
    'pending and cancelled authentication never read or expose policy documents',
    (tester) async {
      final vehicle = await car();
      final original = await seed(vehicle);
      authenticator.pending = Completer<WalletAuthenticationResult>();
      await mount(tester, vehicle, original: original);
      await _tap(tester, find.byKey(const ValueKey('open-documents')));
      expect(authenticator.calls, 1);
      expect(documentReads, 0);
      expect(find.text(_secretPolicy), findsNothing);
      expect(find.text('Mi p\u00f3liza y documentos'), findsNothing);
      authenticator.pending!.complete(WalletAuthenticationResult.cancelled);
      await tester.pumpAndSettle();
      expect(session.accessAllowed, isFalse);
      expect(documentReads, 0);
      expect(find.text('No se pudo desbloquear Documentos.'), findsOneWidget);
      expect(launcher.urls, isEmpty);
      expect(clipboard, isEmpty);
    },
  );

  testWidgets('secure window failure prevents document reads and private UI', (
    tester,
  ) async {
    final vehicle = await car();
    final original = await seed(vehicle);
    platform.failEnable = true;
    await mount(tester, vehicle, original: original);
    await _tap(tester, find.byKey(const ValueKey('open-documents')));
    expect(
      find.textContaining('No se pudo abrir la billetera protegida.'),
      findsOneWidget,
    );
    expect(find.text(_secretPolicy), findsNothing);
    expect(documentReads, 0);
    expect(session.accessAllowed, isFalse);
  });

  testWidgets(
    'authentication result cannot reveal wallet over a different active route',
    (tester) async {
      final vehicle = await car();
      final original = await seed(vehicle);
      authenticator.pending = Completer<WalletAuthenticationResult>();
      await mount(tester, vehicle, original: original);
      await _tap(tester, find.byKey(const ValueKey('open-documents')));
      final navigator = Navigator.of(tester.element(find.byType(_SheetProbe)));
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                const Scaffold(body: Text('Otro m\u00f3dulo activo')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      authenticator.pending!.complete(WalletAuthenticationResult.success);
      await tester.pumpAndSettle();
      expect(find.text('Otro m\u00f3dulo activo'), findsOneWidget);
      expect(find.text(_secretPolicy), findsNothing);
      expect(find.text('Mi p\u00f3liza y documentos'), findsNothing);
      expect(documentReads, 0);
      expect(session.accessAllowed, isFalse);
    },
  );

  testWidgets(
    'locking hides policy metadata from paint hit tests and semantics immediately',
    (tester) async {
      final vehicle = await car();
      final original = await seed(vehicle);
      await mount(tester, vehicle, original: original);
      final semantics = tester.ensureSemantics();
      try {
        await _tap(tester, find.byKey(const ValueKey('open-documents')));
        expect(platform.secure, isTrue);
        expect(find.text(_secretPolicy), findsOneWidget);
        expect(documentReads, greaterThan(0));
        session.lock();
        await tester.pump();
        expect(find.text('Documentos bloqueados'), findsOneWidget);
        expect(find.text(_secretPolicy), findsNothing);
        expect(
          find.byTooltip('Copiar n\u00famero de p\u00f3liza').hitTestable(),
          findsNothing,
        );
        expect(find.bySemanticsLabel(RegExp(_secretPolicy)), findsNothing);
        expect(
          platform.secure,
          isTrue,
          reason: 'Keep screen protected while the locked sheet is mounted.',
        );
        await _tap(tester, find.text('Cerrar').last);
        await tester.pumpAndSettle();
        expect(session.accessAllowed, isFalse);
        expect(platform.secure, isFalse);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('reminder without a due date is pending, not active', (
    tester,
  ) async {
    final vehicle = await car();
    final original = await VehicleObligationStore(harness.database).upsert(
      vehicleId: vehicle.id,
      type: _type,
      reminderEnabled: true,
      details: const {'providerName': 'SURA'},
    );
    await mount(tester, vehicle, original: original);
    await _tap(tester, find.byKey(const ValueKey('open-documents')));
    expect(find.text('Pendiente de fecha'), findsOneWidget);
    expect(find.text('Activado'), findsNothing);
  });

  testWidgets('nested policy editor also hides drafts when the wallet locks', (
    tester,
  ) async {
    final vehicle = await car();
    final original = await seed(vehicle);
    await mount(tester, vehicle, original: original);
    await _tap(tester, find.byKey(const ValueKey('open-documents')));
    await _tap(tester, find.text('Editar datos de p\u00f3liza'));
    await _enter(tester, 'policyNumber', 'PRIVATE-NESTED-DRAFT');
    session.lock();
    await tester.pump();
    expect(find.text('PRIVATE-NESTED-DRAFT'), findsNothing);
    expect(
      find.byKey(const ValueKey('insurance-editor-policyNumber')).hitTestable(),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('insurance-editor-save')).hitTestable(),
      findsNothing,
    );
    expect(
      (await store.get(vehicle.id, _type))!.details['policyNumber'],
      _secretPolicy,
    );
    expect(platform.secure, isTrue);
  });

  testWidgets(
    'assistance is an opaque full-screen route hiding the promotional background',
    (tester) async {
      final vehicle = await car();
      final original = await seed(vehicle);
      await mount(tester, vehicle, original: original);
      expect(find.text('PROMOTIONAL-BACKGROUND-FIXTURE'), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('open-assistance')));
      final title = find.text('Necesito asistencia');
      expect(title, findsOneWidget);
      final route = ModalRoute.of(tester.element(title))!;
      expect(route.opaque, isTrue);
      expect((route as MaterialPageRoute<void>).fullscreenDialog, isTrue);
      expect(find.text('PROMOTIONAL-BACKGROUND-FIXTURE'), findsNothing);
      expect(
        find.text('PROMOTIONAL-BACKGROUND-FIXTURE', skipOffstage: false),
        findsOneWidget,
        reason: 'The previous module is preserved for return, not painted under a scrim.',
      );
      expect(launcher.urls, isEmpty);
      expect(launcher.phones, isEmpty);
      await _tap(tester, find.byTooltip('Cerrar'));
      expect(find.text('PROMOTIONAL-BACKGROUND-FIXTURE'), findsOneWidget);
    },
  );

  testWidgets(
    'official assistance precedes private contacts and keeps service evidence scoped',
    (tester) async {
      final vehicle = await car();
      final original = await seed(
        vehicle,
        details: const {
          'providerId': 'alpha',
          'providerName': 'Alfa Seguros',
          'towPhone': '#555',
        },
      );
      final insurer = InsuranceCompany(
        id: 'alpha',
        name: _alpha.name,
        legalName: _alpha.legalName,
        aliases: const [],
        website: _alpha.website,
        sourceUrl: _alpha.sourceUrl,
        reviewedAt: _alpha.reviewedAt,
        categories: const ['car'],
        channels: const [
          InsuranceChannel(
            id: 'official-driver',
            label: 'Asistencia oficial ficticia',
            kind: 'phone',
            value: '#123',
            purpose: 'assistance',
            sourceUrl: 'https://alpha.example/service',
            reviewedAt: '2026-09-14',
            verified: true,
            services: [InsuranceService.designatedDriver],
            conditions:
                'Solicitar con anticipaci\u00f3n; sujeto a la p\u00f3liza.',
          ),
        ],
      );
      await mount(
        tester,
        vehicle,
        original: original,
        loadDirectory: () async => InsuranceDirectory(entries: [insurer]),
      );
      await _tap(tester, find.byKey(const ValueKey('open-assistance')));
      expect(
        find.textContaining('Solicitudes: Conductor elegido'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Solicitar con anticipaci\u00f3n'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Gr\u00faa: canal espec\u00edfico sin confirmar'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Carro taller: canal espec\u00edfico sin confirmar',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Conductor elegido: canal espec\u00edfico sin confirmar',
        ),
        findsNothing,
      );
      expect(
        tester.getTopLeft(find.text('Canales oficiales')).dy,
        lessThan(tester.getTopLeft(find.text('Contactos particulares')).dy),
      );
      expect(launcher.phones, isEmpty);
      await _tap(tester, find.text('Asistencia oficial ficticia'));
      expect(launcher.phones, ['#123']);
      await _tap(tester, find.byKey(const ValueKey('call-towPhone')));
      expect(launcher.phones, ['#123', '#555']);
    },
  );

  for (final overlay in ['calendar', 'selector', 'manual']) {
    testWidgets(
      'protected $overlay excludes metadata and rejects stale result after lock',
      (tester) async {
        final vehicle = await car();
        final original = await seed(vehicle);
        await mount(tester, vehicle, original: original);
        final semantics = tester.ensureSemantics();
        try {
          await _tap(tester, find.byKey(const ValueKey('open-documents')));
          await _tap(tester, find.text('Editar datos de p\u00f3liza'));
          await _enter(tester, 'policyNumber', 'LOCKED-DRAFT-FIXTURE');
          if (overlay == 'calendar') {
            await _tap(
              tester,
              find.byKey(const ValueKey('insurance-editor-due')),
            );
          } else {
            await _tap(
              tester,
              find.byKey(const ValueKey('insurance-editor-insurer')),
            );
            if (overlay == 'manual') {
              await _tap(
                tester,
                find.byKey(const ValueKey('insurance-directory-manual')),
              );
              await tester.enterText(
                find.byKey(const ValueKey('insurance-editor-providerName')),
                'PRIVATE-INSURER-DRAFT',
              );
            }
          }
          session.lock();
          await tester.pump();
          expect(find.byType(CalendarDatePicker), findsNothing);
          expect(find.text('Directorio de aseguradoras'), findsNothing);
          expect(find.text('PRIVATE-INSURER-DRAFT'), findsNothing);
          expect(
            find.bySemanticsLabel(
              RegExp('PRIVATE-INSURER-DRAFT|LOCKED-DRAFT-FIXTURE'),
            ),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('insurance-editor-save')).hitTestable(),
            findsNothing,
          );
          expect(platform.secure, isTrue);
          expect(store.saveCalls, 0);
          expect(
            (await store.get(vehicle.id, _type))!.details,
            original.details,
          );
          await _tap(tester, find.text('Cerrar').last);
          expect(store.saveCalls, 0);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  for (final size in const [
    Size(360, 780),
    Size(360, 800),
    Size(390, 844),
    Size(412, 915),
    Size(430, 932),
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'policy refinement layout and fictional screenshots ${size.width}x${size.height} scale$scale',
        (tester) async {
          final vehicle = await car();
          final original = await seed(
            vehicle,
            details: const {
              'providerId': 'alpha',
              'providerName': 'Alfa Seguros',
              'policyNumber': 'FICTICIA-2026-01234567890123456789',
              'premiumMinorUnits': '120000050',
              'premiumPeriod': 'annual',
              'premiumCurrency': 'COP',
              'assistancePhone': '#123',
            },
          );
          await mount(
            tester,
            vehicle,
            original: original,
            size: size,
            scale: scale,
          );
          await _tap(tester, find.byKey(const ValueKey('open-documents')));
          expect(find.text('PROMOTIONAL-BACKGROUND-FIXTURE'), findsNothing);
          expect(
            ModalRoute.of(
              tester.element(find.text('Mi p\u00f3liza y documentos')),
            )!.opaque,
            isTrue,
          );
          expect(tester.takeException(), isNull);
          final copy = find.byTooltip('Copiar n\u00famero de p\u00f3liza');
          expect(tester.getSize(copy).height, greaterThanOrEqualTo(48));
          await _exportScreenshot(
            tester,
            'fictional-policy-${size.width.toInt()}x${size.height.toInt()}-scale-$scale',
          );
          await _tap(tester, find.text('Editar datos de p\u00f3liza'));
          expect(tester.takeException(), isNull);
          await _exportScreenshot(
            tester,
            'fictional-editor-${size.width.toInt()}x${size.height.toInt()}-scale-$scale',
          );
          await _tap(
            tester,
            find.byKey(const ValueKey('insurance-editor-due')),
          );
          expect(tester.takeException(), isNull);
          _expectCalendarTextFits(tester);
          await _exportScreenshot(
            tester,
            'fictional-calendar-${size.width.toInt()}x${size.height.toInt()}-scale-$scale',
          );
          await _tap(tester, find.text('Cancelar'));
          await _tap(
            tester,
            find.byKey(const ValueKey('insurance-editor-insurer')),
          );
          expect(tester.takeException(), isNull);
          final searchLabel = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.text('Buscar aseguradora'),
              matching: find.byType(RichText),
            ),
          );
          expect(searchLabel.didExceedMaxLines, isFalse);
          expect(
            searchLabel.getMaxIntrinsicHeight(searchLabel.size.width),
            lessThanOrEqualTo(searchLabel.size.height + .1),
          );
          await _exportScreenshot(
            tester,
            'fictional-selector-${size.width.toInt()}x${size.height.toInt()}-scale-$scale',
          );
          final selected = tester.widget<ListTile>(
            find.widgetWithText(ListTile, 'Alfa Seguros').last,
          );
          expect(selected.selected, isTrue);
          await _tap(tester, find.byTooltip('Cerrar').last);
          final save = find.byKey(const ValueKey('insurance-editor-save'));
          await tester.ensureVisible(save);
          await tester.pump();
          expect(save.hitTestable(), findsOneWidget);
          expect(tester.getSize(save).height, greaterThanOrEqualTo(48));
          expect(tester.takeException(), isNull);
          expect(store.saveCalls, 0);
        },
      );
    }
  }

  for (final size in const [
    Size(360, 780),
    Size(390, 844),
    Size(412, 915),
    Size(430, 932),
  ]) {
    testWidgets(
      'editor text x2 and keyboard stay scrollable and save is reachable at $size',
      (tester) async {
        final vehicle = await car();
        final original = await seed(vehicle);
        await mount(
          tester,
          vehicle,
          original: original,
          size: size,
          scale: 2,
          keyboard: 280,
        );
        await _tap(tester, find.byKey(const ValueKey('open-editor')));
        await _enter(tester, 'policyNumber', 'ACCESSIBLE-DRAFT');
        final save = find.byKey(const ValueKey('insurance-editor-save'));
        await tester.ensureVisible(save);
        await tester.pump();
        expect(save.hitTestable(), findsOneWidget);
        expect(tester.getSize(save).height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
        await _tap(tester, save);
        expect(
          (await store.get(vehicle.id, _type))!.details['policyNumber'],
          'ACCESSIBLE-DRAFT',
        );
      },
    );
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String field, String value) async {
  if (field == 'providerName') {
    await _tap(tester, find.byKey(const ValueKey('insurance-editor-insurer')));
    await _tap(
      tester,
      find.byKey(const ValueKey('insurance-directory-manual')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('insurance-editor-providerName')),
      value,
    );
    await _tap(tester, find.byKey(const ValueKey('insurance-manual-accept')));
    return;
  }
  if (field == 'start' || field == 'due') {
    await _tap(tester, find.byKey(ValueKey('insurance-editor-$field')));
    tester
        .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .onDateChanged(DateTime.parse(value));
    await tester.pump();
    await _tap(tester, find.text('Aceptar'));
    return;
  }
  if ([
        'assistancePhone',
        'towPhone',
        'designatedDriverPhone',
      ].contains(field) &&
      find.byKey(ValueKey('insurance-editor-$field')).evaluate().isEmpty) {
    await _tap(
      tester,
      find.byKey(const ValueKey('insurance-editor-phones-toggle')),
    );
  }
  final finder = find.byKey(ValueKey('insurance-editor-$field'));
  await tester.ensureVisible(finder);
  await tester.enterText(finder, value);
  await tester.pump();
}

Future<void> _exportScreenshot(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('INSURANCE_SCREENSHOTS')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('insurance-screenshot-boundary')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('../temp-insurance-policy-preview');
      await directory.create(recursive: true);
      await File('${directory.path}/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void _expectCalendarTextFits(WidgetTester tester) {
  final calendar = find.byType(CalendarDatePicker);
  final calendarRect = tester.getRect(calendar);
  final paragraphs = find.descendant(
    of: calendar,
    matching: find.byType(RichText),
  );
  var twoDigitDays = 0;
  for (final element in paragraphs.evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    final text = paragraph.text.toPlainText();
    if (!RegExp(r'^\d{1,2}$|\b\d{4}\b').hasMatch(text)) continue;
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason: 'Calendar text clipped: $text',
    );
    expect(
      paragraph.getMaxIntrinsicWidth(double.infinity),
      lessThanOrEqualTo(paragraph.size.width + .1),
      reason: 'Calendar text wrapped: $text',
    );
    final rect = paragraph.localToGlobal(Offset.zero) & paragraph.size;
    expect(
      calendarRect.inflate(.1).contains(rect.topLeft),
      isTrue,
      reason: text,
    );
    expect(
      calendarRect.inflate(.1).contains(rect.bottomRight),
      isTrue,
      reason: text,
    );
    if (RegExp(r'^\d{2}$').hasMatch(text)) {
      twoDigitDays++;
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: text.length),
      );
      expect(
        boxes,
        hasLength(1),
        reason: 'Both day digits must fit on one line: $text',
      );
      expect(
        boxes.single.bottom,
        lessThanOrEqualTo(paragraph.size.height + .1),
        reason: text,
      );
    }
  }
  expect(
    twoDigitDays,
    22,
    reason: 'January 10 through 31 must all render fully.',
  );
}

Future<void> _frames(WidgetTester tester) async {
  for (var frame = 0; frame < 12; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

class _SheetProbe extends ConsumerWidget {
  const _SheetProbe({required this.vehicle, required this.original});
  final VehicleProfile vehicle;
  final VehicleObligation? original;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(insuranceDirectoryProvider);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
            const Text('PROMOTIONAL-BACKGROUND-FIXTURE'),
            TextButton(
              key: const ValueKey('open-editor'),
              onPressed: () =>
                  showInsuranceEditor(context, ref, vehicle, original),
              child: const Text('Editor'),
            ),
            TextButton(
              key: const ValueKey('open-directory'),
              onPressed: () => showInsuranceDirectory(context, ref),
              child: const Text('Directorio'),
            ),
            TextButton(
              key: const ValueKey('open-assistance'),
              onPressed: () =>
                  showInsuranceAssistance(context, ref, vehicle, original),
              child: const Text('Asistencia'),
            ),
            TextButton(
              key: const ValueKey('open-documents'),
              onPressed: () => showInsuranceDocuments(context, ref, vehicle),
              child: const Text('Documentos'),
            ),
            TextButton(
              key: const ValueKey('open-whatsapp'),
              onPressed: () => openInsuranceChannel(context, ref, _whatsapp),
              child: const Text('WhatsApp'),
            ),
            TextButton(
              key: const ValueKey('open-unverified'),
              onPressed: () => openInsuranceChannel(context, ref, _unverified),
              child: const Text('Pendiente'),
            ),
            TextButton(
              key: const ValueKey('open-demo'),
              onPressed: () => showInsuranceQuoteDemo(context, vehicle),
              child: const Text('Demo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlledStore extends VehicleObligationStore {
  _ControlledStore(super.database);
  var saveCalls = 0;
  var failSave = false;
  Completer<void>? hold;
  @override
  Future<VehicleObligation> upsert({
    required String vehicleId,
    required VehicleObligationType type,
    DateTime? startDate,
    DateTime? dueDate,
    Map<String, String> details = const {},
    bool reminderEnabled = true,
  }) async {
    saveCalls++;
    final wait = hold;
    if (wait != null) await wait.future;
    if (failSave) {
      throw StateError('fixture store failure, never display native internals');
    }
    return super.upsert(
      vehicleId: vehicleId,
      type: type,
      startDate: startDate,
      dueDate: dueDate,
      details: details,
      reminderEnabled: reminderEnabled,
    );
  }

  void finishPending() {
    final pending = hold;
    if (pending != null && !pending.isCompleted) pending.complete();
  }
}

class _Launcher implements ExternalLauncher {
  final phones = <String>[];
  final urls = <String>[];
  var failNext = false;
  var throwNext = false;
  bool _result() {
    if (throwNext) {
      throwNext = false;
      throw StateError('native fixture failure');
    }
    if (failNext) {
      failNext = false;
      return false;
    }
    return true;
  }

  @override
  Future<bool> callPhone(String phone) async {
    phones.add(phone);
    return _result();
  }

  @override
  Future<bool> openExternal(String uri) async {
    urls.add(uri);
    return _result();
  }
}

class _Authenticator implements WalletDeviceAuthenticator {
  var calls = 0;
  Completer<WalletAuthenticationResult>? pending;
  @override
  Future<bool> canAuthenticate() async => true;
  @override
  Future<WalletAuthenticationResult> authenticate() async {
    calls++;
    return pending == null
        ? WalletAuthenticationResult.success
        : await pending!.future;
  }

  void finishPending() {
    final result = pending;
    if (result != null && !result.isCompleted) {
      result.complete(WalletAuthenticationResult.cancelled);
    }
  }
}

class _ProtectedPreferences implements WalletSecurityPreferencesStore {
  WalletSecurityPreferences value = const WalletSecurityPreferences(
    protectionEnabled: true,
    offerSeen: true,
  );
  @override
  Future<WalletSecurityPreferences> read() async => value;
  @override
  Future<void> write(WalletSecurityPreferences preferences) async {
    value = preferences;
  }
}

class _SecurePlatform extends WalletPlatform {
  var secure = false;
  var failEnable = false;
  @override
  Future<void> setSecure(bool enabled) async {
    if (enabled && failEnable) {
      throw const WalletPlatformException('fixture-secure-window-failed');
    }
    secure = enabled;
  }
}
