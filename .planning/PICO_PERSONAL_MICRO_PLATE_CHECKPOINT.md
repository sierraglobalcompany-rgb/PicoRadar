# Checkpoint - Mi Pico y Placa micro plate

Fecha: 2026-09-11
Branch: codex/garage-single-favorite

## Cambio implementado

- Mi pico y placa ahora usa una variante `micro` de placa exclusivamente en el hero personal.
- La placa micro mantiene proporcion horizontal, emblema central y grupos en una sola linea para placas de seis caracteres como `ZVV73D`, `BOG127` y `KZA123`.
- La variante micro no cae al layout vertical; si el numero necesita menos espacio, se escala solo la fila del numero.
- La ciudad visible del selector temporal usa etiqueta corta:
  - `co-ant-medellin` -> `Medellin`
  - `co-dc-bogota` -> `Bogota`
  - `co-vac-cali` -> `Cali`
  - `co-cal-manizales` -> `Manizales`
  - fallback: texto antes de `·`, `/`, coma o ` - `
- La semantica conserva la accion completa: cambiar ciudad de consulta con ciudad actual.

## Archivos tocados en esta correccion

- `mobile/lib/core/design_system/branding.dart`
- `mobile/lib/features/garage/presentation/vehicle_plate_badge.dart`
- `mobile/lib/features/pico_placa/presentation/pico_detail_screen.dart`
- `mobile/test/features/pico_placa/presentation/pico_detail_screen_test.dart`

## Validacion ejecutada

- `dart format --output=none --set-exit-if-changed lib/core/design_system/branding.dart lib/features/garage/presentation/vehicle_plate_badge.dart lib/features/pico_placa/presentation/pico_detail_screen.dart test/features/pico_placa/presentation/pico_detail_screen_test.dart`
- `flutter analyze`
- `flutter test test/features/pico_placa/presentation/pico_detail_screen_test.dart`
- `flutter build apk --release --flavor dev`

Resultado:

- Formato: OK.
- Analisis: OK, sin issues.
- Test focalizado: OK, 76/76.
- APK dev release optimizada: OK.

## APK generado

Ruta:

`C:\Users\felip\Documents\ChatGPT\PicoRadar_ Pico y Placa\temp\VIAJE-R1-real-planner\temp\PICO_PERSONAL_MICRO_PLATE_APK_20260911\picoradar-mi-pico-micro-plate-dev-release.apk`

SHA-256:

`97374A2417A0066FBBE9C21C05283970B1FF1121A81B13A2613DB981C937201C`

## Estado de prueba fisica

No se instalo ni se probo en el Mi A3 despues de generar el APK.

Motivo: el usuario pidio crear checkpoint y pausar antes de probar/instalar en el celular para no afectar otro proceso en el dispositivo.

## Siguiente paso seguro

Cuando el usuario autorice usar el Mi A3:

1. Instalar `picoradar-mi-pico-micro-plate-dev-release.apk`.
2. Abrir Mi pico y placa.
3. Capturar hero superior y scroll de calendario.
4. Verificar visualmente:
   - placa horizontal, no vertical;
   - vehiculo con mayor protagonismo que la placa;
   - ciudad visible `Medellin`, no `Medellin · Valle de Aburra` ni `Medellin / Valle de Aburra`;
   - selector temporal abre sin cambiar GPS, ciudad global ni favorito.

