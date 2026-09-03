import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_tokens.dart';
import '../data/module_registry.dart';
import '../domain/app_module.dart';

enum AppsLauncherMode { primary, more }

class AppsLauncherPanel extends ConsumerStatefulWidget {
  const AppsLauncherPanel({
    required this.vehicleId,
    required this.onDismiss,
    required this.onNavigate,
    super.key,
  });

  final String? vehicleId;
  final VoidCallback onDismiss;
  final void Function(String location) onNavigate;

  @override
  ConsumerState<AppsLauncherPanel> createState() => _AppsLauncherPanelState();
}

class _AppsLauncherPanelState extends ConsumerState<AppsLauncherPanel> {
  AppsLauncherMode _mode = AppsLauncherMode.primary;

  @override
  Widget build(BuildContext context) {
    final flags = ref.watch(moduleFeatureFlagsProvider);
    final modules = switch (_mode) {
      AppsLauncherMode.primary => visibleModules(primaryModules, flags),
      AppsLauncherMode.more => visibleModules(secondaryModules, flags),
    };
    final heightFactor = 0.7;

    return Align(
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: heightFactor,
        widthFactor: 1,
        child: Material(
          key: const ValueKey('apps-launcher-panel'),
          color: AppColors.surface,
          elevation: 18,
          shadowColor: AppColors.navy.withValues(alpha: 0.2),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.modal),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            bottom: false,
            child: Column(
              children: [
                _DragHandle(onDismiss: widget.onDismiss),
                const Text('Apps', style: AppTextStyles.h1),
                const SizedBox(height: AppSpacing.m),
                _ModeSelector(
                  mode: _mode,
                  onChanged: (mode) => setState(() => _mode = mode),
                ),
                const SizedBox(height: AppSpacing.m),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: AppMotion.fade,
                    child: _mode == AppsLauncherMode.primary
                        ? _PrimaryLauncherGrid(
                            modules: modules,
                            vehicleId: widget.vehicleId,
                            onOpen: _openModule,
                          )
                        : _MoreLauncherList(
                            modules: modules,
                            vehicleId: widget.vehicleId,
                            onOpen: _openModule,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openModule(AppModule module) async {
    if (module.requiresVehicle && widget.vehicleId == null) {
      await _showVehicleGuard(context);
      return;
    }
    widget.onNavigate(appsLauncherLocation(module, widget.vehicleId));
  }

  Future<void> _showVehicleGuard(BuildContext rootContext) {
    return showDialog<void>(
      context: rootContext,
      builder: (context) => AlertDialog(
        title: const Text('Agrega un vehículo'),
        content: const Text('Agrega un vehículo para usar esta función.'),
        actions: [
          TextButton(
            key: const ValueKey('vehicle-guard-cancel'),
            onPressed: () => context.pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('vehicle-guard-add'),
            onPressed: () {
              context.pop();
              widget.onDismiss();
              rootContext.go('/onboarding/vehicle?return=apps');
            },
            child: const Text('Agregar vehículo'),
          ),
        ],
      ),
    );
  }
}

String appsLauncherLocation(AppModule module, String? vehicleId) {
  if (!module.requiresVehicle ||
      vehicleId == null ||
      module.destination == AppRoute.trip.path) {
    return module.destination;
  }
  final uri = Uri.parse(module.destination);
  return uri
      .replace(
        queryParameters: {...uri.queryParameters, 'vehicleId': vehicleId},
      )
      .toString();
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('apps-launcher-drag-handle'),
      behavior: HitTestBehavior.opaque,
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > 420) {
          onDismiss();
        }
      },
      child: const SizedBox(
        height: 28,
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.all(Radius.circular(AppRadius.chip)),
            ),
            child: SizedBox(width: 54, height: 5),
          ),
        ),
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.mode, required this.onChanged});

  final AppsLauncherMode mode;
  final ValueChanged<AppsLauncherMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: SegmentedButton<AppsLauncherMode>(
        key: const ValueKey('apps-launcher-mode-selector'),
        segments: const [
          ButtonSegment(
            value: AppsLauncherMode.primary,
            icon: Icon(Icons.directions_car_filled_outlined),
            label: Text('Principales'),
          ),
          ButtonSegment(
            value: AppsLauncherMode.more,
            icon: Icon(Icons.grid_view_rounded),
            label: Text('Más'),
          ),
        ],
        selected: {mode},
        onSelectionChanged: (selected) => onChanged(selected.single),
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
          visualDensity: VisualDensity.standard,
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? AppColors.teal
                : AppColors.navy.withValues(alpha: 0.76);
          }),
        ),
      ),
    );
  }
}

class _PrimaryLauncherGrid extends StatelessWidget {
  const _PrimaryLauncherGrid({
    required this.modules,
    required this.vehicleId,
    required this.onOpen,
  });

  final List<AppModule> modules;
  final String? vehicleId;
  final ValueChanged<AppModule> onOpen;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final aspectRatio = scale >= 1.5 ? 0.9 : 1.08;
    return GridView.builder(
      key: const ValueKey('apps-launcher-primary-grid'),
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, 132),
      itemCount: modules.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppSpacing.m,
        crossAxisSpacing: AppSpacing.m,
        childAspectRatio: aspectRatio,
      ),
      itemBuilder: (context, index) => _LauncherTile(
        module: modules[index],
        vehicleId: vehicleId,
        onOpen: onOpen,
      ),
    );
  }
}

class _MoreLauncherList extends StatelessWidget {
  const _MoreLauncherList({
    required this.modules,
    required this.vehicleId,
    required this.onOpen,
  });

  final List<AppModule> modules;
  final String? vehicleId;
  final ValueChanged<AppModule> onOpen;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: const ValueKey('apps-launcher-more-list'),
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, 132),
      itemCount: modules.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.s),
      itemBuilder: (context, index) => _LauncherRow(
        module: modules[index],
        vehicleId: vehicleId,
        onOpen: onOpen,
      ),
    );
  }
}

class _LauncherTile extends StatelessWidget {
  const _LauncherTile({
    required this.module,
    required this.vehicleId,
    required this.onOpen,
  });

  final AppModule module;
  final String? vehicleId;
  final ValueChanged<AppModule> onOpen;

  @override
  Widget build(BuildContext context) {
    final disabled = module.requiresVehicle && vehicleId == null;
    return Semantics(
      button: true,
      enabled: !disabled,
      label: module.title,
      excludeSemantics: true,
      onTap: () => onOpen(module),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(
            color: disabled
                ? AppColors.border.withValues(alpha: 0.72)
                : AppColors.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('app-module-${module.id}'),
          onTap: () => onOpen(module),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  module.icon,
                  size: 30,
                  color: AppColors.teal.withValues(alpha: disabled ? 0.48 : 1),
                ),
                const SizedBox(height: AppSpacing.s),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _launcherTileLabel(module),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.navy.withValues(
                          alpha: disabled ? 0.58 : 1,
                        ),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _launcherTileLabel(AppModule module) {
  return switch (module.id) {
    'seguro_asistencia' => 'Seguro y\nasistencia',
    _ => module.title,
  };
}

class _LauncherRow extends StatelessWidget {
  const _LauncherRow({
    required this.module,
    required this.vehicleId,
    required this.onOpen,
  });

  final AppModule module;
  final String? vehicleId;
  final ValueChanged<AppModule> onOpen;

  @override
  Widget build(BuildContext context) {
    final disabled = module.requiresVehicle && vehicleId == null;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        side: BorderSide(
          color: disabled
              ? AppColors.border.withValues(alpha: 0.72)
              : AppColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        key: ValueKey('app-secondary-${module.id}'),
        minTileHeight: 56,
        leading: Icon(
          module.icon,
          color: AppColors.teal.withValues(alpha: disabled ? 0.48 : 1),
        ),
        title: Text(
          module.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyStrong.copyWith(
            color: AppColors.navy.withValues(alpha: disabled ? 0.58 : 1),
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => onOpen(module),
      ),
    );
  }
}
