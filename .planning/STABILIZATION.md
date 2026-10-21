# Estabilizacion de la version consolidada

Estado: cerrado con checkpoint local, 2026-09-16. Rama:
`codex/stabilize-current-suite`. Base de consolidacion: `ccd00bd`.

Autorizacion del owner: dejar una base unica actual sin los 87 fallos conocidos,
generar APK dev release e instalarlo en el celular, sin limpiar otros proyectos ni
eliminar trabajo ajeno.

## Resultado

- Los 87 fallos globales conocidos quedaron en 0 fallos automatizados en la suite
  final.
- La regresion focalizada de cierre paso: 417 aprobadas / 0 fallos.
- Suite completa final: 2959 aprobadas / 11 omitidas existentes / 0 fallos.
- `dart format --output=none --set-exit-if-changed .`: limpio.
- `flutter analyze`: limpio, sin issues.
- Build Android dev release: exitoso.
- Instalacion en Mi A3: `adb install -r`, resultado `Success`.

## APK instalado

- Archivo: `artifacts/current/apk/PicoRadar-dev-release-stabilized-20260915-235843.apk`
- SHA256: `53C7195D361F9DF984E63462EE2EB0533F14E5EF4316A7B3EBF788D4A56634C5`
- Dispositivo ADB: `116f2191b19a`

## Fallos resueltos

- Home/Pico: expectativas y llaves de calendario/fuentes alineadas con la UI
  vigente, sin restaurar pantallas antiguas.
- Pico con texto ampliado: ajuste de selector de ciudad, grilla semanal y textos
  de dias restringidos para evitar overflow.
- Garage/Apps launcher/K7: pruebas estabilizadas contra rutas y superficies
  actuales, esperando roots reales de pantalla.
- Documents: `vehicleId` explicito inexistente ahora falla cerrado y exige elegir
  un vehiculo vigente, sin caer silenciosamente al favorito.
- CDA mapa y Compra/Venta/Peritajes: aperturas externas protegidas ante retorno
  `false` o excepcion.
- K7 funcional: matriz de cobertura actualizada para pantallas y hojas nuevas.

## Hallazgos durante el cierre

- La primera repeticion global despues de resolver los 15 focalizados encontro 1
  fallo adicional: una expectativa vieja de Documentos que aun esperaba fallback
  al favorito cuando entraba un `vehicleId` inexistente. Se corrigio al contrato
  seguro actual: fail-closed.
- Quedan 11 tests omitidos existentes en la suite. No se agregaron skips nuevos
  para ocultar fallos de esta estabilizacion.
- No se ejecuto QA visual fisica con capturas en esta etapa; solo build e
  instalacion fisica del APK. La validacion visual de modulos sigue siendo una
  actividad separada cuando el owner la solicite.

## Alcance respetado

- No se hizo merge ni push.
- No se eliminaron carpetas externas ni temporales.
- `capturas/`, `mockups/` y `output/` se preservaron como contenido previo sin
  seguimiento y no se incluyeron como cambios propios.
- No se modificaron datos del celular ni se reinstalo una version antigua.

## Evidencia local

- Log suite completa final: `artifacts/current/consolidation/full-tests-final.log`
- Log primera repeticion global: `artifacts/current/consolidation/full-tests-rerun.log`
- APK final: `artifacts/current/apk/PicoRadar-dev-release-stabilized-20260915-235843.apk`
