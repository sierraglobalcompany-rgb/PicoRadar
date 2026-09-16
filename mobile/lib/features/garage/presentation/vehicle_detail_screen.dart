import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_clock.dart';
import '../../../app/app_providers.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_tokens.dart';
import '../../onboarding/data/registration_city_catalog.dart';
import '../../vehicle_status/data/tax_authority_resolution.dart';
import '../../vehicle_status/domain/vehicle_obligation.dart';
import '../../vehicle_status/platform/obligation_notifications.dart';
import '../../visual_assets/presentation/visual_asset_widgets.dart';
import '../application/vehicle_associated_data_cleaner.dart';
import '../data/vehicle_profile.dart';
import '../data/vehicle_repository.dart';
import 'vehicle_deletion_window.dart';
import 'vehicle_display.dart';
import 'vehicle_plate_badge.dart';

class VehicleDetailScreen extends ConsumerWidget {
  const VehicleDetailScreen({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehicleListProvider);

    return SafeArea(
      child: vehicles.when(
        data: (items) {
          final vehicle = _findVehicle(items, vehicleId);
          if (vehicle == null) {
            return _MissingVehicle(onBack: () => context.go('/garage'));
          }

          return _VehicleDetail(key: ValueKey(vehicle.id), vehicle: vehicle);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(error.toString()),
          );
        },
      ),
    );
  }

  VehicleProfile? _findVehicle(List<VehicleProfile> vehicles, String id) {
    for (final vehicle in vehicles) {
      if (vehicle.id == id) {
        return vehicle;
      }
    }
    return null;
  }
}

class _VehicleDetail extends ConsumerStatefulWidget {
  const _VehicleDetail({required this.vehicle, super.key});

  final VehicleProfile vehicle;

  @override
  ConsumerState<_VehicleDetail> createState() => _VehicleDetailState();
}

class _VehicleDetailState extends ConsumerState<_VehicleDetail> {
  bool _deleting = false;
  VehicleDeletionWindow? _pendingDeletion;

  VehicleProfile get vehicle => widget.vehicle;

  @override
  void dispose() {
    _pendingDeletion?.cancel();
    super.dispose();
  }

  bool _more = false;
  bool? _split;
  Size? _layoutSize;
  double? _textScale;
  String? _metadataKey;

  void _back() {
    if (_more) {
      _pendingDeletion?.cancel();
      setState(() => _more = false);
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/garage');
    }
  }

  @override
  Widget build(BuildContext context) {
    final obligations = ref.watch(vehicleObligationsProvider(vehicle.id));
    final taxCatalog = ref.watch(taxCatalogProvider);
    final registrationCities = ref.watch(registrationCityCatalogProvider);
    final now = ref.watch(bogotaNowProvider);
    final city = vehicle.registrationCity?.trim();
    final registration = city == null || city.isEmpty ? 'Sin registrar' : city;
    final name = vehicle.nickname?.trim();
    final makeModel = vehicleMakeModel(vehicle);
    final identity = name != null && name.isNotEmpty
        ? name
        : makeModel.isNotEmpty
        ? makeModel
        : 'Mi vehículo';
    final byType = {
      for (final item in obligations.asData?.value ?? <VehicleObligation>[])
        item.type: item,
    };
    String summary(VehicleObligationType type) {
      if (obligations.hasError) return 'No disponible';
      if (!obligations.hasValue) return 'Cargando…';
      if (type == VehicleObligationType.tax) {
        if (taxCatalog.hasError) return 'No disponible';
        if (!taxCatalog.hasValue) return 'Cargando…';
        final catalog = taxCatalog.requireValue;
        final authority = catalog.authorityById(
          byType[type]?.details['authorityId'] ??
              suggestTaxAuthority(
                catalog,
                registrationCities.asData?.value,
                vehicle.registrationCity,
              ),
        );
        final calendar = authority == null
            ? null
            : catalog.calendarFor(authority.id, now.year);
        if (calendar == null ||
            calendar.status == 'pending' ||
            calendar.status == 'withdrawn' ||
            calendar.activeEvents.isEmpty) {
          return 'Calendario pendiente';
        }
        final stale = ref.watch(
          appClockProvider.select(
            (instant) =>
                calendar.reviewAfter != null &&
                !instant.isBefore(calendar.reviewAfter!),
          ),
        );
        if (stale) {
          return 'Revisión pendiente';
        }
        return calendar.status == 'verified'
            ? 'Calendario oficial'
            : 'Calendario parcial';
      }
      final item = byType[type];
      final state = evaluateVehicleObligationState(
        dueDate: item?.dueDate,
        nowBogota: now,
      );
      if (item?.dueDate != null &&
          (state == VehicleObligationState.valid ||
              state == VehicleObligationState.dueSoon)) {
        return 'Vence ${formatShortDate(item!.dueDate!)}';
      }
      return obligationStatusText(type, state);
    }

    final cards = [
      _DetailAction(
        id: 'pico',
        title: 'Pico y placa',
        status: 'Estado y calendario',
        icon: Icons.event_available_outlined,
        onTap: () => context.push(
          picoShellLocation(
            origin: PicoRouteOrigin.garage,
            vehicleId: vehicle.id,
          ),
        ),
      ),
      for (final (type, title, icon, id) in [
        (
          VehicleObligationType.soat,
          'SOAT',
          Icons.verified_user_outlined,
          'soat',
        ),
        (
          VehicleObligationType.rtm,
          'Tecnomecánica',
          Icons.assignment_turned_in_outlined,
          'rtm',
        ),
        (
          VehicleObligationType.insurance,
          'Seguro',
          Icons.health_and_safety_outlined,
          'insurance',
        ),
        (
          VehicleObligationType.tax,
          'Impuestos',
          Icons.account_balance_outlined,
          'tax',
        ),
      ])
        _DetailAction(
          id: id,
          title: title,
          status: summary(type),
          icon: icon,
          onTap: () => context.push(
            '${obligationRouteForType(type)}?vehicleId=${vehicle.id}',
          ),
        ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.clamp(0.0, 760.0);
          final contentWidth = width - 32;
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final size = Size(width, constraints.maxHeight);
          if (_layoutSize != size ||
              _textScale != scale ||
              _metadataKey != '$identity|$registration') {
            _metadataKey = '$identity|$registration';
            _layoutSize = size;
            _textScale = scale;
            _split = null;
          }
          final titleHeight =
              _detailTextHeight(
                context,
                'Detalle del vehículo',
                _detailHeading,
                width - 80,
              ) +
              16;
          final headerHeight = titleHeight.clamp(48.0, double.infinity);
          final plateWidth = 96.0 * scale.clamp(1.0, 2.0);
          final plateHeight = VehiclePlateBadge.contentHeight(
            context,
            vehicle,
            plateWidth,
            compactWidth: plateWidth,
          );
          final metadata = _DetailIdentity(
            identity: identity,
            registration: registration,
            onEdit: () => context.push('/garage/vehicle/${vehicle.id}/edit'),
          );
          final metadataHeight = metadata.height(context, contentWidth);
          final pairWidth = (contentWidth - 8) / 2;
          final paired = cards
              .skip(3)
              .every((card) => card.titleFits(context, pairWidth));
          final heights = cards
              .map((card) => card.height(context, contentWidth))
              .toList();
          final pairHeight = paired
              ? cards
                    .skip(3)
                    .map((card) => card.height(context, pairWidth))
                    .reduce((a, b) => a > b ? a : b)
              : heights[3] + heights[4] + 8;
          final deleteHeight = _detailButtonHeight(
            context,
            'Eliminar vehículo',
            contentWidth,
          );
          final fullActionsHeight =
              heights[0] +
              heights[1] +
              heights[2] +
              pairHeight +
              deleteHeight +
              32;
          final minHeroHeight = headerHeight + 110 + plateHeight / 2;
          // Reserve date/error text before loading completes so controls stay in place.
          final reserve = cards
              .skip(1)
              .take(3)
              .map(
                (card) =>
                    card.height(
                      context,
                      card.id == 'insurance' && paired
                          ? pairWidth
                          : contentWidth,
                      statusOverride: 'Vence 30 sep',
                    ) -
                    card.height(
                      context,
                      card.id == 'insurance' && paired
                          ? pairWidth
                          : contentWidth,
                    ),
              )
              .fold<double>(0, (sum, extra) => sum + (extra > 0 ? extra : 0));
          _split ??=
              minHeroHeight +
                  metadataHeight +
                  fullActionsHeight +
                  reserve +
                  24 >
              constraints.maxHeight;
          final split = _split!;
          if (!split) _more = false;
          final moreHeight = _detailButtonHeight(
            context,
            'Más gestiones',
            contentWidth,
          );
          final actionsHeight = !split
              ? fullActionsHeight
              : _more
              ? heights[2] + heights[3] + heights[4] + deleteHeight + 24
              : heights[0] + heights[1] + moreHeight + 16;
          final identityHeight = _more ? 0.0 : metadataHeight;
          final heroHeight =
              constraints.maxHeight - actionsHeight - identityHeight - 24;
          void openPicker() => showVehicleVisualPicker(context, ref, vehicle);

          Widget action(int index, [double? height]) =>
              SizedBox(height: height ?? heights[index], child: cards[index]);
          final delete = SizedBox(
            height: deleteHeight,
            child: OutlinedButton.icon(
              key: const ValueKey('detail-delete-vehicle'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.red,
                side: const BorderSide(color: AppColors.red),
                backgroundColor: AppColors.red.withValues(alpha: .025),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
              ),
              onPressed: _deleting ? null : _confirmDelete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Eliminar vehículo', style: _detailTitle),
            ),
          );

          return PopScope(
            canPop: !_more,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop && _more) _back();
            },
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: width,
                child: Column(
                  children: [
                    SizedBox(
                      height: heroHeight,
                      child: _DetailHero(
                        vehicle: vehicle,
                        title: _more ? 'Más gestiones' : 'Detalle del vehículo',
                        headerHeight: headerHeight,
                        plateHeight: plateHeight,
                        plateWidth: plateWidth,
                        compact: split,
                        onBack: _back,
                        onChangeImage: openPicker,
                      ),
                    ),
                    if (!_more)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          height: metadataHeight,
                          child: metadata,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!split || !_more) ...[
                            action(0),
                            const SizedBox(height: 8),
                            action(1),
                            const SizedBox(height: 8),
                          ],
                          if (!split || _more) ...[
                            action(2),
                            const SizedBox(height: 8),
                            if (!split && paired)
                              SizedBox(
                                height: pairHeight,
                                child: Row(
                                  children: [
                                    Expanded(child: cards[3]),
                                    const SizedBox(width: 8),
                                    Expanded(child: cards[4]),
                                  ],
                                ),
                              )
                            else ...[
                              action(3),
                              const SizedBox(height: 8),
                              action(4),
                            ],
                            const SizedBox(height: 8),
                            delete,
                          ] else
                            SizedBox(
                              height: moreHeight,
                              child: OutlinedButton.icon(
                                key: const ValueKey('detail-more-actions'),
                                onPressed: () => setState(() => _more = true),
                                icon: const Icon(Icons.more_horiz),
                                label: const Text(
                                  'Más gestiones',
                                  style: _detailTitle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete() async {
    if (_deleting) return;
    final repository = ref.read(vehicleRepositoryProvider);
    final cleaner = ref.read(vehicleAssociatedDataCleanerProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final target = vehicle;
    var confirmed = false;
    var committing = false;
    var deleted = false;
    String? message;
    setState(() => _deleting = true);
    try {
      confirmed =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('¿Eliminar este vehículo?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(target.plate),
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
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  key: const ValueKey('confirm-delete-vehicle'),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Eliminar'),
                ),
              ],
            ),
          ) ==
          true;
      if (!confirmed || !mounted) return;
      final pending = VehicleDeletionWindow(context);
      _pendingDeletion = pending;
      if (!await pending.wait()) return;
      _pendingDeletion = null;
      committing = true;
      message = await _deleteVehicleAndAssociatedData(
        repository,
        cleaner,
        target.id,
      );
      deleted = true;
    } on _VehicleDeleteFailure catch (failure) {
      message = failure.message;
    } catch (_) {
      message = 'No pudimos completar la eliminación. Inténtalo de nuevo.';
    } finally {
      _pendingDeletion = null;
      if (committing) {
        container.invalidate(activeVehicleProvider);
        container.invalidate(vehicleListProvider);
        container.invalidate(obligationNotificationSyncProvider);
      }
      if (mounted) setState(() => _deleting = false);
    }
    if (!mounted) return;
    if (deleted) context.go('/garage');
    if (message != null) {
      messenger?.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<String?> _deleteVehicleAndAssociatedData(
    VehicleRepository repository,
    VehicleAssociatedDataCleaner cleaner,
    String vehicleId,
  ) async {
    try {
      await cleaner.deleteForVehicle(vehicleId);
    } catch (_) {
      throw const _VehicleDeleteFailure(
        'No pudimos limpiar los datos asociados. Inténtalo de nuevo.',
      );
    }
    try {
      await repository.deleteVehicle(vehicleId);
    } catch (_) {
      if (await repository.getVehicle(vehicleId) != null) {
        throw const _VehicleDeleteFailure(
          'Los datos privados se limpiaron, pero no pudimos eliminar el vehículo. Inténtalo de nuevo.',
        );
      }
      return 'El vehículo se eliminó, pero no pudimos completar algunos ajustes locales.';
    }
    return null;
  }
}

class _VehicleDeleteFailure implements Exception {
  const _VehicleDeleteFailure(this.message);

  final String message;
}

const _detailHeading = TextStyle(
  letterSpacing: 0,
  fontSize: 20,
  fontWeight: FontWeight.w700,
  height: 1.15,
  color: Colors.white,
);
const _detailTitle = TextStyle(
  letterSpacing: 0,
  fontSize: 16,
  fontWeight: FontWeight.w700,
  height: 1.15,
);
const _detailSubtitle = TextStyle(
  letterSpacing: 0,
  fontSize: 14,
  height: 1.2,
  color: Color(0xFF52677B),
);

double _detailTextHeight(
  BuildContext context,
  String value,
  TextStyle style,
  double width,
) {
  final painter = TextPainter(
    text: TextSpan(
      text: value,
      style: Theme.of(context).textTheme.bodyMedium!.merge(style),
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: width.clamp(1.0, double.infinity));
  final height = painter.height.ceilToDouble();
  painter.dispose();
  return height;
}

double _detailButtonHeight(BuildContext context, String label, double width) =>
    (_detailTextHeight(context, label, _detailTitle, width - 80) + 20).clamp(
      48.0,
      double.infinity,
    );

class _DetailHero extends StatelessWidget {
  const _DetailHero({
    required this.vehicle,
    required this.title,
    required this.headerHeight,
    required this.plateHeight,
    required this.plateWidth,
    required this.compact,
    required this.onBack,
    required this.onChangeImage,
  });
  final VehicleProfile vehicle;
  final String title;
  final double headerHeight;
  final double plateHeight;
  final double plateWidth;
  final bool compact;
  final VoidCallback onBack;
  final VoidCallback onChangeImage;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageWidth = compact
            ? constraints.maxWidth - plateWidth - 48
            : constraints.maxWidth - 32;
        final image = Semantics(
          button: true,
          label: 'Cambiar imagen del vehículo',
          child: InkWell(
            key: const ValueKey('detail-vehicle-image'),
            onTap: onChangeImage,
            child: VehicleVisualImage(
              vehicle: vehicle,
              cacheWidth: (imageWidth * MediaQuery.devicePixelRatioOf(context))
                  .ceil(),
              fallbackBuilder: (_) =>
                  Icon(vehicleIcon(vehicle), size: 72, color: Colors.white),
            ),
          ),
        );
        final plate = SizedBox(
          width: plateWidth,
          height: plateHeight,
          child: Center(
            child: VehiclePlateBadge(
              vehicle: vehicle,
              compact: true,
              compactWidth: plateWidth,
            ),
          ),
        );
        final camera = IconButton.filled(
          key: const ValueKey('detail-change-vehicle-image'),
          tooltip: 'Cambiar imagen del vehículo',
          onPressed: onChangeImage,
          style: IconButton.styleFrom(
            backgroundColor: AppColors.teal,
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 48),
            side: const BorderSide(color: Colors.white, width: 2),
          ),
          icon: const Icon(Icons.camera_alt_outlined, size: 26),
        );
        return Stack(
          children: [
            Positioned.fill(
              bottom: compact ? 0 : plateHeight / 2,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(22),
                  ),
                ),
              ),
            ),
            Column(
              children: [
                SizedBox(
                  height: headerHeight,
                  child: Row(
                    children: [
                      IconButton(
                        key: const ValueKey('detail-back'),
                        onPressed: onBack,
                        tooltip: 'Volver',
                        color: Colors.white,
                        icon: const Icon(Icons.arrow_back),
                      ),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(title, style: _detailHeading),
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                  ),
                ),
                Expanded(
                  child: compact
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Stack(
                                  children: [
                                    Positioned.fill(child: image),
                                    Positioned(top: 0, right: 0, child: camera),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              plate,
                            ],
                          ),
                        )
                      : Stack(
                          children: [
                            Positioned.fill(
                              bottom: plateHeight / 2 + 2,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: image,
                              ),
                            ),
                            Positioned(top: 4, right: 16, child: camera),
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: plate,
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _DetailIdentity extends StatelessWidget {
  const _DetailIdentity({
    required this.identity,
    required this.registration,
    required this.onEdit,
  });
  final String identity;
  final String registration;
  final VoidCallback onEdit;
  double height(BuildContext context, double width) {
    final editWidth = _editWidth(context, width);
    final cityHeight =
        _detailTextHeight(
          context,
          'Matrícula',
          _detailSubtitle,
          width - editWidth - 16,
        ) +
        _detailTextHeight(
          context,
          registration,
          _detailTitle,
          width - editWidth - 16,
        ) +
        2;
    final rowHeight = cityHeight.clamp(
      editWidth == 48
          ? 48
          : (_detailTextHeight(
                      context,
                      'Editar',
                      _detailTitle,
                      editWidth - 46,
                    ) +
                    16)
                .clamp(48.0, double.infinity),
      double.infinity,
    );
    return _detailTextHeight(context, identity, _detailTitle, width) +
        rowHeight +
        12;
  }

  double _editWidth(BuildContext context, double width) {
    final requested = 104 * MediaQuery.textScalerOf(context).scale(1);
    return requested > width * .40 ? 48 : requested;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final editWidth = _editWidth(context, constraints.maxWidth);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(identity, style: _detailTitle.copyWith(color: AppColors.navy)),
          const SizedBox(height: 4),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Matrícula', style: _detailSubtitle),
                      const SizedBox(height: 2),
                      Text(
                        registration,
                        style: _detailTitle.copyWith(color: AppColors.navy),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const SizedBox(height: 32, child: VerticalDivider(width: 1)),
                const SizedBox(width: 7),
                SizedBox(
                  width: editWidth,
                  child: editWidth == 48
                      ? IconButton.outlined(
                          key: const ValueKey('detail-edit-vehicle'),
                          tooltip: 'Editar',
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_outlined),
                        )
                      : OutlinedButton.icon(
                          key: const ValueKey('detail-edit-vehicle'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                          ),
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_outlined, size: 22),
                          label: const Text('Editar', style: _detailTitle),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      );
    },
  );
}

class _DetailAction extends StatelessWidget {
  const _DetailAction({
    required this.id,
    required this.title,
    required this.status,
    required this.icon,
    required this.onTap,
  });
  final String id;
  final String title;
  final String status;
  final IconData icon;
  final VoidCallback onTap;

  bool titleFits(BuildContext context, double width) {
    final painter = TextPainter(
      text: TextSpan(
        text: title,
        style: Theme.of(context).textTheme.bodyMedium!.merge(_detailTitle),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final fits = painter.width <= width - 72;
    painter.dispose();
    return fits;
  }

  double height(BuildContext context, double width, {String? statusOverride}) =>
      (_detailTextHeight(context, title, _detailTitle, width - 72) +
              _detailTextHeight(
                context,
                statusOverride ?? status,
                _detailSubtitle,
                width - 72,
              ) +
              18)
          .clamp(56.0, double.infinity);

  @override
  Widget build(BuildContext context) => Material(
    key: ValueKey('detail-status-$id'),
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
      side: const BorderSide(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: AppColors.teal, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: _detailTitle.copyWith(color: AppColors.navy),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status,
                    style: _detailSubtitle,
                    semanticsLabel: status.startsWith('Vence')
                        ? '$status, según fecha guardada'
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 16, color: AppColors.navy),
          ],
        ),
      ),
    ),
  );
}

class _MissingVehicle extends StatelessWidget {
  const _MissingVehicle({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Vehículo no encontrado'),
            const SizedBox(height: AppSpacing.l),
            FilledButton(
              onPressed: onBack,
              child: const Text('Volver al Garaje'),
            ),
          ],
        ),
      ),
    );
  }
}
