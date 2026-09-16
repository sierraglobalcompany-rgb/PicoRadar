import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_tokens.dart';
import '../../garage/data/vehicle_profile.dart';
import '../../vehicle_status/data/private_vehicle_document_store.dart';
import '../application/wallet_providers.dart';
import '../data/wallet_models.dart';
import 'documents_async_content.dart';
import 'documents_driver_sheet.dart';
import 'documents_recovery_notice.dart';
import 'documents_sheets.dart';
import 'documents_widgets.dart';
import 'wallet_access_gate.dart';
import 'wallet_actions.dart';

const vehicleDocumentPrivateCopy = 'Copia privada cifrada en este dispositivo.';
const vehicleDocumentOfficialWarning =
    'Guardar un archivo no confirma su vigencia oficial.';
// Settings still invalidates the legacy list during device-data cleanup.
final vehicleDocumentsProvider =
    FutureProvider.family<List<PrivateVehicleDocumentMetadata>, String>(
      (ref, vehicleId) => ref
          .watch(privateVehicleDocumentStoreProvider)
          .listForVehicle(vehicleId),
    );

class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen(this.vehicleId, {super.key});
  final String? vehicleId;
  @override
  Widget build(BuildContext context) =>
      WalletAccessGate(child: _DocumentsBody(vehicleId: vehicleId));
}

class _DocumentsBody extends ConsumerWidget {
  const _DocumentsBody({required this.vehicleId});
  final String? vehicleId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drivers = ref.watch(walletDriversProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            key: const ValueKey('documents-compact-page'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DocumentsHeader(
                onProtection: WalletActions(context, ref).protection,
                onManage: () => showWalletDriverManagement(context, ref),
                onBack: () => context.canPop()
                    ? context.pop()
                    : context.go(AppRoute.home.path),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => DocumentsAsyncContent(
                    value: drivers,
                    builder: (items) {
                      final ordered = [...items]
                        ..sort((a, b) {
                          if (a.isPrincipal != b.isPrincipal) {
                            return a.isPrincipal ? -1 : 1;
                          }
                          return a.id.compareTo(b.id);
                        });
                      if (ordered.isEmpty) {
                        return DocumentsLoadState(
                          label: 'No se pudo cargar el conductor.',
                          onRetry: () => ref.invalidate(walletDriversProvider),
                        );
                      }
                      return SizedBox(
                        height: constraints.maxHeight,
                        child: _DocumentsContent(
                          drivers: ordered,
                          vehicleId: vehicleId,
                        ),
                      );
                    },
                    loadingLabel: 'Cargando conductores',
                    errorLabel: 'No se pudieron leer los conductores.',
                    onRetry: () => ref.invalidate(walletDriversProvider),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _PrivacyFooter(driver: drivers.asData?.value.firstOrNull),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentsContent extends ConsumerStatefulWidget {
  const _DocumentsContent({required this.drivers, required this.vehicleId});
  final List<WalletDriver> drivers;
  final String? vehicleId;
  @override
  ConsumerState<_DocumentsContent> createState() => _DocumentsContentState();
}

class _DocumentsContentState extends ConsumerState<_DocumentsContent> {
  int _tab = 0;
  final _vehicleCarouselKey = GlobalKey();
  Object? _layoutSignature;
  bool _split = false;

  @override
  Widget build(BuildContext context) {
    final copies = {
      for (final driver in widget.drivers)
        driver.id: ref.watch(
          walletDocumentsProvider(WalletOwner.driver(driver.id)),
        ),
    };
    final vehicles = ref.watch(vehicleListProvider);
    final items = vehicles.asData?.value ?? const <VehicleProfile>[];
    final favorite = ref.watch(activeVehicleProvider);
    final actions = WalletActions(context, ref);
    final personal = DocumentsPersonalCards(
      drivers: widget.drivers,
      copies: copies,
      onOpen: (driver, type, document) {
        if (document != null) {
          actions.view(document);
        } else {
          actions.add(
            WalletOwner.driver(driver.id),
            type,
            ownerLabel: driver.displayName,
          );
        }
      },
      onRetry: (driver) => ref.invalidate(
        walletDocumentsProvider(WalletOwner.driver(driver.id)),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final personalHeight = DocumentsPersonalCards.measureHeight(
          context,
          constraints.maxWidth,
          widget.drivers.length,
        );
        final vehicleMinimum = items.isEmpty
            ? 112.0
            : DocumentsVehicleCarousel.minimumHeight(
                context,
                constraints.maxWidth,
                items,
              );
        // Copy updates cannot switch presentation or move the current tab.
        final signature = (
          constraints.maxWidth,
          constraints.maxHeight,
          MediaQuery.textScalerOf(context),
          widget.drivers.map((d) => d.id).join('|'),
          items.map((v) => '${v.id}:${walletVehicleLabel(v)}').join('|'),
        );
        if (_layoutSignature != signature) {
          _layoutSignature = signature;
          _split = personalHeight + 8 + vehicleMinimum > constraints.maxHeight;
        }
        final initialId = items.any((v) => v.id == widget.vehicleId)
            ? widget.vehicleId
            : favorite.asData?.value?.id;
        final vehicleContent = vehicles.when(
          data: (list) {
            if (list.isEmpty) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Aún no tienes vehículos en tu garaje.',
                    style: documentsTextStyle,
                    textAlign: TextAlign.center,
                  ),
                  TextButton.icon(
                    onPressed: () => context.go(AppRoute.garage.path),
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar vehículo'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                ],
              );
            }
            if (initialId == null && favorite.isLoading) {
              return const DocumentsLoadState(label: 'Cargando vehículos');
            }
            return DocumentsVehicleCarousel(
              key: _vehicleCarouselKey,
              vehicles: list,
              initialVehicleId: initialId,
              onOpen: (vehicle) =>
                  showWalletVehicleDocuments(context, ref, vehicle),
            );
          },
          loading: () => const DocumentsLoadState(label: 'Cargando vehículos'),
          error: (_, _) => DocumentsLoadState(
            label: 'No se pudieron leer los vehículos.',
            onRetry: () => ref.invalidate(vehicleListProvider),
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_split) ...[
              _DocumentTabs(
                value: _tab,
                onChanged: (value) => setState(() => _tab = value),
              ),
              const SizedBox(height: 8),
            ],
            if (!_split) ...[
              SizedBox(height: personalHeight, child: personal),
              const SizedBox(height: 8),
              Expanded(child: vehicleContent),
            ] else
              Expanded(
                child: IndexedStack(
                  index: _tab,
                  sizing: StackFit.expand,
                  children: [
                    Align(alignment: Alignment.topCenter, child: personal),
                    vehicleContent,
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DocumentTabs extends StatelessWidget {
  const _DocumentTabs({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey('documents-local-tabs'),
    children: [
      for (var index = 0; index < 2; index++)
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: index == 0 ? 4 : 0,
              left: index == 1 ? 4 : 0,
            ),
            child: Semantics(
              selected: value == index,
              child: TextButton(
                key: ValueKey('documents-tab-$index'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.all(8),
                  foregroundColor: value == index
                      ? Colors.white
                      : AppColors.teal,
                  backgroundColor: value == index
                      ? AppColors.teal
                      : const Color(0xFFE8F5F3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => onChanged(index),
                child: Text(
                  index == 0 ? 'Conductor' : 'Vehículos',
                  style: documentsStrongStyle.copyWith(
                    color: value == index ? Colors.white : AppColors.teal,
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class _PrivacyFooter extends ConsumerWidget {
  const _PrivacyFooter({this.driver});
  final WalletDriver? driver;
  Future<void> _show(
    BuildContext context,
    WidgetRef ref, {
    bool recovery = false,
  }) async {
    if (!ref.read(walletSessionProvider).accessAllowed) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => DocumentsSessionSheet(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                recovery ? 'Copias por recuperar' : 'Privacidad y copias',
                style: documentsStrongStyle,
              ),
              const SizedBox(height: 8),
              if (recovery && driver != null)
                DocumentsRecoveryNotice(owner: WalletOwner.driver(driver!.id))
              else ...[
                const Text(
                  'Copias privadas cifradas en este dispositivo. No tienen respaldo automático.',
                  style: documentsTextStyle,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Copias de respaldo. No sustituyen los documentos oficiales. Guardar una copia no confirma su autenticidad ni vigencia.',
                  style: documentsTextStyle,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Puedes proteger toda la billetera con el desbloqueo del teléfono desde el candado.',
                  style: documentsTextStyle,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    for (final item
        in ref.watch(walletDriversProvider).asData?.value ?? <WalletDriver>[]) {
      ref.watch(walletDocumentsProvider(WalletOwner.driver(item.id)));
    }
    final recovery = ref
        .watch(walletStoreProvider)
        .migrationReport
        .needsRecovery;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - (recovery ? 56 : 0);
        final labelStyle = Theme.of(context).textTheme.bodyMedium!
            .merge(documentsTextStyle)
            .copyWith(
              inherit: false,
              letterSpacing: 0,
              fontWeight: MediaQuery.boldTextOf(context)
                  ? FontWeight.bold
                  : FontWeight.normal,
            );
        final label = TextPainter(
          text: TextSpan(text: 'Privacidad y copias', style: labelStyle),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final compact = label.width + 48 > width || label.height + 16 > 48;
        label.dispose();
        return SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (recovery)
                IconButton(
                  key: const ValueKey('documents-recovery-warning'),
                  tooltip:
                      'Copias por recuperar. La lista puede estar incompleta.',
                  onPressed: () => _show(context, ref, recovery: true),
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  icon: const Icon(
                    Icons.warning_amber_outlined,
                    color: AppColors.orange,
                  ),
                ),
              if (compact)
                IconButton(
                  key: const ValueKey('documents-privacy'),
                  tooltip: 'Privacidad y copias',
                  onPressed: () => _show(context, ref),
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  icon: const Icon(Icons.info_outline, color: AppColors.teal),
                )
              else
                TextButton.icon(
                  key: const ValueKey('documents-privacy'),
                  onPressed: () => _show(context, ref),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  icon: const Icon(Icons.info_outline, size: 20),
                  label: Text('Privacidad y copias', style: labelStyle),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DocumentsHeader extends StatelessWidget {
  const _DocumentsHeader({
    required this.onBack,
    required this.onProtection,
    required this.onManage,
  });
  final VoidCallback onBack;
  final VoidCallback onProtection;
  final VoidCallback onManage;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final titleStyle = Theme.of(context).textTheme.bodyMedium!
          .merge(AppTextStyles.h2)
          .copyWith(inherit: false, letterSpacing: 0);
      final title = Text('Documentos', style: titleStyle);
      final back = IconButton(
        tooltip: 'Volver',
        onPressed: onBack,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: const Icon(Icons.arrow_back, color: AppColors.navy),
      );
      final manage = IconButton(
        key: const ValueKey('documents-manage-drivers'),
        tooltip: 'Gestionar conductores',
        onPressed: onManage,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: const Icon(Icons.people_outline, color: AppColors.teal),
      );
      final protection = IconButton(
        key: const ValueKey('documents-protection'),
        tooltip: 'Protección de documentos',
        onPressed: onProtection,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: const Icon(Icons.lock_outline, color: AppColors.teal),
      );
      final painter = TextPainter(
        text: TextSpan(text: 'Documentos', style: titleStyle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final stacked = painter.width > math.max(1, constraints.maxWidth - 160);
      painter.dispose();
      if (stacked) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [back, const Spacer(), manage, protection]),
            const SizedBox(height: 8),
            title,
          ],
        );
      }
      return Row(
        children: [
          back,
          const SizedBox(width: 8),
          Expanded(child: title),
          const SizedBox(width: 8),
          manage,
          protection,
        ],
      );
    },
  );
}
