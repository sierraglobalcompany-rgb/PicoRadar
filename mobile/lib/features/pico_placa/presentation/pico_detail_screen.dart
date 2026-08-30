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
import '../../location/application/location_controller.dart';
import '../../visual_assets/presentation/visual_asset_widgets.dart';
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
            _PicoTopBar(title: 'MI PICO Y PLACA'),
            const SizedBox(height: AppSpacing.m),
            _SourceStrip(jurisdiction: jurisdiction, ruleSet: ruleSet),
            const SizedBox(height: AppSpacing.m),
            _PersonalHero(vehicle: vehicle),
            const SizedBox(height: AppSpacing.m),
            _TodayStatusCard(
              title: 'Pico y placa hoy',
              status: today.status,
              main: _statusText(today.status),
              detail: _windowsOrControlled(today),
              chips: [
                _InfoChipData('Ciudad', jurisdiction.name),
                _InfoChipData('Regla', plateBasisLabel(ruleSet, vehicle)),
                _InfoChipData('Mañana', _statusText(tomorrow.status)),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 380;
                final children = [
                  _MiniFactCard(
                    title: 'Estado inmediato',
                    value: _immediateText(today),
                    icon: _statusIcon(today.status),
                    color: _statusColor(today.status),
                  ),
                  _MiniFactCard(
                    title: 'Próxima restricción',
                    value: nextRestriction == null
                        ? 'Sin restricción verificada en 30 días'
                        : '${_weekday(nextRestriction.date)} ${nextRestriction.date.day} · ${_windowsOrControlled(nextRestriction.evaluation)}',
                    icon: Icons.event_note_rounded,
                    color: AppColors.blue,
                  ),
                ];
                if (compact) {
                  return Column(
                    children: [
                      children[0],
                      const SizedBox(height: AppSpacing.s),
                      children[1],
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: children[0]),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(child: children[1]),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.m),
            _PersonalCalendar(
              days: futureDays,
              evaluations: [
                for (final day in futureDays)
                  _evaluate(ruleSet, jurisdiction, vehicle, day),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            _SourceCard(ruleSet: ruleSet),
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
            _PicoTopBar(title: 'Pico y placa de la ciudad'),
            const SizedBox(height: AppSpacing.m),
            _CitySelectorCard(
              jurisdiction: jurisdiction,
              isTransient: isTransient,
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

class _PicoTopBar extends StatelessWidget {
  const _PicoTopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Volver',
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoute.home.path);
                }
              },
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: PicoRadarBrandLockup(
                markSize: 30,
                textStyle: AppTextStyles.bodyStrong,
              ),
            ),
            const HomeAvatarButton(embedded: true, visualSize: 34),
            IconButton(
              tooltip: 'Alertas',
              onPressed: () {},
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.s),
          child: Text(title, style: AppTextStyles.h2),
        ),
      ],
    );
  }
}

class _SourceStrip extends StatelessWidget {
  const _SourceStrip({required this.jurisdiction, required this.ruleSet});

  final RestrictionJurisdiction jurisdiction;
  final RestrictionRuleSet ruleSet;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      backgroundColor: AppColors.teal.withValues(alpha: 0.08),
      borderColor: AppColors.teal.withValues(alpha: 0.2),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined, color: AppColors.teal),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              '${jurisdiction.name} · ${_sourceLabel(ruleSet)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalHero extends StatelessWidget {
  const _PersonalHero({required this.vehicle});

  final VehicleProfile vehicle;

  @override
  Widget build(BuildContext context) {
    final title = vehicle.nickname?.trim().isNotEmpty == true
        ? vehicle.nickname!.trim()
        : vehicleMakeModel(vehicle).isNotEmpty
        ? vehicleMakeModel(vehicle)
        : vehicleTypeLabel(vehicle);
    return AppCard(
      key: const ValueKey('pico-personal-screen'),
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MI VEHÍCULO',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.teal,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.h1),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      [
                        vehicle.year?.toString(),
                        shortVehicleTypeLabel(vehicle),
                      ].whereType<String>().join(' · '),
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: AppSpacing.m),
                    ColombianPlateBadge(plate: vehicle.plate),
                  ],
                ),
              ),
              SizedBox(
                width: 132,
                height: 96,
                child: VehicleVisualImage(
                  vehicle: vehicle,
                  cacheWidth: 260,
                  fallbackBuilder: (_) => Icon(
                    vehicleIcon(vehicle),
                    size: 64,
                    color: vehicleAccent(vehicle),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayStatusCard extends StatelessWidget {
  const _TodayStatusCard({
    required this.title,
    required this.status,
    required this.main,
    required this.detail,
    required this.chips,
  });

  final String title;
  final RestrictionDayStatus status;
  final String main;
  final String detail;
  final List<_InfoChipData> chips;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return AppCard(
      backgroundColor: color.withValues(alpha: 0.08),
      borderColor: color.withValues(alpha: 0.24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_statusIcon(status), color: color),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong.copyWith(color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          Text(main, style: AppTextStyles.h1.copyWith(color: color)),
          const SizedBox(height: AppSpacing.xs),
          Text(detail, style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.m),
          Wrap(
            spacing: AppSpacing.s,
            runSpacing: AppSpacing.s,
            children: [for (final chip in chips) _InfoChip(chip: chip)],
          ),
        ],
      ),
    );
  }
}

class _MiniFactCard extends StatelessWidget {
  const _MiniFactCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.caption),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong.copyWith(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalCalendar extends StatelessWidget {
  const _PersonalCalendar({required this.days, required this.evaluations});

  final List<DateTime> days;
  final List<RestrictionDayEvaluation> evaluations;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Próximos días', style: AppTextStyles.h2),
          const SizedBox(height: AppSpacing.s),
          SizedBox(
            key: const ValueKey('pico-personal-calendar'),
            height: 136,
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
      width: 116,
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
            style: AppTextStyles.h1.copyWith(color: color),
          ),
          const Spacer(),
          Text(
            _statusText(evaluation.status),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w800),
          ),
          if (evaluation.effectiveWindows.isNotEmpty)
            Text(
              _windows(evaluation.effectiveWindows),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(fontSize: 11),
            ),
        ],
      ),
    );
  }
}

class _CitySelectorCard extends StatelessWidget {
  const _CitySelectorCard({
    required this.jurisdiction,
    required this.isTransient,
    required this.onSelect,
    required this.onAdopt,
  });

  final RestrictionJurisdiction jurisdiction;
  final bool isTransient;
  final VoidCallback onSelect;
  final VoidCallback? onAdopt;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.location_city_rounded, color: AppColors.teal),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(jurisdiction.name, style: AppTextStyles.h2),
                    Text(
                      isTransient ? 'Consulta temporal' : 'Ciudad configurada',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const ValueKey('pico-city-change'),
                tooltip: 'Cambiar ciudad',
                onPressed: onSelect,
                icon: const Icon(Icons.expand_more_rounded),
              ),
            ],
          ),
          if (onAdopt != null) ...[
            const SizedBox(height: AppSpacing.s),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('pico-city-adopt'),
                onPressed: onAdopt,
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('Usar esta ciudad como mi ubicación'),
              ),
            ),
          ],
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
    return Wrap(
      spacing: AppSpacing.s,
      runSpacing: AppSpacing.s,
      children: [
        for (final item in coverages)
          ChoiceChip(
            key: ValueKey('pico-city-category-${item.category.name}'),
            label: Text(item.category.label),
            selected: item.category == selected,
            onSelected: item.ruleSet.coverageKnown
                ? (_) => onChanged(item.category)
                : null,
          ),
      ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 112,
            width: double.infinity,
            child: CustomPaint(painter: _CityRoadPainter()),
          ),
          const SizedBox(height: AppSpacing.s),
          Text(jurisdiction.name, style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(_statusIcon(summary.status), color: color),
              const SizedBox(width: AppSpacing.s),
              Text(
                'Hoy',
                style: AppTextStyles.bodyStrong.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          Text(
            _statusText(summary.status),
            style: AppTextStyles.h1.copyWith(color: color),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(summary.ruleLabel, style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.m),
          Wrap(
            spacing: AppSpacing.s,
            runSpacing: AppSpacing.s,
            children: [
              _InfoChip(
                chip: _InfoChipData(
                  'Horario',
                  _windowsOrText(summary.effectiveWindows),
                ),
              ),
              _InfoChip(
                chip: _InfoChipData(
                  'Datos',
                  _dataState(summary.coverageKnown, summary.dataIsStale),
                ),
              ),
            ],
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
  });

  final RestrictionJurisdiction jurisdiction;
  final _CategoryCoverage coverage;
  final DateTime weekStart;

  @override
  Widget build(BuildContext context) {
    final days = [
      for (var offset = 0; offset < 7; offset += 1)
        DateTime(weekStart.year, weekStart.month, weekStart.day + offset),
    ];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Semana', style: AppTextStyles.h2),
          const SizedBox(height: AppSpacing.s),
          for (final day in days)
            _WeekRow(
              summary: summarizeCityRestrictionDay(
                ruleSet: coverage.ruleSet,
                jurisdictionId: jurisdiction.id,
                category: coverage.category,
                date: day,
              ),
            ),
        ],
      ),
    );
  }
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({required this.summary});

  final CityRestrictionDaySummary summary;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(summary.status);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(_weekday(summary.date), style: AppTextStyles.caption),
          ),
          Icon(_statusIcon(summary.status), size: 18, color: color),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              summary.ruleLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            _windowsOrText(summary.effectiveWindows),
            style: AppTextStyles.caption.copyWith(fontSize: 11),
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
          if (items.isEmpty)
            TextButton.icon(
              onPressed: () => context.go(AppRoute.vehicleOnboarding.path),
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('Agregar vehículo'),
            )
          else
            for (final item in items)
              _VehicleShortcut(
                data: item,
                consultedJurisdictionId: consultedJurisdictionId,
              ),
        ],
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
    return ListTile(
      key: ValueKey('pico-city-vehicle-${data.vehicle.id}'),
      contentPadding: EdgeInsets.zero,
      leading: SizedBox(
        width: 56,
        child: VehicleVisualImage(
          vehicle: data.vehicle,
          cacheWidth: 128,
          fallbackBuilder: (_) => Icon(vehicleIcon(data.vehicle)),
        ),
      ),
      title: ColombianPlateBadge(plate: data.vehicle.plate, compact: true),
      subtitle: Text(
        '${shortVehicleTypeLabel(data.vehicle)} · ${_statusText(data.evaluation.status)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.go(
        Uri(path: AppRoute.pico.path, queryParameters: params).toString(),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Fuente oficial', style: AppTextStyles.h2),
          const SizedBox(height: AppSpacing.s),
          Text(_sourceLabel(ruleSet), style: AppTextStyles.body),
          if (ruleSet.verifiedAt != null)
            Text(
              'Verificado: ${_date(ruleSet.verifiedAt!)}',
              style: AppTextStyles.caption,
            ),
          if (source != null) ...[
            const SizedBox(height: AppSpacing.s),
            TextButton.icon(
              onPressed: () => launchUrl(Uri.parse(source)),
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(Uri.parse(source).host),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChipData {
  const _InfoChipData(this.label, this.value);

  final String label;
  final String value;
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.chip});

  final _InfoChipData chip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        '${chip.label}: ${chip.value}',
        style: AppTextStyles.caption.copyWith(fontSize: 11.5),
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

String _statusText(RestrictionDayStatus status) {
  return switch (status) {
    RestrictionDayStatus.restricted => 'No puedes circular',
    RestrictionDayStatus.allowed => 'Puedes circular',
    RestrictionDayStatus.unknown => 'Sin confirmar',
    RestrictionDayStatus.stale => 'Datos desactualizados',
  };
}

String _immediateText(RestrictionDayEvaluation evaluation) {
  return switch (evaluation.status) {
    RestrictionDayStatus.restricted => 'Revisa la ventana vigente',
    RestrictionDayStatus.allowed => 'Sin restricción activa',
    RestrictionDayStatus.unknown => 'Cobertura por confirmar',
    RestrictionDayStatus.stale => 'Actualiza datos antes de confiar',
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
    RestrictionDayStatus.allowed => 'Sin ventana de restricción verificada',
    RestrictionDayStatus.unknown => 'Consulta el calendario y la fuente',
    RestrictionDayStatus.stale => 'Datos pendientes de actualización',
    RestrictionDayStatus.restricted => _windowsOrText(
      evaluation.effectiveWindows,
    ),
  };
}

String _windowsOrText(List<RestrictionDayWindow> windows) {
  return windows.isEmpty ? 'Horario no publicado' : _windows(windows);
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
