import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/core/config/app_config.dart';
import 'package:picoradar/core/database/app_database.dart';
import 'package:picoradar/core/sync/dataset_sync_service.dart';
import 'package:picoradar/features/pico_placa/data/pico_preferences.dart';
import 'package:picoradar/features/settings/application/national_dataset_status_provider.dart';
import 'package:picoradar/features/settings/presentation/settings_screen.dart';

void main() {
  testWidgets('missing CDN config explains and disables manual refresh', (
    tester,
  ) async {
    var refreshCalls = 0;
    await _pumpSettings(
      tester,
      configured: false,
      refresh: () async {
        refreshCalls++;
        return const DatasetSyncResult(imported: ['restrictions']);
      },
    );

    final button = find.byKey(
      const ValueKey('settings-refresh-national-datasets'),
    );
    expect(
      find.text('Servidor OTA no configurado en esta compilación.'),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.tap(button);
    await tester.pump();
    expect(refreshCalls, 0);
  });

  testWidgets(
    'reports national imports and missing importer, then refreshes status',
    (tester) async {
      var statusReads = 0;
      await _pumpSettings(
        tester,
        statusReads: () => statusReads++,
        refresh: () async => const DatasetSyncResult(
          imported: ['restrictions'],
          skippedMissingImporter: ['service_providers'],
        ),
      );
      final initialStatusReads = statusReads;

      await _tapRefresh(tester);
      await _showResult(tester);

      expect(
        find.textContaining(
          'Datos nacionales nuevos instalados: Restricciones nacionales.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'No se pudieron actualizar Directorio de servicios: falta el importador correspondiente.',
        ),
        findsOneWidget,
      );
      expect(statusReads, greaterThan(initialStatusReads));
    },
  );

  testWidgets('304 reports no new changes', (tester) async {
    await _pumpSettings(
      tester,
      refresh: () async => const DatasetSyncResult(
        notModified: true,
      ),
    );

    await _tapRefresh(tester);
    await _showResult(tester);

    expect(
      find.textContaining(
        'Sin cambios nuevos detectados: el manifiesto no cambió.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('nuevos instalados'), findsNothing);
  });

  testWidgets('current local versions report no new changes', (tester) async {
    await _pumpSettings(
      tester,
      refresh: () async => const DatasetSyncResult(
        skippedCurrent: ['restrictions'],
      ),
    );

    await _tapRefresh(tester);
    await _showResult(tester);

    expect(
      find.text('Sin cambios nuevos detectados en: Restricciones nacionales.'),
      findsOneWidget,
    );
  });

  testWidgets('reports imports limited to other catalogs', (tester) async {
    await _pumpSettings(
      tester,
      refresh: () async => const DatasetSyncResult(
        imported: ['tolls_inventory'],
      ),
    );

    await _tapRefresh(tester);
    await _showResult(tester);

    expect(
      find.textContaining('Otros catálogos nuevos instalados: Peajes.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Datos nacionales nuevos instalados'),
      findsNothing,
    );
  });

  testWidgets('reports null result as unavailable', (tester) async {
    await _pumpSettings(tester, refresh: () async => null);

    await _tapRefresh(tester);
    await _showResult(tester);

    expect(
      find.text(
        'La actualización nacional no está disponible en este momento.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows a safe message when refresh throws', (tester) async {
    await _pumpSettings(
      tester,
      refresh: () async => throw Exception(
        'https://cdn.example.test/manifest?token=private-secret',
      ),
    );

    await _tapRefresh(tester);
    await _showResult(tester);

    expect(
      find.text(
        'No pudimos actualizar los datos nacionales. Revisa la conexión e inténtalo de nuevo.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('private-secret'), findsNothing);
    expect(find.textContaining('cdn.example.test'), findsNothing);
  });

  testWidgets('blocks reentrant refresh while the first request is pending', (
    tester,
  ) async {
    final pending = Completer<DatasetSyncResult?>();
    var refreshCalls = 0;
    await _pumpSettings(
      tester,
      refresh: () {
        refreshCalls++;
        return pending.future;
      },
    );

    final button = find.byKey(
      const ValueKey('settings-refresh-national-datasets'),
    );
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    expect(refreshCalls, 1);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(button);
    await tester.pump();
    expect(refreshCalls, 1);

    pending.complete(const DatasetSyncResult(notModified: true));
    await _showResult(tester);
    expect(
      find.textContaining('Sin cambios nuevos detectados'),
      findsOneWidget,
    );
  });
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  required Future<DatasetSyncResult?> Function() refresh,
  bool configured = true,
  void Function()? statusReads,
}) async {
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  final container = ProviderContainer(
    retry: (retryCount, error) => null,
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      datasetSyncConfigProvider.overrideWithValue(
        configured ? AppConfig(cdnBaseUrl: 'https://cdn.example.test') : null,
      ),
      manualDatasetRefreshProvider.overrideWithValue(refresh),
      settingsNotificationStatusProvider.overrideWith(
        (ref) async => const SettingsNotificationStatus(
          alertPreferences: PicoAlertPreferences(
            enabled: true,
            dayBeforeEnabled: true,
            sameDayEnabled: true,
            dayBeforeMinute: 480,
            sameDayMinute: 480,
            permissionRequested: true,
            permissionGranted: true,
          ),
          osNotificationsEnabled: true,
        ),
      ),
      cameraDatasetDiagnosticProvider.overrideWithValue(
        const AsyncValue.data(
          CameraDatasetDiagnostic(version: 'test-cameras', count: 1),
        ),
      ),
      nationalDatasetStatusProvider.overrideWith((ref) async {
        statusReads?.call();
        return const <String, NationalDatasetRecord>{};
      }),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: SettingsScreen(onChangeAvatar: () {})),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _tapRefresh(WidgetTester tester) async {
  final button = find.byKey(
    const ValueKey('settings-refresh-national-datasets'),
  );
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
}

Future<void> _showResult(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}
