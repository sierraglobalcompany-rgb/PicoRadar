import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../garage/data/vehicle_profile.dart';

bool get insuranceQuoteDemoAvailable =>
    appFlavor == 'dev' && const String.fromEnvironment('APP_ENV') == 'dev';

Future<void> showInsuranceQuoteDemo(
  BuildContext context,
  VehicleProfile vehicle,
) async {
  if (!insuranceQuoteDemoAvailable) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => InsuranceQuoteDemoSheet(vehicle: vehicle),
  );
}

/// Local presentation only: no repository, transport or applicant input exists.
class InsuranceQuoteDemoSheet extends StatefulWidget {
  const InsuranceQuoteDemoSheet({required this.vehicle, super.key});
  final VehicleProfile vehicle;

  @override
  State<InsuranceQuoteDemoSheet> createState() =>
      _InsuranceQuoteDemoSheetState();
}

class _InsuranceQuoteDemoSheetState extends State<InsuranceQuoteDemoSheet> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  var _step = 0;
  var _terms = false;
  var _privacy = false;
  var _finished = false;

  @override
  void initState() {
    super.initState();
    final vehicle = widget.vehicle;
    _fields = {
      'plate': TextEditingController(text: vehicle.plate),
      'brand': TextEditingController(text: vehicle.brand),
      'model': TextEditingController(text: vehicle.model),
      'year': TextEditingController(text: vehicle.year?.toString()),
      'registration': TextEditingController(text: vehicle.registrationCity),
      'department': TextEditingController(),
      'circulation': TextEditingController(),
    };
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .9,
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Cotizaci\u00f3n de demostraci\u00f3n',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Text('Demostraci\u00f3n: no se enviar\u00e1n datos.'),
              const SizedBox(height: 16),
              if (_finished) ...[
                const Icon(Icons.check_circle_outline, size: 40),
                const Text(
                  'Demostraci\u00f3n finalizada. No se envi\u00f3 ninguna solicitud.',
                  key: ValueKey('insurance-demo-finished'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ] else ...[
                Text(
                  '${_step + 1} de 3 \u00b7 ${const ['Veh\u00edculo', 'Solicitante', 'Revisi\u00f3n'][_step]}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                if (_step == 0) ...[
                  Text(
                    widget.vehicle.kind == VehicleKind.motorcycle
                        ? 'Moto'
                        : 'Carro',
                  ),
                  Text(
                    widget.vehicle.serviceType == VehicleServiceType.taxi
                        ? 'Servicio: taxi'
                        : 'Servicio: particular',
                  ),
                  _field('plate', 'Placa'),
                  _field('brand', 'Marca'),
                  _field('model', 'L\u00ednea / modelo'),
                  _field('year', 'A\u00f1o'),
                  _field('registration', 'Municipio de matr\u00edcula'),
                  _field('department', 'Departamento de matr\u00edcula'),
                  _field('circulation', 'Ciudad de circulaci\u00f3n'),
                ],
                if (_step == 1) ...[
                  const Text(
                    'Datos ficticios, no editables. No ingreses datos personales.',
                  ),
                  const ListTile(
                    title: Text('Nombre'),
                    subtitle: Text('Persona de ejemplo'),
                  ),
                  const ListTile(
                    title: Text('Documento'),
                    subtitle: Text(
                      'FICTICIO \u00b7 no solicitado a una persona real',
                    ),
                  ),
                  const ListTile(
                    title: Text('Correo'),
                    subtitle: Text('ejemplo@example.invalid'),
                  ),
                  const ListTile(
                    title: Text('Tel\u00e9fono'),
                    subtitle: Text('No disponible en demostraci\u00f3n'),
                  ),
                ],
                if (_step == 2) ...[
                  Text(
                    '${_fields['brand']!.text} ${_fields['model']!.text} \u00b7 ${_fields['year']!.text}',
                  ),
                  Text('Placa: ${_fields['plate']!.text}'),
                  Text(
                    'Matr\u00edcula: ${_fields['registration']!.text}, ${_fields['department']!.text}',
                  ),
                  Text('Circulaci\u00f3n: ${_fields['circulation']!.text}'),
                  const Text(
                    'Solicitante ficticio. No existe un aliado receptor en esta demostraci\u00f3n.',
                  ),
                  CheckboxListTile(
                    key: const ValueKey('insurance-demo-terms'),
                    contentPadding: EdgeInsets.zero,
                    value: _terms,
                    onChanged: (value) =>
                        setState(() => _terms = value ?? false),
                    title: const Text(
                      'Simular aceptaci\u00f3n de t\u00e9rminos',
                    ),
                  ),
                  CheckboxListTile(
                    key: const ValueKey('insurance-demo-privacy'),
                    contentPadding: EdgeInsets.zero,
                    value: _privacy,
                    onChanged: (value) =>
                        setState(() => _privacy = value ?? false),
                    title: const Text(
                      'Simular autorizaci\u00f3n de tratamiento de datos',
                    ),
                  ),
                  const Text(
                    'Estas selecciones no son una autorizaci\u00f3n real y no se guardan.',
                  ),
                ],
                const SizedBox(height: 16),
                if (_step > 0)
                  TextButton(
                    onPressed: () => setState(() => _step--),
                    child: const Text('Anterior'),
                  ),
                FilledButton(
                  key: const ValueKey('insurance-demo-next'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: _step == 2 && (!_terms || !_privacy)
                      ? null
                      : () {
                          if (_step == 0 && !_form.currentState!.validate()) {
                            return;
                          }
                          FocusScope.of(context).unfocus();
                          setState(() {
                            if (_step == 2) {
                              _finished = true;
                            } else {
                              _step++;
                            }
                          });
                        },
                  child: Text(
                    _step == 2 ? 'Finalizar demostraci\u00f3n' : 'Continuar',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  Widget _field(String id, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label),
        Semantics(
          label: label,
          child: TextFormField(
            key: ValueKey('insurance-demo-$id'),
            controller: _fields[id],
            keyboardType: id == 'year'
                ? TextInputType.number
                : TextInputType.text,
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return 'Completa este dato del veh\u00edculo.';
              if (id == 'year') {
                final year = int.tryParse(text);
                if (year == null ||
                    year < 1900 ||
                    year > DateTime.now().year + 2) {
                  return 'Revisa el a\u00f1o.';
                }
              }
              if (id == 'plate' &&
                  !RegExp(r'^[A-Za-z0-9 -]{3,12}$').hasMatch(text)) {
                return 'Revisa el formato de la placa.';
              }
              return null;
            },
          ),
        ),
      ],
    ),
  );
}
