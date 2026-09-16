import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/design_system/branding.dart';
import '../../garage/data/vehicle_profile.dart';
import '../../garage/presentation/vehicle_plate_badge.dart';
import '../../visual_assets/presentation/visual_asset_widgets.dart';
import '../data/wallet_models.dart';

const documentsTextStyle = TextStyle(
  fontSize: 14,
  height: 1.35,
  color: AppColors.navy,
);
const documentsStrongStyle = TextStyle(
  fontSize: 14,
  height: 1.35,
  fontWeight: FontWeight.w700,
  color: AppColors.navy,
);

String walletDocumentLabel(WalletDocumentType type) => switch (type) {
  WalletDocumentType.identityCard => 'Cédula de ciudadanía',
  WalletDocumentType.driverLicense => 'Licencia de conducción',
  WalletDocumentType.trafficLicense => 'Licencia de tránsito',
  WalletDocumentType.rtm => 'Tecnomecánica',
  _ => type.label,
};

String walletDocumentStatus(WalletDocument? document) {
  if (document == null) return 'Sin copia';
  if (document.pdf != null) {
    final pages = int.tryParse(document.metadata['pdfPageCount'] ?? '');
    if (pages == null || pages < 1) return 'PDF guardado';
    return pages == 1 ? 'PDF · 1 página' : 'PDF · $pages páginas';
  }
  if (document.type.isDriverDocument ||
      document.type == WalletDocumentType.trafficLicense) {
    if (document.front != null && document.back == null) return 'Solo frente';
    if (document.front == null && document.back != null) return 'Solo reverso';
  }
  return document.sides.isEmpty ? 'Sin copia' : 'Copia guardada';
}

String walletVehicleLabel(VehicleProfile vehicle) {
  final nickname = vehicle.nickname?.trim() ?? '';
  if (nickname.isNotEmpty) return nickname;
  final description = [vehicle.brand, vehicle.model]
      .whereType<String>()
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .join(' ');
  return description.isEmpty ? 'Mi vehículo' : description;
}

class DocumentsPersonalCards extends StatelessWidget {
  const DocumentsPersonalCards({
    required this.drivers,
    required this.copies,
    required this.onOpen,
    required this.onRetry,
    super.key,
  });

  final List<WalletDriver> drivers;
  final Map<String, AsyncValue<List<WalletDocument>>> copies;
  final void Function(WalletDriver, WalletDocumentType, WalletDocument?) onOpen;
  final ValueChanged<WalletDriver> onRetry;

  /// Includes both cards and their gap; independent of asynchronous copy state.
  static double measureHeight(
    BuildContext context,
    double width,
    int driverCount,
  ) => _PersonalLayout.measure(context, width, driverCount).height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _PersonalLayout.measure(
          context,
          constraints.maxWidth,
          drivers.length,
        );
        final ordered = [
          ...drivers.where((driver) => driver.isPrincipal),
          ...drivers.where((driver) => !driver.isPrincipal),
        ];
        Widget card(WalletDocumentType type) {
          return _PersonalCard(
            key: ValueKey('documents-personal-${type.name}'),
            type: type,
            drivers: ordered,
            copies: copies,
            layout: layout,
            onOpen: onOpen,
            onRetry: onRetry,
          );
        }

        return SizedBox(
          height: layout.height,
          child: layout.stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    card(WalletDocumentType.identityCard),
                    const SizedBox(height: 8),
                    card(WalletDocumentType.driverLicense),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: card(WalletDocumentType.identityCard)),
                    const SizedBox(width: 8),
                    Expanded(child: card(WalletDocumentType.driverLicense)),
                  ],
                ),
        );
      },
    );
  }
}

TextStyle _measuredStyle(BuildContext context, TextStyle style) {
  final resolved = Theme.of(context).textTheme.bodyMedium!.merge(style);
  return resolved.copyWith(
    inherit: false,
    letterSpacing: 0,
    fontWeight: MediaQuery.boldTextOf(context)
        ? FontWeight.bold
        : resolved.fontWeight,
  );
}

Size _measureText(
  BuildContext context,
  String text,
  double width,
  TextStyle style,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: _measuredStyle(context, style)),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    locale: Localizations.maybeLocaleOf(context),
  )..layout(maxWidth: math.max(1, width));
  final size = painter.size;
  painter.dispose();
  return size;
}

const _personalStatuses = [
  'Sin copia',
  'PDF guardado',
  'Solo frente',
  'Solo reverso',
  'Copia guardada',
  'Cargando',
  'Error',
];

// Keep the 14 sp type size; two-line rows need less leading than body prose.
const _personalRowStyle = TextStyle(
  fontSize: 14,
  height: 1.2,
  color: AppColors.navy,
);
final _personalOrdinalStyle = _personalRowStyle.copyWith(
  fontWeight: FontWeight.w700,
);

class _PersonalLayout {
  const _PersonalLayout({
    required this.stacked,
    required this.titleHeight,
    required this.rowHeight,
    required this.ordinalWidth,
    required this.driverCount,
  });

  final bool stacked;
  final double titleHeight;
  final double rowHeight;
  final double ordinalWidth;
  final int driverCount;
  double get verticalPadding => stacked ? 8 : 16;
  double get titleGap => stacked ? 4 : 8;
  TextStyle get titleStyle =>
      stacked ? _personalOrdinalStyle : documentsStrongStyle;
  double get cardHeight =>
      verticalPadding * 2 + titleHeight + titleGap + driverCount * rowHeight;
  double get height => stacked ? cardHeight * 2 + 8 : cardHeight;

  static _PersonalLayout measure(
    BuildContext context,
    double width,
    int driverCount,
  ) {
    final ordinalWidth = ['1', '2']
        .map(
          (text) => _measureText(
            context,
            text,
            double.infinity,
            _personalOrdinalStyle,
          ).width,
        )
        .reduce(math.max);
    final rowChrome = 18 + 2 + ordinalWidth + 4 + 20 + 4;
    final halfContentWidth = (width - 8) / 2 - 24;
    final titleWords = [
      walletDocumentLabel(WalletDocumentType.identityCard),
      walletDocumentLabel(WalletDocumentType.driverLicense),
    ].expand((text) => text.split(' '));
    bool wordFits(String word, double available, TextStyle style) =>
        _measureText(context, word, double.infinity, style).width <= available;
    // Reflow when a complete word would no longer fit the two-column layout.
    final stacked =
        titleWords.any(
          (word) => !wordFits(word, halfContentWidth, documentsStrongStyle),
        ) ||
        _personalStatuses
            .expand((text) => text.split(' '))
            .any(
              (word) => !wordFits(
                word,
                halfContentWidth - rowChrome,
                _personalRowStyle,
              ),
            );
    final contentWidth = (stacked ? width : (width - 8) / 2) - 24;
    final titleHeight =
        [
              walletDocumentLabel(WalletDocumentType.identityCard),
              walletDocumentLabel(WalletDocumentType.driverLicense),
              if (!stacked) 'Cédula de\nciudadanía',
            ]
            .map(
              (text) => _measureText(
                context,
                text,
                contentWidth,
                stacked ? _personalOrdinalStyle : documentsStrongStyle,
              ).height,
            )
            .reduce(math.max);
    final statusHeight = _personalStatuses
        .map(
          (text) => _measureText(
            context,
            text,
            contentWidth - rowChrome,
            _personalRowStyle,
          ).height,
        )
        .reduce(math.max);
    final ordinalHeight = _measureText(
      context,
      '2',
      ordinalWidth,
      _personalOrdinalStyle,
    ).height;
    // Android PdfRenderer exposes a positive 32-bit page count. Reserve its
    // widest decimal representation; this is a layout sample, not a page cap.
    final pdfCountHeight = _measureText(
      context,
      '8888888888 pág.',
      contentWidth,
      _personalRowStyle,
    ).height;
    final pdfLabelHeight = _measureText(
      context,
      'PDF ·',
      contentWidth - rowChrome,
      _personalRowStyle,
    ).height;
    final pdfHeight =
        math.max(20, math.max(ordinalHeight, pdfLabelHeight)) + pdfCountHeight;
    return _PersonalLayout(
      stacked: stacked,
      titleHeight: titleHeight,
      rowHeight: math.max(
        48,
        math.max(pdfHeight, math.max(statusHeight, ordinalHeight)) +
            (stacked ? 0 : 4),
      ),
      ordinalWidth: ordinalWidth,
      driverCount: driverCount,
    );
  }
}

class _PersonalCard extends StatelessWidget {
  const _PersonalCard({
    required this.type,
    required this.drivers,
    required this.copies,
    required this.layout,
    required this.onOpen,
    required this.onRetry,
    super.key,
  });

  final WalletDocumentType type;
  final List<WalletDriver> drivers;
  final Map<String, AsyncValue<List<WalletDocument>>> copies;
  final _PersonalLayout layout;
  final void Function(WalletDriver, WalletDocumentType, WalletDocument?) onOpen;
  final ValueChanged<WalletDriver> onRetry;

  @override
  Widget build(BuildContext context) {
    final dark = type == WalletDocumentType.identityCard;
    return SizedBox(
      height: layout.cardHeight,
      child: Material(
        color: dark ? AppColors.navy : const Color(0xFFE8F5F3),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: layout.verticalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: layout.titleHeight,
                child: Text(
                  !layout.stacked && type == WalletDocumentType.identityCard
                      ? 'Cédula de\nciudadanía'
                      : walletDocumentLabel(type),
                  semanticsLabel: walletDocumentLabel(type),
                  style: _measuredStyle(
                    context,
                    layout.titleStyle,
                  ).copyWith(color: dark ? Colors.white : AppColors.navy),
                ),
              ),
              SizedBox(height: layout.titleGap),
              for (final driver in drivers) _driverRow(context, driver),
            ],
          ),
        ),
      ),
    );
  }

  Widget _driverRow(BuildContext context, WalletDriver driver) {
    final state =
        copies[driver.id] ?? const AsyncLoading<List<WalletDocument>>();
    final loading = state.isLoading;
    final failed = !loading && state.hasError;
    final document = loading || failed
        ? null
        : state.asData?.value
              .where(
                (entry) =>
                    entry.type == type &&
                    entry.owner == WalletOwner.driver(driver.id),
              )
              .firstOrNull;
    final fullStatus = loading
        ? 'Cargando'
        : failed
        ? 'Error al cargar'
        : walletDocumentStatus(document);
    final status = failed ? 'Error' : fullStatus;
    final pages = document?.pdf == null
        ? null
        : int.tryParse(document!.metadata['pdfPageCount'] ?? '');
    final knownPages = pages != null && pages > 0;
    final foreground = type == WalletDocumentType.identityCard
        ? Colors.white
        : AppColors.navy;
    final actionColor = type == WalletDocumentType.identityCard
        ? Colors.white
        : AppColors.teal;
    final ordinal = driver.isPrincipal ? 1 : 2;
    final action = loading
        ? ''
        : failed
        ? 'Reintentar'
        : document == null
        ? 'Agregar'
        : 'Ver documento';
    final label =
        'Conductor $ordinal, ${driver.displayName}, ${walletDocumentLabel(type)}, $fullStatus${action.isEmpty ? '' : ', $action'}';
    final VoidCallback? onTap = loading
        ? null
        : failed
        ? () => onRetry(driver)
        : () => onOpen(driver, type, document);
    return SizedBox(
      key: ValueKey('documents-personal-row-${type.name}-${driver.id}'),
      height: layout.rowHeight,
      child: Semantics(
        label: label,
        button: true,
        enabled: onTap != null,
        onTap: onTap,
        excludeSemantics: true,
        child: Tooltip(
          message: label,
          excludeFromSemantics: true,
          child: InkWell(
            key: ValueKey(
              'documents-personal-${loading
                  ? 'loading'
                  : failed
                  ? 'error'
                  : document == null
                  ? 'add'
                  : 'open'}-${type.name}-${driver.id}',
            ),
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 18, color: foreground),
                    const SizedBox(width: 2),
                    SizedBox(
                      width: layout.ordinalWidth,
                      child: Text(
                        '$ordinal',
                        style: _measuredStyle(
                          context,
                          _personalOrdinalStyle,
                        ).copyWith(color: foreground),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        knownPages ? 'PDF ·' : status,
                        style: _measuredStyle(
                          context,
                          _personalRowStyle,
                        ).copyWith(color: foreground),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      loading
                          ? Icons.hourglass_empty
                          : failed
                          ? Icons.refresh
                          : document == null
                          ? Icons.add
                          : Icons.chevron_right,
                      size: 20,
                      color: actionColor,
                    ),
                  ],
                ),
                if (knownPages)
                  Text(
                    '$pages pág.',
                    style: _measuredStyle(
                      context,
                      _personalRowStyle,
                    ).copyWith(color: foreground),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DocumentsVehicleCarousel extends StatefulWidget {
  const DocumentsVehicleCarousel({
    required this.vehicles,
    required this.initialVehicleId,
    required this.onOpen,
    super.key,
  });

  final List<VehicleProfile> vehicles;
  final String? initialVehicleId;
  final ValueChanged<VehicleProfile> onOpen;

  /// Includes heading, controls, card, 112 dp image and its 4 dp inner margin.
  static double minimumHeight(
    BuildContext context,
    double width,
    List<VehicleProfile> vehicles,
  ) => vehicles.isEmpty
      ? 0
      : _VehicleLayout.measure(context, width, vehicles).minimumHeight;

  @override
  State<DocumentsVehicleCarousel> createState() =>
      _DocumentsVehicleCarouselState();
}

class _DocumentsVehicleCarouselState extends State<DocumentsVehicleCarousel> {
  late final PageController _controller;
  String? _focusedId;

  @override
  void initState() {
    super.initState();
    final index = math.max(
      0,
      widget.vehicles.indexWhere((v) => v.id == widget.initialVehicleId),
    );
    _focusedId = widget.vehicles.isEmpty ? null : widget.vehicles[index].id;
    _controller = PageController(initialPage: index, viewportFraction: .88);
  }

  @override
  void didUpdateWidget(covariant DocumentsVehicleCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.vehicles.isEmpty) return;
    final previousIndex = oldWidget.vehicles.indexWhere(
      (v) => v.id == _focusedId,
    );
    final index = math.max(
      0,
      widget.vehicles.indexWhere(
        (v) => v.id == (_focusedId ?? widget.initialVehicleId),
      ),
    );
    _focusedId = widget.vehicles[index].id;
    if (index != previousIndex || oldWidget.vehicles.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) _controller.jumpToPage(index);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.vehicles.isEmpty) return const SizedBox.shrink();
    final index = math.max(
      0,
      widget.vehicles.indexWhere((v) => v.id == _focusedId),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _VehicleLayout.measure(
          context,
          constraints.maxWidth,
          widget.vehicles,
        );
        final height = constraints.hasBoundedHeight
            ? math.max(layout.minimumHeight, constraints.maxHeight)
            : layout.minimumHeight;
        final imageHeight = 120 + height - layout.minimumHeight;
        return SizedBox(
          height: height,
          child: Column(
            children: [
              _heading(context, index, layout),
              const SizedBox(height: 8),
              SizedBox(
                height: height - layout.headingHeight - 8,
                child: PageView.builder(
                  key: const ValueKey('documents-vehicle-carousel'),
                  controller: _controller,
                  itemCount: widget.vehicles.length,
                  onPageChanged: (index) =>
                      setState(() => _focusedId = widget.vehicles[index].id),
                  itemBuilder: (context, index) {
                    final vehicle = widget.vehicles[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          key: ValueKey('documents-vehicle-card-${vehicle.id}'),
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => widget.onOpen(vehicle),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Column(
                              children: [
                                if (!layout.nameInFooter) ...[
                                  SizedBox(
                                    height: layout.nameHeight,
                                    width: double.infinity,
                                    child: _vehicleIdentity(
                                      context,
                                      vehicle,
                                      layout.showPlateNumber,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                SizedBox(
                                  key: ValueKey(
                                    'documents-vehicle-image-${vehicle.id}',
                                  ),
                                  height: imageHeight,
                                  width: double.infinity,
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: VehicleVisualImage(
                                      vehicle: vehicle,
                                      cacheWidth: 640,
                                      fallbackBuilder: (_) => Center(
                                        child: Icon(
                                          vehicle.kind == VehicleKind.motorcycle
                                              ? Icons.two_wheeler
                                              : Icons.directions_car_outlined,
                                          size: 64,
                                          color: AppColors.navy,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  key: ValueKey(
                                    'documents-vehicle-footer-${vehicle.id}',
                                  ),
                                  height: layout.footerHeight,
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 96,
                                        height: layout.plateHeight,
                                        child: Center(
                                          child: MediaQuery(
                                            data: MediaQuery.of(context)
                                                .copyWith(
                                                  textScaler:
                                                      TextScaler.noScaling,
                                                ),
                                            child: VehiclePlateBadge(
                                              vehicle: vehicle,
                                              compact: true,
                                              compactWidth: 96,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            if (layout.nameInFooter) ...[
                                              SizedBox(
                                                height: layout.nameHeight,
                                                child: _vehicleIdentity(
                                                  context,
                                                  vehicle,
                                                  layout.showPlateNumber,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                            ],
                                            Align(
                                              alignment: AlignmentDirectional
                                                  .centerEnd,
                                              child: SizedBox(
                                                height: layout.buttonHeight,
                                                width: layout.iconAction
                                                    ? 48
                                                    : double.infinity,
                                                child: layout.iconAction
                                                    ? IconButton.filled(
                                                        key: ValueKey(
                                                          'documents-vehicle-open-${vehicle.id}',
                                                        ),
                                                        tooltip:
                                                            'Ver documentos de ${walletVehicleLabel(vehicle)}',
                                                        onPressed: () => widget
                                                            .onOpen(vehicle),
                                                        icon: const Icon(
                                                          Icons
                                                              .description_outlined,
                                                        ),
                                                      )
                                                    : FilledButton(
                                                        key: ValueKey(
                                                          'documents-vehicle-open-${vehicle.id}',
                                                        ),
                                                        onPressed: () => widget
                                                            .onOpen(vehicle),
                                                        style: FilledButton.styleFrom(
                                                          minimumSize:
                                                              const Size(
                                                                48,
                                                                48,
                                                              ),
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 8,
                                                              ),
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                          ),
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            Expanded(
                                                              child: Text(
                                                                'Ver documentos',
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                                style:
                                                                    _measuredStyle(
                                                                      context,
                                                                      documentsStrongStyle,
                                                                    ).copyWith(
                                                                      color: Colors
                                                                          .white,
                                                                    ),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            const Icon(
                                                              Icons
                                                                  .chevron_right,
                                                              size: 20,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _heading(BuildContext context, int index, _VehicleLayout layout) {
    final title = Text(
      'Vehículos',
      style: _measuredStyle(context, documentsStrongStyle),
    );
    final controls = SizedBox(
      width: layout.controlsWidth,
      height: layout.controlsHeight,
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              tooltip: 'Vehículo anterior',
              onPressed: index == 0
                  ? null
                  : () => _controller.previousPage(
                      duration: AppMotion.carouselSnap,
                      curve: Curves.easeOut,
                    ),
              icon: const Icon(Icons.chevron_left),
            ),
          ),
          Expanded(
            child: Text(
              '${index + 1} de ${widget.vehicles.length}',
              key: const ValueKey('documents-vehicle-counter'),
              textAlign: TextAlign.center,
              style: _measuredStyle(context, documentsTextStyle),
            ),
          ),
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              tooltip: 'Vehículo siguiente',
              onPressed: index == widget.vehicles.length - 1
                  ? null
                  : () => _controller.nextPage(
                      duration: AppMotion.carouselSnap,
                      curve: Curves.easeOut,
                    ),
              icon: const Icon(Icons.chevron_right),
            ),
          ),
        ],
      ),
    );
    return SizedBox(
      key: const ValueKey('documents-vehicle-heading'),
      height: layout.headingHeight,
      child: layout.inlineHeading
          ? Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: 8),
                controls,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title,
                const SizedBox(height: 4),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: controls,
                ),
              ],
            ),
    );
  }
}

Widget _vehicleIdentity(
  BuildContext context,
  VehicleProfile vehicle,
  bool showPlateNumber,
) => Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    Text(
      walletVehicleLabel(vehicle),
      style: _measuredStyle(context, documentsStrongStyle),
    ),
    if (showPlateNumber)
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          vehicle.plate.trim().toUpperCase(),
          key: ValueKey('documents-vehicle-readable-plate-${vehicle.id}'),
          semanticsLabel: 'Placa ${vehicle.plate.trim().toUpperCase()}',
          style: _measuredStyle(context, documentsTextStyle),
        ),
      ),
  ],
);

double _documentsPlateHeight(VehicleProfile vehicle) {
  final registration = vehicle.registrationCity?.trim() ?? '';
  return ColombianPlateBadge.detailedHeight(
    plate: vehicle.plate,
    registration: vehicle.kind == VehicleKind.motorcycle || registration.isEmpty
        ? 'COLOMBIA'
        : registration.toUpperCase(),
    width: 96,
    compactWidth: 96,
    textScaler: TextScaler.noScaling,
  );
}

class _VehicleLayout {
  const _VehicleLayout({
    required this.inlineHeading,
    required this.headingHeight,
    required this.controlsWidth,
    required this.controlsHeight,
    required this.nameHeight,
    required this.plateHeight,
    required this.buttonHeight,
    required this.iconAction,
    required this.nameInFooter,
    required this.showPlateNumber,
  });

  final bool inlineHeading;
  final double headingHeight;
  final double controlsWidth;
  final double controlsHeight;
  final double nameHeight;
  final double plateHeight;
  final double buttonHeight;
  final bool iconAction;
  final bool nameInFooter;
  final bool showPlateNumber;
  double get footerHeight =>
      math.max(plateHeight, buttonHeight + (nameInFooter ? nameHeight + 8 : 0));
  double get minimumHeight =>
      headingHeight +
      8 +
      16 +
      (nameInFooter ? 0 : nameHeight + 8) +
      120 +
      8 +
      footerHeight;

  static _VehicleLayout measure(
    BuildContext context,
    double width,
    List<VehicleProfile> vehicles,
  ) {
    final contentWidth = math.max(1.0, width * .88 - 8 - 32);
    final showPlateNumber = MediaQuery.textScalerOf(context).scale(14) > 14;
    double identityHeight(VehicleProfile vehicle, double width) =>
        _measureText(
          context,
          walletVehicleLabel(vehicle),
          width,
          documentsStrongStyle,
        ).height +
        (showPlateNumber
            ? 4 +
                  _measureText(
                    context,
                    vehicle.plate.trim().toUpperCase(),
                    width,
                    documentsTextStyle,
                  ).height
            : 0);
    final nameHeight = vehicles
        .map((vehicle) => identityHeight(vehicle, contentWidth))
        .reduce(math.max);
    final plateHeight = vehicles.map(_documentsPlateHeight).reduce(math.max);
    final buttonTextWidth = contentWidth - 96 - 8 - 44;
    final iconAction = ['Ver', 'documentos'].any(
      (word) =>
          _measureText(
            context,
            word,
            double.infinity,
            documentsStrongStyle,
          ).width >
          buttonTextWidth,
    );
    final buttonHeight = iconAction
        ? 48.0
        : math.max(
            48.0,
            _measureText(
                  context,
                  'Ver documentos',
                  buttonTextWidth,
                  documentsStrongStyle,
                ).height +
                16,
          );
    final footerTextWidth = contentWidth - 96 - 8;
    final footerNameHeight = vehicles
        .map((vehicle) => identityHeight(vehicle, footerTextWidth))
        .reduce(math.max);
    final nameInFooter =
        vehicles.every(
          (vehicle) => walletVehicleLabel(vehicle)
              .split(RegExp(r'\s+'))
              .every(
                (word) =>
                    _measureText(
                      context,
                      word,
                      double.infinity,
                      documentsStrongStyle,
                    ).width <=
                    footerTextWidth,
              ),
        ) &&
        (!showPlateNumber ||
            vehicles.every(
              (vehicle) =>
                  _measureText(
                    context,
                    vehicle.plate.trim().toUpperCase(),
                    double.infinity,
                    documentsTextStyle,
                  ).width <=
                  footerTextWidth,
            )) &&
        math.max(plateHeight, footerNameHeight + 8 + buttonHeight) <=
            nameHeight + 8 + math.max(plateHeight, buttonHeight);
    final counters = [
      for (var index = 1; index <= vehicles.length; index++)
        '$index de ${vehicles.length}',
    ];
    final countWidth = counters
        .map(
          (text) => _measureText(
            context,
            text,
            double.infinity,
            documentsTextStyle,
          ).width,
        )
        .reduce(math.max);
    final controlsWidth = math.min(width, 96 + countWidth);
    final countHeight = counters
        .map(
          (text) => _measureText(
            context,
            text,
            controlsWidth - 96,
            documentsTextStyle,
          ).height,
        )
        .reduce(math.max);
    final controlsHeight = math.max(48.0, countHeight);
    final title = _measureText(
      context,
      'Vehículos',
      double.infinity,
      documentsStrongStyle,
    );
    final inline = title.width + 8 + controlsWidth <= width;
    return _VehicleLayout(
      inlineHeading: inline,
      headingHeight: inline
          ? math.max(title.height, controlsHeight)
          : _measureText(
                  context,
                  'Vehículos',
                  width,
                  documentsStrongStyle,
                ).height +
                4 +
                controlsHeight,
      controlsWidth: controlsWidth,
      controlsHeight: controlsHeight,
      nameHeight: nameInFooter ? footerNameHeight : nameHeight,
      plateHeight: plateHeight,
      buttonHeight: buttonHeight,
      iconAction: iconAction,
      nameInFooter: nameInFooter,
      showPlateNumber: showPlateNumber,
    );
  }
}

class DocumentsLoadState extends StatelessWidget {
  const DocumentsLoadState({required this.label, this.onRetry, super.key});
  final String label;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: documentsTextStyle),
        if (onRetry != null)
          TextButton.icon(
            onPressed: onRetry,
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar', style: documentsStrongStyle),
          )
        else
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    ),
  );
}
