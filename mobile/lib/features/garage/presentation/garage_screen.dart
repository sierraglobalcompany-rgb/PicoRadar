import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/shell/picoradar_app_header.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/design_system/actions_and_badges.dart';
import '../../../core/design_system/branding.dart';
import '../../../core/design_system/surfaces.dart';
import '../../home/presentation/home_screen.dart';
import '../../pico_placa/data/pico_preferences.dart';
import '../../visual_assets/presentation/visual_asset_widgets.dart';
import '../data/garage_favorites.dart';
import '../data/vehicle_profile.dart';
import 'vehicle_display.dart';

enum GarageFilter { all, favorites, active }

const _garageViewportFraction = 0.58;
const _garageSideCardScale = 0.91;
const _garageCarouselHeight = 204.0;
const _garageFilterVisualHeight = 46.0;
const _garageFilterWidthFactor = 0.86;
const _garageAddVehicleHeight = 76.0;
const _garageActionHeight = 64.0;

class GarageScreen extends ConsumerWidget {
  const GarageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehicleListProvider);
    final active = ref.watch(activeVehicleProvider);
    final favorites = ref.watch(garageFavoriteVehicleIdsProvider);
    final alerts = ref.watch(picoAlertPreferencesProvider);
    final alertPreferences = alerts.asData?.value ?? _defaultAlertPreferences;

    return PicoSurface(
      child: vehicles.when(
        data: (items) {
          String? activeId;
          if (active case AsyncData(:final value)) {
            activeId = value?.id;
            _ensureActiveVehicle(ref, items, activeId);
          }

          if (items.isEmpty) {
            return _GarageEmpty(alertPreferences: alertPreferences);
          }

          return _GarageReady(
            vehicles: items,
            activeId: activeId,
            favoriteIds: favorites.asData?.value ?? const {},
            alertPreferences: alertPreferences,
          );
        },
        loading: () => _GarageSkeleton(alertPreferences: alertPreferences),
        error: (error, stackTrace) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(error.toString()),
          );
        },
      ),
    );
  }

  void _ensureActiveVehicle(
    WidgetRef ref,
    List<VehicleProfile> vehicles,
    String? activeId,
  ) {
    if (vehicles.isEmpty ||
        (activeId != null &&
            vehicles.any((vehicle) => vehicle.id == activeId))) {
      return;
    }

    Future<void>.microtask(() async {
      final repository = ref.read(vehicleRepositoryProvider);
      final latestActive = await repository.getActiveVehicle();
      if (latestActive != null) {
        return;
      }
      await repository.setActiveVehicle(vehicles.first.id);
      ref.invalidate(activeVehicleProvider);
      ref.invalidate(vehicleListProvider);
    });
  }
}

class _GarageReady extends ConsumerStatefulWidget {
  const _GarageReady({
    required this.vehicles,
    required this.activeId,
    required this.favoriteIds,
    required this.alertPreferences,
  });

  final List<VehicleProfile> vehicles;
  final String? activeId;
  final Set<String> favoriteIds;
  final PicoAlertPreferences alertPreferences;

  @override
  ConsumerState<_GarageReady> createState() => _GarageReadyState();
}

class _GarageReadyState extends ConsumerState<_GarageReady> {
  GarageFilter _filter = GarageFilter.all;
  late PageController _controller;
  String? _focusedVehicleId;

  @override
  void initState() {
    super.initState();
    _focusedVehicleId = _initialFocusedId(widget.vehicles, widget.activeId);
    _controller = PageController(
      initialPage: _focusedIndex(_filteredVehicles()),
      viewportFraction: _garageViewportFraction,
    );
  }

  @override
  void didUpdateWidget(covariant _GarageReady oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldFiltered = _filteredVehiclesFor(
      vehicles: oldWidget.vehicles,
      activeId: oldWidget.activeId,
      favoriteIds: oldWidget.favoriteIds,
    );
    final filtered = _filteredVehicles();
    if (filtered.isEmpty) {
      _focusedVehicleId = null;
      return;
    }
    final focusBefore = _focusedVehicleId;
    if (!filtered.any((vehicle) => vehicle.id == _focusedVehicleId)) {
      _focusedVehicleId = _initialFocusedId(filtered, widget.activeId);
    }
    if (focusBefore != _focusedVehicleId ||
        !_sameVehicleIds(oldFiltered, filtered)) {
      _jumpToFocused(filtered);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredVehicles();
    final focusedIndex = _focusedIndex(filtered);
    final focused = filtered.isEmpty ? null : filtered[focusedIndex];

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 380
            ? AppSpacing.l
            : AppSpacing.l;
        return SingleChildScrollView(
          key: const ValueKey('garage-v2-scroll'),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AppSpacing.s,
            horizontalPadding,
            AppSpacing.s,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _GarageHeader(alertPreferences: widget.alertPreferences),
                  const SizedBox(height: AppSpacing.m),
                  _GarageFilterSegment(
                    selected: _filter,
                    onChanged: _selectFilter,
                  ),
                  const SizedBox(height: AppSpacing.m),
                  if (focused == null)
                    _FilteredEmpty(filter: _filter, onShowAll: _showAll)
                  else ...[
                    _GarageCarousel(
                      vehicles: filtered,
                      focusedIndex: focusedIndex,
                      activeId: widget.activeId,
                      favoriteIds: widget.favoriteIds,
                      controller: _controller,
                      onChanged: (index) {
                        if (index < 0 || index >= filtered.length) {
                          return;
                        }
                        setState(() {
                          _focusedVehicleId = filtered[index].id;
                        });
                      },
                      onFavorite: _toggleFavorite,
                    ),
                    const SizedBox(height: AppSpacing.s),
                    _CarouselIndicator(
                      count: filtered.length,
                      index: focusedIndex,
                    ),
                    const SizedBox(height: AppSpacing.s),
                    _GarageInfoPanel(
                      vehicle: focused,
                      active: focused.id == widget.activeId,
                      onMakeActive: _makeActive,
                    ),
                    const SizedBox(height: AppSpacing.s),
                    _AddVehicleCard(onTap: _addVehicle),
                    const SizedBox(height: AppSpacing.xs),
                    _GarageActions(vehicle: focused, onDelete: _confirmDelete),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<VehicleProfile> _filteredVehicles() {
    return _filteredVehiclesFor(
      vehicles: widget.vehicles,
      activeId: widget.activeId,
      favoriteIds: widget.favoriteIds,
    );
  }

  List<VehicleProfile> _filteredVehiclesFor({
    required List<VehicleProfile> vehicles,
    required String? activeId,
    required Set<String> favoriteIds,
  }) {
    return switch (_filter) {
      GarageFilter.all => vehicles,
      GarageFilter.favorites =>
        vehicles
            .where((vehicle) => favoriteIds.contains(vehicle.id))
            .toList(growable: false),
      GarageFilter.active =>
        vehicles
            .where((vehicle) => vehicle.id == activeId)
            .toList(growable: false),
    };
  }

  void _selectFilter(GarageFilter filter) {
    setState(() {
      _filter = filter;
      final filtered = _filteredVehicles();
      _focusedVehicleId = _initialFocusedId(filtered, widget.activeId);
    });
    _jumpToFocused(_filteredVehicles());
  }

  void _showAll() => _selectFilter(GarageFilter.all);

  void _jumpToFocused(List<VehicleProfile> filtered) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients || filtered.isEmpty) {
        return;
      }
      _controller.jumpToPage(_focusedIndex(filtered));
    });
  }

  int _focusedIndex(List<VehicleProfile> filtered) {
    if (filtered.isEmpty) {
      return 0;
    }
    final index = filtered.indexWhere(
      (vehicle) => vehicle.id == _focusedVehicleId,
    );
    return index < 0 ? 0 : index;
  }

  String? _initialFocusedId(List<VehicleProfile> vehicles, String? activeId) {
    if (vehicles.isEmpty) {
      return null;
    }
    final activeIndex = vehicles.indexWhere(
      (vehicle) => vehicle.id == activeId,
    );
    return vehicles[activeIndex < 0 ? 0 : activeIndex].id;
  }

  bool _sameVehicleIds(List<VehicleProfile> left, List<VehicleProfile> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var i = 0; i < left.length; i += 1) {
      if (left[i].id != right[i].id) {
        return false;
      }
    }
    return true;
  }

  Future<void> _toggleFavorite(VehicleProfile vehicle) async {
    await toggleGarageFavoriteVehicleId(
      ref.read(appPreferencesProvider),
      vehicle.id,
    );
    ref.invalidate(garageFavoriteVehicleIdsProvider);
  }

  Future<void> _makeActive(VehicleProfile vehicle) async {
    await ref.read(vehicleRepositoryProvider).setActiveVehicle(vehicle.id);
    ref.invalidate(activeVehicleProvider);
    ref.invalidate(vehicleListProvider);
  }

  void _addVehicle() {
    context.push('${AppRoute.vehicleOnboarding.path}?return=garage');
  }

  Future<void> _confirmDelete(VehicleProfile vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('¿Eliminar este vehículo?'),
          content: Text(vehicle.plate),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const ValueKey('garage-confirm-delete-vehicle'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final repository = ref.read(vehicleRepositoryProvider);
    final activeBeforeDelete = await repository.getActiveVehicle();
    final wasActive = activeBeforeDelete?.id == vehicle.id;
    await repository.deleteVehicle(vehicle.id);
    final favorites = await loadGarageFavoriteVehicleIds(
      ref.read(appPreferencesProvider),
    );
    if (favorites.remove(vehicle.id)) {
      await saveGarageFavoriteVehicleIds(
        ref.read(appPreferencesProvider),
        favorites,
      );
    }

    if (wasActive) {
      final remaining = await repository.listVehicles();
      if (remaining.isNotEmpty) {
        await repository.setActiveVehicle(remaining.first.id);
      } else {
        await repository.clearActiveVehicle();
      }
    }

    ref.invalidate(activeVehicleProvider);
    ref.invalidate(vehicleListProvider);
    ref.invalidate(garageFavoriteVehicleIdsProvider);
    ref.invalidate(obligationNotificationSyncProvider);
    if (!mounted) {
      return;
    }
    final remaining = await repository.listVehicles();
    setState(() {
      _focusedVehicleId = _initialFocusedId(remaining, widget.activeId);
    });
  }
}

class _GarageHeader extends StatelessWidget {
  const _GarageHeader({required this.alertPreferences});

  final PicoAlertPreferences alertPreferences;

  @override
  Widget build(BuildContext context) {
    return PicoRadarAppHeader(
      alertPreferences: alertPreferences,
      onNotificationsPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) =>
            HomeNotificationSheet(alertPreferences: alertPreferences),
      ),
      headerKey: const ValueKey('garage-compact-top-bar'),
      brandKey: const ValueKey('garage-brand-lockup'),
      capsuleKey: const ValueKey('garage-user-controls-capsule'),
      bellKey: const ValueKey('garage-notification-bell'),
    );
  }
}

class _GarageFilterSegment extends StatelessWidget {
  const _GarageFilterSegment({required this.selected, required this.onChanged});

  final GarageFilter selected;
  final ValueChanged<GarageFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final targetWidth = textScale <= 1.25
            ? constraints.maxWidth * _garageFilterWidthFactor
            : constraints.maxWidth;
        return Align(
          alignment: Alignment.center,
          child: SizedBox(
            key: const ValueKey('garage-filter-segment'),
            width: targetWidth,
            height: 48,
            child: Center(
              child: Material(
                color: AppColors.surface,
                elevation: 2,
                shadowColor: AppColors.navy.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.chip),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  height: _garageFilterVisualHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.72),
                    ),
                  ),
                  child: Row(
                    children: [
                      _GarageFilterButton(
                        value: GarageFilter.all,
                        selected: selected == GarageFilter.all,
                        onChanged: onChanged,
                        label: 'Todos',
                        icon: Icons.check_rounded,
                      ),
                      _GarageFilterDivider(
                        visible:
                            selected != GarageFilter.all &&
                            selected != GarageFilter.favorites,
                      ),
                      _GarageFilterButton(
                        value: GarageFilter.favorites,
                        selected: selected == GarageFilter.favorites,
                        onChanged: onChanged,
                        label: 'Favoritos',
                        icon: Icons.star_border_rounded,
                      ),
                      _GarageFilterDivider(
                        visible:
                            selected != GarageFilter.favorites &&
                            selected != GarageFilter.active,
                      ),
                      _GarageFilterButton(
                        value: GarageFilter.active,
                        selected: selected == GarageFilter.active,
                        onChanged: onChanged,
                        label: 'Activos',
                        icon: Icons.radio_button_checked_rounded,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GarageFilterButton extends StatelessWidget {
  const _GarageFilterButton({
    required this.value,
    required this.selected,
    required this.onChanged,
    required this.label,
    required this.icon,
  });

  final GarageFilter value;
  final bool selected;
  final ValueChanged<GarageFilter> onChanged;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.navy;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Material(
            color: selected ? AppColors.teal : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.chip),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onChanged(value),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18, color: foreground),
                    const SizedBox(width: AppSpacing.s),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.fade,
                        style: AppTextStyles.caption.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GarageFilterDivider extends StatelessWidget {
  const _GarageFilterDivider({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: AppMotion.fade,
      opacity: visible ? 1 : 0,
      child: Container(
        width: 1,
        height: 22,
        color: AppColors.border.withValues(alpha: 0.72),
      ),
    );
  }
}

class _GarageCarousel extends StatelessWidget {
  const _GarageCarousel({
    required this.vehicles,
    required this.focusedIndex,
    required this.activeId,
    required this.favoriteIds,
    required this.controller,
    required this.onChanged,
    required this.onFavorite,
  });

  final List<VehicleProfile> vehicles;
  final int focusedIndex;
  final String? activeId;
  final Set<String> favoriteIds;
  final PageController controller;
  final ValueChanged<int> onChanged;
  final ValueChanged<VehicleProfile> onFavorite;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return SizedBox(
      key: const ValueKey('garage-vehicle-carousel'),
      height: textScale <= 1.25 ? _garageCarouselHeight : 232,
      child: PageView.builder(
        controller: controller,
        itemCount: vehicles.length,
        onPageChanged: onChanged,
        padEnds: true,
        itemBuilder: (context, index) {
          final vehicle = vehicles[index];
          final focused = index == focusedIndex;
          return AnimatedScale(
            duration: AppMotion.carouselSnap,
            curve: AppMotion.standardCurve,
            scale: focused ? 1 : _garageSideCardScale,
            child: _GarageVehicleCard(
              vehicle: vehicle,
              active: vehicle.id == activeId,
              favorite: favoriteIds.contains(vehicle.id),
              focused: focused,
              onFavorite: () => onFavorite(vehicle),
            ),
          );
        },
      ),
    );
  }
}

class _GarageVehicleCard extends StatelessWidget {
  const _GarageVehicleCard({
    required this.vehicle,
    required this.active,
    required this.favorite,
    required this.focused,
    required this.onFavorite,
  });

  final VehicleProfile vehicle;
  final bool active;
  final bool favorite;
  final bool focused;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final accent = vehicleAccent(vehicle);
    final title = vehicleDisplayName(vehicle);

    return Material(
      key: ValueKey('garage-vehicle-card-${vehicle.id}'),
      color: AppColors.surface,
      elevation: focused ? 8 : 2,
      shadowColor: AppColors.navy.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: active
                ? AppColors.teal.withValues(alpha: 0.48)
                : AppColors.border,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.m,
                AppSpacing.s,
                AppSpacing.m,
                AppSpacing.s,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: VehicleVisualImage(
                      vehicle: vehicle,
                      cacheWidth: 420,
                      fallbackBuilder: (_) =>
                          Icon(vehicleIcon(vehicle), color: accent, size: 64),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    title,
                    key: ValueKey('garage-vehicle-title-${vehicle.id}'),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h2.copyWith(fontSize: 18),
                  ),
                  if (vehicle.year != null)
                    Text(
                      '${vehicle.year}',
                      key: ValueKey('garage-vehicle-year-${vehicle.id}'),
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.navy.withValues(alpha: 0.72),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xs),
                  ColombianPlateBadge(plate: vehicle.plate),
                ],
              ),
            ),
            Positioned(
              top: AppSpacing.xs,
              right: AppSpacing.xs,
              child: Semantics(
                button: true,
                toggled: favorite,
                label: favorite ? 'Quitar de favoritos' : 'Agregar a favoritos',
                child: Tooltip(
                  message: favorite
                      ? 'Quitar de favoritos'
                      : 'Agregar a favoritos',
                  child: SizedBox.square(
                    dimension: 48,
                    child: Center(
                      child: Material(
                        color: favorite
                            ? AppColors.teal
                            : AppColors.surface.withValues(alpha: 0.94),
                        shape: const CircleBorder(),
                        elevation: 2,
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          key: ValueKey('garage-favorite-${vehicle.id}'),
                          customBorder: const CircleBorder(),
                          onTap: onFavorite,
                          child: SizedBox.square(
                            dimension: 36,
                            child: Icon(
                              favorite
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: favorite ? Colors.white : AppColors.navy,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarouselIndicator extends StatelessWidget {
  const _CarouselIndicator({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (count > 1)
          for (var i = 0; i < count; i += 1) ...[
            AnimatedContainer(
              key: ValueKey('garage-carousel-dot-$i'),
              duration: AppMotion.fade,
              width: i == index ? 16 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == index
                    ? AppColors.navy
                    : AppColors.border.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
          ],
        Text(
          '${index + 1} de $count',
          key: const ValueKey('garage-carousel-count'),
          style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _GarageInfoPanel extends StatelessWidget {
  const _GarageInfoPanel({
    required this.vehicle,
    required this.active,
    required this.onMakeActive,
  });

  final VehicleProfile vehicle;
  final bool active;
  final ValueChanged<VehicleProfile> onMakeActive;

  @override
  Widget build(BuildContext context) {
    final fields = [
      _InfoField(Icons.credit_card_outlined, 'Placa', vehicle.plate),
      _InfoField(
        Icons.directions_car_outlined,
        'Tipo',
        vehicleTypeLabel(vehicle),
      ),
      _InfoField(
        Icons.verified_user_outlined,
        'Estado',
        active ? 'Activo' : 'No activo',
        highlight: active,
      ),
      if (_hasText(vehicle.registrationCity))
        _InfoField(
          Icons.location_on_outlined,
          'Matrícula',
          vehicle.registrationCity!.trim(),
        ),
      _InfoField(
        Icons.badge_outlined,
        'Servicio',
        vehicle.serviceType == VehicleServiceType.taxi ? 'Taxi' : 'Particular',
      ),
      if (vehicle.year != null)
        _InfoField(Icons.calendar_today_outlined, 'Año', '${vehicle.year}'),
    ];

    return AppCard(
      key: const ValueKey('garage-info-panel'),
      padding: const EdgeInsets.all(AppSpacing.m),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final columnCount = textScale <= 1.25 ? 3 : 2;
          final spacing = AppSpacing.s;
          final columnWidth =
              (constraints.maxWidth - (spacing * (columnCount - 1))) /
              columnCount;
          return Wrap(
            spacing: spacing,
            runSpacing: AppSpacing.s,
            children: [
              for (final field in fields)
                SizedBox(
                  width: columnWidth,
                  child: _InfoCell(field: field),
                ),
              if (!active)
                SizedBox(
                  width: columnCount == 3
                      ? (columnWidth * 2) + spacing
                      : columnWidth,
                  child: SecondaryButton(
                    key: const ValueKey('garage-action-make-active'),
                    label: 'Hacer activo',
                    icon: Icons.check_circle_outline,
                    onPressed: () => onMakeActive(vehicle),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoField {
  const _InfoField(this.icon, this.label, this.value, {this.highlight = false});

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;
}

class _InfoCell extends StatelessWidget {
  const _InfoCell({required this.field});

  final _InfoField field;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          field.icon,
          color: AppColors.navy.withValues(alpha: 0.72),
          size: 18,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                field.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10.5,
                  height: 1.05,
                  color: AppColors.navy.withValues(alpha: 0.72),
                ),
              ),
              Container(
                padding: field.highlight
                    ? const EdgeInsets.symmetric(horizontal: 7, vertical: 1)
                    : EdgeInsets.zero,
                decoration: field.highlight
                    ? BoxDecoration(
                        color: AppColors.teal.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(AppRadius.chip),
                      )
                    : null,
                child: Text(
                  field.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong.copyWith(
                    fontSize: 13.5,
                    height: 1.05,
                    color: field.highlight ? AppColors.teal : AppColors.navy,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddVehicleCard extends StatelessWidget {
  const _AddVehicleCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return Semantics(
      button: true,
      label: 'Agregar vehículo',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('garage-add-vehicle'),
          onTap: onTap,
          child: SizedBox(
            height: textScale <= 1.25 ? _garageAddVehicleHeight : 132,
            child: CustomPaint(
              painter: _DashedBorderPainter(
                color: AppColors.blue.withValues(alpha: 0.38),
                radius: AppRadius.card,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.l,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.teal.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox.square(
                        dimension: 48,
                        child: Icon(
                          Icons.add_rounded,
                          color: AppColors.teal,
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Agregar vehículo',
                            style: AppTextStyles.bodyStrong.copyWith(
                              fontSize: 14,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            'Registra un nuevo vehículo y comienza a gestionarlo.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 11,
                              height: 1.05,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.navy,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GarageActions extends StatelessWidget {
  const _GarageActions({required this.vehicle, required this.onDelete});

  final VehicleProfile vehicle;
  final ValueChanged<VehicleProfile> onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        const actionGap = 4.0;
        final itemWidth = (constraints.maxWidth - (actionGap * 3)) / 4;
        final itemHeight = textScale <= 1.25 ? _garageActionHeight : 124.0;
        return Row(
          key: const ValueKey('garage-quick-actions'),
          children: [
            _QuickAction(
              width: itemWidth,
              height: itemHeight,
              keyName: 'garage-action-detail',
              icon: Icons.description_outlined,
              label: 'Detalle',
              onTap: () => context.push('/garage/vehicle/${vehicle.id}'),
            ),
            const SizedBox(width: actionGap),
            _QuickAction(
              width: itemWidth,
              height: itemHeight,
              keyName: 'garage-action-maintenance',
              icon: Icons.build_outlined,
              label: 'Mantenimiento',
              onTap: () => _showMaintenanceSoon(context),
            ),
            const SizedBox(width: actionGap),
            _QuickAction(
              width: itemWidth,
              height: itemHeight,
              keyName: 'garage-action-documents',
              icon: Icons.folder_copy_outlined,
              label: 'Documentos',
              onTap: () => context.push(
                '/apps/module/documentos?vehicleId=${vehicle.id}',
              ),
            ),
            const SizedBox(width: actionGap),
            _QuickAction(
              width: itemWidth,
              height: itemHeight,
              keyName: 'garage-action-delete',
              icon: Icons.delete_outline,
              label: 'Eliminar',
              danger: true,
              onTap: () => onDelete(vehicle),
            ),
          ],
        );
      },
    );
  }

  void _showMaintenanceSoon(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              key: const ValueKey('garage-maintenance-soon-sheet'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mantenimiento', style: AppTextStyles.h1),
                const SizedBox(height: AppSpacing.s),
                const Text(
                  'Mantenimiento estará disponible próximamente para registrar aceite, revisiones y servicios.',
                ),
                const SizedBox(height: AppSpacing.l),
                PrimaryButton(
                  label: 'Entendido',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.width,
    required this.height,
    required this.keyName,
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final double width;
  final double height;
  final String keyName;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.red : AppColors.navy;
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.input),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey(keyName),
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.input),
              border: Border.all(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
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

class _FilteredEmpty extends StatelessWidget {
  const _FilteredEmpty({required this.filter, required this.onShowAll});

  final GarageFilter filter;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final title = switch (filter) {
      GarageFilter.favorites => 'No tienes vehículos favoritos.',
      GarageFilter.active => 'No hay vehículo activo.',
      GarageFilter.all => 'No tienes vehículos todavía',
    };
    return EmptyState(
      key: ValueKey('garage-filter-empty-${filter.name}'),
      title: title,
      message: 'Puedes volver a ver todos tus vehículos cuando quieras.',
      actionLabel: 'Ver todos',
      onActionPressed: onShowAll,
    );
  }
}

class _GarageEmpty extends StatelessWidget {
  const _GarageEmpty({required this.alertPreferences});

  final PicoAlertPreferences alertPreferences;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GarageHeader(alertPreferences: alertPreferences),
          const SizedBox(height: AppSpacing.xl),
          EmptyState(
            key: const ValueKey('garage-empty-state'),
            title: 'No tienes vehículos todavía',
            message: 'Agrega tu primer vehículo para ver y gestionar su información local.',
            actionLabel: 'Agregar vehículo',
            actionKey: const ValueKey('garage-add-vehicle'),
            onActionPressed: () {
              context.push('${AppRoute.vehicleOnboarding.path}?return=garage');
            },
          ),
        ],
      ),
    );
  }
}

class _GarageSkeleton extends StatelessWidget {
  const _GarageSkeleton({required this.alertPreferences});

  final PicoAlertPreferences alertPreferences;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          _GarageHeader(alertPreferences: alertPreferences),
          const SizedBox(height: AppSpacing.l),
          AppSkeleton(
            height: _garageFilterVisualHeight,
            borderRadius: AppRadius.chip,
            width: MediaQuery.sizeOf(context).width,
          ),
          const SizedBox(height: AppSpacing.s),
          AppSkeleton(
            height: _garageCarouselHeight,
            borderRadius: AppRadius.card,
            width: MediaQuery.sizeOf(context).width,
          ),
          const SizedBox(height: AppSpacing.s),
          AppSkeleton(
            height: 112,
            borderRadius: AppRadius.card,
            width: MediaQuery.sizeOf(context).width,
          ),
        ],
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    const dash = 8.0;
    const gap = 6.0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = color;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.7),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

String vehicleDisplayName(VehicleProfile vehicle) {
  if (_hasText(vehicle.nickname)) {
    return vehicle.nickname!.trim();
  }
  final makeModel = vehicleMakeModel(vehicle);
  if (makeModel.isNotEmpty) {
    return makeModel;
  }
  if (_hasText(vehicle.subtype)) {
    return vehicle.subtype!.trim();
  }
  return vehicleTypeLabel(vehicle);
}

const _defaultAlertPreferences = PicoAlertPreferences(
  enabled: true,
  dayBeforeEnabled: true,
  sameDayEnabled: true,
  dayBeforeMinute: 19 * 60,
  sameDayMinute: 5 * 60,
  permissionRequested: false,
  permissionGranted: false,
);
