import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/documents/application/wallet_providers.dart';
import 'package:picoradar/features/documents/data/wallet_models.dart';
import 'package:picoradar/features/documents/platform/wallet_platform.dart';
import 'package:picoradar/features/documents/presentation/documents_sheets.dart';
import 'package:picoradar/features/documents/presentation/documents_widgets.dart';
import 'package:picoradar/features/documents/presentation/wallet_actions.dart';
import 'package:picoradar/features/documents/presentation/wallet_viewer.dart';

import '../../../test_app_harness.dart';

void main() {
  test('only identity and driving or traffic licenses use two-sided flow', () {
    expect(WalletDocumentType.identityCard.supportsTwoSides, isTrue);
    expect(WalletDocumentType.driverLicense.supportsTwoSides, isTrue);
    expect(WalletDocumentType.trafficLicense.supportsTwoSides, isTrue);
    expect(WalletDocumentType.soat.supportsTwoSides, isFalse);
    expect(WalletDocumentType.other.supportsTwoSides, isFalse);
  });

  testWidgets(
    'scanner guides front then back through separate one-page scans',
    (tester) async {
      final harness = TestAppHarness();
      addTearDown(harness.dispose);
      final files = await tester.runAsync(
        () async => [
          await _png(harness.documentRoot, 'front.png'),
          await _png(harness.documentRoot, 'back.png'),
        ],
      );
      final scanner = _QueuedScanner(files!);
      await _pumpActions(tester, harness, scanner);

      await tester.tap(find.text('Agregar documento'));
      await _until(tester, find.text('Escanear'));
      await tester.tap(find.text('Escanear'));
      await _until(tester, find.text('Reverso del documento'));
      expect(scanner.maxPages, [1]);
      expect(find.text('Guardar solo frente'), findsOneWidget);

      await tester.tap(find.text('Capturar reverso'));
      await _untilEnabled(
        tester,
        find.byKey(const ValueKey('wallet-viewer-save')),
      );
      expect(scanner.maxPages, [1, 1]);
      await tester.tap(find.byKey(const ValueKey('wallet-viewer-save')));
      await _untilGone(tester, find.byType(WalletViewer));
      await _untilWalletIdle(tester);
      expect(scanner.deletedPaths, hasLength(2));
    },
  );

  testWidgets('front-only document offers side actions and whole deletion', (
    tester,
  ) async {
    final harness = TestAppHarness();
    addTearDown(harness.dispose);
    final document = WalletDocument(
      id: 'document',
      owner: const WalletOwner.driver('principal'),
      type: WalletDocumentType.identityCard,
      importedAt: DateTime(2026),
      front: const WalletFileRef(
        encryptedRelativePath: 'docs/document/front.prcf',
        originalName: 'front.png',
        mimeType: 'image/png',
      ),
    );
    await _pumpActions(
      tester,
      harness,
      _QueuedScanner(const []),
      menuDocument: document,
    );

    await tester.tap(find.text('Opciones del documento'));
    await _until(tester, find.text('Agregar reverso'));
    expect(find.text('Reemplazar frente'), findsOneWidget);
    expect(find.text('Eliminar documento completo'), findsOneWidget);
    expect(find.text('Reemplazar PDF'), findsNothing);
  });

  testWidgets('PDF document offers PDF replacement and whole deletion', (
    tester,
  ) async {
    final harness = TestAppHarness();
    addTearDown(harness.dispose);
    final document = WalletDocument(
      id: 'pdf-document',
      owner: const WalletOwner.driver('principal'),
      type: WalletDocumentType.driverLicense,
      importedAt: DateTime(2026),
      pdf: const WalletFileRef(
        encryptedRelativePath: 'docs/pdf-document/pdf.prcf',
        originalName: 'license.pdf',
        mimeType: 'application/pdf',
      ),
      metadata: const {'pdfPageCount': '2'},
    );
    await _pumpActions(
      tester,
      harness,
      _QueuedScanner(const []),
      menuDocument: document,
    );

    await tester.tap(find.text('Opciones del documento'));
    await _until(tester, find.text('Reemplazar PDF'));
    expect(find.text('Eliminar documento completo'), findsOneWidget);
    expect(find.text('Reemplazar frente'), findsNothing);
    expect(find.text('Agregar reverso'), findsNothing);
  });

  testWidgets('single-sided image document does not offer a back action', (
    tester,
  ) async {
    final harness = TestAppHarness();
    addTearDown(harness.dispose);
    final document = WalletDocument(
      id: 'other-document',
      owner: const WalletOwner.driver('principal'),
      type: WalletDocumentType.other,
      importedAt: DateTime(2026),
      front: const WalletFileRef(
        encryptedRelativePath: 'docs/other-document/front.prcf',
        originalName: 'other.png',
        mimeType: 'image/png',
      ),
    );
    await _pumpActions(
      tester,
      harness,
      _QueuedScanner(const []),
      menuDocument: document,
    );

    await tester.tap(find.text('Opciones del documento'));
    await _until(tester, find.text('Reemplazar frente'));
    expect(find.text('Agregar reverso'), findsNothing);
    expect(find.text('Reemplazar reverso'), findsNothing);
  });

  test('PDF status distinguishes one and two validated pages', () {
    WalletDocument pdf(String pages) => WalletDocument(
      id: 'pdf-$pages',
      owner: const WalletOwner.driver('principal'),
      type: WalletDocumentType.driverLicense,
      importedAt: DateTime(2026),
      pdf: const WalletFileRef(
        encryptedRelativePath: 'docs/pdf/pdf.prcf',
        originalName: 'license.pdf',
        mimeType: 'application/pdf',
      ),
      metadata: {'pdfPageCount': pages},
    );

    expect(walletDocumentStatus(pdf('1')), 'PDF · 1 página');
    expect(walletDocumentStatus(pdf('2')), 'PDF · 2 páginas');
  });
}

Future<void> _pumpActions(
  WidgetTester tester,
  TestAppHarness harness,
  WalletPlatform scanner, {
  WalletDocument? menuDocument,
}) async {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getTemporaryDirectory') {
          return harness.documentRoot.path;
        }
        return null;
      });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  await harness.pump(
    tester,
    childOverride: ProviderScope(
      overrides: [walletPlatformProvider.overrideWithValue(scanner)],
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => Column(
              children: [
                TextButton(
                  onPressed: () => WalletActions(context, ref).add(
                    const WalletOwner.driver('principal'),
                    WalletDocumentType.identityCard,
                    ownerLabel: 'Principal',
                  ),
                  child: const Text('Agregar documento'),
                ),
                TextButton(
                  onPressed: () async {
                    await ref.read(walletSessionProvider).unlock();
                    final document =
                        menuDocument ??
                        (await ref
                                .read(walletStoreProvider)
                                .listDocuments(
                                  owner: const WalletOwner.driver('principal'),
                                ))
                            .single;
                    if (context.mounted) {
                      await showWalletDocumentMenu(
                        context,
                        ref,
                        document,
                        ownerLabel: 'Principal',
                      );
                    }
                  },
                  child: const Text('Opciones del documento'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Future<File> _png(Directory root, String name) async {
  final file = File('${root.path}/$name');
  await file.writeAsBytes(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8A'
      'AQUBAScY42YAAAAASUVORK5CYII=',
    ),
  );
  return file;
}

Future<void> _until(WidgetTester tester, Finder target) async {
  for (var attempt = 0; attempt < 300 && target.evaluate().isEmpty; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  if (target.evaluate().isEmpty) {
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data)
        .whereType<String>()
        .toList();
    fail('Target not found. Visible text: $texts');
  }
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _untilWalletIdle(WidgetTester tester) async {
  final container = ProviderScope.containerOf(
    tester.element(find.text('Agregar documento')),
  );
  for (
    var attempt = 0;
    attempt < 100 && container.read(walletOperationProvider).busy;
    attempt++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(container.read(walletOperationProvider).busy, isFalse);
}

Future<void> _untilEnabled(WidgetTester tester, Finder target) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    final widgets = target.evaluate();
    if (widgets.isNotEmpty &&
        tester.widget<FilledButton>(target).onPressed != null) {
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  fail('Save action did not become available.');
}

Future<void> _untilGone(WidgetTester tester, Finder target) async {
  for (
    var attempt = 0;
    attempt < 100 && target.evaluate().isNotEmpty;
    attempt++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  if (target.evaluate().isNotEmpty) {
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data)
        .whereType<String>()
        .toList();
    fail('Target remained visible. Visible text: $texts');
  }
  await tester.pump(const Duration(milliseconds: 200));
}

class _QueuedScanner extends WalletPlatform {
  _QueuedScanner(this.files);

  final List<File> files;
  final List<int> maxPages = [];
  final List<String> deletedPaths = [];
  var _next = 0;

  @override
  Future<List<WalletCaptureFile>?> scan({int maxPages = 2}) async {
    this.maxPages.add(maxPages);
    final file = files[_next++];
    return [
      WalletCaptureFile(
        file: file,
        originalName: file.uri.pathSegments.last,
        mimeType: 'image/png',
      ),
    ];
  }

  @override
  Future<void> deleteScanTemps(List<String> paths) async {
    deletedPaths.addAll(paths);
  }

  @override
  Future<void> setSecure(bool enabled) async {}
}
