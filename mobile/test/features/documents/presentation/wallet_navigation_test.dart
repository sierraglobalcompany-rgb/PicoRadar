import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app.dart';
import 'package:picoradar/app/router/app_router.dart';
import 'package:picoradar/app/shell/app_shell.dart';
import 'package:picoradar/features/documents/application/wallet_providers.dart';
import 'package:picoradar/features/documents/data/wallet_store.dart';
import 'package:picoradar/features/documents/presentation/documents_screen.dart';
import 'package:picoradar/features/documents/presentation/documents_sheets.dart';
import 'package:picoradar/features/documents/presentation/wallet_actions.dart';
import 'package:picoradar/features/documents/presentation/wallet_viewer.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';

import '../../../test_app_harness.dart';

void main() {
  testWidgets('real shell retires root viewer and wipes a late private read', (
    tester,
  ) async {
    final harness = TestAppHarness();
    addTearDown(harness.dispose);
    final store = _DelayedViewerStore();
    await harness.pump(
      tester,
      childOverride: ProviderScope(
        overrides: [
          walletStoreProvider.overrideWithValue(store),
          walletDriversProvider.overrideWithValue(
            const AsyncValue.data(<WalletDriver>[]),
          ),
        ],
        child: const PicoRadarApp(),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppShell)),
    );
    final router = container.read(appRouterProvider);
    router.go('/apps/module/documentos');
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(DocumentsScreen));
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        builder: (_) => DocumentsSessionSheet(
          child: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => WalletActions(context, ref).view(
                WalletDocument(
                  id: 'copy',
                  owner: const WalletOwner.driver('principal'),
                  type: WalletDocumentType.identityCard,
                  importedAt: DateTime(2026),
                  front: const WalletFileRef(
                    encryptedRelativePath: 'private.prcf',
                    originalName: 'private.png',
                    mimeType: 'image/png',
                  ),
                ),
              ),
              child: const Text('View'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('View'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(WalletViewer), findsOneWidget);
    expect(store.reads, 1);
    router.go('/apps/module/seguro_asistencia');
    await tester.pumpAndSettle();
    expect(find.byType(WalletViewer, skipOffstage: false), findsNothing);
    expect(
      find.byType(DocumentsSessionSheet, skipOffstage: false),
      findsNothing,
    );
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    store.pending.complete(bytes);
    await tester.pumpAndSettle();
    expect(bytes, everyElement(0));
    expect(store.purges, greaterThan(0));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final root in [false, true]) {
    testWidgets('real shell removes expired wallet modal root=$root', (
      tester,
    ) async {
      final harness = TestAppHarness();
      addTearDown(harness.dispose);
      await harness.repository.createVehicle(
        plate: 'AAA123',
        kind: VehicleKind.car,
      );
      await harness.pump(
        tester,
        moduleFeatureFlags: {'module_seguro_asistencia_enabled': true},
        childOverride: ProviderScope(
          overrides: [
            walletDriversProvider.overrideWithValue(
              const AsyncValue.data(<WalletDriver>[]),
            ),
          ],
          child: const PicoRadarApp(),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppShell)),
      );
      final router = container.read(appRouterProvider);
      router.go('/apps/module/documentos');
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(DocumentsScreen));
      var closed = false;
      unawaited(
        showModalBottomSheet<void>(
          context: context,
          useRootNavigator: root,
          builder: (_) =>
              const DocumentsSessionSheet(child: Text('Private modal')),
        ).then((_) => closed = true),
      );
      await tester.pumpAndSettle();
      expect(find.text('Private modal'), findsOneWidget);
      if (root) {
        router.go('/apps/module/seguro_asistencia');
      } else {
        await tester.tap(find.byKey(const ValueKey('tab-apps')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('apps-launcher-overlay')),
          findsOneWidget,
        );
        final insurance = find.byKey(
          const ValueKey('app-module-seguro_asistencia'),
        );
        await tester.ensureVisible(insurance);
        await tester.tap(insurance);
      }
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/apps/module/seguro_asistencia',
      );
      expect(closed, isTrue);
      expect(
        find.byType(DocumentsSessionSheet, skipOffstage: false),
        findsNothing,
      );
      expect(find.text('Documentos bloqueados'), findsNothing);
      router.go('/garage');
      await tester.pumpAndSettle();
      router.go('/apps/module/documentos');
      await tester.pumpAndSettle();
      expect(find.text('Private modal'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

class _DelayedViewerStore implements WalletStore {
  final pending = Completer<Uint8List>();
  int reads = 0;
  int purges = 0;
  @override
  WalletMigrationReport get migrationReport => const WalletMigrationReport();
  @override
  Future<Uint8List> readDocumentBytes(
    WalletDocument document,
    WalletDocumentSide side,
  ) {
    reads++;
    return pending.future;
  }

  @override
  Future<void> purgeViewerCache() async {
    purges++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
