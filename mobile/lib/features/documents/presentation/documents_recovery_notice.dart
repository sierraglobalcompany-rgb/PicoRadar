import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../application/wallet_providers.dart';
import '../data/wallet_models.dart';
import 'documents_widgets.dart';

class DocumentsRecoveryNotice extends ConsumerStatefulWidget {
  const DocumentsRecoveryNotice({required this.owner, super.key});
  final WalletOwner owner;

  @override
  ConsumerState<DocumentsRecoveryNotice> createState() =>
      _DocumentsRecoveryNoticeState();
}

class _DocumentsRecoveryNoticeState
    extends ConsumerState<DocumentsRecoveryNotice> {
  bool _busy = false;
  bool _failed = false;

  Future<void> _retry() async {
    final session = ref.read(walletSessionProvider);
    if (_busy || !session.accessAllowed) return;
    final epoch = session.epoch;
    final store = ref.read(walletStoreProvider);
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await store.retryPendingCleanup();
      if (!mounted || !session.isAuthorizedEpoch(epoch)) return;
      ref.invalidate(walletDriversProvider);
      ref.invalidate(walletDocumentsProvider(widget.owner));
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(walletDocumentsProvider(widget.owner));
    final report = ref.watch(walletStoreProvider).migrationReport;
    if (!report.needsRecovery && !_failed) return const SizedBox.shrink();
    return Padding(
      key: const ValueKey('documents-recovery-warning'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.warning_amber_outlined,
                color: AppColors.orange,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _failed
                      ? 'No se pudo completar la recuperación. Intenta de nuevo.'
                      : 'Hay copias que requieren recuperación o una limpieza pendiente. La lista puede estar incompleta.',
                  style: documentsTextStyle,
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('documents-recovery-retry'),
              onPressed: _busy ? null : _retry,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: const Icon(Icons.refresh),
              label: Text(
                _busy ? 'Reintentando' : 'Reintentar',
                style: documentsStrongStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
