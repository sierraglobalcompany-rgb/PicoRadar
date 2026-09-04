const peritajesProfessionalInspectionWarning =
    'Este checklist no es un certificado ni reemplaza una inspeccion profesional.';

const peritajesChecklistItems = [
  'identidad y documentos',
  'carroceria/chasis',
  'motor/transmision',
  'frenos/suspension/llantas',
  'sistemas electricos',
  'prueba de conduccion',
];

String peritajesChecklistLabel(String value) {
  if (value.isEmpty) {
    return value;
  }
  return value[0].toUpperCase() + value.substring(1);
}
