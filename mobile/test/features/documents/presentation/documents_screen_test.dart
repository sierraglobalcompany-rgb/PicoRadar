import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:picoradar/app/app_providers.dart';
import 'package:picoradar/app/theme/app_theme.dart';
import 'package:picoradar/features/documents/presentation/documents_screen.dart';
import 'package:picoradar/features/garage/data/vehicle_profile.dart';
import 'package:picoradar/features/vehicle_status/data/private_vehicle_document_store.dart';
import 'package:picoradar/features/vehicle_status/platform/vehicle_document_gateway.dart';

import '../../vehicle_status/presentation/v01b_obligations_test_font.dart';

late Directory root;
late _MemoryDocumentStore _store;
late VehicleProfile vehicle;
var ids = 0;

void main() {
  setUpAll(loadV01bObligationsTestFont);
  setUp(() {
    ids = 0;
    root = Directory.systemTemp.createTempSync('picoradar-documents-screen-');
    _store = _MemoryDocumentStore(root);
    vehicle = VehicleProfile(
      id: 'vehicle-1',
      plate: 'ABC123',
      kind: VehicleKind.car,
      serviceType: VehicleServiceType.private,
      createdAt: DateTime.utc(2026, 8, 30),
      updatedAt: DateTime.utc(2026, 8, 30),
    );
  });

  tearDown(() async {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  for (final size in const [Size(360, 800), Size(390, 844), Size(412, 915)]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('V01B vehicle documents title readable $size scale $scale', (
        tester,
      ) async {
        await _pumpDocuments(
          tester,
          size: size,
          textScaleFactor: scale,
          productionTheme: true,
        );
        final title = find.descendant(
          of: find.text('Documentos vehiculares'),
          matching: find.byType(RichText),
        );
        final paragraph = tester.renderObject<RenderParagraph>(title);
        for (final selection in const [
          TextSelection(baseOffset: 0, extentOffset: 10),
          TextSelection(baseOffset: 11, extentOffset: 22),
        ]) {
          final word = paragraph.getBoxesForSelection(selection);
          expect(
            word.map((box) => box.top).toSet(),
            hasLength(1),
            reason: 'The vehicle-scoped title must not split words',
          );
        }
        final attach = find.byKey(
          const ValueKey('documents-row-import-traffic_license'),
        );
        await tester.ensureVisible(attach);
        await tester.pump();
        expect(attach.hitTestable(), findsOneWidget);
        expect(tester.getSize(attach).height, greaterThanOrEqualTo(44));
        expect(find.text(vehicleDocumentOfficialWarning), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('shows vehicle-scoped documents and required private copy', (
    tester,
  ) async {
    await _import(
      type: PrivateVehicleDocumentType.soat,
      name: 'soat.pdf',
      bytes: [1, 2, 3],
    );
    await _import(
      type: PrivateVehicleDocumentType.rtm,
      name: 'rtm.pdf',
      bytes: [4, 5, 6],
    );

    await _pumpDocuments(tester);

    expect(find.text('Documentos vehiculares'), findsOneWidget);
    expect(find.text(vehicleDocumentPrivateCopy), findsOneWidget);
    expect(find.text(vehicleDocumentOfficialWarning), findsOneWidget);
    expect(find.byKey(const ValueKey('documents-card-soat')), findsOneWidget);
    expect(find.byKey(const ValueKey('documents-card-rtm')), findsOneWidget);
    expect(find.text('soat.pdf'), findsOneWidget);
    expect(find.text('rtm.pdf'), findsOneWidget);
    expect(find.textContaining('Verificado oficialmente'), findsNothing);
    expect(find.textContaining('vigente'), findsNothing);
  });

  testWidgets('imports selected type and clears picker temporary files', (
    tester,
  ) async {
    final picked = File('${root.path}/picked.pdf');
    picked.writeAsBytesSync([7, 8, 9]);
    final gateway = _FakeDocumentGateway(
      pickedDocument: PickedVehicleDocument(
        file: picked,
        originalName: 'seguro.pdf',
        mimeType: 'application/pdf',
      ),
    );

    await _pumpDocuments(tester, gateway: gateway);
    await _selectType(tester, 'Seguro voluntario');
    await tester.tap(
      find.byKey(const ValueKey('documents-import-voluntary_insurance')),
    );
    await _pumpFrames(tester);

    expect(gateway.clearTemporaryFileCalls, 1);
    final metadata = await _store.get(
      vehicleId: vehicle.id,
      documentType: PrivateVehicleDocumentType.voluntaryInsurance,
    );
    expect(metadata?.originalName, 'seguro.pdf');
  });

  testWidgets('clears picker temporary files when import is cancelled', (
    tester,
  ) async {
    final gateway = _FakeDocumentGateway();

    await _pumpDocuments(tester, gateway: gateway);
    await tester.tap(
      find.byKey(const ValueKey('documents-import-traffic_license')),
    );
    await _pumpFrames(tester);

    expect(gateway.clearTemporaryFileCalls, 1);
    expect(
      await _store.get(
        vehicleId: vehicle.id,
        documentType: PrivateVehicleDocumentType.trafficLicense,
      ),
      isNull,
    );
  });

  testWidgets('replaces and deletes a vehicle-scoped copy', (tester) async {
    await _import(
      type: PrivateVehicleDocumentType.trafficLicense,
      name: 'licencia.pdf',
      bytes: [1],
    );
    final replacement = File('${root.path}/replacement.pdf');
    replacement.writeAsBytesSync([2]);
    final gateway = _FakeDocumentGateway(
      pickedDocument: PickedVehicleDocument(
        file: replacement,
        originalName: 'licencia-nueva.pdf',
        mimeType: 'application/pdf',
      ),
    );

    await _pumpDocuments(tester, gateway: gateway);
    await tester.tap(
      find.byKey(const ValueKey('documents-replace-traffic_license')),
    );
    await _pumpFrames(tester);

    expect(find.text('licencia-nueva.pdf'), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey('documents-delete-traffic_license')),
    );
    await _pumpFrames(tester);

    expect(find.text('Eliminar copia local'), findsOneWidget);
    expect(
      find.text(
        '¿Eliminar Licencia de tránsito (licencia-nueva.pdf) de este dispositivo?',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('documents-delete-cancel')));
    await _pumpFrames(tester);
    expect(
      await _store.get(
        vehicleId: vehicle.id,
        documentType: PrivateVehicleDocumentType.trafficLicense,
      ),
      isNotNull,
    );

    await tester.tap(
      find.byKey(const ValueKey('documents-delete-traffic_license')),
    );
    await _pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('documents-delete-confirm')));
    await _pumpFrames(tester);

    expect(
      await _store.get(
        vehicleId: vehicle.id,
        documentType: PrivateVehicleDocumentType.trafficLicense,
      ),
      isNull,
    );
  });

  testWidgets('ignores document actions while an operation is busy', (
    tester,
  ) async {
    final picked = File('${root.path}/picked.pdf');
    picked.writeAsBytesSync([7, 8, 9]);
    final gateway = _DelayedPickDocumentGateway();

    await _pumpDocuments(tester, gateway: gateway);
    await tester.tap(
      find.byKey(const ValueKey('documents-import-traffic_license')),
    );
    await tester.pump();

    expect(gateway.pickCalls, 1);
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('documents-import-traffic_license')),
    );
    expect(button.onPressed, isNull);

    gateway.completePick(
      PickedVehicleDocument(
        file: picked,
        originalName: 'licencia.pdf',
        mimeType: 'application/pdf',
      ),
    );
    await _pumpFrames(tester);

    expect(gateway.clearTemporaryFileCalls, 1);
    expect(
      (await _store.get(
        vehicleId: vehicle.id,
        documentType: PrivateVehicleDocumentType.trafficLicense,
      ))?.originalName,
      'licencia.pdf',
    );
  });

  testWidgets(
    'late picker result after leaving screen is cleaned and ignored',
    (tester) async {
      final picked = File('${root.path}/late.pdf');
      picked.writeAsBytesSync([7, 8, 9]);
      final gateway = _DelayedPickDocumentGateway();

      await _pumpDocuments(tester, gateway: gateway);
      await tester.tap(
        find.byKey(const ValueKey('documents-import-traffic_license')),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());

      gateway.completePick(
        PickedVehicleDocument(
          file: picked,
          originalName: 'late.pdf',
          mimeType: 'application/pdf',
        ),
      );
      await _pumpFrames(tester);

      expect(gateway.clearTemporaryFileCalls, 1);
      expect(
        await _store.get(
          vehicleId: vehicle.id,
          documentType: PrivateVehicleDocumentType.trafficLicense,
        ),
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('viewer handoff purges plaintext after failed open', (
    tester,
  ) async {
    await _import(
      type: PrivateVehicleDocumentType.other,
      name: 'otro.pdf',
      bytes: [3, 4],
    );
    final gateway = _FakeDocumentGateway(openResult: false);

    await _pumpDocuments(tester, gateway: gateway);
    await _selectType(tester, 'Otro');
    await tester.tap(find.byKey(const ValueKey('documents-open-other')));
    await _pumpFrames(tester);

    expect(gateway.openedFiles, hasLength(1));
    expect(
      find.text('No se pudo abrir la copia cifrada. Puedes reemplazarla.'),
      findsOneWidget,
    );
    expect(await _viewerCacheFiles(), isEmpty);
  });

  testWidgets('tampered encrypted file shows visible error', (tester) async {
    final metadata = await _import(
      type: PrivateVehicleDocumentType.soat,
      name: 'soat.pdf',
      bytes: [1, 2],
    );
    _store.failOpenIds.add(metadata.documentId);

    await _pumpDocuments(tester);
    await _selectType(tester, 'SOAT');
    await tester.tap(find.byKey(const ValueKey('documents-open-soat')));
    await _pumpFrames(tester);

    expect(
      find.text('No se pudo abrir la copia cifrada. Puedes reemplazarla.'),
      findsOneWidget,
    );
  });

  testWidgets('corrupt index is a visible recoverable error', (tester) async {
    _store.failList = true;

    await _pumpDocuments(tester);
    await _pumpFrames(tester);

    expect(
      find.text(
        'No se pudo leer la billetera cifrada. Puedes reemplazar el archivo afectado.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('without a vehicle, CTA goes to Garage', (tester) async {
    await _pumpDocuments(
      tester,
      vehicleId: null,
      vehicles: const [],
      enableGarageRoute: true,
    );

    await tester.tap(find.byKey(const ValueKey('documents-go-garage')));
    await _pumpFrames(tester);

    expect(find.text('garage'), findsOneWidget);
  });

  testWidgets('document screen avoids personal wallet scope and OCR copy', (
    tester,
  ) async {
    await _pumpDocuments(tester);

    expect(find.text('Licencia de tránsito'), findsWidgets);
    expect(find.textContaining('licencia de conducción'), findsNothing);
    expect(find.textContaining('cédula'), findsNothing);
    expect(find.textContaining('OCR'), findsNothing);
    expect(find.textContaining('nube'), findsNothing);
  });

  testWidgets('document screen remains usable in phone viewports', (
    tester,
  ) async {
    for (final viewport in [
      (size: const Size(360, 800), scale: 1.0),
      (size: const Size(390, 844), scale: 1.5),
      (size: const Size(412, 915), scale: 2.0),
    ]) {
      await _pumpDocuments(
        tester,
        size: viewport.size,
        textScaleFactor: viewport.scale,
      );
      expect(
        find.byKey(const ValueKey('documents-screen-scroll')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}

Future<PrivateVehicleDocumentMetadata> _import({
  required PrivateVehicleDocumentType type,
  required String name,
  required List<int> bytes,
}) async {
  final source = File('${root.path}/$name');
  source.writeAsBytesSync(bytes);
  return _store.importDocument(
    vehicleId: vehicle.id,
    documentType: type,
    source: source,
    originalName: name,
    mimeType: 'application/pdf',
  );
}

Future<List<FileSystemEntity>> _viewerCacheFiles() async {
  final viewer = Directory('${root.path}/vehicle_document_viewer');
  if (!viewer.existsSync()) {
    return const [];
  }
  return viewer.listSync(recursive: true);
}

Future<void> _pumpDocuments(
  WidgetTester tester, {
  String? vehicleId = 'vehicle-1',
  List<VehicleProfile>? vehicles,
  VehicleDocumentGateway? gateway,
  Size size = const Size(390, 844),
  double textScaleFactor = 1.0,
  bool enableGarageRoute = false,
  bool productionTheme = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = enableGarageRoute
      ? GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => DocumentsScreen(vehicleId),
            ),
            GoRoute(
              path: '/garage',
              builder: (context, state) => const Scaffold(body: Text('garage')),
            ),
          ],
        )
      : null;
  final appBuilder = _scaledBuilder(textScaleFactor);
  final child = router == null
      ? MaterialApp(
          theme: productionTheme ? buildPicoRadarTheme() : null,
          home: DocumentsScreen(vehicleId),
          builder: appBuilder,
        )
      : MaterialApp.router(routerConfig: router, builder: appBuilder);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        vehicleListProvider.overrideWithValue(
          AsyncValue.data(vehicles ?? [vehicle]),
        ),
        privateVehicleDocumentStoreProvider.overrideWithValue(_store),
        vehicleDocumentGatewayProvider.overrideWithValue(
          gateway ?? _FakeDocumentGateway(),
        ),
      ],
      child: child,
    ),
  );
  await _pumpFrames(tester);
}

Future<void> _selectType(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const ValueKey('documents-type-selector')));
  await _pumpFrames(tester);
  await tester.tap(find.text(label).last);
  await _pumpFrames(tester);
}

Future<void> _pumpFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump();
}

TransitionBuilder _scaledBuilder(double textScaleFactor) {
  return (context, child) {
    final mediaQuery = MediaQuery.of(context);
    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: TextScaler.linear(textScaleFactor)),
      child: child ?? const SizedBox.shrink(),
    );
  };
}

class _MemoryDocumentStore extends PrivateVehicleDocumentStore {
  _MemoryDocumentStore(this.root);

  final Directory root;
  final _documents =
      <(String, PrivateVehicleDocumentType), PrivateVehicleDocumentMetadata>{};
  final failOpenIds = <String>{};
  bool failList = false;

  @override
  Future<PrivateVehicleDocumentMetadata?> get({
    required String vehicleId,
    required PrivateVehicleDocumentType documentType,
  }) async {
    return _documents[(vehicleId, documentType)];
  }

  @override
  Future<List<PrivateVehicleDocumentMetadata>> listForVehicle(
    String vehicleId,
  ) async {
    if (failList) {
      throw StateError('index failed');
    }
    return [
      for (final entry in _documents.entries)
        if (entry.key.$1 == vehicleId) entry.value,
    ];
  }

  @override
  Future<PrivateVehicleDocumentMetadata> importDocument({
    required String vehicleId,
    required PrivateVehicleDocumentType documentType,
    required File source,
    required String originalName,
    required String mimeType,
  }) async {
    source.readAsBytesSync();
    final metadata = PrivateVehicleDocumentMetadata(
      documentId: 'screen-doc-${(++ids).toString().padLeft(4, '0')}',
      vehicleId: vehicleId,
      documentType: documentType,
      originalName: originalName,
      mimeType: mimeType,
      importedAt: DateTime.utc(2026, 8, 30, 12),
      encryptedRelativePath:
          'docs/${documentType.value}/$vehicleId/screen-doc-$ids.prcf',
    );
    _documents[(vehicleId, documentType)] = metadata;
    return metadata;
  }

  @override
  Future<PrivateVehicleDocumentMetadata> replaceDocument({
    required String vehicleId,
    required PrivateVehicleDocumentType documentType,
    required File source,
    required String originalName,
    required String mimeType,
  }) {
    return importDocument(
      vehicleId: vehicleId,
      documentType: documentType,
      source: source,
      originalName: originalName,
      mimeType: mimeType,
    );
  }

  @override
  Future<File> decryptForView(PrivateVehicleDocumentMetadata metadata) async {
    if (failOpenIds.contains(metadata.documentId)) {
      throw const FileSystemException('Corrupt encrypted file');
    }
    await purgeViewerCache();
    final folder = Directory(
      '${root.path}/vehicle_document_viewer/${metadata.documentId}',
    );
    folder.createSync(recursive: true);
    final file = File('${folder.path}/${metadata.originalName}');
    file.writeAsBytesSync([1, 2, 3]);
    return file;
  }

  @override
  Future<void> delete(PrivateVehicleDocumentMetadata metadata) async {
    _documents.remove((metadata.vehicleId, metadata.documentType));
    await purgeViewerCache(metadata: metadata);
  }

  @override
  Future<void> purgeViewerCache({
    PrivateVehicleDocumentMetadata? metadata,
  }) async {
    final viewer = Directory('${root.path}/vehicle_document_viewer');
    if (metadata != null) {
      final folder = Directory('${viewer.path}/${metadata.documentId}');
      if (folder.existsSync()) {
        folder.deleteSync(recursive: true);
      }
      return;
    }
    if (viewer.existsSync()) {
      viewer.deleteSync(recursive: true);
    }
  }
}

class _FakeDocumentGateway implements VehicleDocumentGateway {
  _FakeDocumentGateway({this.pickedDocument, this.openResult = true});

  final PickedVehicleDocument? pickedDocument;
  final bool openResult;
  final openedFiles = <File>[];
  var pickCalls = 0;
  var clearTemporaryFileCalls = 0;

  @override
  Future<void> clearTemporaryFiles() async {
    clearTemporaryFileCalls += 1;
  }

  @override
  Future<bool> openDocument(File file) async {
    openedFiles.add(file);
    return openResult;
  }

  @override
  Future<PickedVehicleDocument?> pickDocument() async {
    pickCalls += 1;
    return pickedDocument;
  }
}

class _DelayedPickDocumentGateway implements VehicleDocumentGateway {
  final _picked = Completer<PickedVehicleDocument?>();
  final openedFiles = <File>[];
  var pickCalls = 0;
  var clearTemporaryFileCalls = 0;

  @override
  Future<void> clearTemporaryFiles() async {
    clearTemporaryFileCalls += 1;
  }

  @override
  Future<bool> openDocument(File file) async {
    openedFiles.add(file);
    return true;
  }

  @override
  Future<PickedVehicleDocument?> pickDocument() {
    pickCalls += 1;
    return _picked.future;
  }

  void completePick(PickedVehicleDocument? pickedDocument) {
    if (!_picked.isCompleted) {
      _picked.complete(pickedDocument);
    }
  }
}
