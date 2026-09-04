import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../app/theme/app_tokens.dart';
import '../../garage/data/vehicle_profile.dart';
import '../application/trip_services.dart';
import '../domain/trip_draft.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Viaje')),
      body: SafeArea(
        child: activeVehicle.when(
          data: (vehicle) => TripContent(
            formKey: _formKey,
            originController: _originController,
            destinationController: _destinationController,
            selectedDate: _selectedDate,
            completedChecklist: _completedChecklist,
            activeVehicle: vehicle,
            draftRestored: _draftRestored,
            onDateChanged: (date) => setState(() => _selectedDate = date),
            onChecklistChanged: _setChecklistItem,
            onSaveDraft: () => _saveDraft(vehicle),
            onDeleteDraft: _deleteDraft,
            onGoogleMaps: _openGoogleMaps,
            onWaze: _openWaze,
            onInvias: _openInvias,
          ),
          loading: () => const _LoadingPane(),
          error: (error, stackTrace) => _ErrorPane(message: error.toString()),
        ),
      ),
    );
  }

  Future<void> _restoreDraft() async {
    final draft = await ref.read(tripDraftStoreProvider).loadDraft();
    if (!mounted || draft == null) {
      return;
    }
    setState(() {
      _originController.text = draft.origin;
      _destinationController.text = draft.destination;
      _selectedDate = DateUtils.dateOnly(draft.date);
      _completedChecklist = draft.completedChecklist;
      _draftRestored = true;
    });
  }

  Future<void> _saveDraft(VehicleProfile? activeVehicle) async {
    if (!_validateTripFields()) {
      return;
    }
    await ref.read(tripDraftStoreProvider).saveDraft(_draft(activeVehicle?.id));
    if (!mounted) {
      return;
    }
    ref.invalidate(tripDraftProvider);
    _showSnackBar('Borrador guardado en este dispositivo.');
  }

  Future<void> _deleteDraft() async {
    await ref.read(tripDraftStoreProvider).deleteDraft();
    if (!mounted) {
      return;
    }
    setState(() {
      _originController.clear();
      _destinationController.clear();
      _selectedDate = DateUtils.dateOnly(DateTime.now());
      _completedChecklist = {};
      _draftRestored = false;
    });
    ref.invalidate(tripDraftProvider);
    _showSnackBar('Borrador eliminado.');
  }

  Future<void> _openGoogleMaps() async {
    if (!_validateTripFields()) {
      return;
    }
    final opened = await ref
        .read(tripExternalNavigationProvider)
        .openGoogleMaps(
          origin: _originController.text,
          destination: _destinationController.text,
        );
    if (!opened && mounted) {
      _showSnackBar('No pudimos abrir Google Maps.');
    }
  }

  Future<void> _openWaze() async {
    if (!_validateTripFields()) {
      return;
    }
    final opened = await ref
        .read(tripExternalNavigationProvider)
        .openWaze(destination: _destinationController.text);
    if (!opened && mounted) {
      _showSnackBar('No pudimos abrir Waze.');
    }
  }

  Future<void> _openInvias() async {
    final opened = await ref
        .read(tripExternalNavigationProvider)
        .openInviasRoadStatus();
    if (!opened && mounted) {
      _showSnackBar('No pudimos abrir INVÍAS.');
    }
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
