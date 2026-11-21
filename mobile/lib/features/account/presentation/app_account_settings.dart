import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_account_client.dart';
import '../data/app_account_config.dart';

class AppAccountSettingsSection extends ConsumerStatefulWidget {
  const AppAccountSettingsSection({super.key});

  @override
  ConsumerState<AppAccountSettingsSection> createState() =>
      _AppAccountSettingsSectionState();
}

class _AppAccountSettingsSectionState
    extends ConsumerState<AppAccountSettingsSection> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _municipality = TextEditingController();
  final _categories = <String>{};
  AppAccountProfile? _profile;
  bool _privacyAccepted = false;
  bool _marketing = false;
  bool _otpRequested = false;
  bool _busy = false;
  String? _message;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _name.dispose();
    _phone.dispose();
    _municipality.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appAccountConfigProvider);
    if (!config.isAvailable) {
      return const Card(
        key: ValueKey('account-unavailable'),
        child: ListTile(
          leading: Icon(Icons.person_outline),
          title: Text('Cuenta opcional'),
          subtitle: Text(
            'No disponible todavía. PicoRadar funciona sin cuenta.',
          ),
        ),
      );
    }

    return Card(
      key: const ValueKey('account-settings-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Cuenta opcional',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text('PicoRadar sigue funcionando sin inicio de sesión.'),
            if (_profile == null) ..._loginFields(config),
            if (_profile != null) ..._profileFields(),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_message!, key: const ValueKey('account-status')),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _error!,
                  key: const ValueKey('account-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _loginFields(AppAccountConfig config) => [
    const SizedBox(height: 12),
    Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: const ValueKey('account-restore-session'),
        onPressed: _busy ? null : _restoreSession,
        icon: const Icon(Icons.lock_open_outlined),
        label: const Text('Revisar sesión guardada'),
      ),
    ),
    TextField(
      key: const ValueKey('account-email'),
      controller: _email,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      decoration: const InputDecoration(labelText: 'Correo'),
    ),
    if (config.privacyConfigured) ...[
      CheckboxListTile(
        key: const ValueKey('account-privacy-consent'),
        contentPadding: EdgeInsets.zero,
        value: _privacyAccepted,
        onChanged: (value) => setState(() => _privacyAccepted = value == true),
        title: const Text(
          'Si es una cuenta nueva, acepto la política de privacidad vigente.',
        ),
        subtitle: Text(
          'Versión ${config.privacyVersion} · Los datos del garaje no se envían.',
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          key: const ValueKey('account-open-privacy'),
          onPressed: () => launchUrl(
            config.privacyUri!,
            mode: LaunchMode.externalApplication,
          ),
          child: const Text('Leer política de privacidad'),
        ),
      ),
    ] else
      const Text(
        'Las altas nuevas esperan la configuración de la política vigente. Las cuentas existentes aún pueden solicitar acceso.',
      ),
    if (_otpRequested)
      TextField(
        key: const ValueKey('account-otp'),
        controller: _code,
        keyboardType: TextInputType.number,
        maxLength: 8,
        decoration: const InputDecoration(labelText: 'Código de acceso'),
      ),
    const SizedBox(height: 8),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton(
          key: const ValueKey('account-request-otp'),
          onPressed: _busy ? null : _requestOtp,
          child: const Text('Solicitar código'),
        ),
        if (_otpRequested)
          FilledButton(
            key: const ValueKey('account-verify-otp'),
            onPressed: _busy ? null : _verifyOtp,
            child: const Text('Verificar código'),
          ),
      ],
    ),
  ];

  List<Widget> _profileFields() => [
    const SizedBox(height: 12),
    Text('Correo verificado: ${_profile!.email}'),
    TextField(
      key: const ValueKey('account-name'),
      controller: _name,
      maxLength: 120,
      decoration: const InputDecoration(labelText: 'Nombre (opcional)'),
    ),
    TextField(
      key: const ValueKey('account-phone'),
      controller: _phone,
      maxLength: 24,
      keyboardType: TextInputType.phone,
      decoration: const InputDecoration(labelText: 'Teléfono (opcional)'),
    ),
    TextField(
      key: const ValueKey('account-municipality'),
      controller: _municipality,
      maxLength: 120,
      decoration: const InputDecoration(
        labelText: 'Municipio declarado (opcional)',
      ),
    ),
    const Padding(
      padding: EdgeInsets.only(top: 8),
      child: Text('Categorías declaradas (opcionales)'),
    ),
    for (final category in const {
      'car': 'Carro',
      'motorcycle': 'Motocicleta',
      'taxi': 'Taxi',
      'public_service': 'Servicio público',
    }.entries)
      CheckboxListTile(
        key: ValueKey('account-category-${category.key}'),
        contentPadding: EdgeInsets.zero,
        value: _categories.contains(category.key),
        title: Text(category.value),
        onChanged: (value) => setState(() {
          value == true
              ? _categories.add(category.key)
              : _categories.remove(category.key);
        }),
      ),
    SwitchListTile(
      key: const ValueKey('account-marketing-consent'),
      contentPadding: EdgeInsets.zero,
      value: _marketing,
      title: const Text('Recibir novedades comerciales por correo'),
      subtitle: const Text('Opcional y separado del uso de la cuenta.'),
      onChanged: _busy ? null : _changeMarketing,
    ),
    Wrap(
      spacing: 8,
      children: [
        FilledButton(
          key: const ValueKey('account-save-profile'),
          onPressed: _busy ? null : _saveProfile,
          child: const Text('Guardar perfil'),
        ),
        OutlinedButton(
          key: const ValueKey('account-logout'),
          onPressed: _busy ? null : _logout,
          child: const Text('Cerrar sesión'),
        ),
        TextButton(
          key: const ValueKey('account-delete'),
          onPressed: _busy ? null : _confirmDelete,
          child: const Text('Eliminar cuenta'),
        ),
      ],
    ),
  ];

  Future<void> _requestOtp() async {
    final config = ref.read(appAccountConfigProvider);
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Escribe el correo de tu cuenta.');
      return;
    }
    await _run(() async {
      await ref
          .read(appAccountClientProvider)
          .requestOtp(_email.text, privacyAccepted: _privacyAccepted);
      _otpRequested = true;
      _message = config.privacyConfigured
          ? _privacyAccepted
                ? 'Solicitud procesada. Si la cuenta está habilitada, revisa el correo; no compartas el código.'
                : 'Si ya tienes cuenta, revisa el correo. Para crear una cuenta nueva debes aceptar la política vigente.'
          : 'Si ya tienes una cuenta, revisa el correo. No se tramitan altas nuevas sin política configurada.';
    });
  }

  Future<void> _restoreSession() async {
    await _run(() async {
      final profile = await ref.read(appAccountClientProvider).loadProfile();
      _applyProfile(profile);
      _message = 'Sesión recuperada. Los datos del garaje no se sincronizan.';
    });
  }

  Future<void> _verifyOtp() async {
    await _run(() async {
      final profile = await ref
          .read(appAccountClientProvider)
          .verifyOtp(_email.text, _code.text);
      _applyProfile(profile);
      _message = 'Cuenta conectada. Los vehículos y documentos siguen locales.';
    });
  }

  Future<void> _saveProfile() async {
    await _run(() async {
      final profile = await ref
          .read(appAccountClientProvider)
          .updateProfile(
            name: _name.text,
            phone: _phone.text,
            municipality: _municipality.text,
            categories: _categories.toList(growable: false),
          );
      _applyProfile(profile);
      _message = 'Perfil guardado.';
    });
  }

  Future<void> _changeMarketing(bool accepted) async {
    final previous = _marketing;
    setState(() => _marketing = accepted);
    await _run(() async {
      _marketing = await ref
          .read(appAccountClientProvider)
          .updateMarketing(accepted);
      _message = accepted
          ? 'Preferencia comercial activada.'
          : 'Preferencia comercial desactivada.';
    }, marketingFallback: previous);
  }

  Future<void> _logout() async {
    await _run(() async {
      await ref.read(appAccountClientProvider).logout();
      _reset();
      _message =
          'Sesión cerrada. Los datos locales del dispositivo se conservaron.';
    });
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: const Text(
          'Se borrará el perfil de cuenta del servidor. Vehículos y documentos de este dispositivo se conservarán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar cuenta'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await ref.read(appAccountClientProvider).suppress();
      _reset();
      _message =
          'Cuenta eliminada. Los datos locales del dispositivo se conservaron.';
    });
  }

  Future<void> _run(
    Future<void> Function() action, {
    bool? marketingFallback,
  }) async {
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await action();
    } on AppAccountFailure catch (failure) {
      _error = switch (failure.code) {
        'not_configured' => 'No disponible todavía.',
        'unauthorized' || 'invalid_or_expired_code' => 'El código o la sesión no se pudo confirmar. Revisa el dato e inténtalo de nuevo.',
        'rate_limited' =>
          'Demasiados intentos. Espera antes de volver a solicitarlo.',
        _ => 'No se pudo completar la solicitud. Inténtalo más tarde.',
      };
      if (marketingFallback != null) _marketing = marketingFallback;
    } catch (_) {
      _error = 'No se pudo completar la solicitud. Inténtalo más tarde.';
      if (marketingFallback != null) _marketing = marketingFallback;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _applyProfile(AppAccountProfile profile) {
    _profile = profile;
    _name.text = profile.name;
    _phone.text = profile.phone;
    _municipality.text = profile.municipality;
    _categories
      ..clear()
      ..addAll(profile.categories);
    _marketing = profile.marketingConsent;
  }

  void _reset() {
    _profile = null;
    _email.clear();
    _otpRequested = false;
    _privacyAccepted = false;
    _code.clear();
    _name.clear();
    _phone.clear();
    _municipality.clear();
    _categories.clear();
    _marketing = false;
  }
}
