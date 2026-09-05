import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../app/theme/app_tokens.dart';
import '../../comparendos/presentation/comparendos_screen.dart';
import '../../documents/presentation/documents_screen.dart';
import '../../garage/data/vehicle_profile.dart';
import '../../garage/presentation/vehicle_display.dart';
import '../../tramites/presentation/tramites_screen.dart';
import '../data/buy_sell_draft.dart';

class BuySellScreen extends ConsumerStatefulWidget {
  const BuySellScreen({
    super.key,
    this.onOpenComparendos,
    this.onOpenTramites,
    this.onOpenPeritajes,
    this.onOpenDocuments,
  });

  final ValueChanged<VehicleProfile>? onOpenComparendos;
  final ValueChanged<VehicleProfile>? onOpenTramites;
  final ValueChanged<VehicleProfile>? onOpenPeritajes;
  final ValueChanged<VehicleProfile>? onOpenDocuments;

  @override
  ConsumerState<BuySellScreen> createState() => _BuySellScreenState();
}

class _BuySellScreenState extends ConsumerState<BuySellScreen> {
  final _candidatePlateController = TextEditingController();
  final _cityController = TextEditingController();
  final _notesController = TextEditingController();
  var _mode = BuySellMode.buy;
  var _checkedItems = <String>{};
  bool _restoring = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _restoreDraft(silent: true);
  }

  @override
  void dispose() {
    _candidatePlateController.dispose();
    _cityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeVehicle = ref.watch(activeVehicleProvider);
    final vehicle = activeVehicle.asData?.value;
    final hasVehicle = vehicle != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Compra/Venta')),
      body: SafeArea(
        child: ListView(
          key: const ValueKey('buy-sell-screen'),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.l,
            AppSpacing.l,
            96,
          ),
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(vehicle: vehicle),
                    const SizedBox(height: AppSpacing.l),
                    _DraftForm(
                      mode: _mode,
                      candidatePlateController: _candidatePlateController,
                      cityController: _cityController,
                      notesController: _notesController,
                      checkedItems: _checkedItems,
                      onModeChanged: (mode) => setState(() => _mode = mode),
                      onChecklistChanged: _updateChecklist,
                    ),
                    const SizedBox(height: AppSpacing.l),
                    _DraftActions(
                      restoring: _restoring,
                      busy: _busy,
                      onSave: _saveDraft,
                      onRestore: () => _restoreDraft(silent: false),
                      onDelete: _deleteDraft,
                      onCopy: _copySummary,
                    ),
                    const SizedBox(height: AppSpacing.l),
                    _VehicleActions(
                      enabled: hasVehicle,
                      onComparendos: hasVehicle
                          ? () => _openComparendos(vehicle)
                          : null,
                      onTramites: hasVehicle
                          ? () => _openTramites(vehicle)
                          : null,
                      onPeritajes: hasVehicle
                          ? () => _openPeritajes(vehicle)
                          : null,
                      onDocuments: hasVehicle
                          ? () => _openDocuments(vehicle)
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.l),
                    const _MandatoryNotice(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _restoreDraft({required bool silent}) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _restoring = true;
    });
    final preferences = ref.read(appPreferencesProvider);
    BuySellDraft? draft;
    var failed = false;
    try {
      draft = await loadBuySellDraft(preferences);
    } catch (_) {
      failed = true;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      if (draft != null) {
        _mode = draft.mode;
        _candidatePlateController.text = draft.candidatePlate;
        _cityController.text = draft.city;
        _notesController.text = draft.notes;
        _checkedItems = draft.checkedItems;
      }
      _restoring = false;
      _busy = false;
    });
    if (failed) {
      _showSnackBar('No se pudo restaurar el borrador.');
      return;
    }
    if (silent) {
      return;
    }
    _showSnackBar(
      draft == null ? 'No hay borrador guardado.' : 'Borrador restaurado.',
    );
  }

  Future<void> _saveDraft() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    final preferences = ref.read(appPreferencesProvider);
    try {
      await saveBuySellDraft(preferences, _currentDraft());
      if (!mounted) {
        return;
      }
      _showSnackBar('Borrador guardado en este dispositivo.');
    } catch (_) {
      if (mounted) {
        _showSnackBar('No se pudo guardar el borrador.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _deleteDraft() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    final preferences = ref.read(appPreferencesProvider);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Eliminar borrador'),
          content: const Text(
            'Esta accion borra el borrador guardado en este dispositivo.',
          ),
          actions: [
            TextButton(
              key: const ValueKey('buy-sell-delete-cancel'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const ValueKey('buy-sell-delete-confirm'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) {
        return;
      }
      await deleteBuySellDraft(preferences);
      if (!mounted) {
        return;
      }
      _showSnackBar('Borrador eliminado.');
    } catch (_) {
      if (mounted) {
        _showSnackBar('No se pudo eliminar el borrador.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _copySummary() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await Clipboard.setData(ClipboardData(text: _summaryText()));
      if (!mounted) {
        return;
      }
      _showSnackBar('Resumen copiado.');
    } catch (_) {
      if (mounted) {
        _showSnackBar('No se pudo copiar el resumen.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _updateChecklist(String item, bool checked) {
    setState(() {
      final next = {..._checkedItems};
      if (checked) {
        next.add(item);
      } else {
        next.remove(item);
      }
      _checkedItems = next;
    });
  }

  BuySellDraft _currentDraft() {
    return BuySellDraft(
      mode: _mode,
      candidatePlate: _candidatePlateController.text,
      city: _cityController.text,
      notes: _notesController.text,
      checkedItems: _checkedItems,
    );
  }

  String _summaryText() {
    final lines = [
      'Preparacion ${_mode.label.toLowerCase()} - PicoRadar',
      if (_candidatePlateController.text.trim().isNotEmpty)
        'Placa candidata: ${_candidatePlateController.text.trim()}',
      if (_cityController.text.trim().isNotEmpty)
        'Ciudad: ${_cityController.text.trim()}',
      'Checklist:',
      for (final item in _checklistItems(_mode))
        '${_checkedItems.contains(item) ? '[x]' : '[ ]'} $item',
      if (_notesController.text.trim().isNotEmpty) ...[
        'Notas:',
        _notesController.text.trim(),
      ],
      buySellMandatoryCopy,
    ];
    return lines.join('\n');
  }

  void _openComparendos(VehicleProfile vehicle) {
    final callback = widget.onOpenComparendos;
    if (callback != null) {
      callback(vehicle);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ComparendosScreen(vehicleId: vehicle.id),
      ),
    );
  }

  void _openTramites(VehicleProfile vehicle) {
    final callback = widget.onOpenTramites;
    if (callback != null) {
      callback(vehicle);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => const TramitesScreen()),
    );
  }

  void _openPeritajes(VehicleProfile vehicle) {
    final callback = widget.onOpenPeritajes;
    if (callback != null) {
      callback(vehicle);
      return;
    }
    _showSnackBar('Peritajes se abre desde Servicios en esta versión.');
  }

  void _openDocuments(VehicleProfile vehicle) {
    final callback = widget.onOpenDocuments;
    if (callback != null) {
      callback(vehicle);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => DocumentsScreen(vehicle.id),
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.vehicle});

  final VehicleProfile? vehicle;

  @override
  Widget build(BuildContext context) {
    final active = vehicle;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Preparación de compra/venta', style: AppTextStyles.h2),
            const SizedBox(height: AppSpacing.s),
            Text(
              'Organiza verificaciones y documentos antes de avanzar.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.navy.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            if (active == null)
              const _VehicleHint()
            else
              _ActiveVehicleChip(vehicle: active),
          ],
        ),
      ),
    );
  }
}

class _VehicleHint extends StatelessWidget {
  const _VehicleHint();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('buy-sell-no-active-vehicle'),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: const Padding(
        padding: EdgeInsets.all(AppSpacing.m),
        child: Text(
          'Activa un vehículo en Garaje para abrir comparendos, trámites, peritajes y documentos.',
        ),
      ),
    );
  }
}

class _ActiveVehicleChip extends StatelessWidget {
  const _ActiveVehicleChip({required this.vehicle});

  final VehicleProfile vehicle;

  @override
  Widget build(BuildContext context) {
    final makeModel = vehicleMakeModel(vehicle);
    return DecoratedBox(
      key: const ValueKey('buy-sell-active-vehicle'),
      decoration: BoxDecoration(
        color: vehicleAccent(vehicle).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Row(
          children: [
            Icon(vehicleIcon(vehicle), color: vehicleAccent(vehicle)),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Text(
                [
                  vehicle.plate,
                  if (makeModel.isNotEmpty) makeModel,
                  if (vehicle.year != null) vehicle.year.toString(),
                ].join(' · '),
                style: AppTextStyles.bodyStrong,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftForm extends StatelessWidget {
  const _DraftForm({
    required this.mode,
    required this.candidatePlateController,
    required this.cityController,
    required this.notesController,
    required this.checkedItems,
    required this.onModeChanged,
    required this.onChecklistChanged,
  });

  final BuySellMode mode;
  final TextEditingController candidatePlateController;
  final TextEditingController cityController;
  final TextEditingController notesController;
  final Set<String> checkedItems;
  final ValueChanged<BuySellMode> onModeChanged;
  final void Function(String item, bool checked) onChecklistChanged;

  @override
  Widget build(BuildContext context) {
    final items = _checklistItems(mode);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<BuySellMode>(
              key: const ValueKey('buy-sell-mode'),
              direction: MediaQuery.textScalerOf(context).scale(1) > 1.25
                  ? Axis.vertical
                  : Axis.horizontal,
              segments: const [
                ButtonSegment(
                  value: BuySellMode.buy,
                  label: Text('Comprar'),
                  icon: Icon(Icons.search_outlined),
                ),
                ButtonSegment(
                  value: BuySellMode.sell,
                  label: Text('Vender'),
                  icon: Icon(Icons.sell_outlined),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (selection) {
                onModeChanged(selection.first);
              },
            ),
            const SizedBox(height: AppSpacing.l),
            TextField(
              key: const ValueKey('buy-sell-candidate-plate'),
              controller: candidatePlateController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Placa candidata',
                hintText: 'Opcional',
                prefixIcon: Icon(Icons.pin_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              key: const ValueKey('buy-sell-city'),
              controller: cityController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Ciudad',
                hintText: 'Opcional',
                prefixIcon: Icon(Icons.location_city_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              key: const ValueKey('buy-sell-notes'),
              controller: notesController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Notas',
                hintText: 'Observaciones opcionales',
                prefixIcon: Icon(Icons.notes_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            Text('Checklist', style: AppTextStyles.bodyStrong),
            const SizedBox(height: AppSpacing.s),
            for (final item in items)
              Material(
                color: Colors.transparent,
                child: CheckboxListTile(
                  key: ValueKey('buy-sell-check-$item'),
                  value: checkedItems.contains(item),
                  onChanged: (value) =>
                      onChecklistChanged(item, value ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: Text(item),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DraftActions extends StatelessWidget {
  const _DraftActions({
    required this.restoring,
    required this.busy,
    required this.onSave,
    required this.onRestore,
    required this.onDelete,
    required this.onCopy,
  });

  final bool restoring;
  final bool busy;
  final VoidCallback onSave;
  final VoidCallback onRestore;
  final VoidCallback onDelete;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.s,
      runSpacing: AppSpacing.s,
      children: [
        FilledButton.icon(
          key: const ValueKey('buy-sell-save-draft'),
          onPressed: busy ? null : onSave,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Guardar borrador'),
        ),
        OutlinedButton.icon(
          key: const ValueKey('buy-sell-restore-draft'),
          onPressed: busy || restoring ? null : onRestore,
          icon: const Icon(Icons.restore_outlined),
          label: const Text('Restaurar'),
        ),
        TextButton.icon(
          key: const ValueKey('buy-sell-delete-draft'),
          onPressed: busy ? null : onDelete,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Eliminar'),
        ),
        OutlinedButton.icon(
          key: const ValueKey('buy-sell-copy-summary'),
          onPressed: busy ? null : onCopy,
          icon: const Icon(Icons.copy_outlined),
          label: const Text('Copiar resumen'),
        ),
      ],
    );
  }
}

class _VehicleActions extends StatelessWidget {
  const _VehicleActions({
    required this.enabled,
    required this.onComparendos,
    required this.onTramites,
    required this.onPeritajes,
    required this.onDocuments,
  });

  final bool enabled;
  final VoidCallback? onComparendos;
  final VoidCallback? onTramites;
  final VoidCallback? onPeritajes;
  final VoidCallback? onDocuments;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Acciones del vehículo', style: AppTextStyles.h2),
            const SizedBox(height: AppSpacing.s),
            Text(
              enabled
                  ? 'Usa el vehículo activo para preparar verificaciones.'
                  : 'Disponibles cuando exista un vehículo activo.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.navy.withValues(alpha: 0.70),
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            Wrap(
              spacing: AppSpacing.s,
              runSpacing: AppSpacing.s,
              children: [
                _ActionButton(
                  keyName: 'buy-sell-open-comparendos',
                  icon: Icons.fact_check_outlined,
                  label: 'Comparendos',
                  onPressed: onComparendos,
                ),
                _ActionButton(
                  keyName: 'buy-sell-open-tramites',
                  icon: Icons.assignment_outlined,
                  label: 'Trámites',
                  onPressed: onTramites,
                ),
                _ActionButton(
                  keyName: 'buy-sell-open-peritajes',
                  icon: Icons.manage_search_outlined,
                  label: 'Peritajes',
                  onPressed: onPeritajes,
                ),
                _ActionButton(
                  keyName: 'buy-sell-open-documents',
                  icon: Icons.folder_copy_outlined,
                  label: 'Documentos',
                  onPressed: onDocuments,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.keyName,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final String keyName;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: ValueKey(keyName),
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _MandatoryNotice extends StatelessWidget {
  const _MandatoryNotice();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.plateYellow.withValues(alpha: 0.24),
        border: Border.all(color: AppColors.plateYellow),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: const Padding(
        padding: EdgeInsets.all(AppSpacing.m),
        child: Text(
          buySellMandatoryCopy,
          key: ValueKey('buy-sell-mandatory-copy'),
        ),
      ),
    );
  }
}

List<String> _checklistItems(BuySellMode mode) {
  return switch (mode) {
    BuySellMode.buy => const [
      'Revisar comparendos y obligaciones.',
      'Confirmar trámites de traspaso.',
      'Agendar peritaje antes de pagar.',
      'Revisar documentos privados y oficiales.',
    ],
    BuySellMode.sell => const [
      'Preparar comparendos y obligaciones.',
      'Confirmar trámites de traspaso.',
      'Tener peritaje o revisión disponible.',
      'Organizar documentos del vehículo.',
    ],
  };
}
