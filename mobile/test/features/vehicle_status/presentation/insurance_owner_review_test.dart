import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/shell/app_shell.dart' show AppTab;
import 'package:picoradar/app/theme/app_theme.dart';
import 'package:picoradar/core/design_system/navigation.dart';
import 'package:picoradar/features/documents/application/wallet_providers.dart';
import 'package:picoradar/features/documents/application/wallet_session.dart';
import 'package:picoradar/features/documents/data/wallet_models.dart';
import 'package:picoradar/features/documents/platform/wallet_platform.dart';
import 'package:picoradar/features/documents/presentation/documents_sheets.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/garage/presentation/vehicle_plate_badge.dart';
import 'package:picoradar/features/onboarding/data/registration_city_catalog.dart';
import 'package:picoradar/features/vehicle_status/data/insurance_directory.dart';
import 'package:picoradar/features/vehicle_status/domain/vehicle_obligation.dart';
import 'package:picoradar/features/vehicle_status/platform/external_launcher.dart';
import 'package:picoradar/features/vehicle_status/presentation/insurance_owner_content.dart';
import 'package:picoradar/features/visual_assets/data/visual_asset_catalogs.dart';

import '../../../plate_test_fonts.dart';
import '../../../test_app_harness.dart';

final _date = DateTime(2026, 9, 13);
final _car = VehicleProfile(
  id: 'review-car',
  plate: 'BOG127',
  nickname: 'Carro de prueba',
  kind: VehicleKind.car,
  serviceType: VehicleServiceType.private,
  registrationCity: 'Bogotá',
  createdAt: _date,
  updatedAt: _date,
);
final _moto = VehicleProfile(
  id: 'review-moto',
  plate: 'ZVV73D',
  nickname: 'Moto de prueba',
  kind: VehicleKind.motorcycle,
  serviceType: VehicleServiceType.private,
  createdAt: _date,
  updatedAt: _date,
);
final _visuals = VehicleVisualCatalog.fromJson(
  jsonDecode(File(vehicleCatalogAssetPath).readAsStringSync())
      as Map<String, Object?>,
);
final _cities = RegistrationCityCatalog.fromJson(
  jsonDecode(File(registrationCityCatalogAssetPath).readAsStringSync())
      as Map<String, Object?>,
);
const _channelLabel = 'Conductor elegido y carro taller · según póliza';
final _directory = InsuranceDirectory(
  entries: [
    InsuranceCompany(
      id: 'review-company',
      name: 'Aseguradora de prueba',
      legalName: 'Entidad ficticia para pruebas',
      aliases: const [],
      website: 'https://example.invalid/',
      sourceUrl: 'https://example.invalid/contactos',
      reviewedAt: '2026-09-13',
      categories: const ['car', 'motorcycle'],
      channels: const [
        InsuranceChannel(
          id: 'review-wa',
          label: _channelLabel,
          kind: 'whatsapp',
          value: '573000000000',
          purpose: 'assistance',
          sourceUrl: 'https://example.invalid/contactos',
          reviewedAt: '2026-09-13',
          verified: true,
        ),
      ],
    ),
  ],
);

VehicleObligation _policy(String id, {String? customName}) => VehicleObligation(
  id: '$id:insurance',
  vehicleId: id,
  type: VehicleObligationType.insurance,
  reminderEnabled: false,
  createdAt: _date,
  updatedAt: _date,
  details: {
    if (customName == null) 'providerId': 'review-company',
    'providerName': customName ?? 'Aseguradora de prueba',
    'policyNumber': 'FICTICIO-$id',
  },
);

void main() {
  setUpAll(loadPlateTestFonts);

  testWidgets('two line insurer stays inside its header and above contacts', (
    tester,
  ) async {
    await _pump(
      tester,
      size: const Size(360, 780),
      customCompany: 'Seguros de automóviles de Colombia',
    );
    final edit = find.byKey(const ValueKey('insurance-edit'));
    final bounds = tester.getRect(edit);
    for (final element
        in find
            .descendant(of: edit, matching: find.byType(RichText))
            .evaluate()) {
      final paragraph = element.renderObject! as RenderParagraph;
      for (final glyph in paragraph.getBoxesForSelection(
        TextSelection(
          baseOffset: 0,
          extentOffset: paragraph.text.toPlainText().length,
        ),
      )) {
        expect(
          paragraph.localToGlobal(Offset(glyph.left, glyph.top)).dy,
          greaterThanOrEqualTo(bounds.top - .5),
        );
        expect(
          paragraph.localToGlobal(Offset(glyph.right, glyph.bottom)).dy,
          lessThanOrEqualTo(bounds.bottom + .5),
        );
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('incoming vehicle ID synchronizes existing carousel and policy', (
    tester,
  ) async {
    final incoming = ValueNotifier<String?>(_car.id);
    addTearDown(incoming.dispose);
    await _pump(tester, incoming: incoming);
    final carousel = find.byKey(const ValueKey('insurance-vehicle-carousel'));
    final controller = tester.widget<PageView>(carousel).controller!;
    final container = ProviderScope.containerOf(
      tester.element(find.byType(InsuranceOwnerScreen)),
    );
    expect(controller.page, closeTo(0, .001));

    incoming.value = _moto.id;
    await tester.pumpAndSettle();

    expect(tester.widget<PageView>(carousel).controller, same(controller));
    expect(controller.page, closeTo(1, .001));
    _expectFocus(tester, _moto);
    expect((await container.read(activeVehicleProvider.future))?.id, _car.id);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('insurance-assistance')));
    await tester.pumpAndSettle();
    expect(find.text('FICTICIO-${_moto.id}'), findsOneWidget);
    expect(find.text('FICTICIO-${_car.id}'), findsNothing);
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();

    incoming.value = _car.id;
    await tester.pumpAndSettle();
    expect(controller.page, closeTo(0, .001));
    _expectFocus(tester, _car);
  });

  testWidgets('selection and resizing keep the single home carousel mounted', (
    tester,
  ) async {
    await _pump(tester, preview: true, scale: 2, size: const Size(360, 780));
    final carousel = find.byKey(const ValueKey('insurance-vehicle-carousel'));
    final controller = tester.widget<PageView>(carousel).controller!;
    expect(controller.page, closeTo(0, .001));
    await tester.tap(find.byKey(const ValueKey('insurance-vehicle-selector')));
    await tester.pumpAndSettle();
    expect(controller.hasClients, isTrue);
    await tester.tap(find.text(_moto.nickname!).last);
    await tester.pumpAndSettle();
    expect(tester.widget<PageView>(carousel).controller, same(controller));
    expect(controller.page, closeTo(1, .001));
    _expectFocus(tester, _moto);
    for (final size in const [Size(430, 932), Size(360, 780)]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(tester.widget<PageView>(carousel).controller, same(controller));
      expect(controller.hasClients, isTrue);
      expect(controller.page, closeTo(1, .001));
      _expectFocus(tester, _moto);
      expect(
        find.byKey(const ValueKey('insurance-policy-panel')),
        findsOneWidget,
      );
      expect(find.byType(TabBar), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets(
      'documents entry survives missing policy metadata text $scale',
      (tester) async {
        final wallet = _WalletFixture();
        await _pump(tester, configured: false, scale: scale, wallet: wallet);
        final entry = find.byKey(const ValueKey('insurance-documents'));
        expect(entry.hitTestable(), findsOneWidget);
        final label = find.descendant(
          of: entry,
          matching: find.text('Póliza y documentos'),
        );
        final tooltip = find.byTooltip('Póliza y documentos');
        expect(
          label.evaluate().isNotEmpty || tooltip.evaluate().isNotEmpty,
          isTrue,
          reason: 'The separate documents icon retains access to an existing Wallet PDF',
        );
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(_protectedDocumentsHeading(), findsOneWidget);
        expect(find.text('Copia guardada'), findsOneWidget);
        expect(wallet.reads, [WalletOwner.vehicle(_car.id)]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('vehicle tap without a policy opens its editor', (tester) async {
    await _pump(tester, configured: false);
    await tester.tap(find.byKey(ValueKey('insurance-vehicle-open-${_car.id}')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('insurance-editor-insurer')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('insurance-editor-providerName')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('insurance-editor-policyNumber')),
      findsOneWidget,
    );
    expect(find.byType(DocumentsSessionSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final result in [
    WalletAuthenticationResult.success,
    WalletAuthenticationResult.cancelled,
  ]) {
    testWidgets('vehicle policy tap protects documents until auth $result', (
      tester,
    ) async {
      final wallet = _WalletFixture();
      wallet.authenticator.pending = Completer<WalletAuthenticationResult>();
      await _pump(tester, wallet: wallet);
      await tester.tap(
        find.byKey(ValueKey('insurance-vehicle-open-${_car.id}')),
      );
      await tester.pumpAndSettle();
      expect(wallet.authenticator.calls, 1);
      expect(wallet.reads, isEmpty);
      expect(find.byType(DocumentsSessionSheet), findsNothing);
      expect(find.text('Copia guardada'), findsNothing);
      expect(
        find.byKey(const ValueKey('insurance-editor-policyNumber')),
        findsNothing,
      );
      wallet.authenticator.pending!.complete(result);
      await tester.pumpAndSettle();
      if (result == WalletAuthenticationResult.success) {
        expect(_protectedDocumentsHeading(), findsOneWidget);
        expect(find.text('FICTICIO-${_car.id}'), findsOneWidget);
        expect(find.text('FICTICIO-${_moto.id}'), findsNothing);
        expect(find.text('Copia guardada'), findsOneWidget);
        expect(wallet.reads, [WalletOwner.vehicle(_car.id)]);
        expect(wallet.platform.secure, isTrue);
      } else {
        expect(find.byType(DocumentsSessionSheet), findsNothing);
        expect(find.text('Copia guardada'), findsNothing);
        expect(wallet.reads, isEmpty);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final configured in [false, true]) {
    testWidgets(
      'swiping vehicles never opens editor or documents configured $configured',
      (tester) async {
        final wallet = _WalletFixture();
        await _pump(tester, configured: configured, wallet: wallet);
        final carousel = find.byKey(
          const ValueKey('insurance-vehicle-carousel'),
        );
        final controller = tester.widget<PageView>(carousel).controller!;
        final container = ProviderScope.containerOf(
          tester.element(find.byType(InsuranceOwnerScreen)),
        );
        for (final step in [(-300.0, _moto, 1.0), (300.0, _car, 0.0)]) {
          await tester.drag(carousel, Offset(step.$1, 0));
          await tester.pumpAndSettle();
          expect(
            tester.widget<PageView>(carousel).controller,
            same(controller),
          );
          expect(controller.page, closeTo(step.$3, .001));
          _expectFocus(tester, step.$2);
          expect(find.byType(BottomSheet), findsNothing);
          expect(find.byType(DocumentsSessionSheet), findsNothing);
          expect(
            find.byKey(const ValueKey('insurance-editor-policyNumber')),
            findsNothing,
          );
          expect(wallet.authenticator.calls, 0);
          expect(wallet.reads, isEmpty);
          expect(
            (await container.read(activeVehicleProvider.future))?.id,
            _car.id,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('WhatsApp shows scope before any external action', (
    tester,
  ) async {
    final launcher = _RecordingLauncher();
    await _pump(tester, launcher: launcher);
    await tester.tap(find.byKey(const ValueKey('insurance-whatsapp')));
    await tester.pumpAndSettle();

    expect(launcher.externalUrls, isEmpty);
    expect(launcher.phoneNumbers, isEmpty);
    expect(find.text('Necesito asistencia'), findsOneWidget);
    expect(find.text(_channelLabel), findsOneWidget);
    final tile = find.ancestor(
      of: find.text(_channelLabel),
      matching: find.byType(ListTile),
    );
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(launcher.externalUrls, ['https://wa.me/573000000000']);
    expect(launcher.phoneNumbers, isEmpty);
    expect(Uri.parse(launcher.externalUrls.single).query, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long custom company stays inside edit area above contacts', (
    tester,
  ) async {
    const longName =
        'Aseguradora particular para todos mis vehículos de transporte '
        'empresarial y familiar con asistencia integral en todo el territorio';
    await _pump(tester, size: const Size(360, 780), customCompany: longName);
    final edit = find.byKey(const ValueKey('insurance-edit'));
    final editRect = tester.getRect(edit);
    final callRect = tester.getRect(
      find.byKey(const ValueKey('insurance-call')),
    );
    final whatsRect = tester.getRect(
      find.byKey(const ValueKey('insurance-whatsapp')),
    );
    final semantics = tester.ensureSemantics();
    try {
      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(longName))),
        findsWidgets,
      );
    } finally {
      semantics.dispose();
    }
    for (final element
        in find
            .descendant(of: edit, matching: find.byType(RichText))
            .evaluate()) {
      final paragraph = element.renderObject! as RenderParagraph;
      expect(paragraph.didExceedMaxLines, isFalse);
      for (final box in paragraph.getBoxesForSelection(
        TextSelection(
          baseOffset: 0,
          extentOffset: paragraph.text.toPlainText().length,
        ),
      )) {
        final topLeft = paragraph.localToGlobal(Offset(box.left, box.top));
        final bottomRight = paragraph.localToGlobal(
          Offset(box.right, box.bottom),
        );
        expect(topLeft.dx, greaterThanOrEqualTo(editRect.left - .5));
        expect(topLeft.dy, greaterThanOrEqualTo(editRect.top - .5));
        expect(bottomRight.dx, lessThanOrEqualTo(editRect.right + .5));
        expect(bottomRight.dy, lessThanOrEqualTo(editRect.bottom + .5));
        expect(bottomRight.dy, lessThanOrEqualTo(callRect.top + .5));
        expect(bottomRight.dy, lessThanOrEqualTo(whatsRect.top + .5));
      }
    }
    expect(tester.takeException(), isNull);
  });
  for (final scale in [1.5, 2.0]) {
    testWidgets(
      'compact company label retains full accessible name scale $scale',
      (tester) async {
        const longName =
            'Aseguradora particular para mis vehículos familiares y empresariales';
        final semantics = tester.ensureSemantics();
        try {
          await _pump(
            tester,
            size: const Size(360, 780),
            scale: scale,
            customCompany: longName,
          );
          expect(
            find.bySemanticsLabel(RegExp(RegExp.escape(longName))),
            findsWidgets,
          );
          expect(
            find.byKey(const ValueKey('insurance-policy-panel')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('insurance-assistance')).hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}

Finder _protectedDocumentsHeading() => find.descendant(
  of: find.byType(DocumentsSessionSheet),
  matching: find.text('Mi póliza y documentos'),
);

void _expectFocus(WidgetTester tester, VehicleProfile vehicle) {
  expect(
    tester
        .widget<Text>(find.byKey(const ValueKey('insurance-vehicle-name')))
        .data,
    vehicle.nickname,
  );
  expect(
    tester
        .widget<VehiclePlateBadge>(
          find.descendant(
            of: find.byKey(const ValueKey('insurance-plate')),
            matching: find.byType(VehiclePlateBadge),
          ),
        )
        .vehicle
        .id,
    vehicle.id,
  );
}

class _RecordingLauncher implements ExternalLauncher {
  final externalUrls = <String>[];
  final phoneNumbers = <String>[];
  @override
  Future<bool> openExternal(String uri) async {
    externalUrls.add(uri);
    return true;
  }

  @override
  Future<bool> callPhone(String phone) async {
    phoneNumbers.add(phone);
    return true;
  }
}

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double scale = 1,
  bool configured = true,
  bool preview = false,
  String? customCompany,
  ValueNotifier<String?>? incoming,
  _RecordingLauncher? launcher,
  _WalletFixture? wallet,
}) async {
  final harness = TestAppHarness();
  addTearDown(harness.dispose);
  if (wallet != null) addTearDown(wallet.dispose);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(harness.database),
        walletStoreProvider.overrideWithValue(harness.walletStore),
        if (wallet != null) ...[
          walletSessionProvider.overrideWithValue(wallet.session),
          walletPlatformProvider.overrideWithValue(wallet.platform),
          walletScreenSecurityProvider.overrideWithValue(
            WalletScreenSecurity(wallet.platform),
          ),
          walletDocumentsProvider.overrideWith((ref, owner) async {
            final session = ref.watch(walletSessionProvider);
            if (!session.accessAllowed || !wallet.platform.secure) {
              throw StateError('Private metadata read before protection');
            }
            wallet.reads.add(owner);
            return [
              WalletDocument(
                id: '${owner.id}-policy-copy',
                owner: owner,
                type: WalletDocumentType.voluntaryInsurance,
                importedAt: _date,
                pdf: const WalletFileRef(
                  encryptedRelativePath: 'fixture/policy.enc',
                  originalName: 'fixture-policy.pdf',
                  mimeType: 'application/pdf',
                ),
              ),
            ];
          }),
        ],
        insurancePreviewProvider.overrideWithValue(preview),
        insuranceDirectoryProvider.overrideWith((ref) async => _directory),
        externalLauncherProvider.overrideWithValue(
          launcher ?? _RecordingLauncher(),
        ),
        vehicleListProvider.overrideWith((ref) async => [_car, _moto]),
        activeVehicleProvider.overrideWith((ref) async => _car),
        vehicleObligationProvider.overrideWith(
          (ref, key) async =>
              configured ? _policy(key.$1, customName: customCompany) : null,
        ),
        vehicleVisualCatalogProvider.overrideWithValue(
          AsyncValue.data(_visuals),
        ),
        registrationCityCatalogProvider.overrideWith((ref) async => _cities),
        vehicleVisualOverrideProvider.overrideWith((ref, id) async => null),
      ],
      child: MaterialApp(
        theme: buildPicoRadarTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            padding: const EdgeInsets.only(top: 24, bottom: 24),
            viewPadding: const EdgeInsets.only(top: 24, bottom: 24),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: incoming == null
              ? InsuranceOwnerScreen(vehicleId: _car.id)
              : ValueListenableBuilder<String?>(
                  valueListenable: incoming,
                  builder: (_, id, _) => InsuranceOwnerScreen(vehicleId: id),
                ),
          bottomNavigationBar: AppBottomNav(
            destinations: [
              for (final tab in AppTab.values)
                AppBottomNavDestination(
                  label: tab.label,
                  icon: tab.icon,
                  selectedIcon: tab.selectedIcon,
                  color: tab.color,
                  keyName: tab.name,
                ),
            ],
            currentIndex: AppTab.apps.index,
            onSelect: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _WalletFixture {
  final authenticator = _Authenticator();
  final platform = _SecurePlatform();
  final reads = <WalletOwner>[];
  late final session = WalletSession(
    authenticator: authenticator,
    preferences: _ProtectedPreferences(),
  );

  void dispose() {
    final pending = authenticator.pending;
    if (pending != null && !pending.isCompleted) {
      pending.complete(WalletAuthenticationResult.cancelled);
    }
    session.dispose();
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
  @override
  Future<void> setSecure(bool enabled) async {
    secure = enabled;
  }
}
