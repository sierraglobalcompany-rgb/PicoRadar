import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../documents/application/wallet_providers.dart';
import '../../documents/data/wallet_models.dart';
import '../../documents/presentation/wallet_access_gate.dart';
import '../../documents/presentation/wallet_actions.dart';

const _documentTypes = [
  WalletDocumentType.trafficLicense,
  WalletDocumentType.soat,
  WalletDocumentType.rtm,
  WalletDocumentType.appraisal,
  WalletDocumentType.salePurchase,
  WalletDocumentType.other,
];

final _preparationReadyProvider = FutureProvider.autoDispose
    .family<bool, String>((ref, id) async {
      final session = ref.watch(walletSessionProvider);
      session.addListener(ref.invalidateSelf);
      ref.onDispose(() => session.removeListener(ref.invalidateSelf));
      final epoch = session.epoch;
      bool authorized() => ref.mounted && session.isAuthorizedEpoch(epoch);
      if (!authorized()) throw StateError('Wallet locked');
      final store = ref.watch(walletStoreProvider);
      await store.initialize();
      await store.ensurePreparation(id, isAuthorized: authorized);
      final exists = await store.preparationExists(id);
      if (!authorized()) throw StateError('Wallet locked');
      return exists;
    });

/// Push inside the shell with RouteSettings(name: '/purchase-documents').
/// The caller must persist a stable preparation ID before opening. The owner
/// is ensured in WalletStore only after the gate authorizes this visit.
/// This screen never creates a vehicle or duplicates a document attachment.
class PurchaseDocumentsScreen extends StatelessWidget {
  const PurchaseDocumentsScreen({
    required this.preparationId,
    required this.ownerLabel,
    this.initialType,
    this.legacyAttachmentClaim = false,
    super.key,
  });

  static const routeName = '/purchase-documents';

  final String preparationId;
  final String ownerLabel;
  final WalletDocumentType? initialType;
  final bool legacyAttachmentClaim;

  @override
  Widget build(BuildContext context) => WalletAccessGate(
    key: ValueKey('purchase-documents-$preparationId'),
    visitRouteName: routeName,
    child: _PurchaseDocumentsContent(
      preparationId: preparationId,
      ownerLabel: ownerLabel,
      initialType: initialType,
      legacyAttachmentClaim: legacyAttachmentClaim,
    ),
  );
}

class _PurchaseDocumentsContent extends ConsumerWidget {
  const _PurchaseDocumentsContent({
    required this.preparationId,
    required this.ownerLabel,
    required this.initialType,
    required this.legacyAttachmentClaim,
  });

  final String preparationId;
  final String ownerLabel;
  final WalletDocumentType? initialType;
  final bool legacyAttachmentClaim;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = WalletOwner.preparation(preparationId);
    final ready = ref.watch(_preparationReadyProvider(preparationId));
    final actions = WalletActions(
      context,
      ref,
      visitRouteName: PurchaseDocumentsScreen.routeName,
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Documentos'),
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Protecci\u00f3n de documentos',
            icon: const Icon(Icons.lock_outline),
            onPressed: () => actions.protection(),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ready.when(
          skipLoadingOnRefresh: false,
          skipLoadingOnReload: false,
          loading: _loading,
          error: (_, _) => _Retry(
            message: 'No se pudo abrir esta preparaci\u00f3n.',
            onRetry: () =>
                ref.invalidate(_preparationReadyProvider(preparationId)),
          ),
          data: (exists) {
            if (!exists) {
              return _Retry(
                message: 'Esta preparaci\u00f3n ya no est\u00e1 disponible.',
                onRetry: () =>
                    ref.invalidate(_preparationReadyProvider(preparationId)),
              );
            }
            final documents = ref.watch(walletDocumentsProvider(owner));
            return documents.when(
              skipLoadingOnRefresh: false,
              skipLoadingOnReload: false,
              loading: _loading,
              error: (_, _) => _Retry(
                message: 'No se pudieron cargar las copias.',
                onRetry: () => ref.invalidate(walletDocumentsProvider(owner)),
              ),
              data: (loaded) {
                final copies = loaded
                    .where(
                      (copy) =>
                          copy.owner == owner &&
                          _documentTypes.contains(copy.type),
                    )
                    .toList();
                final count = copies
                    .where((copy) => copy.sides.isNotEmpty)
                    .length;
                final hasTrafficLicense = copies.any(
                  (copy) =>
                      copy.type == WalletDocumentType.trafficLicense &&
                      copy.sides.isNotEmpty,
                );
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(ownerLabel, style: AppTextStyles.h2),
                    const SizedBox(height: 8),
                    Text(
                      count == 1 ? '1 copia local' : '$count copias locales',
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Copias de respaldo. No sustituyen los documentos oficiales.',
                    ),
                    if (legacyAttachmentClaim && !hasTrafficLicense) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Copia pendiente de importar',
                        key: ValueKey('purchase-documents-legacy'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    for (final type in _documentTypes)
                      _DocumentRow(
                        type: type,
                        document: copies
                            .where((copy) => copy.type == type)
                            .firstOrNull,
                        initiallyExpanded: type == initialType,
                        onAdd: () =>
                            actions.add(owner, type, ownerLabel: ownerLabel),
                        onView: (document) =>
                            actions.view(document, ownerLabel: ownerLabel),
                        onDelete: actions.delete,
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  static Widget _loading() => const Center(
    child: CircularProgressIndicator(
      semanticsLabel: 'Cargando documentos',
      key: ValueKey('purchase-documents-loading'),
    ),
  );
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({
    required this.type,
    required this.document,
    required this.initiallyExpanded,
    required this.onAdd,
    required this.onView,
    required this.onDelete,
  });

  final WalletDocumentType type;
  final WalletDocument? document;
  final bool initiallyExpanded;
  final VoidCallback onAdd;
  final ValueChanged<WalletDocument> onView;
  final ValueChanged<WalletDocument> onDelete;

  @override
  Widget build(BuildContext context) {
    final copy = document;
    final hasCopy = copy != null && copy.sides.isNotEmpty;
    return ExpansionTile(
      key: ValueKey('purchase-document-${type.value}'),
      tilePadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      childrenPadding: const EdgeInsets.only(bottom: 12),
      initiallyExpanded: initiallyExpanded,
      leading: Icon(
        hasCopy ? Icons.description_outlined : Icons.note_add_outlined,
        color: hasCopy ? AppColors.teal : AppColors.navy,
      ),
      title: Text(type.label, style: AppTextStyles.bodyStrong),
      subtitle: Text(_copyStatus(copy)),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (hasCopy)
                FilledButton.icon(
                  key: ValueKey('purchase-view-${type.value}'),
                  onPressed: () => onView(copy),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Ver copia'),
                ),
              OutlinedButton.icon(
                key: ValueKey('purchase-add-${type.value}'),
                onPressed: onAdd,
                icon: Icon(hasCopy ? Icons.swap_horiz : Icons.add),
                label: Text(hasCopy ? 'Reemplazar' : 'Agregar copia'),
              ),
              if (copy != null)
                IconButton(
                  key: ValueKey('purchase-delete-${type.value}'),
                  tooltip: 'Eliminar copia',
                  onPressed: () => onDelete(copy),
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static String _copyStatus(WalletDocument? document) {
    if (document == null || document.sides.isEmpty) return 'Sin copia';
    if (document.pdf != null) {
      final pages = int.tryParse(document.metadata['pdfPageCount'] ?? '');
      if (pages == null || pages < 1) return 'PDF guardado';
      return pages == 1
          ? 'PDF \u00b7 1 p\u00e1gina'
          : 'PDF \u00b7 $pages p\u00e1ginas';
    }
    if (document.front != null && document.back != null) {
      return 'Frente y reverso \u00b7 2 im\u00e1genes';
    }
    return document.front != null ? 'Solo frente' : 'Solo reverso';
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const ValueKey('purchase-documents-retry'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    ),
  );
}
