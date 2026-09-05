import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/design_system/branding.dart';
import '../../garage/data/vehicle_profile.dart';
import '../../garage/presentation/vehicle_display.dart';
import '../../home/data/home_banner_config.dart';
import '../data/private_vehicle_document_store.dart';
import '../data/vehicle_status_catalog.dart';
import '../domain/vehicle_obligation.dart';
import '../platform/external_launcher.dart';

class SoatRtmOwnerContent extends ConsumerWidget {
  const SoatRtmOwnerContent({
    required this.vehicle,
    required this.vehicles,
    required this.type,
    required this.obligation,
    required this.onEdit,
    required this.onSelectVehicle,
    super.key,
  });

  final VehicleProfile vehicle;
  final List<VehicleProfile> vehicles;
  final VehicleObligationType type;
  final VehicleObligation? obligation;
  final VoidCallback onEdit;
  final ValueChanged<VehicleProfile> onSelectVehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nowBogota = ref.watch(bogotaNowProvider);
    final documentType = _documentType(type);
    final document = ref.watch(
      privateVehicleDocumentProvider((vehicle.id, documentType)),
    );
    final metadata = document.asData?.value;
    final visualState = _visualState(
      obligation: obligation,
      hasDocument: metadata != null,
      nowBogota: nowBogota,
    );

    return ListView(
      key: ValueKey('owner-status-${type.value}'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m,
        AppSpacing.m,
        AppSpacing.m,
        AppSpacing.xxl,
      ),
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _VehicleSelectorCard(
                  vehicle: vehicle,
                  onTap: () => _showVehicleSelector(context),
                ),
                const SizedBox(height: AppSpacing.m),
                _StatusHero(
                  vehicle: vehicle,
                  type: type,
                  obligation: obligation,
                  visualState: visualState,
                ),
                const SizedBox(height: AppSpacing.m),
                _PrimaryAction(
                  type: type,
                  visualState: visualState,
                  hasDocument: metadata != null,
                  onEdit: onEdit,
                  onAttach: () => _attachDocument(context, ref),
                  onView: metadata == null
                      ? null
                      : () => _viewDocument(context, ref, metadata),
                  onFindCda: () => context.push('/apps/cda'),
                ),
                const SizedBox(height: AppSpacing.m),
                _DocumentCard(
                  type: type,
                  metadata: metadata,
                  errorMessage: document.error?.toString(),
                  onAttach: () => _attachDocument(context, ref),
                  onView: metadata == null
                      ? null
                      : () => _viewDocument(context, ref, metadata),
                  onDelete: metadata == null
                      ? null
                      : () => _deleteDocument(context, ref, metadata),
                ),
                const SizedBox(height: AppSpacing.m),
                _ReminderCard(
                  type: type,
                  vehicleId: vehicle.id,
                  obligation: obligation,
                ),
                const SizedBox(height: AppSpacing.m),
                _HistoryCard(type: type),
                const SizedBox(height: AppSpacing.m),
                _OfficialCheckCard(type: type),
                const SizedBox(height: AppSpacing.m),
                _EducationCard(type: type),
                const SizedBox(height: AppSpacing.m),
                _CommercialBanner(type: type),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showVehicleSelector(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              0,
              AppSpacing.l,
              AppSpacing.xl,
            ),
            itemBuilder: (context, index) {
              final item = vehicles[index];
              return ListTile(
                key: ValueKey('vehicle-selector-${item.id}'),
                leading: ColombianPlateBadge(plate: item.plate, compact: true),
                title: Text(_vehicleTitle(item)),
                subtitle: Text(vehicleTypeLabel(item)),
                trailing: item.id == vehicle.id
                    ? const Icon(Icons.check_circle, color: AppColors.teal)
                    : null,
                onTap: () {
                  Navigator.of(context).pop();
                  onSelectVehicle(item);
                },
              );
            },
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemCount: vehicles.length,
          ),
        );
      },
    );
  }

  Future<void> _attachDocument(BuildContext context, WidgetRef ref) async {
    final documentGateway = ref.read(vehicleDocumentGatewayProvider);
    final picked = await documentGateway.pickDocument();
    if (picked == null) {
      return;
    }
    try {
      await ref
          .read(privateVehicleDocumentStoreProvider)
          .importDocument(
            vehicleId: vehicle.id,
            documentType: _documentType(type),
            source: picked.file,
            originalName: picked.originalName,
            mimeType: picked.mimeType,
          );
    } finally {
      await documentGateway.clearTemporaryFiles();
    }
    ref.invalidate(
      privateVehicleDocumentProvider((vehicle.id, _documentType(type))),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_documentLabel(type)} guardado localmente.')),
      );
    }
  }

  Future<void> _viewDocument(
    BuildContext context,
    WidgetRef ref,
    PrivateVehicleDocumentMetadata metadata,
  ) async {
    final file = await ref
        .read(privateVehicleDocumentStoreProvider)
        .decryptForView(metadata);
    final opened = await ref
        .read(vehicleDocumentGatewayProvider)
        .openDocument(file);
    if (!opened) {
      await ref
          .read(privateVehicleDocumentStoreProvider)
          .purgeViewerCache(metadata: metadata);
    }
    if (context.mounted && !opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el documento.')),
      );
    }
  }

  Future<void> _deleteDocument(
    BuildContext context,
    WidgetRef ref,
    PrivateVehicleDocumentMetadata metadata,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar copia local'),
        content: const Text(
          'Se eliminará solo la copia guardada en este dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await ref.read(privateVehicleDocumentStoreProvider).delete(metadata);
    ref.invalidate(
      privateVehicleDocumentProvider((vehicle.id, _documentType(type))),
    );
  }
}

enum _OwnerVisualState { notConfigured, active, dueSoon, expired, unknown }

class _VehicleSelectorCard extends StatelessWidget {
  const _VehicleSelectorCard({required this.vehicle, required this.onTap});

  final VehicleProfile vehicle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        key: const ValueKey('owner-vehicle-selector'),
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.m),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              ColombianPlateBadge(plate: vehicle.plate, compact: true),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _vehicleTitle(vehicle),
                      style: AppTextStyles.bodyStrong,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Selecciona otro vehículo',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.navy.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_down, color: AppColors.navy),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusHero extends StatelessWidget {
  const _StatusHero({
    required this.vehicle,
    required this.type,
    required this.obligation,
    required this.visualState,
  });

  final VehicleProfile vehicle;
  final VehicleObligationType type;
  final VehicleObligation? obligation;
  final _OwnerVisualState visualState;

  @override
  Widget build(BuildContext context) {
    final details = obligation?.details ?? const <String, String>{};
    final color = _stateColor(visualState);
    final facts = _heroFacts(
      vehicle: vehicle,
      type: type,
      obligation: obligation,
      details: details,
      color: color,
    );
    return Container(
      key: ValueKey('owner-hero-${type.value}'),
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220B1B2F),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusChip(
                      label: _stateChip(type, visualState),
                      color: color,
                    ),
                    const SizedBox(height: AppSpacing.s),
                    Text(
                      _heroTitle(type, visualState),
                      style: AppTextStyles.h2.copyWith(
                        color: Colors.white,
                        fontSize: 26,
                        height: 1.06,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _heroSubtitle(type, visualState),
                      style: AppTextStyles.body.copyWith(
                        color: Colors.white.withValues(alpha: 0.86),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              _HeroMark(type: type, color: color),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          Divider(color: Colors.white.withValues(alpha: 0.22), height: 1),
          const SizedBox(height: AppSpacing.s),
          _HeroFactGrid(facts: facts),
        ],
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.type,
    required this.visualState,
    required this.hasDocument,
    required this.onEdit,
    required this.onAttach,
    required this.onFindCda,
    this.onView,
  });

  final VehicleObligationType type;
  final _OwnerVisualState visualState;
  final bool hasDocument;
  final VoidCallback onEdit;
  final VoidCallback onAttach;
  final VoidCallback? onView;
  final VoidCallback onFindCda;

  @override
  Widget build(BuildContext context) {
    final isRtm = type == VehicleObligationType.rtm;
    final label = isRtm
        ? 'BUSCAR CDA'
        : _soatPrimaryLabel(visualState, hasDocument);
    final action = isRtm
        ? onFindCda
        : _soatPrimaryAction(visualState, hasDocument);
    return FilledButton.icon(
      key: ValueKey('owner-primary-${type.value}'),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.plateYellow,
        foregroundColor: AppColors.navy,
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
      onPressed: action,
      icon: Icon(isRtm ? Icons.location_on_outlined : Icons.shield_outlined),
      label: Text(label),
    );
  }

  VoidCallback _soatPrimaryAction(
    _OwnerVisualState visualState,
    bool hasDocument,
  ) {
    return switch (visualState) {
      _OwnerVisualState.active => hasDocument ? (onView ?? onAttach) : onAttach,
      _OwnerVisualState.dueSoon ||
      _OwnerVisualState.expired ||
      _OwnerVisualState.notConfigured ||
      _OwnerVisualState.unknown => onEdit,
    };
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.type,
    required this.metadata,
    required this.errorMessage,
    required this.onAttach,
    this.onView,
    this.onDelete,
  });

  final VehicleObligationType type;
  final PrivateVehicleDocumentMetadata? metadata;
  final String? errorMessage;
  final VoidCallback onAttach;
  final VoidCallback? onView;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isSoat = type == VehicleObligationType.soat;
    final hasDocument = metadata != null;
    final body = errorMessage != null
        ? 'No se pudo leer la copia local.'
        : hasDocument
        ? (isSoat ? 'Póliza guardada' : 'Tu certificado está cargado.')
        : (isSoat
              ? 'No has guardado tu póliza.'
              : 'Aún no has cargado tu certificado.');
    return _SoftCard(
      keyName: 'owner-document-${type.value}',
      icon: isSoat ? Icons.description_outlined : Icons.fact_check_outlined,
      iconColor: AppColors.teal,
      title: isSoat ? 'Documento SOAT' : 'Mi certificado RTM',
      body: body,
      trailing: Wrap(
        spacing: AppSpacing.s,
        children: [
          FilledButton.tonal(
            key: ValueKey('owner-document-action-${type.value}'),
            onPressed: hasDocument ? onView : onAttach,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
              child: Text(
                hasDocument
                    ? (isSoat ? 'Ver SOAT' : 'Ver certificado')
                    : (isSoat ? 'Adjuntar SOAT' : 'Cargar certificado'),
              ),
            ),
          ),
          if (hasDocument)
            PopupMenuButton<String>(
              key: ValueKey('owner-document-menu-${type.value}'),
              onSelected: (value) {
                if (value == 'replace') {
                  onAttach();
                } else if (value == 'delete') {
                  onDelete?.call();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'replace', child: Text('Reemplazar')),
                PopupMenuItem(value: 'delete', child: Text('Eliminar copia')),
              ],
            ),
        ],
      ),
    );
  }
}

class _ReminderCard extends ConsumerWidget {
  const _ReminderCard({
    required this.type,
    required this.vehicleId,
    required this.obligation,
  });

  final VehicleObligationType type;
  final String vehicleId;
  final VehicleObligation? obligation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = obligation?.reminderEnabled ?? true;
    return _SoftCard(
      keyName: 'owner-reminder-${type.value}',
      icon: Icons.notifications_none,
      iconColor: AppColors.teal,
      title: enabled ? 'Recordatorio activo' : 'Recordatorio desactivado',
      body: enabled
          ? 'Te avisaremos 30, 7 y 1 día antes del vencimiento guardado.'
          : 'Actívalo cuando quieras recibir avisos locales.',
      trailing: Switch(
        key: ValueKey('owner-reminder-switch-${type.value}'),
        value: enabled,
        onChanged: (value) =>
            _saveReminderOnly(ref, vehicleId, type, obligation, value),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.type});

  final VehicleObligationType type;

  @override
  Widget build(BuildContext context) {
    final label = type == VehicleObligationType.soat ? 'SOAT' : 'RTM';
    return _SoftCard(
      keyName: 'owner-history-${type.value}',
      icon: Icons.history,
      iconColor: AppColors.green,
      title: 'Historial $label',
      body: 'Aún no hay registros anteriores.',
      trailing: const Icon(Icons.chevron_right, color: AppColors.teal),
    );
  }
}

class _OfficialCheckCard extends ConsumerWidget {
  const _OfficialCheckCard({required this.type});

  final VehicleObligationType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      key: ValueKey('owner-runt-${type.value}'),
      onPressed: () => _openOwnerExternal(
        context,
        ref,
        runtVehicleByPlateLink.uri,
        'No pudimos abrir RUNT.',
      ),
      icon: const Icon(Icons.open_in_new),
      label: const Text('Consultar en RUNT'),
    );
  }
}

class _EducationCard extends StatelessWidget {
  const _EducationCard({required this.type});

  final VehicleObligationType type;

  @override
  Widget build(BuildContext context) {
    final isSoat = type == VehicleObligationType.soat;
    return _SoftCard(
      keyName: 'owner-education-${type.value}',
      icon: isSoat ? Icons.health_and_safety_outlined : Icons.car_repair,
      iconColor: AppColors.teal,
      title: isSoat
          ? 'El SOAT te protege a ti y a los demás'
          : 'Ten tu RTM a la mano',
      body: isSoat
          ? 'Conserva una copia local y verifica la vigencia oficial en RUNT.'
          : 'Mantén tu certificado disponible y revisa la vigencia oficial.',
      trailing: const Icon(Icons.chevron_right, color: AppColors.teal),
    );
  }
}

class _CommercialBanner extends ConsumerWidget {
  const _CommercialBanner({required this.type});

  final VehicleObligationType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaign = ref.watch(homeBannerCampaignProvider);
    return campaign.when(
      data: (item) => _CommercialBannerBody(type: type, campaign: item),
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

class _CommercialBannerBody extends ConsumerWidget {
  const _CommercialBannerBody({required this.type, required this.campaign});

  final VehicleObligationType type;
  final HomeBannerCampaign? campaign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = campaign;
    if (item == null) {
      return const SizedBox.shrink(key: ValueKey('owner-commercial-none'));
    }
    final target = safeHomeBannerUri(item);
    final isSponsored = item.kind == HomeBannerKind.sponsored && target != null;
    final isHouse = item.kind == HomeBannerKind.house;
    if (!isSponsored && !isHouse) {
      return const SizedBox.shrink(key: ValueKey('owner-commercial-none'));
    }

    final label = isSponsored ? 'Patrocinado' : 'PicoRadar';
    final title = item.title.trim().isEmpty ? _houseTitle(type) : item.title;
    final subtitle = item.subtitle.trim().isEmpty
        ? _houseSubtitle(type)
        : item.subtitle;

    return Semantics(
      button: target != null,
      label: '$label, $title',
      child: Material(
        key: ValueKey(
          isSponsored
              ? 'owner-sponsored-${type.value}'
              : 'owner-house-${type.value}',
        ),
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: target == null
              ? null
              : () => _openOwnerExternal(
                  context,
                  ref,
                  target.toString(),
                  'No pudimos abrir el enlace.',
                ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Row(
              children: [
                _BannerLabel(label: label),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.78),
                        ),
                      ),
                    ],
                  ),
                ),
                if (target != null)
                  const Icon(Icons.arrow_outward_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerLabel extends StatelessWidget {
  const _BannerLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.plateYellow,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

Future<void> _openOwnerExternal(
  BuildContext context,
  WidgetRef ref,
  String url,
  String failureMessage,
) async {
  final launcher = ref.read(externalLauncherProvider);
  var opened = false;
  try {
    opened = await launcher.openExternal(url);
  } catch (_) {
    opened = false;
  }
  if (!context.mounted || opened) {
    return;
  }
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(failureMessage)));
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({
    required this.keyName,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.trailing,
  });

  final String keyName;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final compact = scale < 1.5;
    final header = Row(
      children: [
        CircleAvatar(
          radius: compact ? 21 : 25,
          backgroundColor: iconColor.withValues(alpha: 0.10),
          child: Icon(icon, color: iconColor, size: compact ? 22 : 24),
        ),
        const SizedBox(width: AppSpacing.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                body,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.navy.withValues(alpha: 0.70),
                ),
              ),
            ],
          ),
        ),
        if (compact) ...[
          const SizedBox(width: AppSpacing.s),
          Flexible(
            child: Align(alignment: Alignment.centerRight, child: trailing),
          ),
        ],
      ],
    );
    return Container(
      key: ValueKey(keyName),
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          if (!compact) ...[
            const SizedBox(height: AppSpacing.s),
            Align(alignment: Alignment.centerRight, child: trailing),
          ],
        ],
      ),
    );
  }
}

class _HeroFactGrid extends StatelessWidget {
  const _HeroFactGrid({required this.facts});

  final List<_HeroFactData> facts;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final columns = scale >= 1.7 || constraints.maxWidth < 300 ? 1 : 2;
        final spacing = columns == 1 ? 0.0 : AppSpacing.s;
        final width = (constraints.maxWidth - spacing) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: AppSpacing.s,
          children: [
            for (final fact in facts) _HeroFact(data: fact, width: width),
          ],
        );
      },
    );
  }
}

class _HeroFactData {
  const _HeroFactData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
}

class _HeroFact extends StatelessWidget {
  const _HeroFact({required this.data, required this.width});

  final _HeroFactData data;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            data.icon,
            color: Colors.white.withValues(alpha: 0.78),
            size: 18,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label,
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                    height: 1.05,
                  ),
                ),
                Text(
                  data.value,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: data.color,
                    height: 1.05,
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

class _HeroMark extends StatelessWidget {
  const _HeroMark({required this.type, required this.color});

  final VehicleObligationType type;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 30,
      backgroundColor: color.withValues(alpha: 0.16),
      child: Icon(
        type == VehicleObligationType.soat
            ? Icons.verified_user_outlined
            : Icons.assignment_turned_in_outlined,
        color: color,
        size: 34,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

PrivateVehicleDocumentType _documentType(VehicleObligationType type) {
  return switch (type) {
    VehicleObligationType.soat => PrivateVehicleDocumentType.soat,
    VehicleObligationType.rtm => PrivateVehicleDocumentType.rtm,
    _ => throw ArgumentError.value(type, 'type', 'Unsupported owner screen.'),
  };
}

List<_HeroFactData> _heroFacts({
  required VehicleProfile vehicle,
  required VehicleObligationType type,
  required VehicleObligation? obligation,
  required Map<String, String> details,
  required Color color,
}) {
  final isSoat = type == VehicleObligationType.soat;
  return [
    _HeroFactData(
      icon: Icons.calendar_month,
      label: isSoat ? 'Vence el' : 'Próxima RTM',
      value: obligation?.dueDate == null
          ? 'Sin fecha'
          : _formatHeroDate(obligation!.dueDate!),
      color: color,
    ),
    if (isSoat && (details['insurerName'] ?? '').isNotEmpty)
      _HeroFactData(
        icon: Icons.shield_outlined,
        label: 'Aseguradora',
        value: details['insurerName']!,
        color: color,
      ),
    if (isSoat && (details['policyNumber'] ?? '').isNotEmpty)
      _HeroFactData(
        icon: Icons.confirmation_number_outlined,
        label: 'Póliza',
        value: details['policyNumber']!,
        color: color,
      ),
    if (!isSoat && (details['cdaName'] ?? '').isNotEmpty)
      _HeroFactData(
        icon: Icons.apartment_outlined,
        label: 'CDA',
        value: details['cdaName']!,
        color: color,
      ),
    if (!isSoat && (details['certificateNumber'] ?? '').isNotEmpty)
      _HeroFactData(
        icon: Icons.verified_outlined,
        label: 'N.º certificado',
        value: details['certificateNumber']!,
        color: color,
      ),
    if (!isSoat)
      _HeroFactData(
        icon: vehicleIcon(vehicle),
        label: 'Placa',
        value: vehicle.plate,
        color: color,
      ),
  ];
}

_OwnerVisualState _visualState({
  required VehicleObligation? obligation,
  required bool hasDocument,
  required DateTime nowBogota,
}) {
  if (obligation == null) {
    return hasDocument
        ? _OwnerVisualState.unknown
        : _OwnerVisualState.notConfigured;
  }
  if (obligation.dueDate == null) {
    return obligation.details.isEmpty && !hasDocument
        ? _OwnerVisualState.notConfigured
        : _OwnerVisualState.unknown;
  }
  return switch (evaluateVehicleObligationState(
    dueDate: obligation.dueDate,
    nowBogota: nowBogota,
  )) {
    VehicleObligationState.notConfigured => _OwnerVisualState.notConfigured,
    VehicleObligationState.valid => _OwnerVisualState.active,
    VehicleObligationState.dueSoon => _OwnerVisualState.dueSoon,
    VehicleObligationState.expired => _OwnerVisualState.expired,
  };
}

String _vehicleTitle(VehicleProfile vehicle) {
  final nickname = vehicle.nickname?.trim();
  if (nickname != null && nickname.isNotEmpty) {
    return nickname;
  }
  final makeModel = [
    vehicle.brand?.trim(),
    vehicle.model?.trim(),
    if (vehicle.year != null) '${vehicle.year}',
  ].whereType<String>().where((value) => value.isNotEmpty).join(' ');
  return makeModel.isEmpty ? vehicleTypeLabel(vehicle) : makeModel;
}

Color _stateColor(_OwnerVisualState state) {
  return switch (state) {
    _OwnerVisualState.active => AppColors.teal,
    _OwnerVisualState.dueSoon => AppColors.orange,
    _OwnerVisualState.expired => AppColors.red,
    _OwnerVisualState.notConfigured ||
    _OwnerVisualState.unknown => AppColors.blue,
  };
}

String _stateChip(VehicleObligationType type, _OwnerVisualState state) {
  final prefix = type == VehicleObligationType.soat ? 'SOAT' : 'RTM';
  return switch (state) {
    _OwnerVisualState.active =>
      type == VehicleObligationType.soat ? 'SOAT ACTIVO' : 'RTM VIGENTE',
    _OwnerVisualState.dueSoon => '$prefix POR VENCER',
    _OwnerVisualState.expired => '$prefix VENCIDO',
    _OwnerVisualState.unknown => '$prefix POR VERIFICAR',
    _OwnerVisualState.notConfigured => '$prefix SIN CONFIGURAR',
  };
}

String _heroTitle(VehicleObligationType type, _OwnerVisualState state) {
  return switch (state) {
    _OwnerVisualState.active => '¡Todo en regla!',
    _OwnerVisualState.dueSoon => 'Vence pronto',
    _OwnerVisualState.expired => 'Revisa esta obligación',
    _OwnerVisualState.unknown => 'Completa los datos',
    _OwnerVisualState.notConfigured =>
      type == VehicleObligationType.soat
          ? 'Configura tu SOAT'
          : 'Configura tu tecnomecánica',
  };
}

String _heroSubtitle(VehicleObligationType type, _OwnerVisualState state) {
  final label = type == VehicleObligationType.soat
      ? 'Tu SOAT'
      : 'Tu Revisión Técnico-Mecánica';
  return switch (state) {
    _OwnerVisualState.active => '$label está vigente.',
    _OwnerVisualState.dueSoon => 'La fecha guardada está dentro de 30 días.',
    _OwnerVisualState.expired => 'La fecha guardada ya venció.',
    _OwnerVisualState.unknown => 'Verifica la información en RUNT.',
    _OwnerVisualState.notConfigured =>
      'Agrega la fecha de vencimiento para recibir recordatorios.',
  };
}

String _soatPrimaryLabel(_OwnerVisualState state, bool hasDocument) {
  return switch (state) {
    _OwnerVisualState.active => hasDocument ? 'VER SOAT' : 'ADJUNTAR SOAT',
    _OwnerVisualState.dueSoon ||
    _OwnerVisualState.expired => 'ACTUALIZAR DATOS DEL SOAT',
    _OwnerVisualState.notConfigured => 'AGREGAR DATOS DEL SOAT',
    _OwnerVisualState.unknown => 'COMPLETAR DATOS',
  };
}

String _houseTitle(VehicleObligationType type) {
  return type == VehicleObligationType.soat
      ? 'Guarda tu SOAT local'
      : 'Lleva tu RTM a mano';
}

String _houseSubtitle(VehicleObligationType type) {
  return type == VehicleObligationType.soat
      ? 'Sin subir documentos a la nube.'
      : 'Tu certificado queda privado en este dispositivo.';
}

String _documentLabel(VehicleObligationType type) {
  return type == VehicleObligationType.soat ? 'SOAT' : 'Certificado RTM';
}

String _formatHeroDate(DateTime date) {
  const months = [
    'ENE',
    'FEB',
    'MAR',
    'ABR',
    'MAY',
    'JUN',
    'JUL',
    'AGO',
    'SEP',
    'OCT',
    'NOV',
    'DIC',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

Future<void> _saveReminderOnly(
  WidgetRef ref,
  String vehicleId,
  VehicleObligationType type,
  VehicleObligation? obligation,
  bool enabled,
) async {
  await ref
      .read(vehicleObligationStoreProvider)
      .upsert(
        vehicleId: vehicleId,
        type: type,
        startDate: obligation?.startDate,
        dueDate: obligation?.dueDate,
        details: obligation?.details ?? const {},
        reminderEnabled: enabled,
      );
  ref.invalidate(vehicleObligationProvider((vehicleId, type)));
  ref.invalidate(vehicleObligationsProvider(vehicleId));
  ref.invalidate(obligationNotificationSyncProvider);
}
