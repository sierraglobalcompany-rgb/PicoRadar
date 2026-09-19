# C11 Home Sponsor Carousel Handoff

## Status
`PARTIAL - automatic gates passed; build and physical QA pending`

## Lot
`C11 - Inicio: carrusel patrocinado borde a borde`

## Git
- Branch: `fix/C11-home-sponsor-carousel`
- Base commit: `13190d0ff177995322806e67d1ca5fdf5d856495`
- Worktree: `C:/Users/felip/.codex/worktrees/home-sponsor-carousel/PicoRadar_ Pico y Placa`

## Outcome
- Una sola campana ocupa el ancho completo en telefonos.
- Flechas e indicadores estan integrados en el banner, sin contador visible.
- El antiguo banner inferior se retiro solo de Inicio.
- Inicio cabe sin scroll con texto normal en la matriz aprobada.

## Files / areas changed
- `mobile/lib/features/home/presentation/home_partner_carousel.dart`
- `mobile/lib/features/home/presentation/home_screen.dart`
- `mobile/lib/features/home/presentation/home_vehicle_carousel.dart`
- `mobile/lib/features/home/presentation/home_banner_slot.dart` (retirado)
- Pruebas de Inicio y contrato visual.

## Tests executed
| Command / test | Result |
|---|---|
| Home carousel, Home screen y startup visual slots | 198 passed |
| `flutter analyze` | Pending |
| Suite movil completa | Pending |

## Manual QA
- Matriz widget: 360x780, 360x800, 390x844, 412x915 y 430x932.
- Texto 1.0 sin scroll; texto 1.5/2.0 sin overflow critico.

## Physical Android QA
`Pending`
- Device: Mi A3 API 30
- Evidence: pendiente de build e instalacion dev.

## Data / migration impact
- Ninguno. No hay migracion ni cambio de datos del usuario.

## Security / privacy review
- Sin red, nuevos permisos, PII o activacion publicitaria.
- El formulario de aliados conserva sus gates existentes.

## Dependencies added/changed
- Ninguna.

## Known risks / debt
- La aprobacion visual del owner requiere captura fisica de la APK final.

## Stop conditions encountered
- Ninguna.

## Next lot(s) unblocked
- Continuacion de C11 tras aprobacion visual.

## Do not forget
- No merge performed.
