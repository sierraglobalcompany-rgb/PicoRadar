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
import '../data/pico_jurisdiction_catalog.dart';
import '../data/pico_preferences.dart';
import '../data/restriction_store.dart';
import '../domain/city_restriction_summary.dart';
import '../domain/restriction_day_evaluation.dart';
import '../domain/vehicle_month_evaluation.dart';

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
                        runtimeJurisdictions: jurisdictionItems,
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
                        runtimeJurisdictions: jurisdictionItems,
                      );
                    }
                    return _CityPicoView(
                      key: ValueKey(jurisdictionId),
                      jurisdictions: jurisdictionItems,
                      selectedJurisdictionId: selectedId,
                      initialJurisdictionId: jurisdictionId,
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

class _PersonalPicoView extends ConsumerStatefulWidget {
  const _PersonalPicoView({
    required this.vehicle,
    required this.jurisdiction,
    required this.runtimeJurisdictions,
  });

  final VehicleProfile vehicle;
  final RestrictionJurisdiction jurisdiction;
  final List<RestrictionJurisdiction> runtimeJurisdictions;

  @override
  ConsumerState<_PersonalPicoView> createState() => _PersonalPicoViewState();
}

class _PersonalPicoViewState extends ConsumerState<_PersonalPicoView> {
  String? _transientJurisdictionId;
  Object? _coverageKey;
  Future<RestrictionRuleSet>? _coverageFuture;
  ProviderSubscription<int>? _expirySubscription;
  int _expiryRevision = 0;
  Object? _dailyKey;
  final _dailyEvaluations = <DateTime, RestrictionDayEvaluation>{};

  @override
  void dispose() {
    _expirySubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(bogotaDateProvider);
    final jurisdiction =
        _findJurisdiction(
          widget.runtimeJurisdictions,
          _transientJurisdictionId,
        ) ??
        widget.jurisdiction;
    final alertPreferences = ref
        .watch(picoAlertPreferencesProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => _defaultAlertPreferences,
        );
    final store = ref.watch(restrictionStoreProvider);
    final seed = ref.watch(bundledRestrictionsProvider.future);
    final vehicle = widget.vehicle;
    final coverageKey = (
      store,
      seed,
      jurisdiction.id,
      vehicle.kind,
      vehicle.serviceType,
      DateUtils.dateOnly(now),
      _expiryRevision,
    );
    if (_coverageKey != coverageKey) {
      _coverageKey = coverageKey;
      _expirySubscription?.close();
      _expirySubscription = null;
      final instant = ref.read(currentInstantProvider);
      _coverageFuture = seed.then((_) async {
        final rules = await store.loadCoverage(
          jurisdiction.id,
          vehicle.kind,
          vehicle.serviceType,
          instant,
        );
        if (mounted && _coverageKey == coverageKey) {
          _expirySubscription = _watchCoverageExpiry(
            ref,
            [rules],
            instant,
            () => setState(() => _expiryRevision++),
          );
        }
        return rules;
      });
    }
    return FutureBuilder<RestrictionRuleSet>(
      future: _coverageFuture,
      builder: (context, snapshot) {
        // FutureBuilder retains the previous result while a new day loads.
        final ruleSet =
            snapshot.connectionState == ConnectionState.done && snapshot.hasData
            ? snapshot.data!
            : const RestrictionRuleSet(
                coverageKnown: false,
                dataIsStale: false,
                rules: [],
              );
        final dailyKey = (ruleSet, jurisdiction.id, widget.vehicle, now);
        if (_dailyKey != dailyKey) {
          _dailyKey = dailyKey;
          _dailyEvaluations.clear();
        }
        // Only the current view's day and its next 30 days can enter this cache.
        RestrictionDayEvaluation evaluate(DateTime date) =>
            _dailyEvaluations.putIfAbsent(
              date,
              () => _evaluate(ruleSet, jurisdiction, widget.vehicle, date),
            );
        final today = evaluate(now);
        final tomorrowDate = DateTime(now.year, now.month, now.day + 1);
        final tomorrow = evaluate(tomorrowDate);
        final futureDays = [
          for (var offset = 1; offset <= 14; offset += 1)
            DateTime(now.year, now.month, now.day + offset),
        ];
        final nextRestriction = _nextRestriction(now, evaluate);

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
            _SourceStrip(
              jurisdiction: jurisdiction,
              ruleSet: ruleSet,
              isTransient: jurisdiction.id != widget.jurisdiction.id,
              onSelect: () => _showPersonalCitySelector(context, jurisdiction),
            ),
            if (snapshot.hasError)
              const _InfoFootnote(
                text: 'No pudimos cargar la cobertura. Estado sin confirmar.',
              )
            else
              const SizedBox.shrink(),
            const SizedBox(height: AppSpacing.m),
            _PersonalHero(
              vehicle: widget.vehicle,
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
              vehicle: widget.vehicle,
              now: now,
              days: futureDays,
              evaluations: [for (final day in futureDays) evaluate(day)],
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPersonalCitySelector(
    BuildContext context,
    RestrictionJurisdiction selectedJurisdiction,
  ) async {
    final selected = await _showPicoJurisdictionSelector(
      context: context,
      title: 'Ciudad para este vehículo',
      runtimeJurisdictions: widget.runtimeJurisdictions,
      selectedJurisdictionId: selectedJurisdiction.id,
      now: ref.read(currentInstantProvider),
    );
    if (selected != null && mounted) {
      setState(() => _transientJurisdictionId = selected);
    }
  }
}

class _CityPicoView extends ConsumerStatefulWidget {
  const _CityPicoView({
    required this.jurisdictions,
    required this.selectedJurisdictionId,
    required this.initialJurisdictionId,
    required this.vehicles,
    super.key,
  });

  final List<RestrictionJurisdiction> jurisdictions;
  final String? selectedJurisdictionId;
  final String? initialJurisdictionId;
  final List<VehicleProfile> vehicles;

  @override
  ConsumerState<_CityPicoView> createState() => _CityPicoViewState();
}

class _CityPicoViewState extends ConsumerState<_CityPicoView> {
  String? _consultedJurisdictionId;
  PicoVehicleCategory _category = PicoVehicleCategory.cars;
  Object? _coverageKey;
  Future<List<_CategoryCoverage>>? _coverageFuture;
  ProviderSubscription<int>? _expirySubscription;
  int _expiryRevision = 0;
  Object? _shortcutsKey;
  Future<List<_VehicleShortcutData>>? _shortcutsFuture;
  Object? _summaryKey;
  late CityRestrictionDaySummary _summary;
  late CityRestrictionRuleSummary _ruleSummary;
  late CityRestrictionRotationSummary _rotation;

  @override
  void initState() {
    super.initState();
    _consultedJurisdictionId = widget.initialJurisdictionId;
  }

  @override
  void dispose() {
    _expirySubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(bogotaDateProvider);
    final globalJurisdiction = _findJurisdiction(
      widget.jurisdictions,
      widget.selectedJurisdictionId,
    );
    final jurisdiction = _consultedJurisdictionId != null
        ? _findJurisdiction(widget.jurisdictions, _consultedJurisdictionId)
        : globalJurisdiction ??
              (widget.jurisdictions.isNotEmpty
                  ? widget.jurisdictions.first
                  : null);
    if (jurisdiction == null) {
      if (_consultedJurisdictionId != null) {
        return const _Message('No reconocemos la ciudad solicitada.');
      }
      return const _Message('No hay ciudades disponibles para consultar.');
    }
    final isTransient =
        globalJurisdiction != null && jurisdiction.id != globalJurisdiction.id;
    final store = ref.watch(restrictionStoreProvider);
    final seed = ref.watch(bundledRestrictionsProvider.future);
    final coverageKey = (
      store,
      seed,
      jurisdiction.id,
      DateUtils.dateOnly(now),
      _expiryRevision,
    );
    final instant = ref.read(currentInstantProvider);
    if (_coverageKey != coverageKey) {
      _coverageKey = coverageKey;
      _expirySubscription?.close();
      _expirySubscription = null;
      _coverageFuture = seed.then((_) async {
        final coverages = await _loadCategoryCoverages(
          store,
          jurisdiction,
          instant,
        );
        if (mounted && _coverageKey == coverageKey) {
          _expirySubscription = _watchCoverageExpiry(
            ref,
            coverages.map((item) => item.ruleSet),
            instant,
            () => setState(() => _expiryRevision++),
          );
        }
        return coverages;
      });
    }
    final vehicles = widget.vehicles;
    final shortcutsKey = (coverageKey, vehicles);
    if (_shortcutsKey != shortcutsKey) {
      _shortcutsKey = shortcutsKey;
      _shortcutsFuture = _coverageFuture!.then(
        (coverages) => _loadVehicleShortcuts(
          store,
          jurisdiction,
          vehicles,
          now,
          instant,
          coverages,
        ),
      );
    }

    return FutureBuilder<List<_CategoryCoverage>>(
      future: _coverageFuture,
      builder: (context, snapshot) {
        final coverages =
            snapshot.connectionState == ConnectionState.done && snapshot.hasData
            ? snapshot.data!
            : [
                for (final category in PicoVehicleCategory.values)
                  _CategoryCoverage(
                    category: category,
                    ruleSet: const RestrictionRuleSet(
                      coverageKnown: false,
                      dataIsStale: false,
                      rules: [],
                    ),
                  ),
              ];
        final currentCoverage = coverages.firstWhere(
          (item) => item.category == _category,
          orElse: () => coverages.first,
        );
        final summaryKey = (
          currentCoverage.ruleSet,
          jurisdiction.id,
          currentCoverage.category,
          now,
        );
        if (_summaryKey != summaryKey) {
          _summaryKey = summaryKey;
          _summary = summarizeCityRestrictionDay(
            ruleSet: currentCoverage.ruleSet,
            jurisdictionId: jurisdiction.id,
            category: currentCoverage.category,
            date: now,
          );
          _ruleSummary = summarizeCityRestrictionRules(
            ruleSet: currentCoverage.ruleSet,
            jurisdictionId: jurisdiction.id,
            category: currentCoverage.category,
            date: now,
          );
          _rotation = summarizeCityRestrictionRotation(
            ruleSet: currentCoverage.ruleSet,
            jurisdictionId: jurisdiction.id,
            category: currentCoverage.category,
            date: now,
          );
        }

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
            if (snapshot.hasError)
              const _InfoFootnote(
                text: 'No pudimos cargar la cobertura. Estado sin confirmar.',
              )
            else
              const SizedBox.shrink(),
            const SizedBox(height: AppSpacing.m),
            _CategorySegment(
              coverages: coverages,
              selected: currentCoverage.category,
              onChanged: (category) => setState(() => _category = category),
            ),
            const SizedBox(height: AppSpacing.m),
            _CityHero(
              summary: _summary,
              ruleSummary: _ruleSummary,
              jurisdiction: jurisdiction,
            ),
            const SizedBox(height: AppSpacing.m),
            _RotationMatrixCard(rotation: _rotation),
            const SizedBox(height: AppSpacing.m),
            _RuleSummaryCard(summary: _ruleSummary),
            const SizedBox(height: AppSpacing.m),
            _WeekSchedule(
              jurisdiction: jurisdiction,
              coverage: currentCoverage,
              weekStart: _weekStart(now),
              currentDate: now,
            ),
            const SizedBox(height: AppSpacing.m),
            FutureBuilder<List<_VehicleShortcutData>>(
              future: _shortcutsFuture,
              builder: (context, shortcuts) {
                return _VehicleShortcuts(
                  items: shortcuts.connectionState == ConnectionState.done
                      ? shortcuts.data ?? const []
                      : const [],
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
    final selected = await _showPicoJurisdictionSelector(
      context: context,
      title: 'Consultar ciudad',
      runtimeJurisdictions: widget.jurisdictions,
      selectedJurisdictionId:
          _consultedJurisdictionId ?? widget.selectedJurisdictionId,
      now: ref.read(currentInstantProvider),
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

Future<String?> _showPicoJurisdictionSelector({
  required BuildContext context,
  required String title,
  required List<RestrictionJurisdiction> runtimeJurisdictions,
  required String? selectedJurisdictionId,
  required DateTime now,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: _CitySelectorSheet(
        title: title,
        runtimeJurisdictions: runtimeJurisdictions,
        selectedJurisdictionId: selectedJurisdictionId,
        now: now,
      ),
    ),
  );
}

class _CitySelectorSheet extends ConsumerStatefulWidget {
  const _CitySelectorSheet({
    required this.title,
    required this.runtimeJurisdictions,
    required this.selectedJurisdictionId,
    required this.now,
  });

  final String title;
  final List<RestrictionJurisdiction> runtimeJurisdictions;
  final String? selectedJurisdictionId;
  final DateTime now;

  @override
  ConsumerState<_CitySelectorSheet> createState() => _CitySelectorSheetState();
}

class _CitySelectorSheetState extends ConsumerState<_CitySelectorSheet> {
  late final TextEditingController _controller;
  late final Future<Map<String, _CityCoverageAvailability>> _availability;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _availability = _loadCityAvailability();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(picoJurisdictionCatalogProvider);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.72,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.l,
          0,
          AppSpacing.l,
          AppSpacing.l + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          key: const ValueKey('pico-city-selector'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: AppTextStyles.h2),
            const SizedBox(height: AppSpacing.s),
            TextField(
              key: const ValueKey('pico-city-search'),
              controller: _controller,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Buscar ciudad',
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: AppSpacing.s),
            Expanded(
              child: FutureBuilder<Map<String, _CityCoverageAvailability>>(
                future: _availability,
                builder: (context, availabilitySnapshot) {
                  return catalog.when(
                    data: (catalog) => _CitySelectorList(
                      entries: _catalogWithRuntimeFallback(
                        catalog,
                        widget.runtimeJurisdictions,
                      ),
                      query: _query,
                      runtimeJurisdictionIds: widget.runtimeJurisdictions
                          .map((jurisdiction) => jurisdiction.id)
                          .toSet(),
                      availability: availabilitySnapshot.data ?? const {},
                      selectedJurisdictionId: widget.selectedJurisdictionId,
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stackTrace) => Center(
                      child: Text(
                        'No pudimos cargar el catálogo.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, _CityCoverageAvailability>> _loadCityAvailability() async {
    final store = ref.read(restrictionStoreProvider);
    final values = <String, _CityCoverageAvailability>{};
    for (final jurisdiction in widget.runtimeJurisdictions) {
      final categories = <String>[];
      var stale = false;
      for (final category in PicoVehicleCategory.values) {
        final ruleSet = await store.loadCoverage(
          jurisdiction.id,
          category.kind,
          category.serviceType,
          widget.now,
        );
        if (ruleSet.coverageKnown) {
          categories.add(category.label);
          stale = stale || ruleSet.dataIsStale;
        }
      }
      values[jurisdiction.id] = _CityCoverageAvailability(
        categories: categories,
        dataIsStale: stale,
      );
    }
    return values;
  }
}

class _CitySelectorList extends StatelessWidget {
  const _CitySelectorList({
    required this.entries,
    required this.query,
    required this.runtimeJurisdictionIds,
    required this.availability,
    required this.selectedJurisdictionId,
  });

  final List<PicoJurisdictionCatalogEntry> entries;
  final String query;
  final Set<String> runtimeJurisdictionIds;
  final Map<String, _CityCoverageAvailability> availability;
  final String? selectedJurisdictionId;

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = normalizePicoJurisdictionText(query);
    final filtered = entries
        .where((entry) {
          if (normalizedQuery.isEmpty) {
            return true;
          }
          return normalizePicoJurisdictionText(
            '${entry.name} ${entry.department}',
          ).contains(normalizedQuery);
        })
        .toList(growable: false);
    final available = filtered
        .where((entry) => runtimeJurisdictionIds.contains(entry.id))
        .toList(growable: false);
    final upcoming = filtered
        .where((entry) => !runtimeJurisdictionIds.contains(entry.id))
        .toList(growable: false);

    if (filtered.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(child: Text('Sin resultados')),
      );
    }

    return ListView(
      key: const ValueKey('pico-city-selector-results'),
      children: [
        if (available.isNotEmpty)
          _CitySelectorSection(
            key: const ValueKey('pico-city-section-available'),
            title: 'Disponibles en PicoRadar',
            entries: available,
            available: true,
            availability: availability,
            selectedJurisdictionId: selectedJurisdictionId,
          ),
        if (upcoming.isNotEmpty)
          _CitySelectorSection(
            key: const ValueKey('pico-city-section-upcoming'),
            title: 'Otras ciudades',
            entries: upcoming,
            available: false,
            availability: availability,
            selectedJurisdictionId: selectedJurisdictionId,
          ),
      ],
    );
  }
}

class _CitySelectorSection extends StatelessWidget {
  const _CitySelectorSection({
    super.key,
    required this.title,
    required this.entries,
    required this.available,
    required this.availability,
    required this.selectedJurisdictionId,
  });

  final String title;
  final List<PicoJurisdictionCatalogEntry> entries;
  final bool available;
  final Map<String, _CityCoverageAvailability> availability;
  final String? selectedJurisdictionId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.s,
              bottom: AppSpacing.xs,
            ),
            child: Text(title, style: AppTextStyles.caption),
          ),
          for (final entry in entries)
            _PicoCatalogCityTile(
              entry: entry,
              available: available,
              availability: availability[entry.id],
              selected: entry.id == selectedJurisdictionId,
            ),
        ],
      ),
    );
  }
}

class _PicoCatalogCityTile extends StatelessWidget {
  const _PicoCatalogCityTile({
    required this.entry,
    required this.available,
    required this.availability,
    required this.selected,
  });

  final PicoJurisdictionCatalogEntry entry;
  final bool available;
  final _CityCoverageAvailability? availability;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final statusLabel = available ? 'Disponible' : 'Próximamente';
    return ListTile(
      key: ValueKey('pico-city-option-${entry.id}'),
      enabled: available,
      minVerticalPadding: AppSpacing.s,
      title: Text(entry.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            available
                ? availability?.description ?? 'Verificando cobertura'
                : '${entry.department} · Cobertura en preparación',
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _AvailabilityChip(
                key: ValueKey('pico-city-status-${entry.id}'),
                label: statusLabel,
                available: available,
              ),
              if (selected) const Icon(Icons.check_rounded),
            ],
          ),
        ],
      ),
      onTap: available ? () => Navigator.of(context).pop(entry.id) : null,
    );
  }
}

class _AvailabilityChip extends StatelessWidget {
  const _AvailabilityChip({
    super.key,
    required this.label,
    required this.available,
  });

  final String label;
  final bool available;

  @override
  Widget build(BuildContext context) {
    final color = available ? AppColors.green : AppColors.orange;
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

List<PicoJurisdictionCatalogEntry> _catalogWithRuntimeFallback(
  PicoJurisdictionCatalog catalog,
  List<RestrictionJurisdiction> runtimeJurisdictions,
) {
  final entries = [...catalog.records];
  final catalogIds = entries.map((entry) => entry.id).toSet();
  for (final jurisdiction in runtimeJurisdictions) {
    if (!catalogIds.contains(jurisdiction.id)) {
      entries.add(
        PicoJurisdictionCatalogEntry(
          id: jurisdiction.id,
          name: jurisdiction.name,
          department: 'Colombia',
          classification: 'SUPPORTED_CURRENT',
          sourceDate: 'runtime',
        ),
      );
    }
  }
  return entries;
}

class _CityCoverageAvailability {
  const _CityCoverageAvailability({
    required this.categories,
    required this.dataIsStale,
  });

  final List<String> categories;
  final bool dataIsStale;

  bool get hasCoverage => categories.isNotEmpty;

  String get description {
    if (categories.isEmpty) {
      return 'Sin cobertura PicoRadar';
    }
    final state = dataIsStale ? 'por actualizar' : 'vigente';
    return '${categories.join(', ')} · Cobertura $state';
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
  const _SourceStrip({
    required this.jurisdiction,
    required this.ruleSet,
    required this.isTransient,
    required this.onSelect,
  });

  final RestrictionJurisdiction jurisdiction;
  final RestrictionRuleSet ruleSet;
  final bool isTransient;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Cambiar ciudad temporal de Pico y Placa',
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.input),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('pico-personal-location-source'),
          onTap: onSelect,
          borderRadius: BorderRadius.circular(AppRadius.input),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.l,
              vertical: AppSpacing.s,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.input),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: AppColors.blue,
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: Text(
                        '${jurisdiction.name}, Colombia',
                        style: AppTextStyles.bodyStrong.copyWith(
                          color: AppColors.teal,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.teal,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  isTransient
                      ? 'Consulta temporal · ${_sourceLabel(ruleSet)}'
                      : _sourceLabel(ruleSet),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    this.icon,
    this.wrap = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool wrap;

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
              maxLines: wrap ? null : 1,
              overflow: wrap ? TextOverflow.visible : TextOverflow.ellipsis,
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
          Wrap(
            spacing: AppSpacing.s,
            runSpacing: AppSpacing.s,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
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
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'MI PICO Y PLACA',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.teal,
                  fontWeight: FontWeight.w900,
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
                        label: _todayStatusText(today.status),
                        color: statusColor,
                        wrap: true,
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
                        'Pico y placa hoy',
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
                        style: AppTextStyles.caption,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s),
                _StatusPill(
                  label: 'Mañana: ${_dailyStatusText(tomorrow.status)}',
                  color: _statusColor(tomorrow.status),
                  wrap: true,
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
      _StatusMetric(
        label: 'Hoy',
        value: _dailyStatusText(status),
        color: color,
      ),
      _StatusMetric(label: 'Horario', value: windows, color: AppColors.navy),
      _StatusMetric(label: 'Regla', value: rule, color: AppColors.navy),
    ];
    return LayoutBuilder(
      key: const ValueKey('pico-personal-status-grid'),
      builder: (context, constraints) {
        if (constraints.maxWidth < 360 ||
            MediaQuery.textScalerOf(context).scale(14) > 18) {
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
    required this.vehicle,
    required this.now,
    required this.days,
    required this.evaluations,
  });

  final RestrictionDayEvaluation today;
  final _NextRestriction? nextRestriction;
  final RestrictionJurisdiction jurisdiction;
  final RestrictionRuleSet ruleSet;
  final VehicleProfile vehicle;
  final DateTime now;
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
          _PersonalCalendar(
            days: days,
            evaluations: evaluations,
            ruleSet: ruleSet,
            jurisdiction: jurisdiction,
            vehicle: vehicle,
            now: now,
          ),
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

class _ImmediateState extends ConsumerWidget {
  const _ImmediateState({
    required this.evaluation,
    required this.nextRestriction,
  });

  final RestrictionDayEvaluation evaluation;
  final _NextRestriction? nextRestriction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(bogotaNowProvider);
    final phase = restrictionPhaseAt(evaluation, now);
    final nextStart = nextRestrictionStartMinute(evaluation, now);
    final color = switch (phase) {
      RestrictionDayPhase.active => AppColors.red,
      RestrictionDayPhase.unknown ||
      RestrictionDayPhase.stale => AppColors.orange,
      _ => AppColors.green,
    };
    final icon = switch (phase) {
      RestrictionDayPhase.active => Icons.block_rounded,
      RestrictionDayPhase.unknown => Icons.help_outline_rounded,
      RestrictionDayPhase.stale => Icons.update_rounded,
      RestrictionDayPhase.before => Icons.schedule_rounded,
      _ => Icons.check_circle_rounded,
    };
    final label = switch (phase) {
      RestrictionDayPhase.active => 'No puede circular',
      RestrictionDayPhase.before =>
        nextStart == null
            ? 'Horario por confirmar'
            : 'Empieza a las ${formatRestrictionTime12(nextStart)}',
      RestrictionDayPhase.between => 'Sin restricción ahora',
      RestrictionDayPhase.finished => 'Restricción finalizada',
      RestrictionDayPhase.unrestricted => 'Sin pico y placa hoy',
      RestrictionDayPhase.unknown => 'Por verificar',
      RestrictionDayPhase.stale => 'Datos vencidos',
    };
    return Row(
      key: const ValueKey('pico-immediate-state'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 30),
        ),
        const SizedBox(width: AppSpacing.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Estado inmediato', style: AppTextStyles.bodyStrong),
              const SizedBox(height: AppSpacing.xs),
              _StatusPill(
                label: 'Hoy · ${_weekday(now)} ${_shortDate(now)}',
                color: AppColors.blue,
                icon: Icons.today_rounded,
                wrap: true,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                key: const ValueKey('pico-immediate-verdict'),
                style: AppTextStyles.bodyStrong.copyWith(color: color),
              ),
              Text(
                _windowsOrControlled(evaluation),
                style: AppTextStyles.caption,
              ),
              if (phase == RestrictionDayPhase.between && nextStart != null)
                Text(
                  'Vuelve a empezar a las ${formatRestrictionTime12(nextStart)}',
                  style: AppTextStyles.caption,
                ),
              if (nextRestriction != null) ...[
                const SizedBox(height: AppSpacing.s),
                Text('Próxima restricción', style: AppTextStyles.bodyStrong),
                Text(
                  '${_weekday(nextRestriction!.date)} '
                  '${_shortDate(nextRestriction!.date)}',
                  key: const ValueKey('pico-next-restriction'),
                  style: AppTextStyles.caption,
                ),
                Text(
                  formatRestrictionWindows12(
                        nextRestriction!.evaluation.effectiveWindows,
                      )
                      .replaceAll(' a. m.', '\u00a0a.\u00a0m.')
                      .replaceAll(' p. m.', '\u00a0p.\u00a0m.'),
                  key: const ValueKey('pico-next-restriction-windows'),
                  style: AppTextStyles.caption,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

enum _PersonalCalendarMode { nextDays, month }

class _PersonalCalendar extends StatefulWidget {
  const _PersonalCalendar({
    required this.days,
    required this.evaluations,
    required this.ruleSet,
    required this.jurisdiction,
    required this.vehicle,
    required this.now,
  });

  final List<DateTime> days;
  final List<RestrictionDayEvaluation> evaluations;
  final RestrictionRuleSet ruleSet;
  final RestrictionJurisdiction jurisdiction;
  final VehicleProfile vehicle;
  final DateTime now;

  @override
  State<_PersonalCalendar> createState() => _PersonalCalendarState();
}

class _PersonalCalendarState extends State<_PersonalCalendar> {
  _PersonalCalendarMode _mode = _PersonalCalendarMode.nextDays;
  late DateTime _visibleMonth;
  bool _monthWasNavigated = false;
  Object? _monthKey;
  List<VehicleMonthDayEvaluation> _monthDays = const [];

  List<VehicleMonthDayEvaluation> _evaluateVisibleMonth() {
    final key = (
      widget.ruleSet,
      widget.jurisdiction.id,
      widget.vehicle,
      _visibleMonth,
      widget.now,
    );
    if (_monthKey != key) {
      _monthKey = key;
      _monthDays = evaluateVehicleMonth(
        ruleSet: widget.ruleSet,
        jurisdictionId: widget.jurisdiction.id,
        vehicle: widget.vehicle,
        year: _visibleMonth.year,
        month: _visibleMonth.month,
      );
    }
    return _monthDays;
  }

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(widget.now.year, widget.now.month);
  }

  @override
  void didUpdateWidget(covariant _PersonalCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ruleSet != widget.ruleSet ||
        oldWidget.vehicle != widget.vehicle ||
        oldWidget.jurisdiction.id != widget.jurisdiction.id ||
        oldWidget.now != widget.now) {
      _monthKey = null;
      _monthDays = const [];
    }
    if (!_monthWasNavigated &&
        (oldWidget.now.year != widget.now.year ||
            oldWidget.now.month != widget.now.month)) {
      _visibleMonth = DateTime(widget.now.year, widget.now.month);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxWindows = widget.evaluations.fold<int>(
      1,
      (count, evaluation) => evaluation.effectiveWindows.length > count
          ? evaluation.effectiveWindows.length
          : count,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Próximos días', style: AppTextStyles.bodyStrong),
            const SizedBox(height: AppSpacing.s),
            SegmentedButton<_PersonalCalendarMode>(
              key: const ValueKey('pico-personal-calendar-mode'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: _PersonalCalendarMode.nextDays,
                  label: Text('Próximos días'),
                ),
                ButtonSegment(
                  value: _PersonalCalendarMode.month,
                  label: Text('Mes'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selected) {
                setState(() => _mode = selected.single);
              },
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                minimumSize: WidgetStatePropertyAll(Size(0, 40)),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        if (_mode == _PersonalCalendarMode.nextDays)
          SizedBox(
            key: const ValueKey('pico-personal-calendar'),
            height:
                28 +
                MediaQuery.textScalerOf(context).scale(104 + 44.0 * maxWindows),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.days.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s),
              itemBuilder: (context, index) => _DayCard(
                key: ValueKey('pico-calendar-day-${index + 1}'),
                date: widget.days[index],
                evaluation: widget.evaluations[index],
              ),
            ),
          )
        else
          _MonthCalendar(
            visibleMonth: _visibleMonth,
            now: widget.now,
            days: _evaluateVisibleMonth(),
            sourceLabel: _sourceLabel(widget.ruleSet),
            onPrevious: () {
              setState(() {
                _monthWasNavigated = true;
                _visibleMonth = DateTime(
                  _visibleMonth.year,
                  _visibleMonth.month - 1,
                );
              });
            },
            onNext: () {
              setState(() {
                _monthWasNavigated = true;
                _visibleMonth = DateTime(
                  _visibleMonth.year,
                  _visibleMonth.month + 1,
                );
              });
            },
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
      width: 156,
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
            _dailyStatusText(evaluation.status),
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          if (evaluation.status == RestrictionDayStatus.restricted &&
              evaluation.effectiveWindows.isNotEmpty)
            Text(
              formatRestrictionWindows12(evaluation.effectiveWindows),
              style: AppTextStyles.caption.copyWith(fontSize: 11),
            ),
        ],
      ),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.visibleMonth,
    required this.now,
    required this.days,
    required this.sourceLabel,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime visibleMonth;
  final DateTime now;
  final List<VehicleMonthDayEvaluation> days;
  final String sourceLabel;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final leadingEmptyDays =
        DateTime(visibleMonth.year, visibleMonth.month, 1).weekday -
        DateTime.monday;
    final cells = [for (var i = 0; i < leadingEmptyDays; i += 1) null, ...days];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    return Column(
      key: const ValueKey('pico-personal-month-calendar'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              key: const ValueKey('pico-month-previous'),
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left_rounded),
              tooltip: 'Mes anterior',
            ),
            Expanded(
              child: Text(
                '${_monthName(visibleMonth.month)} ${visibleMonth.year}',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyStrong,
              ),
            ),
            IconButton(
              key: const ValueKey('pico-month-next'),
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right_rounded),
              tooltip: 'Mes siguiente',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        const _MonthWeekdayHeader(),
        const SizedBox(height: AppSpacing.xs),
        GridView.builder(
          key: const ValueKey('pico-personal-month-grid'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cells.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (context, index) {
            final item = cells[index];
            if (item == null) {
              return const SizedBox.shrink();
            }
            return _MonthDayCell(
              item: item,
              isToday: _isSameDay(item.date, now),
              sourceLabel: sourceLabel,
            );
          },
        ),
      ],
    );
  }
}

class _MonthWeekdayHeader extends StatelessWidget {
  const _MonthWeekdayHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final label in const ['L', 'M', 'X', 'J', 'V', 'S', 'D'])
          Expanded(
            child: Center(
              child: Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy.withValues(alpha: 0.62),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MonthDayCell extends StatelessWidget {
  const _MonthDayCell({
    required this.item,
    required this.isToday,
    required this.sourceLabel,
  });

  final VehicleMonthDayEvaluation item;
  final bool isToday;
  final String sourceLabel;

  @override
  Widget build(BuildContext context) {
    final status = item.evaluation.status;
    final color = _statusColor(status);
    final restricted = status == RestrictionDayStatus.restricted;
    return Semantics(
      button: true,
      selected: isToday,
      label:
          '${isToday ? 'Hoy · ' : ''}${_date(item.date)} ${_dailyStatusText(status)}',
      child: Material(
        color: restricted
            ? AppColors.red.withValues(alpha: 0.14)
            : color.withValues(
                alpha: status == RestrictionDayStatus.allowed ? 0.07 : 0.1,
              ),
        borderRadius: BorderRadius.circular(AppRadius.input),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('pico-month-day-${_date(item.date)}'),
          onTap: () => _showMonthDayDetail(context, item, sourceLabel),
          child: Container(
            constraints: const BoxConstraints(minHeight: 46),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.input),
              border: Border.all(
                color: isToday ? AppColors.navy : color.withValues(alpha: 0.28),
                width: isToday ? 2 : 1,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    '${item.date.day}',
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: restricted ? AppColors.red : AppColors.navy,
                    ),
                  ),
                ),
                Positioned(
                  right: 5,
                  bottom: 5,
                  child: Container(
                    key: ValueKey(
                      'pico-month-status-${_date(item.date)}-${status.name}',
                    ),
                    width: restricted ? 9 : 7,
                    height: restricted ? 9 : 7,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
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

void _showMonthDayDetail(
  BuildContext context,
  VehicleMonthDayEvaluation item,
  String sourceLabel,
) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final evaluation = item.evaluation;
      final color = _statusColor(evaluation.status);
      return SafeArea(
        top: false,
        child: Padding(
          key: const ValueKey('pico-month-day-detail-sheet'),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.s,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_shortDate(item.date), style: AppTextStyles.caption),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Icon(_statusIcon(evaluation.status), color: color),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Text(
                      _dailyStatusText(evaluation.status),
                      style: AppTextStyles.h2.copyWith(color: color),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s),
              Text(
                _windowsOrControlled(evaluation),
                style: AppTextStyles.bodyStrong,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _detailBasis(evaluation.status),
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: AppSpacing.s),
              Text(sourceLabel, style: AppTextStyles.caption),
            ],
          ),
        ),
      );
    },
  );
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
        LayoutBuilder(
          builder: (context, constraints) {
            final selector = _CitySelectorPill(
              jurisdiction: jurisdiction,
              isTransient: isTransient,
              onSelect: onSelect,
            );
            final freshness = _FreshnessPill(ruleSet: ruleSet);
            final textScaler = MediaQuery.textScalerOf(context);
            final cityStyle = DefaultTextStyle.of(context).style
                .merge(AppTextStyles.bodyStrong);
            final painter = TextPainter(
              textDirection: Directionality.of(context),
              textScaler: textScaler,
              locale: Localizations.maybeLocaleOf(context),
            );
            var longestWordWidth = 0.0;
            for (final word in jurisdiction.name.split(RegExp(r'\s+'))) {
              painter.text = TextSpan(text: word, style: cityStyle);
              painter.layout();
              if (painter.width > longestWordWidth) {
                longestWordWidth = painter.width;
              }
            }
            painter.dispose();
            final selectorMinWidth =
                longestWordWidth +
                2 * AppSpacing.m +
                2 * _CitySelectorPill.borderWidth +
                2 * AppIconSize.m +
                AppSpacing.s;
            final inlineWidth = (constraints.maxWidth - AppSpacing.m) / 2;
            if (textScaler.scale(1) > 1.25 || inlineWidth < selectorMinWidth) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  selector,
                  const SizedBox(height: AppSpacing.s),
                  freshness,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: selector),
                const SizedBox(width: AppSpacing.m),
                Expanded(child: freshness),
              ],
            );
          },
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
  static const borderWidth = 1.0;

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
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: AppSpacing.s,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border, width: borderWidth),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.location_on_rounded,
                color: AppColors.teal,
                size: AppIconSize.m,
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(jurisdiction.name, style: AppTextStyles.bodyStrong),
                    Text(
                      isTransient ? 'Temporal' : 'Configurada',
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.expand_more_rounded, size: AppIconSize.m),
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
                onPressed: () => onChanged(coverages[index].category),
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
  const _CityHero({
    required this.summary,
    required this.ruleSummary,
    required this.jurisdiction,
  });

  final CityRestrictionDaySummary summary;
  final CityRestrictionRuleSummary ruleSummary;
  final RestrictionJurisdiction jurisdiction;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(summary.status);
    final description = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(jurisdiction.name, style: AppTextStyles.caption),
        const SizedBox(height: AppSpacing.xs),
        _StatusPill(
          label: 'Hoy · ${_weekday(summary.date)} ${summary.date.day}',
          color: color,
          icon: _statusIcon(summary.status),
          wrap: true,
        ),
        const SizedBox(height: AppSpacing.m),
        Text(
          _statusText(summary.status),
          style: AppTextStyles.h1.copyWith(color: color),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${ruleSummary.category.label} · ${summary.digitBasis.label}',
          style: AppTextStyles.bodyStrong,
        ),
      ],
    );
    final art = SizedBox(
      height: 146,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Semantics(
          label: 'Ilustración de pico y placa en ciudad',
          child: Image.asset(
            _cityHeroArtAsset,
            key: const ValueKey('pico-city-hero-art'),
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
            cacheWidth: 520,
          ),
        ),
      ),
    );
    return AppCard(
      key: const ValueKey('pico-city-hero'),
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (MediaQuery.textScalerOf(context).scale(1) > 1.25)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                description,
                const SizedBox(height: AppSpacing.m),
                SizedBox(width: 146, child: art),
              ],
            )
          else
            Row(
              children: [
                Expanded(flex: 58, child: description),
                const SizedBox(width: AppSpacing.m),
                Expanded(flex: 42, child: art),
              ],
            ),
          const SizedBox(height: AppSpacing.s),
          _HeroFact(
            label: summary.status == RestrictionDayStatus.restricted
                ? 'Restringidos'
                : 'Estado',
            value: summary.status == RestrictionDayStatus.restricted
                ? _digitsOrRule(summary)
                : summary.ruleLabel,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _heroScheduleText(summary.effectiveWindows),
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

class _HeroFact extends StatelessWidget {
  const _HeroFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label:',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.navy.withValues(alpha: 0.68),
          ),
        ),
        Text(value, style: AppTextStyles.bodyStrong),
      ],
    );
  }
}

class _RuleSummaryCard extends StatelessWidget {
  const _RuleSummaryCard({required this.summary});

  final CityRestrictionRuleSummary summary;

  @override
  Widget build(BuildContext context) {
    final unavailable = !summary.coverageKnown;
    return AppCard(
      key: const ValueKey('pico-city-rule-summary-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cómo aplica', style: AppTextStyles.h2),
          const SizedBox(height: AppSpacing.m),
          if (unavailable)
            _RuleSummaryLine(
              label: summary.category.label,
              value: 'Cobertura aún no disponible para esta ciudad.',
            )
          else ...[
            _RuleSummaryLine(label: 'Categoría', value: summary.category.label),
            _RuleSummaryLine(
              label: 'Se controla por',
              value: summary.digitBasis.label.toUpperCase(),
            ),
            _RuleSummaryLine(
              label: 'Horario',
              value: _windowsOrText(summary.generalWindows),
            ),
            _RuleSummaryLine(
              label: 'Vigencia',
              value: _validity(summary.validFrom, summary.validUntil),
            ),
          ],
        ],
      ),
    );
  }
}

class _RuleSummaryLine extends StatelessWidget {
  const _RuleSummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(label, style: AppTextStyles.caption),
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(child: Text(value, style: AppTextStyles.bodyStrong)),
        ],
      ),
    );
  }
}

class _RotationMatrixCard extends StatelessWidget {
  const _RotationMatrixCard({required this.rotation});

  final CityRestrictionRotationSummary rotation;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const ValueKey('pico-city-rotation-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rotation.title, style: AppTextStyles.h2),
          const SizedBox(height: AppSpacing.s),
          for (var index = 0; index < rotation.rows.length; index += 1)
            _RotationRow(row: rotation.rows[index], index: index),
        ],
      ),
    );
  }
}

class _RotationRow extends StatelessWidget {
  const _RotationRow({required this.row, required this.index});

  final CityRestrictionRotationRow row;
  final int index;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(row.status);
    return Container(
      key: ValueKey('pico-city-rotation-row-$index'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.7)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final date = Text(row.label, style: AppTextStyles.bodyStrong);
          final digits = Text(
            _rotationDigits(row),
            style: AppTextStyles.bodyStrong.copyWith(color: color),
          );
          final stacked =
              constraints.maxWidth < 320 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.25;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (stacked) ...[
                date,
                digits,
              ] else
                Row(
                  children: [
                    SizedBox(width: 92, child: date),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(child: digits),
                  ],
                ),
              const SizedBox(height: AppSpacing.xs),
              Text(_compactWindows(row.windows), style: AppTextStyles.caption),
            ],
          );
        },
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
          SingleChildScrollView(
            key: const ValueKey('pico-city-week-list'),
            scrollDirection: Axis.horizontal,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < days.length; index += 1) ...[
                    if (index > 0) const SizedBox(width: AppSpacing.s),
                    _WeekDayTile(
                      index: index,
                      isToday: _isSameDay(days[index], currentDate),
                      summary: summarizeCityRestrictionDay(
                        ruleSet: coverage.ruleSet,
                        jurisdictionId: jurisdiction.id,
                        category: coverage.category,
                        date: days[index],
                      ),
                    ),
                  ],
                ],
              ),
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
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final tileWidth = 112 + ((textScale - 1) * 72);
    return Container(
      key: ValueKey('pico-city-week-day-$index'),
      width: tileWidth,
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
          const SizedBox(height: AppSpacing.xs),
          Text(
            _weekStatusText(summary.status),
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (summary.status == RestrictionDayStatus.restricted) ...[
            const SizedBox(height: 2),
            Text(
              _digitsOrRule(summary),
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
          const Spacer(),
          Text(
            _compactWindows(summary.effectiveWindows),
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
        onTap: () => context.push(
          picoShellLocation(
            origin: PicoRouteOrigin.apps,
            vehicleId: params['vehicleId'],
            jurisdictionId: params['jurisdictionId'],
          ),
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
          Text(_sourceLabel(ruleSet), style: AppTextStyles.body),
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

ProviderSubscription<int>? _watchCoverageExpiry(
  WidgetRef ref,
  Iterable<RestrictionRuleSet> coverages,
  DateTime loadedAt,
  VoidCallback onChanged,
) {
  final deadlines = coverages
      .map((rules) => rules.staleAfter)
      .whereType<DateTime>()
      .toSet();
  if (deadlines.isEmpty) return null;
  // One boundary selector handles multiple categories and backward clock changes.
  int expiredAt(DateTime instant) =>
      deadlines.where((deadline) => !instant.isBefore(deadline)).length;
  final subscription = ref.listenManual(
    currentInstantProvider.select(expiredAt),
    (_, _) => onChanged(),
  );
  if (subscription.read() != expiredAt(loadedAt)) onChanged();
  return subscription;
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
  RestrictionStore store,
  RestrictionJurisdiction jurisdiction,
  DateTime instant,
) async {
  return [
    for (final category in PicoVehicleCategory.values)
      _CategoryCoverage(
        category: category,
        ruleSet: await store.loadCoverage(
          jurisdiction.id,
          category.kind,
          category.serviceType,
          instant,
        ),
      ),
  ];
}

Future<List<_VehicleShortcutData>> _loadVehicleShortcuts(
  RestrictionStore store,
  RestrictionJurisdiction jurisdiction,
  List<VehicleProfile> vehicles,
  DateTime now,
  DateTime instant,
  List<_CategoryCoverage> categoryCoverages,
) async {
  final items = <_VehicleShortcutData>[];
  final coverages = {
    for (final item in categoryCoverages)
      (item.category.kind, item.category.serviceType): item.ruleSet,
  };
  for (final vehicle in vehicles.take(4)) {
    final category = (vehicle.kind, vehicle.serviceType);
    final ruleSet = coverages[category] ??= await store.loadCoverage(
      jurisdiction.id,
      vehicle.kind,
      vehicle.serviceType,
      instant,
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
  DateTime now,
  RestrictionDayEvaluation Function(DateTime) evaluate,
) {
  for (var offset = 1; offset <= 30; offset += 1) {
    final date = DateTime(now.year, now.month, now.day + offset);
    final evaluation = evaluate(date);
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

const _cityHeroArtAsset = 'assets/pico/pico_city_hero_art_owner_v1.png';

String _statusText(RestrictionDayStatus status) {
  return switch (status) {
    RestrictionDayStatus.restricted => 'Restricción hoy',
    RestrictionDayStatus.allowed => 'Sin restricción hoy',
    RestrictionDayStatus.unknown => 'Sin confirmar',
    RestrictionDayStatus.stale => 'Datos desactualizados',
  };
}

String _dailyStatusText(RestrictionDayStatus status) {
  return switch (status) {
    RestrictionDayStatus.restricted => 'Con pico y placa',
    RestrictionDayStatus.allowed => 'Sin pico y placa',
    RestrictionDayStatus.unknown => 'Por verificar',
    RestrictionDayStatus.stale => 'Datos vencidos',
  };
}

String _todayStatusText(RestrictionDayStatus status) {
  return switch (status) {
    RestrictionDayStatus.restricted => 'Hoy tienes pico y placa',
    RestrictionDayStatus.allowed => 'Sin pico y placa hoy',
    RestrictionDayStatus.unknown => 'Hoy: por verificar',
    RestrictionDayStatus.stale => 'Hoy: datos vencidos',
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

String _weekStatusText(RestrictionDayStatus status) {
  return switch (status) {
    RestrictionDayStatus.restricted => 'No circula',
    RestrictionDayStatus.allowed => 'Libre',
    RestrictionDayStatus.unknown ||
    RestrictionDayStatus.stale => 'Sin información vigente',
  };
}

String _detailBasis(RestrictionDayStatus status) {
  return switch (status) {
    RestrictionDayStatus.restricted =>
      'Restricción calculada para este vehículo.',
    RestrictionDayStatus.allowed =>
      'No hay regla restrictiva aplicable a este vehículo.',
    RestrictionDayStatus.unknown =>
      'La cobertura no permite confirmar este día.',
    RestrictionDayStatus.stale =>
      'La regla existe, pero la vigencia debe actualizarse.',
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
    return evaluation.effectiveWindows.isEmpty
        ? 'Horario no publicado'
        : formatRestrictionWindows12(evaluation.effectiveWindows);
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

String _heroScheduleText(List<RestrictionDayWindow> windows) {
  return windows.isEmpty
      ? 'Horario no publicado'
      : 'Horario: ${_windows(windows)}';
}

String _digitsOrRule(CityRestrictionDaySummary summary) {
  if (summary.restrictedDigits.isEmpty) {
    return summary.ruleLabel;
  }
  return summary.restrictedDigits.map((digit) => '$digit').join(' · ');
}

String _rotationDigits(CityRestrictionRotationRow row) {
  if (row.status == RestrictionDayStatus.restricted) {
    if (row.digits.isEmpty) {
      return 'Todas las placas';
    }
    return row.digits.map((digit) => '$digit').join(' · ');
  }
  return switch (row.status) {
    RestrictionDayStatus.allowed => 'Sin restricción',
    RestrictionDayStatus.unknown => 'Cobertura no disponible',
    RestrictionDayStatus.stale => 'Datos por actualizar',
    RestrictionDayStatus.restricted => 'Todas las placas',
  };
}

String _validity(DateTime? validFrom, DateTime? validUntil) {
  if (validFrom == null && validUntil == null) {
    return 'No publicada';
  }
  if (validFrom != null && validUntil != null) {
    return '${_shortDate(validFrom)} - ${_shortDate(validUntil)}';
  }
  if (validFrom != null) {
    return 'Desde ${_shortDate(validFrom)}';
  }
  return 'Hasta ${_shortDate(validUntil!)}';
}

String _compactWindows(List<RestrictionDayWindow> windows) {
  return windows.isEmpty ? 'Sin hora' : formatRestrictionWindows12(windows);
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
  return formatRestrictionWindows12(windows);
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

String _monthName(int month) {
  return switch (month) {
    1 => 'Enero',
    2 => 'Febrero',
    3 => 'Marzo',
    4 => 'Abril',
    5 => 'Mayo',
    6 => 'Junio',
    7 => 'Julio',
    8 => 'Agosto',
    9 => 'Septiembre',
    10 => 'Octubre',
    11 => 'Noviembre',
    _ => 'Diciembre',
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
