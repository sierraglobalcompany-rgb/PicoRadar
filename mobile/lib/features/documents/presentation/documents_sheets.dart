import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../garage/data/vehicle_profile.dart';
import '../application/wallet_providers.dart';
import '../data/wallet_models.dart';
import 'documents_widgets.dart';
import 'documents_async_content.dart';
import 'documents_recovery_notice.dart';
import 'wallet_actions.dart';
import 'wallet_visit_scope.dart';

export 'documents_driver_sheet.dart' show showWalletDriverSelector;

/// The caller owns WalletAccessGate. A sheet shares that authorized visit;
/// its contents disappear immediately if the session is locked underneath it.
Future<void> showWalletVehicleDocuments(
  BuildContext context,
  WidgetRef ref,
  VehicleProfile vehicle, {
  WalletDocumentType? initialType,
}) async {
  if (!ref.read(walletSessionProvider).accessAllowed) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => DocumentsSessionSheet(
      child: _VehicleDocumentsSheet(vehicle: vehicle, initialType: initialType),
    ),
  );
}

Future<void> showWalletDocumentMenu(
  BuildContext context,
  WidgetRef ref,
  WalletDocument document, {
  required String ownerLabel,
}) async {
  final session = ref.read(walletSessionProvider);
  final epoch = session.epoch;
  if (!session.accessAllowed) return;
  final choice = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => DocumentsSessionSheet(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              walletDocumentLabel(document.type),
              style: documentsStrongStyle,
            ),
            const SizedBox(height: 8),
            if (document.pdf != null)
              ListTile(
                minTileHeight: 48,
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('Reemplazar PDF', style: documentsTextStyle),
                onTap: () => Navigator.of(context).pop('pdf'),
              )
            else ...[
              ListTile(
                minTileHeight: 48,
                leading: const Icon(Icons.flip_to_front_outlined),
                title: Text(
                  document.front == null
                      ? 'Agregar frente'
                      : 'Reemplazar frente',
                  style: documentsTextStyle,
                ),
                onTap: () => Navigator.of(context).pop('front'),
              ),
              if (document.type.supportsTwoSides && document.front != null)
                ListTile(
                  minTileHeight: 48,
                  leading: const Icon(Icons.flip_to_back_outlined),
                  title: Text(
                    document.back == null
                        ? 'Agregar reverso'
                        : 'Reemplazar reverso',
                    style: documentsTextStyle,
                  ),
                  onTap: () => Navigator.of(context).pop('back'),
                ),
            ],
            ListTile(
              minTileHeight: 48,
              leading: const Icon(Icons.delete_outline, color: AppColors.red),
              title: const Text(
                'Eliminar documento completo',
                style: documentsTextStyle,
              ),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted || !session.isAuthorizedEpoch(epoch)) return;
  final actions = WalletActions(context, ref);
  final side = switch (choice) {
    'front' => WalletDocumentSide.front,
    'back' => WalletDocumentSide.back,
    'pdf' => WalletDocumentSide.pdf,
    _ => null,
  };
  if (side != null) {
    await actions.add(
      document.owner,
      document.type,
      ownerLabel: ownerLabel,
      document: document,
      side: side,
    );
  } else if (choice == 'delete') {
    await actions.delete(document);
  }
}

class DocumentsSessionSheet extends ConsumerStatefulWidget {
  const DocumentsSessionSheet({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<DocumentsSessionSheet> createState() =>
      _DocumentsSessionSheetState();
}

class _DocumentsSessionSheetState extends ConsumerState<DocumentsSessionSheet> {
  bool _opened = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(walletSessionProvider);
    return WalletVisitScope(
      child: ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          final allowed = session.accessAllowed;
          if (allowed) _opened = true;
          return Stack(
            children: [
              if (_opened)
                Offstage(
                  offstage: !allowed,
                  child: ExcludeFocus(
                    excluding: !allowed,
                    child: ExcludeSemantics(
                      excluding: !allowed,
                      child: TickerMode(enabled: allowed, child: widget.child),
                    ),
                  ),
                ),
              if (!allowed)
                Material(
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_outline, color: AppColors.teal),
                          const SizedBox(height: 16),
                          const Text(
                            'Documentos bloqueados',
                            style: documentsStrongStyle,
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text(
                              'Cerrar',
                              style: documentsStrongStyle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _VehicleDocumentsSheet extends ConsumerStatefulWidget {
  const _VehicleDocumentsSheet({required this.vehicle, this.initialType});
  final VehicleProfile vehicle;
  final WalletDocumentType? initialType;

  @override
  ConsumerState<_VehicleDocumentsSheet> createState() =>
      _VehicleDocumentsSheetState();
}

class _VehicleDocumentsSheetState
    extends ConsumerState<_VehicleDocumentsSheet> {
  final _initialRow = GlobalKey();
  bool _initialFocused = false;

  @override
  Widget build(BuildContext context) {
    final owner = WalletOwner.vehicle(widget.vehicle.id);
    final documents = ref.watch(walletDocumentsProvider(owner));
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          key: const ValueKey('documents-vehicle-sheet-scroll'),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      walletVehicleLabel(widget.vehicle),
                      style: documentsStrongStyle,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar documentos del vehículo',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(widget.vehicle.plate, style: documentsTextStyle),
              const SizedBox(height: 8),
              DocumentsRecoveryNotice(owner: owner),
              DocumentsAsyncContent(
                value: documents,
                loadingLabel: 'Cargando copias privadas',
                errorLabel: 'No se pudieron leer las copias de este vehículo.',
                onRetry: () => ref.invalidate(walletDocumentsProvider(owner)),
                builder: (items) {
                  if (!_initialFocused && widget.initialType != null) {
                    _initialFocused = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final row = _initialRow.currentContext;
                      if (mounted && row != null) Scrollable.ensureVisible(row);
                    });
                  }
                  return Column(
                    children: [
                      for (final type in const [
                        WalletDocumentType.trafficLicense,
                        WalletDocumentType.soat,
                        WalletDocumentType.rtm,
                        WalletDocumentType.voluntaryInsurance,
                        WalletDocumentType.salePurchase,
                        WalletDocumentType.appraisal,
                        WalletDocumentType.other,
                      ])
                        _VehicleDocumentRow(
                          key: type == widget.initialType
                              ? _initialRow
                              : ValueKey('documents-row-${type.name}'),
                          owner: owner,
                          type: type,
                          document: items
                              .where((item) => item.type == type)
                              .firstOrNull,
                          ownerLabel: walletVehicleLabel(widget.vehicle),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehicleDocumentRow extends ConsumerWidget {
  const _VehicleDocumentRow({
    required this.owner,
    required this.type,
    required this.document,
    required this.ownerLabel,
    super.key,
  });
  final WalletOwner owner;
  final WalletDocumentType type;
  final WalletDocument? document;
  final String ownerLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = WalletActions(context, ref);
    final saved = document;
    void open() {
      if (saved == null) {
        actions.add(owner, type, ownerLabel: ownerLabel);
      } else {
        actions.view(saved);
      }
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: open,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 64),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          walletDocumentLabel(type),
                          style: documentsStrongStyle,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          walletDocumentStatus(saved),
                          style: documentsTextStyle,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              key: ValueKey(
                'documents-vehicle-${saved == null ? 'add' : 'open'}-${type.name}',
              ),
              tooltip:
                  '${saved == null ? 'Agregar' : 'Abrir'} ${walletDocumentLabel(type)}',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: open,
              icon: Icon(
                saved == null ? Icons.add : Icons.visibility_outlined,
                color: AppColors.teal,
              ),
            ),
            if (saved != null)
              IconButton(
                key: ValueKey('documents-vehicle-menu-${type.name}'),
                tooltip: 'Opciones de ${walletDocumentLabel(type)}',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: () => showWalletDocumentMenu(
                  context,
                  ref,
                  saved,
                  ownerLabel: ownerLabel,
                ),
                icon: const Icon(Icons.more_vert),
              ),
          ],
        ),
        const Divider(height: 1, color: AppColors.border),
      ],
    );
  }
}
