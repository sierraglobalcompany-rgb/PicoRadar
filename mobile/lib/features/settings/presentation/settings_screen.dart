import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/database/app_database.dart';
import '../../comparendos/presentation/comparendos_screen.dart';
import '../../driving/data/camera_pack_loader.dart';
import '../../defense/application/defense_case_providers.dart';
import '../../documents/presentation/documents_screen.dart';
import '../../pico_placa/data/pico_preferences.dart';
import '../../trip/application/trip_services.dart';
import '../../vehicle_status/data/private_vehicle_document_store.dart';
import '../../vehicle_status/platform/external_launcher.dart';

const ansvFotodeteccionUrl =
    'https://fotodeteccion.ansv.gov.co/ubicaciones-aprobadas.html';
const simitSourceUrl = 'https://www.simit.org.co/';
const sicPersonalDataGuideUrl =
    'https://sedeelectronica.sic.gov.co/noticias/sic-expide-guia-para-el-correcto-tratamiento-de-las-fotografias-como-datos-personales';

final settingsNotificationStatusProvider =
    FutureProvider.autoDispose<SettingsNotificationStatus>((ref) async {
      final alertPreferencesFuture = ref.watch(
        picoAlertPreferencesProvider.future,
      );
      final scheduler = ref.watch(picoNotificationSchedulerProvider);
      final alertPreferences = await alertPreferencesFuture;
      bool? osNotificationsEnabled;
      try {
        osNotificationsEnabled = await scheduler.areNotificationsEnabled();
      } on MissingPluginException {
        osNotificationsEnabled = null;
      }
      return SettingsNotificationStatus(
        alertPreferences: alertPreferences,
        osNotificationsEnabled: osNotificationsEnabled,
      );
    });

final cameraDatasetDiagnosticProvider = FutureProvider<CameraDatasetDiagnostic>(
  (ref) async {
    final raw = await rootBundle.loadString(cameraPackAssetPath);
    final json = jsonDecode(raw) as Map<String, Object?>;
    final records = json['records'] as List?;
    return CameraDatasetDiagnostic(
      version: _text(json['version'], fallback: 'unknown'),
      count: _int(json['recordCount']) ?? records?.length ?? 0,
    );
  },
);

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({
    required this.onChangeAvatar,
    this.onConfigureNotifications,
    super.key,
  });

  final VoidCallback onChangeAvatar;
  final VoidCallback? onConfigureNotifications;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  var _busyActionKey = '';

  @override
  Widget build(BuildContext context) {
    final notificationStatus = ref.watch(settingsNotificationStatusProvider);
    final cameraDiagnostic = ref.watch(cameraDatasetDiagnosticProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: SafeArea(
        child: SingleChildScrollView(
          key: const ValueKey('settings-screen-scroll'),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.l,
            AppSpacing.l,
            96,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SettingsSection(
                    key: const ValueKey('settings-appearance-section'),
                    title: 'Apariencia',
                    icon: Icons.palette_outlined,
                    children: [
                      _SectionText('Personaliza tu avatar local de PicoRadar.'),
                      const SizedBox(height: AppSpacing.m),
                      OutlinedButton.icon(
                        key: const ValueKey('settings-change-avatar'),
                        onPressed: widget.onChangeAvatar,
                        icon: const Icon(Icons.face_outlined),
                        label: const Text('Cambiar avatar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.l),
                  _SettingsSection(
                    key: const ValueKey('settings-notifications-section'),
                    title: 'Notificaciones',
                    icon: Icons.notifications_none_outlined,
                    children: [
                      notificationStatus.when(
                        data: (status) =>
                            _NotificationStatusSummary(status: status),
                        loading: () => const _SectionText(
                          'Revisando estado local de alertas.',
                        ),
                        error: (error, stackTrace) => _SectionText(
                          'No pudimos leer el estado de notificaciones.',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.m),
                      FilledButton.icon(
                        key: const ValueKey('settings-go-home-notifications'),
                        onPressed: _configureNotifications,
                        icon: const Icon(Icons.home_outlined),
                        label: const Text('Ir a Inicio para configurar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.l),
                  _SettingsSection(
                    key: const ValueKey('settings-privacy-section'),
                    title: 'Privacidad',
                    icon: Icons.privacy_tip_outlined,
                    children: [
                      const _TruthList(
                        items: [
                          'Los datos del vehículo viven en este dispositivo.',
                          'Los documentos se guardan cifrados en almacenamiento privado.',
                          'PicoRadar funciona sin cuenta.',
                          'No hay sincronización en nube en Free 1.0.',
                          'No guardamos historial GPS.',
                          'No subimos GPS al servidor.',
                        ],
                      ),
                      const SizedBox(height: AppSpacing.l),
                      _ActionButton(
                        valueKey: 'settings-purge-document-viewer',
                        busy: _busyActionKey == 'documents',
                        icon: Icons.cleaning_services_outlined,
                        label: 'Purgar temporales del visor',
                        onPressed: () => _runAction(
                          key: 'documents',
                          successMessage: 'Temporales del visor purgados.',
                          action: () => ref
                              .read(privateVehicleDocumentStoreProvider)
                              .purgeViewerCache(),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s),
                      _ActionButton(
                        valueKey: 'settings-delete-trip-draft',
                        busy: _busyActionKey == 'trip',
                        icon: Icons.route_outlined,
                        label: 'Borrar borrador de Viaje',
                        onPressed: _deleteTripDraft,
                      ),
                      const SizedBox(height: AppSpacing.s),
                      _ActionButton(
                        valueKey: 'settings-delete-comparendos-note',
                        busy: _busyActionKey == 'comparendos',
                        icon: Icons.fact_check_outlined,
                        label: 'Borrar nota de Comparendos',
                        onPressed: _deleteComparendosNote,
                      ),
                      const SizedBox(height: AppSpacing.s),
                      _ActionButton(
                        valueKey: 'settings-delete-active-vehicle-private-data',
                        busy: _busyActionKey == 'vehicle-private-data',
                        icon: Icons.no_encryption_gmailerrorred_outlined,
                        label:
                            'Borrar archivos y expedientes del vehículo activo',
                        onPressed: _deleteActiveVehiclePrivateData,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.l),
                  _SettingsSection(
                    key: const ValueKey('settings-sources-section'),
                    title: 'Fuentes',
                    icon: Icons.source_outlined,
                    children: [
                      for (final source in settingsSourceLinks) ...[
                        _SourceButton(source: source),
                        if (source != settingsSourceLinks.last)
                          const SizedBox(height: AppSpacing.s),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.l),
                  _SettingsSection(
                    key: const ValueKey('settings-support-section'),
                    title: 'Soporte',
                    icon: Icons.support_agent_outlined,
                    children: [
                      _SectionText(
                        'Copia un diagnóstico técnico sin placa, vehículo, GPS ni identificador del dispositivo.',
                      ),
                      const SizedBox(height: AppSpacing.m),
                      cameraDiagnostic.when(
                        data: (diagnostic) => FilledButton.icon(
                          key: const ValueKey('settings-copy-diagnostic'),
                          onPressed: () => _copyDiagnostic(diagnostic),
                          icon: const Icon(Icons.copy_outlined),
                          label: const Text('Copiar diagnóstico'),
                        ),
                        loading: () =>
                            const _SectionText('Preparando diagnóstico local.'),
                        error: (error, stackTrace) => OutlinedButton.icon(
                          key: const ValueKey(
                            'settings-copy-diagnostic-unavailable',
                          ),
                          onPressed: null,
                          icon: const Icon(Icons.error_outline),
                          label: const Text('Diagnóstico no disponible'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _configureNotifications() {
    final callback = widget.onConfigureNotifications;
    if (callback != null) {
      callback();
      return;
    }
    context.go(AppRoute.home.path);
  }

  Future<void> _deleteComparendosNote() async {
    final confirmed = await _confirmDestructiveAction(
      title: 'Borrar nota de Comparendos',
      message:
          'La nota local del vehículo activo se eliminará de este dispositivo.',
    );
    if (!confirmed || !mounted) {
      return;
    }
    final preferences = ref.read(appPreferencesProvider);
    final activeVehicleFuture = ref.read(activeVehicleProvider.future);

    await _runAction(
      key: 'comparendos',
      successMessage: 'Nota de Comparendos eliminada del vehículo activo.',
      action: () async {
        final activeVehicle = await activeVehicleFuture;
        final vehicleId = activeVehicle?.id.trim();
        if (vehicleId == null || vehicleId.isEmpty) {
          throw const _SettingsActionMessage(
            'No hay vehículo activo para limpiar.',
          );
        }
        await preferences.remove('comparendos.last_checked.$vehicleId');
      },
    );
  }

  Future<void> _deleteTripDraft() async {
    final confirmed = await _confirmDestructiveAction(
      title: 'Borrar borrador de Viaje',
      message: 'El borrador local de Viaje se eliminará de este dispositivo.',
    );
    if (!confirmed || !mounted) {
      return;
    }
    final store = ref.read(tripDraftStoreProvider);

    await _runAction(
      key: 'trip',
      successMessage: 'Borrador de Viaje eliminado.',
      action: store.deleteDraft,
    );
  }

  Future<void> _deleteActiveVehiclePrivateData() async {
    final confirmed = await _confirmDestructiveAction(
      title: 'Borrar archivos y expedientes del vehículo activo',
      message: 'Se eliminarán documentos cifrados, temporales del visor, expedientes de Defensa, borrador de Peritajes y nota de Comparendos del vehículo activo. No se borrará el vehículo, mantenimiento ni obligaciones.',
    );
    if (!confirmed || !mounted) {
      return;
    }
    final activeVehicleFuture = ref.read(activeVehicleProvider.future);
    final cleaner = ref.read(vehicleAssociatedDataCleanerProvider);
    final providerContainer = ProviderScope.containerOf(context, listen: false);

    await _runAction(
      key: 'vehicle-private-data',
      successMessage: 'Archivos y expedientes del vehículo activo eliminados.',
      action: () async {
        final activeVehicle = await activeVehicleFuture;
        final vehicleId = activeVehicle?.id.trim();
        if (vehicleId == null || vehicleId.isEmpty) {
          throw const _SettingsActionMessage(
            'No hay vehículo activo para limpiar.',
          );
        }
        final vehicleDocumentList = vehicleDocumentsProvider(vehicleId);
        final privateVehicleDocuments = [
          for (final type in PrivateVehicleDocumentType.values)
            privateVehicleDocumentProvider((vehicleId, type)),
        ];
        final defenseCases = defenseCasesProvider(vehicleId);
        await cleaner.deleteForVehicle(vehicleId);
        providerContainer.invalidate(comparendosLastCheckedProvider(vehicleId));
        providerContainer.invalidate(vehicleDocumentList);
        for (final provider in privateVehicleDocuments) {
          providerContainer.invalidate(provider);
        }
        providerContainer.invalidate(defenseCases);
      },
    );
  }

  Future<bool> _confirmDestructiveAction({
    required String title,
    required String message,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
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
    return confirmed ?? false;
  }

  Future<void> _runAction({
    required String key,
    required String successMessage,
    required Future<void> Function() action,
  }) async {
    if (_busyActionKey.isNotEmpty) {
      return;
    }
    setState(() => _busyActionKey = key);
    var message = successMessage;
    try {
      await action();
    } on _SettingsActionMessage catch (error) {
      message = error.message;
    } catch (_) {
      message = 'No pudimos completar la acción.';
    } finally {
      if (mounted) {
        setState(() => _busyActionKey = '');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  Future<void> _copyDiagnostic(CameraDatasetDiagnostic diagnostic) async {
    final text = settingsDiagnosticText(
      schemaVersion: AppDatabase.currentSchemaVersion,
      cameraDataset: diagnostic,
    );
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pudimos copiar el diagnóstico.')),
        );
      }
      return;
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Diagnóstico copiado.')));
  }
}

class SettingsNotificationStatus {
  const SettingsNotificationStatus({
    required this.alertPreferences,
    required this.osNotificationsEnabled,
  });

  final PicoAlertPreferences alertPreferences;
  final bool? osNotificationsEnabled;
}

class CameraDatasetDiagnostic {
  const CameraDatasetDiagnostic({required this.version, required this.count});

  final String version;
  final int count;
}

class SettingsSourceLink {
  const SettingsSourceLink({
    required this.label,
    required this.description,
    required this.url,
  });

  final String label;
  final String description;
  final String url;
}

const settingsSourceLinks = [
  SettingsSourceLink(
    label: 'ANSV Fotodetección',
    description: 'Ubicaciones aprobadas de cámaras.',
    url: ansvFotodeteccionUrl,
  ),
  SettingsSourceLink(
    label: 'SIMIT',
    description: 'Consulta nacional oficial de comparendos.',
    url: simitSourceUrl,
  ),
  SettingsSourceLink(
    label: 'INVÍAS',
    description: 'Estado oficial de la red vial nacional.',
    url: inviasRoadStatusUrl,
  ),
  SettingsSourceLink(
    label: 'Guía SIC de datos personales',
    description: 'Tratamiento correcto de fotografías como datos personales.',
    url: sicPersonalDataGuideUrl,
  ),
];

String settingsDiagnosticText({
  required int schemaVersion,
  required CameraDatasetDiagnostic cameraDataset,
}) {
  return [
    'PicoRadar diagnostic',
    'schemaVersion=$schemaVersion',
    'cameraDatasetVersion=${cameraDataset.version}',
    'cameraDatasetCount=${cameraDataset.count}',
  ].join('\n');
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
    super.key,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.teal),
                const SizedBox(width: AppSpacing.s),
                Expanded(child: Text(title, style: AppTextStyles.h2)),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _NotificationStatusSummary extends StatelessWidget {
  const _NotificationStatusSummary({required this.status});

  final SettingsNotificationStatus status;

  @override
  Widget build(BuildContext context) {
    return _TruthList(
      items: [_permissionLabel(status), _alertsLabel(status.alertPreferences)],
    );
  }

  String _permissionLabel(SettingsNotificationStatus status) {
    if (status.osNotificationsEnabled == false) {
      return 'Permiso del sistema: desactivado.';
    }
    if (status.osNotificationsEnabled == true) {
      return 'Permiso del sistema: activo.';
    }
    if (status.alertPreferences.permissionGranted) {
      return 'Permiso del sistema: no disponible; último estado local: activo.';
    }
    if (status.alertPreferences.permissionRequested) {
      return 'Permiso del sistema: no disponible; último estado local: desactivado.';
    }
    return 'Permiso del sistema: no disponible; no se ha solicitado desde Ajustes.';
  }

  String _alertsLabel(PicoAlertPreferences preferences) {
    final anyWindow =
        preferences.dayBeforeEnabled || preferences.sameDayEnabled;
    if (preferences.enabled && anyWindow) {
      return 'Alertas locales: activadas.';
    }
    return 'Alertas locales: desactivadas.';
  }
}

class _TruthList extends StatelessWidget {
  const _TruthList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: AppColors.green,
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(child: Text(item, style: AppTextStyles.body)),
              ],
            ),
          ),
      ],
    );
  }
}

class _SourceButton extends ConsumerWidget {
  const _SourceButton({required this.source});

  final SettingsSourceLink source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      key: ValueKey('settings-source-${source.label}'),
      onPressed: () async {
        final launcher = ref.read(externalLauncherProvider);
        bool opened;
        try {
          opened = await launcher.openExternal(source.url);
        } catch (_) {
          opened = false;
        }
        if (!opened && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No pudimos abrir ${source.label}.')),
          );
        }
      },
      icon: const Icon(Icons.open_in_new),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(source.label),
          Text(source.description, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.valueKey,
    required this.busy,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final String valueKey;
  final bool busy;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: ValueKey(valueKey),
      onPressed: busy ? null : onPressed,
      icon: busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      label: Text(label),
    );
  }
}

class _SectionText extends StatelessWidget {
  const _SectionText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTextStyles.body);
  }
}

class _SettingsActionMessage implements Exception {
  const _SettingsActionMessage(this.message);

  final String message;
}

String _text(Object? value, {required String fallback}) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? fallback : text;
}

int? _int(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}
