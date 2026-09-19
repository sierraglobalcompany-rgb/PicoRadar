# C11 Home Sponsor Carousel Handoff

## Status
`DONE - pending owner visual approval`

## Lot
`C11 - Inicio: carrusel patrocinado borde a borde`

## Git
- Branch: `fix/C11-home-sponsor-carousel`
- Implementation checkpoint: `be61d43a38762cef3941c3d96b3a0590f382091c`
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
| `flutter analyze --no-pub` | Passed, no issues |
| Suite movil completa | 3,226 passed, 10 skipped |
| Dev release build and wallet release gate | Passed |

## Manual QA
- Matriz widget: 360x780, 360x800, 390x844, 412x915 y 430x932.
- Texto 1.0 sin scroll; texto 1.5/2.0 sin overflow critico.

## Physical Android QA
`Required and passed`
- Device: Mi A3 API 30
- Installed with `adb install -r` at 2026-09-19 17:32:32 without clearing data.
- APK: `artifacts/current/apk/PicoRadar-dev-release-home-carousel-20260919.apk`
- SHA-256: `B1CA1EE0762252E476A9CA8C068A752B4F2B6DF7C460F1B8490E99DAB2E0E907`
- Evidence: `artifacts/current/evidence/home-carousel-mi-a3-20260919.png`
  and `artifacts/current/evidence/home-carousel-next-mi-a3-20260919.png`.
- Observed: full-width single slide, integrated controls, successful next-arrow
  navigation, no legacy lower banner and no overlap with the main status.

## Data / migration impact
- Ninguno. No hay migracion ni cambio de datos del usuario.

## Security / privacy review
- Sin red, nuevos permisos, PII o activacion publicitaria.
- El formulario de aliados conserva sus gates existentes.

## Dependencies added/changed
- Ninguna.

## Known risks / debt
- La aprobacion visual final sigue correspondiendo al owner; la evidencia fisica
  cumple los criterios medibles del lote.

## Stop conditions encountered
- Ninguna.

## Next lot(s) unblocked
- Continuacion de C11 tras aprobacion visual.

## Do not forget
- No merge performed.
