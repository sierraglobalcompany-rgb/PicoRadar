import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_providers.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/design_system/branding.dart';
import '../../../core/design_system/surfaces.dart';
import '../../garage/data/vehicle_profile.dart';
import '../../garage/presentation/vehicle_display.dart';
import '../../home/presentation/pico_notification_sheet.dart';
import '../../location/application/location_controller.dart';
import '../../visual_assets/presentation/visual_asset_widgets.dart';
import '../data/pico_preferences.dart';
import '../data/restriction_store.dart';
import '../domain/city_restriction_summary.dart';
import '../domain/restriction_day_evaluation.dart';

class PicoDetailScreen extends ConsumerWidget {
  const PicoDetailScreen({this.vehicleId, this.jurisdictionId, super.key});

  final String? vehicleId;
  final String? jurisdictionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seed = ref.watch(bundledRestrictionsProvider);
    final vehicles = ref.watch(vehicleListProvider);
    final active = ref.watch(activeVehicleProvider);
    final jurisdictions = ref.watch(restrictionJurisdictionsProvider);
    final selected = ref.watch(selectedPicoJurisdictionIdProvider);

    return Scaffold(
      body: PicoSurface(
        child: seed.when(
          data: (_) => jurisdictions.when(
            data: (jurisdictionItems) => selected.when(
              data: (selectedId) => vehicles.when(
                data: (vehicleItems) => active.when(
                  data: (activeVehicle) {
                    final explicitVehicle = _findVehicle(
                      vehicleItems,
                      vehicleId,
                    );
                    if (_hasQueryValue(vehicleId) && explicitVehicle != null) {
                      final selectedJurisdiction = _findJurisdiction(
                        jurisdictionItems,
                        selectedId,
                      );
                      final transient = _findJurisdiction(
                        jurisdictionItems,
                        jurisdictionId,
                      );
                      final jurisdiction = transient ?? selectedJurisdiction;
                      if (jurisdiction == null) {
                        return const _Message(
                          'Selecciona tu ciudad en la app.',
                        );
                      }
                      return _PersonalPicoView(
                        vehicle: explicitVehicle,
                        jurisdiction: jurisdiction,
                      );
                    }
                    if (_hasQueryValue(vehicleId) && explicitVehicle == null) {
                      final fallback = activeVehicle;
                      final jurisdiction = _findJurisdiction(
                        jurisdictionItems,
                        selectedId,
                      );
                      if (fallback == null || jurisdiction == null) {
                        return const _Message('No pudimos abrir ese vehículo.');
                      }
                      return _PersonalPicoView(
                        vehicle: fallback,
                        jurisdiction: jurisdiction,
                      );
                    }
                    return _CityPicoView(
                      jurisdictions: jurisdictionItems,
                      selectedJurisdictionId: selectedId,
                      vehicles: vehicleItems,
                    );
                  },
                  loading: _Loading.new,
                  error: (error, stackTrace) => _Message(error.toString()),
                ),
                loading: _Loading.new,
                error: (error, stackTrace) => _Message(error.toString()),
              ),
              loading: _Loading.new,
              error: (error, stackTrace) => _Message(error.toString()),
            ),
            loading: _Loading.new,
            error: (error, stackTrace) => _Message(error.toString()),
          ),
          loading: _Loading.new,
          error: (error, stackTrace) => _Message(error.toString()),
        ),
      ),
    );
  }
}

class _PersonalPicoView extends ConsumerWidget {
  const _PersonalPicoView({required this.vehicle, required this.jurisdiction});

  final VehicleProfile vehicle;
  final RestrictionJurisdiction jurisdiction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(bogotaNowProvider);
    final alertPreferences = ref
        .watch(picoAlertPreferencesProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => _defaultAlertPreferences,
        );
    return FutureBuilder<RestrictionRuleSet>(
      future: ref
          .read(restrictionStoreProvider)
          .loadCoverage(
            jurisdiction.id,
            vehicle.kind,
            vehicle.serviceType,
            ref.read(currentInstantProvider),
          ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const _Loading();
        }
        final ruleSet = snapshot.data!;
        final today = _evaluate(ruleSet, jurisdiction, vehicle, now);
        final tomorrowDate = DateTime(now.year, now.month, now.day + 1);
        final tomorrow = _evaluate(
          ruleSet,
          jurisdiction,
          vehicle,
          tomorrowDate,
        );
        final futureDays = [
          for (var offset = 1; offset <= 14; offset += 1)
            DateTime(now.year, now.month, now.day + offset),
        ];
        final nextRestriction = _nextRestriction(
          ruleSet,
          jurisdiction,
          vehicle,
          now,
        );

        return ListView(
          key: const ValueKey('pico-scroll-root'),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.s,
            AppSpacing.l,
            AppSpacing.xl,
          ),
          children: [
            _PersonalPicoHeader(alertPreferences: alertPreferences),
            const SizedBox(height: AppSpacing.m),
            _SourceStrip(jurisdiction: jurisdiction, ruleSet: ruleSet),
            const SizedBox(height: AppSpacing.m),
            _PersonalHero(
              vehicle: vehicle,
              jurisdiction: jurisdiction,
              ruleSet: ruleSet,
              today: today,
              tomorrow: tomorrow,
            ),
            const SizedBox(height: AppSpacing.m),
            _PersonalLowerModule(
              today: today,
              nextRestriction: nextRestriction,
              jurisdiction: jurisdiction,
              ruleSet: ruleSet,
              days: futureDays,
              evaluations: [
                for (final day in futureDays)
                  _evaluate(ruleSet, jurisdiction, vehicle, day),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _CityPicoView extends ConsumerStatefulWidget {
  const _CityPicoView({
    required this.jurisdictions,
    required this.selectedJurisdictionId,
    required this.vehicles,
  });

  final List<RestrictionJurisdiction> jurisdictions;
  final String? selectedJurisdictionId;
  final List<VehicleProfile> vehicles;

  @override
  ConsumerState<_CityPicoView> createState() => _CityPicoViewState();
}

class _CityPicoViewState extends ConsumerState<_CityPicoView> {
  String? _consultedJurisdictionId;
  PicoVehicleCategory _category = PicoVehicleCategory.cars;

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(bogotaNowProvider);
    final globalJurisdiction = _findJurisdiction(
      widget.jurisdictions,
      widget.selectedJurisdictionId,
    );
    final jurisdiction =
        _findJurisdiction(widget.jurisdictions, _consultedJurisdictionId) ??
        globalJurisdiction ??
        (widget.jurisdictions.isNotEmpty ? widget.jurisdictions.first : null);
    if (jurisdiction == null) {
      return const _Message('No hay ciudades disponibles para consultar.');
    }
    final isTransient =
        globalJurisdiction != null && jurisdiction.id != globalJurisdiction.id;

    return FutureBuilder<List<_CategoryCoverage>>(
      future: _loadCategoryCoverages(ref, jurisdiction, now),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const _Loading();
        }
        final coverages = snapshot.data!;
        final currentCoverage = coverages.firstWhere(
          (item) => item.category == _category,
          orElse: () => coverages.first,
        );
        final summary = summarizeCityRestrictionDay(
          ruleSet: currentCoverage.ruleSet,
          jurisdictionId: jurisdiction.id,
          category: currentCoverage.category,
          date: now,
        );

        return ListView(
          key: const ValueKey('pico-city-screen'),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.s,
            AppSpacing.l,
            AppSpacing.xl,
          ),
          children: [
            const _CityPicoHeader(),
            const SizedBox(height: AppSpacing.m),
            _CityTopControls(
              jurisdiction: jurisdiction,
              isTransient: isTransient,
              ruleSet: currentCoverage.ruleSet,
              onSelect: () => _showCitySelector(context),
              onAdopt: isTransient ? () => _adoptCity(jurisdiction) : null,
            ),
            const SizedBox(height: AppSpacing.m),
            _CategorySegment(
              coverages: coverages,
              selected: currentCoverage.category,
              onChanged: (category) => setState(() => _category = category),
            ),
            const SizedBox(height: AppSpacing.m),
            _CityHero(summary: summary, jurisdiction: jurisdiction),
            const SizedBox(height: AppSpacing.m),
            _WeekSchedule(
              jurisdiction: jurisdiction,
              coverage: currentCoverage,
              weekStart: _weekStart(now),
              currentDate: now,
            ),
            const SizedBox(height: AppSpacing.m),
            FutureBuilder<List<_VehicleShortcutData>>(
              future: _loadVehicleShortcuts(
                ref,
                jurisdiction,
                widget.vehicles,
                now,
              ),
              builder: (context, shortcuts) {
                return _VehicleShortcuts(
                  items: shortcuts.data ?? const [],
                  consultedJurisdictionId: isTransient ? jurisdiction.id : null,
                );
              },
            ),
            const SizedBox(height: AppSpacing.m),
            _SourceCard(ruleSet: currentCoverage.ruleSet),
          ],
        );
      },
    );
  }

  Future<void> _showCitySelector(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          key: const ValueKey('pico-city-selector'),
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.l,
                0,
                AppSpacing.l,
                AppSpacing.s,
              ),
              child: Text('Consultar ciudad', style: AppTextStyles.h2),
            ),
            for (final jurisdiction in widget.jurisdictions)
              ListTile(
                key: ValueKey('pico-city-option-${jurisdiction.id}'),
                title: Text(jurisdiction.name),
                trailing: jurisdiction.id == _consultedJurisdictionId
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.of(context).pop(jurisdiction.id),
              ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _consultedJurisdictionId = selected);
    }
  }

  Future<void> _adoptCity(RestrictionJurisdiction jurisdiction) async {
    await ref.read(locationStateProvider.notifier).selectManual(jurisdiction);
    if (mounted) {
      setState(() => _consultedJurisdictionId = jurisdiction.id);
    }
  }
}

class _PersonalPicoHeader extends StatelessWidget {
  const _PersonalPicoHeader({required this.alertPreferences});

  final PicoAlertPreferences alertPreferences;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('pico-personal-header'),
      children: [
        _BackIconButton(onPressed: () => _goBack(context)),
        const SizedBox(width: AppSpacing.s),
        const Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: PicoRadarBrandLockup(markSize: 32),
          ),
        ),
        const SizedBox(width: AppSpacing.s),
        _PicoUserControls(alertPreferences: alertPreferences),
      ],
    );
  }
}

class _CityPicoHeader extends StatelessWidget {
  const _CityPicoHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('pico-city-header'),
      height: 56,
      child: Row(
        children: [
          _BackIconButton(onPressed: () => _goBack(context)),
          Expanded(
            child: Text(
              'Pico y placa de la ciudad',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.h2.copyWith(color: AppColors.teal),
            ),
          ),
          IconButton(
            key: const ValueKey('pico-city-info'),
            tooltip: 'Información',
            onPressed: () => _showCityInfo(context),
            icon: const Icon(Icons.info_outline_rounded, color: AppColors.navy),
          ),
        ],
      ),
    );
  }
}

class _BackIconButton extends StatelessWidget {
  const _BackIconButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 1,
      child: IconButton(
        tooltip: 'Volver',
        onPressed: onPressed,
        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.navy),
      ),
    );
  }
}

class _PicoUserControls extends StatelessWidget {
  const _PicoUserControls({required this.alertPreferences});

  final PicoAlertPreferences alertPreferences;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 3,
      shadowColor: AppColors.navy.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 52,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HomeAvatarButton(embedded: true, visualSize: 40),
            Container(
              width: 1,
              height: 28,
              color: AppColors.border.withValues(alpha: 0.72),
            ),
            SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                key: const ValueKey('pico-notification-bell'),
                tooltip: 'Alertas',
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (context) =>
                      PicoNotificationSheet(alertPreferences: alertPreferences),
                ),
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(
                      Icons.notifications_none_rounded,
                      color: AppColors.navy,
                    ),
                    if (alertPreferences.permissionGranted &&
                        alertPreferences.enabled)
                      Positioned(
                        right: -1,
                        top: -1,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.teal,
                            shape: BoxShape.circle,
                          ),
                        ),
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

void _goBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(AppRoute.home.path);
  }
}

void _showCityInfo(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.s,
          AppSpacing.xl,
          AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          key: const ValueKey('pico-city-info-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sobre esta consulta', style: AppTextStyles.h2),
            const SizedBox(height: AppSpacing.m),
            const Text('Los datos vienen de fuentes oficiales disponibles.'),
            const SizedBox(height: AppSpacing.s),
            const Text(
              'Puedes consultar otra ciudad sin cambiar tu ubicación.',
            ),
            const SizedBox(height: AppSpacing.s),
            const Text('Usar esta ciudad guarda la selección manualmente.'),
          ],
        ),
      ),
    ),
  );
}

class _SourceStrip extends StatelessWidget {
  const _SourceStrip({required this.jurisdiction, required this.ruleSet});

  final RestrictionJurisdiction jurisdiction;
  final RestrictionRuleSet ruleSet;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('pico-personal-location-source'),
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined, color: AppColors.blue),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${jurisdiction.name}, Colombia',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: AppColors.teal,
                  ),
                ),
                Text(
                  _sourceLabel(ruleSet),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.teal),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: color),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalHero extends StatelessWidget {
  const _PersonalHero({
    required this.vehicle,
    required this.jurisdiction,
    required this.ruleSet,
    required this.today,
    required this.tomorrow,
  });

  final VehicleProfile vehicle;
  final RestrictionJurisdiction jurisdiction;
  final RestrictionRuleSet ruleSet;
  final RestrictionDayEvaluation today;
  final RestrictionDayEvaluation tomorrow;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(today.status);
    final title = vehicle.nickname?.trim().isNotEmpty == true
        ? vehicle.nickname!.trim()
        : vehicleMakeModel(vehicle).isNotEmpty
        ? vehicleMakeModel(vehicle)
        : vehicleTypeLabel(vehicle);
    return AppCard(
      key: const ValueKey('pico-personal-screen'),
      padding: const EdgeInsets.all(AppSpacing.l),
      borderColor: AppColors.blue.withValues(alpha: 0.36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.m,
                    vertical: AppSpacing.s,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(AppRadius.input),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        size: 17,
                        color: Colors.white,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          'MI VEHÍCULO',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'MI PICO Y PLACA',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.teal,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 54,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(title, style: AppTextStyles.h1),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      [
                        vehicle.year?.toString(),
                        shortVehicleTypeLabel(vehicle),
                      ].whereType<String>().join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.navy.withValues(alpha: 0.78),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _StatusPill(
                        label: _statusText(today.status),
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: ColombianPlateBadge(plate: vehicle.plate),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                flex: 46,
                child: SizedBox(
                  height: 132,
                  child: VehicleVisualImage(
                    vehicle: vehicle,
                    cacheWidth: 360,
                    fallbackBuilder: (_) => Icon(
                      vehicleIcon(vehicle),
                      size: 78,
                      color: vehicleAccent(vehicle),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          Container(
            key: const ValueKey('pico-personal-combined-hero'),
            padding: const EdgeInsets.all(AppSpacing.m),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.input),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_statusIcon(today.status), color: statusColor),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(
                      child: Text(
                        'Pico y placa',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyStrong,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s),
                Container(height: 1, color: AppColors.border),
                const SizedBox(height: AppSpacing.m),
                _PersonalStatusGrid(
                  status: today.status,
                  windows: _windowsOrControlled(today),
                  rule: plateBasisLabel(ruleSet, vehicle),
                ),
                const SizedBox(height: AppSpacing.m),
                Container(height: 1, color: AppColors.border),
                const SizedBox(height: AppSpacing.s),
                Row(
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      color: AppColors.teal,
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(
                      child: Text(
                        '${jurisdiction.name} · ${_sourceLabel(ruleSet)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption,
                      ),
                    ),
                    _StatusPill(
                      label: 'Mañana: ${_compactStatusText(tomorrow.status)}',
                      color: _statusColor(tomorrow.status),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalStatusGrid extends StatelessWidget {
  const _PersonalStatusGrid({
    required this.status,
    required this.windows,
    required this.rule,
  });

  final RestrictionDayStatus status;
  final String windows;
  final String rule;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    final items = [
      _StatusMetric(label: 'Estado', value: _statusText(status), color: color),
      _StatusMetric(label: 'Horario', value: windows, color: AppColors.navy),
      _StatusMetric(label: 'Regla', value: rule, color: AppColors.navy),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 230) {
          return Column(
            children: [
              for (final item in items) ...[
                item,
                if (item != items.last) const SizedBox(height: AppSpacing.s),
              ],
            ],
          );
        }
        return Row(
          key: const ValueKey('pico-personal-status-grid'),
          children: [
            for (var i = 0; i < items.length; i += 1) ...[
              Expanded(child: items[i]),
              if (i != items.length - 1)
                Container(width: 1, height: 72, color: AppColors.border),
            ],
          ],
        );
      },
    );
  }
}

class _StatusMetric extends StatelessWidget {
  const _StatusMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyStrong.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _PersonalLowerModule extends StatelessWidget {
  const _PersonalLowerModule({
    required this.today,
    required this.nextRestriction,
    required this.jurisdiction,
    required this.ruleSet,
    required this.days,
    required this.evaluations,
  });

  final RestrictionDayEvaluation today;
  final _NextRestriction? nextRestriction;
  final RestrictionJurisdiction jurisdiction;
  final RestrictionRuleSet ruleSet;
  final List<DateTime> days;
  final List<RestrictionDayEvaluation> evaluations;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const ValueKey('pico-personal-lower-module'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ImmediateState(evaluation: today, nextRestriction: nextRestriction),
          const SizedBox(height: AppSpacing.m),
          Container(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.m),
          _PersonalCalendar(days: days, evaluations: evaluations),
          const SizedBox(height: AppSpacing.s),
          _InfoFootnote(
            text: 'La rotación puede cambiar por festivos o medidas especiales. Consulta la fuente oficial.',
          ),
          const SizedBox(height: AppSpacing.xs),
          _InfoFootnote(
            text: '${jurisdiction.name} · ${_sourceLabel(ruleSet)}',
          ),
        ],
      ),
    );
  }
}

class _ImmediateState extends StatelessWidget {
  const _ImmediateState({
    required this.evaluation,
    required this.nextRestriction,
  });

  final RestrictionDayEvaluation evaluation;
  final _NextRestriction? nextRestriction;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(evaluation.status);
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(_statusIcon(evaluation.status), color: color, size: 30),
        ),
        const SizedBox(width: AppSpacing.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Estado inmediato', style: AppTextStyles.bodyStrong),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _statusText(evaluation.status),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyStrong.copyWith(color: color),
              ),
              Text(
                _windowsOrControlled(evaluation),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
        if (nextRestriction != null) ...[
          const SizedBox(width: AppSpacing.s),
          _StatusPill(
            label:
                '${_weekday(nextRestriction!.date)} ${nextRestriction!.date.day}',
            color: AppColors.blue,
            icon: Icons.event_note_rounded,
          ),
        ],
      ],
    );
  }
}

class _PersonalCalendar extends StatelessWidget {
  const _PersonalCalendar({required this.days, required this.evaluations});

  final List<DateTime> days;
  final List<RestrictionDayEvaluation> evaluations;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Próximos días', style: AppTextStyles.bodyStrong),
        const SizedBox(height: AppSpacing.s),
        SizedBox(
          key: const ValueKey('pico-personal-calendar'),
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s),
            itemBuilder: (context, index) => _DayCard(
              key: ValueKey('pico-calendar-day-${index + 1}'),
              date: days[index],
              evaluation: evaluations[index],
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoFootnote extends StatelessWidget {
  const _InfoFootnote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.caption.copyWith(
        color: AppColors.navy.withValues(alpha: 0.68),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.date, required this.evaluation, super.key});

  final DateTime date;
  final RestrictionDayEvaluation evaluation;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(evaluation.status);
    return Container(
      width: 74,
      padding: const EdgeInsets.all(AppSpacing.s),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_weekday(date), style: AppTextStyles.caption),
          Text(
            date.day.toString(),
            style: AppTextStyles.h2.copyWith(color: color),
          ),
          const SizedBox(height: AppSpacing.xs),
          Icon(_statusIcon(evaluation.status), size: 16, color: color),
          const Spacer(),
          Text(
            _compactStatusText(evaluation.status),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          if (evaluation.status == RestrictionDayStatus.restricted &&
              evaluation.effectiveWindows.isNotEmpty)
            Text(
              _compactWindows(evaluation.effectiveWindows),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(fontSize: 11),
            ),
        ],
      ),
    );
  }
}

class _CityTopControls extends StatelessWidget {
  const _CityTopControls({
    required this.jurisdiction,
    required this.isTransient,
    required this.ruleSet,
    required this.onSelect,
    required this.onAdopt,
  });

  final RestrictionJurisdiction jurisdiction;
  final bool isTransient;
  final RestrictionRuleSet ruleSet;
  final VoidCallback onSelect;
  final VoidCallback? onAdopt;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('pico-city-top-controls'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _CitySelectorPill(
              jurisdiction: jurisdiction,
              isTransient: isTransient,
              onSelect: onSelect,
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(child: _FreshnessPill(ruleSet: ruleSet)),
          ],
        ),
        if (onAdopt != null) ...[
          const SizedBox(height: AppSpacing.s),
          OutlinedButton.icon(
            key: const ValueKey('pico-city-adopt'),
            onPressed: onAdopt,
            icon: const Icon(Icons.my_location_rounded),
            label: const Text('Usar esta ciudad'),
          ),
        ],
      ],
    );
  }
}

class _CitySelectorPill extends StatelessWidget {
  const _CitySelectorPill({
    required this.jurisdiction,
    required this.isTransient,
    required this.onSelect,
  });

  final RestrictionJurisdiction jurisdiction;
  final bool isTransient;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('pico-city-change'),
        onTap: onSelect,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: 168,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: AppSpacing.s,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on_rounded, color: AppColors.teal),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      jurisdiction.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyStrong,
                    ),
                    Text(
                      isTransient ? 'Temporal' : 'Configurada',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.expand_more_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _FreshnessPill extends StatelessWidget {
  const _FreshnessPill({required this.ruleSet});

  final RestrictionRuleSet ruleSet;

  @override
  Widget build(BuildContext context) {
    final stale = ruleSet.dataIsStale || !ruleSet.coverageKnown;
    final color = stale ? AppColors.orange : AppColors.teal;
    return Container(
      key: const ValueKey('pico-city-freshness'),
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(Icons.sync_rounded, color: color, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  stale ? 'Datos' : 'Verificado',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          Text(
            ruleSet.verifiedAt == null
                ? (stale ? 'Sin cobertura' : 'Fuente oficial')
                : _shortDate(ruleSet.verifiedAt!),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

class _CategorySegment extends StatelessWidget {
  const _CategorySegment({
    required this.coverages,
    required this.selected,
    required this.onChanged,
  });

  final List<_CategoryCoverage> coverages;
  final PicoVehicleCategory selected;
  final ValueChanged<PicoVehicleCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('pico-city-category-segment'),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (var index = 0; index < coverages.length; index += 1) ...[
            Expanded(
              child: _CategorySegmentButton(
                coverage: coverages[index],
                selected: coverages[index].category == selected,
                onPressed: coverages[index].ruleSet.coverageKnown
                    ? () => onChanged(coverages[index].category)
                    : null,
              ),
            ),
            if (index != coverages.length - 1) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

class _CategorySegmentButton extends StatelessWidget {
  const _CategorySegmentButton({
    required this.coverage,
    required this.selected,
    required this.onPressed,
  });

  final _CategoryCoverage coverage;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.teal : AppColors.navy;
    return Material(
      color: selected
          ? AppColors.teal.withValues(alpha: 0.14)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.chip),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('pico-city-category-${coverage.category.name}'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: SizedBox(
          height: 42,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_categoryIcon(coverage.category), size: 18, color: color),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  coverage.category.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: onPressed == null
                        ? AppColors.navy.withValues(alpha: 0.45)
                        : color,
                    fontWeight: FontWeight.w900,
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

class _CityHero extends StatelessWidget {
  const _CityHero({required this.summary, required this.jurisdiction});

  final CityRestrictionDaySummary summary;
  final RestrictionJurisdiction jurisdiction;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(summary.status);
    return AppCard(
      key: const ValueKey('pico-city-hero'),
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 58,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(jurisdiction.name, style: AppTextStyles.caption),
                const SizedBox(height: AppSpacing.xs),
                _StatusPill(
                  label: 'Hoy · ${_weekday(summary.date)} ${summary.date.day}',
                  color: color,
                  icon: _statusIcon(summary.status),
                ),
                const SizedBox(height: AppSpacing.m),
                Text(
                  _statusText(summary.status),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h1.copyWith(color: color),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  summary.ruleLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong,
                ),
                const SizedBox(height: AppSpacing.s),
                Text(
                  _windowsOrText(summary.effectiveWindows),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            flex: 42,
            child: SizedBox(
              height: 132,
              child: CustomPaint(painter: _CityRoadPainter()),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekSchedule extends StatelessWidget {
  const _WeekSchedule({
    required this.jurisdiction,
    required this.coverage,
    required this.weekStart,
    required this.currentDate,
  });

  final RestrictionJurisdiction jurisdiction;
  final _CategoryCoverage coverage;
  final DateTime weekStart;
  final DateTime currentDate;

  @override
  Widget build(BuildContext context) {
    final days = [
      for (var offset = 0; offset < 7; offset += 1)
        DateTime(weekStart.year, weekStart.month, weekStart.day + offset),
    ];
    return AppCard(
      key: const ValueKey('pico-city-week-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Semana', style: AppTextStyles.h2),
          const SizedBox(height: AppSpacing.s),
          SizedBox(
            key: const ValueKey('pico-city-week-list'),
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: days.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s),
              itemBuilder: (context, index) {
                final day = days[index];
                return _WeekDayTile(
                  index: index,
                  isToday: _isSameDay(day, currentDate),
                  summary: summarizeCityRestrictionDay(
                    ruleSet: coverage.ruleSet,
                    jurisdictionId: jurisdiction.id,
                    category: coverage.category,
                    date: day,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          Text(
            'Consulta local con fuente oficial versionada.',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

class _WeekDayTile extends StatelessWidget {
  const _WeekDayTile({
    required this.index,
    required this.isToday,
    required this.summary,
  });

  final int index;
  final bool isToday;
  final CityRestrictionDaySummary summary;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(summary.status);
    return Container(
      key: ValueKey('pico-city-week-day-$index'),
      width: 78,
      padding: const EdgeInsets.all(AppSpacing.s),
      decoration: BoxDecoration(
        color: isToday
            ? AppColors.teal.withValues(alpha: 0.1)
            : color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(
          color: isToday ? AppColors.teal : color.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_weekday(summary.date), style: AppTextStyles.caption),
          Text(
            summary.date.day.toString(),
            style: AppTextStyles.h2.copyWith(color: color),
          ),
          const SizedBox(height: AppSpacing.xs),
          Icon(_statusIcon(summary.status), color: color, size: 18),
          const Spacer(),
          Text(
            _compactStatusText(summary.status),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            _compactWindows(summary.effectiveWindows),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _VehicleShortcuts extends StatelessWidget {
  const _VehicleShortcuts({
    required this.items,
    required this.consultedJurisdictionId,
  });

  final List<_VehicleShortcutData> items;
  final String? consultedJurisdictionId;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const ValueKey('pico-city-vehicles-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Mis vehículos', style: AppTextStyles.h2)),
              TextButton(
                onPressed: () => context.go(AppRoute.garage.path),
                child: const Text('Ver todos'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          SizedBox(
            key: const ValueKey('pico-city-vehicles-list'),
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s),
              itemBuilder: (context, index) {
                if (index == items.length) {
                  return const _AddVehicleShortcut();
                }
                return _VehicleShortcut(
                  data: items[index],
                  consultedJurisdictionId: consultedJurisdictionId,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AddVehicleShortcut extends StatelessWidget {
  const _AddVehicleShortcut();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.input),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('pico-city-add-vehicle'),
        onTap: () => context.go(AppRoute.vehicleOnboarding.path),
        child: Container(
          width: 132,
          padding: const EdgeInsets.all(AppSpacing.m),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.input),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.add_circle_outline_rounded,
                color: AppColors.teal,
                size: 30,
              ),
              const SizedBox(height: AppSpacing.s),
              Text(
                'Agregar',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyStrong.copyWith(color: AppColors.teal),
              ),
              Text(
                'vehículo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehicleShortcut extends StatelessWidget {
  const _VehicleShortcut({
    required this.data,
    required this.consultedJurisdictionId,
  });

  final _VehicleShortcutData data;
  final String? consultedJurisdictionId;

  @override
  Widget build(BuildContext context) {
    final params = {'vehicleId': data.vehicle.id};
    if (consultedJurisdictionId != null) {
      params['jurisdictionId'] = consultedJurisdictionId!;
    }
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.input),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('pico-city-vehicle-${data.vehicle.id}'),
        onTap: () => context.go(
          Uri(path: AppRoute.pico.path, queryParameters: params).toString(),
        ),
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: Container(
          width: 142,
          padding: const EdgeInsets.all(AppSpacing.s),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.input),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
                  child: VehicleVisualImage(
                    vehicle: data.vehicle,
                    cacheWidth: 180,
                    fallbackBuilder: (_) => Icon(
                      vehicleIcon(data.vehicle),
                      color: vehicleAccent(data.vehicle),
                      size: 46,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: ColombianPlateBadge(
                  plate: data.vehicle.plate,
                  compact: true,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                shortVehicleTypeLabel(data.vehicle),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption,
              ),
              Text(
                _compactStatusText(data.evaluation.status),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: _statusColor(data.evaluation.status),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.ruleSet});

  final RestrictionRuleSet ruleSet;

  @override
  Widget build(BuildContext context) {
    final source = _httpsSource(ruleSet);
    return AppCard(
      key: const ValueKey('pico-official-source-block'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_rounded, color: AppColors.teal),
              const SizedBox(width: AppSpacing.s),
              Expanded(child: Text('Fuente oficial', style: AppTextStyles.h2)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _sourceLabel(ruleSet),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body,
          ),
          if (ruleSet.verifiedAt != null)
            Text(
              'Verificado: ${_date(ruleSet.verifiedAt!)}',
              style: AppTextStyles.caption,
            ),
          if (source != null) ...[
            const SizedBox(height: AppSpacing.s),
            TextButton.icon(
              key: const ValueKey('pico-source-open'),
              onPressed: () {
                launchUrl(Uri.parse(source));
              },
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text('Abrir sitio · ${Uri.parse(source).host}'),
            ),
          ],
        ],
      ),
    );
  }
}

class _CityRoadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()..color = AppColors.teal.withValues(alpha: 0.08);
    final road = Paint()..color = AppColors.navy;
    final stripe = Paint()
      ..color = AppColors.plateYellow
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(20)),
      sky,
    );
    final roadPath = Path()
      ..moveTo(size.width * 0.14, size.height)
      ..quadraticBezierTo(
        size.width * 0.48,
        size.height * 0.24,
        size.width * 0.86,
        size.height,
      )
      ..close();
    canvas.drawPath(roadPath, road);
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.62),
      Offset(size.width * 0.5, size.height * 0.88),
      stripe,
    );
    final building = Paint()..color = AppColors.blue.withValues(alpha: 0.28);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.12, size.height * 0.2, 42, 54),
        const Radius.circular(6),
      ),
      building,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.74, size.height * 0.12, 48, 64),
        const Radius.circular(6),
      ),
      building,
    );
  }

  @override
  bool shouldRepaint(covariant _CityRoadPainter oldDelegate) => false;
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}

class _CategoryCoverage {
  const _CategoryCoverage({required this.category, required this.ruleSet});

  final PicoVehicleCategory category;
  final RestrictionRuleSet ruleSet;
}

class _VehicleShortcutData {
  const _VehicleShortcutData({required this.vehicle, required this.evaluation});

  final VehicleProfile vehicle;
  final RestrictionDayEvaluation evaluation;
}

class _NextRestriction {
  const _NextRestriction({required this.date, required this.evaluation});

  final DateTime date;
  final RestrictionDayEvaluation evaluation;
}

Future<List<_CategoryCoverage>> _loadCategoryCoverages(
  WidgetRef ref,
  RestrictionJurisdiction jurisdiction,
  DateTime now,
) async {
  final store = ref.read(restrictionStoreProvider);
  return [
    for (final category in PicoVehicleCategory.values)
      _CategoryCoverage(
        category: category,
        ruleSet: await store.loadCoverage(
          jurisdiction.id,
          category.kind,
          category.serviceType,
          ref.read(currentInstantProvider),
        ),
      ),
  ];
}

Future<List<_VehicleShortcutData>> _loadVehicleShortcuts(
  WidgetRef ref,
  RestrictionJurisdiction jurisdiction,
  List<VehicleProfile> vehicles,
  DateTime now,
) async {
  final store = ref.read(restrictionStoreProvider);
  final items = <_VehicleShortcutData>[];
  for (final vehicle in vehicles.take(4)) {
    final ruleSet = await store.loadCoverage(
      jurisdiction.id,
      vehicle.kind,
      vehicle.serviceType,
      ref.read(currentInstantProvider),
    );
    items.add(
      _VehicleShortcutData(
        vehicle: vehicle,
        evaluation: _evaluate(ruleSet, jurisdiction, vehicle, now),
      ),
    );
  }
  return items;
}

RestrictionDayEvaluation _evaluate(
  RestrictionRuleSet ruleSet,
  RestrictionJurisdiction jurisdiction,
  VehicleProfile vehicle,
  DateTime date,
) {
  return evaluateRestrictionDay(
    ruleSet: ruleSet,
    jurisdictionId: jurisdiction.id,
    plate: vehicle.plate,
    vehicleKind: vehicle.kind,
    serviceType: vehicle.serviceType,
    date: date,
  );
}

_NextRestriction? _nextRestriction(
  RestrictionRuleSet ruleSet,
  RestrictionJurisdiction jurisdiction,
  VehicleProfile vehicle,
  DateTime now,
) {
  for (var offset = 1; offset <= 30; offset += 1) {
    final date = DateTime(now.year, now.month, now.day + offset);
    final evaluation = _evaluate(ruleSet, jurisdiction, vehicle, date);
    if (evaluation.status == RestrictionDayStatus.restricted) {
      return _NextRestriction(date: date, evaluation: evaluation);
    }
  }
  return null;
}

VehicleProfile? _findVehicle(List<VehicleProfile> vehicles, String? id) {
  if (!_hasQueryValue(id)) {
    return null;
  }
  for (final vehicle in vehicles) {
    if (vehicle.id == id) {
      return vehicle;
    }
  }
  return null;
}

RestrictionJurisdiction? _findJurisdiction(
  List<RestrictionJurisdiction> items,
  String? id,
) {
  if (!_hasQueryValue(id)) {
    return null;
  }
  for (final item in items) {
    if (item.id == id) {
      return item;
    }
  }
  return null;
}

bool _hasQueryValue(String? value) => value != null && value.trim().isNotEmpty;

const _defaultAlertPreferences = PicoAlertPreferences(
  enabled: true,
  dayBeforeEnabled: true,
  sameDayEnabled: true,
  dayBeforeMinute: 19 * 60,
  sameDayMinute: 5 * 60,
  permissionRequested: false,
  permissionGranted: false,
);

String _statusText(RestrictionDayStatus status) {
  return switch (status) {
    RestrictionDayStatus.restricted => 'No puedes circular',
    RestrictionDayStatus.allowed => 'Puedes circular',
    RestrictionDayStatus.unknown => 'Sin confirmar',
    RestrictionDayStatus.stale => 'Datos desactualizados',
  };
}

String _compactStatusText(RestrictionDayStatus status) {
  return switch (status) {
    RestrictionDayStatus.restricted => 'No circula',
    RestrictionDayStatus.allowed => 'Libre',
    RestrictionDayStatus.unknown => 'Revisar',
    RestrictionDayStatus.stale => 'Actualizar',
  };
}

IconData _categoryIcon(PicoVehicleCategory category) {
  return switch (category) {
    PicoVehicleCategory.cars => Icons.directions_car_filled_rounded,
    PicoVehicleCategory.motorcycles => Icons.two_wheeler_rounded,
    PicoVehicleCategory.taxis => Icons.local_taxi_rounded,
  };
}

Color _statusColor(RestrictionDayStatus status) {
  return switch (status) {
    RestrictionDayStatus.restricted => AppColors.red,
    RestrictionDayStatus.allowed => AppColors.green,
    RestrictionDayStatus.unknown => AppColors.orange,
    RestrictionDayStatus.stale => AppColors.orange,
  };
}

IconData _statusIcon(RestrictionDayStatus status) {
  return switch (status) {
    RestrictionDayStatus.restricted => Icons.block_rounded,
    RestrictionDayStatus.allowed => Icons.check_circle_rounded,
    RestrictionDayStatus.unknown => Icons.help_outline_rounded,
    RestrictionDayStatus.stale => Icons.update_rounded,
  };
}

String _windowsOrControlled(RestrictionDayEvaluation evaluation) {
  if (evaluation.status == RestrictionDayStatus.restricted) {
    return _windowsOrText(evaluation.effectiveWindows);
  }
  return switch (evaluation.status) {
    RestrictionDayStatus.allowed => 'Libre',
    RestrictionDayStatus.unknown => 'Por confirmar',
    RestrictionDayStatus.stale => 'Actualizar',
    RestrictionDayStatus.restricted => _windowsOrText(
      evaluation.effectiveWindows,
    ),
  };
}

String _windowsOrText(List<RestrictionDayWindow> windows) {
  return windows.isEmpty ? 'Horario no publicado' : _windows(windows);
}

String _compactWindows(List<RestrictionDayWindow> windows) {
  if (windows.isEmpty) {
    return 'Sin hora';
  }
  if (windows.length == 1) {
    return '${_minute(windows.first.startMinute)}-${_minute(windows.first.endMinute)}';
  }
  return '${_minute(windows.first.startMinute)} +${windows.length - 1}';
}

String _dataState(bool coverageKnown, bool dataIsStale) {
  if (!coverageKnown) {
    return 'Sin cobertura';
  }
  return dataIsStale ? 'Por actualizar' : 'Vigentes';
}

String _sourceLabel(RestrictionRuleSet ruleSet) {
  final source = _httpsSource(ruleSet);
  final host = source == null ? null : Uri.parse(source).host;
  final state = _dataState(ruleSet.coverageKnown, ruleSet.dataIsStale);
  if (host == null || host.isEmpty) {
    return 'Fuente oficial · $state';
  }
  return 'Fuente oficial: $host · $state';
}

String? _httpsSource(RestrictionRuleSet ruleSet) {
  for (final source in ruleSet.sourceUrls) {
    final uri = Uri.tryParse(source);
    if (uri != null && uri.scheme == 'https') {
      return source;
    }
  }
  return null;
}

String _windows(List<RestrictionDayWindow> windows) {
  return windows
      .map(
        (window) =>
            '${_minute(window.startMinute)}-${_minute(window.endMinute)}',
      )
      .join(', ');
}

String _minute(int minute) {
  if (minute == 1440) {
    return '24:00';
  }
  return '${(minute ~/ 60).toString().padLeft(2, '0')}:'
      '${(minute % 60).toString().padLeft(2, '0')}';
}

String _date(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

String _shortDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _weekday(DateTime date) {
  return switch (date.weekday) {
    DateTime.monday => 'Lun',
    DateTime.tuesday => 'Mar',
    DateTime.wednesday => 'Mié',
    DateTime.thursday => 'Jue',
    DateTime.friday => 'Vie',
    DateTime.saturday => 'Sáb',
    _ => 'Dom',
  };
}

DateTime _weekStart(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

bool _isSameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}
