import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_providers.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/design_system/surfaces.dart';
import '../../garage/data/vehicle_profile.dart';
import '../../garage/presentation/vehicle_display.dart';
import '../../garage/presentation/vehicle_plate_badge.dart';
import '../../location/application/location_controller.dart';
import '../../visual_assets/presentation/visual_asset_widgets.dart';
import '../data/pico_jurisdiction_catalog.dart';
import '../data/restriction_store.dart';
import '../domain/city_restriction_summary.dart';
import '../domain/colombia_holiday_calendar.dart';
import '../domain/restriction_engine.dart';
import '../domain/restriction_rule.dart';
import '../domain/restriction_day_evaluation.dart';
import '../domain/vehicle_month_evaluation.dart';
import 'today_restriction_summary.dart';

part 'city_pico_widgets.dart';

class PicoDetailScreen extends ConsumerWidget {
  const PicoDetailScreen({this.vehicleId, this.jurisdictionId, super.key});

  final String? vehicleId;
  final String? jurisdictionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seed = ref.watch(bundledRestrictionsProvider);
    final jurisdictions = ref.watch(restrictionJurisdictionsProvider);
    final selected = ref.watch(selectedPicoJurisdictionIdProvider);

    return Scaffold(
      body: PicoSurface(
        child: seed.when(
          data: (_) => jurisdictions.when(
            data: (jurisdictionItems) => selected.when(
              data: (selectedId) {
                if (!_hasQueryValue(vehicleId)) {
                  return _CityPicoView(
                    key: ValueKey(jurisdictionId),
                    jurisdictions: jurisdictionItems,
                    selectedJurisdictionId: selectedId,
                    initialJurisdictionId: jurisdictionId,
                  );
                }
                return ref
                    .watch(vehicleListProvider)
                    .when(
                      data: (vehicleItems) => ref
                          .watch(activeVehicleProvider)
                          .when(
                            data: (activeVehicle) {
                              final explicitVehicle = _findVehicle(
                                vehicleItems,
                                vehicleId,
                              );
                              if (_hasQueryValue(vehicleId) &&
                                  explicitVehicle != null) {
                                final selectedJurisdiction = _findJurisdiction(
                                  jurisdictionItems,
                                  selectedId,
                                );
                                final transient = _findJurisdiction(
                                  jurisdictionItems,
                                  jurisdictionId,
                                );
                                final jurisdiction =
                                    transient ?? selectedJurisdiction;
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
                              if (_hasQueryValue(vehicleId) &&
                                  explicitVehicle == null) {
                                final fallback = activeVehicle;
                                final jurisdiction = _findJurisdiction(
                                  jurisdictionItems,
                                  selectedId,
                                );
                                if (fallback == null || jurisdiction == null) {
                                  return const _Message(
                                    'No pudimos abrir ese vehículo.',
                                  );
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
                              );
                            },
                            loading: _Loading.new,
                            error: (error, stackTrace) =>
                                _Message(error.toString()),
                          ),
                      loading: _Loading.new,
                      error: (error, stackTrace) => _Message(error.toString()),
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
        final nextRestriction = _nextRestriction(now, evaluate);

        return ListView(
          key: const ValueKey('pico-scroll-root'),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s,
            AppSpacing.s,
            AppSpacing.s,
            AppSpacing.xl,
          ),
          children: [
            if (snapshot.hasError)
              const _InfoFootnote(
                text: 'No pudimos cargar la cobertura. Estado sin confirmar.',
              ),
            const SizedBox(height: AppSpacing.s),
            _PersonalHero(
              vehicle: widget.vehicle,
              jurisdiction: jurisdiction,
              isTransient: jurisdiction.id != widget.jurisdiction.id,
              onSelectCity: () =>
                  _showPersonalCitySelector(context, jurisdiction),
            ),
            const SizedBox(height: AppSpacing.l),
            TodayRestrictionSummary(
              key: const ValueKey('pico-personal-screen'),
              keyPrefix: 'pico',
              evaluation: today,
              vehicleKind: widget.vehicle.kind,
              cityLabel: _shortCityLabel(jurisdiction),
            ),
            const SizedBox(height: AppSpacing.m),
            _PersonalLowerModule(
              key: const ValueKey('pico-personal-calendar-state'),
              nextRestriction: nextRestriction,
              jurisdiction: jurisdiction,
              ruleSet: ruleSet,
              vehicle: widget.vehicle,
              now: now,
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
    super.key,
  });

  final List<RestrictionJurisdiction> jurisdictions;
  final String? selectedJurisdictionId;
  final String? initialJurisdictionId;

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
  Object? _summaryKey;
  late CityRestrictionDaySummary _summary;
  late CityRestrictionRuleSummary _ruleSummary;
  late _CityWeekData _week;
  bool _showDates = false;

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
    final global = _findJurisdiction(
      widget.jurisdictions,
      widget.selectedJurisdictionId,
    );
    final jurisdiction = _consultedJurisdictionId != null
        ? _findJurisdiction(widget.jurisdictions, _consultedJurisdictionId)
        : global;
    if (jurisdiction == null) {
      return _CityEmptySelection(
        invalid: _consultedJurisdictionId != null,
        onSelect: () => _showCitySelector(context),
      );
    }
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
        final values = await _loadCategoryCoverages(
          store,
          jurisdiction,
          instant,
        );
        if (mounted && _coverageKey == coverageKey) {
          _expirySubscription = _watchCoverageExpiry(
            ref,
            values.map((item) => item.ruleSet),
            instant,
            () => setState(() => _expiryRevision++),
          );
        }
        return values;
      });
    }
    return FutureBuilder<List<_CategoryCoverage>>(
      future: _coverageFuture,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState != ConnectionState.done;
        final coverages = !loading && snapshot.hasData
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
        final coverage = coverages.firstWhere(
          (item) => item.category == _category,
        );
        final summaryKey = (coverage.ruleSet, jurisdiction.id, _category, now);
        if (_summaryKey != summaryKey) {
          _summaryKey = summaryKey;
          final start = _weekStart(now);
          _week = _CityWeekData([
            for (var offset = 0; offset < 7; offset++)
              summarizeCityRestrictionDay(
                ruleSet: coverage.ruleSet,
                jurisdictionId: jurisdiction.id,
                category: _category,
                date: DateTime(start.year, start.month, start.day + offset),
              ),
          ]);
          _summary = _week.days[now.weekday - 1];
          _ruleSummary = summarizeCityRestrictionRules(
            ruleSet: coverage.ruleSet,
            jurisdictionId: jurisdiction.id,
            category: _category,
            date: now,
          );
          _showDates = !summarizeCityRestrictionRotation(
            ruleSet: coverage.ruleSet,
            jurisdictionId: jurisdiction.id,
            category: _category,
            date: now,
          ).isWeekly;
          // A dated exception earlier in this week still needs visible dates.
          _showDates =
              _showDates ||
              coverage.ruleSet.rules.any((rule) {
                final end = DateTime(start.year, start.month, start.day + 7);
                final overlaps =
                    rule.validFrom.isBefore(end) &&
                    (rule.validUntil == null ||
                        !rule.validUntil!.isBefore(start));
                return overlaps &&
                    (rule.weekdays == null || rule.dateParity != null);
              });
        }
        void openRules(bool sources) => _showCityRuleSheet(
          context,
          jurisdiction,
          coverage.ruleSet,
          _ruleSummary,
          sources: sources,
        );
        return _CityPage(
          jurisdiction: jurisdiction,
          configured: jurisdiction.id == global?.id,
          now: now,
          coverages: coverages,
          coverage: coverage,
          summary: _summary,
          ruleSummary: _ruleSummary,
          week: _week,
          showDates: _showDates,
          loading: loading,
          failed: snapshot.hasError,
          onSelectCity: () => _showCitySelector(context),
          onCategory: (category) => setState(() => _category = category),
          onRetry: () => setState(() {
            _coverageKey = null;
          }),
          onRules: () => openRules(false),
          onSources: () => openRules(true),
          onVehicles: () => _showCityVehicles(jurisdiction),
        );
      },
    );
  }

  Future<void> _showCityVehicles(RestrictionJurisdiction jurisdiction) async {
    final initialCoverage = _coverageFuture!;
    var firstLoad = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _CityVehiclesSheet(
        load: () async {
          final reuse = firstLoad;
          firstLoad = false;
          final now = ref.read(bogotaDateProvider);
          final instant = ref.read(currentInstantProvider);
          final store = ref.read(restrictionStoreProvider);
          await ref.read(bundledRestrictionsProvider.future);
          final coverages = reuse
              ? await initialCoverage
              : await _loadCategoryCoverages(store, jurisdiction, instant);
          if (!mounted) {
            return (
              items: <_VehicleShortcutData>[],
              coverages: <_CategoryCoverage>[],
            );
          }
          final vehicles = await ref.read(vehicleListProvider.future);
          final items = await _loadVehicleShortcuts(
            store,
            jurisdiction,
            vehicles,
            now,
            instant,
            coverages,
          );
          return (items: items, coverages: coverages);
        },
        onVehicle: (vehicle) {
          Navigator.of(sheetContext).pop();
          context.push(
            picoShellLocation(
              origin: PicoRouteOrigin.apps,
              vehicleId: vehicle.id,
              jurisdictionId: jurisdiction.id,
            ),
          );
        },
        onAdd: () {
          Navigator.of(sheetContext).pop();
          context.push(AppRoute.vehicleOnboarding.path);
        },
      ),
    );
  }

  Future<void> _showCitySelector(BuildContext context) async {
    final selectedId =
        _consultedJurisdictionId ?? widget.selectedJurisdictionId;
    final consulted = _findJurisdiction(widget.jurisdictions, selectedId);
    final selected = await _showPicoJurisdictionSelector(
      context: context,
      title: 'Consultar ciudad',
      runtimeJurisdictions: widget.jurisdictions,
      selectedJurisdictionId: selectedId,
      now: ref.read(currentInstantProvider),
      onAdopt:
          consulted != null && consulted.id != widget.selectedJurisdictionId
          ? () async {
              await ref
                  .read(locationStateProvider.notifier)
                  .selectManual(consulted);
              if (mounted) {
                setState(() => _consultedJurisdictionId = consulted.id);
              }
            }
          : null,
    );
    if (selected != null && mounted) {
      setState(() => _consultedJurisdictionId = selected);
    }
  }
}

Future<String?> _showPicoJurisdictionSelector({
  required BuildContext context,
  required String title,
  required List<RestrictionJurisdiction> runtimeJurisdictions,
  required String? selectedJurisdictionId,
  required DateTime now,
  Future<void> Function()? onAdopt,
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
        onAdopt: onAdopt,
      ),
    ),
  );
}

class _CitySelectorSheet extends ConsumerStatefulWidget {
  const _CitySelectorSheet({
    this.onAdopt,
    required this.title,
    required this.runtimeJurisdictions,
    required this.selectedJurisdictionId,
    required this.now,
  });

  final String title;
  final List<RestrictionJurisdiction> runtimeJurisdictions;
  final String? selectedJurisdictionId;
  final DateTime now;
  final Future<void> Function()? onAdopt;

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
            if (widget.onAdopt != null)
              _CityAdoptButton(onAdopt: widget.onAdopt!),
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
    required this.isTransient,
    required this.onSelect,
  });

  final RestrictionJurisdiction jurisdiction;
  final bool isTransient;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final cityLabel = _shortCityLabel(jurisdiction);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final longLabel = cityLabel.length >= 11;
    final dense = scale >= 1.8;
    final hideIcon = dense || (longLabel && scale > 1.2);
    final fontSize = longLabel ? 12.2 : 13.0;
    return Tooltip(
      message: cityLabel,
      child: Semantics(
        button: true,
        label: 'Cambiar ciudad de consulta. Ciudad actual: $cityLabel',
        child: Material(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(24),
          elevation: 1,
          child: InkWell(
            key: const ValueKey('pico-personal-change-city'),
            onTap: onSelect,
            borderRadius: BorderRadius.circular(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 136, minHeight: 34),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: dense ? AppSpacing.xs : AppSpacing.s,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!hideIcon) ...[
                      const Icon(
                        Icons.place_rounded,
                        color: AppColors.teal,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        cityLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.teal,
                          fontSize: fontSize,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (isTransient) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
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

String _shortCityLabel(RestrictionJurisdiction jurisdiction) {
  switch (jurisdiction.id) {
    case 'co-ant-medellin':
      return 'Medellín';
    case 'co-dc-bogota':
      return 'Bogotá';
    case 'co-vac-cali':
      return 'Cali';
    case 'co-cal-manizales':
      return 'Manizales';
    case 'co-san-bucaramanga':
      return 'Bucaramanga';
    case 'co-met-villavicencio':
      return 'Villavicencio';
  }

  var label = jurisdiction.name.trim();
  for (final separator in const ['·', '/', ',', ' - ']) {
    final index = label.indexOf(separator);
    if (index > 0) {
      label = label.substring(0, index).trim();
      break;
    }
  }
  return label.isEmpty ? jurisdiction.name : label;
}

// Explain only a rule actually selected by the same engine as the daily result.
// This runs with the daily view, not with the summary's minute/second repaint.
String? _personalRuleReason(
  RestrictionRuleSet rules,
  String jurisdictionId,
  VehicleProfile vehicle,
  RestrictionDayEvaluation today,
  DateTime date,
) {
  if (today.status != RestrictionDayStatus.restricted ||
      today.effectiveWindows.isEmpty) {
    return null;
  }
  final reasons = <String>{};
  for (final window in today.effectiveWindows) {
    final evaluation = const RestrictionEngine().evaluate(
      RestrictionContext(
        jurisdictionId: jurisdictionId,
        plate: vehicle.plate,
        vehicleKind: vehicle.kind,
        serviceType: vehicle.serviceType,
        registrationOrigin: RegistrationOrigin.unknown,
        localDateTime: DateTime(
          date.year,
          date.month,
          date.day,
        ).add(Duration(minutes: window.startMinute)),
        isHoliday: const ColombiaHolidayCalendar().isHoliday(date),
        coverageKnown: rules.coverageKnown,
        dataIsStale: rules.dataIsStale,
      ),
      rules.rules,
    );
    if (evaluation.status != RestrictionStatus.restricted) return null;
    final matched = rules.rules.where(
      (rule) => rule.id == evaluation.matchedRuleId,
    );
    if (matched.length != 1) return null;
    final rule = matched.single;
    final digit = plateDigit(vehicle.plate, rule.digitPosition);
    if (digit != null && rule.digits?.contains(digit) == true) {
      final position =
          rule.digitPosition == RestrictionDigitPosition.firstNumeric
          ? 'primer número'
          : 'último dígito';
      reasons.add('Aplica por el $position: $digit');
    } else {
      reasons.add('Restricción aplicable a este vehículo.');
    }
  }
  return reasons.length == 1
      ? reasons.single
      : 'Condiciones distintas según el tramo.';
}

class _PersonalHero extends StatelessWidget {
  const _PersonalHero({
    required this.vehicle,
    required this.jurisdiction,
    required this.isTransient,
    required this.onSelectCity,
  });

  final VehicleProfile vehicle;
  final RestrictionJurisdiction jurisdiction;
  final bool isTransient;
  final VoidCallback onSelectCity;

  @override
  Widget build(BuildContext context) {
    final name = vehicle.nickname?.trim();
    final make = vehicleMakeModel(vehicle);
    final title = name?.isNotEmpty == true
        ? name!
        : make.isNotEmpty
        ? make
        : 'Mi vehículo';
    return LayoutBuilder(
      key: const ValueKey('pico-personal-identity'),
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final frameHeight = scale > 1.3 ? 206.0 : 190.0;
        final totalHeight = frameHeight + 18;
        final titleTop = scale > 1.3 ? 58.0 : 56.0;
        final isMotorcycle = vehicle.kind == VehicleKind.motorcycle;
        final vehicleSlotTop = scale > 1.3 ? 116.0 : 94.0;
        final vehicleScale = isMotorcycle
            ? (scale > 1.3 ? 1.22 : 1.52)
            : (scale > 1.3 ? 1.24 : 1.55);
        final vehicleTranslateY = isMotorcycle
            ? (scale > 1.3 ? -10.0 : -14.0)
            : 0.0;
        final vehicleSlotBottom = isMotorcycle ? 0.0 : -6.0;
        const plateWidth = 86.0;
        return SizedBox(
          key: const ValueKey('pico-personal-hero-city'),
          width: constraints.maxWidth,
          height: totalHeight,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: frameHeight,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          'assets/pico/pico_personal_city_background_owner_v1.png',
                          fit: BoxFit.cover,
                          cacheWidth: (constraints.maxWidth * 2).round(),
                          errorBuilder: (_, _, _) => Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFFEAF6FF), Colors.white],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.02),
                                Colors.white.withValues(alpha: 0.72),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: titleTop,
                        left: AppSpacing.l,
                        right: AppSpacing.l,
                        child: Text(
                          title,
                          key: const ValueKey('pico-personal-vehicle-name'),
                          textAlign: TextAlign.left,
                          maxLines: 2,
                          overflow: TextOverflow.visible,
                          style: AppTextStyles.h2.copyWith(
                            color: AppColors.navy,
                            height: 1.08,
                          ),
                        ),
                      ),
                      Positioned(
                        top: AppSpacing.xs,
                        left: AppSpacing.xs,
                        child: SizedBox(
                          key: const ValueKey('pico-personal-hero-back'),
                          width: 48,
                          height: 48,
                          child: Center(
                            child: Material(
                              color: Colors.white.withValues(alpha: 0.88),
                              shape: const CircleBorder(),
                              elevation: 1,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => _goBack(context),
                                child: const Tooltip(
                                  message: 'Volver',
                                  child: SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: Icon(
                                      Icons.arrow_back_rounded,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: AppSpacing.xs,
                        right: AppSpacing.xs,
                        top: vehicleSlotTop,
                        bottom: vehicleSlotBottom,
                        child: SizedBox.expand(
                          key: const ValueKey('pico-personal-vehicle-art-slot'),
                          child: Transform.translate(
                            key: const ValueKey(
                              'pico-personal-vehicle-art-offset',
                            ),
                            offset: Offset(0, vehicleTranslateY),
                            child: Transform.scale(
                              key: const ValueKey(
                                'pico-personal-vehicle-art-scale',
                              ),
                              scale: vehicleScale,
                              child: VehicleVisualImage(
                                vehicle: vehicle,
                                cacheWidth: 560,
                                fallbackBuilder: (_) => Icon(
                                  vehicleIcon(vehicle),
                                  size: 104,
                                  color: vehicleAccent(vehicle),
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
              Positioned(
                top: frameHeight - 17,
                child: VehiclePlateBadge(
                  vehicle: vehicle,
                  compact: true,
                  compactWidth: plateWidth,
                  micro: true,
                ),
              ),
              Positioned(
                top: AppSpacing.s,
                right: AppSpacing.s,
                child: _SourceStrip(
                  jurisdiction: jurisdiction,
                  isTransient: isTransient,
                  onSelect: onSelectCity,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PersonalLowerModule extends StatelessWidget {
  const _PersonalLowerModule({
    super.key,
    required this.nextRestriction,
    required this.jurisdiction,
    required this.ruleSet,
    required this.vehicle,
    required this.now,
  });

  final _NextRestriction? nextRestriction;
  final RestrictionJurisdiction jurisdiction;
  final RestrictionRuleSet ruleSet;
  final VehicleProfile vehicle;
  final DateTime now;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('pico-personal-lower-module'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _PersonalCalendar(
        ruleSet: ruleSet,
        jurisdiction: jurisdiction,
        vehicle: vehicle,
        now: now,
      ),
      if (nextRestriction != null) ...[
        const SizedBox(height: AppSpacing.m),
        Text('Próxima restricción', style: AppTextStyles.bodyStrong),
        Text(
          '${_weekday(nextRestriction!.date)} ${_shortDate(nextRestriction!.date)}',
          key: const ValueKey('pico-next-restriction'),
          style: AppTextStyles.body.copyWith(fontSize: 14),
        ),
        Text(
          formatRestrictionWindows12(
            nextRestriction!.evaluation.effectiveWindows,
          ),
          key: const ValueKey('pico-next-restriction-windows'),
          style: AppTextStyles.body.copyWith(fontSize: 14),
        ),
      ],
      const SizedBox(height: AppSpacing.m),
      _PersonalSourceDetails(ruleSet: ruleSet),
    ],
  );
}

class _PersonalSourceDetails extends StatelessWidget {
  const _PersonalSourceDetails({required this.ruleSet});

  final RestrictionRuleSet ruleSet;

  @override
  Widget build(BuildContext context) {
    final verification = ruleSet.verifiedAt == null
        ? 'Por verificar'
        : 'Verificada ${_shortDate(ruleSet.verifiedAt!)}';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('pico-personal-source-row'),
        onTap: () => _showPersonalSourceSheet(context, ruleSet),
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.navy),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: AppTextStyles.body.copyWith(color: AppColors.navy),
                    children: [
                      TextSpan(
                        text: 'Fuente y vigencia',
                        style: AppTextStyles.bodyStrong,
                      ),
                      TextSpan(text: ' · $verification'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              const Icon(Icons.chevron_right_rounded, color: AppColors.navy),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonalCalendar extends StatefulWidget {
  const _PersonalCalendar({
    required this.ruleSet,
    required this.jurisdiction,
    required this.vehicle,
    required this.now,
  });

  final RestrictionRuleSet ruleSet;
  final RestrictionJurisdiction jurisdiction;
  final VehicleProfile vehicle;
  final DateTime now;

  @override
  State<_PersonalCalendar> createState() => _PersonalCalendarState();
}

class _PersonalCalendarState extends State<_PersonalCalendar> {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MonthCalendar(
          visibleMonth: _visibleMonth,
          now: widget.now,
          days: _evaluateVisibleMonth(),
          sourceLabel: _sourceLabel(widget.ruleSet),
          ruleSet: widget.ruleSet,
          jurisdiction: widget.jurisdiction,
          vehicle: widget.vehicle,
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

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.visibleMonth,
    required this.now,
    required this.days,
    required this.sourceLabel,
    required this.ruleSet,
    required this.jurisdiction,
    required this.vehicle,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime visibleMonth;
  final DateTime now;
  final List<VehicleMonthDayEvaluation> days;
  final String sourceLabel;
  final RestrictionRuleSet ruleSet;
  final RestrictionJurisdiction jurisdiction;
  final VehicleProfile vehicle;
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Column(
            children: [
              const _MonthWeekdayHeader(),
              const SizedBox(height: 4),
              GridView.builder(
                key: const ValueKey('pico-personal-month-grid'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cells.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 3,
                  crossAxisSpacing: 4,
                  childAspectRatio: 1.12,
                ),
                itemBuilder: (context, index) {
                  final item = cells[index];
                  if (item == null) {
                    return const _OutsideMonthCell();
                  }
                  return _MonthDayCell(
                    item: item,
                    isToday: _isSameDay(item.date, now),
                    sourceLabel: sourceLabel,
                    ruleSet: ruleSet,
                    jurisdiction: jurisdiction,
                    vehicle: vehicle,
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        const _CalendarLegendRow(),
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
        for (final label in const [
          'Lun',
          'Mar',
          'Mié',
          'Jue',
          'Vie',
          'Sáb',
          'Dom',
        ])
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

class _OutsideMonthCell extends StatelessWidget {
  const _OutsideMonthCell();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.55)),
      ),
    );
  }
}

class _CalendarLegendRow extends StatelessWidget {
  const _CalendarLegendRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('pico-calendar-legend'),
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        spacing: AppSpacing.m,
        runSpacing: AppSpacing.s,
        children: const [
          _CalendarLegendItem(
            label: 'Libre',
            status: RestrictionDayStatus.allowed,
          ),
          _CalendarLegendItem(
            label: 'Restricción',
            status: RestrictionDayStatus.restricted,
          ),
          _CalendarLegendItem(
            label: 'Por verificar',
            status: RestrictionDayStatus.unknown,
          ),
        ],
      ),
    );
  }
}

class _CalendarLegendItem extends StatelessWidget {
  const _CalendarLegendItem({required this.label, required this.status});

  final String label;
  final RestrictionDayStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CalendarStatusBadge(
          date: 'legend-$label',
          status: status,
          color: color,
          size: 14,
          iconSize: 9,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: AppTextStyles.body.copyWith(fontSize: 14)),
      ],
    );
  }
}

class _MonthDayCell extends StatelessWidget {
  const _MonthDayCell({
    required this.item,
    required this.isToday,
    required this.sourceLabel,
    required this.ruleSet,
    required this.jurisdiction,
    required this.vehicle,
  });

  final VehicleMonthDayEvaluation item;
  final bool isToday;
  final String sourceLabel;
  final RestrictionRuleSet ruleSet;
  final RestrictionJurisdiction jurisdiction;
  final VehicleProfile vehicle;

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
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('pico-month-day-${_date(item.date)}'),
          onTap: () => _showMonthDayDetail(
            context,
            item,
            sourceLabel,
            ruleSet,
            jurisdiction,
            vehicle,
          ),
          child: Container(
            constraints: const BoxConstraints(minHeight: 36),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isToday ? AppColors.navy : color.withValues(alpha: 0.28),
                width: isToday ? 2 : 1,
              ),
            ),
            child: Stack(
              children: [
                Align(
                  alignment: const Alignment(0, -0.35),
                  child: Text(
                    '${item.date.day}',
                    style: AppTextStyles.bodyStrong.copyWith(
                      fontSize: 16,
                      color: restricted ? AppColors.red : AppColors.navy,
                    ),
                  ),
                ),
                Positioned(
                  right: 4,
                  bottom: 1,
                  child: _CalendarStatusBadge(
                    date: _date(item.date),
                    status: status,
                    color: color,
                    size: 8.5,
                    iconSize: 5.5,
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

class _CalendarStatusBadge extends StatelessWidget {
  const _CalendarStatusBadge({
    required this.date,
    required this.status,
    required this.color,
    this.size = 17,
    this.iconSize = 12.5,
  });

  final String date;
  final RestrictionDayStatus status;
  final Color color;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final icon = switch (status) {
      RestrictionDayStatus.allowed => Icons.check_rounded,
      RestrictionDayStatus.restricted => Icons.remove_rounded,
      RestrictionDayStatus.unknown ||
      RestrictionDayStatus.stale => Icons.question_mark_rounded,
    };
    return Container(
      key: ValueKey('pico-month-status-icon-$date-${status.name}'),
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: iconSize),
    );
  }
}

void _showMonthDayDetail(
  BuildContext context,
  VehicleMonthDayEvaluation item,
  String sourceLabel,
  RestrictionRuleSet ruleSet,
  RestrictionJurisdiction jurisdiction,
  VehicleProfile vehicle,
) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final evaluation = item.evaluation;
      final color = _statusColor(evaluation.status);
      final reason = _personalRuleReason(
        ruleSet,
        jurisdiction.id,
        vehicle,
        evaluation,
        item.date,
      );
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
                reason ?? _detailBasis(evaluation.status),
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

void _showPersonalSourceSheet(
  BuildContext context,
  RestrictionRuleSet ruleSet,
) {
  final source = _httpsSource(ruleSet);
  final validities = ruleSet.rules
      .map((rule) => _validity(rule.validFrom, rule.validUntil))
      .toSet();
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          key: const ValueKey('pico-personal-source-sheet'),
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
              Text('Fuente y vigencia', style: AppTextStyles.h2),
              const SizedBox(height: AppSpacing.s),
              Text(_sourceLabel(ruleSet), style: AppTextStyles.bodyStrong),
              if (ruleSet.verifiedAt != null)
                Text('Última verificación: ${_shortDate(ruleSet.verifiedAt!)}'),
              if (validities.isNotEmpty)
                Text('Vigencia publicada: ${validities.join('; ')}'),
              if (ruleSet.staleAfter != null)
                Text('Revisión de datos: ${_shortDate(ruleSet.staleAfter!)}'),
              const SizedBox(height: AppSpacing.s),
              const Text(
                'La rotación puede cambiar por festivos o medidas especiales. Consulta la fuente oficial antes de decidir.',
              ),
              if (source != null) ...[
                const SizedBox(height: AppSpacing.s),
                TextButton.icon(
                  key: const ValueKey('pico-personal-source-open'),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final opened = await launchUrl(Uri.parse(source));
                    if (!opened) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('No pudimos abrir la fuente.'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text('Abrir sitio · ${Uri.parse(source).host}'),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
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
  for (final vehicle in vehicles) {
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

String _dailyStatusText(RestrictionDayStatus status) {
  return switch (status) {
    RestrictionDayStatus.restricted => 'Con pico y placa',
    RestrictionDayStatus.allowed => 'Sin pico y placa',
    RestrictionDayStatus.unknown => 'Por verificar',
    RestrictionDayStatus.stale => 'Datos vencidos',
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

String _cityHeroVehicleAsset(PicoVehicleCategory category) {
  return switch (category) {
    PicoVehicleCategory.cars => 'assets/vehicles/veh_car_chevrolet_01.webp',
    PicoVehicleCategory.motorcycles => 'assets/vehicles/veh_moto_akt_01.webp',
    PicoVehicleCategory.taxis => 'assets/vehicles/veh_car_taxi_01.webp',
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

String _digitsOrRule(CityRestrictionDaySummary summary) {
  if (summary.restrictedDigits.isEmpty) {
    return summary.ruleLabel;
  }
  return summary.restrictedDigits.map((digit) => '$digit').join(' · ');
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
