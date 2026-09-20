# C11 Home Sponsor Carousel Handoff

## Status
`DONE - pending owner visual approval and larger-device physical QA`

## Lot
`C11 - Inicio: patrocinador ligero y vehiculo realmente adaptable`

## Git
- Branch: `fix/C11-home-sponsor-carousel`
- Responsive vehicle implementation checkpoint:
  `13de5558d8ec103ed14bd0be1ba86b5b6dc021d5`
- Responsive vehicle safety checkpoint:
  `codex/checkpoint-before-c11-responsive-vehicle` at
  `5a0d31fdb83932c6ea644724d25e51e2ebfe72f4`
- Light controls implementation checkpoint:
  `d3155af0fc4ba37aea56397f1e1dd606bb837bc1`
- Safety checkpoint: `codex/checkpoint-before-c11-home-controls` at
  `cb9a458c36ac98e98f72d8427880f5286a7181dc`
- Base commit: `13190d0ff177995322806e67d1ca5fdf5d856495`
- Worktree: `C:/Users/felip/.codex/worktrees/home-sponsor-carousel/PicoRadar_ Pico y Placa`

## Outcome
- Una sola campana ocupa el ancho completo en telefonos.
- La capsula ovalada se elimino por completo.
- Flechas de 22 dp con objetivos tactiles transparentes de 48 dp quedaron en
  las esquinas inferiores del banner.
- Cuatro circulos directos sobre la imagen muestran la campana activa, sin
  contador, barra, fondo ni fila adicional.
- El antiguo banner inferior se retiro solo de Inicio.
- El vehiculo es ahora el bloque elastico de Inicio: usa todo el alto restante
  entre 168 y 360 dp, sin conservar el anterior 40% de espacio vacio.
- La tarjeta central crece continuamente del 64% al 78% del ancho. La zona de
  imagen ocupa expresamente todo el ancho para que crezca el vehiculo visible,
  no solo su contenedor.
- La resolucion solicitada se calcula con ancho y densidad, limitada entre 360
  y 1024 px. Cambiar el viewport reconstruye el controlador sin perder foco.
- Inicio cabe sin scroll con texto normal en la matriz aprobada. SOAT y
  Tecnomecanica quedan completamente visibles sobre la navegacion inferior.

## Files / areas changed
- `mobile/lib/features/home/presentation/home_partner_carousel.dart`
- `mobile/lib/features/home/presentation/home_vehicle_carousel.dart`
- `mobile/test/features/home/presentation/home_partner_carousel_test.dart`
- `mobile/test/features/home/presentation/home_screen_test.dart`
- `docs/CURRENT.md`
- `docs/DESIGN_CONTRACT.md`

## Tests executed
| Command / test | Result |
|---|---|
| Home carousel y Home screen con shell real | 192 passed |
| `flutter analyze --no-pub` | Passed, no issues |
| Suite movil completa | 3,226 passed, 10 skipped |
| Dev release build and wallet release gate | Passed |

## Manual QA
- Matriz widget: 360x780, 360x800, 390x844, 412x915 y 430x932.
- Se monto `PicoRadarApp`, `AppBottomNav` y areas seguras equivalentes al Mi A3.
- Texto 1.0 con `maxScrollExtent == 0`; texto 1.5/2.0 sin overflow critico.
- Se verifico crecimiento monotono del vehiculo, `BoxFit.contain`, controles
  de 48 dp y ausencia de interseccion entre flechas y CTA.
- La prueba de regresion reproduce el defecto anterior: en 360x1000 el
  carrusel se quedaba en 300 dp. Ahora alcanza 360 dp, ensancha tarjeta y area
  visual y conserva pagina y vehiculo enfocado.

## Physical Android QA
`Required and passed`
- Device: Mi A3 API 30
- Installed with `adb install -r` at 2026-09-19 19:03:07 without clearing data.
- Package: `co.picoradar.app.dev`, version `1.0.0` (1), target API 36.
- APK:
  `artifacts/current/apk/PicoRadar-dev-release-home-responsive-vehicle-20260919.apk`
- Local and installed SHA-256:
  `3F5ECDF2F5C55C4BD5FB788A030E894CF2A7DE33B72F6C157360678C39660143`
- Evidence:
  `artifacts/current/evidence/home-responsive-vehicle-mi-a3-20260919.png`.
- Observed: full-width single slide, direct circles, corner arrows, successful
  vehicle complete, no legacy lower banner, and SOAT plus Tecnomecanica fully
  visible above the bottom navigation without scroll.
- Connected device remains Mi A3 at 720x1560 px / 320 dpi (360x780 dp). The
  larger matrix is automated and green, but a second physical larger device
  was not connected and is not claimed as physically verified.

## Data / migration impact
- Ninguno. No hay migracion ni cambio de datos del usuario.

## Security / privacy review
- Sin red, nuevos permisos, PII o activacion publicitaria.
- El formulario de aliados conserva sus gates existentes.

## Dependencies added/changed
- Ninguna.

## Known risks / debt
- La aprobacion visual final sigue correspondiendo al owner.
- Falta una captura fisica en un segundo telefono de mayor viewport; no bloquea
  el build ni la instalacion, pero permanece como evidencia pendiente.

## Stop conditions encountered
- Ninguna.

## Next lot(s) unblocked
- Continuacion de C11 tras aprobacion visual.

## Do not forget
- No merge performed.
