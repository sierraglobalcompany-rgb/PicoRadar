# PicoRadar: handoff único de recuperación V2

## Estado

**PARTIAL — en verificación.** Fuente recuperada y respaldos comprobados; reconstrucción independiente y CI aún no acreditados. Este documento se actualizará con los resultados observados.

## Git y trabajo

- Canónico: `D:/Dev/PicoRadar`, exFAT; branch `recovery/20261019-modern`.
- Fuente moderna: `ffe0cbd194310e004b20abd97fcd10e685c7df88` (B07 administrativo).
- Original C: `codex/forensic-alerts`, `d26ba84b1e1aeb7738e7dc965a3ad4adca16d917`, preservado.
- Base remota del PR: main histórico `e9ef37511df3110ffb0fc006ef06be781df432ac`. No se seleccionó como runtime moderno.
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
| Flutter formato/análisis/tests/APK desde clon remoto | NOT_RUN en este corte |
| Laravel/Pint/migraciones/assets desde clon remoto | NOT_RUN en este corte |
| B06/B07 paquete y navegador desde clon remoto | NOT_RUN; denegación local de archivo señalada abajo |
| CI del HEAD final | NOT_RUN en este corte |

## Bloqueos, QA y deuda

Windows deniega recrear `scripts/tests/test_hostinger_installer_browser.ps1` en D:. `git restore --source=HEAD -- <archivo>` devolvió `Permission denied`; el archivo permanece en el árbol Git y no se elimina del commit. Causa aún no determinada; no se desactiva seguridad ni se evade la denegación. El checkout local puede mostrar esa ausencia.

QA física scanner, autenticación, notificaciones, Conducir y rendimiento heredada: **pendiente, no ejecutada**, por instrucción de no tocar Mi A3. Sin merge ni Hostinger. Word3D/World3D y originales artísticos históricos no localizados dentro de la cobertura; assets runtime sí versionados. Chats antiguos no exportados no accesibles.

## NEXT

Completar Gate C desde un clon nuevo exclusivamente GitHub en `D:/Verification/PicoRadar`, branch `recovery/20261019-modern`, fijar SHA/tree y ejecutar README. Registrar resultados exactos y la denegación de escritura si se reproduce; no iniciar una función nueva.
