import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../application/wallet_providers.dart';
import '../data/wallet_models.dart';
import 'documents_async_content.dart';
import 'documents_recovery_notice.dart';
import 'documents_sheets.dart'
    show DocumentsSessionSheet, showWalletDocumentMenu;
import 'documents_widgets.dart';
import 'wallet_actions.dart';

Future<void> showWalletDriverManagement(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!ref.read(walletSessionProvider).accessAllowed) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const DocumentsSessionSheet(child: _DriverSelector()),
  );
}

Future<String?> showWalletDriverSelector(
  BuildContext context,
  WidgetRef ref,
  String selectedId,
) async {
  if (!ref.read(walletSessionProvider).accessAllowed) return null;
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) =>
        DocumentsSessionSheet(child: _DriverSelector(selectedId: selectedId)),
  );
}

class _DriverSelector extends ConsumerStatefulWidget {
  const _DriverSelector({this.selectedId});
  final String? selectedId;
  bool get managementOnly => selectedId == null;

  @override
  ConsumerState<_DriverSelector> createState() => _DriverSelectorState();
}

class _DriverSelectorState extends ConsumerState<_DriverSelector> {
  bool _busy = false;
  String? _error;

  Future<void> _edit([WalletDriver? driver]) async {
    if (_busy) return;
    final session = ref.read(walletSessionProvider);
    if (!session.accessAllowed) return;
    final epoch = session.epoch;
    setState(() => _busy = true);
    try {
      final saved = await showDialog<WalletDriver>(
        context: context,
        builder: (_) =>
            DocumentsSessionSheet(child: _DriverNameDialog(driver: driver)),
      );
      if (!mounted || saved == null || !session.isAuthorizedEpoch(epoch)) {
        return;
      }
      if (!widget.managementOnly) Navigator.of(context).pop(saved.id);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openDocuments(WalletDriver driver) async {
    if (_busy || !ref.read(walletSessionProvider).accessAllowed) return;
    setState(() => _busy = true);
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) =>
            DocumentsSessionSheet(child: _DriverDocumentsSheet(driver: driver)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _principalMenu(WalletDriver driver) async {
    if (_busy) return;
    final session = ref.read(walletSessionProvider);
    if (!session.accessAllowed) return;
    final epoch = session.epoch;
    final clear = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => DocumentsSessionSheet(
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ListTile(
              minTileHeight: 48,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_outline, color: AppColors.red),
              title: const Text(
                'Eliminar copias del conductor',
                style: documentsStrongStyle,
              ),
              onTap: () => Navigator.of(context).pop(true),
            ),
          ),
        ),
      ),
    );
    if (!mounted || clear != true || !session.isAuthorizedEpoch(epoch)) return;
    await _delete(driver);
  }

  Future<void> _delete(WalletDriver driver) async {
    if (_busy) return;
    final session = ref.read(walletSessionProvider);
    if (!session.accessAllowed) return;
    final epoch = session.epoch;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => DocumentsSessionSheet(
        child: AlertDialog(
          scrollable: true,
          title: Text(
            driver.isPrincipal
                ? 'Eliminar copias del conductor'
                : 'Eliminar conductor',
            style: documentsStrongStyle,
          ),
          content: Text(
            driver.isPrincipal
                ? 'Se eliminarán todas las copias personales de este conductor en este dispositivo. El perfil se conserva y vuelve a llamarse Principal. Las copias del segundo conductor y de los vehículos se conservan.'
                : 'Se eliminarán ${driver.displayName} y sus copias personales de este dispositivo. Los documentos de los vehículos se conservan.',
            style: documentsTextStyle,
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar', style: documentsStrongStyle),
            ),
            TextButton(
              key: const ValueKey('documents-driver-delete-confirm'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                driver.isPrincipal ? 'Eliminar copias' : 'Eliminar',
                style: documentsStrongStyle.copyWith(color: AppColors.red),
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || confirmed != true || !session.isAuthorizedEpoch(epoch)) {
      return;
    }
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(walletStoreProvider)
          .deleteDriver(
            driver.id,
            isAuthorized: () => session.isAuthorizedEpoch(epoch),
          );
      container.invalidate(walletDriversProvider);
      container.invalidate(
        walletDocumentsProvider(WalletOwner.driver(driver.id)),
      );
      if (!mounted || !session.isAuthorizedEpoch(epoch)) return;
      if (!widget.managementOnly) Navigator.of(context).pop();
    } catch (_) {
      if (mounted && session.isAuthorizedEpoch(epoch)) {
        setState(
          () => _error = driver.isPrincipal
              ? 'No se pudieron eliminar las copias del conductor. Intenta de nuevo.'
              : 'No se pudo eliminar el conductor. Intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final drivers = ref.watch(walletDriversProvider);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.managementOnly
                        ? 'Gestionar conductores'
                        : 'Conductor',
                    style: documentsStrongStyle,
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar conductores',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_error != null)
              Text(
                _error!,
                style: documentsTextStyle.copyWith(color: AppColors.red),
              ),
            DocumentsAsyncContent(
              value: drivers,
              loadingLabel: 'Cargando conductores',
              errorLabel: 'No se pudieron leer los conductores.',
              onRetry: () => ref.invalidate(walletDriversProvider),
              builder: (items) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final driver in [
                    ...items.where((driver) => driver.isPrincipal),
                    ...items.where((driver) => !driver.isPrincipal),
                  ])
                    Row(
                      key: ValueKey('documents-driver-row-${driver.id}'),
                      children: [
                        Expanded(
                          child: ListTile(
                            key: ValueKey(
                              'documents-driver-${widget.managementOnly ? 'manage' : 'select'}-${driver.id}',
                            ),
                            contentPadding: EdgeInsets.zero,
                            minTileHeight: 48,
                            leading: widget.managementOnly
                                ? Text(
                                    driver.isPrincipal ? '1' : '2',
                                    style: documentsStrongStyle,
                                  )
                                : Icon(
                                    driver.id == widget.selectedId
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    color: AppColors.teal,
                                  ),
                            title: Text(
                              driver.displayName,
                              style: documentsStrongStyle,
                            ),
                            onTap: _busy
                                ? null
                                : () {
                                    if (widget.managementOnly) {
                                      _openDocuments(driver);
                                    } else if (ref
                                        .read(walletSessionProvider)
                                        .accessAllowed) {
                                      Navigator.of(context).pop(driver.id);
                                    }
                                  },
                          ),
                        ),
                        if (driver.isPrincipal && !widget.managementOnly)
                          IconButton(
                            key: ValueKey('documents-driver-menu-${driver.id}'),
                            tooltip: 'Opciones de ${driver.displayName}',
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            onPressed: _busy
                                ? null
                                : () => _principalMenu(driver),
                            icon: const Icon(Icons.more_vert),
                          ),
                        if (widget.managementOnly || !driver.isPrincipal) ...[
                          IconButton(
                            key: ValueKey(
                              'documents-driver-rename-${driver.id}',
                            ),
                            tooltip: 'Cambiar nombre de ${driver.displayName}',
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            onPressed: _busy ? null : () => _edit(driver),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            key: ValueKey(
                              'documents-driver-delete-${driver.id}',
                            ),
                            tooltip: driver.isPrincipal
                                ? 'Eliminar copias de ${driver.displayName}'
                                : 'Eliminar ${driver.displayName}',
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            onPressed: _busy ? null : () => _delete(driver),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.red,
                            ),
                          ),
                        ],
                      ],
                    ),
                  if (!items.any((driver) => !driver.isPrincipal))
                    TextButton.icon(
                      key: const ValueKey('documents-driver-add'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: _busy ? null : _edit,
                      icon: const Icon(Icons.person_add_alt),
                      label: const Text(
                        'Agregar conductor',
                        style: documentsStrongStyle,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverDocumentsSheet extends ConsumerWidget {
  const _DriverDocumentsSheet({required this.driver});
  final WalletDriver driver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = WalletOwner.driver(driver.id);
    final documents = ref.watch(walletDocumentsProvider(owner));
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          key: ValueKey('documents-driver-sheet-${driver.id}'),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${driver.isPrincipal ? 1 : 2}. ${driver.displayName}',
                      style: documentsStrongStyle,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar documentos del conductor',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              DocumentsRecoveryNotice(owner: owner),
              DocumentsAsyncContent(
                value: documents,
                loadingLabel: 'Cargando copias privadas',
                errorLabel: 'No se pudieron leer las copias de este conductor.',
                onRetry: () => ref.invalidate(walletDocumentsProvider(owner)),
                builder: (items) => Column(
                  children: [
                    for (final type in const [
                      WalletDocumentType.driverLicense,
                      WalletDocumentType.identityCard,
                    ])
                      _DriverDocumentRow(
                        key: ValueKey(
                          'documents-driver-${driver.id}-${type.name}',
                        ),
                        owner: owner,
                        ownerLabel: driver.displayName,
                        type: type,
                        document: items
                            .where(
                              (item) =>
                                  item.owner == owner && item.type == type,
                            )
                            .firstOrNull,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverDocumentRow extends ConsumerWidget {
  const _DriverDocumentRow({
    required this.owner,
    required this.ownerLabel,
    required this.type,
    required this.document,
    super.key,
  });
  final WalletOwner owner;
  final String ownerLabel;
  final WalletDocumentType type;
  final WalletDocument? document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = document;
    final actions = WalletActions(context, ref);
    void open() {
      if (!ref.read(walletSessionProvider).accessAllowed) return;
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
                'documents-driver-${owner.id}-${saved == null ? 'add' : 'open'}-${type.name}',
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
                key: ValueKey('documents-driver-${owner.id}-menu-${type.name}'),
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

class _DriverNameDialog extends ConsumerStatefulWidget {
  const _DriverNameDialog({this.driver});
  final WalletDriver? driver;

  @override
  ConsumerState<_DriverNameDialog> createState() => _DriverNameDialogState();
}

class _DriverNameDialogState extends ConsumerState<_DriverNameDialog> {
  late final TextEditingController _name;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.driver?.displayName ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Escribe un nombre.');
      return;
    }
    final session = ref.read(walletSessionProvider);
    if (!session.accessAllowed) return;
    final epoch = session.epoch;
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final driver = await ref
          .read(walletStoreProvider)
          .saveDriver(
            id: widget.driver?.id,
            displayName: name,
            isAuthorized: () => session.isAuthorizedEpoch(epoch),
          );
      container.invalidate(walletDriversProvider);
      if (!mounted || !session.isAuthorizedEpoch(epoch)) return;
      Navigator.of(context).pop(driver);
    } catch (_) {
      if (mounted && session.isAuthorizedEpoch(epoch)) {
        setState(
          () => _error = 'No se pudo guardar el nombre. Intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.driver == null ? 'Agregar conductor' : 'Cambiar nombre',
      style: documentsStrongStyle,
    ),
    content: TextField(
      key: const ValueKey('documents-driver-name'),
      controller: _name,
      enabled: !_busy,
      autofocus: true,
      autocorrect: false,
      enableSuggestions: false,
      maxLength: 100,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.done,
      style: documentsTextStyle,
      decoration: InputDecoration(
        labelText: 'Nombre local',
        errorText: _error,
        errorMaxLines: 4,
      ),
      onSubmitted: (_) => _save(),
    ),
    actions: [
      TextButton(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: _busy ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancelar', style: documentsStrongStyle),
      ),
      FilledButton(
        key: const ValueKey('documents-driver-save'),
        style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: _busy ? null : _save,
        child: Text(
          _busy ? 'Guardando' : 'Guardar',
          style: documentsStrongStyle.copyWith(color: Colors.white),
        ),
      ),
    ],
  );
}
