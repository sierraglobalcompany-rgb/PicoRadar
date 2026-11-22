import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/dataset_sync_service.dart';
import '../../comparendos/presentation/comparendos_screen.dart';
import '../../account/presentation/app_account_settings.dart';
import '../../driving/data/camera_pack_loader.dart';
import '../../defense/application/defense_case_providers.dart';
import '../application/national_dataset_status_provider.dart';
import '../../documents/application/wallet_providers.dart';
import '../../documents/data/wallet_models.dart';
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
    final nationalDatasetStatus = ref.watch(nationalDatasetStatusProvider);
    final syncConfig = ref.watch(datasetSyncConfigProvider);

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
                    key: const ValueKey('settings-national-dataset-section'),
                    title: 'Estado de datos nacionales',
                    icon: Icons.storage_outlined,
                    children: [
                      if (syncConfig == null) ...[
                        const _SectionText(
                          'Servidor OTA no configurado en esta compilación.',
                        ),
                        const SizedBox(height: AppSpacing.s),
                      ],
                      nationalDatasetStatus.when(
                        data: (records) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final key in nationalDatasetKeys)
                              _NationalDatasetStatusRow(
                                datasetKey: key,
                                record: records[key],
                              ),
                          ],
                        ),
                        loading: () => const _SectionText(
                          'Leyendo el registro local de versiones.',
                        ),
                        error: (error, stackTrace) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final key in nationalDatasetKeys)
                              _NationalDatasetStatusRow(
                                datasetKey: key,
                                record: null,
                                readError: true,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s),
                      Semantics(
                        liveRegion: _busyActionKey == 'national-datasets',
                        child: FilledButton.icon(
                          key: const ValueKey(
                            'settings-refresh-national-datasets',
                          ),
                          onPressed: syncConfig == null ||
                                  _busyActionKey.isNotEmpty
                              ? null
                              : _refreshNationalDatasets,
                          icon: _busyActionKey == 'national-datasets'
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    semanticsLabel:
                                        'Actualizando datos nacionales',
                                  ),
                                )
                              : const Icon(Icons.sync),
                          label: const Text(
                            'Actualizar datos nacionales ahora',
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s),
                      const _SectionText(
                        'Datos instalados ≠ cobertura legal confirmada. Si falta evidencia para tu municipio, vehículo, servicio o fecha, el estado es desconocido; consulta el detalle de pico y placa',
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
                          'Los vehículos y documentos siguen en este dispositivo; si activas una cuenta, solo el perfil consentido se guarda en el servidor.',
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
                          action: () =>
                              ref.read(walletStoreProvider).purgeViewerCache(),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s),
                      _ActionButton(
                        valueKey: 'settings-delete-trip-draft',
                        destructive: true,
                        busy: _busyActionKey == 'trip',
                        icon: Icons.route_outlined,
                        label: 'Borrar borrador de Viaje',
                        onPressed: _deleteTripDraft,
                      ),
                      const SizedBox(height: AppSpacing.s),
                      _ActionButton(
                        valueKey: 'settings-delete-comparendos-note',
                        destructive: true,
                        busy: _busyActionKey == 'comparendos',
                        icon: Icons.fact_check_outlined,
                        label: 'Borrar nota de Comparendos',
                        onPressed: _deleteComparendosNote,
                      ),
                      const SizedBox(height: AppSpacing.s),
                      _ActionButton(
                        valueKey: 'settings-delete-active-vehicle-private-data',
                        destructive: true,
                        busy: _busyActionKey == 'vehicle-private-data',
                        icon: Icons.no_encryption_gmailerrorred_outlined,
                        label: 'Borrar archivos y expedientes del vehículo favorito',
                        onPressed: _deleteActiveVehiclePrivateData,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.l),
                  _SettingsSection(
                    key: const ValueKey('settings-account-section'),
                    title: 'Cuenta',
                    icon: Icons.person_outline,
                    children: const [AppAccountSettingsSection()],
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

  Future<void> _refreshNationalDatasets() async {
    if (_busyActionKey.isNotEmpty ||
        ref.read(datasetSyncConfigProvider) == null) {
      return;
    }
    setState(() => _busyActionKey = 'national-datasets');
    var message = 'No pudimos actualizar los datos nacionales.';
    try {
      final result = await ref.read(manualDatasetRefreshProvider)();
      if (result == null) {
        message =
            'La actualización nacional no está disponible en este momento.';
      } else {
        ref.invalidate(nationalDatasetStatusProvider);
        message = _datasetRefreshMessage(result);
      }
    } catch (_) {
      message =
          'No pudimos actualizar los datos nacionales. Revisa la conexión e inténtalo de nuevo.';
    } finally {
      if (mounted) {
        setState(() => _busyActionKey = '');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  String _datasetRefreshMessage(DatasetSyncResult result) {
    final importedNational = result.imported
        .where(nationalDatasetKeys.contains)
        .toList();
    final importedOther = result.imported
        .where((key) => !nationalDatasetKeys.contains(key))
        .toList();
    final parts = <String>[];

    if (importedNational.isNotEmpty) {
      parts.add(
        'Datos nacionales nuevos instalados: ${_datasetLabels(importedNational)}.',
      );
    }
    if (importedOther.isNotEmpty) {
      parts.add(
        '${importedNational.isEmpty ? 'Otros catálogos nuevos instalados' : 'También se instalaron otros catálogos'}: ${_datasetLabels(importedOther)}.',
      );
    }
    if (result.notModified) {
      parts.add('Sin cambios nuevos detectados: el manifiesto no cambió.');
    } else if (result.skippedCurrent.isNotEmpty) {
      parts.add(
        'Sin cambios nuevos detectados en: ${_datasetLabels(result.skippedCurrent)}.',
      );
    }

    if (result.skippedMissingImporter.isNotEmpty) {
      final missingNational = result.skippedMissingImporter
          .where(nationalDatasetKeys.contains)
          .toList();
      final missingOther = result.skippedMissingImporter
          .where((key) => !nationalDatasetKeys.contains(key))
          .toList();
      if (missingNational.isNotEmpty) {
        parts.add(
          'No se pudieron actualizar ${_datasetLabels(missingNational)}: falta el importador correspondiente.',
        );
      }
      if (missingOther.isNotEmpty) {
        parts.add(
          'Se omitieron catálogos sin importador: ${_datasetLabels(missingOther)}.',
        );
      }
    }

    if (parts.isEmpty) {
      parts.add('El servidor no reportó cambios nuevos para instalar.');
    }
    return parts.join(' ');
  }

  String _datasetLabels(List<String> datasetKeys) {
    const labels = {
      'restrictions': 'Restricciones nacionales',
      'service_providers': 'Directorio de servicios',
      'tolls_inventory': 'Peajes',
      'tax_calendars': 'Calendarios de impuestos',
      'cda_catalog': 'Directorio de CDA',
      'cda_geography': 'Cobertura geográfica de CDA',
      'insurance_directory': 'Directorio de aseguradoras',
    };
    return datasetKeys.map((key) => labels[key] ?? key).join(', ');
  }

  Future<void> _deleteComparendosNote() async {
    final confirmed = await _confirmDestructiveAction(
      title: 'Borrar nota de Comparendos',
      message: 'La nota local del vehículo favorito se eliminará de este dispositivo.',
    );
    if (!confirmed || !mounted) {
      return;
    }
    final preferences = ref.read(appPreferencesProvider);
    final activeVehicleFuture = ref.read(activeVehicleProvider.future);

    await _runAction(
      key: 'comparendos',
      successMessage: 'Nota de Comparendos eliminada del vehículo favorito.',
      action: () async {
        final activeVehicle = await activeVehicleFuture;
        final vehicleId = activeVehicle?.id.trim();
        if (vehicleId == null || vehicleId.isEmpty) {
          throw const _SettingsActionMessage(
            'No hay vehículo favorito para limpiar.',
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
      title: 'Borrar archivos y expedientes del vehículo favorito',
      message: 'Se eliminarán documentos cifrados, temporales del visor, expedientes de Defensa, borrador de Peritajes y nota de Comparendos del vehículo favorito. No se borrará el vehículo, mantenimiento ni obligaciones.',
    );
    if (!confirmed || !mounted) {
      return;
    }
    final activeVehicleFuture = ref.read(activeVehicleProvider.future);
    final cleaner = ref.read(vehicleAssociatedDataCleanerProvider);
    final session = ref.read(walletSessionProvider);
    final providerContainer = ProviderScope.containerOf(context, listen: false);

    await _runAction(
      key: 'vehicle-private-data',
      successMessage:
          'Archivos y expedientes del vehículo favorito eliminados.',
      action: () async {
        final activeVehicle = await activeVehicleFuture;
        final vehicleId = activeVehicle?.id.trim();
        if (vehicleId == null || vehicleId.isEmpty) {
          throw const _SettingsActionMessage(
            'No hay vehículo favorito para limpiar.',
          );
        }
        final vehicleDocumentList = vehicleDocumentsProvider(vehicleId);
        final privateVehicleDocuments = [
          for (final type in PrivateVehicleDocumentType.values)
            privateVehicleDocumentProvider((vehicleId, type)),
        ];
        final defenseCases = defenseCasesProvider(vehicleId);
        if (!mounted) return;
        session.lock();
        try {
          if (!await session.initialize() ||
              !mounted ||
              !await session.unlock() ||
              !mounted) {
            throw _SettingsActionMessage(
              session.failureMessage ?? 'No se pudo autorizar la eliminacion.',
            );
          }
          final epoch = session.epoch;
          await cleaner.deletePrivateDataForVehicle(
            vehicleId,
            isAuthorized: () => session.isAuthorizedEpoch(epoch),
          );
          providerContainer.invalidate(
            walletDocumentsProvider(WalletOwner.vehicle(vehicleId)),
          );
          providerContainer.invalidate(
            comparendosLastCheckedProvider(vehicleId),
          );
          providerContainer.invalidate(vehicleDocumentList);
          for (final provider in privateVehicleDocuments) {
            providerContainer.invalidate(provider);
          }
          providerContainer.invalidate(defenseCases);
        } finally {
          session.lock();
        }
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
                Expanded(
                  child: Text(
                    title,
                    style: MediaQuery.textScalerOf(context).scale(1) > 1.25
                        ? AppTextStyles.h2.copyWith(fontSize: 18)
                        : AppTextStyles.h2,
                  ),
                ),
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

class _NationalDatasetStatusRow extends StatelessWidget {
  const _NationalDatasetStatusRow({
    required this.datasetKey,
    required this.record,
    this.readError = false,
  });

  final String datasetKey;
  final NationalDatasetRecord? record;
  final bool readError;

  @override
  Widget build(BuildContext context) {
    final label = datasetKey == 'restrictions'
        ? 'Restricciones nacionales'
        : 'Directorio de servicios';
    final state = readError
        ? 'ERROR_LECTURA'
        : record == null
        ? 'SIN_INSTALAR'
        : record!.status == 'installed'
        ? 'INSTALADO_REGISTRADO'
        : 'ESTADO_NO_RECONOCIDO';
    final details = switch (state) {
      'ERROR_LECTURA' => 'No fue posible leer el estado local.',
      'SIN_INSTALAR' when datasetKey == 'restrictions' =>
        'Sin versión OTA registrada; puede haber datos incorporados en la app.',
      'SIN_INSTALAR' =>
        'Sin directorio remoto instalado; respaldo vacío.',
      'ESTADO_NO_RECONOCIDO' =>
        'El registro local tiene un estado que la app no reconoce.',
      _ => _installedDetails(record!),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.m),
      child: Semantics(
        label: '$label. $state. $details',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.bodyStrong),
            const SizedBox(height: AppSpacing.xs),
            Text(state, style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.xs),
            Text(details, style: AppTextStyles.body),
          ],
        ),
      ),
    );
  }

  String _installedDetails(NationalDatasetRecord record) {
    final localDate = record.appliedAt.toLocal();
    final installedAt = '${localDate.year.toString().padLeft(4, '0')}-'
        '${localDate.month.toString().padLeft(2, '0')}-'
        '${localDate.day.toString().padLeft(2, '0')} '
        '${localDate.hour.toString().padLeft(2, '0')}:'
        '${localDate.minute.toString().padLeft(2, '0')}';
    final incompleteHash = record.hasCompleteHash
        ? ''
        : ' · Registro local incompleto.';
    return 'Versión ${record.version} · Fecha de instalación registrada: '
        '$installedAt · revisión ${record.publicationRevision}$incompleteHash';
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
    this.destructive = false,
  });

  final String valueKey;
  final bool busy;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: ValueKey(valueKey),
      style: destructive
          ? OutlinedButton.styleFrom(
              foregroundColor: AppColors.red,
              side: const BorderSide(color: AppColors.red),
            )
          : null,
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
