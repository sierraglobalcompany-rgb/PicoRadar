import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_tokens.dart';
import '../../garage/data/vehicle_profile.dart';
import '../../garage/presentation/vehicle_display.dart';
import '../../services/data/google_maps_service_search.dart';
import '../../vehicle_status/platform/external_launcher.dart';
import '../data/peritajes_draft_store.dart';
import '../domain/peritajes_checklist.dart';

class PeritajesScreen extends ConsumerStatefulWidget {
  const PeritajesScreen(this.vehicleId, {super.key});

  final String? vehicleId;

  @override
  ConsumerState<PeritajesScreen> createState() => _PeritajesScreenState();
}

class _PeritajesScreenState extends ConsumerState<PeritajesScreen> {
  final _notesController = TextEditingController();
  final _checkedItems = <String>{};
  bool _isBusy = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vehicleId = widget.vehicleId?.trim();
    if (vehicleId == null || vehicleId.isEmpty) {
      return const _NoVehicleState();
    }

    final vehicles = ref.watch(vehicleListProvider);
    return vehicles.when(
      data: (items) {
        final vehicle = _findVehicle(items, vehicleId);
        if (vehicle == null) {
          return const _NoVehicleState();
        }
        return _PeritajesContent(
          vehicle: vehicle,
          checkedItems: _checkedItems,
          notesController: _notesController,
          isBusy: _isBusy,
          onToggleItem: _toggleItem,
          onSaveDraft: () => _saveDraft(vehicle.id),
          onRestoreDraft: () => _restoreDraft(vehicle.id),
          onDeleteDraft: () => _deleteDraft(vehicle.id),
          onOpenDocuments: () => _openDocuments(vehicle.id),
          onSearchMaps: () => _searchMaps(vehicle),
        );
      },
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const _NoVehicleState(),
    );
  }

  void _toggleItem(String item, bool value) {
    setState(() {
      if (value) {
        _checkedItems.add(item);
      } else {
        _checkedItems.remove(item);
      }
    });
  }

  Future<void> _saveDraft(String vehicleId) async {
    if (!_beginOperation()) {
      return;
    }
    final store = PeritajesDraftStore(ref.read(appPreferencesProvider));
    try {
      await store.saveDraft(
        vehicleId,
        PeritajesDraft(
          checkedItems: _checkedItems,
          notes: _notesController.text,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      if (!mounted) {
        return;
      }
      _showSnackBar('Borrador de peritaje guardado.');
    } catch (_) {
      if (mounted) {
        _showSnackBar('No pudimos guardar el borrador.');
      }
    } finally {
      _endOperation();
    }
  }

  Future<void> _restoreDraft(String vehicleId) async {
    if (!_beginOperation()) {
      return;
    }
    final store = PeritajesDraftStore(ref.read(appPreferencesProvider));
    try {
      final draft = await store.loadDraft(vehicleId);
      if (!mounted) {
        return;
      }
      if (draft == null) {
        _showSnackBar('No hay borrador guardado para este vehículo.');
        return;
      }
      setState(() {
        _checkedItems
          ..clear()
          ..addAll(draft.checkedItems.where(peritajesChecklistItems.contains));
        _notesController.text = draft.notes;
      });
      _showSnackBar('Borrador de peritaje restaurado.');
    } catch (_) {
      if (mounted) {
        _showSnackBar('No pudimos restaurar el borrador.');
      }
    } finally {
      _endOperation();
    }
  }

  Future<void> _deleteDraft(String vehicleId) async {
    if (!_beginOperation()) {
      return;
    }
    final store = PeritajesDraftStore(ref.read(appPreferencesProvider));
    try {
      await store.deleteDraft(vehicleId);
      if (!mounted) {
        return;
      }
      setState(() {
        _checkedItems.clear();
        _notesController.clear();
      });
      _showSnackBar('Borrador de peritaje eliminado.');
    } catch (_) {
      if (mounted) {
        _showSnackBar('No pudimos eliminar el borrador.');
      }
    } finally {
      _endOperation();
    }
  }

  void _openDocuments(String vehicleId) {
    context.go(
      Uri(
        path: '/apps/module/documentos',
        queryParameters: {'vehicleId': vehicleId},
      ).toString(),
    );
  }

  Future<void> _searchMaps(VehicleProfile vehicle) async {
    if (!_beginOperation()) {
      return;
    }
    final launcher = ref.read(externalLauncherProvider);
    final uri = googleMapsServiceSearchUri(
      category: 'peritaje vehicular',
      city: vehicle.registrationCity ?? '',
    );
    final opened = await launcher.openExternal(uri.toString());
    if (!mounted || opened) {
      _endOperation();
      return;
    }
    _showSnackBar('No pudimos abrir Google Maps.');
    _endOperation();
  }

  bool _beginOperation() {
    if (_isBusy || !mounted) {
      return false;
    }
    setState(() => _isBusy = true);
    return true;
  }

  void _endOperation() {
    if (!mounted) {
      return;
    }
    setState(() => _isBusy = false);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PeritajesContent extends StatelessWidget {
  const _PeritajesContent({
    required this.vehicle,
    required this.checkedItems,
    required this.notesController,
    required this.isBusy,
    required this.onToggleItem,
    required this.onSaveDraft,
    required this.onRestoreDraft,
    required this.onDeleteDraft,
    required this.onOpenDocuments,
    required this.onSearchMaps,
  });

  final VehicleProfile vehicle;
  final Set<String> checkedItems;
  final TextEditingController notesController;
  final bool isBusy;
  final void Function(String item, bool value) onToggleItem;
  final VoidCallback onSaveDraft;
  final VoidCallback onRestoreDraft;
  final VoidCallback onDeleteDraft;
  final VoidCallback onOpenDocuments;
  final VoidCallback onSearchMaps;

  @override
  Widget build(BuildContext context) {
    final checkedCount = checkedItems.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Peritajes')),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          key: const ValueKey('peritajes-screen'),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.m,
            AppSpacing.l,
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
                    _Header(vehicle: vehicle, checkedCount: checkedCount),
                    const SizedBox(height: AppSpacing.m),
                    const _WarningNotice(),
                    const SizedBox(height: AppSpacing.l),
                    Text('Checklist de revisión', style: AppTextStyles.h2),
                    const SizedBox(height: AppSpacing.s),
                    for (final item in peritajesChecklistItems)
                      CheckboxListTile(
                        key: ValueKey('peritajes-check-$item'),
                        value: checkedItems.contains(item),
                        onChanged: isBusy
                            ? null
                            : (value) => onToggleItem(item, value ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        title: Text(peritajesChecklistLabel(item)),
                      ),
                    const SizedBox(height: AppSpacing.l),
                    TextField(
                      key: const ValueKey('peritajes-notes-field'),
                      controller: notesController,
                      enabled: !isBusy,
                      minLines: 4,
                      maxLines: 8,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Notas',
                        hintText:
                            'Anota hallazgos, dudas o puntos por revisar.',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.l),
                    Wrap(
                      spacing: AppSpacing.s,
                      runSpacing: AppSpacing.s,
                      children: [
                        FilledButton.icon(
                          key: const ValueKey('peritajes-save-draft'),
                          onPressed: isBusy ? null : onSaveDraft,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Guardar borrador'),
                        ),
                        OutlinedButton.icon(
                          key: const ValueKey('peritajes-restore-draft'),
                          onPressed: isBusy ? null : onRestoreDraft,
                          icon: const Icon(Icons.restore_outlined),
                          label: const Text('Restaurar'),
                        ),
                        TextButton.icon(
                          key: const ValueKey('peritajes-delete-draft'),
                          onPressed: isBusy ? null : onDeleteDraft,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Borrar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.l),
                    _ActionCard(
                      keyName: 'peritajes-open-documents',
                      icon: Icons.description_outlined,
                      title: 'Abrir Documentos',
                      body: 'Guarda o consulta la copia Peritaje de este vehículo.',
                      onTap: isBusy ? null : onOpenDocuments,
                    ),
                    const SizedBox(height: AppSpacing.s),
                    _ActionCard(
                      keyName: 'peritajes-search-maps',
                      icon: Icons.map_outlined,
                      title: 'Buscar peritaje vehicular',
                      body: 'Abre una búsqueda externa en Google Maps.',
                      onTap: isBusy ? null : onSearchMaps,
                    ),
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
  const _Header({required this.vehicle, required this.checkedCount});

  final VehicleProfile vehicle;
  final int checkedCount;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppSpacing.l),
        leading: CircleAvatar(
          backgroundColor: Colors.white.withValues(alpha: 0.16),
          child: Icon(vehicleIcon(vehicle), color: Colors.white),
        ),
        title: Text(
          vehicle.nickname?.trim().isNotEmpty == true
              ? vehicle.nickname!.trim()
              : vehicle.plate,
          style: AppTextStyles.h1.copyWith(color: Colors.white),
        ),
        subtitle: Text(
          '$checkedCount de ${peritajesChecklistItems.length} puntos revisados',
          style: AppTextStyles.caption.copyWith(
            color: Colors.white.withValues(alpha: 0.82),
          ),
        ),
      ),
    );
  }
}

class _WarningNotice extends StatelessWidget {
  const _WarningNotice();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.plateYellow.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.plateYellow),
      ),
      child: const Padding(
        padding: EdgeInsets.all(AppSpacing.m),
        child: Text(
          peritajesProfessionalInspectionWarning,
          key: ValueKey('peritajes-warning-copy'),
          style: AppTextStyles.caption,
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.keyName,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final String keyName;
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: title,
      child: Material(
        key: ValueKey(keyName),
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: ListTile(
          onTap: onTap,
          enabled: onTap != null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            side: const BorderSide(color: AppColors.border),
          ),
          contentPadding: const EdgeInsets.all(AppSpacing.m),
          leading: CircleAvatar(
            backgroundColor: AppColors.teal.withValues(alpha: 0.10),
            child: Icon(icon, color: AppColors.teal),
          ),
          title: Text(title, style: AppTextStyles.bodyStrong),
          subtitle: Text(
            body,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.navy.withValues(alpha: 0.68),
            ),
          ),
          trailing: const Icon(Icons.chevron_right, color: AppColors.teal),
        ),
      ),
    );
  }
}

class _NoVehicleState extends StatelessWidget {
  const _NoVehicleState();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Peritajes')),
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
                  Text('Peritajes', style: AppTextStyles.h1),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    'Selecciona o agrega un vehículo en Garaje para preparar su peritaje.',
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: AppSpacing.l),
                  FilledButton(
                    key: const ValueKey('peritajes-go-garage'),
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
