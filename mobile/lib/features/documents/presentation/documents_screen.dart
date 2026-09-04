import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_tokens.dart';
import '../../garage/data/vehicle_profile.dart';
import '../../garage/presentation/vehicle_display.dart';
import '../../vehicle_status/data/private_vehicle_document_store.dart';

const vehicleDocumentPrivateCopy = 'Copia privada cifrada en este dispositivo.';
const vehicleDocumentOfficialWarning =
    'Guardar un archivo no confirma su vigencia oficial.';

final vehicleDocumentsProvider =
    FutureProvider.family<List<PrivateVehicleDocumentMetadata>, String>((
      ref,
      vehicleId,
    ) {
      return ref
          .watch(privateVehicleDocumentStoreProvider)
          .listForVehicle(vehicleId);
    });

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen(this.vehicleId, {super.key});

  final String? vehicleId;

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  PrivateVehicleDocumentType _selectedType =
      PrivateVehicleDocumentType.trafficLicense;
  String? _visibleError;

  @override
  Widget build(BuildContext context) {
    final vehicleId = widget.vehicleId?.trim();
    if (vehicleId == null || vehicleId.isEmpty) {
      return const _NoVehicleState();
    }

    final vehicles = ref.watch(vehicleListProvider);
    final documents = ref.watch(vehicleDocumentsProvider(vehicleId));

    return vehicles.when(
      data: (items) {
        final vehicle = _findVehicle(items, vehicleId);
        if (vehicle == null) {
          return const _NoVehicleState();
        }
        return documents.when(
          data: (metadata) => _DocumentsContent(
            vehicle: vehicle,
            documents: metadata,
            selectedType: _selectedType,
            visibleError: _visibleError,
            onTypeChanged: (value) => setState(() {
              _selectedType = value;
              _visibleError = null;
            }),
            onAttach: _attachDocument,
            onView: _viewDocument,
            onDelete: _deleteDocument,
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _DocumentsContent(
            vehicle: vehicle,
            documents: const [],
            selectedType: _selectedType,
            visibleError: 'No se pudo leer la billetera cifrada. Puedes reemplazar el archivo afectado.',
            onTypeChanged: (value) => setState(() => _selectedType = value),
            onAttach: _attachDocument,
            onView: _viewDocument,
            onDelete: _deleteDocument,
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const _NoVehicleState(),
    );
  }

  Future<void> _attachDocument(PrivateVehicleDocumentType type) async {
    final vehicleId = widget.vehicleId?.trim();
    if (vehicleId == null || vehicleId.isEmpty) {
      return;
    }
    final gateway = ref.read(vehicleDocumentGatewayProvider);
    try {
      final picked = await gateway.pickDocument();
      if (picked == null) {
        return;
      }
      await ref
          .read(privateVehicleDocumentStoreProvider)
          .replaceDocument(
            vehicleId: vehicleId,
            documentType: type,
            source: picked.file,
            originalName: picked.originalName,
            mimeType: picked.mimeType,
          );
      ref.invalidate(vehicleDocumentsProvider(vehicleId));
      ref.invalidate(privateVehicleDocumentProvider((vehicleId, type)));
      if (mounted) {
        setState(() => _visibleError = null);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _visibleError =
              'No se pudo guardar la copia cifrada. Intenta reemplazarla.',
        );
      }
    } finally {
      await gateway.clearTemporaryFiles();
    }
  }

  Future<void> _viewDocument(PrivateVehicleDocumentMetadata metadata) async {
    try {
      final file = await ref
          .read(privateVehicleDocumentStoreProvider)
          .decryptForView(metadata);
      final opened = await ref
          .read(vehicleDocumentGatewayProvider)
          .openDocument(file);
      if (!opened) {
        await ref
            .read(privateVehicleDocumentStoreProvider)
            .purgeViewerCache(metadata: metadata);
        throw const FileSystemException('External document viewer failed.');
      }
      if (mounted) {
        setState(() => _visibleError = null);
      }
    } catch (_) {
      await ref
          .read(privateVehicleDocumentStoreProvider)
          .purgeViewerCache(metadata: metadata);
      if (mounted) {
        setState(
          () => _visibleError =
              'No se pudo abrir la copia cifrada. Puedes reemplazarla.',
        );
      }
    }
  }

  Future<void> _deleteDocument(PrivateVehicleDocumentMetadata metadata) async {
    try {
      await ref.read(privateVehicleDocumentStoreProvider).delete(metadata);
      ref.invalidate(vehicleDocumentsProvider(metadata.vehicleId));
      ref.invalidate(
        privateVehicleDocumentProvider((
          metadata.vehicleId,
          metadata.documentType,
        )),
      );
      if (mounted) {
        setState(() => _visibleError = null);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _visibleError =
              'No se pudo eliminar la copia local. Intenta de nuevo.',
        );
      }
    }
  }
}

class _DocumentsContent extends StatelessWidget {
  const _DocumentsContent({
    required this.vehicle,
    required this.documents,
    required this.selectedType,
    required this.visibleError,
    required this.onTypeChanged,
    required this.onAttach,
    required this.onView,
    required this.onDelete,
  });

  final VehicleProfile vehicle;
  final List<PrivateVehicleDocumentMetadata> documents;
  final PrivateVehicleDocumentType selectedType;
  final String? visibleError;
  final ValueChanged<PrivateVehicleDocumentType> onTypeChanged;
  final ValueChanged<PrivateVehicleDocumentType> onAttach;
  final ValueChanged<PrivateVehicleDocumentMetadata> onView;
  final ValueChanged<PrivateVehicleDocumentMetadata> onDelete;

  @override
  Widget build(BuildContext context) {
    final byType = {
      for (final document in documents) document.documentType: document,
    };
    final selected = byType[selectedType];
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          key: const ValueKey('documents-screen-scroll'),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.m,
            AppSpacing.m,
            AppSpacing.m,
            AppSpacing.xxl,
          ),
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(vehicle: vehicle),
                    const SizedBox(height: AppSpacing.m),
                    _Notice(message: vehicleDocumentPrivateCopy),
                    const SizedBox(height: AppSpacing.s),
                    _Notice(message: vehicleDocumentOfficialWarning),
                    if (visibleError != null) ...[
                      const SizedBox(height: AppSpacing.m),
                      _ErrorNotice(message: visibleError!),
                    ],
                    const SizedBox(height: AppSpacing.l),
                    DropdownButtonFormField<PrivateVehicleDocumentType>(
                      key: const ValueKey('documents-type-selector'),
                      initialValue: selectedType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de documento',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final type in PrivateVehicleDocumentType.values)
                          DropdownMenuItem(
                            value: type,
                            child: Text(
                              type.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      selectedItemBuilder: (context) => [
                        for (final type in PrivateVehicleDocumentType.values)
                          Text(type.label, overflow: TextOverflow.ellipsis),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          onTypeChanged(value);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.m),
                    _SelectedDocumentCard(
                      type: selectedType,
                      metadata: selected,
                      onAttach: () => onAttach(selectedType),
                      onView: selected == null ? null : () => onView(selected),
                      onDelete: selected == null
                          ? null
                          : () => onDelete(selected),
                    ),
                    const SizedBox(height: AppSpacing.l),
                    Text('Copias guardadas', style: AppTextStyles.h2),
                    const SizedBox(height: AppSpacing.s),
                    for (final type in PrivateVehicleDocumentType.values) ...[
                      _DocumentRow(
                        type: type,
                        metadata: byType[type],
                        onAttach: () => onAttach(type),
                        onView: byType[type] == null
                            ? null
                            : () => onView(byType[type]!),
                        onDelete: byType[type] == null
                            ? null
                            : () => onDelete(byType[type]!),
                      ),
                      const SizedBox(height: AppSpacing.s),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.vehicle});

  final VehicleProfile vehicle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Row(
          children: [
            _PlateMark(vehicle: vehicle),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Documentos vehiculares', style: AppTextStyles.h1),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    vehicle.nickname?.trim().isNotEmpty == true
                        ? vehicle.nickname!.trim()
                        : vehicle.plate,
                    style: AppTextStyles.caption,
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

class _PlateMark extends StatelessWidget {
  const _PlateMark({required this.vehicle});

  final VehicleProfile vehicle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: vehicleAccent(vehicle).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s),
        child: Icon(
          vehicleIcon(vehicle),
          color: vehicleAccent(vehicle),
          size: AppIconSize.m,
        ),
      ),
    );
  }
}

class _SelectedDocumentCard extends StatelessWidget {
  const _SelectedDocumentCard({
    required this.type,
    required this.metadata,
    required this.onAttach,
    required this.onView,
    required this.onDelete,
  });

  final PrivateVehicleDocumentType type;
  final PrivateVehicleDocumentMetadata? metadata;
  final VoidCallback onAttach;
  final VoidCallback? onView;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final hasDocument = metadata != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(type.label, style: AppTextStyles.h2),
            const SizedBox(height: AppSpacing.s),
            Text(
              hasDocument
                  ? 'Copia guardada: ${metadata!.originalName}'
                  : 'Sin copia guardada.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.m),
            Wrap(
              spacing: AppSpacing.s,
              runSpacing: AppSpacing.s,
              children: [
                FilledButton.icon(
                  key: ValueKey(
                    hasDocument
                        ? 'documents-replace-${type.value}'
                        : 'documents-import-${type.value}',
                  ),
                  onPressed: onAttach,
                  icon: Icon(hasDocument ? Icons.swap_horiz : Icons.add),
                  label: Text(hasDocument ? 'Reemplazar' : 'Adjuntar'),
                ),
                if (hasDocument)
                  OutlinedButton.icon(
                    key: ValueKey('documents-open-${type.value}'),
                    onPressed: onView,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Ver'),
                  ),
                if (hasDocument)
                  TextButton.icon(
                    key: ValueKey('documents-delete-${type.value}'),
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Eliminar'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({
    required this.type,
    required this.metadata,
    required this.onAttach,
    required this.onView,
    required this.onDelete,
  });

  final PrivateVehicleDocumentType type;
  final PrivateVehicleDocumentMetadata? metadata;
  final VoidCallback onAttach;
  final VoidCallback? onView;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final hasDocument = metadata != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        key: ValueKey('documents-card-${type.value}'),
        title: Text(type.label),
        subtitle: Text(hasDocument ? metadata!.originalName : 'Sin copia'),
        trailing: hasDocument
            ? PopupMenuButton<_DocumentAction>(
                key: ValueKey('documents-menu-${type.value}'),
                onSelected: (action) {
                  switch (action) {
                    case _DocumentAction.open:
                      onView?.call();
                      break;
                    case _DocumentAction.replace:
                      onAttach();
                      break;
                    case _DocumentAction.delete:
                      onDelete?.call();
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _DocumentAction.open,
                    child: Text('Ver'),
                  ),
                  PopupMenuItem(
                    value: _DocumentAction.replace,
                    child: Text('Reemplazar'),
                  ),
                  PopupMenuItem(
                    value: _DocumentAction.delete,
                    child: Text('Eliminar'),
                  ),
                ],
              )
            : IconButton(
                key: ValueKey('documents-row-import-${type.value}'),
                tooltip: 'Adjuntar',
                onPressed: onAttach,
                icon: const Icon(Icons.add_circle_outline),
              ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Text(message, style: AppTextStyles.caption),
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F2),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: AppColors.red),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Text(message, style: AppTextStyles.body),
      ),
    );
  }
}

class _NoVehicleState extends StatelessWidget {
  const _NoVehicleState();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Documentos vehiculares', style: AppTextStyles.h1),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    'Selecciona o agrega un vehículo en Garaje para guardar sus copias privadas.',
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: AppSpacing.l),
                  FilledButton(
                    key: const ValueKey('documents-go-garage'),
                    onPressed: () => context.go(AppRoute.garage.path),
                    child: const Text('Ir a Garaje'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

VehicleProfile? _findVehicle(List<VehicleProfile> vehicles, String vehicleId) {
  for (final vehicle in vehicles) {
    if (vehicle.id == vehicleId) {
      return vehicle;
    }
  }
  return null;
}

enum _DocumentAction { open, replace, delete }
