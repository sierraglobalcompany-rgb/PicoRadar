# PicoRadar: handoff único de recuperación V2

## Estado

**PARTIAL — Gate C en curso.** Fuente recuperada y respaldos comprobados. Clon remoto independiente creado y comprobado; ejecución de suites aún abierta y CI bloqueado por infraestructura. No se declara DONE.

## Git y trabajo

- Canónico: `D:/Dev/PicoRadar`, exFAT; branch `recovery/20261019-modern`.
- Fuente moderna: `ffe0cbd194310e004b20abd97fcd10e685c7df88` (B07 administrativo).
- Original C: `codex/forensic-alerts`, `d26ba84b1e1aeb7738e7dc965a3ad4adca16d917`, preservado.
- Base remota del PR: main histórico `e9ef37511df3110ffb0fc006ef06be781df432ac`. No se seleccionó como runtime moderno.
- PR draft sin merge: https://github.com/sierraglobalcompany-rgb/PicoRadar/pull/71.
- Primer read-back remoto: `21be9d97156191bdf19253d9bc52fa699502d644`, tree `fe79831e1c7e8c7d8f1f0f82f250e8b40dcffa80`; clon independiente y pruebas parten de ese corte. Las revisiones posteriores son documentales.
- Comparador pendiente recuperado sin integrar: `recovery/20261019-pending-b04`, HEAD `fe0d8d46bf7c6abb223d246e7af43fbe1648439c`.
- El SHA de la entrega se obtiene con `git rev-parse HEAD` o el commit del PR; no se usa un hash autorreferencial dentro del documento.

## Cambios

Se recuperó la historia moderna owner → C11 → coherencia → B06 → B07 sin cambiar código runtime. README, AGENTS, CURRENT, DESIGN_CONTRACT, SOP, README servidor y entrada GSD orientan a la rama moderna y reconstrucción portable. Matriz: `PicoRadar_FORENSE_10_PASADAS.md`.

Los pipelines y lockfiles se conservan; no se añadieron dependencias, parsers, migraciones ni activaciones comerciales. B04 comparador permanece pendiente y separado. Versiones anteriores y QA histórica no se aplican sobre el runtime.

## Preservación

- 13 worktrees con estados comparados antes/después.
- 1.723 archivos no regenerables: 1.406.579.578 bytes verificados por SHA-256.
- Almacén Git completo: 792/792 archivos coincidentes, incluyendo índices, refs, reflogs y objetos; bundle complementario verificado.
- 93 entregables externos y 3 archivos privados B06 respaldados.
- Índice privado: `D:/PicoRadar_Rescue/manifests/`; snapshots y bundles fuera de Git. No copiar sesiones, bases, tokens ni manifiestos privados al chat/PR.
- C: intacto; D: no constituye por sí solo respaldo físico independiente.

## Tests y evidencia

| Comprobación | Resultado observado |
| --- | --- |
| Hashes ZIP V2 | 5/5 coinciden |
| Snapshot WIP / Git common-dir | PASS, cifras anteriores |
| Selección por ancestry y diffs | PASS; B07 contiene ancestros modernos |
| `git diff --check` documental | PASS antes del commit inicial |
| Escaneo historia moderna | Gitleaks 8.30.1; 1 falso positivo revisado en URL pública Power BI; sin credencial reproducida |
| Clon exclusivo GitHub | PASS: SHA/tree anteriores, inicialmente limpio, sin alternates |
| `flutter pub get` | PASS, lockfile conservado |
| `dart format --output=none --set-exit-if-changed .` | PASS |
| `flutter analyze --no-pub` | PASS, sin issues |
| Codegen | CODEGEN_NOT_REQUIRED según SOP-07; entradas y generados rastreados conservados |
| Suite móvil completa | IN_PROGRESS, concurrency=2; al menos ocho fallos de esperas/timeout/archivos observados; no se declara PASS |
| Simulación/APK/tests nativos | Pendientes de finalizar la suite en ejecución |
| Laravel/Pint/migraciones/assets | Composer validate PASS; 108 dependencias del lockfile en instalación, sin updates; resto pendiente |
| B06/B07 paquete y navegador desde clon remoto | NOT_RUN; denegación local de archivo señalada abajo |
| CI de `21be9d9` | CI_INFRA_BLOCKED_GITHUB_BILLING; cinco jobs fallaron sin iniciar steps por pagos/límite de gasto |
| Revisión de continuidad independiente | PASS de reanudación desde GitHub, exclusivamente lecturas remotas; no certifica reconstrucción. Contradicciones documentales de codegen/SOP/antecedentes visuales corregidas |

## Bloqueos, QA y deuda

Windows deniega recrear `scripts/tests/test_hostinger_installer_browser.ps1` en D:. `git restore --source=HEAD -- <archivo>` devolvió `Permission denied`. El archivo apareció inicialmente en el clon independiente y luego dejó de estar presente también allí. Permanece intacto en Git y no se incluye su eliminación en ningún commit. SHA-256 del contenido remoto: `a0b9b1d43b60402e6635b710212085168d16e8c230badee641c736d3f3656f2d`. Causa no confirmada; no se desactiva seguridad ni se evade el bloqueo. Ambos checkouts pueden mostrar su ausencia.

Pruebas móviles: se observaron esperas propias de fixtures de aproximadamente un segundo y timeouts generales de 30 segundos durante operaciones de archivo, además de un error de teardown por archivo abierto. Hipótesis pendiente de aislar: carga de E/S durante la instalación concurrente. No se debilitaron aserciones, omitieron pruebas ni cambiaron privacidad/runtime. Los contadores finales y las reproducciones aisladas siguen pendientes.

Firma release debug y su TODO son deuda histórica explícita; no se autoriza publicar una release con esa configuración.

QA física scanner, autenticación, notificaciones, Conducir y rendimiento heredada: **pendiente, no ejecutada**, por instrucción de no tocar Mi A3. Sin merge ni Hostinger. Word3D/World3D y originales artísticos históricos no localizados dentro de la cobertura; assets runtime sí versionados. Chats antiguos no exportados no accesibles.

## NEXT

Completar Gate C del clon GitHub `D:/Verification/PicoRadar`: consultar primero `D:/PicoRadar_Rescue/manifests/recovery-progress.md` y `*-gates.json` para no duplicar procesos en ejecución; recoger resultados, aislar fallos móviles una vez finalice la instalación y ejecutar los gates restantes. En otra máquina, crear un clon nuevo y seguir README. Cerrar con SHA/tree remoto, tests y blockers exactos; no iniciar una función nueva.
