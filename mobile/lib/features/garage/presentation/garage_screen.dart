import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/shell/picoradar_app_header.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/design_system/actions_and_badges.dart';
import '../../../core/design_system/surfaces.dart';
import '../../home/presentation/home_screen.dart';
import '../../pico_placa/data/pico_preferences.dart';
import '../../visual_assets/presentation/visual_asset_widgets.dart';
import '../application/vehicle_associated_data_cleaner.dart';
import '../data/vehicle_profile.dart';
import '../data/vehicle_repository.dart';
import 'vehicle_deletion_window.dart';
import 'vehicle_display.dart';
import 'vehicle_plate_badge.dart';

enum GarageFilter { all, favorites }

const _garageViewportFraction = 0.70;
const _garageSideCardScale = 0.91;
const _garageCarouselHeight = 196.0;
const _garageCarouselMaxHeight = 360.0;
const _garageFilterVisualHeight = 46.0;
const _garageFilterWidthFactor = 0.86;
const _garageAddVehicleHeight = 66.0;
const _garageActionHeight = 64.0;

class GarageScreen extends ConsumerWidget {
  const GarageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehicleListProvider);
    final active = ref.watch(activeVehicleProvider);
    final alerts = ref.watch(picoAlertPreferencesProvider);
    final alertPreferences = alerts.asData?.value ?? _defaultAlertPreferences;

    return PicoSurface(
      child: vehicles.when(
        data: (items) {
          final activeId = active.hasValue ? active.requireValue?.id : null;
          final knownFavorite =
              activeId != null && items.any((item) => item.id == activeId);
          final retryFavorite = active.isLoading
              ? null
              : () => ref.invalidate(activeVehicleProvider);
          if (active.hasError && !knownFavorite) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _GarageHeader(alertPreferences: alertPreferences),
                  const SizedBox(height: AppSpacing.l),
                  _FavoriteReadError(
                    hasPrevious: false,
                    onRetry: retryFavorite,
                  ),
                ],
              ),
            );
          }
          if (items.isNotEmpty && active.isLoading && !active.hasValue) {
            return _GarageSkeleton(alertPreferences: alertPreferences);
          }

          if (items.isEmpty) {
            return _GarageEmpty(alertPreferences: alertPreferences);
          }

          return _GarageReady(
            vehicles: [...items]..sort(compareVehiclesAlphabetically),
            activeId: activeId,
            favoriteReadFailed: active.hasError,
            onRetryFavorite: retryFavorite,
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
}

class _GarageReady extends ConsumerStatefulWidget {
  const _GarageReady({
    required this.vehicles,
    required this.activeId,
    required this.favoriteReadFailed,
    required this.onRetryFavorite,
    required this.alertPreferences,
  });

  final List<VehicleProfile> vehicles;
  final String? activeId;
  final bool favoriteReadFailed;
  final VoidCallback? onRetryFavorite;
  final PicoAlertPreferences alertPreferences;

  @override
  ConsumerState<_GarageReady> createState() => _GarageReadyState();
}

class _GarageReadyState extends ConsumerState<_GarageReady> {
  GarageFilter _filter = GarageFilter.all;
  late PageController _controller;
  String? _focusedVehicleId;
  String? _deletingVehicleId;
  bool _savingFavorite = false;
  VehicleDeletionWindow? _pendingDeletion;
  final GlobalKey _garageChromeTopKey = GlobalKey();
  final GlobalKey _garageChromeBottomKey = GlobalKey();
  double? _measuredChromeHeight;
  Object? _carouselMinimumKey;
  double _carouselMinimumHeight = _garageCarouselHeight;

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
    _pendingDeletion?.cancel();
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
        final contentWidth = (constraints.maxWidth - horizontalPadding * 2)
            .clamp(0.0, 720.0);
        _scheduleChromeMeasurement();
        final measuredChrome = _measuredChromeHeight;
        final availableCarouselHeight =
            measuredChrome == null || constraints.maxHeight.isInfinite
            ? _garageCarouselHeight
            : constraints.maxHeight - measuredChrome;
        _updateCarouselMinimum(
          context: context,
          width: contentWidth,
          vehicles: filtered,
        );
        final fits =
            measuredChrome != null &&
            focused != null &&
            availableCarouselHeight >= _carouselMinimumHeight;
        return SingleChildScrollView(
          key: const ValueKey('garage-v2-scroll'),
          physics: fits
              ? const NeverScrollableScrollPhysics()
              : const ClampingScrollPhysics(),
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
                  SizeChangedLayoutNotifier(
                    child: Column(
                      key: _garageChromeTopKey,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _GarageHeader(
                          alertPreferences: widget.alertPreferences,
                        ),
                        const SizedBox(height: AppSpacing.s),
                        if (widget.favoriteReadFailed) ...[
                          _FavoriteReadError(
                            hasPrevious: true,
                            onRetry: widget.onRetryFavorite,
                          ),
                          const SizedBox(height: AppSpacing.s),
                        ],
                        _GarageFilterSegment(
                          selected: _filter,
                          onChanged: _selectFilter,
                        ),
                        const SizedBox(height: AppSpacing.s),
                      ],
                    ),
                  ),
                  if (focused == null)
                    _FilteredEmpty(filter: _filter, onShowAll: _showAll)
                  else ...[
                    _GarageCarousel(
                      vehicles: filtered,
                      focusedIndex: focusedIndex,
                      activeId: widget.activeId,
                      controller: _controller,
                      availableHeight: availableCarouselHeight,
                      onChanged: (index) {
                        if (index < 0 || index >= filtered.length) {
                          return;
                        }
                        setState(() {
                          _focusedVehicleId = filtered[index].id;
                        });
                      },
                      onFavorite:
                          _savingFavorite ||
                              _deletingVehicleId != null ||
                              widget.favoriteReadFailed
                          ? null
                          : _useAsFavorite,
                      onOpen: (vehicle) =>
                          context.push('/garage/vehicle/${vehicle.id}'),
                    ),
                    SizeChangedLayoutNotifier(
                      child: Column(
                        key: _garageChromeBottomKey,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: AppSpacing.s),
                          _CarouselIndicator(
                            count: filtered.length,
                            index: focusedIndex,
                          ),
                          const SizedBox(height: AppSpacing.s),
                          _GarageInfoPanel(vehicle: focused),
                          const SizedBox(height: AppSpacing.s),
                          _GarageActions(
                            vehicle: focused,
                            deleteInProgress:
                                _deletingVehicleId != null || _savingFavorite,
                            onDelete: _confirmDelete,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          _AddVehicleCard(onTap: _addVehicle),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _scheduleChromeMeasurement() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final topHeight = _garageChromeTopKey.currentContext?.size?.height ?? 0;
      final bottomHeight =
          _garageChromeBottomKey.currentContext?.size?.height ?? 0;
      final nextHeight = topHeight + bottomHeight + AppSpacing.s * 2;
      final previousHeight = _measuredChromeHeight;
      if (previousHeight == null || (previousHeight - nextHeight).abs() > 0.5) {
        setState(() {
          _measuredChromeHeight = nextHeight;
        });
      }
    });
  }

  void _updateCarouselMinimum({
    required BuildContext context,
    required double width,
    required List<VehicleProfile> vehicles,
  }) {
    if (vehicles.isEmpty) {
      _carouselMinimumHeight = _garageCarouselHeight;
      return;
    }
    final textScaler = MediaQuery.textScalerOf(context);
    final textScale = textScaler.scale(1);
    final directionality = Directionality.of(context);
    final titleWidth = width * _garageViewportFraction - 2 * AppSpacing.m;
    final measurementKey = (vehicles, titleWidth, directionality, textScale);
    if (_carouselMinimumKey == measurementKey) {
      return;
    }
    _carouselMinimumKey = measurementKey;
    var extraTitleHeight = 0.0;
    final painter = TextPainter(
      textDirection: directionality,
      textScaler: textScaler,
    );
    for (final vehicle in vehicles) {
      painter.text = TextSpan(
        text: vehicleDisplayName(vehicle),
        style: AppTextStyles.h2.copyWith(fontSize: 18),
      );
      painter.layout(maxWidth: titleWidth);
      final extra = painter.height - painter.preferredLineHeight;
      if (extra > extraTitleHeight) {
        extraTitleHeight = extra;
      }
    }
    painter.dispose();

    var cardHeight = textScale <= 1.25 ? _garageCarouselHeight : 232.0;
    for (final vehicle in vehicles) {
      final needed =
          VehiclePlateBadge.contentHeight(context, vehicle, titleWidth) +
          18 * textScale * 1.3 +
          (vehicle.year == null ? 0 : 22 * textScale) +
          118;
      if (needed > cardHeight) {
        cardHeight = needed.ceilToDouble();
      }
    }
    _carouselMinimumHeight = cardHeight + extraTitleHeight;
  }

  List<VehicleProfile> _filteredVehicles() {
    return _filteredVehiclesFor(
      vehicles: widget.vehicles,
      activeId: widget.activeId,
    );
  }

  List<VehicleProfile> _filteredVehiclesFor({
    required List<VehicleProfile> vehicles,
    required String? activeId,
  }) {
    return switch (_filter) {
      GarageFilter.all => vehicles,
      GarageFilter.favorites =>
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

  Future<void> _useAsFavorite(VehicleProfile vehicle) async {
    if (_deletingVehicleId != null ||
        _savingFavorite ||
        widget.favoriteReadFailed ||
        vehicle.id == widget.activeId) {
      return;
    }
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() => _savingFavorite = true);
    try {
      await ref.read(vehicleRepositoryProvider).setActiveVehicle(vehicle.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No pudimos guardar el favorito. Inténtalo de nuevo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingFavorite = false);
      container.invalidate(activeVehicleProvider);
    }
  }

  void _addVehicle() {
    context.push('${AppRoute.vehicleOnboarding.path}?return=garage');
  }

  Future<void> _confirmDelete(VehicleProfile vehicle) async {
    if (_deletingVehicleId != null || _savingFavorite) {
      return;
    }
    final repository = ref.read(vehicleRepositoryProvider);
    final cleaner = ref.read(vehicleAssociatedDataCleanerProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        var confirming = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('¿Eliminar este vehículo?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vehicle.plate),
                  const SizedBox(height: AppSpacing.m),
                  const Text(
                    'Se eliminarán el vehículo y sus datos locales asociados:\n'
                    'mantenimientos, obligaciones, documentos cifrados,\n'
                    'expedientes de Defensa, borrador de Peritajes y nota de Comparendos.\n'
                    'Tendrás 5 segundos para deshacer. Después, la eliminación será irreversible.',
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: confirming
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  key: const ValueKey('garage-confirm-delete-vehicle'),
                  onPressed: confirming || _deletingVehicleId != null
                      ? null
                      : () {
                          setDialogState(() {
                            confirming = true;
                          });
                          Navigator.of(context).pop(true);
                        },
                  child: const Text('Eliminar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || confirmed != true || _deletingVehicleId != null) {
      return;
    }

    setState(() {
      _deletingVehicleId = vehicle.id;
    });

    late final _GarageDeleteResult result;
    var committing = false;
    try {
      final pending = VehicleDeletionWindow(context);
      _pendingDeletion = pending;
      if (!await pending.wait()) return;
      _pendingDeletion = null;
      committing = true;
      result = await _deleteVehicleAndAssociatedData(
        repository: repository,
        cleaner: cleaner,
        vehicle: vehicle,
      );
    } on _GarageDeleteFailure catch (failure) {
      if (!mounted) {
        return;
      }
      setState(() {
        _deletingVehicleId = null;
      });
      messenger?.showSnackBar(SnackBar(content: Text(failure.message)));
      return;
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _deletingVehicleId = null;
      });
      messenger?.showSnackBar(
        const SnackBar(
          content: Text(
            'No pudimos completar la eliminación. Inténtalo de nuevo.',
          ),
        ),
      );
      return;
    } finally {
      _pendingDeletion = null;
      if (mounted) setState(() => _deletingVehicleId = null);
      if (committing) {
        container.invalidate(activeVehicleProvider);
        container.invalidate(vehicleListProvider);
        container.invalidate(obligationNotificationSyncProvider);
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _deletingVehicleId = null;
      if (!result.remainingVehicles.any(
        (item) => item.id == _focusedVehicleId,
      )) {
        _focusedVehicleId = _initialFocusedId(
          [...result.remainingVehicles]..sort(compareVehiclesAlphabetically),
          widget.activeId,
        );
      }
    });
    final message = result.message;
    if (message != null) {
      messenger?.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<_GarageDeleteResult> _deleteVehicleAndAssociatedData({
    required VehicleRepository repository,
    required VehicleAssociatedDataCleaner cleaner,
    required VehicleProfile vehicle,
  }) async {
    try {
      await cleaner.deleteForVehicle(vehicle.id);
    } catch (_) {
      throw const _GarageDeleteFailure(
        'No pudimos limpiar los datos asociados. Inténtalo de nuevo.',
      );
    }

    try {
      await repository.deleteVehicle(vehicle.id);
    } catch (_) {
      final rowStillExists = await repository.getVehicle(vehicle.id) != null;
      if (rowStillExists) {
        throw const _GarageDeleteFailure(
          'Los datos privados se limpiaron, pero no pudimos eliminar el vehículo. Inténtalo de nuevo.',
        );
      }
      return _GarageDeleteResult(
        remainingVehicles: await repository.listVehicles(),
        message: 'El vehículo se eliminó, pero no pudimos completar algunos ajustes locales.',
      );
    }
    return _GarageDeleteResult(
      remainingVehicles: await repository.listVehicles(),
    );
  }
}

class _GarageDeleteFailure implements Exception {
  const _GarageDeleteFailure(this.message);

  final String message;
}

class _FavoriteReadError extends StatelessWidget {
  const _FavoriteReadError({required this.hasPrevious, required this.onRetry});

  final bool hasPrevious;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const ValueKey('garage-favorite-read-error'),
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, color: AppColors.red),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text(
                  hasPrevious
                      ? 'No pudimos actualizar el favorito. Se muestra el último favorito conocido.'
                      : 'No pudimos cargar el vehículo favorito.',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          SecondaryButton(
            key: const ValueKey('garage-favorite-retry'),
            label: 'Reintentar',
            icon: Icons.refresh,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class _GarageDeleteResult {
  const _GarageDeleteResult({required this.remainingVehicles, this.message});

  final List<VehicleProfile> remainingVehicles;
  final String? message;
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
    final visualHeight = textScale <= 1.25
        ? _garageFilterVisualHeight
        : _garageFilterVisualHeight * textScale;
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
            height: visualHeight + 2,
            child: Center(
              child: Material(
                color: AppColors.surface,
                elevation: 2,
                shadowColor: AppColors.navy.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.chip),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  height: visualHeight,
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
                        label: 'Favorito',
                        icon: Icons.star_border_rounded,
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
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.25;
    return Expanded(
      flex: largeText ? (value == GarageFilter.favorites ? 4 : 3) : 1,
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
                child: Flex(
                  direction: largeText ? Axis.vertical : Axis.horizontal,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18, color: foreground),
                    SizedBox(
                      width: largeText ? 0 : AppSpacing.s,
                      height: largeText ? AppSpacing.xs : 0,
                    ),
                    Flexible(
                      child: Text(
                        label,
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

class _GarageCarousel extends StatefulWidget {
  const _GarageCarousel({
    required this.vehicles,
    required this.focusedIndex,
    required this.activeId,
    required this.controller,
    required this.availableHeight,
    required this.onChanged,
    required this.onFavorite,
    required this.onOpen,
  });

  final List<VehicleProfile> vehicles;
  final int focusedIndex;
  final String? activeId;
  final PageController controller;
  final double availableHeight;
  final ValueChanged<int> onChanged;
  final ValueChanged<VehicleProfile>? onFavorite;
  final ValueChanged<VehicleProfile> onOpen;

  @override
  State<_GarageCarousel> createState() => _GarageCarouselState();
}

class _GarageCarouselState extends State<_GarageCarousel> {
  Object? _titleMeasurementKey;
  double _extraTitleHeight = 0;

  @override
  Widget build(BuildContext context) {
    final vehicles = widget.vehicles;
    final onFavorite = widget.onFavorite;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final titleWidth =
            constraints.maxWidth * _garageViewportFraction - 2 * AppSpacing.m;
        final measurementKey = (
          vehicles,
          titleWidth,
          Directionality.of(context),
          MediaQuery.textScalerOf(context),
        );
        if (_titleMeasurementKey != measurementKey) {
          _titleMeasurementKey = measurementKey;
          final painter = TextPainter(
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          );
          _extraTitleHeight = 0;
          for (final vehicle in vehicles) {
            painter.text = TextSpan(
              text: vehicleDisplayName(vehicle),
              style: AppTextStyles.h2.copyWith(fontSize: 18),
            );
            painter.layout(maxWidth: titleWidth);
            final extra = painter.height - painter.preferredLineHeight;
            if (extra > _extraTitleHeight) _extraTitleHeight = extra;
          }
          painter.dispose();
        }
        var cardHeight = textScale <= 1.25 ? _garageCarouselHeight : 232.0;
        for (final vehicle in vehicles) {
          final needed =
              VehiclePlateBadge.contentHeight(context, vehicle, titleWidth) +
              18 * textScale * 1.3 +
              (vehicle.year == null ? 0 : 22 * textScale) +
              118;
          if (needed > cardHeight) cardHeight = needed.ceilToDouble();
        }
        final minimumHeight = cardHeight + _extraTitleHeight;
        final maximumHeight = minimumHeight > _garageCarouselMaxHeight
            ? minimumHeight
            : _garageCarouselMaxHeight;
        final adaptiveHeight = widget.availableHeight
            .clamp(minimumHeight, maximumHeight)
            .toDouble();
        return SizedBox(
          key: const ValueKey('garage-vehicle-carousel'),
          height: adaptiveHeight,
          child: PageView.builder(
            controller: widget.controller,
            itemCount: vehicles.length,
            onPageChanged: widget.onChanged,
            padEnds: true,
            itemBuilder: (context, index) {
              final vehicle = vehicles[index];
              final focused = index == widget.focusedIndex;
              return AnimatedScale(
                duration: AppMotion.carouselSnap,
                curve: AppMotion.standardCurve,
                scale: focused ? 1 : _garageSideCardScale,
                child: _GarageVehicleCard(
                  vehicle: vehicle,
                  favorite: vehicle.id == widget.activeId,
                  focused: focused,
                  onFavorite: onFavorite == null
                      ? null
                      : () => onFavorite(vehicle),
                  onOpen: () => widget.onOpen(vehicle),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _GarageVehicleCard extends StatelessWidget {
  const _GarageVehicleCard({
    required this.vehicle,
    required this.favorite,
    required this.focused,
    required this.onFavorite,
    required this.onOpen,
  });

  final VehicleProfile vehicle;
  final bool favorite;
  final bool focused;
  final VoidCallback? onFavorite;
  final VoidCallback onOpen;

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
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: favorite
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
                      child: KeyedSubtree(
                        key: ValueKey('garage-vehicle-art-${vehicle.id}'),
                        child: VehicleVisualImage(
                          vehicle: vehicle,
                          cacheWidth: 420,
                          fallbackBuilder: (_) => Icon(
                            vehicleIcon(vehicle),
                            color: accent,
                            size: 64,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      title,
                      key: ValueKey('garage-vehicle-title-${vehicle.id}'),
                      textAlign: TextAlign.center,
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
                    VehiclePlateBadge(vehicle: vehicle, compact: true),
                  ],
                ),
              ),
              Positioned(
                top: AppSpacing.xs,
                right: AppSpacing.xs,
                child: Semantics(
                  button: true,
                  enabled: onFavorite != null,
                  toggled: favorite,
                  label: favorite ? 'Vehículo favorito' : 'Usar como favorito',
                  child: Tooltip(
                    excludeFromSemantics: true,
                    message: favorite
                        ? 'Vehículo favorito'
                        : 'Usar como favorito',
                    child: GestureDetector(
                      // A disabled favorite control must not open its parent vehicle card.
                      onTap: onFavorite == null ? () {} : null,
                      behavior: HitTestBehavior.opaque,
                      excludeFromSemantics: true,
                      child: Opacity(
                        opacity: onFavorite == null ? 0.45 : 1,
                        child: InkWell(
                          key: ValueKey('garage-favorite-${vehicle.id}'),
                          onTap: onFavorite,
                          borderRadius: BorderRadius.circular(24),
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
                                child: SizedBox.square(
                                  dimension: 36,
                                  child: Icon(
                                    favorite
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    color: favorite
                                        ? Colors.white
                                        : AppColors.navy,
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
                ),
              ),
            ],
          ),
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
  const _GarageInfoPanel({required this.vehicle});

  final VehicleProfile vehicle;

  @override
  Widget build(BuildContext context) {
    final fields = [
      _InfoField(Icons.credit_card_outlined, 'Placa', vehicle.plate),
      _InfoField(
        Icons.directions_car_outlined,
        'Tipo',
        vehicleTypeLabel(vehicle),
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
      padding: const EdgeInsets.all(12),
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
            runSpacing: 6,
            children: [
              for (final field in fields)
                SizedBox(
                  width: columnWidth,
                  child: _InfoCell(field: field),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoField {
  const _InfoField(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;
}

class _InfoCell extends StatelessWidget {
  const _InfoCell({required this.field});

  final _InfoField field;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 10.5,
                      height: 1.05,
                      color: AppColors.navy.withValues(alpha: 0.72),
                    ),
                  ),
                  Text(
                    field.value,
                    style: AppTextStyles.bodyStrong.copyWith(
                      fontSize: 13.5,
                      height: 1.05,
                      color: AppColors.navy,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
            height: textScale <= 1.25
                ? _garageAddVehicleHeight
                : textScale >= 1.8
                ? 160
                : 132,
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
  const _GarageActions({
    required this.vehicle,
    required this.deleteInProgress,
    required this.onDelete,
  });

  final VehicleProfile vehicle;
  final bool deleteInProgress;
  final ValueChanged<VehicleProfile> onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        const actionGap = 4.0;
        final itemWidth = (constraints.maxWidth - (actionGap * 2)) / 3;
        if (textScale > 1.25) {
          final accessibleActionHeight = textScale >= 1.8 ? 96.0 : 72.0;
          return Column(
            key: const ValueKey('garage-quick-actions'),
            children: [
              _QuickAction(
                width: constraints.maxWidth,
                height: accessibleActionHeight,
                keyName: 'garage-action-maintenance',
                icon: Icons.build_outlined,
                label: 'Mantenimiento',
                onTap: () => context.push(
                  _vehicleModuleLocation('talleres', vehicle.id),
                ),
              ),
              const SizedBox(height: actionGap),
              _QuickAction(
                width: constraints.maxWidth,
                height: accessibleActionHeight,
                keyName: 'garage-action-documents',
                icon: Icons.folder_copy_outlined,
                label: 'Documentos',
                onTap: () => context.push(
                  _vehicleModuleLocation('documentos', vehicle.id),
                ),
              ),
              const SizedBox(height: actionGap),
              _QuickAction(
                width: constraints.maxWidth,
                height: accessibleActionHeight,
                keyName: 'garage-action-delete',
                icon: Icons.delete_outline,
                label: 'Eliminar',
                danger: true,
                onTap: deleteInProgress ? null : () => onDelete(vehicle),
              ),
            ],
          );
        }
        return Row(
          key: const ValueKey('garage-quick-actions'),
          children: [
            _QuickAction(
              width: itemWidth,
              height: _garageActionHeight,
              keyName: 'garage-action-maintenance',
              icon: Icons.build_outlined,
              label: 'Mantenimiento',
              onTap: () =>
                  context.push(_vehicleModuleLocation('talleres', vehicle.id)),
            ),
            const SizedBox(width: actionGap),
            _QuickAction(
              width: itemWidth,
              height: _garageActionHeight,
              keyName: 'garage-action-documents',
              icon: Icons.folder_copy_outlined,
              label: 'Documentos',
              onTap: () => context.push(
                _vehicleModuleLocation('documentos', vehicle.id),
              ),
            ),
            const SizedBox(width: actionGap),
            _QuickAction(
              width: itemWidth,
              height: _garageActionHeight,
              keyName: 'garage-action-delete',
              icon: Icons.delete_outline,
              label: 'Eliminar',
              danger: true,
              onTap: deleteInProgress ? null : () => onDelete(vehicle),
            ),
          ],
        );
      },
    );
  }
}

String _vehicleModuleLocation(String moduleId, String vehicleId) {
  return Uri(
    path: '/apps/module/$moduleId',
    queryParameters: {'vehicleId': vehicleId},
  ).toString();
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
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final Color color;
    if (!enabled) {
      color = AppColors.navy.withValues(alpha: 0.32);
    } else if (danger) {
      color = AppColors.red;
    } else {
      color = AppColors.navy;
    }
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
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.visible,
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
      GarageFilter.favorites => 'No hay vehículo favorito.',
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
