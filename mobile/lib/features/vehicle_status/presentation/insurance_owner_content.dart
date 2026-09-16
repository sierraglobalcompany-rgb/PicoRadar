import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/theme/app_tokens.dart';
import '../../garage/data/vehicle_profile.dart';
import '../../garage/presentation/vehicle_display.dart';
import '../../garage/presentation/vehicle_plate_badge.dart';
import '../../visual_assets/presentation/visual_asset_widgets.dart';
import '../data/insurance_directory.dart';
import '../domain/vehicle_obligation.dart';
import 'insurance_owner_sheets.dart';
import 'insurance_quote_demo.dart';

// Both gates are required: a production flavor cannot enable the preview.
final insurancePreviewProvider = Provider<bool>(
  (ref) =>
      appFlavor == 'dev' && const String.fromEnvironment('APP_ENV') == 'dev',
);

const _body = TextStyle(fontSize: 14, height: 1.35, letterSpacing: 0);
const _strong = TextStyle(
  fontSize: 16,
  height: 1.35,
  fontWeight: FontWeight.w700,
  letterSpacing: 0,
);

String _name(VehicleProfile v) {
  final nick = v.nickname?.trim() ?? '';
  if (nick.isNotEmpty) return nick;
  final label = [
    v.brand,
    v.model,
  ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' ');
  return label.isEmpty ? 'Mi vehículo' : label;
}

double _textHeight(
  BuildContext context,
  String text,
  double width,
  TextStyle style,
) {
  final resolved = Theme.of(context).textTheme.bodyMedium!
      .merge(style)
      .copyWith(inherit: false, letterSpacing: 0);
  final painter = TextPainter(
    text: TextSpan(text: text, style: resolved),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: math.max(1, width));
  final height = painter.height;
  painter.dispose();
  return height;
}

bool _hasPolicy(VehicleObligation? value) =>
    (value?.details['providerName']?.trim().isNotEmpty ?? false) ||
    (value?.details['policyNumber']?.trim().isNotEmpty ?? false) ||
    value?.dueDate != null ||
    value?.startDate != null;

class InsuranceOwnerScreen extends ConsumerStatefulWidget {
  const InsuranceOwnerScreen({this.vehicleId, super.key});
  final String? vehicleId;
  @override
  ConsumerState<InsuranceOwnerScreen> createState() =>
      _InsuranceOwnerScreenState();
}

class _InsuranceOwnerScreenState extends ConsumerState<InsuranceOwnerScreen> {
  String? _focusId;
  bool _resolved = false;
  PageController? _pages;
  List<String> _ids = const [];
  bool _syncPending = false;
  bool _syncScheduled = false;

  void _queuePageSync() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (!mounted || !(_pages?.hasClients ?? false)) return;
      final index = _ids.indexOf(_focusId ?? '');
      if (index >= 0) _pages!.jumpToPage(index);
      _syncPending = false;
    });
  }

  @override
  void dispose() {
    _pages?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant InsuranceOwnerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vehicleId != widget.vehicleId) {
      _resolved = false;
      _syncPending = true;
      _queuePageSync();
    }
  }

  void _select(VehicleProfile vehicle, List<VehicleProfile> items) {
    setState(() => _focusId = vehicle.id);
    _syncPending = true;
    _queuePageSync();
  }

  Future<void> _chooseVehicle(List<VehicleProfile> items) async {
    final chosen = await showModalBottomSheet<VehicleProfile>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheet).height * .65,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Cambiar vehículo', style: _strong),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final v in items)
                      ListTile(
                        minVerticalPadding: 12,
                        leading: Icon(vehicleIcon(v)),
                        title: Text(_name(v)),
                        subtitle: Text(v.plate),
                        trailing: v.id == _focusId
                            ? const Icon(Icons.check, color: AppColors.teal)
                            : null,
                        onTap: () => Navigator.pop(sheet, v),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null && mounted) _select(chosen, items);
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  Widget _navigation(Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: _InsuranceBack(onPressed: _goBack),
        ),
      ),
      Expanded(child: child),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(vehicleListProvider);
    final active = ref.watch(activeVehicleProvider);
    return Scaffold(
      body: SafeArea(
        child: vehicles.when(
          loading: () =>
              _navigation(const Center(child: CircularProgressIndicator())),
          error: (_, _) => _navigation(
            _retry(
              'No se pudieron leer los vehículos.',
              () => ref.invalidate(vehicleListProvider),
            ),
          ),
          data: (items) {
            if (!_resolved && widget.vehicleId == null && active.hasError) {
              return _navigation(
                _retry(
                  'No se pudo leer el vehículo favorito.',
                  () => ref.invalidate(activeVehicleProvider),
                ),
              );
            }
            if (!_resolved && widget.vehicleId == null && active.isLoading) {
              return _navigation(
                const Center(child: CircularProgressIndicator()),
              );
            }
            if (!_resolved) {
              _focusId =
                  widget.vehicleId ??
                  active.asData?.value?.id ??
                  (items.isEmpty ? null : items.first.id);
              _resolved = true;
            }
            final index = items.indexWhere((v) => v.id == _focusId);
            if (index < 0) return _navigation(_empty(items));
            final vehicle = items[index];
            _pages ??= PageController(
              initialPage: index,
              viewportFraction: .90,
              onAttach: (_) {
                _syncPending = true;
                _queuePageSync();
              },
            );
            final ids = items.map((v) => v.id).toList();
            if (_ids.join(',') != ids.join(',')) {
              _ids = ids;
              _syncPending = true;
              _queuePageSync();
            }
            final states = {
              for (final v in items)
                v.id: ref.watch(
                  vehicleObligationProvider((
                    v.id,
                    VehicleObligationType.insurance,
                  )),
                ),
            };
            return _content(items, vehicle, states);
          },
        ),
      ),
    );
  }

  Widget _retry(String text, VoidCallback retry) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: _body),
          TextButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    ),
  );

  Widget _empty(List<VehicleProfile> items) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        const Spacer(),
        Text(
          items.isEmpty
              ? 'Agrega un vehículo para registrar su póliza.'
              : 'Este vehículo ya no está disponible.',
          style: _strong,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () =>
              items.isEmpty ? context.go('/garage') : _chooseVehicle(items),
          icon: Icon(items.isEmpty ? Icons.add : Icons.directions_car),
          label: Text(items.isEmpty ? 'Agregar vehículo' : 'Cambiar vehículo'),
        ),
        const Spacer(),
        SizedBox(height: 88, child: _footer(null, null, level: 2)),
      ],
    ),
  );

  void _openVehicle(
    VehicleProfile vehicle,
    AsyncValue<VehicleObligation?> state,
  ) {
    state.when(
      loading: () {},
      error: (_, _) => ref.invalidate(
        vehicleObligationProvider((
          vehicle.id,
          VehicleObligationType.insurance,
        )),
      ),
      data: (value) {
        if (_hasPolicy(value)) {
          showInsuranceDocuments(context, ref, vehicle);
        } else {
          showInsuranceEditor(context, ref, vehicle, value);
        }
      },
    );
  }

  Widget _content(
    List<VehicleProfile> items,
    VehicleProfile vehicle,
    Map<String, AsyncValue<VehicleObligation?>> states,
  ) {
    final preview = ref.watch(insurancePreviewProvider);
    final state = states[vehicle.id]!;
    final value = state.asData?.value;
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final plateBand =
            48.0 +
            (scale > 1
                ? items
                          .map(
                            (v) => _textHeight(
                              context,
                              v.plate,
                              width - 40,
                              _body,
                            ),
                          )
                          .reduce(math.max) +
                      4
                : 0);
        // Reserve both policy states before async loads. Levels only simplify
        // secondary content; the page never changes into tabs or another view.
        late _InsuranceLayout layout;
        for (var level = 0; level <= 3; level++) {
          final inlineActions = level >= 2 && scale <= 1.1;
          final nameHeight = items
              .map(
                (v) => _textHeight(
                  context,
                  level == 3 ? 'Mi vehículo' : _name(v),
                  width - (level <= 1 ? 176 : 80),
                  _strong,
                ),
              )
              .reduce(math.max);
          final heading = math.max(48.0, nameHeight + 8);
          final banner = preview
              ? _InsuranceBanner.height(context, width, level)
              : 56.0;
          final panel = level <= 1
              ? 120.0
              : math.max(
                  inlineActions ? 48.0 : 56.0,
                  _textHeight(
                        context,
                        'Registrar mi póliza',
                        width - 100,
                        _strong,
                      ) +
                      16,
                );
          final footer = inlineActions
              ? 48.0
              : level == 0
              ? 112.0
              : math.max(
                  64.0,
                  (level == 1
                              ? [
                                  'Directorio de aseguradoras',
                                  'Necesito asistencia',
                                  'Mi póliza y documentos',
                                ]
                              : ['Directorio', 'Asistencia', 'Mi póliza'])
                          .map(
                            (label) => _textHeight(
                              context,
                              label,
                              (width - 41) / 2 - (level == 1 ? 68 : 8),
                              _body.copyWith(fontWeight: FontWeight.w700),
                            ),
                          )
                          .reduce(math.max) +
                      (level == 1 ? 20 : 38),
                );
          layout = _InsuranceLayout(
            level: level,
            banner: banner,
            heading: heading,
            plate: plateBand,
            panel: panel,
            footer: footer,
            art:
                box.maxHeight -
                banner -
                heading -
                plateBand -
                panel -
                footer -
                (inlineActions ? 0 : 8),
          );
          // Allocate the recovered plate/margin space to contained vehicle art.
          if (layout.art >= (preview && scale <= 1.1 ? 144 : 112)) break;
        }
        final inlineActions = layout.level >= 2 && scale <= 1.1;
        return Column(
          key: const ValueKey('insurance-owner-content'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (preview)
              _InsuranceBanner(
                level: layout.level,
                heightValue: layout.banner,
                configured: _hasPolicy(value),
                onBack: _goBack,
                onQuote: state.isLoading || state.hasError
                    ? null
                    : () => showInsuranceQuoteDemo(context, vehicle),
              )
            else
              SizedBox(
                height: layout.banner,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _InsuranceBack(onPressed: _goBack),
                  ),
                ),
              ),
            SizedBox(
              height: layout.heading,
              child: _vehicleHeading(items, vehicle, layout.level),
            ),
            Expanded(child: _vehicleArtwork(items, states)),
            SizedBox(
              height: layout.plate,
              child: _plate(vehicle, items, scale),
            ),
            if (!inlineActions) const SizedBox(height: 4),
            SizedBox(
              key: const ValueKey('insurance-policy-panel'),
              height: layout.panel,
              child: state.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Center(
                  child: Tooltip(
                    message: 'No se pudo leer la póliza. Reintentar',
                    child: TextButton.icon(
                      onPressed: () => ref.invalidate(
                        vehicleObligationProvider((
                          vehicle.id,
                          VehicleObligationType.insurance,
                        )),
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar póliza', style: _body),
                    ),
                  ),
                ),
                data: (_) => _policyPanel(
                  vehicle,
                  value,
                  layout.level,
                  inlineActions: inlineActions,
                ),
              ),
            ),
            SizedBox(
              key: const ValueKey('insurance-footer'),
              height: layout.footer,
              child: _footer(
                vehicle,
                value,
                level: layout.level,
                inlineActions: inlineActions,
              ),
            ),
            if (!inlineActions) const SizedBox(height: 4),
          ],
        );
      },
    );
  }

  Widget _vehicleHeading(
    List<VehicleProfile> items,
    VehicleProfile vehicle,
    int level,
  ) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        Expanded(
          child: Tooltip(
            message: _name(vehicle),
            child: Text(
              level == 3 &&
                      _textHeight(
                            context,
                            _name(vehicle),
                            MediaQuery.sizeOf(context).width - 80,
                            _strong,
                          ) >
                          48
                  ? 'Mi vehículo'
                  : _name(vehicle),
              key: const ValueKey('insurance-vehicle-name'),
              semanticsLabel: _name(vehicle),
              style: _strong,
            ),
          ),
        ),
        if (level <= 1)
          TextButton(
            key: const ValueKey('insurance-vehicle-selector'),
            onPressed: () => _chooseVehicle(items),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Cambiar vehículo', style: _body),
                Icon(Icons.chevron_right, size: 20),
              ],
            ),
          )
        else
          IconButton(
            key: const ValueKey('insurance-vehicle-selector'),
            tooltip: 'Cambiar vehículo',
            onPressed: () => _chooseVehicle(items),
            icon: const Icon(Icons.swap_horiz),
          ),
      ],
    ),
  );

  Widget _vehicleArtwork(
    List<VehicleProfile> items,
    Map<String, AsyncValue<VehicleObligation?>> states,
  ) => PageView.builder(
    key: const ValueKey('insurance-vehicle-carousel'),
    controller: _pages,
    itemCount: items.length,
    onPageChanged: (index) {
      if (!_syncPending && items[index].id != _focusId) {
        setState(() => _focusId = items[index].id);
      }
    },
    itemBuilder: (context, index) {
      final v = items[index];
      return Semantics(
        button: true,
        label: '${_name(v)}, ${v.plate}. Abrir mi póliza',
        child: GestureDetector(
          key: ValueKey('insurance-vehicle-open-${v.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => _openVehicle(v, states[v.id]!),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: VehicleVisualImage(
              vehicle: v,
              cacheWidth:
                  (MediaQuery.sizeOf(context).width *
                          MediaQuery.devicePixelRatioOf(context))
                      .round(),
              fallbackBuilder: (_) => Icon(vehicleIcon(v), size: 48),
            ),
          ),
        ),
      );
    },
  );

  Widget _plate(
    VehicleProfile vehicle,
    List<VehicleProfile> items,
    double scale,
  ) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      SizedBox(
        height: 48,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              key: const ValueKey('insurance-plate'),
              width: 80,
              height: 80 / 2.15,
              child: MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.noScaling),
                child: VehiclePlateBadge(
                  vehicle: vehicle,
                  compact: true,
                  compactWidth: 80,
                  micro: true,
                  microNumberFontSize: 20,
                ),
              ),
            ),
            if (items.length > 1)
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Vehículo anterior',
                      onPressed: items.indexOf(vehicle) > 0
                          ? () => _select(
                              items[items.indexOf(vehicle) - 1],
                              items,
                            )
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text(
                      '${items.indexOf(vehicle) + 1}/${items.length}',
                      style: _body,
                    ),
                  ],
                ),
              ),
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const ValueKey('insurance-documents'),
                    tooltip: 'Póliza y documentos',
                    onPressed: () =>
                        showInsuranceDocuments(context, ref, vehicle),
                    icon: const Icon(Icons.description_outlined, size: 22),
                  ),
                  if (items.length > 1)
                    IconButton(
                      tooltip: 'Vehículo siguiente',
                      onPressed: items.indexOf(vehicle) < items.length - 1
                          ? () => _select(
                              items[items.indexOf(vehicle) + 1],
                              items,
                            )
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      if (scale > 1)
        Text(
          vehicle.plate,
          key: const ValueKey('insurance-readable-plate'),
          style: _body,
        ),
    ],
  );

  Widget _policyPanel(
    VehicleProfile vehicle,
    VehicleObligation? value,
    int level, {
    bool inlineActions = false,
  }) {
    final has = _hasPolicy(value);
    final company = ref
        .watch(insuranceDirectoryProvider)
        .asData
        ?.value
        .resolve(value?.details['providerId'], value?.details['providerName']);
    final channels = company?.verifiedChannels ?? const <InsuranceChannel>[];
    final phones = channels.where((c) => c.kind == 'phone');
    final whats = channels.where((c) => c.kind == 'whatsapp');
    final provider =
        company?.name ?? value?.details['providerName'] ?? 'Mi aseguradora';
    final providerHeight = _textHeight(
      context,
      provider,
      MediaQuery.sizeOf(context).width - 168,
      _strong,
    );
    final providerFits = providerHeight <= 44;
    final showProviderLabel =
        providerFits &&
        providerHeight +
                _textHeight(
                  context,
                  'Mi aseguradora',
                  MediaQuery.sizeOf(context).width - 168,
                  _body,
                ) <=
            56;
    final compact = level >= 2;
    if (!has) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!compact) ...[
              const Divider(height: 1),
              const SizedBox(height: 4),
              Expanded(
                child: Row(
                  children: [
                    _roundIcon(Icons.description_outlined, size: 36),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Aún no has registrado una póliza',
                        style: _strong,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
            ],
            SizedBox(
              height: compact ? null : 48,
              child: FilledButton(
                key: const ValueKey('insurance-register'),
                onPressed: () =>
                    showInsuranceEditor(context, ref, vehicle, value),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text('Registrar mi póliza', style: _strong),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.chevron_right, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 8,
            vertical: inlineActions ? 0 : 4,
          ),
          child: Column(
            children: [
              Expanded(
                child: InkWell(
                  key: const ValueKey('insurance-edit'),
                  onTap: () =>
                      showInsuranceEditor(context, ref, vehicle, value),
                  child: Row(
                    children: [
                      _roundIcon(Icons.shield_outlined, dark: true, size: 36),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Tooltip(
                          message: 'Aseguradora registrada: $provider. Cambiar',
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!compact && showProviderLabel)
                                Text(
                                  'Mi aseguradora',
                                  style: _body.copyWith(color: Colors.white70),
                                ),
                              Text(
                                providerFits ? provider : 'Mi póliza',
                                semanticsLabel:
                                    'Aseguradora registrada: $provider. Cambiar',
                                style: _strong.copyWith(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (!compact)
                        Text(
                          'Cambiar',
                          style: _body.copyWith(color: const Color(0xff76e4df)),
                        ),
                      const Icon(
                        Icons.chevron_right,
                        color: Color(0xff76e4df),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 4),
                SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      Expanded(
                        child: _contactButton(
                          keyName: 'insurance-call',
                          label: phones.isEmpty ? 'Contactos' : 'Llamar',
                          icon: Icons.call_outlined,
                          color: const Color(0xff09677e),
                          onTap: () => showInsuranceAssistance(
                            context,
                            ref,
                            vehicle,
                            value,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _contactButton(
                          keyName: 'insurance-whatsapp',
                          label: whats.isEmpty ? 'Canales' : 'WhatsApp',
                          icon: whats.isEmpty
                              ? Icons.info_outline
                              : Icons.chat_outlined,
                          color: AppColors.teal,
                          onTap: () => showInsuranceAssistance(
                            context,
                            ref,
                            vehicle,
                            value,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _contactButton({
    required String keyName,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) => FilledButton(
    key: ValueKey(keyName),
    style: FilledButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    onPressed: onTap,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 8),
        Flexible(child: Text(label, style: _strong)),
      ],
    ),
  );

  Widget _footer(
    VehicleProfile? vehicle,
    VehicleObligation? value, {
    required int level,
    bool inlineActions = false,
  }) {
    final has = _hasPolicy(value) && vehicle != null;
    final docs = vehicle == null
        ? () => showInsuranceDirectory(context, ref)
        : () => showInsuranceDocuments(context, ref, vehicle);
    void assistance() => showInsuranceAssistance(context, ref, vehicle, value);
    if (has && level == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Expanded(
              child: _action(
                keyName: 'insurance-assistance',
                label: 'Necesito asistencia',
                icon: Icons.local_shipping_outlined,
                onTap: assistance,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _action(
                keyName: 'insurance-directory-or-docs',
                label: 'Mi póliza y documentos',
                icon: Icons.description_outlined,
                onTap: docs,
              ),
            ),
          ],
        ),
      );
    }
    final short = level >= 2;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Divider(height: inlineActions ? 0 : 1),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _action(
                    keyName: 'insurance-directory-or-docs',
                    label: has
                        ? (short ? 'Mi póliza' : 'Mi póliza y documentos')
                        : (short ? 'Directorio' : 'Directorio de aseguradoras'),
                    semantics: has
                        ? 'Mi póliza y documentos'
                        : 'Directorio de aseguradoras',
                    icon: has ? Icons.description_outlined : Icons.apartment,
                    onTap: has
                        ? docs
                        : () => showInsuranceDirectory(context, ref),
                    compact: short,
                    inlineActions: inlineActions,
                  ),
                ),
                const VerticalDivider(width: 9, indent: 12, endIndent: 12),
                Expanded(
                  child: _action(
                    keyName: 'insurance-assistance',
                    label: short ? 'Asistencia' : 'Necesito asistencia',
                    semantics: 'Necesito asistencia',
                    icon: Icons.call_outlined,
                    onTap: assistance,
                    compact: short,
                    inlineActions: inlineActions,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _action({
    required String keyName,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    String? semantics,
    bool compact = false,
    bool inlineActions = false,
  }) => Semantics(
    button: true,
    label: semantics ?? label,
    excludeSemantics: true,
    child: InkWell(
      key: ValueKey(keyName),
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: compact && inlineActions
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: AppColors.teal, size: 22),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        style: _body.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                  ],
                )
              : compact
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: AppColors.teal, size: 22),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: _body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    if (compact)
                      Icon(icon, color: AppColors.teal, size: 22)
                    else
                      _roundIcon(icon, size: 36),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        style: _body.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    if (!compact)
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.teal,
                        size: 16,
                      ),
                  ],
                ),
        ),
      ),
    ),
  );

  Widget _roundIcon(IconData icon, {double size = 40, bool dark = false}) =>
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: dark ? AppColors.teal : const Color(0xffe3f2f3),
        ),
        child: Icon(
          icon,
          size: size * .60,
          color: dark ? Colors.white : AppColors.teal,
        ),
      );
}

class _InsuranceLayout {
  const _InsuranceLayout({
    required this.level,
    required this.banner,
    required this.heading,
    required this.plate,
    required this.panel,
    required this.footer,
    required this.art,
  });
  final int level;
  final double banner, heading, plate, panel, footer, art;
}

class _InsuranceBack extends StatelessWidget {
  const _InsuranceBack({required this.onPressed, this.onImage = false});
  final VoidCallback onPressed;
  final bool onImage;
  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('insurance-back'),
    width: 48,
    height: 48,
    child: IconButton(
      tooltip: 'Volver',
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      icon: Container(
        key: const ValueKey('insurance-back-surface'),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onImage
              ? Colors.white.withValues(alpha: .16)
              : AppColors.navy.withValues(alpha: .08),
        ),
        child: Icon(
          Icons.arrow_back,
          color: onImage ? Colors.white : AppColors.navy,
          size: 24,
        ),
      ),
    ),
  );
}

class _InsuranceBanner extends StatelessWidget {
  const _InsuranceBanner({
    required this.configured,
    required this.heightValue,
    required this.level,
    required this.onBack,
    required this.onQuote,
  });
  final bool configured;
  final double heightValue;
  final int level;
  final VoidCallback onBack;
  final VoidCallback? onQuote;
  static const quoteTitle = 'Encuentra opciones para asegurar tu vehículo';
  static const compareTitle = 'Compara opciones para tu próxima póliza';
  static const quoteDescription =
      'Solicita una cotización con un aliado de seguros.';
  static const compareDescription =
      'Consulta coberturas y formas de pago con un aliado.';
  static const descriptionStyle = TextStyle(
    fontSize: 14,
    height: 1.35,
    color: Colors.white,
    letterSpacing: 0,
  );
  static bool showDescription(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(14) <= 15.4;
  static String headline(BuildContext context, bool configured) {
    if (!showDescription(context)) {
      return configured ? compareTitle : quoteTitle;
    }
    return configured
        ? 'Compara opciones\npara tu próxima\npóliza'
        : 'Encuentra opciones\npara asegurar\ntu vehículo';
  }

  static double titleFraction(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(14) > 21 ? 1 : .72;
  static bool showHeadline(BuildContext context, int level) =>
      level < 3 || MediaQuery.textScalerOf(context).scale(14) <= 15.4;
  static TextStyle titleStyle(int level) => TextStyle(
    fontSize: level == 0 ? 24 : 22,
    height: 1.4,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    letterSpacing: 0,
  );
  static double height(BuildContext context, double width, int level) {
    final cta = math.max(
      48.0,
      _textHeight(context, 'Comparar mi póliza', width - 84, _strong) + 16,
    );
    if (!showHeadline(context, level)) return 56 + cta + 12;
    final titleWidth = (width - 32) * titleFraction(context);
    final title = math.max(
      _textHeight(
        context,
        headline(context, false),
        titleWidth,
        titleStyle(level),
      ),
      _textHeight(
        context,
        headline(context, true),
        titleWidth,
        titleStyle(level),
      ),
    );
    final description = showDescription(context)
        ? math.max(
                _textHeight(
                  context,
                  quoteDescription,
                  titleWidth,
                  descriptionStyle,
                ),
                _textHeight(
                  context,
                  compareDescription,
                  titleWidth,
                  descriptionStyle,
                ),
              ) +
              8
        : 0.0;
    final content =
        56 + title + 8 + description + cta + (level == 0 ? 48 : 0) + 12;
    return showDescription(context) ? math.max(279.0, content) : content;
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('insurance-banner'),
    height: heightValue,
    child: Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: AppColors.navy,
          child: Image.asset(
            'assets/pico/insurance_owner_banner_v1.png',
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
            cacheWidth:
                (MediaQuery.sizeOf(context).width *
                        MediaQuery.devicePixelRatioOf(context))
                    .round(),
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => const SizedBox.expand(),
          ),
        ),
        if (level >= 3)
          ColoredBox(color: AppColors.navy.withValues(alpha: .28)),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    _InsuranceBack(onPressed: onBack, onImage: true),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Vista previa',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (level > 0)
                      IconButton(
                        tooltip: 'Conocer al aliado',
                        onPressed: () => _about(context),
                        color: Colors.white,
                        icon: const Icon(Icons.info_outline),
                      ),
                  ],
                ),
              ),
              if (showHeadline(context, level)) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: FractionallySizedBox(
                    widthFactor: titleFraction(context),
                    child: Text(
                      headline(context, configured),
                      key: const ValueKey('insurance-banner-title'),
                      semanticsLabel: configured ? compareTitle : quoteTitle,
                      style: titleStyle(level),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (showDescription(context)) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: FractionallySizedBox(
                      widthFactor: titleFraction(context),
                      child: Text(
                        configured ? compareDescription : quoteDescription,
                        key: const ValueKey('insurance-banner-description'),
                        style: descriptionStyle,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
              Expanded(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const ValueKey('insurance-quote'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xffffdf32),
                          foregroundColor: AppColors.navy,
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: onQuote,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                configured
                                    ? 'Comparar mi póliza'
                                    : 'Cotizar mi póliza',
                                style: _strong,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (level == 0)
                SizedBox(
                  height: 48,
                  child: TextButton.icon(
                    onPressed: () => _about(context),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    icon: const Icon(Icons.chevron_right),
                    iconAlignment: IconAlignment.end,
                    label: const Text('Conocer al aliado', style: _body),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  void _about(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    builder: (_) => const SafeArea(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Vista previa de una futura alianza. No hay un aliado receptor ni se envían solicitudes o datos personales.',
          style: _body,
        ),
      ),
    ),
  );
}
