import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../app/theme/app_tokens.dart';
import '../../garage/data/vehicle_profile.dart';
import '../../pico_placa/domain/bogota_time.dart';
import '../../vehicle_status/platform/external_launcher.dart';
import '../application/route_geometry_index.dart';
import '../application/trip_route_association_resolver.dart';
import '../application/trip_route_associations.dart';
import '../application/trip_services.dart';
import '../application/trip_tile_config.dart';
import '../data/toll_inventory.dart';
import '../domain/trip_draft.dart';
import '../data/trip_municipality_catalog.dart';
import '../data/trip_plan_client.dart';
import '../data/trip_route_preview_data.dart';
import '../domain/trip_plan.dart';
import 'trip_plan_result.dart';
import 'trip_route_preview_map.dart';
import 'trip_screen_content.dart';

final tripRouteMapConfigProvider = Provider<TripRouteMapConfig>((ref) {
  const tilesApproved = bool.fromEnvironment(
    'PICORADAR_TRIP_MAP_TILES_APPROVED',
  );
  const tileUrlTemplate = String.fromEnvironment(
    'PICORADAR_TRIP_TILE_URL_TEMPLATE',
  );
  const tileUserAgent = String.fromEnvironment(
    'PICORADAR_TRIP_TILE_USER_AGENT',
  );
  const tileAttribution = String.fromEnvironment(
    'PICORADAR_TRIP_TILE_ATTRIBUTION',
  );
  final resolved = resolveTripTileConfig(
    approved: tilesApproved,
    urlTemplate: tileUrlTemplate,
    userAgent: tileUserAgent,
    attribution: tileAttribution,
  );
  return TripRouteMapConfig(
    tileUrlTemplate: resolved.urlTemplate,
    attributionLabel: resolved.attribution,
    userAgentPackageName: resolved.userAgent,
    approved: resolved.enabled,
  );
});

final tripRouteAssociationResolverProvider =
    Provider<TripRouteAssociationResolver>(
      (ref) => CachedTripRouteAssociationResolver(),
    );

class TripScreen extends ConsumerStatefulWidget {
  const TripScreen({super.key});

  @override
  ConsumerState<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends ConsumerState<TripScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _resultsAnchorKey = GlobalKey();
  final _mapAnchorKey = GlobalKey();
  final _originFocusNode = FocusNode(debugLabel: 'trip-origin-focus');
  final _destinationFocusNode = FocusNode(debugLabel: 'trip-destination-focus');
  final _vehicleFocusNode = FocusNode(debugLabel: 'trip-vehicle-focus');
  final _timeFocusNode = FocusNode(debugLabel: 'trip-time-focus');
  final _resultsFocusNode = FocusNode(debugLabel: 'trip-results-focus');
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _random = Random.secure();
  VehicleProfile? _lastVehicle;
  var _selectedDate = DateUtils.dateOnly(bogotaWallClock(DateTime.now()));
  int? _departureMinute;
  var _vehicleConfiguration = TripVehicleConfiguration.standardTwoAxle;
  var _vehicleCategorySource = TripVehicleCategorySource.defaultStandard;
  String? _originError;
  String? _destinationError;
  String? _timeError;
  String? _vehicleError;
  String? _planError;
  CancelToken? _cancelToken;
  TripPlanRequest? _request;
  TripPlan? _plan;
  String? _selectedRouteId;
  var _generation = 0;
  var _completedChecklist = <TripChecklistItem>{};
  var _draftRestored = false;
  var _draftLoadComplete = false;
  Object? _draftLoadError;
  String? _selectedVehicleId;
  String? _restoredVehicleId;
  TripMunicipality? _originMunicipality;
  TripMunicipality? _destinationMunicipality;
  String? _revealedRequestId;
  var _userScrollRevision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_restoreDraft());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted && state == AppLifecycleState.resumed) {
      ref.invalidate(tripInstantRestrictionProvider);
      ref.invalidate(tripRestrictionProvider);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _invalidatePlan();
    _scrollController.dispose();
    _originFocusNode.dispose();
    _destinationFocusNode.dispose();
    _vehicleFocusNode.dispose();
    _timeFocusNode.dispose();
    _resultsFocusNode.dispose();
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeVehicle = ref.watch(activeVehicleProvider);
    final vehicles = ref.watch(vehicleListProvider);
    final municipalities = ref.watch(tripMunicipalityCatalogProvider);

    return Scaffold(
      body: SafeArea(
        child: !_draftLoadComplete
            ? _draftLoadError == null
                  ? const _LoadingPane()
                  : _DraftLoadErrorPane(onRetry: _retryDraftLoad)
            : activeVehicle.when(
                data: (active) => vehicles.when(
                  data: (items) => municipalities.when(
                    data: (catalog) => _buildContent(
                      activeVehicle: active,
                      vehicles: items,
                      catalog: catalog,
                    ),
                    loading: () => const _LoadingPane(),
                    error: (error, stackTrace) => const _ErrorPane(
                      message: 'No pudimos cargar los municipios.',
                    ),
                  ),
                  loading: () => const _LoadingPane(),
                  error: (error, stackTrace) => const _ErrorPane(
                    message: 'No pudimos cargar los vehículos.',
                  ),
                ),
                loading: () => const _LoadingPane(),
                error: (error, stackTrace) => const _ErrorPane(
                  message: 'No pudimos cargar el vehículo activo.',
                ),
              ),
      ),
    );
  }

  Widget _buildContent({
    required VehicleProfile? activeVehicle,
    required List<VehicleProfile> vehicles,
    required TripMunicipalityCatalog catalog,
  }) {
    final selectedVehicle = _selectedVehicle(vehicles, activeVehicle);
    // Provider updates can remove or edit a vehicle while a request is pending.
    if (!identical(_lastVehicle, selectedVehicle)) {
      _invalidatePlan();
      _vehicleConfiguration = TripVehicleConfiguration.standardTwoAxle;
      _vehicleCategorySource = TripVehicleCategorySource.defaultStandard;
      _lastVehicle = selectedVehicle;
    }
    final origin =
        _originMunicipality ?? catalog.findExact(_originController.text);
    final destination =
        _destinationMunicipality ??
        catalog.findExact(_destinationController.text);
    final date = DateUtils.dateOnly(_selectedDate);
    final departureUtc = _departureMinute == null
        ? _request?.departureMode == TripDepartureMode.now
              ? _request?.departureUtc
              : null
        : bogotaScheduledTime(
            date: date,
            minuteOfDay: _departureMinute!,
          ).toUtc();
    final currentPlan = _plan;
    final currentRequest = _request;
    final selectedRoute = currentPlan?.routes
        .where((route) => route.id == _selectedRouteId)
        .firstOrNull;
    final tollInventory = selectedRoute == null
        ? null
        : ref.watch(tripTollInventoryProvider);
    final cameraSnapshot = selectedRoute == null
        ? null
        : ref.watch(tripCameraPackSnapshotProvider);
    final originRestriction = ref.watch(
      tripRestrictionProvider((
        municipality: origin,
        vehicle: selectedVehicle,
        date: date,
      )),
    );
    final destinationRestriction = ref.watch(
      tripRestrictionProvider((
        municipality: destination,
        vehicle: selectedVehicle,
        date: date,
      )),
    );
    final requestedVehicleId = _selectedVehicleId ?? _restoredVehicleId;
    final missingRestoredVehicle =
        requestedVehicleId != null &&
        !vehicles.any((vehicle) => vehicle.id == requestedVehicleId);

    return TripContent(
      scrollController: _scrollController,
      resultsAnchorKey: _resultsAnchorKey,
      resultsFocusNode: _resultsFocusNode,
      originFocusNode: _originFocusNode,
      destinationFocusNode: _destinationFocusNode,
      vehicleFocusNode: _vehicleFocusNode,
      timeFocusNode: _timeFocusNode,
      onUserScroll: () => _userScrollRevision++,
      formKey: _formKey,
      originController: _originController,
      destinationController: _destinationController,
      selectedDate: date,
      departureMinute: _departureMinute,
      originError: _originError,
      destinationError: _destinationError,
      timeError: _timeError,
      vehicleError: _vehicleError,
      vehicleConfiguration: _vehicleConfiguration,
      onVehicleConfigurationChanged: (value) => setState(() {
        _invalidatePlan();
        _vehicleConfiguration = value;
        _vehicleCategorySource = TripVehicleCategorySource.userSelected;
        _vehicleError = null;
      }),
      onTimeChanged: (value) => setState(() {
        _invalidatePlan();
        _departureMinute = value;
        _timeError = null;
      }),
      isPlanning: _cancelToken != null,
      planError: _planError,
      onPreview: () => _preview(catalog, selectedVehicle),
      onCancelPreview: () => setState(_invalidatePlan),
      planResult:
          currentPlan != null && currentRequest != null && selectedRoute != null
          ? _TripPlanWithLocalData(
              request: currentRequest,
              plan: currentPlan,
              route: selectedRoute,
              onRouteSelected: (id) => setState(() => _selectedRouteId = id),
              onSource: _openSource,
              mapAnchorKey: _mapAnchorKey,
              onViewMap: _scrollToMap,
              tollInventory: tollInventory!,
              cameraSnapshot: cameraSnapshot!,
              mapConfig: ref.watch(tripRouteMapConfigProvider),
              resolver: ref.watch(tripRouteAssociationResolverProvider),
              onRetryTolls: () => ref.invalidate(tripTollInventoryProvider),
              onRetryCameras: () =>
                  ref.invalidate(tripCameraPackSnapshotProvider),
            )
          : null,
      instantRestrictions: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (departureUtc != null)
            TripInstantEndpoint(
              key: const ValueKey('trip-origin-instant'),
              label: 'Origen / salida',
              instantUtc: departureUtc,
              onSource: _openSource,
              evaluation: ref.watch(
                tripInstantRestrictionProvider((
                  municipality: origin,
                  vehicle: selectedVehicle,
                  instantUtc: departureUtc,
                )),
              ),
            )
          else
            const Text(
              'Origen / salida: se muestran las reglas y ventanas del día; no hay veredicto para una hora exacta.',
            ),
          const SizedBox(height: AppSpacing.m),
          if (selectedRoute != null &&
              currentRequest != null &&
              currentRequest.departureUtc != null)
            TripInstantEndpoint(
              key: ValueKey('trip-destination-instant-${selectedRoute.id}'),
              label: 'Destino / llegada aproximada',
              instantUtc: selectedRoute.arrivalUtc(
                currentRequest.departureUtc!,
              ),
              onSource: _openSource,
              evaluation: ref.watch(
                tripInstantRestrictionProvider((
                  municipality: currentRequest.destination,
                  vehicle: currentRequest.vehicle,
                  instantUtc: selectedRoute.arrivalUtc(
                    currentRequest.departureUtc!,
                  ),
                )),
              ),
            )
          else if (selectedRoute != null &&
              currentRequest?.departureMode == TripDepartureMode.dateOnly)
            const Text(
              'Destino / llegada: la fecha real depende de la ruta y puede cambiar al día siguiente.',
            )
          else
            const Text(
              'Destino / llegada: no disponible hasta obtener una ruta.',
            ),
          const SizedBox(height: AppSpacing.s),
          const Text(
            'Se evalúan solo los dos extremos. La llegada al destino no indica la hora de entrada a una zona restringida. Revisa los horarios: la llegada es aproximada.',
          ),
        ],
      ),
      completedChecklist: _completedChecklist,
      vehicles: vehicles,
      selectedVehicle: missingRestoredVehicle ? null : selectedVehicle,
      restoredVehicleMissing: missingRestoredVehicle,
      originSuggestions: _originMunicipality == null
          ? catalog.search(_originController.text)
          : const [],
      destinationSuggestions: _destinationMunicipality == null
          ? catalog.search(_destinationController.text)
          : const [],
      originRestriction: originRestriction,
      destinationRestriction: destinationRestriction,
      draftRestored: _draftRestored,
      localConsultationStarted:
          currentRequest != null ||
          (_planError != null &&
              _originError == null &&
              _destinationError == null &&
              _vehicleError != null),
      localDepartureLabel: currentRequest == null
          ? null
          : switch (currentRequest.departureMode) {
              TripDepartureMode.now => 'Salida: ahora',
              TripDepartureMode.dateOnly =>
                'Salida: Hora opcional · Sin definir',
              TripDepartureMode.specified =>
                'Salida: ${tripInstantLabel(currentRequest.departureUtc!)}',
            },
      onVehicleChanged: (id) => setState(() {
        _invalidatePlan();
        _vehicleConfiguration = TripVehicleConfiguration.standardTwoAxle;
        _vehicleCategorySource = TripVehicleCategorySource.defaultStandard;
        _vehicleError = null;
        _selectedVehicleId = id;
        _restoredVehicleId = null;
      }),
      onOriginChanged: (_) => setState(() {
        _invalidatePlan();
        _originMunicipality = null;
        _originError = null;
      }),
      onDestinationChanged: (_) => setState(() {
        _invalidatePlan();
        _destinationMunicipality = null;
        _destinationError = null;
      }),
      onOriginSelected: (municipality) => setState(() {
        _invalidatePlan();
        _originError = null;
        _originMunicipality = municipality;
        _originController.text = municipality.displayName;
      }),
      onDestinationSelected: (municipality) => setState(() {
        _invalidatePlan();
        _destinationError = null;
        _destinationMunicipality = municipality;
        _destinationController.text = municipality.displayName;
      }),
      onSwapLocations: _swapLocations,
      onDateChanged: (value) => setState(() {
        _invalidatePlan();
        _selectedDate = value;
        _timeError = null;
      }),
      onChecklistChanged: _setChecklistItem,
      onSaveDraft: () => _saveDraft(
        selectedVehicle,
        vehicleSelectionRequired: missingRestoredVehicle,
      ),
      onDeleteDraft: _deleteDraft,
      onGoogleMaps: _openGoogleMaps,
      onWaze: _openWaze,
      onInvias: _openInvias,
    );
  }

  VehicleProfile? _selectedVehicle(
    List<VehicleProfile> vehicles,
    VehicleProfile? activeVehicle,
  ) {
    final requestedId = _selectedVehicleId ?? _restoredVehicleId;
    if (requestedId != null) {
      for (final vehicle in vehicles) {
        if (vehicle.id == requestedId) {
          return vehicle;
        }
      }
      return null;
    }
    if (activeVehicle == null) {
      return null;
    }
    for (final vehicle in vehicles) {
      if (vehicle.id == activeVehicle.id) {
        return vehicle;
      }
    }
    return null;
  }

  Future<void> _restoreDraft() async {
    final store = ref.read(tripDraftStoreProvider);
    TripDraft? draft;
    try {
      draft = await store.loadDraft();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _draftLoadError = error;
        _draftLoadComplete = false;
      });
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _draftLoadError = null;
      _draftLoadComplete = true;
      if (draft == null) {
        return;
      }
      _originController.text = draft.origin;
      _destinationController.text = draft.destination;
      _selectedDate = DateUtils.dateOnly(draft.date);
      _departureMinute = draft.departureMinute;
      _vehicleConfiguration = draft.vehicleConfiguration;
      _vehicleCategorySource = draft.vehicleCategorySource;
      _completedChecklist = draft.completedChecklist;
      _draftRestored = true;
      _restoredVehicleId = draft.activeVehicleId;
      _selectedVehicleId = null;
      _originMunicipality = null;
      _destinationMunicipality = null;
    });
  }

  void _retryDraftLoad() {
    setState(() {
      _draftLoadError = null;
      _draftLoadComplete = false;
    });
    unawaited(_restoreDraft());
  }

  Future<void> _saveDraft(
    VehicleProfile? activeVehicle, {
    required bool vehicleSelectionRequired,
  }) async {
    if (vehicleSelectionRequired) {
      _showSnackBar('Selecciona un vehículo para este viaje.');
      return;
    }
    if (!_validateTripFields()) {
      return;
    }
    final store = ref.read(tripDraftStoreProvider);
    await store.saveDraft(_draft(activeVehicle?.id));
    if (!mounted) {
      return;
    }
    _showSnackBar('Borrador guardado en este dispositivo.');
  }

  Future<void> _deleteDraft() async {
    final store = ref.read(tripDraftStoreProvider);
    final savedDraft = await store.loadDraft();
    if (!mounted) {
      return;
    }
    if (savedDraft != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Borrar borrador'),
          content: const Text(
            'Se eliminará el borrador guardado en este dispositivo.',
          ),
          actions: [
            TextButton(
              key: const ValueKey('trip-delete-cancel'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const ValueKey('trip-delete-confirm'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Borrar'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) {
        return;
      }
    }
    await store.deleteDraft();
    if (!mounted) {
      return;
    }
    setState(() {
      _invalidatePlan();
      _departureMinute = null;
      _vehicleConfiguration = TripVehicleConfiguration.standardTwoAxle;
      _vehicleCategorySource = TripVehicleCategorySource.defaultStandard;
      _originError = null;
      _destinationError = null;
      _timeError = null;
      _vehicleError = null;
      _originController.clear();
      _destinationController.clear();
      _selectedDate = DateUtils.dateOnly(bogotaWallClock(DateTime.now()));
      _completedChecklist = {};
      _draftRestored = false;
      _selectedVehicleId = null;
      _restoredVehicleId = null;
      _originMunicipality = null;
      _destinationMunicipality = null;
    });
    _showSnackBar('Borrador eliminado.');
  }

  Future<void> _openGoogleMaps() async {
    if (!_validateTripFields()) {
      return;
    }
    final navigation = ref.read(tripExternalNavigationProvider);
    var opened = false;
    try {
      opened = await navigation.openGoogleMaps(
        origin: _plan == null
            ? _originController.text
            : '${_plan!.origin.latitude},${_plan!.origin.longitude}',
        destination: _plan == null
            ? _destinationController.text
            : '${_plan!.destination.latitude},${_plan!.destination.longitude}',
      );
    } catch (_) {
      opened = false;
    }
    if (!mounted || opened) {
      return;
    }
    _showSnackBar('No pudimos abrir Google Maps.');
  }

  Future<void> _openWaze() async {
    if (!_validateTripFields()) {
      return;
    }
    final navigation = ref.read(tripExternalNavigationProvider);
    var opened = false;
    try {
      opened = await navigation.openWaze(
        destination: _plan == null
            ? _destinationController.text
            : '${_plan!.destination.latitude},${_plan!.destination.longitude}',
      );
    } catch (_) {
      opened = false;
    }
    if (!mounted || opened) {
      return;
    }
    _showSnackBar('No pudimos abrir Waze.');
  }

  Future<void> _openInvias() async {
    final navigation = ref.read(tripExternalNavigationProvider);
    var opened = false;
    try {
      opened = await navigation.openInviasRoadStatus();
    } catch (_) {
      opened = false;
    }
    if (!mounted || opened) {
      return;
    }
    _showSnackBar('No pudimos abrir INVÍAS.');
  }

  void _setChecklistItem(TripChecklistItem item, bool selected) {
    setState(() {
      _completedChecklist = {..._completedChecklist};
      if (selected) {
        _completedChecklist.add(item);
      } else {
        _completedChecklist.remove(item);
      }
    });
  }

  bool _validateTripFields() {
    return _formKey.currentState?.validate() ?? false;
  }

  TripDraft _draft(String? activeVehicleId) {
    return TripDraft(
      origin: _originController.text,
      destination: _destinationController.text,
      date: _selectedDate,
      departureMinute: _departureMinute,
      vehicleConfiguration: _vehicleConfiguration,
      vehicleCategorySource: _vehicleCategorySource,
      activeVehicleId: activeVehicleId,
      completedChecklist: _completedChecklist,
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _invalidatePlan() {
    _generation++;
    _cancelToken?.cancel();
    _cancelToken = null;
    _request = null;
    _plan = null;
    _selectedRouteId = null;
    _planError = null;
  }

  void _swapLocations() {
    setState(() {
      _invalidatePlan();
      final origin = _originMunicipality;
      _originMunicipality = _destinationMunicipality;
      _destinationMunicipality = origin;
      final originText = _originController.text;
      _originController.text = _destinationController.text;
      _destinationController.text = originText;
      _originError = null;
      _destinationError = null;
    });
  }

  void _focusFirstInvalid() {
    final focusNode = _originError != null
        ? _originFocusNode
        : _destinationError != null
        ? _destinationFocusNode
        : _timeError != null
        ? _timeFocusNode
        : _vehicleError != null
        ? _vehicleFocusNode
        : null;
    if (focusNode == null) return;
    focusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final focusContext = focusNode.context;
      if (!mounted || !focusNode.hasFocus || focusContext == null) return;
      unawaited(
        Scrollable.ensureVisible(
          focusContext,
          alignment: 0.2,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  void _scheduleResultsReveal(String requestId, int scrollRevision) {
    if (_revealedRequestId == requestId) return;
    _revealedRequestId = requestId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _request?.requestId != requestId ||
          _plan?.requestId != requestId ||
          !TickerMode.valuesOf(context).enabled ||
          scrollRevision != _userScrollRevision) {
        return;
      }
      unawaited(
        _reveal(
          _resultsAnchorKey,
          alignment: 0,
          focusNode: _resultsFocusNode,
          requestId: requestId,
          scrollRevision: scrollRevision,
        ),
      );
    });
  }

  void _scrollToMap() {
    unawaited(_reveal(_mapAnchorKey, alignment: 0.25));
  }

  Future<void> _reveal(
    GlobalKey anchor, {
    double alignment = 0.05,
    FocusNode? focusNode,
    String? requestId,
    int? scrollRevision,
  }) async {
    final anchorContext = anchor.currentContext;
    if (!mounted ||
        anchorContext == null ||
        !TickerMode.valuesOf(context).enabled ||
        !_matchesRevealGuard(requestId, scrollRevision)) {
      return;
    }
    var focusChanged = false;
    void markFocusChange() => focusChanged = true;
    if (focusNode != null) FocusManager.instance.addListener(markFocusChange);
    try {
      await Scrollable.ensureVisible(
        anchorContext,
        alignment: alignment,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } finally {
      if (focusNode != null) {
        FocusManager.instance.removeListener(markFocusChange);
      }
    }
    if (focusNode == null ||
        focusChanged ||
        !mounted ||
        !TickerMode.valuesOf(context).enabled ||
        !_matchesRevealGuard(requestId, scrollRevision)) {
      return;
    }
    focusNode.requestFocus();
  }

  bool _matchesRevealGuard(String? requestId, int? scrollRevision) {
    if (requestId == null && scrollRevision == null) return true;
    return requestId != null &&
        scrollRevision != null &&
        _request?.requestId == requestId &&
        _plan?.requestId == requestId &&
        _userScrollRevision == scrollRevision;
  }

  Future<void> _preview(
    TripMunicipalityCatalog catalog,
    VehicleProfile? vehicle,
  ) async {
    if (_cancelToken != null) return;
    ref.invalidate(tripInstantRestrictionProvider);
    ref.invalidate(tripRestrictionProvider);
    final origin =
        _originMunicipality ?? catalog.findExact(_originController.text);
    final destination =
        _destinationMunicipality ??
        catalog.findExact(_destinationController.text);
    setState(() {
      _originError = _originController.text.trim().isEmpty
          ? 'Ingresa el origen.'
          : origin == null
          ? 'Elige municipio y departamento de las sugerencias.'
          : null;
      _destinationError = _destinationController.text.trim().isEmpty
          ? 'Ingresa el destino.'
          : destination == null
          ? 'Elige municipio y departamento de las sugerencias.'
          : origin?.code == destination.code
          ? 'Elige otro municipio: no se ha definido un trayecto urbano.'
          : null;
      _timeError = null;
      _vehicleError = vehicle == null
          ? 'Selecciona un vehículo para este viaje.'
          : _vehicleConfiguration == TripVehicleConfiguration.unsupported
          ? 'Esta configuración no tiene una categoría de tarifa compatible.'
          : null;
      _planError =
          origin != null &&
              destination != null &&
              vehicle != null &&
              _vehicleConfiguration == TripVehicleConfiguration.unsupported
          ? tripPlanErrorText('unsupported_vehicle')
          : null;
    });
    if (_originError != null ||
        _destinationError != null ||
        _timeError != null ||
        _vehicleError != null) {
      _focusFirstInvalid();
      return;
    }
    FocusScope.of(context).unfocus();
    final selectedDate = DateUtils.dateOnly(_selectedDate);
    final nowUtc = DateTime.now().toUtc();
    final today = DateUtils.dateOnly(bogotaWallClock(nowUtc));
    final departureMode = _departureMinute != null
        ? TripDepartureMode.specified
        : selectedDate == today
        ? TripDepartureMode.now
        : TripDepartureMode.dateOnly;
    final departureUtc = switch (departureMode) {
      TripDepartureMode.now => nowUtc,
      TripDepartureMode.specified => bogotaScheduledTime(
        date: selectedDate,
        minuteOfDay: _departureMinute!,
      ).toUtc(),
      TripDepartureMode.dateOnly => null,
    };
    final request = TripPlanRequest(
      requestId: List.generate(
        16,
        (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join(),
      origin: origin!,
      destination: destination!,
      vehicle: vehicle!,
      departureMode: departureMode,
      departureDate: selectedDate,
      departureUtc: departureUtc,
      vehicleConfiguration: _vehicleConfiguration,
      vehicleCategorySource: _vehicleCategorySource,
    );
    final token = CancelToken();
    final scrollRevision = _userScrollRevision;
    setState(() {
      _invalidatePlan();
      _request = request;
      _cancelToken = token;
      _originMunicipality = origin;
      _destinationMunicipality = destination;
    });
    final generation = _generation;
    try {
      final plan = await ref
          .read(tripPlanClientProvider)
          .preview(request, cancelToken: token);
      if (!mounted || generation != _generation || token.isCancelled) return;
      if (plan.requestId != request.requestId || plan.routes.isEmpty) {
        throw const TripPlanFailure('invalid_upstream');
      }
      setState(() {
        _plan = plan;
        _selectedRouteId =
            (plan.routes.toList()..sort(
                  (a, b) => a.durationSeconds.compareTo(b.durationSeconds),
                ))
                .first
                .id;
        _cancelToken = null;
      });
      _scheduleResultsReveal(request.requestId, scrollRevision);
    } catch (error) {
      if (!mounted || generation != _generation || token.isCancelled) return;
      setState(() {
        _cancelToken = null;
        if (error is TripPlanFailure && error.code == 'departure_window') {
          _timeError =
              'Elige una salida futura dentro de los próximos ${error.maxFutureDays ?? 30} días.';
        } else {
          _planError = tripPlanErrorText(
            error is TripPlanFailure ? error.code : 'network',
          );
        }
      });
    }
  }

  Future<void> _openSource(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      _showSnackBar('Fuente no disponible.');
      return;
    }
    var opened = false;
    try {
      opened = await ref.read(externalLauncherProvider).openExternal(url);
    } catch (_) {
      opened = false;
    }
    if (mounted && !opened) _showSnackBar('No pudimos abrir la fuente.');
  }
}

class _TripPlanWithLocalData extends StatelessWidget {
  const _TripPlanWithLocalData({
    required this.request,
    required this.plan,
    required this.route,
    required this.onRouteSelected,
    required this.onSource,
    required this.mapAnchorKey,
    required this.onViewMap,
    required this.tollInventory,
    required this.cameraSnapshot,
    required this.mapConfig,
    required this.resolver,
    required this.onRetryTolls,
    required this.onRetryCameras,
  });

  final TripPlanRequest request;
  final TripPlan plan;
  final TripRouteOption route;
  final ValueChanged<String> onRouteSelected;
  final ValueChanged<String> onSource;
  final GlobalKey mapAnchorKey;
  final VoidCallback onViewMap;
  final AsyncValue<TollInventoryDataset> tollInventory;
  final AsyncValue<TripCameraPackSnapshot> cameraSnapshot;
  final TripRouteMapConfig mapConfig;
  final TripRouteAssociationResolver resolver;
  final VoidCallback onRetryTolls;
  final VoidCallback onRetryCameras;

  @override
  Widget build(BuildContext context) => tollInventory.when(
    data: (tolls) => cameraSnapshot.when(
      data: (cameras) => _TripPlanWithAssociations(
        request: request,
        plan: plan,
        route: route,
        tolls: tolls,
        cameras: cameras,
        mapConfig: mapConfig,
        resolver: resolver,
        onRouteSelected: onRouteSelected,
        onSource: onSource,
        mapAnchorKey: mapAnchorKey,
        onViewMap: onViewMap,
      ),
      loading: () => _result(const _TripMapLoading()),
      error: (_, _) => _result(_TripMapLoadError(onRetry: onRetryCameras)),
    ),
    loading: () => _result(const _TripMapLoading()),
    error: (_, _) => _result(_TripMapLoadError(onRetry: onRetryTolls)),
  );

  Widget _result(Widget mapPreview) => TripPlanResult(
    request: request,
    plan: plan,
    selectedRouteId: route.id,
    onRouteSelected: onRouteSelected,
    onSource: onSource,
    mapPreview: mapPreview,
    mapAnchorKey: mapAnchorKey,
    onViewMap: onViewMap,
  );
}

class _TripPlanWithAssociations extends StatefulWidget {
  const _TripPlanWithAssociations({
    required this.request,
    required this.plan,
    required this.route,
    required this.tolls,
    required this.cameras,
    required this.mapConfig,
    required this.resolver,
    required this.onRouteSelected,
    required this.onSource,
    required this.mapAnchorKey,
    required this.onViewMap,
  });

  final TripPlanRequest request;
  final TripPlan plan;
  final TripRouteOption route;
  final TollInventoryDataset tolls;
  final TripCameraPackSnapshot cameras;
  final TripRouteMapConfig mapConfig;
  final TripRouteAssociationResolver resolver;
  final ValueChanged<String> onRouteSelected;
  final ValueChanged<String> onSource;
  final GlobalKey mapAnchorKey;
  final VoidCallback onViewMap;

  @override
  State<_TripPlanWithAssociations> createState() =>
      _TripPlanWithAssociationsState();
}

class _TripPlanWithAssociationsState extends State<_TripPlanWithAssociations> {
  TripRouteAssociations? _snapshot;
  Object? _error;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    _scheduleResolveAfterFrame();
  }

  @override
  void didUpdateWidget(covariant _TripPlanWithAssociations oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.route.id != widget.route.id ||
        !identical(oldWidget.route.geometry, widget.route.geometry) ||
        oldWidget.tolls.version != widget.tolls.version ||
        oldWidget.cameras.version != widget.cameras.version ||
        !identical(oldWidget.resolver, widget.resolver)) {
      _snapshot = null;
      _error = null;
      _scheduleResolveAfterFrame();
    }
  }

  void _scheduleResolveAfterFrame() {
    final generation = ++_generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation) {
        return;
      }
      _resolve(generation);
    });
  }

  void _resolve(int generation) {
    final request = TripRouteAssociationRequest(
      routeId: widget.route.id,
      geometry: widget.route.geometry,
      tollVersion: widget.tolls.version,
      tolls: widget.tolls.records,
      cameraVersion: widget.cameras.version,
      cameras: widget.cameras.pack.cameras,
    );
    Future.sync(() => widget.resolver.resolve(request)).then(
      (snapshot) {
        if (!mounted || generation != _generation) {
          return;
        }
        setState(() {
          _snapshot = snapshot;
          _error = null;
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted || generation != _generation) {
          return;
        }
        setState(() => _error = error);
      },
    );
  }

  void _retry() {
    setState(() {
      _snapshot = null;
      _error = null;
    });
    _resolve(++_generation);
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final cameraCount =
        snapshot?.geometryQuality == RouteGeometryQuality.polyline
        ? snapshot?.uniqueCameraLocationCount
        : null;
    final mapPreview = switch ((_error, snapshot)) {
      (final Object _, _) => _TripMapLoadError(onRetry: _retry),
      (null, null) => const _TripMapLoading(),
      (null, final TripRouteAssociations associations) => TripRoutePreviewMap(
        routeId: widget.route.id,
        geometry: widget.route.geometry,
        tollInventory: widget.tolls,
        cameraPack: widget.cameras.pack,
        cameraPackVersion: widget.cameras.version,
        associations: associations,
        config: widget.mapConfig,
      ),
    };

    return TripPlanResult(
      request: widget.request,
      plan: widget.plan,
      selectedRouteId: widget.route.id,
      onRouteSelected: widget.onRouteSelected,
      onSource: widget.onSource,
      mapPreview: mapPreview,
      mapAnchorKey: widget.mapAnchorKey,
      onViewMap: widget.onViewMap,
      cameraLocationCount: cameraCount,
    );
  }
}

class _LoadingPane extends StatelessWidget {
  const _LoadingPane();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: ValueKey('trip-loading'),
      child: CircularProgressIndicator(),
    );
  }
}

class _TripMapLoading extends StatelessWidget {
  const _TripMapLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: ValueKey('trip-map-data-loading'),
      child: CircularProgressIndicator(),
    );
  }
}

class _TripMapLoadError extends StatelessWidget {
  const _TripMapLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'No pudimos cargar los datos locales del mapa. El plan sigue disponible.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s),
          TextButton.icon(
            key: const ValueKey('trip-map-data-retry'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar datos'),
          ),
        ],
      ),
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Text(message),
    );
  }
}

class _DraftLoadErrorPane extends StatelessWidget {
  const _DraftLoadErrorPane({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No pudimos cargar el borrador local.'),
            const SizedBox(height: AppSpacing.m),
            FilledButton.icon(
              key: const ValueKey('trip-retry-draft-load'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
