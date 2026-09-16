import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../app/theme/app_tokens.dart';
import '../../comparendos/presentation/comparendos_screen.dart';
import '../../comparendos/data/territorial_catalog.dart';
import '../../documents/data/wallet_models.dart';
import '../../documents/presentation/documents_screen.dart';
import '../../garage/data/vehicle_profile.dart';
import '../../location/application/location_controller.dart';
import '../../location/platform/device_location_gateway.dart';
import '../../onboarding/data/registration_city_catalog.dart';
import '../../services/data/google_maps_service_search.dart';
import '../../tramites/presentation/tramites_screen.dart';
import '../../vehicle_status/platform/external_launcher.dart';
import '../../vehicle_status/data/tax_authority_resolution.dart';
import '../data/buy_sell_draft.dart';
import 'purchase_documents_screen.dart';

part 'purchase_review_sheets.dart';

class BuySellScreen extends ConsumerStatefulWidget {
  const BuySellScreen({
    super.key,
    this.onOpenComparendos,
    this.onOpenTramites,
    this.onOpenPeritajes,
    this.onOpenDocuments,
  });

  final ValueChanged<VehicleProfile>? onOpenComparendos;
  final ValueChanged<VehicleProfile>? onOpenTramites;
  final ValueChanged<VehicleProfile>? onOpenPeritajes;
  final ValueChanged<VehicleProfile>? onOpenDocuments;

  @override
  ConsumerState<BuySellScreen> createState() => _BuySellScreenState();
}

class _BuySellScreenState extends ConsumerState<BuySellScreen> {
  final _sponsorController = PageController();
  final _candidatePlateController = TextEditingController();
  final _candidateBrandLineController = TextEditingController();
  final _candidateModelYearController = TextEditingController();
  final _cityController = TextEditingController();
  final _candidateNotesController = TextEditingController();
  final _notesController = TextEditingController();
  final _contractPlateController = TextEditingController();
  final _contractVehicleController = TextEditingController();
  final _contractBuyerController = TextEditingController();
  final _contractSellerController = TextEditingController();
  final _contractCityController = TextEditingController();
  final _contractPriceController = TextEditingController();
  final _contractDateController = TextEditingController();
  final _contractNotesController = TextEditingController();

  var _mode = BuySellMode.buy;
  var _draft = BuySellDraft.empty();
  var _checkedItems = <String>{};
  var _sponsorIndex = 0;
  bool _busy = false;
  bool _restoreFailed = false;
  bool _openingDocuments = false;
  Future<String>? _preparationIdentity;
  bool _candidateCityConfirmed = false;
  String? _vehicleId;

  @override
  void initState() {
    super.initState();
    _restoreDraft(silent: true);
  }

  @override
  void dispose() {
    _sponsorController.dispose();
    _candidatePlateController.dispose();
    _candidateBrandLineController.dispose();
    _candidateModelYearController.dispose();
    _cityController.dispose();
    _candidateNotesController.dispose();
    _notesController.dispose();
    _contractPlateController.dispose();
    _contractVehicleController.dispose();
    _contractBuyerController.dispose();
    _contractSellerController.dispose();
    _contractCityController.dispose();
    _contractPriceController.dispose();
    _contractDateController.dispose();
    _contractNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _vehicleId ??= ref.watch(activeVehicleProvider).asData?.value?.id;
    final vehicles = ref.watch(vehicleListProvider).asData?.value;
    final vehicle = vehicles
        ?.where((vehicle) => vehicle.id == _vehicleId)
        .firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(1);
            final bottomReserve = textScale > 1.4 ? 104.0 : 96.0;
            final sponsor = _SponsorCarousel(
              controller: _sponsorController,
              currentIndex: _sponsorIndex,
              onPageChanged: (index) => setState(() => _sponsorIndex = index),
              onBack: () => Navigator.of(context).maybePop(),
              onLearnMore: _showSponsorInfo,
            );
            final coverContent = Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.l,
                AppSpacing.s,
                AppSpacing.l,
                bottomReserve,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: _BuySellCoverContent(
                    mode: _mode,
                    draft: _draft,
                    compact: textScale >= 1.35,
                    onPrepareBuy: () =>
                        _openPreparation(BuySellMode.buy, vehicle: vehicle),
                    onPrepareSell: () =>
                        _openPreparation(BuySellMode.sell, vehicle: vehicle),
                    onComparendos: () => _openComparendos(vehicle),
                    onTramites: () => _openTramites(vehicle),
                    onPeritajes: () => _openPeritajes(vehicle),
                    onDocuments: () => _openDocuments(vehicle),
                    onAboutGuide: _showAboutGuide,
                  ),
                ),
              ),
            );

            if (textScale <= 1.35) {
              return SizedBox(
                height: constraints.maxHeight,
                child: Column(
                  key: const ValueKey('buy-sell-screen'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    sponsor,
                    Expanded(child: coverContent),
                  ],
                ),
              );
            }
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  key: const ValueKey('buy-sell-screen'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [sponsor, coverContent],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _restoreDraft({required bool silent}) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    final preferences = ref.read(appPreferencesProvider);
    BuySellDraft? draft;
    var failed = false;
    try {
      draft = await loadBuySellDraft(preferences);
    } catch (_) {
      failed = true;
    }
    if (!mounted) {
      return;
    }
    if (draft != null) {
      _applyDraft(draft);
    }
    setState(() {
      _busy = false;
      _restoreFailed = failed;
    });
    if (failed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'No se pudo restaurar la preparación. Se conserva el borrador original; el guardado está bloqueado.',
          ),
          action: SnackBarAction(
            label: 'Reintentar',
            onPressed: () => _restoreDraft(silent: false),
          ),
        ),
      );
      return;
    }
    if (!silent) {
      _showSnackBar(
        draft == null
            ? 'No hay preparación guardada.'
            : 'Preparación restaurada.',
      );
    }
  }

  void _applyDraft(BuySellDraft draft) {
    final preparation = draft.preparationFor(draft.mode);
    setState(() {
      _draft = draft;
      _mode = draft.mode;
      _candidatePlateController.text = draft.candidateVehicle.plate.isEmpty
          ? draft.candidatePlate
          : draft.candidateVehicle.plate;
      _candidateBrandLineController.text = draft.candidateVehicle.brandLine;
      _candidateModelYearController.text = draft.candidateVehicle.modelYear;
      _cityController.text = draft.candidateVehicle.registrationCity.isEmpty
          ? draft.city
          : draft.candidateVehicle.registrationCity;
      _candidateNotesController.text = draft.candidateVehicle.notes;
      _candidateCityConfirmed =
          draft.candidateVehicle.registrationCityConfirmed;
      _notesController.text = preparation.notes;
      _checkedItems = {...preparation.checkedItems};
      _contractPlateController.text = draft.contract.vehiclePlate;
      _contractVehicleController.text = draft.contract.vehicleDescription;
      _contractBuyerController.text = draft.contract.buyerName;
      _contractSellerController.text = draft.contract.sellerName;
      _contractCityController.text = draft.contract.city;
      _contractPriceController.text = draft.contract.price;
      _contractDateController.text = draft.contract.date;
      _contractNotesController.text = draft.contract.notes;
    });
  }

  Future<void> _openPreparation(
    BuySellMode mode, {
    VehicleProfile? vehicle,
  }) async {
    _syncCurrentPreparation();
    final preparation = _draft.preparationFor(mode);
    setState(() {
      _mode = mode;
      _notesController.text = preparation.notes;
      _checkedItems = {...preparation.checkedItems};
    });
    if (mode == BuySellMode.buy) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => StatefulBuilder(
            builder: (context, setScreenState) {
              void refresh() {
                setScreenState(() {});
                if (mounted) {
                  setState(() {});
                }
              }

              void setStep(String stepId, bool checked) {
                if (checked) {
                  _checkedItems.add(stepId);
                } else {
                  _checkedItems.remove(stepId);
                }
                _syncCurrentPreparation();
                refresh();
              }

              return _PurchasePreparationScreen(
                draft: _draft,
                candidate: _candidateVehicleFromControllers(),
                attachment: _draft.candidateRegistrationAttachment,
                notesController: _notesController,
                checkedItems: _checkedItems,
                busy: _busy,
                onBack: () => Navigator.of(context).maybePop(),
                onAddData: () async {
                  if (_busy || _openingDocuments) return;
                  final candidate = await _showCandidateVehicleSheet();
                  if (candidate == null) {
                    return;
                  }
                  if (!await _acceptCandidate(candidate)) return;
                  refresh();
                },
                onAttachRegistration: () async {
                  await _openPurchaseDocuments(
                    WalletDocumentType.trafficLicense,
                  );
                  refresh();
                },
                onPreparations: () async {
                  if (_busy || _openingDocuments) return;
                  await _showPreparationsSummary();
                  refresh();
                },
                onAbout: _showAboutGuide,
                onStep: (step) =>
                    _showPurchaseStepSheet(step: step, onStepChanged: setStep),
                onSave: () async {
                  await _saveDraft();
                  refresh();
                },
                onCopy: _copySummary,
              );
            },
          ),
        ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void updateChecklist(String item, bool checked) {
              setSheetState(() {
                if (checked) {
                  _checkedItems.add(item);
                } else {
                  _checkedItems.remove(item);
                }
              });
              setState(() {});
            }

            return _PreparationSheet(
              mode: mode,
              notesController: _notesController,
              checkedItems: _checkedItems,
              busy: _busy,
              onChecklistChanged: updateChecklist,
              onSave: () async {
                await _saveDraft();
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              onCopy: _copySummary,
              onContract: mode == BuySellMode.sell ? _openContractSheet : null,
            );
          },
        );
      },
    );
  }

  Future<void> _openContractSheet() async {
    _syncCurrentPreparation();
    if (_mode == BuySellMode.buy) {
      final candidate = _candidateVehicleFromControllers();
      if (_contractPlateController.text.isEmpty) {
        _contractPlateController.text = candidate.plate;
      }
      if (_contractVehicleController.text.isEmpty) {
        _contractVehicleController.text = [
          candidate.brandLine,
          candidate.modelYear,
        ].where((s) => s.isNotEmpty).join(' ');
      }
      if (_contractCityController.text.isEmpty) {
        _contractCityController.text = candidate.registrationCity;
      }
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ContractSheet(
        vehiclePlateController: _contractPlateController,
        vehicleDescriptionController: _contractVehicleController,
        buyerNameController: _contractBuyerController,
        sellerNameController: _contractSellerController,
        cityController: _contractCityController,
        priceController: _contractPriceController,
        dateController: _contractDateController,
        notesController: _contractNotesController,
        onSave: () async {
          await _saveDraft();
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        },
        onCopy: _copyContractText,
      ),
    );
  }

  BuySellCandidateVehicle _candidateVehicleFromControllers() {
    return BuySellCandidateVehicle(
      plate: _candidatePlateController.text,
      brandLine: _candidateBrandLineController.text,
      modelYear: _candidateModelYearController.text,
      registrationCity: _cityController.text,
      registrationCityConfirmed: _candidateCityConfirmed,
      notes: _candidateNotesController.text,
    );
  }

  void _applyCandidateVehicle(BuySellCandidateVehicle candidate) {
    _candidatePlateController.text = candidate.plate;
    _candidateBrandLineController.text = candidate.brandLine;
    _candidateModelYearController.text = candidate.modelYear;
    _cityController.text = candidate.registrationCity;
    _candidateNotesController.text = candidate.notes;
    _candidateCityConfirmed = candidate.registrationCityConfirmed;
  }

  Future<BuySellCandidateVehicle?> _showCandidateVehicleSheet() async {
    return showModalBottomSheet<BuySellCandidateVehicle>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) =>
          _CandidateVehicleSheet(initial: _candidateVehicleFromControllers()),
    );
  }

  Future<void> _persistDraft(BuySellDraft draft) async {
    if (_restoreFailed) {
      throw StateError('Original draft requires recovery');
    }
    await saveBuySellDraft(ref.read(appPreferencesProvider), draft);
  }

  Future<String> _ensurePreparationIdentity() {
    return _preparationIdentity ??= _createPreparationIdentity().whenComplete(
      () {
        _preparationIdentity = null;
      },
    );
  }

  Future<String> _createPreparationIdentity() async {
    if (_restoreFailed) {
      throw StateError('Original draft requires recovery');
    }
    if (_draft.purchaseContext.preparationId.isNotEmpty) {
      return _draft.purchaseContext.preparationId;
    }
    final next = _currentDraft().copyWith(
      purchaseContext: _draft.purchaseContext.copyWith(
        preparationId: newPurchasePreparationId(),
      ),
    );
    await _persistDraft(next);
    if (!mounted) throw StateError('Preparation closed');
    setState(() => _draft = next);
    return next.purchaseContext.preparationId;
  }

  Future<void> _openPurchaseDocuments(WalletDocumentType? type) async {
    if (_busy || _openingDocuments) return;
    _openingDocuments = true;
    try {
      final id = await _ensurePreparationIdentity();
      final candidate = _candidateVehicleFromControllers();
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/purchase-documents'),
          builder: (_) => PurchaseDocumentsScreen(
            preparationId: id,
            ownerLabel: candidate.isEmpty
                ? 'Vehículo que quieres comprar'
                : _candidateSummary(candidate),
            initialType: type,
            legacyAttachmentClaim:
                _draft.candidateRegistrationAttachment.hasAny,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        _showSnackBar(
          'No se pudo abrir la carpeta de esta preparación. Intenta de nuevo.',
        );
      }
    } finally {
      _openingDocuments = false;
    }
  }

  BuySellPurchaseSnapshot _snapshot(BuySellDraft draft) =>
      BuySellPurchaseSnapshot(
        context: draft.purchaseContext,
        candidate: draft.candidateVehicle,
        preparation: draft.preparationFor(BuySellMode.buy),
        legacyAttachment: draft.candidateRegistrationAttachment,
        contract: draft.contract,
      );

  Future<bool> _acceptCandidate(BuySellCandidateVehicle candidate) async {
    final previous = _candidateVehicleFromControllers();
    final identityChanged =
        (previous.plate.isNotEmpty &&
            previous.plate.toUpperCase() != candidate.plate.toUpperCase()) ||
        (previous.plate.isEmpty &&
            previous.brandLine.isNotEmpty &&
            (previous.brandLine != candidate.brandLine ||
                previous.modelYear != candidate.modelYear));
    try {
      if (identityChanged) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: const Text('Preparar otro vehículo'),
            content: const Text(
              'Se creará una nueva preparación. La anterior conservará sus revisiones, notas y documentos en Mis preparaciones.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Crear preparación'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return false;
        await _ensurePreparationIdentity();
        final current = _currentDraft();
        final next = current
            .copyWith(
              purchaseContext: PurchaseConsultationContext(
                preparationId: newPurchasePreparationId(),
              ),
              candidateVehicle: candidate,
              candidatePlate: candidate.plate,
              city: candidate.registrationCity,
              candidateRegistrationAttachment:
                  const BuySellRegistrationAttachment(),
              contract: const BuySellContractDraft(),
              archivedPurchases: [
                ...current.archivedPurchases,
                _snapshot(current),
              ],
            )
            .updatePreparation(BuySellMode.buy, const BuySellPreparation());
        await _persistDraft(next);
        if (!mounted) return false;
        _applyDraft(next);
      } else {
        final next = _currentDraft().copyWith(
          candidateVehicle: candidate,
          candidatePlate: candidate.plate,
          city: candidate.registrationCity,
        );
        await _persistDraft(next);
        if (!mounted) return false;
        _applyCandidateVehicle(candidate);
        _draft = next;
      }
      return true;
    } catch (_) {
      if (mounted) {
        _showSnackBar(
          'No se pudieron guardar los datos. La preparación anterior se conserva.',
        );
      }
      return false;
    }
  }

  Future<void> _showPreparationsSummary() async {
    _syncCurrentPreparation();
    final chosen = await showModalBottomSheet<BuySellPurchaseSnapshot>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: .65,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Mis preparaciones',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
            ListTile(
              title: const Text('Compra actual'),
              subtitle: Text(
                '${_draft.preparationFor(BuySellMode.buy).checkedItems.intersection(BuySellPreparationStepIds.buy).length} de 6 revisiones',
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _draft.archivedPurchases.length,
                itemBuilder: (context, index) {
                  final saved = _draft.archivedPurchases[index];
                  return ListTile(
                    title: Text(
                      saved.candidate.isEmpty
                          ? 'Sin datos de vehículo'
                          : _candidateSummary(saved.candidate),
                    ),
                    subtitle: Text(
                      '${saved.preparation.checkedItems.intersection(BuySellPreparationStepIds.buy).length} de 6 revisiones',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(context, saved),
                  );
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Las copias pertenecen a su preparación, no a tus vehículos del Garaje.',
              ),
            ),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    try {
      await _ensurePreparationIdentity();
      final current = _currentDraft();
      final next = current
          .copyWith(
            purchaseContext: chosen.context,
            candidateVehicle: chosen.candidate,
            candidatePlate: chosen.candidate.plate,
            city: chosen.candidate.registrationCity,
            candidateRegistrationAttachment: chosen.legacyAttachment,
            contract: chosen.contract,
            archivedPurchases: [
              for (final item in current.archivedPurchases)
                if (item.context.preparationId != chosen.context.preparationId)
                  item,
              _snapshot(current),
            ],
          )
          .updatePreparation(BuySellMode.buy, chosen.preparation);
      await _persistDraft(next);
      if (mounted) _applyDraft(next);
    } catch (_) {
      if (mounted) {
        _showSnackBar('No se pudo recuperar la preparación. Intenta de nuevo.');
      }
    }
  }

  Future<void> _purchaseNotes() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.viewInsetsOf(sheet).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Notas de la preparación',
              style: TextStyle(fontSize: 20),
            ),
            TextField(
              controller: _notesController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Observaciones'),
            ),
            FilledButton(
              onPressed: () {
                _syncCurrentPreparation();
                Navigator.pop(sheet);
              },
              child: const Text('Listo'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPurchaseStepSheet({
    required _PurchaseStep step,
    required void Function(String stepId, bool checked) onStepChanged,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _PurchaseReviewSheet(
        step: step,
        candidate: _candidateVehicleFromControllers(),
        consultation: _draft.purchaseContext,
        reviewed: _checkedItems.contains(step.id),
        onReviewedChanged: (checked) => onStepChanged(step.id, checked),
        onContextChanged: (selection) async {
          final id = await _ensurePreparationIdentity();
          final next = _currentDraft().copyWith(
            purchaseContext: selection.copyWith(preparationId: id),
          );
          await _persistDraft(next);
          if (mounted) setState(() => _draft = next);
        },
        onDocuments: _openPurchaseDocuments,
        onPeritaje: () => _openPeritajes(
          null,
          isCurrent: () =>
              context.mounted && ModalRoute.of(context)?.isCurrent == true,
        ),
        onChooseAppraisalCity: () async {
          final uri = await _showCityFallbackSheet(
            'Elegir ciudad',
            'Busca y selecciona dónde quieres realizar el peritaje.',
          );
          if (uri != null &&
              mounted &&
              context.mounted &&
              !await ref
                  .read(externalLauncherProvider)
                  .openExternal(uri.toString())) {
            throw StateError('Maps unavailable');
          }
        },
        onContract: _openContractSheet,
        onNotes: _purchaseNotes,
        onCopy: _copySummary,
      ),
    );
  }

  void _syncCurrentPreparation() {
    _draft = _currentDraft();
  }

  Future<void> _saveDraft() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await _ensurePreparationIdentity();
      final draft = _currentDraft();
      await _persistDraft(draft);
      if (!mounted) {
        return;
      }
      setState(() => _draft = draft);
      _showSnackBar('Preparación guardada en este dispositivo.');
    } catch (_) {
      if (mounted) {
        _showSnackBar('No se pudo guardar la preparación.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _copySummary() async {
    try {
      await Clipboard.setData(ClipboardData(text: _summaryText()));
      if (mounted) {
        _showSnackBar('Resumen copiado.');
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar('No se pudo copiar el resumen.');
      }
    }
  }

  Future<void> _copyContractText() async {
    try {
      await Clipboard.setData(ClipboardData(text: _contractText()));
      if (mounted) {
        _showSnackBar('Texto de compraventa copiado.');
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar('No se pudo copiar el texto.');
      }
    }
  }

  Future<void> _openComparendos(VehicleProfile? vehicle) async {
    if (vehicle != null && widget.onOpenComparendos != null) {
      widget.onOpenComparendos!(vehicle);
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ComparendosScreen(vehicleId: vehicle?.id),
      ),
    );
  }

  Future<void> _openTramites(VehicleProfile? vehicle) async {
    if (vehicle != null && widget.onOpenTramites != null) {
      widget.onOpenTramites!(vehicle);
      return;
    }
    await Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const TramitesScreen()));
  }

  Future<void> _openPeritajes(
    VehicleProfile? vehicle, {
    bool Function()? isCurrent,
  }) async {
    if (vehicle != null && widget.onOpenPeritajes != null) {
      widget.onOpenPeritajes!(vehicle);
      return;
    }
    final uri = await _appraisalUriFromLocation(isCurrent: isCurrent);
    if (uri == null || !mounted || !(isCurrent?.call() ?? true)) {
      return;
    }
    final opened = await ref
        .read(externalLauncherProvider)
        .openExternal(uri.toString());
    if (!mounted) {
      return;
    }
    if (!opened) {
      _showSnackBar('No se pudo abrir Google Maps.');
    }
  }

  Future<Uri?> _appraisalUriFromLocation({bool Function()? isCurrent}) async {
    final gateway = ref.read(deviceLocationGatewayProvider);
    bool active() => mounted && (isCurrent?.call() ?? true);
    try {
      final enabled = await gateway.isLocationServiceEnabled();
      if (!active()) return null;
      if (!enabled) {
        return await _showCityFallbackSheet(
          'GPS apagado',
          'Elige una ciudad para buscar peritajes sin usar ubicación.',
        );
      }
      var permission = await gateway.checkPermission();
      if (!active()) return null;
      if (permission == DeviceLocationPermission.denied ||
          permission == DeviceLocationPermission.notRequested) {
        permission = await gateway.requestPermission();
      }
      if (!active()) return null;
      if (permission != DeviceLocationPermission.granted) {
        return await _showCityFallbackSheet(
          'Ubicación no disponible',
          'Puedes seleccionar una ciudad del catálogo para continuar.',
        );
      }
      final result = await gateway.getCurrentPosition();
      if (!active()) return null;
      if (result is DeviceLocationSuccess &&
          result.point.latitude.isFinite &&
          result.point.longitude.isFinite &&
          result.point.latitude.abs() <= 90 &&
          result.point.longitude.abs() <= 180 &&
          result.point.accuracyMeters.isFinite &&
          result.point.accuracyMeters >= 0 &&
          result.point.accuracyMeters <= 1000) {
        return googleMapsNearbyServiceSearchUri(
          category: GoogleMapsServiceCategory.appraisal,
          latitude: result.point.latitude,
          longitude: result.point.longitude,
        );
      }
      return await _showCityFallbackSheet(
        'Sin señal GPS',
        'No pudimos obtener una posición confiable. Elige una ciudad.',
      );
    } catch (_) {
      if (!active()) return null;
      return await _showCityFallbackSheet(
        'Sin señal GPS',
        'No pudimos obtener una posición confiable. Elige una ciudad.',
      );
    }
  }

  Future<Uri?> _showCityFallbackSheet(String title, String message) async {
    final city = await showModalBottomSheet<RegistrationCity>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _CityFallbackSheet(title: title, message: message),
    );
    if (city == null) {
      return null;
    }
    return googleMapsCityServiceSearchUri(
      category: GoogleMapsServiceCategory.appraisal,
      city: city.displayName,
    );
  }

  Future<void> _openDocuments(VehicleProfile? vehicle) async {
    if (vehicle != null && widget.onOpenDocuments != null) {
      widget.onOpenDocuments!(vehicle);
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => DocumentsScreen(vehicle?.id)),
    );
  }

  void _showSponsorInfo() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _InfoSheet(
        title: 'Aliado de demostración',
        body: 'Este espacio muestra cómo se vería un patrocinio automotor. No es una oferta comercial activa, no captura datos y no implica aval oficial.',
      ),
    );
  }

  void _showAboutGuide() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _InfoSheet(
        title: 'Sobre esta guía',
        body:
            '$buySellMandatoryCopy Puedes continuar sin agregar datos del vehículo. Toca una revisión para abrirla y marca Revisado solo después de comprobarla. Usa los enlaces oficiales y confirma requisitos, costos y vigencia antes de comprar o vender.',
      ),
    );
  }

  BuySellDraft _currentDraft() {
    final preparation = BuySellPreparation(
      notes: _notesController.text,
      checkedItems: {..._checkedItems},
    );
    return _draft
        .copyWith(
          mode: _mode,
          candidatePlate: _candidatePlateController.text,
          city: _cityController.text,
          candidateVehicle: _candidateVehicleFromControllers(),
          contract: BuySellContractDraft(
            vehiclePlate: _contractPlateController.text,
            vehicleDescription: _contractVehicleController.text,
            buyerName: _contractBuyerController.text,
            sellerName: _contractSellerController.text,
            city: _contractCityController.text,
            price: _contractPriceController.text,
            date: _contractDateController.text,
            notes: _contractNotesController.text,
          ),
        )
        .updatePreparation(_mode, preparation);
  }

  String _summaryText() {
    final items = _checklistItems(_mode);
    final candidate = _candidateVehicleFromControllers();
    final attachment = _draft.candidateRegistrationAttachment;
    final buffer = StringBuffer()
      ..writeln(
        'PicoRadar - Preparar mi ${_mode == BuySellMode.buy ? 'compra' : 'venta'}',
      )
      ..writeln(buySellMandatoryCopy)
      ..writeln();
    if (_mode == BuySellMode.buy) {
      buffer
        ..writeln('Vehículo candidato:')
        ..writeln(
          candidate.isEmpty
              ? 'Sin datos agregados.'
              : [
                  if (candidate.plate.trim().isNotEmpty)
                    'Placa ${candidate.plate.trim()}',
                  if (candidate.brandLine.trim().isNotEmpty)
                    candidate.brandLine.trim(),
                  if (candidate.modelYear.trim().isNotEmpty)
                    'Modelo ${candidate.modelYear.trim()}',
                  if (candidate.registrationCity.trim().isNotEmpty)
                    'Matrícula ${candidate.registrationCity.trim()}',
                ].join(' · '),
        )
        ..writeln(
          'Matrícula y soportes: consultar la carpeta privada de esta preparación.',
        )
        ..writeln(
          attachment.hasAny
              ? 'Existe una declaración histórica de adjunto; no acredita una copia importada.'
              : '',
        )
        ..writeln();
    }
    for (final item in items) {
      buffer.writeln(
        '${_checkedItems.contains(item) ? '[x]' : '[ ]'} ${_checklistLabel(item, _mode)}',
      );
    }
    final notes = _notesController.text.trim();
    if (notes.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Notas:')
        ..writeln(notes);
    }
    return buffer.toString().trim();
  }

  String _contractText() {
    String value(TextEditingController controller, String fallback) {
      final text = controller.text.trim();
      return text.isEmpty ? fallback : text;
    }

    return '''
CONTRATO DE COMPRAVENTA DE VEHICULO

En ${value(_contractCityController, '[ciudad]')}, el dia ${value(_contractDateController, '[fecha]')}, ${value(_contractSellerController, '[vendedor]')} declara vender a ${value(_contractBuyerController, '[comprador]')} el vehiculo identificado con placa ${value(_contractPlateController, '[placa]')}.

Descripcion del vehiculo: ${value(_contractVehicleController, '[marca, linea, modelo y datos relevantes]')}.
Valor acordado: ${value(_contractPriceController, '[valor]')}.

Observaciones: ${value(_contractNotesController, '[sin observaciones]')}.

Este texto es una preparacion privada. No reemplaza asesoria legal, revision documental, peritaje, pagos ni tramite oficial de traspaso.
'''
        .trim();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SponsorCarousel extends StatelessWidget {
  const _SponsorCarousel({
    required this.controller,
    required this.currentIndex,
    required this.onPageChanged,
    required this.onBack,
    required this.onLearnMore,
  });

  final PageController controller;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onBack;
  final VoidCallback onLearnMore;

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final accessible = textScale > 1.35;
    final idealHeight = accessible
        ? (viewport.width * 0.61).clamp(210.0, 270.0)
        : (viewport.width * 0.69).clamp(240.0, 292.0);
    final bannerHeight = math.min(
      idealHeight,
      viewport.height * (accessible ? 0.32 : 0.35),
    );

    return SizedBox(
      key: const ValueKey('buy-sell-sponsor-frame'),
      height: bannerHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView(
            key: const ValueKey('buy-sell-sponsor-carousel'),
            controller: controller,
            onPageChanged: onPageChanged,
            children: [
              _SponsorSlide(
                title: 'Tu próximo vehículo empieza aquí',
                partner: 'Aliado automotor',
                subtitle:
                    'Compara, revisa y prepara cada paso antes de elegir.',
                imageAsset:
                    'assets/pico/buy_sell_banner_automotive_demo_v1.webp',
                onLearnMore: onLearnMore,
              ),
              _SponsorSlide(
                title: 'Compra con revisión previa',
                partner: 'Peritaje aliado',
                subtitle: 'Agenda una inspección antes de cerrar el negocio.',
                imageAsset:
                    'assets/pico/buy_sell_banner_appraisal_demo_v1.webp',
                onLearnMore: onLearnMore,
              ),
              _SponsorSlide(
                title: 'Trámite acompañado',
                partner: 'Gestión documental',
                subtitle: 'Organiza formularios y requisitos con tiempo.',
                imageAsset: 'assets/pico/buy_sell_banner_transfer_demo_v1.webp',
                onLearnMore: onLearnMore,
              ),
            ],
          ),
          Positioned(
            top: AppSpacing.s,
            left: AppSpacing.s,
            child: Semantics(
              button: true,
              label: 'Volver',
              child: Tooltip(
                message: 'Volver',
                child: SizedBox(
                  key: const ValueKey('buy-sell-back'),
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.60),
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onBack,
                        child: const SizedBox(
                          width: 38,
                          height: 38,
                          child: Icon(
                            Icons.arrow_back,
                            color: AppColors.navy,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.xl,
            bottom: AppSpacing.l,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < 3; index++)
                  AnimatedContainer(
                    duration: AppMotion.fade,
                    margin: const EdgeInsets.only(right: AppSpacing.s),
                    width: currentIndex == index ? 22 : 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: currentIndex == index ? 0.95 : 0.48,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SponsorSlide extends StatelessWidget {
  const _SponsorSlide({
    required this.title,
    required this.partner,
    required this.subtitle,
    required this.imageAsset,
    required this.onLearnMore,
  });

  final String title;
  final String partner;
  final String subtitle;
  final String imageAsset;
  final VoidCallback onLearnMore;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final accessible = textScale > 1.35;
        final compact = constraints.maxHeight < 230 || accessible;
        return Semantics(
          label: 'Patrocinado. Demostración. $partner. $title. $subtitle',
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(imageAsset, fit: BoxFit.cover),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.navy.withValues(alpha: 0.96),
                        AppColors.navy.withValues(alpha: 0.70),
                        AppColors.navy.withValues(alpha: 0.14),
                      ],
                      stops: const [0, 0.52, 1],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  accessible ? AppSpacing.xl : AppSpacing.xxl,
                  compact ? 52 : 58,
                  AppSpacing.xl,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: accessible ? 210 : 270,
                      ),
                      child: Text(
                        accessible
                            ? 'Demostración · $partner'
                            : 'Patrocinado · Demostración\n$partner',
                        maxLines: accessible ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: accessible ? 10.5 : null,
                          height: 1.18,
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 4 : AppSpacing.s),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: accessible ? 235 : 330,
                      ),
                      child: Text(
                        accessible ? 'Tu próximo vehículo' : title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.display.copyWith(
                          color: Colors.white,
                          fontSize: accessible ? 15 : (compact ? 21 : 24),
                          height: 1.03,
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 6 : AppSpacing.s),
                    SizedBox(
                      height: accessible ? 48 : 40,
                      child: FilledButton.icon(
                        key: const ValueKey('buy-sell-sponsor-info'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.plateYellow,
                          foregroundColor: AppColors.navy,
                          textStyle: AppTextStyles.bodyStrong.copyWith(
                            fontSize: accessible ? 13 : null,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.m,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadius.button,
                            ),
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: onLearnMore,
                        iconAlignment: IconAlignment.end,
                        label: const Text('Conocer al aliado'),
                        icon: const Icon(Icons.arrow_forward, size: 22),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BuySellCoverContent extends StatelessWidget {
  const _BuySellCoverContent({
    required this.mode,
    required this.draft,
    required this.compact,
    required this.onPrepareBuy,
    required this.onPrepareSell,
    required this.onComparendos,
    required this.onTramites,
    required this.onPeritajes,
    required this.onDocuments,
    required this.onAboutGuide,
  });

  final BuySellMode mode;
  final BuySellDraft draft;
  final bool compact;
  final VoidCallback onPrepareBuy;
  final VoidCallback onPrepareSell;
  final VoidCallback onComparendos;
  final VoidCallback onTramites;
  final VoidCallback onPeritajes;
  final VoidCallback onDocuments;
  final VoidCallback onAboutGuide;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tight = compact || constraints.maxHeight < 470;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¿Comprar o vender?',
                        key: const ValueKey('buy-sell-cover-title'),
                        style: AppTextStyles.display.copyWith(
                          fontSize: tight ? 23 : 26,
                          height: 1.02,
                        ),
                      ),
                      SizedBox(height: tight ? 2 : AppSpacing.xs),
                      Text(
                        'Prepara cada paso antes de decidir.',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.navy.withValues(alpha: 0.72),
                          fontSize: tight ? 13 : 14,
                        ),
                      ),
                    ],
                  ),
                ),
                _AboutGuideButton(onTap: onAboutGuide, compact: tight),
              ],
            ),
            SizedBox(height: tight ? AppSpacing.s : AppSpacing.m),
            Row(
              children: [
                Expanded(
                  child: _PreparationCard(
                    keyName: 'buy-sell-prepare-buy',
                    mode: BuySellMode.buy,
                    selected: mode == BuySellMode.buy,
                    checkedCount: draft
                        .preparationFor(BuySellMode.buy)
                        .checkedItems
                        .length,
                    totalCount: _checklistItems(BuySellMode.buy).length,
                    compact: tight,
                    onTap: onPrepareBuy,
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: _PreparationCard(
                    keyName: 'buy-sell-prepare-sell',
                    mode: BuySellMode.sell,
                    selected: mode == BuySellMode.sell,
                    checkedCount: draft
                        .preparationFor(BuySellMode.sell)
                        .checkedItems
                        .length,
                    totalCount: _checklistItems(BuySellMode.sell).length,
                    compact: tight,
                    onTap: onPrepareSell,
                  ),
                ),
              ],
            ),
            SizedBox(height: tight ? AppSpacing.s : AppSpacing.m),
            Text(
              'Herramientas',
              style: AppTextStyles.h2.copyWith(fontSize: 22),
            ),
            SizedBox(height: tight ? AppSpacing.xs : AppSpacing.s),
            _ToolGrid(
              compact: tight,
              onComparendos: onComparendos,
              onTramites: onTramites,
              onPeritajes: onPeritajes,
              onDocuments: onDocuments,
            ),
          ],
        );
      },
    );
  }
}

class _PreparationCard extends StatelessWidget {
  const _PreparationCard({
    required this.keyName,
    required this.mode,
    required this.selected,
    required this.checkedCount,
    required this.totalCount,
    required this.compact,
    required this.onTap,
  });

  final String keyName;
  final BuySellMode mode;
  final bool selected;
  final int checkedCount;
  final int totalCount;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isBuy = mode == BuySellMode.buy;
    final accessible = MediaQuery.textScalerOf(context).scale(1) > 1.35;
    return Semantics(
      label:
          '${isBuy ? 'Preparar mi compra' : 'Preparar mi venta'}, $checkedCount de $totalCount pasos completados',
      button: true,
      child: Material(
        color: selected
            ? AppColors.teal.withValues(alpha: 0.12)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          key: ValueKey(keyName),
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onTap,
          child: Container(
            height: compact ? 100 : 112,
            padding: EdgeInsets.all(compact ? AppSpacing.s : AppSpacing.m),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: selected ? AppColors.teal : AppColors.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isBuy
                          ? Icons.directions_car_filled_outlined
                          : Icons.sell_outlined,
                      color: AppColors.teal,
                      size: compact ? 19 : 23,
                    ),
                    SizedBox(height: compact ? 2 : 3),
                    Text(
                      accessible
                          ? (isBuy ? 'Compra' : 'Venta')
                          : (isBuy ? 'Preparar\ncompra' : 'Preparar\nventa'),
                      maxLines: accessible ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.h2.copyWith(
                        fontSize: compact ? 14 : 15.5,
                        height: 1.02,
                      ),
                    ),
                  ],
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.arrow_forward,
                        color: AppColors.teal,
                        size: 22,
                      ),
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

class _ToolGrid extends StatelessWidget {
  const _ToolGrid({
    required this.onComparendos,
    required this.onTramites,
    required this.onPeritajes,
    required this.onDocuments,
    required this.compact,
  });

  final VoidCallback onComparendos;
  final VoidCallback onTramites;
  final VoidCallback onPeritajes;
  final VoidCallback onDocuments;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('buy-sell-tools-row'),
      height: compact ? 84 : 92,
      child: Row(
        children: [
          Expanded(
            child: _ToolTile(
              keyName: 'buy-sell-open-comparendos',
              icon: Icons.fact_check_outlined,
              label: 'Comparendos',
              compact: compact,
              onTap: onComparendos,
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: _ToolTile(
              keyName: 'buy-sell-open-tramites',
              icon: Icons.assignment_outlined,
              label: 'Trámites',
              compact: compact,
              onTap: onTramites,
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: _ToolTile(
              keyName: 'buy-sell-open-peritajes',
              icon: Icons.manage_search_outlined,
              label: 'Peritajes',
              compact: compact,
              onTap: onPeritajes,
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: _ToolTile(
              keyName: 'buy-sell-open-documents',
              icon: Icons.folder_copy_outlined,
              label: 'Documentos',
              compact: compact,
              onTap: onDocuments,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.keyName,
    required this.icon,
    required this.label,
    required this.compact,
    required this.onTap,
  });

  final String keyName;
  final IconData icon;
  final String label;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accessible = MediaQuery.textScalerOf(context).scale(1) > 1.35;
    final visibleLabel = accessible
        ? switch (label) {
            'Comparendos' => 'Multas',
            'Trámites' => 'Trám.',
            'Peritajes' => 'Perit.',
            'Documentos' => 'Docs',
            _ => label,
          }
        : label;
    return Semantics(
      label: label,
      button: true,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: InkWell(
          key: ValueKey(keyName),
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.input),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.input),
            ),
            child: Padding(
              padding: EdgeInsets.all(compact ? 6 : AppSpacing.s),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    key: ValueKey('buy-sell-tool-icon-$keyName'),
                    icon,
                    color: AppColors.teal,
                    size: accessible ? 24 : (compact ? 28 : 32),
                  ),
                  SizedBox(height: accessible ? 2 : (compact ? 3 : 5)),
                  Text(
                    visibleLabel,
                    textAlign: TextAlign.center,
                    maxLines: accessible ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: accessible ? 9 : (compact ? 9.2 : 11),
                      height: 1.0,
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

class _AboutGuideButton extends StatelessWidget {
  const _AboutGuideButton({required this.onTap, this.compact = false});

  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return IconButton(
        key: const ValueKey('buy-sell-about-guide'),
        onPressed: onTap,
        icon: const Icon(Icons.info_outline),
        tooltip: 'Sobre esta guía',
      );
    }
    return TextButton.icon(
      key: const ValueKey('buy-sell-about-guide'),
      onPressed: onTap,
      icon: const Icon(Icons.info_outline, size: 18),
      label: const Text('Sobre guía'),
    );
  }
}

class _PurchaseStep {
  const _PurchaseStep({
    required this.id,
    required this.number,
    required this.title,
    required this.icon,
    required this.body,
  });

  final String id;
  final int number;
  final String title;
  final IconData icon;
  final String body;
}

const _purchaseSteps = [
  _PurchaseStep(
    id: BuySellPreparationStepIds.comparendos,
    number: 1,
    title: 'Comparendos',
    icon: Icons.description_outlined,
    body: 'Revisa SIMIT y, cuando aplique, la autoridad territorial antes de separar o pagar.',
  ),
  _PurchaseStep(
    id: BuySellPreparationStepIds.taxes,
    number: 2,
    title: 'Impuestos',
    icon: Icons.monetization_on_outlined,
    body: 'Confirma impuesto vehicular y obligaciones pendientes en canales oficiales.',
  ),
  _PurchaseStep(
    id: BuySellPreparationStepIds.transfer,
    number: 3,
    title: 'Traspaso',
    icon: Icons.directions_car_filled_outlined,
    body: 'Verifica requisitos, documentos y cita de traspaso antes de entregar dinero.',
  ),
  _PurchaseStep(
    id: BuySellPreparationStepIds.appraisal,
    number: 4,
    title: 'Peritaje',
    icon: Icons.search,
    body: 'Busca una revisión mecánica independiente antes de tomar la decisión final.',
  ),
  _PurchaseStep(
    id: BuySellPreparationStepIds.documents,
    number: 5,
    title: 'Documentos',
    icon: Icons.file_copy_outlined,
    body: 'Organiza matrícula, SOAT, tecnomecánica, improntas y soportes de compra.',
  ),
  _PurchaseStep(
    id: BuySellPreparationStepIds.paymentDelivery,
    number: 6,
    title: 'Pago y entrega',
    icon: Icons.payment_outlined,
    body:
        'Acuerda forma de pago verificable, entrega y constancia de recibido.',
  ),
];

const _purchaseHeaderBlue = Color(0xFF143963);
const _purchaseReviewBlue = Color(0xFF1D62C6);
const _purchaseInk = Color(0xFF0A2252);
const _purchaseTeal = Color(0xFF078B90);

class _PurchasePreparationScreen extends StatelessWidget {
  const _PurchasePreparationScreen({
    required this.draft,
    required this.candidate,
    required this.attachment,
    required this.notesController,
    required this.checkedItems,
    required this.busy,
    required this.onBack,
    required this.onAddData,
    required this.onAttachRegistration,
    required this.onPreparations,
    required this.onAbout,
    required this.onStep,
    required this.onSave,
    required this.onCopy,
  });

  final BuySellDraft draft;
  final BuySellCandidateVehicle candidate;
  final BuySellRegistrationAttachment attachment;
  final TextEditingController notesController;
  final Set<String> checkedItems;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback onAddData;
  final VoidCallback onAttachRegistration;
  final VoidCallback onPreparations;
  final VoidCallback onAbout;
  final ValueChanged<_PurchaseStep> onStep;
  final VoidCallback onSave;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final accessible = MediaQuery.textScalerOf(context).scale(1) > 1.35;
    final reviewed = _purchaseSteps
        .where((step) => checkedItems.contains(step.id))
        .length;
    return Scaffold(
      backgroundColor: const Color(0xFFFBFDFE),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PurchaseHeader(
                  candidate: candidate,
                  attachment: attachment,
                  compact: accessible,
                  onBack: onBack,
                  onAddData: onAddData,
                  onAttachRegistration: onAttachRegistration,
                ),
                if (accessible)
                  _body(context, reviewed, accessible: true)
                else
                  Expanded(child: _body(context, reviewed, accessible: false)),
              ],
            );
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: accessible
                    ? SingleChildScrollView(
                        key: const ValueKey('buy-sell-purchase-screen'),
                        child: content,
                      )
                    : SizedBox(
                        key: const ValueKey('buy-sell-purchase-screen'),
                        height: constraints.maxHeight,
                        child: content,
                      ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _body(BuildContext context, int reviewed, {required bool accessible}) {
    final grid = _PurchaseStepGrid(
      checkedItems: checkedItems,
      onStep: onStep,
      compact: accessible,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        mainAxisSize: accessible ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PreparationsLink(onTap: onPreparations),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tus revisiones',
                  style: AppTextStyles.h2.copyWith(fontSize: 18, height: 1.2),
                ),
              ),
              Text(
                '$reviewed de ${_purchaseSteps.length}',
                key: const ValueKey('buy-sell-purchase-progress-count'),
                style: AppTextStyles.bodyStrong.copyWith(
                  fontSize: 16,
                  height: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              key: const ValueKey('buy-sell-purchase-progress-bar'),
              minHeight: 6,
              value: reviewed / _purchaseSteps.length,
              backgroundColor: AppColors.border,
              color: _purchaseReviewBlue,
            ),
          ),
          const SizedBox(height: 4),
          if (accessible) grid else Expanded(child: grid),
          const SizedBox(height: 4),
          const Divider(height: 1),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  key: const ValueKey('buy-sell-purchase-notes'),
                  onPressed: () => _showNotesSheet(context, notesController),
                  icon: const Icon(Icons.notes_outlined, size: 20),
                  label: const Text('Notas'),
                  style: _footerStyle,
                ),
              ),
              Expanded(
                flex: 2,
                child: TextButton.icon(
                  key: const ValueKey('buy-sell-purchase-copy-summary'),
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_outlined, size: 20),
                  label: const Text(
                    'Copiar resumen',
                    textAlign: TextAlign.center,
                  ),
                  style: _footerStyle,
                ),
              ),
              IconButton(
                key: const ValueKey('buy-sell-purchase-about'),
                tooltip: 'Sobre esta guía',
                onPressed: onAbout,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(Icons.info_outline, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FilledButton.icon(
            key: const ValueKey('buy-sell-purchase-save-progress'),
            onPressed: busy ? null : onSave,
            icon: const Icon(Icons.save_outlined, size: 22),
            label: const Text('Guardar progreso'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 48),
              backgroundColor: _purchaseTeal,
              foregroundColor: Colors.white,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  ButtonStyle get _footerStyle => TextButton.styleFrom(
    foregroundColor: _purchaseInk,
    minimumSize: const Size(48, 48),
    padding: const EdgeInsets.symmetric(horizontal: 4),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: const TextStyle(fontFamily: 'Roboto', fontSize: 14, height: 1.2),
  );

  Future<void> _showNotesSheet(
    BuildContext context,
    TextEditingController controller,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.l,
          AppSpacing.l,
          MediaQuery.viewInsetsOf(context).bottom +
              MediaQuery.paddingOf(context).bottom +
              AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Notas privadas',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              key: const ValueKey('buy-sell-notes'),
              controller: controller,
              minLines: 4,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Observaciones opcionales',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Listo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseHeader extends StatelessWidget {
  const _PurchaseHeader({
    required this.candidate,
    required this.attachment,
    required this.compact,
    required this.onBack,
    required this.onAddData,
    required this.onAttachRegistration,
  });

  final BuySellCandidateVehicle candidate;
  final BuySellRegistrationAttachment attachment;
  final bool compact;
  final VoidCallback onBack;
  final VoidCallback onAddData;
  final VoidCallback onAttachRegistration;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('buy-sell-purchase-header'),
      decoration: const BoxDecoration(
        color: _purchaseHeaderBlue,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          compact ? 8 : 16,
          16,
          compact ? 8 : 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const SizedBox(width: 32, height: 32),
                      ),
                      IconButton(
                        key: const ValueKey('buy-sell-purchase-back'),
                        tooltip: 'Volver',
                        onPressed: onBack,
                        icon: const Icon(
                          Icons.arrow_back,
                          color: _purchaseInk,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Vehículo que quieres comprar',
                    style: AppTextStyles.h1.copyWith(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                ),
                if (!compact) ...[const SizedBox(width: 4), _optionalLabel],
              ],
            ),
            if (compact)
              Align(alignment: Alignment.centerRight, child: _optionalLabel),
            SizedBox(height: compact ? 8 : 16),
            if (compact)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _dataAction,
                  const SizedBox(height: 8),
                  _attachmentAction,
                ],
              )
            else
              Row(
                children: [
                  Expanded(child: _dataAction),
                  const SizedBox(width: 8),
                  Expanded(child: _attachmentAction),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget get _optionalLabel => DecoratedBox(
    key: const ValueKey('buy-sell-purchase-optional'),
    decoration: BoxDecoration(
      color: const Color(0xFFDDF8F2),
      borderRadius: BorderRadius.circular(24),
    ),
    child: const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        'Opcional',
        style: TextStyle(
          color: _purchaseTeal,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );

  Widget get _dataAction => Tooltip(
    message: candidate.isEmpty ? 'Agregar datos' : _candidateSummary(candidate),
    child: _HeaderAction(
      keyName: 'buy-sell-add-candidate-data',
      minHeight: compact ? 48 : 64,
      icon: Icons.car_repair_outlined,
      label: candidate.isEmpty ? 'Agregar datos' : 'Editar datos',
      onTap: onAddData,
    ),
  );

  Widget get _attachmentAction => _HeaderAction(
    keyName: 'buy-sell-attach-registration',
    minHeight: compact ? 48 : 64,
    icon: Icons.file_present_outlined,
    label: 'Adjuntar matrícula',
    onTap: onAttachRegistration,
  );
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.keyName,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.minHeight,
  });

  final String keyName;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: ValueKey(keyName),
      onPressed: onTap,
      icon: Icon(icon, size: 24),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white, width: 1.2),
        minimumSize: Size(48, minHeight),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 14,
          height: 1.1,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _PreparationsLink extends StatelessWidget {
  const _PreparationsLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _purchaseTeal.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        key: const ValueKey('buy-sell-my-preparations'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.m),
            child: Row(
              children: [
                Icon(Icons.folder_outlined, color: _purchaseInk),
                SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Text(
                    'Mis preparaciones',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                      color: _purchaseInk,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: _purchaseInk),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PurchaseStepGrid extends StatelessWidget {
  const _PurchaseStepGrid({
    required this.checkedItems,
    required this.onStep,
    required this.compact,
  });

  final Set<String> checkedItems;
  final ValueChanged<_PurchaseStep> onStep;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    Widget grid(double rowHeight, {int? columns}) => GridView.builder(
      padding: EdgeInsets.zero,
      primary: false,
      shrinkWrap: compact,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _purchaseSteps.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns ?? 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: rowHeight,
      ),
      itemBuilder: (context, index) {
        final step = _purchaseSteps[index];
        return _PurchaseStepTile(
          step: step,
          reviewed: checkedItems.contains(step.id),
          onTap: () => onStep(step),
        );
      },
    );
    if (compact) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      return LayoutBuilder(
        builder: (context, constraints) {
          final title = TextPainter(
            text: const TextSpan(
              text: 'Comparendos',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          final columns = title.width <= (constraints.maxWidth - 8) / 2 - 8
              ? 2
              : 1;
          title.dispose();
          return grid(64 + 60 * scale, columns: columns);
        },
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final rowHeight = ((constraints.maxHeight - 8) / 2).clamp(0.0, 120.0);
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(height: rowHeight * 2 + 8, child: grid(rowHeight)),
        );
      },
    );
  }
}

class _PurchaseStepTile extends StatelessWidget {
  const _PurchaseStepTile({
    required this.step,
    required this.reviewed,
    required this.onTap,
  });

  final _PurchaseStep step;
  final bool reviewed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = reviewed ? Colors.white : _purchaseInk;
    final scaler = MediaQuery.textScalerOf(context);
    return Semantics(
      label:
          'Paso ${step.number}, ${step.title}, ${reviewed ? 'Revisado' : 'Por revisar'}',
      button: true,
      child: Material(
        color: reviewed ? _purchaseReviewBlue : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: reviewed ? _purchaseReviewBlue : AppColors.border,
          ),
        ),
        child: InkWell(
          key: ValueKey('buy-sell-purchase-step-${step.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Column(
              children: [
                SizedBox(
                  height: 32,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          '${step.number}',
                          key: ValueKey('buy-sell-purchase-number-${step.id}'),
                          style: TextStyle(
                            color: foreground,
                            fontSize: 16,
                            height: 1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        step.icon,
                        key: ValueKey('buy-sell-purchase-icon-${step.id}'),
                        color: foreground,
                        size: 32,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: scaler.scale(14) * 1.1 * 2,
                  child: Center(
                    child: Text(
                      step.id == BuySellPreparationStepIds.paymentDelivery
                          ? 'Pago y\nentrega'
                          : step.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 14,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (reviewed) ...[
                      Icon(
                        Icons.check_circle_outline,
                        color: foreground,
                        size: 14,
                      ),
                      const SizedBox(width: 2),
                    ],
                    Flexible(
                      child: Text(
                        reviewed ? 'Revisado' : 'Por revisar',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 13,
                          height: 1.1,
                        ),
                      ),
                    ),
                    if (!reviewed)
                      Icon(Icons.chevron_right, color: foreground, size: 14),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _sheetTextField({
  required String keyName,
  required TextEditingController controller,
  required String label,
  TextInputType? keyboardType,
  TextCapitalization textCapitalization = TextCapitalization.none,
  int minLines = 1,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.m),
    child: TextField(
      key: ValueKey(keyName),
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      minLines: minLines,
      maxLines: minLines == 1 ? 1 : 4,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );
}

class _PreparationSheet extends StatelessWidget {
  const _PreparationSheet({
    required this.mode,
    required this.notesController,
    required this.checkedItems,
    required this.busy,
    required this.onChecklistChanged,
    required this.onSave,
    required this.onCopy,
    required this.onContract,
  });

  final BuySellMode mode;
  final TextEditingController notesController;
  final Set<String> checkedItems;
  final bool busy;
  final void Function(String item, bool checked) onChecklistChanged;
  final VoidCallback onSave;
  final VoidCallback onCopy;
  final VoidCallback? onContract;

  @override
  Widget build(BuildContext context) {
    final items = _checklistItems(mode);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (context, controller) {
        return ListView(
          controller: controller,
          padding: EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.l,
            AppSpacing.l,
            MediaQuery.paddingOf(context).bottom + AppSpacing.l,
          ),
          children: [
            Text(
              mode == BuySellMode.buy
                  ? 'Preparar mi compra'
                  : 'Preparar mi venta',
              style: AppTextStyles.h1,
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              buySellMandatoryCopy,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.navy.withValues(alpha: 0.70),
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            for (final item in items)
              CheckboxListTile(
                key: ValueKey('buy-sell-check-$item'),
                value: checkedItems.contains(item),
                onChanged: (value) => onChecklistChanged(item, value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text(_checklistLabel(item, mode)),
              ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              key: const ValueKey('buy-sell-notes'),
              controller: notesController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Notas privadas',
                hintText: 'Observaciones opcionales',
                prefixIcon: Icon(Icons.notes_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            if (onContract != null) ...[
              OutlinedButton.icon(
                key: const ValueKey('buy-sell-open-contract'),
                onPressed: onContract,
                icon: const Icon(Icons.description_outlined),
                label: const Text('Preparar texto de compraventa'),
              ),
              const SizedBox(height: AppSpacing.s),
            ],
            FilledButton.icon(
              key: const ValueKey('buy-sell-save-draft'),
              onPressed: busy ? null : onSave,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar progreso'),
            ),
            const SizedBox(height: AppSpacing.s),
            OutlinedButton.icon(
              key: const ValueKey('buy-sell-copy-summary'),
              onPressed: onCopy,
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copiar resumen'),
            ),
          ],
        );
      },
    );
  }
}

class _CandidateVehicleSheet extends ConsumerStatefulWidget {
  const _CandidateVehicleSheet({required this.initial});

  final BuySellCandidateVehicle initial;

  @override
  ConsumerState<_CandidateVehicleSheet> createState() =>
      _CandidateVehicleSheetState();
}

class _CandidateVehicleSheetState
    extends ConsumerState<_CandidateVehicleSheet> {
  late final TextEditingController _plateController;
  late final TextEditingController _brandLineController;
  late final TextEditingController _modelYearController;
  late final TextEditingController _cityController;
  late final TextEditingController _notesController;
  late bool _cityConfirmed;

  @override
  void initState() {
    super.initState();
    _plateController = TextEditingController(text: widget.initial.plate);
    _brandLineController = TextEditingController(
      text: widget.initial.brandLine,
    );
    _modelYearController = TextEditingController(
      text: widget.initial.modelYear,
    );
    _cityController = TextEditingController(
      text: widget.initial.registrationCity,
    );
    _notesController = TextEditingController(text: widget.initial.notes);
    _cityConfirmed = widget.initial.registrationCityConfirmed;
  }

  @override
  void dispose() {
    _plateController.dispose();
    _brandLineController.dispose();
    _modelYearController.dispose();
    _cityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.l,
        AppSpacing.l,
        MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.paddingOf(context).bottom +
            AppSpacing.l,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Datos del vehículo',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              'Solo se guardan en esta preparación. No se crea un vehículo en Garaje.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.navy.withValues(alpha: 0.70),
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            _sheetTextField(
              keyName: 'buy-sell-candidate-plate',
              controller: _plateController,
              label: 'Placa',
              textCapitalization: TextCapitalization.characters,
            ),
            _sheetTextField(
              keyName: 'buy-sell-candidate-brand-line',
              controller: _brandLineController,
              label: 'Marca y línea',
            ),
            _sheetTextField(
              keyName: 'buy-sell-candidate-model-year',
              controller: _modelYearController,
              label: 'Modelo / año',
            ),
            OutlinedButton.icon(
              key: const ValueKey('buy-sell-candidate-city'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.search),
              label: Text(
                _cityController.text.isEmpty
                    ? 'Seleccionar ciudad de matrícula (opcional)'
                    : '${_cityController.text}${_cityConfirmed ? '' : ' · Confirma en catálogo'}',
              ),
              onPressed: () async {
                final city = await showModalBottomSheet<RegistrationCity>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => const _CityFallbackSheet(
                    title: 'Ciudad de matrícula',
                    message: 'Selecciona el municipio y departamento que figuran en la matrícula.',
                  ),
                );
                if (city != null && mounted) {
                  setState(() {
                    _cityController.text = city.displayName;
                    _cityConfirmed = true;
                  });
                }
              },
            ),
            if (_cityController.text.isNotEmpty)
              TextButton.icon(
                onPressed: () => setState(() {
                  _cityController.clear();
                  _cityConfirmed = false;
                }),
                icon: const Icon(Icons.close),
                label: const Text('Quitar ciudad'),
              ),
            _sheetTextField(
              keyName: 'buy-sell-candidate-notes',
              controller: _notesController,
              label: 'Notas del vehículo',
              minLines: 2,
            ),
            const SizedBox(height: AppSpacing.m),
            FilledButton.icon(
              key: const ValueKey('buy-sell-save-candidate-data'),
              onPressed: () {
                Navigator.of(context).pop(
                  BuySellCandidateVehicle(
                    plate: _plateController.text.toUpperCase(),
                    brandLine: _brandLineController.text,
                    modelYear: _modelYearController.text,
                    registrationCity: _cityController.text,
                    registrationCityConfirmed: _cityConfirmed,
                    notes: _notesController.text,
                  ),
                );
              },
              icon: const Icon(Icons.check),
              label: const Text('Guardar datos'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContractSheet extends StatefulWidget {
  const _ContractSheet({
    required this.vehiclePlateController,
    required this.vehicleDescriptionController,
    required this.buyerNameController,
    required this.sellerNameController,
    required this.cityController,
    required this.priceController,
    required this.dateController,
    required this.notesController,
    required this.onSave,
    required this.onCopy,
  });

  final TextEditingController vehiclePlateController;
  final TextEditingController vehicleDescriptionController;
  final TextEditingController buyerNameController;
  final TextEditingController sellerNameController;
  final TextEditingController cityController;
  final TextEditingController priceController;
  final TextEditingController dateController;
  final TextEditingController notesController;
  final VoidCallback onSave;
  final VoidCallback onCopy;

  @override
  State<_ContractSheet> createState() => _ContractSheetState();
}

class _ContractSheetState extends State<_ContractSheet> {
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.50,
      maxChildSize: 0.96,
      builder: (context, controller) {
        return ListView(
          controller: controller,
          padding: EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.l,
            AppSpacing.l,
            MediaQuery.paddingOf(context).bottom + AppSpacing.l,
          ),
          children: [
            const Text(
              'Texto de compraventa',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              'Completa solo lo que necesites. No se genera PDF en esta fase.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.navy.withValues(alpha: 0.70),
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            _sheetTextField(
              keyName: 'buy-sell-contract-vehicle-plate',
              controller: widget.vehiclePlateController,
              label: 'Placa del vehículo',
            ),
            _sheetTextField(
              keyName: 'buy-sell-contract-vehicle',
              controller: widget.vehicleDescriptionController,
              label: 'Datos básicos del vehículo',
            ),
            _sheetTextField(
              keyName: 'buy-sell-contract-buyer',
              controller: widget.buyerNameController,
              label: 'Comprador',
            ),
            _sheetTextField(
              keyName: 'buy-sell-contract-seller',
              controller: widget.sellerNameController,
              label: 'Vendedor',
            ),
            _sheetTextField(
              keyName: 'buy-sell-contract-city',
              controller: widget.cityController,
              label: 'Ciudad',
            ),
            _sheetTextField(
              keyName: 'buy-sell-contract-price',
              controller: widget.priceController,
              label: 'Precio',
              keyboardType: TextInputType.number,
            ),
            _sheetTextField(
              keyName: 'buy-sell-contract-date',
              controller: widget.dateController,
              label: 'Fecha',
            ),
            _sheetTextField(
              keyName: 'buy-sell-contract-notes',
              controller: widget.notesController,
              label: 'Observaciones',
              minLines: 2,
            ),
            const SizedBox(height: AppSpacing.m),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.input),
                border: Border.all(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: Text(
                  _previewText(),
                  key: const ValueKey('buy-sell-contract-preview'),
                  style: AppTextStyles.caption,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            FilledButton.icon(
              key: const ValueKey('buy-sell-save-contract'),
              onPressed: widget.onSave,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar borrador'),
            ),
            const SizedBox(height: AppSpacing.s),
            OutlinedButton.icon(
              key: const ValueKey('buy-sell-copy-contract'),
              onPressed: widget.onCopy,
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copiar texto'),
            ),
          ],
        );
      },
    );
  }

  Widget _sheetTextField({
    required String keyName,
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    int minLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.m),
      child: TextField(
        key: ValueKey(keyName),
        controller: controller,
        keyboardType: keyboardType,
        minLines: minLines,
        maxLines: minLines == 1 ? 1 : 4,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  String _previewText() {
    String value(TextEditingController controller, String fallback) {
      final text = controller.text.trim();
      return text.isEmpty ? fallback : text;
    }

    return 'En ${value(widget.cityController, '[ciudad]')}, '
        '${value(widget.sellerNameController, '[vendedor]')} vende a '
        '${value(widget.buyerNameController, '[comprador]')} el vehículo '
        '${value(widget.vehicleDescriptionController, '[datos del vehículo]')} '
        'placa ${value(widget.vehiclePlateController, '[placa]')} por '
        '${value(widget.priceController, '[valor]')}.';
  }
}

class _CityFallbackSheet extends ConsumerStatefulWidget {
  const _CityFallbackSheet({required this.title, required this.message});

  final String title;
  final String message;

  @override
  ConsumerState<_CityFallbackSheet> createState() => _CityFallbackSheetState();
}

class _CityFallbackSheetState extends ConsumerState<_CityFallbackSheet> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(registrationCityCatalogProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: .85,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList.list(
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(widget.message, style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('buy-sell-city-fallback-search'),
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Buscar ciudad',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            catalog.when(
              data: (catalog) {
                final records = catalog.search(_searchController.text);
                if (records.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Sin coincidencias.'),
                    ),
                  );
                }
                return SliverList.builder(
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final city = records[index];
                    return ListTile(
                      key: ValueKey('buy-sell-city-${city.displayName}'),
                      leading: const Icon(Icons.location_city_outlined),
                      title: Text(city.municipality),
                      subtitle: Text(city.department),
                      onTap: () => Navigator.of(context).pop(city),
                    );
                  },
                );
              },
              error: (_, _) => SliverToBoxAdapter(
                child: Column(
                  children: [
                    const Text('No se pudo cargar el catálogo de ciudades.'),
                    TextButton.icon(
                      onPressed: () =>
                          ref.invalidate(registrationCityCatalogProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
              loading: () => const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoSheet extends StatelessWidget {
  const _InfoSheet({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.s,
        AppSpacing.l,
        MediaQuery.paddingOf(context).bottom + AppSpacing.l,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.s),
          Text(body, style: AppTextStyles.body),
        ],
      ),
    );
  }
}

List<String> _checklistItems(BuySellMode mode) {
  return switch (mode) {
    BuySellMode.buy => const [
      BuySellPreparationStepIds.comparendos,
      BuySellPreparationStepIds.taxes,
      BuySellPreparationStepIds.transfer,
      BuySellPreparationStepIds.appraisal,
      BuySellPreparationStepIds.documents,
      BuySellPreparationStepIds.paymentDelivery,
    ],
    BuySellMode.sell => const [
      BuySellPreparationStepIds.comparendos,
      BuySellPreparationStepIds.taxes,
      BuySellPreparationStepIds.documents,
      BuySellPreparationStepIds.appraisal,
      'saleContract',
      BuySellPreparationStepIds.transfer,
    ],
  };
}

String _checklistLabel(String item, BuySellMode mode) {
  if (mode == BuySellMode.buy) {
    return _purchaseSteps.where((step) => step.id == item).firstOrNull?.title ??
        item;
  }
  return switch (item) {
    BuySellPreparationStepIds.comparendos => 'Comparendos y paz y salvo',
    BuySellPreparationStepIds.taxes => 'Impuestos y obligaciones',
    BuySellPreparationStepIds.documents => 'SOAT, tecnomecánica y documentos',
    BuySellPreparationStepIds.appraisal => 'Peritaje o revisión disponible',
    'saleContract' => 'Texto de compraventa',
    BuySellPreparationStepIds.transfer => 'Cita y traspaso',
    _ => item,
  };
}

String _candidateSummary(BuySellCandidateVehicle candidate) {
  final parts = [
    if (candidate.plate.trim().isNotEmpty) candidate.plate.trim(),
    if (candidate.brandLine.trim().isNotEmpty) candidate.brandLine.trim(),
    if (candidate.modelYear.trim().isNotEmpty)
      'Modelo ${candidate.modelYear.trim()}',
    if (candidate.registrationCity.trim().isNotEmpty)
      candidate.registrationCity.trim(),
  ];
  return parts.isEmpty ? 'Datos agregados.' : parts.join(' · ');
}
