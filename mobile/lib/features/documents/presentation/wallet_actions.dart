import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../application/wallet_draft.dart';
import '../application/wallet_providers.dart';
import '../data/wallet_models.dart';
import '../platform/wallet_platform.dart';
import 'wallet_viewer.dart';

class WalletActions {
  WalletActions(this.context, this.ref, {this.visitRouteName});
  final BuildContext context;
  final WidgetRef ref;

  /// Only supply from a matching WalletAccessGate on a named Navigator route.
  /// Other entry points keep their existing per-operation locking policy.
  final String? visitRouteName;

  void _notice(String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _run(
    Future<void> Function(bool Function() isCurrent) operation,
  ) async {
    final session = ref.read(walletSessionProvider);
    final mutex = ref.read(walletOperationProvider);
    if (mutex.busy) return;
    mutex.busy = true;
    final route = ModalRoute.of(context);
    final router = GoRouter.maybeOf(context);
    final origin = router?.routeInformationProvider.value.uri;
    var visitEnded = false;
    void routeChanged() {
      if (router?.routeInformationProvider.value.uri != origin) {
        visitEnded = true;
      }
    }

    if (visitRouteName != null) {
      router?.routeInformationProvider.addListener(routeChanged);
    }
    bool namedVisitActive() =>
        visitRouteName != null &&
        !visitEnded &&
        context.mounted &&
        route?.settings.name == visitRouteName &&
        route?.isActive == true &&
        router?.routeInformationProvider.value.uri == origin;
    bool isCurrent() =>
        context.mounted && (visitRouteName == null || namedVisitActive());
    final walletVisit =
        visitRouteName == null &&
        (GoRouter.maybeOf(context)?.routeInformationProvider.value.uri.path
                .endsWith('/module/documentos') ??
            true);
    try {
      if (visitRouteName != null && !namedVisitActive()) return;
      if (!session.accessAllowed && !await session.unlock()) {
        _notice(session.failureMessage ?? 'No se pudo desbloquear Documentos.');
        return;
      }
      if (isCurrent()) await operation(isCurrent);
    } on FormatException catch (error) {
      _notice(error.message);
    } on WalletPlatformException catch (_) {
      _notice(
        'No se pudo abrir el escáner o visor. Puedes importar un archivo compatible e intentar de nuevo.',
      );
    } catch (_) {
      _notice(
        'No se pudo completar la operación. Revisa el estado de la copia e intenta de nuevo.',
      );
    } finally {
      if (visitRouteName != null) {
        router?.routeInformationProvider.removeListener(routeChanged);
      }
      mutex.busy = false;
      if (!walletVisit && !namedVisitActive()) session.lock();
    }
  }

  Future<void> add(
    WalletOwner owner,
    WalletDocumentType type, {
    required String ownerLabel,
  }) => _run((isCurrent) async {
    final store = ref.read(walletStoreProvider);
    final session = ref.read(walletSessionProvider);
    final platform = ref.read(walletPlatformProvider);
    final gateway = ref.read(vehicleDocumentGatewayProvider);
    final keyLoader = ref.read(walletFileKeyProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    final router = GoRouter.maybeOf(context);
    final origin = router?.routeInformationProvider.value.uri;
    final route = ModalRoute.of(context);
    bool stillHere() =>
        isCurrent() &&
        router?.routeInformationProvider.value.uri == origin &&
        (visitRouteName == null ||
            (route?.isActive == true &&
                route?.settings.name == visitRouteName));
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.document_scanner_outlined),
              title: const Text('Escanear'),
              onTap: () => Navigator.pop(sheet, 'scan'),
            ),
            ListTile(
              leading: const Icon(Icons.file_upload_outlined),
              title: const Text('Importar archivo'),
              onTap: () => Navigator.pop(sheet, 'import'),
            ),
          ],
        ),
      ),
    );
    if (source == null || !stillHere() || !session.accessAllowed) return;
    final twoSides =
        type.isDriverDocument || type == WalletDocumentType.trafficLicense;
    final scans = <String>[];
    final drafts = <WalletDraft>[];
    final materials = <File>[];
    try {
      final inputs = <WalletDocumentInput>[];
      if (source == 'scan') {
        final files = await platform.scan(maxPages: twoSides ? 2 : 1);
        if (files == null || files.isEmpty) return;
        for (final file in files) {
          scans.add(file.path);
          inputs.add(
            WalletDocumentInput(
              source: file.file,
              originalName: file.originalName,
              mimeType: file.mimeType,
            ),
          );
        }
      } else {
        final picked = await gateway.pickDocument();
        if (picked == null) return;
        inputs.add(
          WalletDocumentInput(
            source: picked.file,
            originalName: picked.originalName,
            mimeType: picked.mimeType,
          ),
        );
      }
      // External activities revoke the visit. Persist only ciphertext before re-authentication.
      drafts.add(await WalletDraft.stage(inputs, key: await keyLoader()));
      if (source == 'scan') {
        await platform.deleteScanTemps(scans);
      } else {
        await gateway.clearTemporaryFiles();
      }
      if (!stillHere()) return;
      if (!session.accessAllowed && !await session.unlock()) return;
      if (!context.mounted || !stillHere()) return;
      if (twoSides && source == 'import' && !drafts.first.files.first.isPdf) {
        final reverse = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: const Text('Reverso del documento'),
            content: const Text(
              'Puedes añadir el reverso o guardar solo el frente.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Solo frente'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Agregar reverso'),
              ),
            ],
          ),
        );
        if (!stillHere() || !session.accessAllowed || reverse == null) return;
        if (reverse == true) {
          final picked = await gateway.pickDocument();
          if (picked != null) {
            final draft = await WalletDraft.stage([
              WalletDocumentInput(
                source: picked.file,
                originalName: picked.originalName,
                mimeType: picked.mimeType,
              ),
            ], key: await keyLoader());
            drafts.add(draft);
            await gateway.clearTemporaryFiles();
            if (draft.files.first.isPdf) {
              throw const FormatException('El reverso debe ser una imagen.');
            }
          }
          if (!stillHere()) return;
          if (!session.accessAllowed && !await session.unlock()) return;
        }
      }
      if (!context.mounted || !stillHere()) return;
      final files = [
        for (final draft in drafts)
          for (var i = 0; i < draft.files.length; i++) (draft, i),
      ];
      final sources = <WalletViewSource>[];
      int? pdfPageCount;
      for (var index = 0; index < files.length; index++) {
        final (draft, i) = files[index];
        sources.add(
          WalletViewSource(
            label: draft.files[i].isPdf
                ? 'PDF'
                : (index == 0 ? 'Frente' : 'Reverso'),
            mimeType: draft.files[i].mimeType,
            readBytes: () => draft.read(i),
            materializePdf: () => draft.materialize(i),
            onPdfPageCount: (count) => pdfPageCount = count,
          ),
        );
      }
      await _pushViewer<bool>(
        isCurrent: isCurrent,
        viewer: WalletViewer(
          title: '$ownerLabel · ${type.label}',
          sources: sources,
          maxPdfPages: twoSides ? 2 : null,
          onSave: () async {
            final epoch = session.epoch;
            if (!stillHere() || !session.isAuthorizedEpoch(epoch)) {
              throw StateError('Wallet locked');
            }
            final ready = <WalletDocumentInput>[];
            try {
              for (final (draft, i) in files) {
                final file = await draft.materialize(i);
                materials.add(file);
                ready.add(
                  WalletDocumentInput(
                    source: file,
                    originalName: draft.files[i].name,
                    mimeType: draft.files[i].mimeType,
                  ),
                );
              }
              await store.saveDocument(
                owner: owner,
                type: type,
                pdf: ready.first.mimeType == 'application/pdf'
                    ? ready.first
                    : null,
                front: ready.first.mimeType == 'application/pdf'
                    ? null
                    : ready.first,
                back: ready.length > 1 ? ready[1] : null,
                metadata: {
                  if (pdfPageCount != null) 'pdfPageCount': '$pdfPageCount',
                },
                isAuthorized: () =>
                    stillHere() && session.isAuthorizedEpoch(epoch),
              );
              container.invalidate(walletDocumentsProvider(owner));
            } finally {
              await Future.wait([
                for (final file in materials) _removeTemporary(file),
              ]);
              materials.clear();
            }
          },
        ),
      );
    } finally {
      await Future.wait<void>([
        for (final draft in drafts) draft.dispose(),
        if (scans.isNotEmpty) platform.deleteScanTemps(scans),
        gateway.clearTemporaryFiles(),
      ]);
    }
  });

  static Future<void> _removeTemporary(File file) async {
    if (await file.exists()) await file.delete();
  }

  Future<T?> _pushViewer<T>({
    required WalletViewer viewer,
    required bool Function() isCurrent,
  }) async {
    if (!isCurrent()) return null;
    final navigator = Navigator.of(context, rootNavigator: true);
    final parentRoute = ModalRoute.of(context);
    final router = GoRouter.maybeOf(context);
    final session = ref.read(walletSessionProvider);
    final route = MaterialPageRoute<T>(builder: (_) => viewer);
    var watching = true;
    var closing = false;
    void closeExpiredVisit() {
      if (!watching || closing || isCurrent()) return;
      closing = true;
      session.lock();
      // Remove only our root viewer, after the locked frame has been built.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (watching && navigator.mounted && route.isActive) {
          navigator.removeRoute(route);
        }
      });
    }

    if (visitRouteName != null) {
      router?.routeInformationProvider.addListener(closeExpiredVisit);
      parentRoute?.popped.then((_) => closeExpiredVisit());
    }
    try {
      return await navigator.push<T>(route);
    } finally {
      watching = false;
      if (visitRouteName != null) {
        router?.routeInformationProvider.removeListener(closeExpiredVisit);
      }
    }
  }

  Future<void> view(WalletDocument document, {String? ownerLabel}) =>
      _run((isCurrent) async {
        final store = ref.read(walletStoreProvider);
        final sources = [
          for (final side in document.sides)
            WalletViewSource(
              label: switch (side) {
                WalletDocumentSide.front => 'Frente',
                WalletDocumentSide.back => 'Reverso',
                WalletDocumentSide.pdf => 'PDF',
              },
              mimeType: document.fileFor(side)!.mimeType,
              readBytes: () async {
                if (!isCurrent()) throw const WalletAuthorizationException();
                final bytes = await store.readDocumentBytes(document, side);
                if (!isCurrent()) {
                  bytes.fillRange(0, bytes.length, 0);
                  throw const WalletAuthorizationException();
                }
                return bytes;
              },
              materializePdf: () async {
                if (!isCurrent()) throw const WalletAuthorizationException();
                final file = await store.decryptForView(document, side);
                if (!isCurrent()) {
                  await _removeTemporary(file);
                  throw const WalletAuthorizationException();
                }
                return file;
              },
            ),
        ];
        try {
          await _pushViewer<void>(
            isCurrent: isCurrent,
            viewer: WalletViewer(
              title: ownerLabel == null
                  ? document.type.label
                  : '$ownerLabel · ${document.type.label}',
              sources: sources,
            ),
          );
        } finally {
          await store.purgeViewerCache();
        }
      });

  Future<void> delete(WalletDocument document) => _run((isCurrent) async {
    final store = ref.read(walletStoreProvider);
    final session = ref.read(walletSessionProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    final epoch = session.epoch;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Eliminar copia'),
        content: const Text(
          'Se eliminará únicamente esta copia privada del dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !isCurrent() ||
        !session.isAuthorizedEpoch(epoch)) {
      return;
    }
    await store.deleteDocument(
      document.id,
      isAuthorized: () => isCurrent() && session.isAuthorizedEpoch(epoch),
    );
    container.invalidate(walletDocumentsProvider(document.owner));
  });

  Future<void> protection({bool firstOffer = false}) {
    if (visitRouteName == null) {
      return _showProtection(firstOffer: firstOffer);
    }
    return _run(
      (isCurrent) =>
          _showProtection(firstOffer: firstOffer, isCurrent: isCurrent),
    );
  }

  Future<void> _showProtection({
    required bool firstOffer,
    bool Function()? isCurrent,
  }) async {
    final session = ref.read(walletSessionProvider);
    await session.initialize();
    bool active() => context.mounted && (isCurrent?.call() ?? true);
    if (!context.mounted || !active()) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => ListenableBuilder(
        listenable: session,
        builder: (sheet, _) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Protección de documentos',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Usa el desbloqueo de tu teléfono para proteger toda la billetera. PicoRadar no recibe ni guarda tu clave.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Quien pueda desbloquear este teléfono podrá abrir ambos conductores. Las copias no tienen respaldo automático.',
                ),
                if (session.failureMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(session.failureMessage!),
                  ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: session.busy
                      ? null
                      : () async {
                          if (!active()) return;
                          final okay = session.protectionEnabled
                              ? await session.disableProtection()
                              : await session.enableProtection();
                          if (okay && sheet.mounted) Navigator.pop(sheet);
                        },
                  icon: Icon(
                    session.protectionEnabled
                        ? Icons.lock_open
                        : Icons.lock_outline,
                  ),
                  label: Text(
                    session.protectionEnabled
                        ? 'Desactivar protección'
                        : 'Proteger documentos',
                  ),
                ),
                if (firstOffer)
                  TextButton(
                    onPressed: session.busy
                        ? null
                        : () async {
                            if (!active()) return;
                            if (await session.dismissOffer() && sheet.mounted) {
                              Navigator.pop(sheet);
                            }
                          },
                    child: const Text('Ahora no'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
