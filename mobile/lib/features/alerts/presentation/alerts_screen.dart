import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/design_system/branding.dart';
import '../../pico_placa/data/pico_preferences.dart';
import '../application/alert_center.dart';
import '../data/alert_settings.dart';

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});
  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen>
    with WidgetsBindingObserver {
  bool _saving = false;
  String? _busyVehicle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() {
    ref.invalidate(picoAlertPreferencesProvider);
    ref.invalidate(picoNotificationSyncProvider);
    ref.invalidate(obligationNotificationSyncProvider);
    ref.invalidate(alertCenterProvider);
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(alertCenterProvider);
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/home'),
                  tooltip: 'Volver',
                  icon: const Icon(Icons.arrow_back),
                ),
                const Expanded(
                  child: Text(
                    'Alertas y recordatorios',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _saving ? null : _refresh,
                  tooltip: 'Actualizar',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          Expanded(
            child: data.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'No se pudieron consultar tus recordatorios. Tus ajustes se conservan.',
                      ),
                      TextButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (value) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  Row(
                    children: [
                      Icon(
                        value.permission
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_off_outlined,
                        color: value.permission
                            ? AppColors.teal
                            : AppColors.red,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          value.permission
                              ? 'Notificaciones permitidas'
                              : 'Notificaciones desactivadas',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      TextButton(
                        onPressed: _saving
                            ? null
                            : value.permission
                            ? _notificationSettings
                            : _permission,
                        child: Text(value.permission ? 'Revisar' : 'Activar'),
                      ),
                    ],
                  ),
                  if (value.schedulingFailed)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Hay avisos sin programar. Revisa los permisos o vuelve a intentarlo.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (value.rows.isEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Agrega un vehículo para configurar sus recordatorios.',
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => context.push('/onboarding/vehicle'),
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar vehículo'),
                    ),
                  ],
                  for (final category in AlertCategory.values) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 4),
                      child: Text(
                        _label(category),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    for (final row in value.rows.where(
                      (r) => r.category == category,
                    ))
                      _row(row, value),
                    const Divider(height: 16),
                  ],
                  TextButton.icon(
                    onPressed: () => _preview(value),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Vista previa y prueba'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(AlertCenterRow row, AlertCenterData data) {
    final missing = row.category != AlertCategory.pico && row.dueDate == null;
    final unavailable = row.settings.alarm && !data.capabilities.canSchedule;
    final status = !row.settings.enabled
        ? 'Desactivado'
        : missing
        ? 'Fecha sin registrar'
        : unavailable
        ? 'Alarma no disponible'
        : row.scheduled
        ? 'Programada: ${_date(row.nextDate!)}'
        : row.nextDate != null
        ? 'Pendiente de programar'
        : row.category == AlertCategory.pico
        ? 'Sin avisos con los datos vigentes'
        : 'Sin avisos futuros';
    return ExpansionTile(
      key: ValueKey('alerts-${row.vehicle.id}-${row.category.name}'),
      tilePadding: EdgeInsets.zero,
      leading: Icon(_icon(row.category), color: AppColors.teal),
      title: Text(
        row.vehicle.plate,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(status, style: const TextStyle(fontSize: 14)),
      children: [
        if (row.dueDate != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Vencimiento registrado: ${_day(row.dueDate!)}'),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Recordatorio'),
          value: row.settings.enabled,
          secondary: _busyVehicle == '${row.vehicle.id}/${row.category.name}'
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onChanged: _saving
              ? null
              : (v) => _save(row, row.settings.copyWith(enabled: v)),
        ),
        if (missing)
          TextButton.icon(
            onPressed: () => context.push(_route(row)),
            icon: const Icon(Icons.event),
            label: const Text('Registrar fecha'),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Aviso'),
          subtitle: Text(row.settings.alarm ? 'Alarma' : 'Notificación'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _saving ? null : () => _delivery(row, data),
        ),
        if (row.settings.alarm &&
            data.capabilities.canSchedule &&
            !data.capabilities.fullScreen)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.open_in_full),
            title: const Text('Permitir pantalla de alarma'),
            subtitle: const Text(
              'Opcional. Sin este permiso, usa los controles de la notificación.',
            ),
            onTap: () async {
              try {
                await ref.read(alarmGatewayProvider).requestFullScreen();
              } catch (_) {
                _message('No se pudieron abrir los ajustes.');
              }
            },
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Notificación enriquecida'),
          subtitle: const Text(
            'Placa ilustrada, oculta en la pantalla bloqueada',
            style: TextStyle(fontSize: 14),
          ),
          value: row.settings.enriched,
          onChanged: _saving
              ? null
              : (v) => _save(row, row.settings.copyWith(enriched: v)),
        ),
        if (row.category == AlertCategory.pico) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Día anterior'),
            value: row.settings.dayBefore,
            onChanged: _saving
                ? null
                : (v) => _save(row, row.settings.copyWith(dayBefore: v)),
          ),
          _time(
            'Hora del día anterior',
            row.settings.dayBeforeMinute,
            (v) => _save(row, row.settings.copyWith(dayBeforeMinute: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mismo día'),
            value: row.settings.sameDay,
            onChanged: _saving
                ? null
                : (v) => _save(row, row.settings.copyWith(sameDay: v)),
          ),
          _time(
            'Hora del mismo día',
            row.settings.sameDayMinute,
            (v) => _save(row, row.settings.copyWith(sameDayMinute: v)),
          ),
        ] else ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_repeat),
            title: const Text('Anticipación'),
            subtitle: Text('${row.settings.offsetDays.join(', ')} días antes'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _saving ? null : () => _offsets(row),
          ),
          _time(
            'Hora del recordatorio',
            row.settings.minute,
            (v) => _save(row, row.settings.copyWith(minute: v)),
          ),
        ],
      ],
    );
  }

  Widget _time(String label, int minute, Future<void> Function(int) save) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.schedule),
        title: Text(label),
        trailing: Text(_clock(minute)),
        onTap: _saving
            ? null
            : () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                    hour: minute ~/ 60,
                    minute: minute % 60,
                  ),
                );
                if (time != null && mounted) {
                  await save(time.hour * 60 + time.minute);
                }
              },
      );

  Future<void> _save(AlertCenterRow row, AlertSettings settings) async {
    if (_saving) return;
    final store = ref.read(alertSettingsStoreProvider);
    setState(() {
      _saving = true;
      _busyVehicle = '${row.vehicle.id}/${row.category.name}';
    });
    try {
      await store.save(row.vehicle.id, row.category, settings);
      if (mounted) _refresh();
    } catch (_) {
      _message('No se guardaron los cambios. Intenta de nuevo.');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _busyVehicle = null;
        });
      }
    }
  }

  Future<void> _permission() async {
    try {
      final scheduler = ref.read(picoNotificationSchedulerProvider);
      final prefs = ref.read(appPreferencesProvider);
      final old = await ref.read(picoAlertPreferencesProvider.future);
      final granted = await scheduler.requestPermission();
      await savePicoAlertPreferences(
        prefs,
        old.copyWith(permissionRequested: true, permissionGranted: granted),
      );
      if (mounted) _refresh();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Activa las notificaciones en los ajustes del teléfono.',
            ),
            action: SnackBarAction(
              label: 'Ajustes',
              onPressed: _notificationSettings,
            ),
          ),
        );
      }
    } catch (_) {
      _message('No se pudo consultar el permiso. Intenta de nuevo.');
    }
  }

  Future<void> _notificationSettings() async {
    try {
      await ref.read(alarmGatewayProvider).openNotificationSettings();
    } catch (_) {
      _message('No se pudieron abrir los ajustes de notificaciones.');
    }
  }

  Future<void> _delivery(AlertCenterRow row, AlertCenterData data) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Tipo de aviso',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ),
              ListTile(
                minTileHeight: 56,
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('Notificación'),
                onTap: () => Navigator.pop(context, 'notification'),
              ),
              ListTile(
                minTileHeight: 56,
                leading: const Icon(Icons.alarm),
                title: const Text('Alarma'),
                subtitle: const Text(
                  'Sonido hasta detenerla o durante dos minutos.',
                ),
                onTap: () => Navigator.pop(context, 'alarm'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'notification') {
      await _save(row, row.settings.copyWith(alarm: false));
      return;
    }
    final gateway = ref.read(alarmGatewayProvider);
    try {
      final capabilities = await gateway.capabilities();
      if (!mounted) return;
      if (!capabilities.supported) {
        _message(
          'La alarma no está disponible en este dispositivo. Puedes usar notificaciones.',
        );
        return;
      }
      if (!capabilities.canSchedule) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permitir alarmas'),
            content: const Text(
              'Se necesitan notificaciones y permiso de alarmas exactas. La opción no se activará hasta que vuelvas y la confirmes.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Ahora no'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Abrir ajustes'),
              ),
            ],
          ),
        );
        if (confirm == true) await gateway.requestPermissions();
        return;
      }
      await _save(row, row.settings.copyWith(alarm: true));
      if (!capabilities.fullScreen) {
        _message(
          'Alarma activada sin pantalla completa. Puedes detenerla desde la notificación.',
        );
      }
    } catch (_) {
      _message('Alarma no disponible. Revisa los permisos e intenta de nuevo.');
    }
  }

  Future<void> _offsets(AlertCenterRow row) async {
    final selected = row.settings.offsetDays.toSet();
    final result = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Días antes del vencimiento',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  for (final day in ({
                    30,
                    15,
                    7,
                    1,
                    0,
                    ...selected,
                  }.toList()..sort((a, b) => b.compareTo(a))))
                    CheckboxListTile(
                      title: Text(
                        day == 0 ? 'El mismo día' : '$day días antes',
                      ),
                      value: selected.contains(day),
                      onChanged: (v) => update(() {
                        if (v == true) {
                          selected.add(day);
                        } else {
                          selected.remove(day);
                        }
                      }),
                    ),
                  FilledButton(
                    onPressed: selected.isEmpty || selected.length > 5
                        ? null
                        : () => Navigator.pop(
                            context,
                            selected.toList()..sort((a, b) => b.compareTo(a)),
                          ),
                    child: const Text('Guardar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (result != null && mounted) {
      await _save(row, row.settings.copyWith(offsetDays: result));
    }
  }

  Future<void> _preview(AlertCenterData data) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Vista previa',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                const Center(child: ColombianPlateBadge(plate: 'DEM123')),
                const ListTile(
                  leading: Icon(Icons.notifications_active_outlined),
                  title: Text('Recordatorio de ejemplo'),
                  subtitle: Text('DEM123 - Vehículo ficticio'),
                ),
                const Text(
                  'La placa se oculta en la pantalla bloqueada. El sistema controla el aspecto final.',
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: data.permission
                      ? () => Navigator.pop(context, 'notification')
                      : null,
                  icon: const Icon(Icons.notifications_outlined),
                  label: const Text('Probar notificación'),
                ),
                TextButton.icon(
                  onPressed: data.capabilities.canSchedule
                      ? () => Navigator.pop(context, 'alarm')
                      : null,
                  icon: const Icon(Icons.alarm),
                  label: const Text('Probar sonido de alarma'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    try {
      if (choice == 'alarm') {
        await ref.read(alarmGatewayProvider).test();
      } else {
        await ref.read(picoNotificationSchedulerProvider).showPreview();
      }
    } catch (_) {
      _message('No se pudo mostrar la prueba. Revisa los permisos.');
    }
  }
}

String _clock(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
String _day(DateTime date) => '${date.day}/${date.month}/${date.year}';
String _date(DateTime date) =>
    '${_day(date)} ${_clock(date.hour * 60 + date.minute)}';
String _label(AlertCategory category) =>
    category == AlertCategory.rtm ? 'Tecnomecánica' : category.label;
IconData _icon(AlertCategory category) => switch (category) {
  AlertCategory.pico => Icons.directions_car_outlined,
  AlertCategory.soat => Icons.health_and_safety_outlined,
  AlertCategory.rtm => Icons.car_repair,
  AlertCategory.insurance => Icons.shield_outlined,
};
String _route(AlertCenterRow row) => Uri(
  path:
      '/apps/module/${switch (row.category) {
        AlertCategory.pico => 'pico',
        AlertCategory.soat => 'soat',
        AlertCategory.rtm => 'tecnomecanica',
        AlertCategory.insurance => 'seguro_asistencia',
      }}',
  queryParameters: {'vehicleId': row.vehicle.id},
).toString();
