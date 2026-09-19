# Lot Handoff

## Status
`DONE`

## Lot
`E/F - datos nacionales y Trámites`

## Git
- Branch: `codex/lot-ef-national-coverage`
- HEAD de implementación validada: `45795618c3e17d6f36d7fcba033820dc3f4dd365`
- Base branch: `main` en `d26ba84b1e1aeb7738e7dc965a3ad4adca16d917`
- Worktree: `C:\Users\felip\.codex\worktrees\owner-national-data\PicoRadar_ Pico y Placa`
- Estado al crear este handoff: limpio después del commit de implementación; solo este handoff queda para el commit documental.

## Outcome
- Trámites consume el inventario territorial versionado de 769 autoridades y 1.003 filas fuente, con búsqueda por autoridad, municipio y departamento.
- Solo Bogotá y Medellín exponen enlaces directos revisados. Las otras 767 autoridades muestran `Por confirmar`: 5 usan fallback institucional y 762 el directorio oficial RUNT.
- Pico y placa clasifica 73 municipios en 6 verificados, 36 condicionales, 2 expirados y 29 pendientes. Solo 5 paquetes afirmativos existentes quedan habilitados en el motor.
- Cámaras y peajes tienen manifiestos tipados con conteos, hashes, procedencia y semántica explícita de snapshot/no vigencia actual. Valores desconocidos permanecen desconocidos.
- Se agregaron matrices de auditoría y un validador determinista para conteos, distribuciones, hashes y aislamiento del motor.

## Files / areas changed
- Catálogo y UI nacional de Trámites.
- Catálogo operativo Pico 73, parser estricto, selector y auditoría CSV/Markdown.
- Manifiestos de cámaras y peajes, además de copy de estado/procedencia en Fotomultas y Viaje.
- Pruebas de datos, búsqueda, compatibilidad, presentación responsiva y semántica de desconocidos.
- Scripts `compile_pico_operational_catalog.py` y `validate_national_coverage.py`.
- No se modificaron Conducir, Billetera, Inicio, consultas backend ni Mantenimiento.

## Tests executed
| Command / test | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed .` | PASS, 371 archivos, 0 cambios |
| `flutter analyze --no-pub` | PASS, sin hallazgos |
| `flutter test --no-pub test/features/comparendos/data test/features/tramites` | PASS, 93 pruebas |
| `flutter test --no-pub test/features/fotomultas` | PASS, 85 pruebas |
| `flutter test --no-pub test/features/trip/data/toll_dataset_manifest_test.dart test/features/trip/data/toll_inventory_test.dart test/features/trip/data/toll_tariff_catalog_test.dart test/features/trip/presentation/trip_route_preview_map_test.dart` | PASS, 49 pruebas |
| `flutter test --no-pub` | PASS, 3.202 pruebas y 10 omitidas |
| `python scripts/validate_national_coverage.py` | PASS |
| `git diff --check` | PASS |

## Manual QA
- Cubierta por pruebas widget en 360x780, 360x800, 390x844, 412x915 y 430x932 con escalas de texto 1.0, 1.5 y 2.0.
- No se realizó QA exploratoria en dispositivo.

## Physical Android QA
`Not required`
- Device: N/A
- Android: N/A
- Evidence: el lote no cambia cámara física, GPS, notificaciones, background, TTS, Bluetooth, HUD ni lifecycle protegido.

## Data / migration impact
- No hay migración de Drift/SQLite ni borrado de datos locales.
- Se reemplaza el catálogo documental Pico 73 por schema 2 y se agregan manifiestos versionados de cámaras y peajes.
- El asset del motor `restrictions_v1.json` permanece byte por byte con SHA-256 `68642a2e8fda49cf89c45d8439c6cbf5064aa176aeefe2fa3c4083c8201c4d16`.

## Security / privacy review
- Sin secretos, PII nueva, logging sensible, GPS continuo ni llamadas backend en el hot path.
- Las fuentes se consumen desde assets locales auditados; el lote no agrega scraping ni bypass de CAPTCHA.

## Dependencies added/changed
- Ninguna.

## Known risks / debt
- Trámites: faltan enlaces de procedimiento acreditados para 767 autoridades; 5 tienen sitio institucional revisado y 762 dependen del directorio RUNT.
- Pico: 36 municipios requieren validación local, 29 no tienen evidencia suficiente y 2 tienen evidencia expirada/derogada. Faltan URLs externas suficientes para Turbaco, Florencia, Fusagasugá, Soacha, Montería, Santa Cruz de Lorica, Neiva, Pitalito, Ipiales, Sincelejo, Palmira y Tuluá.
- Cámaras: 67 de 360 registros no reportan velocidad; el snapshot cubre 13 departamentos o territorios y no confirma operación actual.
- Peajes: las 184 estaciones del inventario conservan tarifa desconocida; 180 no tienen operación confirmada, 1 fue reportada operando por la fuente, 2 son históricas no operativas y 1 aparece dañada en revisión. El catálogo tarifario no tuvo reverificación externa y mantiene 9 candidatos fuera de la base.

## Stop conditions encountered
- Ninguna. No se fabricaron reglas, enlaces, estados actuales ni fechas de renovación.

## Next lot(s) unblocked
- Revisión editorial incremental de enlaces directos de Trámites y evidencia municipal Pico, manteniendo el estado `Por confirmar` hasta contar con fuente suficiente.

## Do not forget
- No se hizo merge ni push.
