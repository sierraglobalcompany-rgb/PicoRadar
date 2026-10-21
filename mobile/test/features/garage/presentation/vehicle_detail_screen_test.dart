import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/features/defense/data/defense_case_store.dart';
import 'package:picoradar/features/documents/application/wallet_providers.dart';
import 'package:picoradar/features/documents/application/wallet_session.dart';
import 'package:picoradar/features/garage/application/vehicle_associated_data_cleaner.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/garage/data/vehicle_repository.dart';
import 'package:picoradar/features/garage/presentation/vehicle_detail_screen.dart';
import 'package:picoradar/features/peritajes/data/peritajes_draft_store.dart';

import '../../../test_app_harness.dart';

void main() {
  late TestAppHarness harness;
  late _DetailCleaner cleaner;
  late _DetailRepository repository;
  late List<String> operations;
  late VehicleProfile target;
  late VehicleProfile other;

  setUp(() {
    harness = TestAppHarness();
    operations = [];
    cleaner = _DetailCleaner(harness, operations);
    repository = _DetailRepository(harness, operations);
  });

  tearDown(() async {
    await harness.dispose();
  });

  Future<GoRouter> openDetail(
    WidgetTester tester, {
    bool isFavorite = true,
    WalletSession? session,
  }) async {
    // Seed queued mutations in the widget test's async zone, not setUp's zone.
    target = await harness.repository.createVehicle(
      plate: 'AAA111',
      kind: VehicleKind.car,
      nickname: 'Mazda',
    );
    other = await harness.repository.createVehicle(
      plate: 'BBB222',
      kind: VehicleKind.car,
      nickname: 'Chevrolet',
    );
    await harness.repository.setActiveVehicle(
      isFavorite ? target.id : other.id,
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final router = GoRouter(
      initialLocation: '/garage/vehicle/${target.id}',
      routes: [
        GoRoute(
          path: '/garage',
          builder: (_, _) => const Scaffold(body: Text('Garaje')),
        ),
        GoRoute(
          path: '/garage/vehicle/:id',
          builder: (_, state) =>
              VehicleDetailScreen(vehicleId: state.pathParameters['id']!),
        ),
      ],
    );
    await harness.pump(
      tester,
      vehicleAssociatedDataCleaner: cleaner,
      childOverride: ProviderScope(
        overrides: [
          vehicleRepositoryProvider.overrideWithValue(repository),
          if (session != null) walletSessionProvider.overrideWithValue(session),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
    });
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets(
    'detail denies deletion when wallet authentication is cancelled',
    (tester) async {
      final auth = _DeletionAuthenticator();
      final session = WalletSession(
        authenticator: auth,
        preferences: _DeletionPreferences(),
      );
      addTearDown(session.dispose);
      await openDetail(tester, session: session);
      await _confirmDelete(tester);
      expect(auth.calls, 1);
      expect(operations, isEmpty);
      expect(await harness.repository.getVehicle(target.id), isNotNull);
    },
  );

  testWidgets('detail rejects authentication completed after route exit', (
    tester,
  ) async {
    final auth = _DeletionAuthenticator()
      ..pending = Completer<WalletAuthenticationResult>();
    final session = WalletSession(
      authenticator: auth,
      preferences: _DeletionPreferences(),
    );
    addTearDown(session.dispose);
    final router = await openDetail(tester, session: session);
    await _confirmDelete(tester);
    expect(auth.calls, 1);
    router.go('/garage');
    await tester.pumpAndSettle();
    auth.pending!.complete(WalletAuthenticationResult.success);
    await tester.pumpAndSettle();
    expect(operations, isEmpty);
    expect(await harness.repository.getVehicle(target.id), isNotNull);
  });

  testWidgets(
    'detail stops before row deletion when background revokes cleanup authorization',
    (tester) async {
      cleaner.gate = Completer<void>();
      await openDetail(tester);
      await _confirmDelete(tester);
      expect(operations, ['cleanup:${target.id}']);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      cleaner.gate!.complete();
      await tester.pumpAndSettle();
      expect(operations, ['cleanup:${target.id}']);
      expect(await repository.getVehicle(target.id), isNotNull);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
    },
  );

  testWidgets('detail exposes the mockup actions without a scroll view', (
    tester,
  ) async {
    await openDetail(tester);
    expect(find.byType(Scrollable), findsNothing);
    expect(find.byKey(const ValueKey('detail-vehicle-image')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('detail-change-vehicle-image')),
      findsOneWidget,
    );
  });

  for (final entry in ['detail-vehicle-image', 'detail-change-vehicle-image']) {
    testWidgets(
      '$entry opens the existing image picker without changing favorite',
      (tester) async {
        await openDetail(tester);
        await tester.tap(find.byKey(ValueKey(entry)));
        // Opening the sheet must work even while its independent catalog loads.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text('Cambiar imagen'), findsOneWidget);
        expect((await repository.getActiveVehicle())?.id, target.id);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Detalle del vehículo'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'detail cancellation explains undo window and irreversible cleanup and changes nothing',
    (tester) async {
      await openDetail(tester);
      await _openDeleteDialog(tester);
      expect(find.textContaining('documentos cifrados'), findsOneWidget);
      expect(
        find.textContaining(
          'Tendrás 5 segundos para deshacer. Después, la eliminación será irreversible.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(operations, isEmpty);
      expect(await repository.getVehicle(target.id), isNotNull);
      expect((await repository.getActiveVehicle())?.id, target.id);
      expect(find.text('Detalle del vehículo'), findsOneWidget);
    },
  );

  for (final isFavorite in [false, true]) {
    testWidgets(
      'detail cleans selected vehicle before row deletion favorite=$isFavorite',
      (tester) async {
        await openDetail(tester, isFavorite: isFavorite);
        await _confirmDelete(tester);
        expect(operations, ['cleanup:${target.id}', 'delete:${target.id}']);
        expect(await repository.getVehicle(target.id), isNull);
        expect(await repository.getVehicle(other.id), isNotNull);
        expect((await repository.getActiveVehicle())?.id, other.id);
        expect(find.text('Garaje'), findsOneWidget);
        expect(find.text('Deshacer'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'detail cleanup failure preserves row and favorite and permits retry',
    (tester) async {
      cleaner.fail = true;
      await openDetail(tester);
      await _confirmDelete(tester);
      expect(operations, ['cleanup:${target.id}']);
      expect(await repository.getVehicle(target.id), isNotNull);
      expect((await repository.getActiveVehicle())?.id, target.id);
      expect(
        find.text(
          'No pudimos limpiar los datos asociados. Inténtalo de nuevo.',
        ),
        findsOneWidget,
      );
      expect(find.text('Detalle del vehículo'), findsOneWidget);
      cleaner.fail = false;
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await _confirmDelete(tester);
      expect(await repository.getVehicle(target.id), isNull);
      expect(find.text('Garaje'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final cancellation in [
    'undo',
    'hide',
    'dismiss',
    'navigation',
    'unmount',
  ]) {
    testWidgets(
      'pending detail deletion cancels on $cancellation before cleanup',
      (tester) async {
        final router = await openDetail(tester);
        final preferencesBefore = {...harness.preferences.values};
        await _confirmDelete(tester, expire: false);
        expect(operations, isEmpty);
        expect(await repository.getVehicle(target.id), isNotNull);
        expect((await repository.getActiveVehicle())?.id, target.id);
        expect(
          tester
              .widget<OutlinedButton>(
                find.byKey(const ValueKey('detail-delete-vehicle')),
              )
              .onPressed,
          isNull,
        );
        await tester.pump(const Duration(seconds: 2));
        switch (cancellation) {
          case 'undo':
            await tester.tap(find.text('Deshacer'));
          case 'hide':
            ScaffoldMessenger.of(
              tester.element(find.byType(VehicleDetailScreen)),
            ).hideCurrentSnackBar();
          case 'dismiss':
            await tester.drag(find.byType(SnackBar), const Offset(0, 200));
          case 'navigation':
            router.go('/garage');
            await tester.pumpAndSettle();
            router.go('/garage/vehicle/${target.id}');
          case 'unmount':
            await tester.pumpWidget(const SizedBox.shrink());
        }
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(operations, isEmpty);
        expect(await repository.getVehicle(target.id), isNotNull);
        expect((await repository.getActiveVehicle())?.id, target.id);
        expect(harness.preferences.values, preferencesBefore);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('detail waits full pending window before cleanup and deletion', (
    tester,
  ) async {
    await openDetail(tester);
    await _confirmDelete(tester, expire: false);
    await tester.pump(const Duration(seconds: 4));
    expect(operations, isEmpty);
    expect(await repository.getVehicle(target.id), isNotNull);
    expect((await repository.getActiveVehicle())?.id, target.id);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(operations, ['cleanup:${target.id}', 'delete:${target.id}']);
    expect(await repository.getVehicle(target.id), isNull);
    expect((await repository.getActiveVehicle())?.id, other.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'detail row failure reports completed private cleanup without claiming deletion',
    (tester) async {
      repository.failDelete = true;
      await openDetail(tester);
      await _confirmDelete(tester);
      expect(operations, ['cleanup:${target.id}', 'delete:${target.id}']);
      expect(await repository.getVehicle(target.id), isNotNull);
      expect((await repository.getActiveVehicle())?.id, target.id);
      expect(
        find.text(
          'Los datos privados se limpiaron, pero no pudimos eliminar el vehículo. Inténtalo de nuevo.',
        ),
        findsOneWidget,
      );
      expect(find.text('Detalle del vehículo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'detail post-row failure returns to Garage and reports partial completion',
    (tester) async {
      repository.failAfterDelete = true;
      await openDetail(tester);
      await _confirmDelete(tester);
      expect(operations, ['cleanup:${target.id}', 'delete:${target.id}']);
      expect(await repository.getVehicle(target.id), isNull);
      expect((await repository.getActiveVehicle())?.id, other.id);
      expect(find.text('Garaje'), findsOneWidget);
      expect(
        find.text(
          'El vehículo se eliminó, pero no pudimos completar algunos ajustes locales.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'detail disables repeated delete while private cleanup is pending',
    (tester) async {
      cleaner.gate = Completer<void>();
      addTearDown(() {
        if (!cleaner.gate!.isCompleted) cleaner.gate!.complete();
      });
      await openDetail(tester);
      await _confirmDelete(tester);
      expect(operations, ['cleanup:${target.id}']);
      expect(await repository.getVehicle(target.id), isNotNull);
      final action = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('detail-delete-vehicle')),
      );
      expect(action.onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('detail-delete-vehicle')));
      await tester.pump();
      expect(find.byType(AlertDialog), findsNothing);
      cleaner.gate!.complete();
      await tester.pumpAndSettle();
      expect(operations, ['cleanup:${target.id}', 'delete:${target.id}']);
      expect(find.text('Garaje'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'detail deletion preserves vehicle if route exits during private cleanup',
    (tester) async {
      cleaner.gate = Completer<void>();
      addTearDown(() {
        if (!cleaner.gate!.isCompleted) cleaner.gate!.complete();
      });
      final router = await openDetail(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(VehicleDetailScreen)),
      );
      expect(
        (await container.read(activeVehicleProvider.future))?.id,
        target.id,
      );
      await _confirmDelete(tester);
      router.go('/garage');
      await tester.pumpAndSettle();
      cleaner.gate!.complete();
      await tester.pumpAndSettle();
      expect(operations, ['cleanup:${target.id}']);
      expect(await repository.getVehicle(target.id), isNotNull);
      expect(
        (await container.read(activeVehicleProvider.future))?.id,
        target.id,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _openDeleteDialog(WidgetTester tester) async {
  final delete = find.byKey(const ValueKey('detail-delete-vehicle'));
  await tester.ensureVisible(delete);
  await tester.pumpAndSettle();
  await tester.tap(delete);
  await tester.pumpAndSettle();
}

Future<void> _confirmDelete(WidgetTester tester, {bool expire = true}) async {
  await _openDeleteDialog(tester);
  await tester.tap(find.byKey(const ValueKey('confirm-delete-vehicle')));
  await tester.pumpAndSettle();
  expect(find.text('Eliminación pendiente'), findsOneWidget);
  if (expire) {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }
}

class _DeletionAuthenticator implements WalletDeviceAuthenticator {
  int calls = 0;
  Completer<WalletAuthenticationResult>? pending;
  @override
  Future<bool> canAuthenticate() async => true;
  @override
  Future<WalletAuthenticationResult> authenticate() async {
    calls++;
    return pending == null
        ? WalletAuthenticationResult.cancelled
        : await pending!.future;
  }
}

class _DeletionPreferences implements WalletSecurityPreferencesStore {
  @override
  Future<WalletSecurityPreferences> read() async =>
      const WalletSecurityPreferences(protectionEnabled: true, offerSeen: true);
  @override
  Future<void> write(WalletSecurityPreferences preferences) async {}
}

class _DetailCleaner extends VehicleAssociatedDataCleaner {
  _DetailCleaner(TestAppHarness harness, this.operations)
    : super(
        documentStore: harness.documentStore,
        defenseCaseStore: DefenseCaseStore(),
        peritajesDraftStore: PeritajesDraftStore(harness.preferences),
        preferences: harness.preferences,
      );

  final List<String> operations;
  bool fail = false;
  Completer<void>? gate;

  @override
  Future<void> deletePrivateDataForVehicle(
    String vehicleId, {
    required bool Function() isAuthorized,
  }) async {
    if (!isAuthorized()) throw StateError('Wallet locked');
    await deleteForVehicle(vehicleId);
    if (!isAuthorized()) throw StateError('Wallet locked');
  }

  @override
  Future<void> deleteForVehicle(String vehicleId) async {
    operations.add('cleanup:$vehicleId');
    if (fail) throw StateError('private cleanup failed');
    final pending = gate;
    if (pending != null) await pending.future;
  }
}

class _DetailRepository extends VehicleRepository {
  _DetailRepository(TestAppHarness harness, this.operations)
    : super(database: harness.database, preferences: harness.preferences);

  final List<String> operations;
  bool failDelete = false;
  bool failAfterDelete = false;

  @override
  Future<void> deleteVehicle(String id) async {
    operations.add('delete:$id');
    if (failDelete) throw StateError('row deletion failed');
    await super.deleteVehicle(id);
    if (failAfterDelete) throw StateError('post-row deletion failed');
  }
}
