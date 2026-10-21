# Lot Handoff

## Status
`DONE`

## Lot
`C11 - cierre de coherencia posterior al carrusel`

## Git
- Branch: `chore/C11-post-coherence`
- HEAD: el commit que contiene este handoff; el SHA exacto queda fijado en el
  `MANIFEST.json` del paquete de entrega.
- Base branch: `chore/C11-post-server-contracts`
- Base HEAD: `b30d7781bd810b35d338f80085b96226758435c7`
- Effective C11 base: `2e8f2ed381eb4d10254532724aa3026c8c310317`
- Safety checkpoint: `codex/checkpoint-before-post-c11-coherence`
- Worktree: `C:/Users/felip/.codex/worktrees/post-c11-server-modes/PicoRadar_ Pico y Placa`

## Outcome
- Se corrigieron las columnas Lite, Completo y Pro de la matriz de 189 acciones
  sin activar ninguno de los modos.
- El preflight de solo lectura separa Laravel/panel de OSRM, conserva estados
  `PASS`, `FAIL`, `UNKNOWN` y `NOT_APPLICABLE`, y registra la procedencia de la
  evidencia antes de afirmar que un host esta listo.
- Las capturas C11 quedaron clasificadas como historicas o finales, con hashes y
  limites probatorios explicitos.
- La prueba puntual de mantenimiento reprodujo dos fallos: uso de `ref` despues
  de desmontar la pantalla y estado visual obsoleto al regresar al vehiculo. Se
  corrigieron con guardado serializado, vehiculo capturado, error visible y
  refresco auto-descartable.

## Files / areas changed
- `docs/post_c11/`: matriz, diferencias, propuesta de modos, evidencia y staging.
- `scripts/server_preflight.ps1` y pruebas de contratos/preflight.
- `mobile/lib/features/maintenance/presentation/maintenance_screen.dart`.
- `mobile/lib/app/app_providers.dart`.
- `mobile/test/features/maintenance/presentation/maintenance_screen_test.dart`.
- `docs/CURRENT.md`.

## Tests executed
| Command / test | Result |
|---|---|
| `scripts/tests/test_post_c11_mode_matrix.ps1` | PASS; 189 acciones, identidades estables y politicas clave coherentes |
| `scripts/tests/test_server_preflight.ps1` | PASS; perfiles separados, procedencia, desconocidos y modo lectura |
| Pruebas rojas del callback de mantenimiento | Reprodujeron ambos defectos antes de la correccion |
| Pruebas focalizadas de mantenimiento e inicio | PASS; 33 pruebas |
| `flutter analyze --no-pub` | PASS; sin observaciones |
| `flutter test --no-pub --concurrency=1 --reporter compact` | PASS; 3238 aprobadas y 10 omitidas conocidas |

## Manual QA
- Se inspeccionaron las capturas historicas y finales de C11; solo las
  `home-light-controls-*` representan el cierre visual aprobado.
- Los preflight locales reportan Laravel `UNKNOWN` y OSRM `FAIL`; ninguno prueba
  la capacidad real de Hostinger.

## Physical Android QA
`Not required`
- No se instalo APK ni se modificaron datos del telefono.

## Data / migration impact
- Sin migraciones ni cambios de schema.
- La matriz y documentos son preparatorios; no activan acceso ni persistencia.
- La preferencia existente de recordatorios conserva su formato.

## Security / privacy review
- El preflight no lee `.env`, no se conecta a DB, no instala, no migra y no
  inicia servicios.
- No se recopilaron credenciales, datos del telefono, GPS ni documentos.
- No se activaron registro, Lite, anuncios, Pro, pagos o WhatsApp.

## Dependencies added/changed
- Ninguna.

## Known risks / debt
- Falta inventariar el plan Hostinger real; hasta entonces Laravel permanece
  `UNKNOWN` y OSRM se evalua de forma independiente.
- Las capturas C11 no prueban por si solas identidad entre APK y fuente.
- Los modos son un contrato propuesto, no comportamiento implementado.

## Stop conditions encountered
- Ninguna. La falta de datos de Hostinger no bloqueo el cierre local solicitado.

## Next lot(s) unblocked
- Recoleccion no secreta de capacidades del hosting y decision separada para
  staging Laravel y OSRM.

## Do not forget
- No se hizo merge, push, deploy, gasto ni instalacion de APK.
