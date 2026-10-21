import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_tokens.dart';
import '../../garage/data/vehicle_profile.dart';
import '../../garage/presentation/vehicle_display.dart';
import '../../garage/presentation/vehicle_plate_badge.dart';
import '../../onboarding/data/registration_city_catalog.dart';
import '../../trip/data/trip_municipality_catalog.dart';
import '../../vehicle_status/platform/external_launcher.dart';
import '../../visual_assets/presentation/visual_asset_widgets.dart';
import '../data/territorial_catalog.dart';

part 'comparendos_widgets.dart';
part 'comparendos_selectors.dart';

final comparendosLastCheckedProvider = FutureProvider.family<String?, String>(
  (ref, vehicleId) =>
      ref.watch(appPreferencesProvider).getString(_lastCheckedKey(vehicleId)),
);

class ComparendosScreen extends ConsumerStatefulWidget {
  const ComparendosScreen({this.vehicleId, super.key});
  final String? vehicleId;
  @override
  ConsumerState<ComparendosScreen> createState() => _ComparendosScreenState();
}

class _ComparendosScreenState extends ConsumerState<ComparendosScreen> {
  String? _vehicleId;
  TripMunicipality? _chosenCity;
  bool _territorialManuallyChosen = false;
  String? _authorityId;
  String? _entryJurisdiction;
  bool _entryCityResolved = false;
  final _savingIds = <String>{};

  @override
  void initState() {
    super.initState();
    _vehicleId = _nonEmpty(widget.vehicleId);
    ref.listenManual(selectedPicoJurisdictionIdProvider, (_, next) {
      if (!_entryCityResolved && next.hasValue) {
        setState(() {
          _entryJurisdiction = next.value;
          _entryCityResolved = true;
        });
      }
    }, fireImmediately: true);
  }

  @override
  void didUpdateWidget(covariant ComparendosScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.vehicleId != oldWidget.vehicleId) {
      _vehicleId = _nonEmpty(widget.vehicleId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(vehicleListProvider);
    final favorite = _vehicleId != null
        ? const AsyncValue<VehicleProfile?>.data(null)
        : ref.watch(activeVehicleProvider);
    return Scaffold(
      appBar: AppBar(
        foregroundColor: AppColors.navy,
        backgroundColor: AppColors.background,
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoute.apps.path);
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text(
          'Comparendos',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        top: false,
        child: vehicles.when(
          loading: () => const _LoadingPane(),
          error: (_, _) => _LoadError(
            message: 'No pudimos cargar tus vehículos.',
            onRetry: () => ref.invalidate(vehicleListProvider),
          ),
          data: (items) => favorite.when(
            loading: () => const _LoadingPane(),
            error: (_, _) => _LoadError(
              message: 'No pudimos cargar el vehículo favorito.',
              onRetry: () => ref.invalidate(activeVehicleProvider),
              onChoose: items.isEmpty ? null : _chooseVehicle,
            ),
            data: (active) {
              // Freeze the initial vehicle for this visit, without changing favorite.
              _vehicleId ??= active?.id;
              final vehicle = items
                  .where((v) => v.id == _vehicleId)
                  .firstOrNull;
              if (vehicle == null) {
                return _NoVehiclePane(
                  hasVehicles: items.isNotEmpty,
                  onChoose: _chooseVehicle,
                );
              }
              return _content(vehicle);
            },
          ),
        ),
      ),
    );
  }

  Widget _content(VehicleProfile vehicle) {
    final municipalities = ref.watch(tripMunicipalityCatalogProvider);
    final authorities = ref.watch(territorialCatalogProvider);
    final cityContext = ref.watch(selectedPicoJurisdictionIdProvider);
    final lastChecked = ref.watch(comparendosLastCheckedProvider(vehicle.id));
    final date = _formatBogotaDate(ref.watch(bogotaNowProvider));
    final city = _territorialManuallyChosen
        ? _chosenCity
        : municipalities.asData?.value.records
              .where((m) => m.code == _entryCityCodes[_entryJurisdiction])
              .firstOrNull;
    final cityAuthorities = city == null
        ? <TerritorialAuthority>[]
        : authorities.asData?.value.forMunicipality(city.code) ??
              <TerritorialAuthority>[];
    final authority =
        authorities.asData?.value.authorities
            .where((a) => a.id == _authorityId)
            .firstOrNull ??
        (cityAuthorities.length == 1 ? cityAuthorities.single : null);
    final loadingCity =
        !_territorialManuallyChosen &&
        (municipalities.isLoading ||
            (!_entryCityResolved && cityContext.isLoading));
    final cityError =
        !_territorialManuallyChosen &&
        (municipalities.hasError ||
            (!_entryCityResolved && cityContext.hasError));
    return SingleChildScrollView(
      key: const ValueKey('comparendos-screen'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _VehicleSummary(
                vehicle: vehicle,
                onCopyPlate: () => _copyPlate(vehicle.plate),
                onChoose: _chooseVehicle,
              ),
              const SizedBox(height: 12),
              _SimitAction(
                onTap: () => _openExternal(
                  simitConsultationUrl,
                  'No pudimos abrir SIMIT.',
                ),
              ),
              const SizedBox(height: 12),
              _TerritorialConsultation(
                city: city,
                authority: authority,
                multipleAuthorities: cityAuthorities.length > 1,
                temporary: _territorialManuallyChosen,
                loading: loadingCity || authorities.isLoading,
                error: cityError || authorities.hasError,
                onRetry: () {
                  ref.invalidate(tripMunicipalityCatalogProvider);
                  ref.invalidate(territorialCatalogProvider);
                  if (!_entryCityResolved) {
                    ref.invalidate(selectedPicoJurisdictionIdProvider);
                  }
                },
                onChoose: _chooseCity,
                onChooseAuthority: () => _chooseAuthority(cityAuthorities),
                onOpen: (url) => _openExternal(
                  url,
                  'No pudimos abrir la autoridad de tránsito.',
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Registro personal',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 8),
              lastChecked.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Cargando registro personal…'),
                ),
                error: (_, _) => _LoadError(
                  message: 'No pudimos leer tu anotación.',
                  onRetry: () => ref.invalidate(
                    comparendosLastCheckedProvider(vehicle.id),
                  ),
                ),
                data: (checked) => _CheckedAction(
                  checked: checked == date,
                  saving: _savingIds.contains(vehicle.id),
                  onTap: () => _markCheckedToday(vehicle.id),
                ),
              ),
              if (lastChecked.asData?.value case final checked?) ...[
                const SizedBox(height: 6),
                Text(
                  'Última consulta anotada: $checked',
                  key: const ValueKey('comparendos-last-checked'),
                  style: const TextStyle(fontSize: 14),
                ),
              ],
              const SizedBox(height: 12),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 22, color: AppColors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Los resultados se consultan en el portal oficial. PicoRadar no obtiene tus resultados.',
                      key: ValueKey('comparendos-local-note'),
                      style: TextStyle(fontSize: 14, color: AppColors.navy),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _chooseVehicle() async {
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useRootNavigator: true,
      builder: (_) => const _VehicleChooser(),
    );
    if (mounted && id != null) setState(() => _vehicleId = id);
  }

  Future<void> _chooseCity() async {
    final result = await showModalBottomSheet<_TerritorialSelection>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useRootNavigator: true,
      builder: (_) => const _CityChooser(),
    );
    if (mounted && result != null) {
      setState(() {
        _chosenCity = result.city;
        _authorityId = result.authorityId;
        _territorialManuallyChosen = true;
      });
    }
  }

  Future<void> _chooseAuthority(List<TerritorialAuthority> authorities) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useRootNavigator: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Seleccionar autoridad', style: AppTextStyles.h2),
              for (final authority in authorities)
                ListTile(
                  title: Text(authority.name),
                  subtitle: Text(authority.platformName),
                  minVerticalPadding: 12,
                  onTap: () => Navigator.pop(context, authority.id),
                ),
            ],
          ),
        ),
      ),
    );
    if (mounted && id != null) setState(() => _authorityId = id);
  }

  Future<void> _copyPlate(String plate) async {
    try {
      await Clipboard.setData(ClipboardData(text: plate));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Placa copiada.')));
      }
    } catch (_) {
      _failure('No pudimos copiar la placa.', () => _copyPlate(plate));
    }
  }

  Future<void> _openExternal(String url, String message) async {
    try {
      if (isSafeOfficialPortalUrl(url) &&
          await ref.read(externalLauncherProvider).openExternal(url)) {
        return;
      }
    } catch (_) {
      // The visible retry below also handles platform launcher failures.
    }
    _failure(message, () => _openExternal(url, message));
  }

  Future<void> _markCheckedToday(String id) async {
    if (_savingIds.contains(id)) return;
    final today = _formatBogotaDate(ref.read(bogotaNowProvider));
    if (ref.read(comparendosLastCheckedProvider(id)).asData?.value == today) {
      return;
    }
    setState(() => _savingIds.add(id));
    try {
      await ref
          .read(appPreferencesProvider)
          .setString(_lastCheckedKey(id), today);
      if (mounted) ref.invalidate(comparendosLastCheckedProvider(id));
    } catch (_) {
      _failure('No pudimos guardar tu anotación.', () => _markCheckedToday(id));
    } finally {
      if (mounted) setState(() => _savingIds.remove(id));
    }
  }

  void _failure(String message, VoidCallback retry) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(label: 'Reintentar', onPressed: retry),
      ),
    );
  }
}

// Suggestions from the saved consultation context, NOT territorial jurisdiction.
const _entryCityCodes = {
  'co-ant-medellin': '05001',
  'co-dc-bogota': '11001',
  'co-vac-cali': '76001',
  'co-cal-manizales': '17001',
  'co-san-bucaramanga': '68001',
  'co-met-villavicencio': '50001',
  'co-bol-cartagena': '13001',
  'co-qui-armenia': '63001',
  'co-tol-ibague': '73001',
  'co-nds-cucuta': '54001',
  'co-mag-santa-marta': '47001',
  'co-ris-pereira': '66001',
  'co-atl-barranquilla': '08001',
  'co-nar-pasto': '52001',
  'co-cor-monteria': '23001',
  'co-cau-popayan': '19001',
};
String? _nonEmpty(String? value) =>
    value?.trim().isNotEmpty == true ? value!.trim() : null;
String _lastCheckedKey(String id) => 'comparendos.last_checked.$id';
String _formatBogotaDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String _vehicleDisplayName(VehicleProfile vehicle) =>
    _nonEmpty(vehicle.nickname) ??
    _nonEmpty(vehicleMakeModel(vehicle)) ??
    'Mi vehículo';
