import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../app/theme/app_tokens.dart';
import '../../garage/data/vehicle_profile.dart';
import '../application/trip_services.dart';
import '../domain/trip_draft.dart';
import '../data/trip_municipality_catalog.dart';
import 'trip_screen_content.dart';

class TripScreen extends ConsumerStatefulWidget {
  const TripScreen({super.key});

  @override
  ConsumerState<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends ConsumerState<TripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  var _selectedDate = DateUtils.dateOnly(DateTime.now());
  var _completedChecklist = <TripChecklistItem>{};
  var _draftRestored = false;
  var _draftLoadComplete = false;
  Object? _draftLoadError;
  String? _selectedVehicleId;
  String? _restoredVehicleId;
  TripMunicipality? _originMunicipality;
  TripMunicipality? _destinationMunicipality;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreDraft());
  }

  @override
  void dispose() {
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
      appBar: AppBar(title: const Text('Planea tu viaje')),
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
                    error: (error, stackTrace) =>
                        _ErrorPane(message: error.toString()),
                  ),
                  loading: () => const _LoadingPane(),
                  error: (error, stackTrace) =>
                      _ErrorPane(message: error.toString()),
                ),
                loading: () => const _LoadingPane(),
                error: (error, stackTrace) =>
                    _ErrorPane(message: error.toString()),
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
    final origin =
        _originMunicipality ?? catalog.findExact(_originController.text);
    final destination =
        _destinationMunicipality ??
        catalog.findExact(_destinationController.text);
    final date = DateUtils.dateOnly(_selectedDate);
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
      formKey: _formKey,
      originController: _originController,
      destinationController: _destinationController,
      selectedDate: date,
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
      onVehicleChanged: (id) => setState(() {
        _selectedVehicleId = id;
        _restoredVehicleId = null;
      }),
      onOriginChanged: (_) => setState(() => _originMunicipality = null),
      onDestinationChanged: (_) =>
          setState(() => _destinationMunicipality = null),
      onOriginSelected: (municipality) => setState(() {
        _originMunicipality = municipality;
        _originController.text = municipality.displayName;
      }),
      onDestinationSelected: (municipality) => setState(() {
        _destinationMunicipality = municipality;
        _destinationController.text = municipality.displayName;
      }),
      onDateChanged: (value) => setState(() => _selectedDate = value),
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
      _originController.clear();
      _destinationController.clear();
      _selectedDate = DateUtils.dateOnly(DateTime.now());
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
        origin: _originController.text,
        destination: _destinationController.text,
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
        destination: _destinationController.text,
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
      activeVehicleId: activeVehicleId,
      completedChecklist: _completedChecklist,
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
