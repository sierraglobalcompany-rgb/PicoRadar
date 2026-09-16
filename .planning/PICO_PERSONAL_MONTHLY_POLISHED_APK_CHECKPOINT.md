# Checkpoint: APK Mi Pico mensual pulido

Fecha: 2026-09-11 15:15 America/Bogota.
Repo: C:/Users/felip/Documents/ChatGPT/PicoRadar_ Pico y Placa/temp/VIAJE-R1-real-planner
Branch: codex/garage-single-favorite
HEAD: ddf60407174e3ee8d447b7eff3ca45e0fd983789

## Correcciones incluidas
- La accion visible bajo el hero muestra la ciudad consultada, por ejemplo "Medellin", no "Cambiar ciudad".
- La placa del hero personal se redujo a 78 dp con texto normal y 88 dp con texto ampliado.
- El vehiculo se escala mas dentro del fondo para recuperar protagonismo.
- El hero personal queda mas bajo para reducir scroll.
- El calendario mensual queda mas compacto, con margen interno y celdas mas bajas.
- La leyenda Libre / Restriccion / Por verificar queda centrada.

## Validacion local
- dart format aplicado.
- flutter test test/features/pico_placa/presentation/pico_detail_screen_test.dart
- flutter analyze

Resultado:
- Pico detail tests: PASS, 75 tests.
- Analisis: PASS, no issues.

## APK generado
APK:
C:/Users/felip/Documents/ChatGPT/PicoRadar_ Pico y Placa/temp/VIAJE-R1-real-planner/temp/PICO_PERSONAL_MONTHLY_POLISHED_APK_20260911/picoradar-mi-pico-mensual-polished-dev-release.apk

Tamano:
94839512 bytes

SHA256:
D4CBF8A5BFE017A885EDC3F10B3052896F1581FA336DA9072CD6D6FC1618B96C

## Limites
- No se instalo en el Mi A3.
- No se hizo prueba fisica local.
- No se uso ADB ni se tocaron datos del celular.
- No hubo commit, push, PR ni merge.
