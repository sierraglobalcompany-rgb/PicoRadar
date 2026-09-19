import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/features/buy_sell/presentation/purchase_documents_screen.dart';
import 'package:picoradar/features/documents/application/wallet_providers.dart';
import 'package:picoradar/features/documents/application/wallet_session.dart';
import 'package:picoradar/features/documents/data/wallet_store.dart';
import 'package:picoradar/features/documents/platform/wallet_platform.dart';
import 'package:picoradar/features/documents/presentation/wallet_viewer.dart';
import 'package:picoradar/features/vehicle_status/platform/vehicle_document_gateway.dart';

const _owner = WalletOwner.preparation('purchase-fixture');
const _ownerLabel = 'Preparaci\u00f3n de prueba';
const _unlock = ValueKey('wallet-unlock');
const _retry = ValueKey('purchase-documents-retry');
const _loading = ValueKey('purchase-documents-loading');

void main() {
  testWidgets(
    'lock hides owner label and wipes an image delivered by a stale read',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final harness = _Harness(protected: true);
        harness.store.documents.add(_copy(WalletDocumentType.soat));
        final lateRead = Completer<Uint8List>();
        harness.store.pendingRead = lateRead;
        await harness.open(tester);
        final view = find.byKey(const ValueKey('purchase-view-soat'));
        await _until(tester, () => view.evaluate().isNotEmpty);
        await tester.tap(view);
        await _until(tester, () => harness.store.reads == 1);
        harness.session.lock();
        await tester.pumpAndSettle();
        expect(find.text('$_ownerLabel \u00b7 SOAT'), findsNothing);
        expect(find.text(_ownerLabel), findsNothing);
        expect(find.bySemanticsLabel(RegExp(_ownerLabel)), findsNothing);
        final bytes = _png();
        lateRead.complete(bytes);
        await _until(tester, () => bytes.every((byte) => byte == 0), io: true);
        expect(find.byType(RawImage), findsNothing);
        expect(harness.platform.secure, isTrue);
      } finally {
        semantics.dispose();
      }
    },
  );

  for (final type in [
    WalletDocumentType.trafficLicense,
    WalletDocumentType.soat,
  ]) {
    testWidgets(
      'legacy claim is resolved only by a real traffic copy: ${type.name}',
      (tester) async {
        final harness = _Harness(legacy: true);
        harness.store.documents.add(_copy(type));
        await harness.open(tester);
        await _until(
          tester,
          () => find.text('1 copia local').evaluate().isNotEmpty,
        );
        expect(
          find.byKey(const ValueKey('purchase-documents-legacy')),
          type == WalletDocumentType.trafficLicense
              ? findsNothing
              : findsOneWidget,
        );
      },
    );
  }

  testWidgets(
    'shell exit closes its root viewer and cannot recreate an off-route owner',
    (tester) async {
      final harness = _Harness(protected: true);
      harness.store.documents.add(_copy(WalletDocumentType.soat));
      await harness.open(tester);
      final view = find.byKey(const ValueKey('purchase-view-soat'));
      await _until(tester, () => view.evaluate().isNotEmpty);
      await tester.tap(view);
      await _until(tester, () => harness.store.reads == 1, io: true);
      harness.router.go('/other');
      await tester.pumpAndSettle();
      expect(find.byType(WalletViewer, skipOffstage: false), findsNothing);
      expect(harness.session.accessAllowed, isFalse);
      final ensures = harness.store.ensures;
      expect(await harness.session.unlock(), isTrue);
      await tester.pumpAndSettle();
      expect(harness.store.ensures, ensures);
      expect(harness.store.reads, 1);
      expect(find.text(_ownerLabel, skipOffstage: false), findsNothing);
    },
  );

  testWidgets(
    'stale root confirmation cannot delete after another visit unlocks',
    (tester) async {
      final harness = _Harness(protected: true);
      harness.store.documents.add(_copy(WalletDocumentType.soat));
      await harness.open(tester);
      final remove = find.byKey(const ValueKey('purchase-delete-soat'));
      await _until(tester, () => remove.evaluate().isNotEmpty);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AlertDialog, 'Eliminar copia'), findsOneWidget);
      harness.router.go('/other');
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog, skipOffstage: false), findsNothing);
      expect(find.text('Other route').hitTestable(), findsOneWidget);
      expect(harness.session.accessAllowed, isFalse);
      expect(harness.container!.read(walletOperationProvider).busy, isFalse);
      expect(await harness.session.unlock(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog, skipOffstage: false), findsNothing);
      expect(find.text('Other route').hitTestable(), findsOneWidget);
      expect(harness.store.deleted, isEmpty);
      expect(harness.store.documents.single.id, 'soat');
      expect(harness.store.documents.single.owner, _owner);
    },
  );

  testWidgets('legacy claim is pending import and never becomes a copy', (
    tester,
  ) async {
    final harness = _Harness(legacy: true);
    await harness.open(tester);
    await _until(
      tester,
      () => find.text('0 copias locales').evaluate().isNotEmpty,
    );
    expect(find.text('Copia pendiente de importar'), findsOneWidget);
    for (final type in [
      WalletDocumentType.trafficLicense,
      WalletDocumentType.soat,
      WalletDocumentType.rtm,
      WalletDocumentType.appraisal,
      WalletDocumentType.salePurchase,
      WalletDocumentType.other,
    ]) {
      await _expectRowStatus(tester, type, 'Sin copia');
    }
    expect(find.text('Garaje'), findsNothing);
    expect(harness.store.owners, everyElement(_owner));
    expect(harness.platform.secure, isTrue);
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(find.text('Abrir copias'), findsOneWidget);
    expect(harness.session.accessAllowed, isFalse);
    expect(harness.platform.secure, isFalse);
  });

  testWidgets('loading and sanitized error retry use real owner provider', (
    tester,
  ) async {
    final harness = _Harness();
    final pending = Completer<List<WalletDocument>>();
    harness.store.pending = pending;
    await harness.open(tester);
    await _until(tester, () => harness.store.owners.isNotEmpty);
    expect(find.byKey(_loading), findsOneWidget);
    pending.completeError(StateError('private filename must never be shown'));
    await _until(tester, () => find.byKey(_retry).evaluate().isNotEmpty);
    expect(find.text('No se pudieron cargar las copias.'), findsOneWidget);
    expect(find.textContaining('private filename'), findsNothing);
    harness.store.pending = null;
    await tester.tap(find.byKey(_retry));
    await _until(
      tester,
      () => find.text('0 copias locales').evaluate().isNotEmpty,
    );
  });

  testWidgets(
    'owner initialization failure retries without loading documents',
    (tester) async {
      final harness = _Harness()..store.failEnsure = true;
      await harness.open(tester);
      await _until(tester, () => find.byKey(_retry).evaluate().isNotEmpty);
      expect(
        find.text('No se pudo abrir esta preparaci\u00f3n.'),
        findsOneWidget,
      );
      expect(harness.store.owners, isEmpty);
      harness.store.failEnsure = false;
      await tester.tap(find.byKey(_retry));
      await _until(
        tester,
        () => find.text('0 copias locales').evaluate().isNotEmpty,
      );
    },
  );

  testWidgets('front back and PDF counts are truthful and owner isolated', (
    tester,
  ) async {
    final harness = _Harness();
    harness.store.documents.addAll([
      _copy(WalletDocumentType.trafficLicense, back: true),
      _copy(WalletDocumentType.soat, pdf: true),
      _copy(WalletDocumentType.rtm, pdf: true, pages: '4'),
      _copy(WalletDocumentType.appraisal),
      _copy(
        WalletDocumentType.other,
        owner: const WalletOwner.preparation('other'),
      ),
    ]);
    await harness.open(tester);
    await _until(
      tester,
      () => find.text('4 copias locales').evaluate().isNotEmpty,
    );
    for (final (type, status) in [
      (
        WalletDocumentType.trafficLicense,
        'Frente y reverso \u00b7 2 im\u00e1genes',
      ),
      (WalletDocumentType.soat, 'PDF guardado'),
      (WalletDocumentType.rtm, 'PDF \u00b7 4 p\u00e1ginas'),
      (WalletDocumentType.appraisal, 'Solo frente'),
      (WalletDocumentType.salePurchase, 'Sin copia'),
      (WalletDocumentType.other, 'Sin copia'),
    ]) {
      await _expectRowStatus(tester, type, status);
    }
  });

  testWidgets(
    'denied authentication exposes no owner and locked Back pops locally',
    (tester) async {
      final harness = _Harness(protected: true);
      harness.auth.result = WalletAuthenticationResult.cancelled;
      await harness.open(tester);
      await _until(
        tester,
        () => harness.auth.calls == 1 && !harness.session.busy,
      );
      expect(find.text(_ownerLabel), findsNothing);
      expect(harness.store.owners, isEmpty);
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(find.text('Abrir copias'), findsOneWidget);
      expect(harness.router.routeInformationProvider.value.uri.path, '/buy');
      expect(harness.session.accessAllowed, isFalse);
    },
  );

  testWidgets(
    'secure window acknowledgement precedes reads even with auth off',
    (tester) async {
      final harness = _Harness();
      final secure = Completer<void>();
      harness.platform.pending = secure;
      await harness.open(tester);
      await _until(tester, () => harness.session.accessAllowed);
      expect(harness.store.owners, isEmpty);
      expect(find.text(_ownerLabel), findsNothing);
      secure.complete();
      await _until(tester, () => find.text(_ownerLabel).evaluate().isNotEmpty);
      expect(harness.platform.secure, isTrue);
    },
  );

  testWidgets('secure acquisition failure stays closed and retries', (
    tester,
  ) async {
    final harness = _Harness()..platform.fail = true;
    await harness.open(tester);
    await _until(
      tester,
      () => find.textContaining('No se pudo proteger').evaluate().isNotEmpty,
    );
    expect(harness.store.owners, isEmpty);
    expect(find.text(_ownerLabel), findsNothing);
    harness.platform.fail = false;
    await tester.tap(find.byKey(_unlock));
    await _until(tester, () => find.text(_ownerLabel).evaluate().isNotEmpty);
  });

  testWidgets('background masks named visit until explicit authentication', (
    tester,
  ) async {
    final harness = _Harness(protected: true);
    await harness.open(tester);
    await _until(tester, () => find.text(_ownerLabel).evaluate().isNotEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(harness.session.accessAllowed, isFalse);
    expect(find.text(_ownerLabel), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text(_ownerLabel), findsNothing);
    await tester.tap(find.byKey(_unlock));
    await _until(tester, () => find.text(_ownerLabel).evaluate().isNotEmpty);
    expect(harness.auth.calls, 2);
  });

  testWidgets(
    'shell branch exit revokes visit and invalidates late authentication',
    (tester) async {
      final harness = _Harness(protected: true);
      final pending = Completer<WalletAuthenticationResult>();
      harness.auth.pending = pending;
      await harness.open(tester);
      await _until(tester, () => harness.auth.calls == 1);
      final epoch = harness.session.epoch;
      harness.router.go('/other');
      await tester.pump();
      pending.complete(WalletAuthenticationResult.success);
      await _until(tester, () => !harness.session.busy);
      expect(harness.session.isAuthorizedEpoch(epoch), isFalse);
      expect(harness.store.owners, isEmpty);
      expect(find.text(_ownerLabel), findsNothing);
    },
  );

  testWidgets(
    'viewer uses owner label and returning preserves this visit only',
    (tester) async {
      final harness = _Harness(protected: true);
      harness.store.documents.add(_copy(WalletDocumentType.soat));
      await harness.open(tester);
      final view = find.byKey(const ValueKey('purchase-view-soat'));
      await _until(tester, () => view.evaluate().isNotEmpty);
      await tester.tap(view);
      await _until(
        tester,
        () => find.byType(RawImage).evaluate().isNotEmpty,
        io: true,
      );
      expect(find.text('$_ownerLabel \u00b7 SOAT'), findsOneWidget);
      expect(harness.store.reads, 1);
      Navigator.of(tester.element(find.byType(WalletViewer))).pop();
      await tester.pumpAndSettle();
      expect(harness.session.accessAllowed, isTrue);
      expect(harness.auth.calls, 1);
      expect(harness.platform.secure, isTrue);
      expect(harness.store.purges, 1);
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(harness.session.accessAllowed, isFalse);
    },
  );

  testWidgets(
    'delete invalidates owner copies and keeps protected visit open',
    (tester) async {
      final harness = _Harness(protected: true);
      harness.store.documents.add(_copy(WalletDocumentType.soat));
      await harness.open(tester);
      final remove = find.byKey(const ValueKey('purchase-delete-soat'));
      await _until(tester, () => remove.evaluate().isNotEmpty);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar').last);
      await _until(
        tester,
        () => find.text('0 copias locales').evaluate().isNotEmpty,
      );
      expect(harness.store.deleted, ['soat']);
      expect(harness.session.accessAllowed, isTrue);
      expect(harness.auth.calls, 1);
    },
  );

  testWidgets(
    'scanner unavailability is explicit and import remains reachable',
    (tester) async {
      final harness = _Harness();
      await harness.open(tester);
      final add = find.byKey(const ValueKey('purchase-add-soat'));
      await _until(tester, () => add.evaluate().isNotEmpty);
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Escanear'));
      await tester.pumpAndSettle();
      final recovery = find.byType(AlertDialog);
      expect(recovery, findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.textContaining('C\u00f3digo: platform_failed'), findsOneWidget);
      expect(find.textContaining('scanner unavailable'), findsNothing);
      expect(harness.store.documents, isEmpty);
      expect(harness.session.accessAllowed, isTrue);
      await tester.tap(
        find.descendant(
          of: recovery,
          matching: find.widgetWithText(TextButton, 'Importar archivo'),
        ),
      );
      await _until(
        tester,
        () =>
            harness.gateway.picks == 1 &&
            !harness.container!.read(walletOperationProvider).busy,
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog, skipOffstage: false), findsNothing);
      expect(harness.store.documents, isEmpty);
      expect(harness.session.accessAllowed, isTrue);
    },
  );

  for (final staleResult in [false, true]) {
    testWidgets(
      staleResult
          ? 'late picker result cannot preview or save after leaving its visit'
          : 'real image import previews before save and cleans staged files',
      (tester) async {
        final root = Directory.systemTemp.createTempSync(
          'purchase-documents-test-',
        );
        const channel = MethodChannel('plugins.flutter.io/path_provider');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (_) async => root.path,
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          );
          if (root.existsSync()) root.deleteSync(recursive: true);
        });
        final original = File('${root.path}/original.png')
          ..writeAsBytesSync(_png());
        final harness = _Harness();
        harness.gateway.picked = PickedVehicleDocument(
          file: original,
          originalName: 'original.png',
          mimeType: 'image/png',
        );
        if (staleResult) {
          harness.gateway.pending = Completer<PickedVehicleDocument?>();
        }
        await harness.open(tester);
        final add = find.byKey(const ValueKey('purchase-add-soat'));
        await _until(tester, () => add.evaluate().isNotEmpty);
        await tester.tap(add);
        await tester.pumpAndSettle();
        await tester.runAsync(() => tester.tap(find.text('Importar archivo')));
        if (staleResult) {
          await _until(tester, () => harness.gateway.picks == 1);
          harness.router.go('/other');
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            harness.gateway.pending!.complete(harness.gateway.picked);
          });
          await _until(
            tester,
            () => !harness.container!.read(walletOperationProvider).busy,
            io: true,
          );
          expect(find.byType(WalletViewer, skipOffstage: false), findsNothing);
          expect(harness.store.savedOwner, isNull);
          expect(harness.store.documents, isEmpty);
          expect(Directory('${root.path}/wallet_pending').listSync(), isEmpty);
          expect(harness.gateway.clears, greaterThanOrEqualTo(2));
          return;
        }
        final save = find.byKey(const ValueKey('wallet-viewer-save'));
        await _until(
          tester,
          () =>
              save.evaluate().isNotEmpty &&
              tester.widget<FilledButton>(save).onPressed != null,
          io: true,
        );
        expect(find.text('$_ownerLabel \u00b7 SOAT'), findsOneWidget);
        expect(harness.store.savedOwner, isNull);
        await tester.tap(save);
        await _until(
          tester,
          () => !harness.container!.read(walletOperationProvider).busy,
          io: true,
        );
        expect(harness.store.savedOwner, _owner);
        expect(harness.store.savedBytes, _png());
        expect(harness.store.documents.single.type, WalletDocumentType.soat);
        expect(harness.gateway.clears, greaterThanOrEqualTo(2));
        expect(original.existsSync(), isTrue);
        final pending = Directory('${root.path}/wallet_pending');
        expect(pending.listSync(), isEmpty);
        expect(harness.session.accessAllowed, isTrue);
      },
    );
  }

  testWidgets(
    'narrow screen and enlarged text keep document actions accessible',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = _Harness(textScale: 2);
      await harness.open(tester);
      final add = find.byKey(const ValueKey('purchase-add-soat'));
      await _until(
        tester,
        () => find.text('0 copias locales').evaluate().isNotEmpty,
      );
      await tester.scrollUntilVisible(add, 150);
      await tester.pumpAndSettle();
      expect(add.hitTestable(), findsOneWidget);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(find.text('Importar archivo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _expectRowStatus(
  WidgetTester tester,
  WalletDocumentType type,
  String status,
) async {
  final row = find.byKey(ValueKey('purchase-document-${type.value}'));
  await tester.scrollUntilVisible(row, 150);
  expect(find.descendant(of: row, matching: find.text(status)), findsOneWidget);
}

Future<void> _until(
  WidgetTester tester,
  bool Function() condition, {
  bool io = false,
}) async {
  for (var frame = 0; frame < 100 && !condition(); frame++) {
    if (io) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(
    condition(),
    isTrue,
    reason: 'Document flow did not reach expected state',
  );
}

Uint8List _png() => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

WalletDocument _copy(
  WalletDocumentType type, {
  WalletOwner owner = _owner,
  bool back = false,
  bool pdf = false,
  String? pages,
}) => WalletDocument(
  id: type.value,
  owner: owner,
  type: type,
  importedAt: DateTime(2026, 9, 15),
  front: pdf ? null : _image,
  back: back ? _image : null,
  pdf: pdf
      ? const WalletFileRef(
          encryptedRelativePath: 'private/pdf',
          originalName: 'fixture.pdf',
          mimeType: 'application/pdf',
        )
      : null,
  metadata: {'pdfPageCount': ?pages},
);

const _image = WalletFileRef(
  encryptedRelativePath: 'private/image',
  originalName: 'fixture.png',
  mimeType: 'image/png',
);

class _Harness {
  _Harness({this.protected = false, this.legacy = false, this.textScale = 1});
  final bool protected;
  final bool legacy;
  final double textScale;
  final store = _Store();
  final platform = _Platform();
  final auth = _Authenticator();
  final gateway = _Gateway();
  ProviderContainer? container;
  late final session = WalletSession(
    authenticator: auth,
    preferences: _Preferences(protected),
  );
  late final router = GoRouter(
    initialLocation: '/buy',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => Scaffold(body: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/buy',
                builder: (context, state) => Scaffold(
                  body: Center(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          settings: const RouteSettings(
                            name: PurchaseDocumentsScreen.routeName,
                          ),
                          builder: (_) => PurchaseDocumentsScreen(
                            preparationId: _owner.id,
                            ownerLabel: _ownerLabel,
                            initialType: WalletDocumentType.soat,
                            legacyAttachmentClaim: legacy,
                          ),
                        ),
                      ),
                      child: const Text('Abrir copias'),
                    ),
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/other',
                builder: (_, _) => const Scaffold(body: Text('Other route')),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  Future<void> open(WidgetTester tester) async {
    addTearDown(() async {
      if (auth.pending case final pending? when !pending.isCompleted) {
        pending.complete(WalletAuthenticationResult.cancelled);
      }
      if (platform.pending case final pending? when !pending.isCompleted) {
        pending.complete();
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      router.dispose();
      session.dispose();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletSessionProvider.overrideWithValue(session),
          walletStoreProvider.overrideWithValue(store),
          walletPlatformProvider.overrideWithValue(platform),
          vehicleDocumentGatewayProvider.overrideWithValue(gateway),
          walletFileKeyProvider.overrideWithValue(
            () async => SecretKey(List.filled(32, 9)),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(
      tester.element(find.text('Abrir copias')),
    );
    await tester.tap(find.text('Abrir copias'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}

class _Store extends Fake implements WalletStore {
  bool exists = true;
  bool failEnsure = false;
  int reads = 0;
  int purges = 0;
  int ensures = 0;
  final documents = <WalletDocument>[];
  final owners = <WalletOwner?>[];
  final deleted = <String>[];
  Completer<List<WalletDocument>>? pending;
  Completer<Uint8List>? pendingRead;
  WalletOwner? savedOwner;
  Uint8List? savedBytes;
  @override
  Future<WalletMigrationReport> initialize() async =>
      const WalletMigrationReport();
  @override
  Future<bool> preparationExists(String id) async => exists;
  @override
  Future<WalletOwner> ensurePreparation(
    String id, {
    bool Function()? isAuthorized,
  }) async {
    expect(isAuthorized?.call(), isTrue);
    ensures++;
    if (failEnsure) throw StateError('Private initialization detail');
    return WalletOwner.preparation(id);
  }

  @override
  Future<List<WalletDocument>> listDocuments({WalletOwner? owner}) async {
    owners.add(owner);
    return pending == null ? List.of(documents) : await pending!.future;
  }

  @override
  Future<Uint8List> readDocumentBytes(
    WalletDocument document,
    WalletDocumentSide side,
  ) async {
    reads++;
    return pendingRead == null ? _png() : await pendingRead!.future;
  }

  @override
  Future<void> purgeViewerCache() async {
    purges++;
  }

  @override
  Future<void> deleteDocument(
    String id, {
    bool Function()? isAuthorized,
  }) async {
    expect(isAuthorized?.call(), isTrue);
    deleted.add(id);
    documents.removeWhere((document) => document.id == id);
  }

  @override
  Future<WalletDocument> saveDocument({
    required WalletOwner owner,
    required WalletDocumentType type,
    WalletDocumentInput? front,
    WalletDocumentInput? back,
    WalletDocumentInput? pdf,
    Map<String, String> metadata = const {},
    bool Function()? isAuthorized,
  }) async {
    expect(isAuthorized?.call(), isTrue);
    savedOwner = owner;
    savedBytes = await front!.source.readAsBytes();
    final copy = _copy(type, owner: owner);
    documents.add(copy);
    return copy;
  }
}

class _Authenticator implements WalletDeviceAuthenticator {
  int calls = 0;
  WalletAuthenticationResult result = WalletAuthenticationResult.success;
  Completer<WalletAuthenticationResult>? pending;
  @override
  Future<bool> canAuthenticate() async => true;
  @override
  Future<WalletAuthenticationResult> authenticate() async {
    calls++;
    return pending == null ? result : await pending!.future;
  }
}

class _Preferences implements WalletSecurityPreferencesStore {
  _Preferences(bool protected)
    : value = WalletSecurityPreferences(
        protectionEnabled: protected,
        offerSeen: true,
      );
  WalletSecurityPreferences value;
  @override
  Future<WalletSecurityPreferences> read() async => value;
  @override
  Future<void> write(WalletSecurityPreferences preferences) async {
    value = preferences;
  }
}

class _Platform extends WalletPlatform {
  bool secure = false;
  bool fail = false;
  Completer<void>? pending;
  @override
  Future<void> setSecure(bool enabled) async {
    if (enabled && pending != null) await pending!.future;
    if (enabled && fail) {
      throw const WalletPlatformException('secure unavailable');
    }
    secure = enabled;
  }

  @override
  Future<List<WalletCaptureFile>?> scan({int maxPages = 2}) async =>
      throw const WalletPlatformException('scanner unavailable');
}

class _Gateway implements VehicleDocumentGateway {
  PickedVehicleDocument? picked;
  Completer<PickedVehicleDocument?>? pending;
  int clears = 0;
  int picks = 0;
  @override
  Future<PickedVehicleDocument?> pickDocument() async {
    picks++;
    return pending == null ? picked : await pending!.future;
  }

  @override
  Future<void> clearTemporaryFiles() async {
    clears++;
  }

  @override
  Future<bool> openDocument(File file) async =>
      throw StateError('Private files must use the protected internal viewer');
}
